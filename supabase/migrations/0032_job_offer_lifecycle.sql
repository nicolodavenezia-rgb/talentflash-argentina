-- Bloque F — T-030: CRUD de ofertas laborales del lado del servidor.
--
-- `public.jobs` existe desde 0007 y 0031 ya le puso la puerta de publicación
-- (`company_can_publish`). Lo que faltaba es todo lo demás. Hasta esta
-- migración, por PostgREST:
--
--   1. Cualquier rol del equipo escribía ofertas, `viewer` incluido.
--   2. No había máquina de estados: desde `closed` o `expired` se volvía a
--      `active`, se insertaba directo en `paused`/`closed`/`expired` y el
--      cliente podía marcar `expired` a mano.
--   3. `published_at` y `closed_at` los escribía el cliente: una empresa podía
--      "subir" su oferta en el feed reescribiendo `published_at`.
--   4. Ninguna regla de contenido: títulos vacíos o sin límite, días de trabajo
--      inventados, sueldo en cualquier moneda, geo incoherente, sector
--      inactivo, y `video_id` apuntando a CUALQUIER video —incluido el de un
--      candidato que se postuló— que `videos_company_select` publicaba.
--   5. No existía el borrado lógico: `deleted_at` estaba protegido y no había
--      ninguna puerta legítima para escribirlo.
--
-- Decisiones del fundador (2026-10-10) que esta migración aplica tal cual:
--
--   D1. El vencimiento de una oferta publicada es estrictamente futuro y está
--       como máximo a 60 días. Se controla al publicar (entrar a `active`) y al
--       editar una oferta que queda `active`. Un borrador acepta cualquier
--       `expires_at`: es incompleto por definición.
--   D2. Barrio obligatorio al publicar si la localidad tiene barrios cargados
--       (la misma regla que candidatos, 0022:109-114). Con el catálogo actual
--       equivale a CABA. En borrador es opcional; un barrio informado tiene
--       que pertenecer a la localidad siempre.
--   D3. El rol `viewer` no escribe ofertas. Crean, editan, publican, pausan,
--       cierran y descartan `owner`, `admin` y `recruiter`. El `viewer` sigue
--       VIENDO las ofertas de su empresa (`jobs_public_select` no se toca).
--
-- Queda AFUERA, a propósito:
--   - T-031: límite de ofertas activas por plan.
--   - T-032: el video pitch de la oferta. Acá solo se valida que `video_id`
--     sea un pitch de alguien de la empresa; subirlo y reproducirlo es T-032.
--   - T-033: el vencimiento automático y la renovación por pg_cron. Este
--     archivo deja la transición `-> expired` reservada al sistema y nada más.
--   - T-034: compartir la oferta y su preview pública.
--   - T-035: el feed del candidato.
--
-- Convención de errores (la traduce el cliente; nunca muestra el texto):
--   42501  sin permiso: rol que no escribe, columna que deriva el servidor,
--          transición reservada al sistema, oferta de otra empresa
--   TFJOB  NUEVO: transición de estado de la oferta no permitida (o la oferta
--          ya fue descartada, o está vencida/cerrada y no se edita)
--   TFDAT  datos inválidos o incompletos (contenido o requisitos de publicación)
--   23502 / 23514  NOT NULL y CHECK de la tabla (p. ej. sueldo ausente)

-- ===========================================================================
-- 1. Quién escribe ofertas (D3)
-- ===========================================================================
--
-- Mismo criterio que `public.is_company_member` en su definición vigente
-- (0014:10-14, nunca redefinida): un exists pelado sobre `company_members`,
-- sin mirar `company_profiles.deleted_at` — 0030:65-74 dejó esa asimetría a
-- propósito y acá no se cambia en silencio. La única diferencia es el filtro
-- de rol.
--
-- Vive en `public` y es ejecutable por `authenticated` porque la usan las
-- policies de INSERT/UPDATE y porque la app la consulta como pista de UX
-- (mostrar u ocultar "Nueva oferta"). La autoridad sigue siendo RLS: el
-- resultado de la RPC no habilita nada. Responde solo sobre `auth.uid()`, así
-- que no sirve para sondear la membresía de terceros. `anon` no la necesita
-- (las dos policies que la usan son `to authenticated`) y no la recibe.

create or replace function public.can_write_company_jobs(p_company_id uuid)
returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.company_members cm
    where cm.company_id = p_company_id
      and cm.profile_id = auth.uid()
      and cm.member_role in ('owner'::public.company_member_role,
                             'admin'::public.company_member_role,
                             'recruiter'::public.company_member_role));
