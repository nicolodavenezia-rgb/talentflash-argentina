-- Bloque D (T-021/T-024/T-025): gestión del perfil profesional del candidato,
-- proyección pública limitada para empresas y preparación para postularse.
--
-- AUDITORÍA DE PRIVACIDAD (decisión central de este bloque): hasta acá una
-- empresa verificada podía hacer SELECT de la FILA COMPLETA de
-- candidate_profiles (policy `cand_visible_to_verified_companies`), columnas
-- privadas incluidas (birth_date, expectativa salarial, video_id, cv_url…).
-- T-024 exige exposición POR CAMPO. Esta migración:
--   1. elimina esa policy: la empresa ya no lee la tabla cruda por REST;
--   2. expone una proyección con whitelist explícita de campos vía RPC
--      `get_candidate_public_profile` (fail-closed: cualquier condición que
--      falle devuelve NULL, indistinguible de "no existe");
--   3. re-apunta la policy de videos que dependía de la policy eliminada.
--
-- Convención de errores (la traduce el cliente; nunca se muestra el texto):
--   42501 sin permiso · TFDAT datos inválidos/incompletos · TFCNS
--   consentimientos · TF018 minoría de edad · 23505 unicidad.

-- ---------------------------------------------------------------------------
-- Esquema: disponibilidad horaria estructurada (T-021).
-- jsonb de franjas [{day, start, end}] — day ∈ lun..dom (mismo formato que
-- jobs.schedule_days), horas 'HH:MM'; end < start = el turno cruza la
-- medianoche. Validación completa en private.validate_candidate_content().
-- ---------------------------------------------------------------------------

alter table candidate_profiles
  add column weekly_availability jsonb not null default '[]'::jsonb;

-- ---------------------------------------------------------------------------
-- Visibilidad candidato→empresa, en un solo lugar.
--
-- `is_published` ya implica consentimiento de publicación VIGENTE (la deriva
-- private.refresh_candidate_publication y se recalcula ante cada cambio de
-- consentimiento o de versión del texto), así que esta función es la regla
-- única: publicado + no borrado + empresa verificada + sin bloqueo mutuo.
-- Viven en `public` (no en `private`) porque las llaman policies y RPCs que
-- se evalúan como `authenticated`/`anon`; son SECURITY DEFINER y fail-closed.
-- ---------------------------------------------------------------------------

create or replace function public.company_can_view_candidate(p_candidate_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.candidate_profiles cp
    join public.profiles p on p.id = cp.profile_id
    where cp.id = p_candidate_profile_id
      and cp.is_published
      and cp.deleted_at is null
      and p.deleted_at is null
      and public.is_verified_company_member()
      and not public.are_blocked(cp.profile_id, auth.uid())
      -- Un caller borrado o suspendido por moderación no ve candidatos aunque
      -- su empresa siga verificada (hallazgo de la auditoría del bloque).
      and exists (
        select 1 from public.profiles me
        where me.id = auth.uid()
          and me.deleted_at is null
          and (me.suspended_until is null or me.suspended_until <= now())
      )
  );
$$;

revoke all on function public.company_can_view_candidate(uuid) from public;
grant execute on function public.company_can_view_candidate(uuid) to authenticated, anon;

-- La empresa pierde el SELECT directo sobre candidate_profiles (T-024):
-- desde acá solo ve la proyección de get_candidate_public_profile.
drop policy cand_visible_to_verified_companies on candidate_profiles;

-- La rama 1 de videos_company_select (videos de candidatos publicados)
-- dependía de la policy eliminada Y era en sí misma una fuga: entregaba la
-- fila COMPLETA de `videos` (con `owner_profile_id` — el id de auth del
-- candidato que este bloque decide no exponer — y `playback_url`) y permitía
-- enumerar candidatos publicados por REST. Como la reproducción para empresas
-- recién llega con el Bloque K (URLs firmadas, T-054), la rama se ELIMINA:
-- hoy la empresa solo sabe si hay presentación por el booleano de la
-- proyección. Quedan las ramas de postulaciones (a SUS ofertas) y del video
-- pitch público de una oferta activa.
drop policy videos_company_select on videos;
create policy videos_company_select on videos for select
  using (
    deleted_at is null and status = 'ready' and (
      exists (select 1 from job_applications a
              join jobs j on j.id = a.job_id
              where a.video_id = videos.id and is_company_member(j.company_id))
      or exists (select 1 from jobs j            -- video pitch de la propia oferta
                 where j.video_id = videos.id and j.status = 'active')
    )
  );

-- ---------------------------------------------------------------------------
-- Endurecimiento de helpers RLS preexistentes (hallazgos de la auditoría de
-- este bloque). PostgREST expone como RPC toda función de `public` con
-- EXECUTE para el caller, y las policies necesitan ese EXECUTE: no se pueden
-- revocar. La defensa correcta es que la función misma falle cerrada.
-- ---------------------------------------------------------------------------

