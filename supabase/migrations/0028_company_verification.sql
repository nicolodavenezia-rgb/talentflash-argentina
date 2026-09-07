-- Bloque E — T-028: verificación manual de empresa (solicitud + cola admin).
--
-- El circuito completo: el owner de una empresa manda su CUIT y la constancia
-- de ARCA, una persona del equipo la revisa desde el panel y la decisión mueve
-- `company_profiles.verification_status`. Todo pasa por RPCs SECURITY DEFINER:
-- ni la solicitud ni la revisión son escrituras directas del cliente.
--
-- Lo que se arregla acá, además del circuito nuevo:
--
--   1. `company_verifications` era superficie de API. 0015 le dio
--      `cv_company_insert` (cualquier MIEMBRO, no solo el owner) y
--      `cv_admin_update` (`using (is_admin())`, sin `with check`, así que un
--      admin podía además mover la fila a otra empresa). 0018 le concedió DML
--      a `authenticated` junto con el resto de `public`. Queda sin ninguna
--      escritura directa, como `company_invitations` en 0027.
--
--   2. `protect_company_profile_update` (0026:75) dejaba pasar cualquier
--      escritura de columna protegida si `public.is_admin()`. El comentario de
--      0026 lo justificaba con "hay una RPC de admin (T-028) que TIENE que
--      poder escribir una columna protegida", pero esa RPC es SECURITY
--      DEFINER: adentro `current_user` es el dueño de la función, no
--      'authenticated', así que la guarda nunca se le aplica. El escape era
--      entonces innecesario Y explotable: una cuenta que fuera a la vez admin
--      de plataforma y owner de una empresa pasaba `comp_member_update`
--      (0015:40) y podía escribir `verification_status = 'approved'` sobre su
--      propia empresa por PostgREST, sin AAL2, sin motivo y sin auditoría.
--      Se quita el escape; el test 017 comprueba las dos mitades (la RPC sigue
--      pudiendo escribir, el cliente no).
--
-- AAL2: la revisión exige segundo factor. En SQL el nivel se lee del claim
-- `aal` del JWT (`request.jwt.claims`), no de una tabla, porque es una
-- propiedad de LA SESIÓN y no de la cuenta. Es el primer uso de `aal` del
-- repositorio; ver el README y `supabase/config.toml` ([auth.mfa.totp]).

-- ---------------------------------------------------------------------------
-- 1. Lectura defensiva del JWT.
--
-- `current_setting('request.jwt.claims', true)` puede venir NULL (conexión sin
-- PostgREST, job de pg_cron) o con algo que no es JSON. Castear directo
-- levantaría un error 22P02 en medio de una policy y convertiría "no sé el
-- nivel" en "explota", que no es fail-closed: es fail-ruidoso. Acá cualquier
-- cosa rara colapsa a '{}'::jsonb y de ahí el nivel sale NULL → no es aal2.
-- ---------------------------------------------------------------------------

create or replace function private.caller_jwt() returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  raw text;
begin
  raw := current_setting('request.jwt.claims', true);
  if raw is null or btrim(raw) = '' then
    return '{}'::jsonb;
  end if;
  begin
    return raw::jsonb;
  exception when others then
    return '{}'::jsonb;
  end;
end $$;

-- Comparación EXACTA contra 'aal2'. Sin lower(), sin trim y sin prefijos: un
-- claim 'AAL2', 'aal2 ' o 'aal3' no es el valor que emite GoTrue y tratarlo
-- como válido sería aceptar un token que no produjo este backend. El
-- `coalesce` final es la parte que importa: `null = 'aal2'` es NULL, y un NULL
-- en un `if not ...` NO entra en la rama — sin el coalesce, un claim ausente
-- sería fail-OPEN.
create or replace function private.caller_is_aal2() returns boolean
language sql stable set search_path = '' as $$
  select coalesce(private.caller_jwt() ->> 'aal' = 'aal2', false);
$$;