$$;

comment on function public.can_write_company_jobs(uuid) is
  'Owner, admin o recruiter de ESA empresa: los roles que escriben ofertas '
  '(D3, 0032). El viewer integra el equipo pero no escribe.';

revoke all on function public.can_write_company_jobs(uuid) from public;
grant execute on function public.can_write_company_jobs(uuid) to authenticated;

-- ===========================================================================
-- 2. Policies de escritura
-- ===========================================================================
--
-- Idénticas a 0031:632-651 salvo el helper de membresía. Se recrean enteras
-- porque Postgres no deja cambiar una rama. `jobs_public_select` NO se toca:
-- el viewer sigue leyendo las ofertas de su empresa por `is_company_member`.
--
-- Efecto observable para el viewer: un INSERT termina en 42501 (falla el
-- `with check`) y un UPDATE afecta cero filas sin error (el `using` lo filtra).

drop policy if exists jobs_company_write on public.jobs;
create policy jobs_company_write on public.jobs for insert to authenticated
  with check (
    public.can_write_company_jobs(company_id)
    -- El cliente no puede firmar la oferta con el uuid de otra persona.
    and created_by = auth.uid()
    and (status <> 'active'::public.job_status
         or public.company_can_publish(company_id))
  );

drop policy if exists jobs_company_update on public.jobs;
create policy jobs_company_update on public.jobs for update to authenticated
  using (public.can_write_company_jobs(company_id))
  with check (
    -- Sobre la fila NUEVA: sin esto, `with check` hereda el `using` y un
    -- borrador podía pasar a `active` sin verificación.
    public.can_write_company_jobs(company_id)
    and (status <> 'active'::public.job_status
         or public.company_can_publish(company_id))
  );

-- ===========================================================================
-- 3. Validación de contenido (todos los contextos)
-- ===========================================================================
--
-- SECURITY DEFINER, como `validate_candidate_profile` y
-- `validate_candidate_content` (0022/0023): tiene que leer catálogos, videos
-- y membresías que el caller no ve, y `authenticated` no tiene USAGE sobre
-- `private`. Aplica al cliente, a las RPC, al seed, a service_role y al cron
-- de T-033: una oferta inválida no existe, la escriba quien la escriba.
--
-- En UPDATE valida SOLO lo que cambió. Una fila escrita antes de esta
-- migración (o antes de que cambie un límite) se puede seguir pausando,
-- cerrando o corrigiendo en otro campo sin que una regla nueva la trabe; lo
-- que no puede es volver a escribirse inválida. En INSERT valida todo.
--
-- Los NULL de columnas NOT NULL no se reportan acá: los rechaza la tabla con
-- 23502, que el cliente ya mapea a "datos inválidos". Así "publicar sin
-- sueldo" falla igual en borrador que publicada, y por la misma razón.
-- ---------------------------------------------------------------------------

-- El máximo de D1 vive en UN solo lugar. Si el fundador lo cambia, cambia acá
-- (y en la validación de UX del cliente, que es solo una pista).
create or replace function private.job_max_publication_days()
returns integer
language sql immutable set search_path = '' as $$
  select 60;
$$;

comment on function private.job_max_publication_days() is
  'Máximo de días entre ahora y el vencimiento de una oferta publicada (D1, 0032).';

revoke all on function private.job_max_publication_days() from public, anon, authenticated;

-- Recorte de los textos de la oferta, con el MISMO conjunto de espacios que
-- `String.trim()` de Dart, que es lo que usa el cliente: U+0009..U+000D,
-- U+0020, U+0085, U+00A0, U+1680, U+2000..U+200A, U+2028, U+2029, U+202F,
-- U+205F, U+3000 y U+FEFF. `btrim(x)` sin segundo argumento solo saca U+0020,
-- así que un título hecho de tabulaciones, saltos de línea o espacios no
-- separables pasaba como "no vacío" y se publicaba en blanco. Vive en UN solo
-- lugar: título, descripción, detalle de horario y cada beneficio pasan por
-- acá. Con `E''` (y no `U&''`) el literal no depende de
-- `standard_conforming_strings`; la segunda línea es continuación del mismo
-- literal (comilla sola tras un salto de línea) y hereda sus escapes.
create or replace function private.job_trim(p_text text)
returns text
language sql immutable set search_path = '' as $$
  select pg_catalog.btrim(
    p_text,
    E'\t\n\u000B\f\r \u0085\u00A0\u1680\u2000\u2001\u2002\u2003\u2004\u2005'
     '\u2006\u2007\u2008\u2009\u200A\u2028\u2029\u202F\u205F\u3000\uFEFF');
