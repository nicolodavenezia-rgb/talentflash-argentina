-- Bloque E — T-027: validación de CUIT con dígito verificador, server-side.
--
-- Hasta 0024 el CUIT se validaba SOLO por formato: `company_profiles.cuit`
-- tiene un `check (cuit ~ '^[0-9]{2}-?[0-9]{8}-?[0-9]$')` (0006) y
-- `complete_company_onboarding` (0022) normalizaba a XX-XXXXXXXX-X sin mirar
-- el dígito verificador — su propio comentario derivaba eso a T-027. Además
-- `create_company_with_owner` (0018) guardaba `btrim(p_cuit)` crudo, así que
-- '20-12345678-9' y '20123456789' entraban como dos filas distintas pese al
-- `unique` de la columna.
--
-- Acá el algoritmo vive en `private` (jamás expuesto a la API: 0018 revoca
-- USAGE del esquema) y se aplica por TRIGGER sobre las dos tablas que guardan
-- un CUIT. El trigger es la red de seguridad real: corre para cualquier
-- escritura, también las que no pasan por una RPC y también las de
-- `service_role`. El value object Dart repite la misma semántica solo para UX.

-- ---------------------------------------------------------------------------
-- Algoritmo módulo 11 (RG AFIP). Los helpers son inmutables y puros: no
-- consultan ARCA, no infieren titularidad y no leen ninguna tabla.
-- ---------------------------------------------------------------------------

-- Deja los 11 dígitos, o null si la entrada no tiene la forma esperada.
--
-- Admite las tres escrituras que usa la gente — '30712345671',
-- '30-71234567-1' y '30 71234567 1' — más espacios exteriores, y NADA más. El
-- separador solo puede caer donde va: '30-7123456-71' se rechaza aunque tenga
-- once dígitos, porque un separador corrido casi siempre es un dígito mal
-- tipeado y aceptarlo silenciosamente convertiría un error de carga en un CUIT
-- ajeno perfectamente válido.
--
-- Conserva los ceros iniciales porque trabaja siempre sobre texto y nunca
-- convierte el CUIT completo a número.
create or replace function private.cuit_digits(p_cuit text) returns text
language sql immutable set search_path = '' as $$
  select case
    when btrim(coalesce(p_cuit, '')) ~ '^[0-9]{2}[ -]?[0-9]{8}[ -]?[0-9]$'
      then translate(btrim(p_cuit), ' -', '')
    else null
  end;
$$;

-- Dígito verificador de los 10 primeros dígitos, con los dos resultados
-- especiales del algoritmo: 11 -> 0 y 10 -> 9. Todo entero, sin punto flotante.
create or replace function private.cuit_check_digit(p_digits text) returns int
language plpgsql immutable set search_path = '' as $$
declare
  weights constant int[] := array[5, 4, 3, 2, 7, 6, 5, 4, 3, 2];
  total int := 0;
  candidate int;
  i int;
begin
  if p_digits is null or p_digits !~ '^[0-9]{10,11}$' then
    return null;
  end if;
  for i in 1..10 loop
    total := total + (substr(p_digits, i, 1))::int * weights[i];
  end loop;
  candidate := 11 - (total % 11);
  if candidate = 11 then
    return 0;
  elsif candidate = 10 then
    return 9;
  end if;
  return candidate;
end $$;

-- Verdadero solo si hay 11 dígitos Y el verificador coincide. Fail-closed:
-- null, vacío, letras, símbolos o largo distinto devuelven false, nunca null.
create or replace function private.cuit_is_valid(p_cuit text) returns boolean
language sql immutable set search_path = '' as $$
  select coalesce(
    private.cuit_check_digit(private.cuit_digits(p_cuit))
      = (substr(private.cuit_digits(p_cuit), 11, 1))::int,
    false);
$$;

-- Forma canónica XX-XXXXXXXX-X, o null si el CUIT no es válido.
create or replace function private.cuit_format(p_cuit text) returns text
language sql immutable set search_path = '' as $$
  select case
    when private.cuit_is_valid(p_cuit)
      then substr(private.cuit_digits(p_cuit), 1, 2) || '-'
        || substr(private.cuit_digits(p_cuit), 3, 8) || '-'
        || substr(private.cuit_digits(p_cuit), 11, 1)
    else null
  end;
$$;