revoke all on function private.caller_jwt() from public, anon, authenticated;
revoke all on function private.caller_is_aal2() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Puerta única de la revisión administrativa.
--
-- Orden deliberado: sesión → rol → segundo factor. Quien no es admin recibe
-- 42501 y jamás llega a enterarse de que existe un requisito de AAL2, así que
-- el endpoint no sirve para descubrir quién es admin. El SQLSTATE 'TFMFA' es
-- propio y estable para que el panel pueda decir "activá el segundo factor"
-- sin leer el texto del mensaje.
-- ---------------------------------------------------------------------------

create or replace function private.require_verification_reviewer() returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise insufficient_privilege using message = 'Se requiere una sesión autenticada';
  end if;
  if not public.is_admin() then
    raise insufficient_privilege
      using message = 'Solo el equipo de TalentFlash puede revisar verificaciones';
  end if;
  if not private.caller_is_aal2() then
    raise sqlstate 'TFMFA'
      using message = 'Para revisar verificaciones necesitás iniciar sesión con segundo factor';
  end if;
end $$;

revoke all on function private.require_verification_reviewer() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Cierre del escape de admin en el protector de company_profiles.
--
-- Idéntica a 0026:75 salvo por la desaparición de `and not public.is_admin()`.
-- Las RPCs SECURITY DEFINER de más abajo siguen pudiendo escribir
-- `verification_status` porque adentro `current_user` es el dueño de la
-- función y la guarda solo mira 'authenticated'/'anon'.
-- ---------------------------------------------------------------------------

create or replace function private.protect_company_profile_update() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user in ('authenticated', 'anon') and (
    new.id is distinct from old.id
    or new.cuit is distinct from old.cuit
    or new.verification_status is distinct from old.verification_status
    or new.created_by is distinct from old.created_by
    or new.created_at is distinct from old.created_at
    or new.deleted_at is distinct from old.deleted_at
    or new.logo_url is distinct from old.logo_url
  ) then
    raise insufficient_privilege
      using message = 'No se pueden modificar columnas protegidas de company_profiles';
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. `company_verifications` deja de ser superficie de API.
--
-- Se conserva el SELECT (la empresa consulta su propio estado y el admin la
-- cola), acotado a `authenticated`: `anon` no tiene nada que hacer acá y una
-- policy sin `to` alcanza también al rol anónimo.
-- ---------------------------------------------------------------------------

drop policy if exists cv_company_insert on public.company_verifications;
drop policy if exists cv_admin_update on public.company_verifications;
drop policy if exists cv_company_select on public.company_verifications;

create policy cv_company_select on public.company_verifications for select to authenticated
  using (public.is_company_member(company_id) or public.is_admin());

revoke insert, update, delete on public.company_verifications from anon, authenticated;

-- Una sola solicitud abierta por empresa. Es lo que hace atómico el reintento
-- del formulario: el segundo envío choca con el índice y se resuelve como
-- UPDATE en la misma sentencia, sin ventana de carrera entre el SELECT y el
-- INSERT.
create unique index if not exists ux_company_verifications_open
  on public.company_verifications(company_id)
  where status in ('pending'::public.verification_status,
                   'in_review'::public.verification_status);

-- ---------------------------------------------------------------------------
-- 5. Helpers de autoridad reutilizables.
-- ---------------------------------------------------------------------------

-- 0026 dejó `is_company_manager` (owner O admin de empresa). La verificación
-- la firma el owner y nadie más, así que hace falta el estricto; hasta ahora
-- eso se escribía inline comparando `private.caller_member_role()`, que no
-- sirve acá porque no recibe la empresa.
create or replace function public.is_company_owner(p_company_id uuid)
returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.company_members cm
    join public.company_profiles cp on cp.id = cm.company_id
    where cm.company_id = p_company_id
      and cm.profile_id = auth.uid()
      and cm.member_role = 'owner'::public.company_member_role
      and cp.deleted_at is null);
$$;