$$;

comment on function private.job_trim(text) is
  'btrim con los espacios de String.trim() de Dart (Unicode White_Space + BOM): '
  'el recorte de los textos de jobs (0032).';

revoke all on function private.job_trim(text) from public, anon, authenticated;

create or replace function private.validate_job_content() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  -- En UPDATE es la fila vieja; en INSERT queda con todos sus campos en NULL,
  -- así que "cambió" equivale a "vino informado" y el INSERT se valida entero
  -- con las mismas comparaciones. (Leer `old` en un INSERT es justamente lo
  -- que 0026 evita con ramas por `tg_op`.)
  prev public.jobs;
  publishing boolean;
  max_days integer := private.job_max_publication_days();
begin
  if tg_op = 'UPDATE' then
    prev := old;
  end if;

  -- Textos: se normalizan (sin espacios en los bordes) antes de medir, igual
  -- que el perfil del candidato (0023:241-247), y se guardan recortados. El
  -- recorte es `private.job_trim` (el de `String.trim()` del cliente): un
  -- texto hecho solo de espacios, tabulaciones, saltos de línea o espacios
  -- Unicode cuenta como vacío.
  if new.title is distinct from prev.title and new.title is not null then
    new.title := private.job_trim(new.title);
    if new.title = '' then
      raise sqlstate 'TFDAT' using message = 'El puesto de la oferta no puede quedar vacío';
    end if;
    if length(new.title) > 120 then
      raise sqlstate 'TFDAT' using message = 'El puesto admite hasta 120 caracteres';
    end if;
  end if;

  if new.description is distinct from prev.description and new.description is not null then
    new.description := private.job_trim(new.description);
    if new.description = '' then
      raise sqlstate 'TFDAT' using message = 'La descripción de la oferta no puede quedar vacía';
    end if;
    if length(new.description) > 4000 then
      raise sqlstate 'TFDAT' using message = 'La descripción admite hasta 4000 caracteres';
    end if;
  end if;

  if new.schedule_detail is distinct from prev.schedule_detail
     and new.schedule_detail is not null then
    new.schedule_detail := private.job_trim(new.schedule_detail);
    if new.schedule_detail = '' then
      raise sqlstate 'TFDAT' using message = 'El detalle del horario no puede quedar vacío';
    end if;
    if length(new.schedule_detail) > 200 then
      raise sqlstate 'TFDAT' using message = 'El detalle del horario admite hasta 200 caracteres';
    end if;
  end if;

  -- Días de trabajo: lista plana de 1 a 7 códigos distintos, con el mismo
  -- vocabulario que las franjas del candidato (0023:381-385). Un arreglo
  -- vacío pasaba el NOT NULL y dejaba la oferta sin días.
  if new.schedule_days is distinct from prev.schedule_days
     and new.schedule_days is not null then
    if coalesce(array_ndims(new.schedule_days), 0) <> 1
       or cardinality(new.schedule_days) > 7 then
      raise sqlstate 'TFDAT' using message = 'La oferta necesita entre 1 y 7 días de trabajo';
    end if;
    if exists (
      select 1 from unnest(new.schedule_days) d
      where d is null
         or array_position(array['lun', 'mar', 'mie', 'jue', 'vie', 'sab', 'dom'], d) is null
    ) then
      raise sqlstate 'TFDAT' using message = 'Los días de trabajo van de lun a dom';
    end if;
    if (select count(*) from unnest(new.schedule_days) d)
       <> (select count(distinct d) from unnest(new.schedule_days) d) then
      raise sqlstate 'TFDAT' using message = 'Hay días de trabajo repetidos';
    end if;
  end if;

  -- Sueldo: en ARS (UX_FLOWS §5) y con el mismo techo que la expectativa del
  -- candidato (0023:433-440). `salary_min >= 0` y `salary_max >= salary_min`
  -- ya son CHECK de la tabla (0007), así que el techo de `salary_max` acota
  -- también a `salary_min`.
  if new.salary_currency is distinct from prev.salary_currency
     and new.salary_currency is not null
     and new.salary_currency <> 'ARS' then
    raise sqlstate 'TFDAT' using message = 'El sueldo de la oferta se expresa en ARS';
  end if;
  if new.salary_max is distinct from prev.salary_max and new.salary_max > 999999999 then
    raise sqlstate 'TFDAT' using message = 'El sueldo máximo está fuera de rango';
  end if;

  -- Beneficios: texto libre (no hay catálogo), acotado como las habilidades
  -- del candidato. Cada uno se recorta con `private.job_trim`; "repetido"
  -- ignora mayúsculas y esos mismos espacios en los bordes.
  if new.benefits is distinct from prev.benefits and new.benefits is not null then
    if array_ndims(new.benefits) > 1
       or exists (select 1 from unnest(new.benefits) b where b is null) then
      raise sqlstate 'TFDAT' using message = 'Los beneficios tienen un formato inválido';
    end if;
    new.benefits := coalesce(
      (select array_agg(private.job_trim(b) order by n)
       from unnest(new.benefits) with ordinality as u(b, n)),
      '{}');
    if cardinality(new.benefits) > 15 then
      raise sqlstate 'TFDAT' using message = 'Se admiten hasta 15 beneficios';
    end if;
    if exists (select 1 from unnest(new.benefits) b where b = '' or length(b) > 60) then
      raise sqlstate 'TFDAT' using message = 'Cada beneficio debe tener entre 1 y 60 caracteres';
    end if;
    if (select count(*) from unnest(new.benefits) b)
       <> (select count(distinct lower(b)) from unnest(new.benefits) b) then
      raise sqlstate 'TFDAT' using message = 'Hay beneficios repetidos';
    end if;
  end if;

  -- `vacancies > 0` ya es CHECK de la tabla; esto pone el techo.
  if new.vacancies is distinct from prev.vacancies and new.vacancies > 100 then
    raise sqlstate 'TFDAT' using message = 'Se admiten hasta 100 vacantes';
  end if;

  -- Geo coherente: mismo criterio que candidatos y empresas (0022:247-266).
  -- Se revalida si cambia CUALQUIERA de las tres columnas, porque mover solo la
  -- localidad puede dejar huérfano un barrio que antes era válido.
  if new.provincia_id is distinct from prev.provincia_id
     or new.localidad_id is distinct from prev.localidad_id
     or new.barrio_id is distinct from prev.barrio_id then
    if new.localidad_id is not null and new.provincia_id is not null and not exists (
      select 1 from public.geo_localidades l
      where l.id = new.localidad_id and l.provincia_id = new.provincia_id
    ) then
      raise sqlstate 'TFDAT'
        using message = 'La localidad no pertenece a la provincia elegida';
    end if;
    if new.barrio_id is not null and new.localidad_id is not null and not exists (
      select 1 from public.geo_barrios b
      where b.id = new.barrio_id and b.localidad_id = new.localidad_id
    ) then
      raise sqlstate 'TFDAT'
        using message = 'El barrio no pertenece a la localidad elegida';
    end if;
  end if;

  -- Sector opcional, pero si viene tiene que existir y estar activo
  -- (0022:267-272). Va antes que la FK, que recién se evalúa al final de la
  -- sentencia: así un id inexistente también es TFDAT y no 23503.
  if new.sector_id is not null and new.sector_id is distinct from prev.sector_id
     and not exists (
       select 1 from public.sectors s where s.id = new.sector_id and s.is_active
     ) then
    raise sqlstate 'TFDAT' using message = 'El sector elegido no está disponible';
  end if;

  -- Video de la oferta: cierra la fuga de `videos_company_select` (0031:776-780).
  -- Esa rama publica la fila COMPLETA de cualquier video referenciado por una
  -- oferta activa, y la empresa ve los `video_id` de las postulaciones a sus
  -- ofertas (rama 1 de la misma policy). Sin esta regla, apuntar `video_id` al
  -- video de un postulante lo exponía —con `owner_profile_id` y `playback_url`—
  -- a cualquier sesión. Ahora solo entra un pitch (`job_pitch`) vivo cuyo
  -- dueño integra la empresa de la oferta. Se revalida también si cambia
  -- `company_id` (solo el backend puede, por `protect_job_write`): el dueño
  -- tiene que ser de la empresa de la oferta, no de la anterior.
  if new.video_id is not null
     and (new.video_id is distinct from prev.video_id
          or new.company_id is distinct from prev.company_id)
     and not exists (
       select 1
       from public.videos v
       where v.id = new.video_id
         and v.deleted_at is null
         and v.purpose = 'job_pitch'::public.video_purpose
         and exists (
           select 1 from public.company_members cm
           where cm.company_id = new.company_id
             and cm.profile_id = v.owner_profile_id)
     ) then
    raise sqlstate 'TFDAT'
      using message = 'El video de la oferta tiene que ser un pitch de alguien de la empresa';
  end if;

  -- Requisitos para PUBLICAR. Se evalúan al entrar a `active` (INSERT ya
  -- activa, o UPDATE desde otro estado, incluido reanudar una pausada) y al
  -- editar una activa en los campos que los afectan. Editar el título de una
  -- activa no los vuelve a pedir.
  publishing := coalesce(
    new.status = 'active'::public.job_status
    and (prev.status is distinct from 'active'::public.job_status
         or new.salary_min is distinct from prev.salary_min
         or new.expires_at is distinct from prev.expires_at
         or new.localidad_id is distinct from prev.localidad_id
         or new.barrio_id is distinct from prev.barrio_id),
    false);

  if publishing then
    -- "Publicar sin sueldo falla server-side" (ROADMAP T-030). El NULL ya lo
    -- corta la tabla; el cero es el sueldo vacío que el NOT NULL no ve.
    if new.salary_min is not null and new.salary_min <= 0 then
      raise sqlstate 'TFDAT'
        using message = 'Para publicar, la oferta necesita un sueldo mayor a cero';
    end if;
    -- D1. `now()` es el inicio de la transacción: el rango se mide contra el
    -- mismo instante en toda la sentencia.
    if new.expires_at is not null and new.expires_at <= now() then
      raise sqlstate 'TFDAT'
        using message = 'Para publicar, el vencimiento tiene que ser una fecha futura';
    end if;
    -- El tope se suma en HORAS exactas (60 × 24 = 1440 h, lo mismo que
    -- `Duration(days: 60)` del cliente), no en días: sumar `days` a un
    -- timestamptz es aritmética de calendario en el TimeZone de la sesión, que
    -- un cliente de PostgREST elige (`Prefer: timezone`), y si en la ventana
    -- cae un cambio de horario "60 días" son 1439 o 1441 h. En horas, el borde
    -- es el mismo instante en cualquier zona.
    if new.expires_at is not null
       and new.expires_at > now() + make_interval(hours => max_days * 24) then
      raise sqlstate 'TFDAT'
        using message = format('Una oferta se publica por un máximo de %s días', max_days);
    end if;
    -- D2. "La localidad tiene barrios cargados" se mira en el catálogo, no en
    -- una lista de localidades: cuando se carguen barrios de otra localidad,
    -- la regla la alcanza sola.
    if new.barrio_id is null and new.localidad_id is not null and exists (
      select 1 from public.geo_barrios b where b.localidad_id = new.localidad_id
    ) then
      raise sqlstate 'TFDAT'
        using message = 'En esta localidad, para publicar hace falta elegir el barrio';
    end if;
  end if;

  return new;