revoke all on function private.cuit_digits(text) from public, anon, authenticated;
revoke all on function private.cuit_check_digit(text) from public, anon, authenticated;
revoke all on function private.cuit_is_valid(text) from public, anon, authenticated;
revoke all on function private.cuit_format(text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Triggers: normalizan y validan en la propia tabla. SECURITY DEFINER porque
-- `private` no tiene USAGE para authenticated (0018) y un trigger común corre
-- con los privilegios de quien escribe.
--
-- No hay excepción para admin ni para service_role: un CUIT con dígito
-- verificador incorrecto no entra por ninguna puerta. El SQLSTATE 'TFCUI' es
-- propio y estable, para que el cliente distinga "CUIT inválido" de cualquier
-- otro rechazo sin leer el texto del mensaje.
--
-- El cortocircuito `is not distinct from old` deja pasar los UPDATE que no
-- tocan el CUIT: sin él, cualquier edición de otra columna volvería a validar
-- (y a reescribir) un valor que ya está en forma canónica.
-- ---------------------------------------------------------------------------

create or replace function private.normalize_company_cuit() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and new.cuit is not distinct from old.cuit then
    return new;
  end if;
  if private.cuit_format(new.cuit) is null then
    raise sqlstate 'TFCUI'
      using message = 'El CUIT no es válido: revisá el dígito verificador';
  end if;
  new.cuit := private.cuit_format(new.cuit);
  return new;
end $$;

create trigger normalize_company_cuit
before insert or update of cuit on public.company_profiles
for each row execute function private.normalize_company_cuit();

create or replace function private.normalize_verification_cuit() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and new.cuit_submitted is not distinct from old.cuit_submitted then
    return new;
  end if;
  if private.cuit_format(new.cuit_submitted) is null then
    raise sqlstate 'TFCUI'
      using message = 'El CUIT no es válido: revisá el dígito verificador';
  end if;
  new.cuit_submitted := private.cuit_format(new.cuit_submitted);
  return new;
end $$;

create trigger normalize_verification_cuit
before insert or update of cuit_submitted on public.company_verifications
for each row execute function private.normalize_verification_cuit();

revoke all on function private.normalize_company_cuit() from public, anon, authenticated;
revoke all on function private.normalize_verification_cuit() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Las dos RPCs que ya escribían un CUIT lo rechazan ahora con el mismo
-- SQLSTATE antes de tocar la tabla, para que el error llegue al cliente como
-- dato de formulario y no como violación opaca de trigger.
--
-- `create or replace` conserva los GRANT de 0018/0022 (precedente: 0023
-- redefine `save_candidate_onboarding` sin reponerlos).
-- ---------------------------------------------------------------------------

create or replace function public.create_company_with_owner(
  p_name text,
  p_cuit text,
  p_legal_name text default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  company_id uuid;
  clean_cuit text;
begin
  if auth.uid() is null then
    raise insufficient_privilege using message = 'Se requiere una sesión autenticada';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'company'::public.user_role and p.deleted_at is null
  ) then
    raise insufficient_privilege
      using message = 'Solo un perfil de empresa puede crear una empresa';
  end if;
  if nullif(btrim(coalesce(p_name, '')), '') is null then
    raise sqlstate 'TFDAT' using message = 'La empresa necesita un nombre';
  end if;

  clean_cuit := private.cuit_format(p_cuit);
  if clean_cuit is null then
    raise sqlstate 'TFCUI'
      using message = 'El CUIT no es válido: revisá el dígito verificador';
  end if;

  insert into public.company_profiles (name, legal_name, cuit, created_by)
  values (btrim(p_name), nullif(btrim(coalesce(p_legal_name, '')), ''),
          clean_cuit, auth.uid())
  returning id into company_id;

  insert into public.company_members (company_id, profile_id, member_role)
  values (company_id, auth.uid(), 'owner'::public.company_member_role);

  return company_id;
end $$;

-- Idéntica a la de 0022 salvo el bloque del CUIT: donde antes solo se exigían
-- 11 dígitos, ahora se exige además el dígito verificador. El resto del cuerpo
-- (idempotencia, consentimientos, sector, tamaño, geo, relación, web) queda
-- palabra por palabra como estaba.
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

  -- T-027: 11 dígitos Y dígito verificador. La verificación contra el padrón
  -- de ARCA sigue fuera de alcance (revisión humana, T-028).
  clean_cuit := private.cuit_format(p_cuit);
  if clean_cuit is null then
    raise sqlstate 'TFCUI'
      using message = 'El CUIT no es válido: revisá el dígito verificador';
  end if;

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
