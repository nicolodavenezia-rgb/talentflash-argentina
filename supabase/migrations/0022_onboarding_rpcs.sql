-- Bloque C (T-016/T-017): finalización de onboarding server-side, derivación
-- de la publicación del candidato y endurecimiento de columnas.
--
-- Convención de errores de las RPC (el cliente los traduce a mensajes es-AR y
-- jamás muestra el texto interno):
--   42501  sin permiso (rol equivocado, sesión ausente, columna protegida)
--   TF018  la persona no es mayor de 18 años
--   TFDAT  datos incompletos o inválidos (geo incoherente, sector inactivo…)
--   TFCNS  consentimientos obligatorios ausentes o de una versión vieja
--   23505  unicidad (p. ej. CUIT ya registrado)
--
-- Contextos: los triggers de PROTECCIÓN son SECURITY INVOKER y distinguen al
-- cliente por `current_user` ('authenticated'/'anon'); los de VALIDACIÓN de
-- datos son SECURITY DEFINER y aplican a todo el mundo, seed incluido.

-- ---------------------------------------------------------------------------
-- Helpers puros
-- ---------------------------------------------------------------------------

-- Mayoría de edad por fecha calendario. Quien nació un 29 de febrero cumple
-- 18 el 1 de marzo de los años no bisiestos (mismo redondeo que aplica el
-- cliente Flutter, para que ninguna de las dos capas sea más permisiva).
create or replace function private.is_adult(p_birth_date date, p_on date default current_date)
returns boolean
language sql
stable
set search_path = ''
as $$
  select case
    when p_birth_date is null then false
    else (
      p_birth_date + interval '18 years'
      + case
          when extract(day from p_birth_date + interval '18 years')
               <> extract(day from p_birth_date)
          then interval '1 day'
          else interval '0 days'
        end
    )::date <= p_on
  end;
$$;

-- ¿El último evento del ledger para este consentimiento es un otorgamiento de
-- la versión vigente? (fail-closed: sin fila vigente o versión vieja = no).
create or replace function private.consent_current(p_profile_id uuid, p_type public.consent_type)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.consent_versions cv
    join public.consents c
      on c.profile_id = p_profile_id
     and c.consent_type = cv.consent_type
     and c.seq = (
       select max(c2.seq) from public.consents c2
       where c2.profile_id = p_profile_id and c2.consent_type = cv.consent_type
     )
    where cv.consent_type = p_type
      and c.granted
      and c.version = cv.version
  );
$$;

-- ¿Están vigentes TODOS los consentimientos obligatorios? Si mañana se suma
-- un tipo obligatorio o sube una versión, esto se vuelve falso solo.
create or replace function private.mandatory_consents_current(p_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select 1
    from public.consent_versions cv
    where cv.is_mandatory
      and not private.consent_current(p_profile_id, cv.consent_type)
  );
$$;

-- Datos mínimos del candidato (T-016): nombre, nacimiento 18+, provincia,
-- localidad, barrio cuando la localidad tiene barrios cargados, sector,
-- disponibilidad y al menos una modalidad.
create or replace function private.candidate_min_data_complete(p_profile_id uuid)
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
    where cp.profile_id = p_profile_id
      and cp.deleted_at is null
      and p.deleted_at is null
      and nullif(btrim(coalesce(p.full_name, '')), '') is not null
      and private.is_adult(cp.birth_date)
      and cp.provincia_id is not null
      and cp.localidad_id is not null
      and cp.sector_id is not null
      and cp.availability is not null
      and coalesce(array_length(cp.work_mode_prefs, 1), 0) > 0
      and (
        cp.barrio_id is not null
        or not exists (
          select 1 from public.geo_barrios b where b.localidad_id = cp.localidad_id
        )
      )
  );
$$;

-- ---------------------------------------------------------------------------
-- Publicación del candidato, derivada SIEMPRE server-side (T-018).
-- is_published nunca lo decide el cliente: onboarding terminado + datos
-- mínimos + correo confirmado + consentimiento de publicación vigente.
-- ---------------------------------------------------------------------------

