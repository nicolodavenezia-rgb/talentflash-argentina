-- Bloque E — T-028: endurecimiento salido de la auditoría adversarial de 0028/0029.
--
-- Cada punto de acá corrige algo que hacía FALSA una afirmación escrita en
-- 0028, 0029 o en sus tests. Nada de esto cambia el comportamiento de la app:
-- son privilegios que ningún cliente usa, un filtro que faltaba y dos locks.

-- ---------------------------------------------------------------------------
-- 1. TRUNCATE y TRIGGER: los dos privilegios que saltean RLS.
--
-- 0018 concedió DML en bloque a `authenticated` sobre todo `public`, y con él
-- se colaron TRUNCATE y TRIGGER, que siguen ahí en 34 tablas. Los dos rompen
-- garantías que este bloque afirma tener:
--
--   - TRUNCATE no evalúa RLS ni dispara triggers FOR EACH ROW. Verificado:
--     `set local role authenticated; truncate public.admin_audit_log;` deja el
--     registro "append-only" en cero filas. Lo mismo con
--     `public.company_verifications` (0028 le revocó INSERT/UPDATE/DELETE pero
--     no TRUNCATE), con `public.company_members` y con `storage.objects`, donde
--     además esquiva las cuatro policies del bucket privado de 0029.
--
--   - TRIGGER permite colgar un trigger propio sobre una tabla ajena. Dos
--     escaladas concretas: (a) un trigger AFTER INSERT sobre
--     `company_verifications` corre DENTRO de la RPC SECURITY DEFINER, con
--     current_user = el dueño de la función, así que saltea RLS y también
--     `protect_company_profile_update`, y puede aprobar cualquier empresa;
--     (b) un trigger BEFORE UPDATE sobre `company_profiles` con un nombre
--     alfabéticamente posterior a `protect_company_profile_update` corre
--     DESPUÉS del guard —Postgres dispara los BEFORE ROW por orden de nombre—
--     y reescribe `new.verification_status` sin que nadie revalide. Eso reabre
--     exactamente el escape que 0028 declaró cerrado.
--
-- Hoy ninguna de las dos es alcanzable desde el navegador: PostgREST no emite
-- TRUNCATE ni DDL, y `authenticated` no tiene CREATE en ningún esquema. Son
-- defensa en profundidad — pero la afirmación "el escape quedó cerrado" solo es
-- cierta con esto puesto, y el costo es cero: ningún cliente los usa.
-- ---------------------------------------------------------------------------

-- Se suma REFERENCES, que tampoco usa ningún cliente: así `company_verifications`
-- queda exactamente con SELECT, que es lo único que necesita `cv_company_select`.
revoke truncate, trigger, references on all tables in schema public
  from anon, authenticated;

-- Tablas futuras: que no vuelvan a nacer con estos privilegios. Complementa el
-- `alter default privileges` que 0024 puso para service_role.
alter default privileges in schema public
  revoke truncate, trigger, references on tables from anon, authenticated;

-- LÍMITE DE PLATAFORMA, comprobado, no una omisión: en `storage.objects` y
-- `storage.buckets` estos mismos privilegios NO se pueden revocar desde una
-- migración. Las tablas son de `supabase_storage_admin`, el rol `postgres` con
-- el que corren las migraciones no es superusuario (`rolsuper = false`) y no es
-- miembro de ese rol (`set role supabase_storage_admin` → "permission denied"),
-- y un REVOKE de quien no otorgó el privilegio no hace nada. Se dejó el intento
-- afuera en vez de escribir un REVOKE decorativo que pareciera protección.
--
-- Qué acota el riesgo mientras tanto: PostgREST expone solo `public` y
-- `graphql_public` (`supabase/config.toml`), así que `storage.objects` no es
-- alcanzable con el JWT de un cliente; quien la toca es storage-api, con su
-- propio rol, y no emite TRUNCATE. El test 017 fija el estado actual: si algún
-- día la tabla cambia de dueño, el test se pone rojo y ahí sí se puede revocar.

-- ---------------------------------------------------------------------------
-- 2. La constancia de una empresa dada de baja deja de ser legible.
--
-- `can_read_company_document` (0029) resolvía el camino de "miembro" con
-- `public.is_company_member`, que es un exists pelado sobre company_members y
-- NO mira `company_profiles.deleted_at`. El camino de escritura sí lo mira,
-- porque `is_company_owner` (0028) hace el join. La asimetría dejaba a los
-- miembros de una empresa dada de baja leyendo su constancia para siempre,
-- mientras el owner ya no podía ni reemplazarla.
--
-- Se arregla acá y no en `is_company_member`, que la usan una decena de
-- policies de 0015: cambiarle la semántica desde esta migración movería cosas
-- muy lejos de T-028 sin que ningún test de este bloque lo cubra.
-- ---------------------------------------------------------------------------