end $$;

comment on function private.validate_job_content() is
  'Contenido y requisitos de publicación de jobs, en todos los contextos '
  '(cliente, RPC, seed, service_role, cron). En UPDATE valida solo lo que '
  'cambió (0032).';

revoke all on function private.validate_job_content() from public, anon, authenticated;

drop trigger if exists validate_job_content on public.jobs;
create trigger validate_job_content
before insert or update on public.jobs
for each row execute function private.validate_job_content();

-- ===========================================================================
-- 4. Ciclo de vida de la oferta frente al cliente
-- ===========================================================================
--
-- Máquina de estados (UX_FLOWS §5): borrador -> activa -> (pausada <-> activa)
-- -> cerrada, y vencida solo por el sistema (T-033). Para el CLIENTE:
--
--   INSERT    nace `draft` o `active` (publicar de una, si la empresa puede).
--   UPDATE    mismo estado en draft/active/paused (edición de contenido), y
--             draft->active, active->paused, paused->active, active->closed,
--             paused->closed, expired->closed. Nada más.
--   `-> expired` es 42501: lo hace el sistema, no la empresa.
--   `expired` y `closed` son historia: no se editan. La única salida es
--             expired->closed, sin tocar ninguna otra columna.
--   Una oferta descartada (`deleted_at`) no se toca más.
--
-- Columnas que deriva el servidor y el cliente no escribe nunca:
--   `published_at` lo fija draft->active. paused->active lo CONSERVA: si
--     pausar y reanudar lo renovara, una empresa podría volver al tope del feed
--     (ordenado por `published_at desc`, 0013:22) cuando quisiera.
--   `closed_at` lo fija cualquier `-> closed`.
--   `deleted_at` lo escribe solo `discard_job_draft` (sección 6).
--   `created_at`/`updated_at` del INSERT los pone el servidor (el cliente
--     podía antedatar la oferta y alterar `idx_jobs_created`).
--
-- PROTECTOR, no validador: SECURITY INVOKER y gateado por `current_user`, el
-- patrón de 0022/0026:61-66. Para PostgREST y pgTAP `current_user` es
-- 'authenticated'; dentro de una RPC SECURITY DEFINER del proyecto es el dueño
-- de la función, y también lo es para el seed, service_role y pg_cron, que
-- pasan de largo. Es exactamente lo que hace falta: `discard_job_draft` tiene
-- que poder escribir `deleted_at`, y el cron de T-033 tiene que poder vencer.
--
-- AUTOCONTENIDO a propósito: corre con los permisos del cliente, que no tiene
-- USAGE sobre `private`, así que no llama a ningún helper de ese esquema ni lee
-- tablas. Todo lo que decide sale de `old`, `new` y `now()`.
--
-- Corre ANTES que el validador (los BEFORE ROW se disparan por orden de
-- nombre: protect_job_lifecycle, protect_job_write, set_updated_at,
-- validate_job_content), así que el validador ve las columnas ya derivadas.