comment on function public.is_company_owner(uuid) is
  'Owner (y solo owner) de ESA empresa. is_company_manager incluye admin (T-028).';

-- LÍMITE DELIBERADO (T-030): este helper es la autorización server-side
-- reutilizable de "esta empresa puede publicar". Hoy NADIE lo llama: la policy
-- `jobs_company_write` (0015:96) sigue exigiendo solo `is_company_member`, así
-- que una empresa sin verificar todavía podría insertar en `jobs`. Cerrar esa
-- puerta es parte de T-030 —ahí nace el CRUD real de oferta, con sus estados y
-- su prueba de "publicar sin verificación falla"—; adelantarlo acá sería
-- cambiar el contrato de una tabla cuyo circuito no existe. El test 017 prueba
-- el helper contra las cuatro combinaciones de estado, no la publicación.
create or replace function public.company_can_publish(p_company_id uuid)
returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.company_profiles cp
    where cp.id = p_company_id
      and cp.verification_status = 'approved'::public.verification_status
      and cp.deleted_at is null);
$$;

comment on function public.company_can_publish(uuid) is
  'Autorización reutilizable de publicación. La conecta a jobs T-030 (T-028).';

-- ---------------------------------------------------------------------------
-- 6. Path de la constancia: SIEMPRE derivado server-side.
--
-- El cliente no manda un path, manda una extensión de una lista cerrada. La
-- carpeta es el `company_id` que resuelve `private.caller_company()` desde
-- `auth.uid()`, así que no hay forma de escribir bajo la carpeta de otra
-- empresa aunque se conozca su UUID. El nombre es fijo: reemplazar la
-- constancia sobreescribe el mismo objeto y no deja huérfanos (misma decisión
-- que el bucket de avatares, 0024).
--
-- `private.company_document_path_company` es el inverso —de path a empresa— y
-- lo usan las policies del bucket en 0029: una sola definición de la forma
-- válida, imposible que las dos mitades se desincronicen.
-- ---------------------------------------------------------------------------

create or replace function private.company_document_extension(p_extension text)
returns text
language sql immutable set search_path = '' as $$
  select case lower(btrim(coalesce(p_extension, '')))
    when 'pdf' then 'pdf'
    when 'jpg' then 'jpg'
    when 'jpeg' then 'jpg'
    when 'png' then 'png'
    when 'webp' then 'webp'
    else null
  end;
$$;

create or replace function private.company_document_path(p_company_id uuid, p_extension text)
returns text
language sql immutable set search_path = '' as $$
  select case
    when p_company_id is null or private.company_document_extension(p_extension) is null then null
    else p_company_id::text || '/constancia-arca.' || private.company_document_extension(p_extension)
  end;
$$;

-- De un nombre de objeto del bucket a la empresa dueña, o NULL si el nombre no
-- tiene la forma exacta `<uuid>/constancia-arca.<ext>`. Fail-closed por
-- construcción: cualquier path raro (vacío, con subcarpetas, con `..`, con
-- otro nombre de archivo) devuelve NULL y ninguna policy lo deja pasar.
create or replace function private.company_document_path_company(p_name text)
returns uuid
language plpgsql
immutable
set search_path = ''
as $$
declare
  partes text[];
begin
  if p_name is null then
    return null;
  end if;
  partes := string_to_array(p_name, '/');
  if array_length(partes, 1) is distinct from 2 then
    return null;
  end if;
  if partes[1] !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return null;
  end if;
  if partes[2] !~ '^constancia-arca\.(pdf|jpg|png|webp)$' then
    return null;
  end if;
  return partes[1]::uuid;
end $$;