-- are_blocked era un oráculo: cualquier autenticado (o anon) podía sondear el
-- estado de bloqueo entre DOS TERCEROS por /rest/v1/rpc/are_blocked. Todos
-- los usos legítimos (policies y helpers) la llaman con auth.uid() como una
-- de las partes, así que ahora exige serlo: una consulta ajena devuelve
-- false, sin filtrar nada.
create or replace function public.are_blocked(p_a uuid, p_b uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select case
    when auth.uid() is null then false
    when p_a is distinct from auth.uid() and p_b is distinct from auth.uid()
      then false
    else exists (select 1 from public.blocks
                 where (blocker_profile_id = p_a and blocked_profile_id = p_b)
                    or (blocker_profile_id = p_b and blocked_profile_id = p_a))
  end;
$$;

-- has_active_subscription filtraba el estado de suscripción de CUALQUIER
-- empresa a cualquier autenticado. Solo el propio titular, un miembro de esa
-- empresa o un admin obtienen la respuesta real.
create or replace function public.has_active_subscription(p_company_id uuid default null)
returns boolean
language sql stable security definer set search_path = '' as $$
  select case
    when p_company_id is not null
         and not public.is_company_member(p_company_id)
         and not public.is_admin()
      then false
    else exists (select 1 from public.subscriptions s
                 where s.status in ('trialing', 'active')
                   and s.current_period_end > now()
                   and ((p_company_id is not null and s.company_id = p_company_id)
                     or (p_company_id is null and s.profile_id = auth.uid())))
  end;
$$;

-- El corte por bloqueo de conversations estaba MUERTO para el lado empresa:
-- su subconsulta sobre candidate_profiles corre bajo el RLS del caller y,
-- sin la policy de lectura empresarial, siempre daba NULL (are_blocked(NULL,
-- uid) = false ⇒ la empresa leía y escribía pese al bloqueo). El lookup del
-- dueño pasa a un helper DEFINER que devuelve SOLO el booleano.
create or replace function public.blocked_with_candidate(p_candidate_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.candidate_profiles cp
    where cp.id = p_candidate_profile_id
      and public.are_blocked(cp.profile_id, auth.uid())
  );
$$;

revoke all on function public.blocked_with_candidate(uuid) from public;
grant execute on function public.blocked_with_candidate(uuid) to authenticated;

drop policy conv_participants_select on conversations;
create policy conv_participants_select on conversations for select
  using (
    (candidate_profile_id = candidate_id() or is_company_member(company_id))
    and not public.blocked_with_candidate(candidate_profile_id)
  );

-- ---------------------------------------------------------------------------
-- Preparación para postularse (T-025, la usará T-040 server-side).
-- SOLO datos mínimos legítimos: onboarding completo + los mínimos que ya
-- valida candidate_min_data_complete (identidad, mayoría de edad, zona,
-- sector, disponibilidad, modalidad). Jamás exige foto, video, educación,
-- CV ni expectativa salarial.
-- ---------------------------------------------------------------------------

create or replace function private.candidate_application_ready(p_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = p_profile_id
      and p.role = 'candidate'::public.user_role
      and p.onboarding_completed
      and p.deleted_at is null
  ) and private.candidate_min_data_complete(p_profile_id);
$$;

revoke all on function private.candidate_application_ready(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Validación de contenido del perfil (T-021), para TODOS los contextos
-- (cliente, RPC, seed): longitudes, listas sin vacíos ni duplicados,
-- estructura y fechas de work_history/education, franjas horarias sin
-- solapamientos (con cruce de medianoche bien modelado) y salario acotado.
-- ---------------------------------------------------------------------------

-- 'YYYY-MM' válido entre 1950-01 y el mes actual inclusive.
create or replace function private.is_year_month(p_value text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select p_value ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'
     and to_date(p_value || '-01', 'YYYY-MM-DD')
         between date '1950-01-01' and date_trunc('month', current_date)::date;
$$;

create or replace function private.validate_candidate_content() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  item jsonb;
  item_keys text[];
  txt text;
  from_month text;
  to_month text;
  -- Franjas horarias en minutos absolutos de la semana (0..10079); cada
  -- franja que cruza la medianoche (o el fin de semana) se parte en tramos
  -- lineales para comparar solapamientos de a pares.
  seg_starts integer[] := '{}';
  seg_ends   integer[] := '{}';
  day_index  integer;
  start_min  integer;
  end_min    integer;
  duration   integer;
  abs_start  integer;
  abs_end    integer;
  i integer;
  j integer;
  per_day integer;
begin
  -- Normalización: texto solo-espacios cuenta como vacío en todas partes.
  new.headline := nullif(btrim(coalesce(new.headline, '')), '');
  new.bio := nullif(btrim(coalesce(new.bio, '')), '');
  new.skills := coalesce(
    (select array_agg(btrim(s)) from unnest(new.skills) as s), '{}');
  new.languages := coalesce(
    (select array_agg(btrim(s)) from unnest(new.languages) as s), '{}');

  if length(coalesce(new.headline, '')) > 120 then
    raise sqlstate 'TFDAT' using message = 'El titular admite hasta 120 caracteres';
  end if;
  if length(coalesce(new.bio, '')) > 2000 then
    raise sqlstate 'TFDAT' using message = 'La biografía admite hasta 2000 caracteres';
  end if;

  if coalesce(array_length(new.skills, 1), 0) > 20 then
    raise sqlstate 'TFDAT' using message = 'Se admiten hasta 20 habilidades';
  end if;
  if exists (select 1 from unnest(new.skills) s
             where s is null or s = '' or length(s) > 40) then
    raise sqlstate 'TFDAT' using message = 'Cada habilidad debe tener entre 1 y 40 caracteres';
  end if;
  if (select count(*) from unnest(new.skills) s)
     <> (select count(distinct lower(s)) from unnest(new.skills) s) then
    raise sqlstate 'TFDAT' using message = 'Hay habilidades repetidas';
  end if;

  if coalesce(array_length(new.languages, 1), 0) > 10 then
    raise sqlstate 'TFDAT' using message = 'Se admiten hasta 10 idiomas';
  end if;
  if exists (select 1 from unnest(new.languages) s
             where s is null or s = '' or length(s) > 30) then
    raise sqlstate 'TFDAT' using message = 'Cada idioma debe tener entre 1 y 30 caracteres';
  end if;
  if (select count(*) from unnest(new.languages) s)
     <> (select count(distinct lower(s)) from unnest(new.languages) s) then
    raise sqlstate 'TFDAT' using message = 'Hay idiomas repetidos';
  end if;

  -- work_history: [{empresa, puesto, desde, hasta?, descripcion?}]
  if jsonb_typeof(new.work_history) is distinct from 'array' then
    raise sqlstate 'TFDAT' using message = 'La experiencia laboral tiene un formato inválido';
  end if;
  if jsonb_array_length(new.work_history) > 20 then
    raise sqlstate 'TFDAT' using message = 'Se admiten hasta 20 experiencias laborales';
  end if;
  for item in select value from jsonb_array_elements(new.work_history) loop
    if jsonb_typeof(item) is distinct from 'object' then
      raise sqlstate 'TFDAT' using message = 'La experiencia laboral tiene un formato inválido';
    end if;
    select array_agg(k) into item_keys from jsonb_object_keys(item) as k;
    if exists (select 1 from unnest(item_keys) k
               where k not in ('empresa', 'puesto', 'desde', 'hasta', 'descripcion')) then
      raise sqlstate 'TFDAT' using message = 'La experiencia laboral tiene campos no permitidos';
    end if;
    txt := nullif(btrim(coalesce(item->>'empresa', '')), '');
    if txt is null or length(txt) > 80 then
      raise sqlstate 'TFDAT' using message = 'Cada experiencia necesita una empresa o lugar (hasta 80 caracteres)';
    end if;
    txt := nullif(btrim(coalesce(item->>'puesto', '')), '');
    if txt is null or length(txt) > 80 then
      raise sqlstate 'TFDAT' using message = 'Cada experiencia necesita un puesto (hasta 80 caracteres)';
    end if;
    from_month := item->>'desde';
    if from_month is null or not private.is_year_month(from_month) then
      raise sqlstate 'TFDAT' using message = 'La fecha de inicio de una experiencia no es válida';
    end if;
    to_month := item->>'hasta';
    if to_month is not null then
      if not private.is_year_month(to_month) or to_month < from_month then
        raise sqlstate 'TFDAT' using message = 'La fecha de fin de una experiencia no es válida';
      end if;
    end if;
    if item ? 'descripcion' and item->>'descripcion' is not null
       and length(item->>'descripcion') > 400 then
      raise sqlstate 'TFDAT' using message = 'La descripción de una experiencia admite hasta 400 caracteres';
    end if;
  end loop;

  -- education: [{nivel, institucion, titulo?, desde?, hasta?}]
  if jsonb_typeof(new.education) is distinct from 'array' then
    raise sqlstate 'TFDAT' using message = 'La educación tiene un formato inválido';
  end if;
  if jsonb_array_length(new.education) > 10 then
    raise sqlstate 'TFDAT' using message = 'Se admiten hasta 10 entradas de educación';
  end if;
  for item in select value from jsonb_array_elements(new.education) loop
    if jsonb_typeof(item) is distinct from 'object' then
      raise sqlstate 'TFDAT' using message = 'La educación tiene un formato inválido';
    end if;
    select array_agg(k) into item_keys from jsonb_object_keys(item) as k;
    if exists (select 1 from unnest(item_keys) k
               where k not in ('nivel', 'institucion', 'titulo', 'desde', 'hasta')) then
      raise sqlstate 'TFDAT' using message = 'La educación tiene campos no permitidos';
    end if;
    if coalesce(item->>'nivel', '')
       not in ('primario', 'secundario', 'terciario', 'universitario', 'posgrado', 'curso') then
      raise sqlstate 'TFDAT' using message = 'El nivel educativo no es válido';
    end if;
    txt := nullif(btrim(coalesce(item->>'institucion', '')), '');
    if txt is null or length(txt) > 80 then
      raise sqlstate 'TFDAT' using message = 'Cada entrada de educación necesita una institución (hasta 80 caracteres)';
    end if;
    if item ? 'titulo' and item->>'titulo' is not null
       and length(item->>'titulo') > 80 then
      raise sqlstate 'TFDAT' using message = 'El título admite hasta 80 caracteres';
    end if;
    from_month := item->>'desde';
    to_month := item->>'hasta';
    if from_month is not null and not private.is_year_month(from_month) then
      raise sqlstate 'TFDAT' using message = 'La fecha de inicio de una entrada de educación no es válida';
    end if;
    if to_month is not null then
      if not private.is_year_month(to_month)
         or (from_month is not null and to_month < from_month) then
        raise sqlstate 'TFDAT' using message = 'La fecha de fin de una entrada de educación no es válida';
      end if;
    end if;
  end loop;

  -- weekly_availability: [{day, start, end}] con hasta 3 franjas por día,
  -- cruce de medianoche permitido (end < start) y sin solapamientos reales
  -- sobre la línea de tiempo de la semana (los tramos que pasan al día
  -- siguiente sí se comparan contra las franjas de ese día).
  if jsonb_typeof(new.weekly_availability) is distinct from 'array' then
    raise sqlstate 'TFDAT' using message = 'La disponibilidad horaria tiene un formato inválido';
  end if;
  if jsonb_array_length(new.weekly_availability) > 21 then
    raise sqlstate 'TFDAT' using message = 'Se admiten hasta 21 franjas horarias';
  end if;
  for item in select value from jsonb_array_elements(new.weekly_availability) loop
    if jsonb_typeof(item) is distinct from 'object' then
      raise sqlstate 'TFDAT' using message = 'La disponibilidad horaria tiene un formato inválido';
    end if;
    select array_agg(k) into item_keys from jsonb_object_keys(item) as k;
    if exists (select 1 from unnest(item_keys) k
               where k not in ('day', 'start', 'end'))
       or not (item ? 'day' and item ? 'start' and item ? 'end') then
      raise sqlstate 'TFDAT' using message = 'Cada franja horaria necesita día, inicio y fin';
    end if;
    day_index := array_position(
      array['lun', 'mar', 'mie', 'jue', 'vie', 'sab', 'dom'], item->>'day');
    if day_index is null then
      raise sqlstate 'TFDAT' using message = 'El día de una franja horaria no es válido';
    end if;
    if coalesce(item->>'start', '') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
       or coalesce(item->>'end', '') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then
      raise sqlstate 'TFDAT' using message = 'Los horarios de una franja deben tener formato HH:MM';
    end if;
    start_min := (substr(item->>'start', 1, 2))::integer * 60
                 + (substr(item->>'start', 4, 2))::integer;
    end_min := (substr(item->>'end', 1, 2))::integer * 60
               + (substr(item->>'end', 4, 2))::integer;
    if start_min = end_min then
      raise sqlstate 'TFDAT' using message = 'Una franja horaria no puede empezar y terminar a la misma hora';
    end if;
    duration := ((end_min - start_min) % 1440 + 1440) % 1440;
    abs_start := (day_index - 1) * 1440 + start_min;
    abs_end := abs_start + duration;              -- puede superar 10080 (dom→lun)
    if abs_end <= 10080 then
      seg_starts := seg_starts || abs_start;
      seg_ends := seg_ends || abs_end;
    else
      seg_starts := seg_starts || abs_start || 0;
      seg_ends := seg_ends || 10080 || (abs_end - 10080);
    end if;
  end loop;

  for day_index in 1..7 loop
    select count(*) into per_day
    from jsonb_array_elements(new.weekly_availability) e
    where e->>'day' = (array['lun', 'mar', 'mie', 'jue', 'vie', 'sab', 'dom'])[day_index];
    if per_day > 3 then
      raise sqlstate 'TFDAT' using message = 'Se admiten hasta 3 franjas por día';
    end if;
  end loop;

  if array_length(seg_starts, 1) is not null then
    for i in 1..array_length(seg_starts, 1) loop
      for j in (i + 1)..coalesce(array_length(seg_starts, 1), 0) loop
        if seg_starts[i] < seg_ends[j] and seg_starts[j] < seg_ends[i] then
          raise sqlstate 'TFDAT' using message = 'Hay franjas horarias superpuestas';
        end if;
      end loop;
    end loop;
  end if;

  -- Salario esperado: opcional, en ARS, acotado (el check salary_range de la
  -- tabla ya exige max >= min cuando ambos existen).
  if new.salary_currency is distinct from 'ARS' then
    raise sqlstate 'TFDAT' using message = 'La expectativa salarial se expresa en ARS';
  end if;
  if new.expected_salary_min is not null
     and (new.expected_salary_min < 0 or new.expected_salary_min > 999999999) then
    raise sqlstate 'TFDAT' using message = 'La expectativa salarial mínima está fuera de rango';
  end if;
  if new.expected_salary_max is not null
     and (new.expected_salary_max < 0 or new.expected_salary_max > 999999999) then
    raise sqlstate 'TFDAT' using message = 'La expectativa salarial máxima está fuera de rango';
  end if;

  return new;
end $$;

-- Nota de despliegue: esta validación NO re-normaliza filas históricas. Hoy
-- no existe ningún entorno con datos previos (solo stacks locales que nacen
-- de `db reset`); si algún día se aplica sobre una base con datos legados,
-- hay que sanearlos antes, porque una fila inválida abortaría los updates en
-- cascada de la derivación de publicación (incluido el bump de versión).
create trigger validate_candidate_content
before insert or update on candidate_profiles
for each row execute function private.validate_candidate_content();

-- ---------------------------------------------------------------------------
-- Protección de columnas frente al cliente (reemplazos).
-- ---------------------------------------------------------------------------

-- Reemplaza la versión de 0022: suma la regla de video_id — un cliente solo
-- puede vincular UN VIDEO PROPIO de presentación (o desvincularlo), nunca un
-- UUID arbitrario. La subconsulta corre bajo el RLS del caller: solo ve sus
-- propios videos.
create or replace function private.protect_candidate_profile_update() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user in ('authenticated', 'anon') and not public.is_admin() then
    if new.id is distinct from old.id
      or new.profile_id is distinct from old.profile_id
      or new.is_published is distinct from old.is_published
      or new.published_at is distinct from old.published_at
      or new.created_at is distinct from old.created_at
      or new.deleted_at is distinct from old.deleted_at
    then
      raise insufficient_privilege
        using message = 'No se pueden modificar columnas protegidas de candidate_profiles';
    end if;
    if new.video_id is distinct from old.video_id and new.video_id is not null
       and not exists (
         select 1 from public.videos v
         where v.id = new.video_id
           and v.owner_profile_id = auth.uid()
           and v.purpose = 'candidate_presentation'::public.video_purpose
           and v.deleted_at is null
       ) then
      raise insufficient_privilege
        using message = 'Solo se puede vincular un video de presentación propio';
    end if;
  end if;
  return new;
end $$;

-- Reemplaza la versión de 0022: `avatar_url` pasa a ser columna protegida —
-- la escribe únicamente la Edge Function de avatares (T-022) con el path
-- canónico; un cliente no puede apuntarla a un objeto ajeno ni a basura.
create or replace function private.protect_profile_update() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user in ('authenticated', 'anon') and not public.is_admin() and (
    new.id is distinct from old.id
    or new.role is distinct from old.role
    or new.email is distinct from old.email
    or new.avatar_url is distinct from old.avatar_url
    or new.suspended_until is distinct from old.suspended_until
    or new.onboarding_completed is distinct from old.onboarding_completed
    or new.created_at is distinct from old.created_at
    or new.deleted_at is distinct from old.deleted_at
  ) then
    raise insufficient_privilege
      using message = 'No se pueden modificar columnas protegidas de profiles';
  end if;
  return new;
end $$;

-- ---------------------------------------------------------------------------
-- RPC: leer el perfil propio (T-021/T-023/T-025).
-- Devuelve el perfil completo del dueño con nombres de catálogo resueltos,
-- estado de presentación honesto y preparación para postularse. El score de
-- completitud NO se persiste ni se calcula acá: es un cálculo puro del
-- cliente, solo visible para el dueño.
-- ---------------------------------------------------------------------------

create or replace function public.get_my_candidate_profile()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  result jsonb;
begin
  if uid is null then
    raise insufficient_privilege using message = 'Se requiere una sesión autenticada';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = uid and p.role = 'candidate'::public.user_role and p.deleted_at is null
  ) then
    raise insufficient_privilege
      using message = 'Solo un perfil de candidato puede leer este perfil';
  end if;

  select jsonb_build_object(
    'candidate_profile_id', cp.id,
    'full_name', p.full_name,
    'avatar_path', p.avatar_url,
    'headline', cp.headline,
    'bio', cp.bio,
    'provincia', case when cp.provincia_id is null then null
      else jsonb_build_object('id', gp.id, 'name', gp.name) end,
    'localidad', case when cp.localidad_id is null then null
      else jsonb_build_object('id', gl.id, 'name', gl.name) end,
    'barrio', case when cp.barrio_id is null then null
      else jsonb_build_object('id', gb.id, 'name', gb.name) end,
    'sector', case when cp.sector_id is null then null
      else jsonb_build_object('id', s.id, 'code', s.code,
                              'name', coalesce(st.name, s.code)) end,
    'availability', cp.availability,
    'work_modes', to_jsonb(cp.work_mode_prefs),
    'experience', cp.experience,
    'weekly_availability', cp.weekly_availability,
    'expected_salary_min', cp.expected_salary_min,
    'expected_salary_max', cp.expected_salary_max,
    'salary_currency', cp.salary_currency,
    'skills', to_jsonb(cp.skills),
    'languages', to_jsonb(cp.languages),
    'work_history', cp.work_history,
    'education', cp.education,
    'presentation_status', coalesce(v.status::text, 'none'),
    'is_published', cp.is_published,
    'application_ready', private.candidate_application_ready(uid)
  )
  into result
  from public.candidate_profiles cp
  join public.profiles p on p.id = cp.profile_id
  left join public.geo_provincias gp on gp.id = cp.provincia_id
  left join public.geo_localidades gl on gl.id = cp.localidad_id
  left join public.geo_barrios gb on gb.id = cp.barrio_id
  left join public.sectors s on s.id = cp.sector_id
  left join public.sector_translations st
    on st.sector_id = s.id and st.locale = 'es-AR'
  left join public.videos v on v.id = cp.video_id and v.deleted_at is null
  where cp.profile_id = uid and cp.deleted_at is null;

  if result is null then
    raise sqlstate 'TFDAT' using message = 'Faltan los datos del onboarding';
  end if;
  return result;
end $$;

revoke all on function public.get_my_candidate_profile() from public;
grant execute on function public.get_my_candidate_profile() to authenticated;

-- ---------------------------------------------------------------------------
-- RPC: editar el perfil propio (T-021).
--
-- Parche jsonb con whitelist de claves: clave PRESENTE se escribe (null =
-- limpiar explícitamente), clave AUSENTE queda intacta, clave desconocida se
-- rechaza. Se aplica en UN solo UPDATE para que los triggers de validación
-- evalúen el estado final (no estados intermedios). Idempotente por
-- construcción. Jamás acepta: role, email, profile_id, onboarding_completed,
-- is_published, published_at, deleted_at, video_id, avatar ni columnas
-- administrativas.
-- ---------------------------------------------------------------------------

create or replace function public.update_my_candidate_profile(p_patch jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  cur public.candidate_profiles%rowtype;
  allowed constant text[] := array[
    'full_name', 'headline', 'bio',
    'provincia_id', 'localidad_id', 'barrio_id', 'sector_id',
    'availability', 'work_mode_prefs', 'experience',
    'weekly_availability', 'expected_salary_min', 'expected_salary_max',
    'skills', 'languages', 'work_history', 'education'
  ];
  bad_key text;
  v_full_name text;
begin
  if uid is null then
    raise insufficient_privilege using message = 'Se requiere una sesión autenticada';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = uid and p.role = 'candidate'::public.user_role and p.deleted_at is null
  ) then
    raise insufficient_privilege
      using message = 'Solo un perfil de candidato puede editar este perfil';
  end if;
  if p_patch is null or jsonb_typeof(p_patch) is distinct from 'object' then
    raise sqlstate 'TFDAT' using message = 'El parche del perfil tiene un formato inválido';
  end if;

  select k into bad_key
  from jsonb_object_keys(p_patch) as k
  where k <> all (allowed)
  limit 1;
  if bad_key is not null then
    raise sqlstate 'TFDAT'
      using message = format('El campo %s no se puede editar desde el perfil', bad_key);
  end if;

  select * into cur
  from public.candidate_profiles cp
  where cp.profile_id = uid and cp.deleted_at is null;
  if not found then
    raise sqlstate 'TFDAT' using message = 'Faltan los datos del onboarding';
  end if;

  -- Casts con rechazo tipado: un valor de tipo equivocado es TFDAT, nunca un
  -- error interno de Postgres filtrado a la UI. Los arrays exigen elementos
  -- string (un null adentro inflaría contadores como work_mode_prefs).
  if exists (
    select 1
    from unnest(array['work_mode_prefs', 'skills', 'languages']) as arr_key
    cross join lateral jsonb_array_elements(
      case when p_patch ? arr_key
             and jsonb_typeof(p_patch->arr_key) = 'array'
           then p_patch->arr_key else '[]'::jsonb end) as e
    where jsonb_typeof(e) <> 'string'
  ) then
    raise sqlstate 'TFDAT' using message = 'El parche del perfil tiene valores inválidos';
  end if;
  if exists (
    select 1
    from unnest(array['work_mode_prefs', 'skills', 'languages',
                      'weekly_availability', 'work_history', 'education']) as arr_key
    where p_patch ? arr_key
      and jsonb_typeof(p_patch->arr_key) not in ('array', 'null')
  ) then
    raise sqlstate 'TFDAT' using message = 'El parche del perfil tiene valores inválidos';
  end if;

  begin
    if p_patch ? 'headline' then
      cur.headline := p_patch->>'headline';
    end if;
    if p_patch ? 'bio' then
      cur.bio := p_patch->>'bio';
    end if;
    if p_patch ? 'provincia_id' then
      cur.provincia_id := (p_patch->>'provincia_id')::uuid;
    end if;
    if p_patch ? 'localidad_id' then
      cur.localidad_id := (p_patch->>'localidad_id')::uuid;
    end if;
    if p_patch ? 'barrio_id' then
      cur.barrio_id := (p_patch->>'barrio_id')::uuid;
    end if;
    if p_patch ? 'sector_id' then
      cur.sector_id := (p_patch->>'sector_id')::uuid;
    end if;
    if p_patch ? 'availability' then
      cur.availability := (p_patch->>'availability')::public.availability_type;
    end if;
    if p_patch ? 'experience' then
      cur.experience := (p_patch->>'experience')::public.experience_level;
    end if;
    -- Nota: p_patch->'clave' con null devuelve jsonb 'null' (no SQL NULL);
    -- el CASE lo degrada a '[]' para que "clave: null" LIMPIE la lista en vez
    -- de reventar en jsonb_array_elements (hallazgo de la auditoría).
    if p_patch ? 'work_mode_prefs' then
      cur.work_mode_prefs := coalesce(
        (select array_agg((e #>> '{}')::public.work_mode)
         from jsonb_array_elements(
           case when jsonb_typeof(p_patch->'work_mode_prefs') = 'array'
                then p_patch->'work_mode_prefs' else '[]'::jsonb end) e),
        '{}'::public.work_mode[]);
    end if;
    if p_patch ? 'skills' then
      cur.skills := coalesce(
        (select array_agg(e #>> '{}')
         from jsonb_array_elements(
           case when jsonb_typeof(p_patch->'skills') = 'array'
                then p_patch->'skills' else '[]'::jsonb end) e),
        '{}'::text[]);
    end if;
    if p_patch ? 'languages' then
      cur.languages := coalesce(
        (select array_agg(e #>> '{}')
         from jsonb_array_elements(
           case when jsonb_typeof(p_patch->'languages') = 'array'
                then p_patch->'languages' else '[]'::jsonb end) e),
        '{}'::text[]);
    end if;
    if p_patch ? 'weekly_availability' then
      cur.weekly_availability := coalesce(p_patch->'weekly_availability', '[]'::jsonb);
      if jsonb_typeof(cur.weekly_availability) = 'null' then
        cur.weekly_availability := '[]'::jsonb;
      end if;
    end if;
    if p_patch ? 'work_history' then
      cur.work_history := coalesce(p_patch->'work_history', '[]'::jsonb);
      if jsonb_typeof(cur.work_history) = 'null' then
        cur.work_history := '[]'::jsonb;
      end if;
    end if;
    if p_patch ? 'education' then
      cur.education := coalesce(p_patch->'education', '[]'::jsonb);
      if jsonb_typeof(cur.education) = 'null' then
        cur.education := '[]'::jsonb;
      end if;
    end if;
    if p_patch ? 'expected_salary_min' then
      cur.expected_salary_min := (p_patch->>'expected_salary_min')::numeric;
    end if;
    if p_patch ? 'expected_salary_max' then
      cur.expected_salary_max := (p_patch->>'expected_salary_max')::numeric;
    end if;
  exception
    -- Bloque acotado a los casts de arriba: cualquier fallo acá es un valor
    -- malformado del cliente, jamás un error interno que haya que filtrar.
    when others then
      raise sqlstate 'TFDAT' using message = 'El parche del perfil tiene valores inválidos';
  end;

  -- Un solo UPDATE: los triggers validan el estado final completo (contenido,
  -- geografía coherente, sector activo) y recalculan la publicación.
  update public.candidate_profiles cp
  set headline = cur.headline,
      bio = cur.bio,
      provincia_id = cur.provincia_id,
      localidad_id = cur.localidad_id,
      barrio_id = cur.barrio_id,
      sector_id = cur.sector_id,
      availability = cur.availability,
      experience = cur.experience,
      work_mode_prefs = cur.work_mode_prefs,
      weekly_availability = cur.weekly_availability,
      expected_salary_min = cur.expected_salary_min,
      expected_salary_max = cur.expected_salary_max,
      skills = cur.skills,
      languages = cur.languages,
      work_history = cur.work_history,
      education = cur.education
  where cp.profile_id = uid and cp.deleted_at is null;

  if p_patch ? 'full_name' then
    v_full_name := nullif(btrim(coalesce(p_patch->>'full_name', '')), '');
    if v_full_name is null or length(v_full_name) < 2 or length(v_full_name) > 80 then
      raise sqlstate 'TFDAT'
        using message = 'El nombre debe tener entre 2 y 80 caracteres';
    end if;
    update public.profiles set full_name = v_full_name where id = uid;
  end if;
end $$;

revoke all on function public.update_my_candidate_profile(jsonb) from public;
grant execute on function public.update_my_candidate_profile(jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- RPC: proyección pública del candidato para empresas (T-024).
--
-- WHITELIST EXPLÍCITA — este es el ÚNICO camino por el que una empresa lee
-- datos de un candidato. Devuelve NULL (indistinguible de "no existe") ante
-- CUALQUIER condición fallida: caller sin empresa verificada, candidato no
-- publicado, sin consentimiento vigente (implícito en is_published), bloqueo
-- mutuo o perfil borrado. Campos que NUNCA viajan: email, teléfono,
-- birth_date, auth user id, expectativa salarial, consents, preferencias,
-- score de completitud, columnas administrativas.
-- ---------------------------------------------------------------------------

create or replace function public.get_candidate_public_profile(p_candidate_profile_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  if auth.uid() is null then
    raise insufficient_privilege using message = 'Se requiere una sesión autenticada';
  end if;
  if not public.company_can_view_candidate(p_candidate_profile_id) then
    return null;
  end if;

  select jsonb_build_object(
    'candidate_profile_id', cp.id,
    -- Nombre de pila, no el nombre completo (UX_FLOWS §6.2: minimización;
    -- el contacto completo recién se desbloquea con el match, T-045).
    'display_name', split_part(coalesce(p.full_name, ''), ' ', 1),
    'headline', cp.headline,
    'bio', cp.bio,
    'provincia', gp.name,
    'localidad', gl.name,
    'barrio', gb.name,
    'sector', case when cp.sector_id is null then null
      else coalesce(st.name, s.code) end,
    'availability', cp.availability,
    'work_modes', to_jsonb(cp.work_mode_prefs),
    'experience', cp.experience,
    'weekly_availability', cp.weekly_availability,
    'skills', to_jsonb(cp.skills),
    'languages', to_jsonb(cp.languages),
    'work_history', cp.work_history,
    'education', cp.education,
    'presentation_available', (v.id is not null and v.status = 'ready'::public.video_status),
    'avatar_path', p.avatar_url,
    'avatar_thumb_path', case when p.avatar_url is null then null
      else regexp_replace(p.avatar_url, 'avatar\.jpg$', 'thumb.jpg') end
  )
  into result
  from public.candidate_profiles cp
  join public.profiles p on p.id = cp.profile_id
  left join public.geo_provincias gp on gp.id = cp.provincia_id
  left join public.geo_localidades gl on gl.id = cp.localidad_id
  left join public.geo_barrios gb on gb.id = cp.barrio_id
  left join public.sectors s on s.id = cp.sector_id
  left join public.sector_translations st
    on st.sector_id = s.id and st.locale = 'es-AR'
  left join public.videos v on v.id = cp.video_id and v.deleted_at is null
  where cp.id = p_candidate_profile_id;

  return result;
end $$;

revoke all on function public.get_candidate_public_profile(uuid) from public;
grant execute on function public.get_candidate_public_profile(uuid) to authenticated;

revoke all on function private.is_year_month(text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Consistencia con el onboarding (hallazgo de la auditoría): el guardado del
-- wizard aceptaba un nombre de cualquier largo, mientras el perfil exige 2 a
-- 80 caracteres. Misma regla en ambos caminos (null sigue permitido: el
-- nombre recién es obligatorio al completar el onboarding).
-- ---------------------------------------------------------------------------

create or replace function public.save_candidate_onboarding(
  p_full_name text,
  p_birth_date date,
  p_provincia_id uuid,
  p_localidad_id uuid,
  p_barrio_id uuid,
  p_sector_id uuid,
  p_availability public.availability_type,
  p_work_modes public.work_mode[]
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  clean_name text := nullif(btrim(coalesce(p_full_name, '')), '');
begin
  if uid is null then
    raise insufficient_privilege using message = 'Se requiere una sesión autenticada';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = uid and p.role = 'candidate'::public.user_role and p.deleted_at is null
  ) then
    raise insufficient_privilege
      using message = 'Solo un perfil de candidato puede guardar este onboarding';
  end if;
  if clean_name is not null
     and (length(clean_name) < 2 or length(clean_name) > 80) then
    raise sqlstate 'TFDAT'
      using message = 'El nombre debe tener entre 2 y 80 caracteres';
  end if;

  update public.profiles
  set full_name = clean_name
  where id = uid;

  -- La validación de edad, geografía y sector la aplican los triggers de
  -- validación (todos los contextos), dentro de esta misma transacción.
  insert into public.candidate_profiles as cp
    (profile_id, birth_date, provincia_id, localidad_id, barrio_id,
     sector_id, availability, work_mode_prefs)
  values
    (uid, p_birth_date, p_provincia_id, p_localidad_id, p_barrio_id,
     p_sector_id, p_availability, coalesce(p_work_modes, '{}'::public.work_mode[]))
  on conflict (profile_id) do update
    set birth_date = excluded.birth_date,
        provincia_id = excluded.provincia_id,
        localidad_id = excluded.localidad_id,
        barrio_id = excluded.barrio_id,
        sector_id = excluded.sector_id,
        availability = excluded.availability,
        work_mode_prefs = excluded.work_mode_prefs;
end $$;