create or replace function private.protect_job_lifecycle() returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  resto public.jobs;
  transicion text;
begin
  if current_user not in ('authenticated', 'anon') then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.status not in ('draft'::public.job_status, 'active'::public.job_status) then
      raise sqlstate 'TFJOB'
        using message = 'Una oferta nueva nace como borrador o publicada';
    end if;
    if new.published_at is not null
       or new.closed_at is not null
       or new.deleted_at is not null then
      raise insufficient_privilege
        using message = 'Las fechas de publicación, cierre y descarte las pone el servidor';
    end if;
    new.created_at := now();
    new.updated_at := now();
    new.published_at := case
      when new.status = 'active'::public.job_status then now()
    end;
    return new;
  end if;

  -- UPDATE.
  if old.deleted_at is not null then
    raise sqlstate 'TFJOB' using message = 'La oferta fue descartada';
  end if;

  if new.id is distinct from old.id
     or new.published_at is distinct from old.published_at
     or new.closed_at is distinct from old.closed_at
     or new.deleted_at is distinct from old.deleted_at then
    raise insufficient_privilege
      using message = 'No se pueden modificar columnas protegidas de jobs';
  end if;

  if new.status = 'expired'::public.job_status
     and old.status <> 'expired'::public.job_status then
    raise insufficient_privilege
      using message = 'Solo el sistema vence una oferta';
  end if;

  if old.status in ('expired'::public.job_status, 'closed'::public.job_status) then
    -- La fila nueva, con lo que expired->closed SÍ cambia igualado a la vieja:
    -- si queda distinta, se tocó algo más. Copiar la fila entera (en vez de
    -- listar columnas) cubre también las columnas que se agreguen mañana.
    resto := new;
    resto.status := old.status;
    resto.closed_at := old.closed_at;
    resto.updated_at := old.updated_at;
    if not (old.status = 'expired'::public.job_status
            and new.status = 'closed'::public.job_status)
       or resto is distinct from old then
      raise sqlstate 'TFJOB'
        using message = 'Una oferta vencida o cerrada no se edita';
    end if;
  elsif new.status is distinct from old.status then
    transicion := format('%s->%s', old.status, new.status);
    if transicion not in ('draft->active', 'active->paused', 'paused->active',
                          'active->closed', 'paused->closed') then
      raise sqlstate 'TFJOB'
        using message = 'Esa transición de estado de la oferta no está permitida';
    end if;
  end if;

  if old.status = 'draft'::public.job_status
     and new.status = 'active'::public.job_status then
    new.published_at := now();
  end if;
  if new.status = 'closed'::public.job_status
     and old.status <> 'closed'::public.job_status then
    new.closed_at := now();
  end if;

  return new;