revoke all on function private.company_document_extension(text) from public, anon, authenticated;
revoke all on function private.company_document_path(uuid, text) from public, anon, authenticated;
revoke all on function private.company_document_path_company(text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 7. La empresa pide su carpeta de subida.
--
-- Devuelve el path exacto al que el cliente debe subir la constancia. Es la
-- única forma de que la UI conozca un path válido, y la policy del bucket
-- (0029) vuelve a comprobar lo mismo por su cuenta: que la RPC sea la fuente
-- del path es comodidad, no seguridad.
-- ---------------------------------------------------------------------------

create or replace function public.company_document_upload_path(p_extension text)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  target_company uuid;
  path text;
begin
  if auth.uid() is null then
    raise insufficient_privilege using message = 'Se requiere una sesión autenticada';
  end if;
  if private.company_document_extension(p_extension) is null then
    raise sqlstate 'TFDAT'
      using message = 'La constancia tiene que ser un PDF o una imagen (jpg, png o webp)';
  end if;

  target_company := private.caller_company();
  if not public.is_company_owner(target_company) then
    raise insufficient_privilege
      using message = 'Solo el owner de la empresa puede cargar la constancia';
  end if;

  path := private.company_document_path(target_company, p_extension);
  return path;
end $$;

revoke all on function public.company_document_upload_path(text) from public;
grant execute on function public.company_document_upload_path(text) to authenticated;

-- ---------------------------------------------------------------------------
-- 8. Solicitud de verificación.
--
-- Quién: el owner de la empresa que resuelve `private.caller_company()`. Un
-- recruiter, un viewer o un admin de empresa reciben 42501 aunque manden el
-- CUIT correcto.
--
-- Coherencia: el CUIT enviado tiene que ser EL de la empresa. Sin esa
-- comprobación, una empresa podría hacer verificar el CUIT de otra y quedar
-- aprobada con documentación ajena; y como `cuit` es inmutable para el cliente
-- (0026), el dato contra el que se compara no lo puede tocar quien solicita.
--
-- Idempotencia y carrera: el `on conflict` sobre el índice parcial de
-- solicitudes abiertas convierte el doble submit en un UPDATE de la misma
-- fila. Si la solicitud abierta ya está `in_review`, el `where` del DO UPDATE
-- no alcanza ninguna fila, `returning` no devuelve nada y se rechaza sin
-- pisarle el trabajo a quien está revisando.
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

  select * into empresa from public.company_profiles where id = target_company;
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
    -- Un reenvío sin constancia no borra la que ya estaba adjunta.
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

  -- Volver a pedir después de un rechazo devuelve la empresa a "pendiente":
  -- el estado de la empresa siempre refleja la solicitud abierta.
  if empresa.verification_status <> 'pending'::public.verification_status then
    update public.company_profiles
       set verification_status = 'pending'::public.verification_status
     where id = target_company;
  end if;

  return request_id;
end $$;

revoke all on function public.request_company_verification(text, text) from public;
grant execute on function public.request_company_verification(text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 9. La empresa consulta su estado.
--
-- Devuelve el estado de la EMPRESA (la fuente de verdad para el resto de la
-- app) junto con la última solicitud, si existe. `documents` no se expone
-- crudo: sale el path de la constancia, que sin una URL firmada no sirve para
-- nada, y así el cliente no depende de la forma interna del jsonb.
-- ---------------------------------------------------------------------------

create or replace function public.my_company_verification()
returns table (
  company_id uuid,
  company_status text,
  request_id uuid,
  request_status text,
  cuit_submitted text,
  document_path text,
  rejection_reason text,
  submitted_at timestamptz,
  reviewed_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  target_company uuid;
begin
  if auth.uid() is null then
    raise insufficient_privilege using message = 'Se requiere una sesión autenticada';
  end if;
  target_company := private.caller_company();

  return query
    select cp.id,
           cp.verification_status::text,
           cv.id,
           cv.status::text,
           cv.cuit_submitted,
           cv.documents -> 0 ->> 'path',
           cv.rejection_reason,
           cv.created_at,
           cv.reviewed_at
    from public.company_profiles cp
    left join lateral (
      select * from public.company_verifications v
      where v.company_id = cp.id
      -- La solicitud ABIERTA primero, y recién después la más reciente. Ordenar
      -- solo por created_at no alcanza: `now()` es el instante de la
      -- transacción, así que un rechazo y su reintento hechos en la misma
      -- transacción comparten timestamp y el desempate quedaba librado al uuid.
      order by (v.status in ('pending'::public.verification_status,
                             'in_review'::public.verification_status)) desc,
               v.created_at desc, v.id desc
      limit 1
    ) cv on true
    where cp.id = target_company;
end $$;

revoke all on function public.my_company_verification() from public;
grant execute on function public.my_company_verification() to authenticated;

-- ---------------------------------------------------------------------------
-- 10. Cola administrativa — AVANCE PARCIAL DE T-077.
--
-- T-077 ("colas operativas: verificación CUIT, denuncias, moderación de
-- videos") es una tarea del Bloque P y sigue ABIERTA. Acá se implementa
-- únicamente el mínimo que T-028 necesita para existir: listar solicitudes por
-- estado y resolverlas. NO se implementan las otras dos colas, ni la
-- asignación de casos, ni el SLA, ni la paginación keyset del panel.
-- ---------------------------------------------------------------------------

create or replace function public.admin_list_company_verifications(
  p_status text default 'pending',
  p_limit int default 50
)
returns table (
  request_id uuid,
  company_id uuid,
  company_name text,
  company_status text,
  request_status text,
  cuit_submitted text,
  document_path text,
  rejection_reason text,
  submitted_at timestamptz,
  reviewed_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  wanted public.verification_status;
  cuantos int := least(greatest(coalesce(p_limit, 50), 1), 200);
begin
  perform private.require_verification_reviewer();

  if coalesce(p_status, '') not in ('pending', 'in_review', 'approved', 'rejected') then
    raise sqlstate 'TFDAT' using message = 'Estado de solicitud desconocido';
  end if;
  wanted := p_status::public.verification_status;

  return query
    select cv.id, cv.company_id, cp.name, cp.verification_status::text,
           cv.status::text, cv.cuit_submitted, cv.documents -> 0 ->> 'path',
           cv.rejection_reason, cv.created_at, cv.reviewed_at
    from public.company_verifications cv
    join public.company_profiles cp on cp.id = cv.company_id
    where cv.status = wanted
    order by cv.created_at, cv.id
    limit cuantos;
end $$;

revoke all on function public.admin_list_company_verifications(text, int) from public;
grant execute on function public.admin_list_company_verifications(text, int) to authenticated;

-- ---------------------------------------------------------------------------
-- 11. Resolución de una solicitud.
--
-- Transiciones explícitas y únicas: pending → approved | rejected. Cualquier
-- otro origen se rechaza, así que una solicitud ya resuelta no se puede
-- volver a resolver — ni por un doble clic, ni por dos personas a la vez: el
-- `for update` serializa a la segunda transacción, que al despertar ve
-- `status <> 'pending'` y sale con TFDAT sin pisar la decisión anterior.
--
-- Motivo controlado: `p_reason` sale de una lista cerrada. Un motivo libre
-- terminaría copiado en un mail o en una notificación, y ahí un texto escrito
-- por una persona apurada es superficie de fuga; además una lista cerrada es
-- lo único que después se puede contar en un tablero.
--
-- Nadie se aprueba a sí mismo: si quien revisa integra la empresa que está
-- revisando, la RPC corta aunque tenga rol admin y AAL2.
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

  select cp.verification_status::text into estado_previo_empresa
  from public.company_profiles cp where cp.id = solicitud.company_id;

  update public.company_verifications
     set status = nuevo,
         reviewed_by = uid,
         reviewed_at = now(),
         rejection_reason = motivo,
         updated_at = now()
   where id = solicitud.id;

  update public.company_profiles
     set verification_status = nuevo
   where id = solicitud.company_id;

  -- Registro append-only: quién, qué empresa, qué solicitud, de qué estado a
  -- cuál y cuándo. `admin_audit_log` (0011) no tiene columna de empresa, así
  -- que el company_id viaja en los dos jsonb para que una fila sola alcance
  -- para reconstruir el hecho.
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