create or replace function private.refresh_candidate_publication(p_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  should_publish boolean;
begin
  select p.onboarding_completed
     and p.deleted_at is null
     and u.email_confirmed_at is not null
     and private.candidate_min_data_complete(p_profile_id)
     and private.consent_current(p_profile_id, 'video_profile_publication'::public.consent_type)
  into should_publish
  from public.profiles p
  join auth.users u on u.id = p.id
  where p.id = p_profile_id
    and p.role = 'candidate'::public.user_role;

  if should_publish is null then
    return;
  end if;

  update public.candidate_profiles cp
  set is_published = should_publish,
      published_at = case when should_publish then coalesce(cp.published_at, now()) end
  where cp.profile_id = p_profile_id
    and cp.is_published is distinct from should_publish;
end $$;

-- Trampolines DEFINER: recalculan la publicación cuando cambia cualquiera de
-- sus insumos. La actualización interna solo escribe cuando el valor cambia,
-- así la recursión del trigger de candidate_profiles termina en un paso.

create or replace function private.on_consent_change_refresh() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.consent_type = 'video_profile_publication'::public.consent_type then
    perform private.refresh_candidate_publication(new.profile_id);
  end if;
  return null;
end $$;

create trigger refresh_publication_on_consent
after insert on consents
for each row execute function private.on_consent_change_refresh();

create or replace function private.on_candidate_profile_change_refresh() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.refresh_candidate_publication(new.profile_id);
  return null;
end $$;

create trigger refresh_publication_on_candidate_change
after insert or update on candidate_profiles
for each row execute function private.on_candidate_profile_change_refresh();

create or replace function private.on_profile_change_refresh() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.role = 'candidate'::public.user_role then
    perform private.refresh_candidate_publication(new.id);
  end if;
  return null;
end $$;

create trigger refresh_publication_on_profile_change
after update on profiles
for each row
when (old.onboarding_completed is distinct from new.onboarding_completed
      or old.deleted_at is distinct from new.deleted_at
      or old.full_name is distinct from new.full_name)
execute function private.on_profile_change_refresh();

-- Subir la versión del texto de publicación despublica a quien aceptó la
-- versión anterior (fail-closed) hasta que vuelva a aceptar.
create or replace function private.on_consent_version_change_refresh() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  cand record;
begin
  if new.consent_type = 'video_profile_publication'::public.consent_type
     and new.version is distinct from old.version then
    for cand in select cp.profile_id from public.candidate_profiles cp loop
      perform private.refresh_candidate_publication(cand.profile_id);
    end loop;
  end if;
  return null;
end $$;

create trigger refresh_publication_on_version_change
after update on consent_versions
for each row execute function private.on_consent_version_change_refresh();

-- ---------------------------------------------------------------------------
-- Validación de datos (todos los contextos): edad, coherencia geográfica y
-- sector activo. "IDs inválidos rechazados" aunque el cliente se saltee la UI.
-- ---------------------------------------------------------------------------

create or replace function private.validate_candidate_profile() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.birth_date is not null and not private.is_adult(new.birth_date) then
    raise sqlstate 'TF018'
      using message = 'La plataforma es solo para mayores de 18 años';
  end if;
  if new.localidad_id is not null and (
    new.provincia_id is null
    or not exists (
      select 1 from public.geo_localidades l
      where l.id = new.localidad_id and l.provincia_id = new.provincia_id
    )
  ) then
    raise sqlstate 'TFDAT'
      using message = 'La localidad no pertenece a la provincia elegida';
  end if;
  if new.barrio_id is not null and (
    new.localidad_id is null
    or not exists (
      select 1 from public.geo_barrios b
      where b.id = new.barrio_id and b.localidad_id = new.localidad_id
    )
  ) then
    raise sqlstate 'TFDAT'
      using message = 'El barrio no pertenece a la localidad elegida';
  end if;
  if new.sector_id is not null and not exists (
    select 1 from public.sectors s where s.id = new.sector_id and s.is_active
  ) then
    raise sqlstate 'TFDAT'
      using message = 'El sector elegido no está disponible';
  end if;
  return new;
end $$;

create trigger validate_candidate_profile
before insert or update on candidate_profiles
for each row execute function private.validate_candidate_profile();

create or replace function private.validate_company_profile() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.localidad_id is not null and (
    new.provincia_id is null
    or not exists (
      select 1 from public.geo_localidades l
      where l.id = new.localidad_id and l.provincia_id = new.provincia_id
    )
  ) then
    raise sqlstate 'TFDAT'
      using message = 'La localidad no pertenece a la provincia elegida';
  end if;
  if new.sector_id is not null and not exists (
    select 1 from public.sectors s where s.id = new.sector_id and s.is_active
  ) then
    raise sqlstate 'TFDAT'
      using message = 'El sector elegido no está disponible';
  end if;
  return new;
end $$;

create trigger validate_company_profile
before insert or update on company_profiles
for each row execute function private.validate_company_profile();

-- ---------------------------------------------------------------------------
-- Protección de columnas frente al cliente.
-- ---------------------------------------------------------------------------

-- Reemplaza la versión de 0018: suma `onboarding_completed` (solo lo marcan
-- las RPC de finalización) y pasa de auth.role() a current_user para que las
-- funciones SECURITY DEFINER propias puedan escribirlo dentro de la misma
-- transacción; para PostgREST y pgTAP ambos valen 'authenticated'.
create or replace function private.protect_profile_update() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user in ('authenticated', 'anon') and not public.is_admin() and (
    new.id is distinct from old.id
    or new.role is distinct from old.role
    or new.email is distinct from old.email
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

-- Reemplaza la versión de 0018: la publicación es derivada, el cliente no la
-- toca ni al insertar ni al actualizar.
create or replace function private.protect_candidate_profile_update() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user in ('authenticated', 'anon') and not public.is_admin() and (
    new.id is distinct from old.id
    or new.profile_id is distinct from old.profile_id
    or new.is_published is distinct from old.is_published
    or new.published_at is distinct from old.published_at
    or new.created_at is distinct from old.created_at
    or new.deleted_at is distinct from old.deleted_at
  ) then
    raise insufficient_privilege
      using message = 'No se pueden modificar columnas protegidas de candidate_profiles';
  end if;
  return new;
end $$;

create or replace function private.protect_candidate_profile_insert() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user in ('authenticated', 'anon') and not public.is_admin()
     and (new.is_published or new.published_at is not null) then
    raise insufficient_privilege
      using message = 'La publicación del perfil se deriva server-side';
  end if;
  return new;
end $$;

create trigger protect_candidate_profile_insert
before insert on candidate_profiles
for each row execute function private.protect_candidate_profile_insert();

-- ---------------------------------------------------------------------------
-- RPC: guardar el avance del wizard de candidato (T-016).
--
-- Semántica de instantánea: cada llamada persiste el estado completo del
-- wizard (null = paso todavía sin responder). Es idempotente y transaccional;
-- si un dato es inválido (p. ej. minoría de edad) NADA de la llamada queda
-- persistido.
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

  update public.profiles
  set full_name = nullif(btrim(coalesce(p_full_name, '')), '')
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

revoke all on function public.save_candidate_onboarding(text, date, uuid, uuid, uuid, uuid, public.availability_type, public.work_mode[]) from public;
grant execute on function public.save_candidate_onboarding(text, date, uuid, uuid, uuid, uuid, public.availability_type, public.work_mode[]) to authenticated;

-- ---------------------------------------------------------------------------
-- RPC: terminar el onboarding de candidato (T-016). El cliente no puede
-- marcar onboarding_completed por su cuenta: esta función valida datos y
-- consentimientos y falla cerrada. Idempotente ante doble submit.
-- ---------------------------------------------------------------------------

create or replace function public.complete_candidate_onboarding() returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise insufficient_privilege using message = 'Se requiere una sesión autenticada';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = uid and p.role = 'candidate'::public.user_role and p.deleted_at is null
  ) then
    raise insufficient_privilege
      using message = 'Solo un perfil de candidato puede terminar este onboarding';
  end if;

  if not private.mandatory_consents_current(uid) then
    raise sqlstate 'TFCNS'
      using message = 'Faltan consentimientos obligatorios de la versión vigente';
  end if;
  if not private.candidate_min_data_complete(uid) then
    raise sqlstate 'TFDAT'
      using message = 'Faltan datos obligatorios para terminar el onboarding';
  end if;

  update public.profiles
  set onboarding_completed = true
  where id = uid and not onboarding_completed;

  perform private.refresh_candidate_publication(uid);
end $$;

revoke all on function public.complete_candidate_onboarding() from public;
grant execute on function public.complete_candidate_onboarding() to authenticated;

-- ---------------------------------------------------------------------------
-- RPC: terminar el onboarding de empresa (T-017). Crea empresa + membresía
-- owner + datos del solicitante en UNA transacción (nunca queda una empresa
-- huérfana) y es idempotente: si la persona ya es owner de una empresa, la
-- devuelve sin duplicar nada. La empresa nace SIEMPRE en verification_status
-- 'pending' (el default); aprobar es exclusivo del circuito admin (T-028).
-- ---------------------------------------------------------------------------

create or replace function public.complete_company_onboarding(
  p_legal_name text,
  p_trade_name text,
  p_cuit text,
  p_sector_id uuid,
  p_size_range text,
  p_provincia_id uuid,
  p_localidad_id uuid,
  p_website text,
  p_applicant_full_name text,
  p_applicant_position text,
  p_applicant_relationship text
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  existing_company uuid;
  new_company uuid;
  clean_cuit text;
  clean_website text;
begin
  if uid is null then
    raise insufficient_privilege using message = 'Se requiere una sesión autenticada';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = uid and p.role = 'company'::public.user_role and p.deleted_at is null
  ) then
    raise insufficient_privilege
      using message = 'Solo un perfil de empresa puede terminar este onboarding';
  end if;

  if not private.mandatory_consents_current(uid) then
    raise sqlstate 'TFCNS'
      using message = 'Faltan consentimientos obligatorios de la versión vigente';
  end if;

  -- Idempotencia: reintentos y dobles taps devuelven la empresa ya creada.
  select cm.company_id into existing_company
  from public.company_members cm
  where cm.profile_id = uid and cm.member_role = 'owner'::public.company_member_role
  order by cm.created_at
  limit 1;

  if existing_company is not null then
    update public.profiles
    set onboarding_completed = true
    where id = uid and not onboarding_completed;
    return existing_company;
  end if;

  if nullif(btrim(coalesce(p_legal_name, '')), '') is null
     or nullif(btrim(coalesce(p_trade_name, '')), '') is null
     or nullif(btrim(coalesce(p_applicant_full_name, '')), '') is null
     or nullif(btrim(coalesce(p_applicant_position, '')), '') is null then
    raise sqlstate 'TFDAT'
      using message = 'Faltan datos obligatorios de la empresa o del solicitante';
  end if;

  -- CUIT: se normaliza a XX-XXXXXXXX-X y se valida el formato aprobado (el
  -- dígito verificador y la verificación contra ARCA son T-027/T-028).
  clean_cuit := regexp_replace(coalesce(p_cuit, ''), '[^0-9]', '', 'g');
  if clean_cuit !~ '^[0-9]{11}$' then
    raise sqlstate 'TFDAT' using message = 'El CUIT debe tener 11 números';
  end if;
  clean_cuit := substr(clean_cuit, 1, 2) || '-' || substr(clean_cuit, 3, 8)
                || '-' || substr(clean_cuit, 11, 1);

  if p_sector_id is null or not exists (
    select 1 from public.sectors s where s.id = p_sector_id and s.is_active
  ) then
    raise sqlstate 'TFDAT' using message = 'El sector elegido no está disponible';
  end if;

  if coalesce(p_size_range, '') not in ('1-10', '11-50', '51-200', '201-500', '501+') then
    raise sqlstate 'TFDAT' using message = 'El tamaño de la empresa no es válido';
  end if;

  if p_provincia_id is null or p_localidad_id is null or not exists (
    select 1 from public.geo_localidades l
    where l.id = p_localidad_id and l.provincia_id = p_provincia_id
  ) then
    raise sqlstate 'TFDAT'
      using message = 'La localidad no pertenece a la provincia elegida';
  end if;

  if coalesce(p_applicant_relationship, '')
     not in ('owner', 'partner', 'manager', 'hr', 'other') then
    raise sqlstate 'TFDAT'
      using message = 'La relación del solicitante con la empresa no es válida';
  end if;

  clean_website := nullif(btrim(coalesce(p_website, '')), '');
  if clean_website is not null and clean_website !~ '^https?://[^[:space:]]+$' then
    raise sqlstate 'TFDAT' using message = 'El sitio web no parece una URL válida';
  end if;

  insert into public.company_profiles
    (name, legal_name, cuit, sector_id, size_range,
     provincia_id, localidad_id, website, created_by)
  values
    (btrim(p_trade_name), btrim(p_legal_name), clean_cuit, p_sector_id, p_size_range,
     p_provincia_id, p_localidad_id, clean_website, uid)
  returning id into new_company;

  insert into public.company_members
    (company_id, profile_id, member_role, position_title, relationship)
  values
    (new_company, uid, 'owner'::public.company_member_role,
     btrim(p_applicant_position), p_applicant_relationship);

  update public.profiles
  set full_name = btrim(p_applicant_full_name),
      onboarding_completed = true
  where id = uid;

  return new_company;
end $$;

revoke all on function public.complete_company_onboarding(text, text, text, uuid, text, uuid, uuid, text, text, text, text) from public;
grant execute on function public.complete_company_onboarding(text, text, text, uuid, text, uuid, uuid, text, text, text, text) to authenticated;

-- Los helpers privados jamás se exponen a la API.
revoke all on function private.is_adult(date, date) from public, anon, authenticated;
revoke all on function private.consent_current(uuid, public.consent_type) from public, anon, authenticated;
revoke all on function private.mandatory_consents_current(uuid) from public, anon, authenticated;
revoke all on function private.candidate_min_data_complete(uuid) from public, anon, authenticated;
revoke all on function private.refresh_candidate_publication(uuid) from public, anon, authenticated;