end $$;

comment on function private.protect_job_lifecycle() is
  'Máquina de estados de la oferta y columnas derivadas frente al cliente '
  '(current_user authenticated/anon). Autocontenida: no lee tablas (0032).';

-- El trigger no necesita EXECUTE del caller para dispararse (igual que
-- `protect_job_write` en 0031:730).
revoke all on function private.protect_job_lifecycle() from public, anon, authenticated;

drop trigger if exists protect_job_lifecycle on public.jobs;
create trigger protect_job_lifecycle
before insert or update on public.jobs
for each row execute function private.protect_job_lifecycle();

comment on trigger protect_job_lifecycle on public.jobs is
  'Transiciones permitidas al cliente y derivación de published_at/closed_at (T-030).';

comment on trigger validate_job_content on public.jobs is
  'Contenido y requisitos de publicación (D1, D2, video pitch) en todos los contextos (T-030).';

-- ===========================================================================
-- 5. Fin de `protect_job_update` (0018)
-- ===========================================================================
--
-- Su cobertura queda repartida, y ninguna de las dos mitades tiene escape:
--
--   - `id` y `deleted_at`              -> `protect_job_lifecycle` (sección 4)
--   - `company_id`, `created_by`, `created_at` -> `protect_job_write` (0031)
--
-- Esto cierra el escape `and not public.is_admin()` que 0031:677-689 dejó
-- abierto para T-030: con él, una cuenta que fuera admin de plataforma Y
-- miembro de una empresa podía reescribir `id` o `deleted_at` de una oferta
-- suya por PostgREST. Es el mismo agujero que 0028 le cerró a
-- `protect_company_profile_update`. La moderación de T-077 no lo necesita:
-- correrá como RPC SECURITY DEFINER o como backend, y ahí `current_user` no es
-- 'authenticated'.
--
-- Además gateaba con `auth.role()`, que dentro de una RPC SECURITY DEFINER
-- sigue diciendo 'authenticated': habría bloqueado a `discard_job_draft`
-- (0026:61-66 explica por qué los otros protectores pasaron a `current_user`).
--
-- Nada más lo usa (grep en migraciones, tests y scripts).