create or replace function public.can_read_company_document(p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  cid uuid;
begin
  if auth.uid() is null then
    return false;
  end if;
  cid := private.company_document_path_company(p_name);
  if cid is null then
    return false;
  end if;
  if exists (
    select 1
    from public.company_members cm
    join public.company_profiles cp on cp.id = cm.company_id
    where cm.company_id = cid
      and cm.profile_id = auth.uid()
      and cp.deleted_at is null
  ) then
    return true;
  end if;
  return public.is_admin() and private.caller_is_aal2();
end $$;

-- ---------------------------------------------------------------------------
-- 3. La empresa se lee CON lock en las dos RPC que la escriben.
--
-- `request_company_verification` leía `company_profiles` sin lock y usaba ese
-- valor, sesenta líneas después, para decidir si devolvía la empresa a
-- 'pending'. Entre la lectura y la escritura está el `insert ... on conflict`,
-- que puede quedar bloqueado esperando la fila de solicitud que un admin tiene
-- tomada. Secuencia real: el owner lee 'rejected'; el admin aprueba y libera;
-- el owner despierta, crea su solicitud nueva y pisa la empresa a 'pending'
-- con un dato viejo. Resultado: empresa 'pending' con una solicitud 'approved',
-- o al revés, según quién termine último.
--
-- Con `for update` sobre `company_profiles` en las DOS funciones, las dos
-- transacciones se serializan sobre la misma fila y la segunda lee el estado
-- ya escrito por la primera. Es el mismo mecanismo que 0028 ya usaba para la
-- solicitud, aplicado también a la empresa.
--
-- Orden de locks, para que no haya deadlock: PRIMERO la empresa, DESPUÉS la
-- solicitud, en ambas funciones.
-- ---------------------------------------------------------------------------

create or replace function public.request_company_verification(
  p_cuit text,
  p_document_extension text default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  target_company uuid;
  empresa public.company_profiles%rowtype;
  clean_cuit text;
  path text;
  docs jsonb := '[]'::jsonb;
  request_id uuid;
begin
  if uid is null then
    raise insufficient_privilege using message = 'Se requiere una sesión autenticada';
  end if;

  target_company := private.caller_company();
  if not public.is_company_owner(target_company) then
    raise insufficient_privilege
      using message = 'Solo el owner de la empresa puede pedir la verificación';
  end if;

  -- Lock de la empresa ANTES de leer nada que después se use para escribirla.
  select * into empresa from public.company_profiles
  where id = target_company for update;

  if empresa.deleted_at is not null then
    raise sqlstate 'TFEMP' using message = 'La empresa no está activa';
  end if;
  if coalesce(btrim(empresa.name), '') = '' then
    raise sqlstate 'TFDAT'
      using message = 'Completá los datos de la empresa antes de pedir la verificación';
  end if;
  if empresa.verification_status = 'approved'::public.verification_status then
    raise sqlstate 'TFDAT' using message = 'Tu empresa ya está verificada';
  end if;

  clean_cuit := private.cuit_format(p_cuit);
  if clean_cuit is null then
    raise sqlstate 'TFCUI'
      using message = 'El CUIT no es válido: revisá el dígito verificador';
  end if;
  if clean_cuit is distinct from empresa.cuit then
    raise sqlstate 'TFDAT'
      using message = 'El CUIT no coincide con el que registraste al crear la empresa';
  end if;

  if p_document_extension is not null then
    path := private.company_document_path(target_company, p_document_extension);
    if path is null then
      raise sqlstate 'TFDAT'
        using message = 'La constancia tiene que ser un PDF o una imagen (jpg, png o webp)';
    end if;
    docs := jsonb_build_array(jsonb_build_object('kind', 'constancia_arca', 'path', path));
  end if;

  insert into public.company_verifications (
    company_id, status, cuit_submitted, documents, submitted_by
  ) values (
    target_company, 'pending'::public.verification_status, clean_cuit, docs, uid
  )
  on conflict (company_id)
    where status in ('pending'::public.verification_status,
                     'in_review'::public.verification_status)
  do update set
    cuit_submitted = excluded.cuit_submitted,
    documents = case when excluded.documents = '[]'::jsonb
                     then public.company_verifications.documents
                     else excluded.documents end,
    submitted_by = excluded.submitted_by,
    rejection_reason = null,
    updated_at = now()
  where public.company_verifications.status = 'pending'::public.verification_status
  returning id into request_id;

  if request_id is null then
    raise sqlstate 'TFDAT'
      using message = 'Tu solicitud ya está en revisión: esperá la respuesta';
  end if;

  -- Se relee el estado bajo el lock que ya tenemos: si un admin resolvió la
  -- empresa mientras esta transacción esperaba, el valor de `empresa` capturado
  -- arriba ya no vale para decidir.
  if (select cp.verification_status from public.company_profiles cp
      where cp.id = target_company)
     <> 'pending'::public.verification_status then
    update public.company_profiles
       set verification_status = 'pending'::public.verification_status
     where id = target_company;
  end if;

  return request_id;
end $$;

revoke all on function public.request_company_verification(text, text) from public;
grant execute on function public.request_company_verification(text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. La revisión toma el mismo lock, en el mismo orden.
--
-- Además de serializar contra el reenvío del owner, el UPDATE de la empresa
-- deja de ser incondicional: solo escribe si el estado cambia. Antes, el guard
-- de idempotencia miraba la SOLICITUD y el UPDATE de `company_profiles` se
-- aplicaba igual, así que una decisión podía pisar el estado de la empresa
-- aunque la empresa ya tuviera otro por una solicitud posterior.
-- ---------------------------------------------------------------------------

create or replace function public.admin_review_company_verification(
  p_request_id uuid,
  p_decision text,
  p_reason text default null
) returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  solicitud public.company_verifications%rowtype;
  nuevo public.verification_status;
  motivo text;
  estado_previo_empresa text;
begin
  perform private.require_verification_reviewer();

  if coalesce(p_decision, '') not in ('approved', 'rejected') then
    raise sqlstate 'TFDAT' using message = 'La decisión solo puede ser aprobar o rechazar';
  end if;
  nuevo := p_decision::public.verification_status;

  if nuevo = 'rejected'::public.verification_status then
    motivo := lower(btrim(coalesce(p_reason, '')));
    if motivo not in ('cuit_no_coincide', 'constancia_ilegible', 'constancia_vencida',
                      'datos_incompletos', 'empresa_no_operativa', 'otro') then
      raise sqlstate 'TFDAT' using message = 'El motivo de rechazo no está en la lista';
    end if;
  elsif coalesce(btrim(p_reason), '') <> '' then
    raise sqlstate 'TFDAT' using message = 'Una aprobación no lleva motivo de rechazo';
  end if;

  -- La empresa PRIMERO y la solicitud DESPUÉS: mismo orden que en
  -- `request_company_verification`, así las dos no se cruzan.
  select cp.verification_status::text into estado_previo_empresa
  from public.company_profiles cp
  where cp.id = (select cv.company_id from public.company_verifications cv
                 where cv.id = p_request_id)
  for update;

  select * into solicitud
  from public.company_verifications
  where id = p_request_id
  for update;

  if not found then
    raise sqlstate 'TFDAT' using message = 'Esa solicitud no existe';
  end if;
  if solicitud.status <> 'pending'::public.verification_status then
    raise sqlstate 'TFDAT' using message = 'Esa solicitud ya fue resuelta';
  end if;
  if public.is_company_member(solicitud.company_id) then
    raise insufficient_privilege
      using message = 'No podés revisar la verificación de una empresa que integrás';
  end if;

  update public.company_verifications
     set status = nuevo,
         reviewed_by = uid,
         reviewed_at = now(),
         rejection_reason = motivo,
         updated_at = now()
   where id = solicitud.id;

  update public.company_profiles
     set verification_status = nuevo
   where id = solicitud.company_id
     and verification_status is distinct from nuevo;

  insert into public.admin_audit_log (admin_id, action, entity_type, entity_id, before, after)
  values (
    uid,
    'company.verification.' || p_decision,
    'company_verifications',
    solicitud.id,
    jsonb_build_object(
      'company_id', solicitud.company_id,
      'request_status', solicitud.status::text,
      'company_status', estado_previo_empresa,
      'rejection_reason', solicitud.rejection_reason),
    jsonb_build_object(
      'company_id', solicitud.company_id,
      'request_status', nuevo::text,
      'company_status', nuevo::text,
      'rejection_reason', motivo)
  );

  return nuevo::text;
end $$;

revoke all on function public.admin_review_company_verification(uuid, text, text) from public;
grant execute on function public.admin_review_company_verification(uuid, text, text) to authenticated;