drop trigger if exists protect_job_update on public.jobs;
drop function if exists private.protect_job_update();

-- ===========================================================================
-- 6. Descartar un borrador (la D del CRUD, borrado lógico)
-- ===========================================================================
--
-- Solo borradores: una oferta que estuvo publicada tiene postulaciones,
-- conversaciones e historia (DATA_MODEL §7: las ofertas `closed`/`expired` se
-- conservan) y se CIERRA, no se borra.
-- No hay DELETE físico: `jobs` sigue sin policy de DELETE, y un borrado físico
-- arrastraría en cascada postulaciones, invitaciones y matches (0008).
--
-- 42501 tanto si la oferta no existe como si es de otra empresa: el endpoint
-- no sirve para averiguar qué ids existen. TFJOB cuando la oferta es del
-- caller pero ya no es un borrador vigente.
--
-- El `for update` serializa dos descartes simultáneos (doble tap) y un
-- descarte contra una publicación en curso de la misma oferta: el segundo ve
-- el estado que dejó el primero.

create or replace function public.discard_job_draft(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  target public.jobs;
begin
  if uid is null then
    raise insufficient_privilege using message = 'Se requiere una sesión autenticada';
  end if;

  select j.* into target
  from public.jobs j
  where j.id = p_job_id
  for update;

  if target.id is null or not public.can_write_company_jobs(target.company_id) then
    raise insufficient_privilege
      using message = 'No podés descartar esta oferta';
  end if;

  if target.deleted_at is not null
     or target.status <> 'draft'::public.job_status then
    raise sqlstate 'TFJOB'
      using message = 'Solo se puede descartar un borrador que no haya sido descartado';
  end if;

  -- Adentro de esta función `current_user` es el dueño, así que
  -- `protect_job_lifecycle` no se aplica y `deleted_at` se puede escribir.
  -- `protect_job_write` sí corre (lee el JWT) y no objeta: no cambia ninguna
  -- de sus columnas.
  update public.jobs j
  set deleted_at = now()
  where j.id = target.id;
end $$;

comment on function public.discard_job_draft(uuid) is
  'Borrado lógico de un borrador propio (owner/admin/recruiter). 42501 si no '
  'existe o es ajeno; TFJOB si no es un borrador vigente (0032).';

revoke all on function public.discard_job_draft(uuid) from public;
grant execute on function public.discard_job_draft(uuid) to authenticated;
