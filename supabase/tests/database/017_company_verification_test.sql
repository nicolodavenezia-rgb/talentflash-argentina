-- Bloque E — T-028: verificación manual de empresa.
--
-- Lo que se prueba acá es que la verificación no la puede mover NADIE por la
-- puerta de atrás: ni un miembro que no sea owner, ni un admin sin segundo
-- factor, ni una empresa sobre sí misma, ni dos revisiones simultáneas sobre
-- la misma solicitud. Cada negativo de permiso va apareado con el positivo
-- equivalente, para que "falla" no pueda significar "el fixture estaba mal".
begin;
select plan(92);

-- --- Fixtures locales -------------------------------------------------------
-- Cuatro cuentas nuevas: quien revisa (admin de plataforma sin empresa), un
-- admin que ADEMÁS integra una empresa (el caso de auto-aprobación), y dos
-- miembros no-owner de company_ok (recruiter y admin de empresa) para separar
-- "es del equipo" de "es el owner".
insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                        confirmation_token, recovery_token,
                        email_change_token_new, email_change, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '94000000-0000-4000-8000-000000000001',
   'authenticated', 'authenticated', 'ver-admin@tests.local',
   crypt('password123', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"role":"candidate"}',
   '', '', '', '', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '94000000-0000-4000-8000-000000000002',
   'authenticated', 'authenticated', 'ver-admin-empresa@tests.local',
   crypt('password123', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"role":"company"}',
   '', '', '', '', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '94000000-0000-4000-8000-000000000003',
   'authenticated', 'authenticated', 'ver-recruiter@tests.local',
   crypt('password123', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"role":"company"}',
   '', '', '', '', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '94000000-0000-4000-8000-000000000004',
   'authenticated', 'authenticated', 'ver-empresa-admin@tests.local',
   crypt('password123', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"role":"company"}',
   '', '', '', '', now(), now());

insert into tests.identifiers (identifier, id) values
  ('ver_admin', '94000000-0000-4000-8000-000000000001'),
  ('ver_admin_empresa', '94000000-0000-4000-8000-000000000002'),
  ('ver_recruiter', '94000000-0000-4000-8000-000000000003'),
  ('ver_empresa_admin', '94000000-0000-4000-8000-000000000004')
on conflict (identifier) do update set id = excluded.id;

insert into public.company_members (company_id, profile_id, member_role) values
  (tests.get_uuid('company_ok'), tests.get_uuid('ver_recruiter'), 'recruiter'),
  (tests.get_uuid('company_ok'), tests.get_uuid('ver_empresa_admin'), 'admin'),
  -- El admin de plataforma que además integra company_pend: es la cuenta con la
  -- que se prueba que nadie se aprueba a sí mismo. La membresía se crea ANTES
  -- de darle el rol admin: `protect_company_member_write` (0026) exige que la
  -- cuenta que se suma a un equipo sea de tipo `company`.
  (tests.get_uuid('company_pend'), tests.get_uuid('ver_admin_empresa'), 'owner');

-- El rol admin se escribe en `profiles` (fuente de verdad de is_admin()), no en
-- metadata: 0019 degrada cualquier intento de alta admin desde el cliente.
update public.profiles set role = 'admin'
where id in (tests.get_uuid('ver_admin'), tests.get_uuid('ver_admin_empresa'));

-- company_ok viene `approved` del seed; para poder ejercer el circuito completo
-- se la devuelve a `pending`, que es el estado del que parte T-028.
update public.company_profiles
set verification_status = 'pending'
where id = tests.get_uuid('company_ok');

-- Guarda los ids que devuelven las RPCs, igual que haría la UI.
create temporary table solicitudes (etiqueta text primary key, id uuid not null)
on commit drop;
grant select, insert on solicitudes to authenticated;

-- ===========================================================================
-- A. La tabla no es superficie de API
-- ===========================================================================

-- Se cuentan TODOS los privilegios menos SELECT, no solo INSERT/UPDATE/DELETE.
-- La versión anterior de esta aserción pasaba en verde con TRUNCATE y TRIGGER
-- todavía concedidos, que son justamente los dos que saltean RLS: TRUNCATE no
-- la evalúa y TRIGGER deja colgar un trigger propio que corre dentro de las RPC
-- SECURITY DEFINER. 0030 los revoca; esto lo vigila.
select results_eq(
  $$ select count(*)::int
     from information_schema.role_table_grants
     where table_schema = 'public' and table_name = 'company_verifications'
       and grantee in ('anon', 'authenticated')
       and privilege_type <> 'SELECT' $$,
  $$ values (0) $$,
  'FIXTURE: a company_verifications no le queda NINGÚN privilegio salvo SELECT');

-- Control positivo apareado: el SELECT sí está, así que el cero de arriba no es
-- "la tabla no tiene grants porque no existe".
select results_eq(
  $$ select count(*)::int
     from information_schema.role_table_grants
     where table_schema = 'public' and table_name = 'company_verifications'
       and grantee = 'authenticated' and privilege_type = 'SELECT' $$,
  $$ values (1) $$,
  'POSITIVO: authenticated conserva el SELECT que necesita cv_company_select');

select results_eq(
  $$ select count(*)::int
     from information_schema.role_table_grants
     where grantee in ('anon', 'authenticated')
       and privilege_type in ('TRUNCATE', 'TRIGGER')
       and table_schema = 'public' $$,
  $$ values (0) $$,
  'NEGATIVO: no queda ni un TRUNCATE ni un TRIGGER en public (los dos saltean RLS)');

-- Límite conocido, fijado a propósito: en `storage` estos privilegios siguen
-- concedidos porque las tablas son de `supabase_storage_admin` y la migración
-- corre como `postgres`, que no es superusuario ni miembro de ese rol. Lo que
-- hoy lo contiene es que PostgREST no expone el esquema `storage`. Si alguna
-- vez la tabla cambia de dueño, esta aserción se pone roja y ahí sí se revoca.
select results_eq(
  $$ select pg_catalog.pg_get_userbyid(c.relowner) = 'supabase_storage_admin'::name
     from pg_catalog.pg_class c
     join pg_catalog.pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'storage' and c.relname = 'objects' $$,
  $$ values (true) $$,
  'FIXTURE: storage.objects sigue siendo de supabase_storage_admin (por eso no se le puede revocar nada desde una migración)');

select tests.authenticate_as('user_empresa_ok');

select throws_ok(
  $$ insert into public.company_verifications (company_id, cuit_submitted, submitted_by)
     values (tests.get_uuid('company_ok'), '30-70000001-6', tests.get_uuid('user_empresa_ok')) $$,
  '42501', null,
  'NEGATIVO: ni el owner puede insertar una solicitud directo en la tabla');

-- TRUNCATE no evalúa RLS: si el privilegio siguiera concedido, esto vaciaría la
-- tabla entera sin pasar por ninguna policy. Mismo caso para el registro de
-- auditoría, que es lo que vuelve real la palabra "append-only".
select throws_ok(
  $$ truncate public.company_verifications $$,
  '42501', null,
  'NEGATIVO: un cliente no puede TRUNCATE company_verifications');

select throws_ok(
  $$ truncate public.admin_audit_log $$,
  '42501', null,
  'NEGATIVO: append-only de verdad: tampoco se puede TRUNCATE la auditoría');

select throws_ok(
  $$ truncate public.company_members $$,
  '42501', null,
  'NEGATIVO: tampoco las membresías, que son de lo que cuelga todo el aislamiento por empresa');

-- ===========================================================================
-- B. Solicitar: quién puede (y quién no)
-- ===========================================================================

select tests.authenticate_as('ver_recruiter');
select throws_ok(
  $$ select public.request_company_verification('30-70000001-6') $$,
  '42501', null,
  'NEGATIVO: un recruiter de la empresa no puede pedir la verificación');

select tests.authenticate_as('ver_empresa_admin');
select throws_ok(
  $$ select public.request_company_verification('30-70000001-6') $$,
  '42501', null,
  'NEGATIVO: tampoco un admin DE EMPRESA: la verificación la firma el owner');

select tests.authenticate_as('user_cand_pub');
select throws_ok(
  $$ select public.request_company_verification('30-70000001-6') $$,
  'TFEMP', null,
  'NEGATIVO: un candidato no integra ninguna empresa y no puede solicitar');

do $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', 'anon', true);
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
end $$;
set local role anon;
select throws_ok(
  $$ select public.request_company_verification('30-70000001-6') $$,
  '42501', null,
  'NEGATIVO: sin sesión no se puede solicitar');
reset role;

-- ===========================================================================
-- C. CUIT: control positivo y control negativo
-- ===========================================================================

select tests.authenticate_as('user_empresa_ok');

-- Mismo CUIT que el de la empresa pero con el dígito verificador alterado
-- (…-6 → …-7): el único cambio respecto del control positivo de más abajo.
select throws_ok(
  $$ select public.request_company_verification('30-70000001-7') $$,
  'TFCUI', null,
  'NEGATIVO: un CUIT con el dígito verificador alterado se rechaza');

-- CUIT íntegro, pero de OTRA empresa del seed: verificar con documentación
-- ajena tiene que ser imposible aunque el número sea válido.
select throws_ok(
  $$ select public.request_company_verification('30-70000003-2') $$,
  'TFDAT', null,
  'NEGATIVO: un CUIT válido que no es el de tu empresa se rechaza');

select lives_ok(
  $$ insert into solicitudes (etiqueta, id)
     select 'ok', public.request_company_verification('30-70000001-6', 'pdf') $$,
  'POSITIVO: el owner con el CUIT correcto crea la solicitud');

select results_eq(
  $$ select cv.status::text, cv.cuit_submitted, cv.documents -> 0 ->> 'path'
     from public.company_verifications cv
     where cv.id = (select id from solicitudes where etiqueta = 'ok') $$,
  $$ values ('pending', '30-70000001-6',
             (select tests.get_uuid('company_ok')::text || '/constancia-arca.pdf')) $$,
  'POSITIVO: queda pending, con el CUIT normalizado y el path derivado server-side');

select results_eq(
  $$ select submitted_by = tests.get_uuid('user_empresa_ok')
     from public.company_verifications
     where id = (select id from solicitudes where etiqueta = 'ok') $$,
  $$ values (true) $$,
  'POSITIVO: submitted_by es quien llamó, no un dato del cliente');

-- Extensión fuera de la lista cerrada: el path no se puede fabricar.
select throws_ok(
  $$ select public.request_company_verification('30-70000001-6', 'exe') $$,
  'TFDAT', null,
  'NEGATIVO: una extensión de constancia fuera de la lista se rechaza');

select throws_ok(
  $$ select public.company_document_upload_path('exe') $$,
  'TFDAT', null,
  'NEGATIVO: upload_path tampoco fabrica un path para una extensión inválida');

select results_eq(
  $$ select public.company_document_upload_path('PDF') $$,
  $$ values ((select tests.get_uuid('company_ok')::text || '/constancia-arca.pdf')) $$,
  'POSITIVO: el path de subida sale del company_id resuelto server-side');

select tests.authenticate_as('ver_recruiter');
select throws_ok(
  $$ select public.company_document_upload_path('pdf') $$,
  '42501', null,
  'NEGATIVO: un recruiter no obtiene un path de subida');

-- ===========================================================================
-- D. Idempotencia y transiciones
-- ===========================================================================

select tests.authenticate_as('user_empresa_ok');

select results_eq(
  $$ select public.request_company_verification('30-70000001-6') =
            (select id from solicitudes where etiqueta = 'ok') $$,
  $$ values (true) $$,
  'POSITIVO: reenviar el formulario devuelve la MISMA solicitud, no crea otra');

select results_eq(
  $$ select count(*)::int from public.company_verifications
     where company_id = tests.get_uuid('company_ok') $$,
  $$ values (1) $$,
  'POSITIVO: el doble submit no duplicó filas');

select results_eq(
  $$ select cv.documents -> 0 ->> 'path'
     from public.company_verifications cv
     where cv.id = (select id from solicitudes where etiqueta = 'ok') $$,
  $$ values ((select tests.get_uuid('company_ok')::text || '/constancia-arca.pdf')) $$,
  'POSITIVO: un reenvío sin constancia no borra la que ya estaba adjunta');

select results_eq(
  $$ select verification_status::text from public.company_profiles
     where id = tests.get_uuid('company_ok') $$,
  $$ values ('pending') $$,
  'POSITIVO: la empresa queda en pending mientras la solicitud está abierta');

-- ===========================================================================
-- E. La cola administrativa: rol confiable Y segundo factor
-- ===========================================================================

select tests.authenticate_as('user_cand_pub');
select throws_ok(
  $$ select * from public.admin_list_company_verifications('pending') $$,
  '42501', null,
  'NEGATIVO: un candidato no ve la cola de verificaciones');

select tests.authenticate_as('user_empresa_ok');
select throws_ok(
  $$ select * from public.admin_list_company_verifications('pending') $$,
  '42501', null,
  'NEGATIVO: el owner de una empresa tampoco ve la cola');

-- Con AAL2 pero SIN rol admin: el segundo factor no otorga autoridad.
select tests.authenticate_as_aal('user_empresa_ok', 'aal2');
select throws_ok(
  $$ select * from public.admin_list_company_verifications('pending') $$,
  '42501', null,
  'NEGATIVO: AAL2 sin rol admin no alcanza');

-- Rol admin sin ningún claim `aal` (es lo que emite una sesión de un factor).
select tests.authenticate_as('ver_admin');
select throws_ok(
  $$ select * from public.admin_list_company_verifications('pending') $$,
  'TFMFA', null,
  'NEGATIVO: admin con el claim aal AUSENTE se rechaza');

select tests.authenticate_as_aal('ver_admin', 'aal1');
select throws_ok(
  $$ select * from public.admin_list_company_verifications('pending') $$,
  'TFMFA', null,
  'NEGATIVO: admin con aal1 se rechaza');

select tests.authenticate_as_aal('ver_admin', 'AAL2');
select throws_ok(
  $$ select * from public.admin_list_company_verifications('pending') $$,
  'TFMFA', null,
  'NEGATIVO: el claim con la caja equivocada (AAL2) NO cuenta como aal2');

select tests.authenticate_as_aal('ver_admin', 'aal3');
select throws_ok(
  $$ select * from public.admin_list_company_verifications('pending') $$,
  'TFMFA', null,
  'NEGATIVO: un nivel desconocido (aal3) tampoco cuenta como aal2');

select tests.authenticate_as_aal('ver_admin', 'aal2');
select results_eq(
  $$ select count(*)::int from public.admin_list_company_verifications('pending')
     where company_id = tests.get_uuid('company_ok') $$,
  $$ values (1) $$,
  'POSITIVO: admin con aal2 ve la solicitud pendiente en la cola');

select throws_ok(
  $$ select * from public.admin_list_company_verifications('inexistente') $$,
  'TFDAT', null,
  'NEGATIVO: un estado desconocido no se acepta como filtro');

select results_eq(
  $$ select count(*)::int from public.admin_list_company_verifications('approved') $$,
  $$ values (0) $$,
  'POSITIVO: el filtro por estado devuelve solo lo pedido');

-- ===========================================================================
-- F. Revisar: decisiones, motivos y doble efecto
-- ===========================================================================

select tests.authenticate_as('ver_admin');
select throws_ok(
  $$ select public.admin_review_company_verification(
       (select id from solicitudes where etiqueta = 'ok'), 'approved') $$,
  'TFMFA', null,
  'NEGATIVO: revisar sin segundo factor se rechaza aunque el rol sea admin');

select tests.authenticate_as_aal('user_empresa_ok', 'aal2');
select throws_ok(
  $$ select public.admin_review_company_verification(
       (select id from solicitudes where etiqueta = 'ok'), 'approved') $$,
  '42501', null,
  'NEGATIVO: una empresa con aal2 no puede aprobar su propia solicitud');

select tests.authenticate_as_aal('ver_admin', 'aal2');

select throws_ok(
  $$ select public.admin_review_company_verification(
       (select id from solicitudes where etiqueta = 'ok'), 'aprobada') $$,
  'TFDAT', null,
  'NEGATIVO: una decisión que no es approved/rejected se rechaza');

select throws_ok(
  $$ select public.admin_review_company_verification(
       (select id from solicitudes where etiqueta = 'ok'), 'rejected') $$,
  'TFDAT', null,
  'NEGATIVO: rechazar sin motivo se rechaza');

select throws_ok(
  $$ select public.admin_review_company_verification(
       (select id from solicitudes where etiqueta = 'ok'), 'rejected', 'porque no me gusta') $$,
  'TFDAT', null,
  'NEGATIVO: un motivo libre, fuera de la lista cerrada, se rechaza');

select throws_ok(
  $$ select public.admin_review_company_verification(
       (select id from solicitudes where etiqueta = 'ok'), 'approved', 'datos_incompletos') $$,
  'TFDAT', null,
  'NEGATIVO: una aprobación no lleva motivo de rechazo');

select throws_ok(
  $$ select public.admin_review_company_verification(
       '00000000-0000-4000-8000-0000000000ff', 'approved') $$,
  'TFDAT', null,
  'NEGATIVO: revisar una solicitud inexistente no crea nada');

select results_eq(
  $$ select cv.status::text, cp.verification_status::text
     from public.company_verifications cv
     join public.company_profiles cp on cp.id = cv.company_id
     where cv.id = (select id from solicitudes where etiqueta = 'ok') $$,
  $$ values ('pending', 'pending') $$,
  'POSITIVO: después de todos los rechazos anteriores nada cambió de estado');

-- --- Auto-aprobación: admin de plataforma que integra la empresa revisada ----
select tests.authenticate_as('user_empresa_pend');
select lives_ok(
  $$ insert into solicitudes (etiqueta, id)
     select 'propia', public.request_company_verification('30-70000002-4') $$,
  'FIXTURE: la empresa que integra el admin también pidió verificación');

select tests.authenticate_as_aal('ver_admin_empresa', 'aal2');
select throws_ok(
  $$ select public.admin_review_company_verification(
       (select id from solicitudes where etiqueta = 'propia'), 'approved') $$,
  '42501', null,
  'NEGATIVO: un admin de plataforma no aprueba la empresa que integra');

select results_eq(
  $$ select verification_status::text from public.company_profiles
     where id = tests.get_uuid('company_pend') $$,
  $$ values ('pending') $$,
  'POSITIVO: la empresa que se quiso auto-aprobar sigue pendiente');

-- Control positivo del mismo admin sobre una empresa que NO integra: lo que lo
-- frenó fue la membresía, no que le faltara algo.
select lives_ok(
  $$ select public.admin_review_company_verification(
       (select id from solicitudes where etiqueta = 'ok'), 'rejected', 'constancia_ilegible') $$,
  'POSITIVO: ese mismo admin sí puede revisar una empresa que no integra');

select results_eq(
  $$ select cv.status::text, cv.rejection_reason, cp.verification_status::text
     from public.company_verifications cv
     join public.company_profiles cp on cp.id = cv.company_id
     where cv.id = (select id from solicitudes where etiqueta = 'ok') $$,
  $$ values ('rejected', 'constancia_ilegible', 'rejected') $$,
  'POSITIVO: el rechazo guarda el motivo y baja el estado de la empresa');

select results_eq(
  $$ select reviewed_by = tests.get_uuid('ver_admin_empresa'), reviewed_at is not null
     from public.company_verifications
     where id = (select id from solicitudes where etiqueta = 'ok') $$,
  $$ values (true, true) $$,
  'POSITIVO: queda registrado quién revisó y cuándo');

-- --- Revisión repetida: la segunda decisión no pisa a la primera -------------
select tests.authenticate_as_aal('ver_admin', 'aal2');
select throws_ok(
  $$ select public.admin_review_company_verification(
       (select id from solicitudes where etiqueta = 'ok'), 'approved') $$,
  'TFDAT', null,
  'NEGATIVO: una solicitud ya resuelta no se vuelve a resolver');

select results_eq(
  $$ select cv.status::text, cv.reviewed_by = tests.get_uuid('ver_admin_empresa'),
            cp.verification_status::text
     from public.company_verifications cv
     join public.company_profiles cp on cp.id = cv.company_id
     where cv.id = (select id from solicitudes where etiqueta = 'ok') $$,
  $$ values ('rejected', true, 'rejected') $$,
  'POSITIVO: la segunda revisión no sobrescribió la decisión ni el revisor');

-- ===========================================================================
-- G. Registro append-only de cada acción administrativa
-- ===========================================================================

select results_eq(
  $$ select count(*)::int from public.admin_audit_log
     where entity_id = (select id from solicitudes where etiqueta = 'ok') $$,
  $$ values (1) $$,
  'POSITIVO: la revisión dejó exactamente una fila de auditoría (el intento fallido no)');

select results_eq(
  $$ select admin_id = tests.get_uuid('ver_admin_empresa'),
            action, entity_type,
            before ->> 'company_id' = tests.get_uuid('company_ok')::text,
            before ->> 'request_status', after ->> 'request_status',
            after ->> 'rejection_reason',
            created_at is not null
     from public.admin_audit_log
     where entity_id = (select id from solicitudes where etiqueta = 'ok') $$,
  $$ values (true, 'company.verification.rejected', 'company_verifications',
             true, 'pending', 'rejected', 'constancia_ilegible', true) $$,
  'POSITIVO: la auditoría guarda actor, empresa, solicitud, estados y timestamp');

select throws_ok(
  $$ update public.admin_audit_log set action = 'falsificada'
     where entity_id = (select id from solicitudes where etiqueta = 'ok') $$,
  '42501', null,
  'NEGATIVO: ni un admin con aal2 puede modificar el registro de auditoría');

select throws_ok(
  $$ delete from public.admin_audit_log
     where entity_id = (select id from solicitudes where etiqueta = 'ok') $$,
  '42501', null,
  'NEGATIVO: tampoco borrarlo');

-- ===========================================================================
-- H. El escape de admin en el protector de company_profiles quedó cerrado
-- ===========================================================================

-- `ver_admin_empresa` es admin de plataforma Y owner de company_pend: pasa
-- `comp_member_update` (0015) y, antes de 0028, el trigger lo dejaba escribir
-- la columna protegida por ser is_admin().
select tests.authenticate_as_aal('ver_admin_empresa', 'aal2');
select throws_ok(
  $$ update public.company_profiles set verification_status = 'approved'
     where id = tests.get_uuid('company_pend') $$,
  '42501', null,
  'NEGATIVO: un admin-de-plataforma-y-owner no se aprueba solo por PostgREST');

select results_eq(
  $$ select verification_status::text from public.company_profiles
     where id = tests.get_uuid('company_pend') $$,
  $$ values ('pending') $$,
  'POSITIVO: la empresa siguió pendiente después del intento directo');

-- Control positivo del mismo hecho: la RPC SECURITY DEFINER sí escribe la
-- columna. Sin esto, el negativo de arriba podría estar pasando porque la
-- columna es imposible de escribir para todos, y el circuito no funcionaría.
select tests.authenticate_as_aal('ver_admin', 'aal2');
select lives_ok(
  $$ select public.admin_review_company_verification(
       (select id from solicitudes where etiqueta = 'propia'), 'approved') $$,
  'POSITIVO: la RPC de revisión sí mueve la columna protegida');

select results_eq(
  $$ select verification_status::text from public.company_profiles
     where id = tests.get_uuid('company_pend') $$,
  $$ values ('approved') $$,
  'POSITIVO: la empresa quedó verificada por la vía correcta');

-- ===========================================================================
-- I. Reverificación y estado ya aprobado
-- ===========================================================================

select tests.authenticate_as('user_empresa_pend');
select throws_ok(
  $$ select public.request_company_verification('30-70000002-4') $$,
  'TFDAT', null,
  'NEGATIVO: una empresa ya verificada no vuelve a pedir la verificación');

-- La empresa rechazada sí puede volver a intentar, y eso la devuelve a pending.
select tests.authenticate_as('user_empresa_ok');
select lives_ok(
  $$ insert into solicitudes (etiqueta, id)
     select 'reintento', public.request_company_verification('30-70000001-6', 'jpeg') $$,
  'POSITIVO: tras un rechazo se puede volver a solicitar');

select results_eq(
  $$ select cv.status::text, cv.rejection_reason is null,
            cv.documents -> 0 ->> 'path',
            cp.verification_status::text
     from public.company_verifications cv
     join public.company_profiles cp on cp.id = cv.company_id
     where cv.id = (select id from solicitudes where etiqueta = 'reintento') $$,
  $$ values ('pending', true,
             (select tests.get_uuid('company_ok')::text || '/constancia-arca.jpg'),
             'pending') $$,
  'POSITIVO: el reintento limpia el motivo, normaliza jpeg→jpg y vuelve a pending');

select results_eq(
  $$ select count(*)::int from public.company_verifications
     where company_id = tests.get_uuid('company_ok') $$,
  $$ values (2) $$,
  'POSITIVO: el reintento crea una solicitud nueva y deja la rechazada como historial');

-- ===========================================================================
-- J. Consulta propia y aislamiento entre empresas
-- ===========================================================================

select results_eq(
  $$ select company_id = tests.get_uuid('company_ok'), request_status, company_status
     from public.my_company_verification() $$,
  $$ values (true, 'pending', 'pending') $$,
  'POSITIVO: la empresa consulta su propio estado y el de su última solicitud');

select tests.authenticate_as('user_empresa_otra');
select results_eq(
  $$ select count(*)::int from public.company_verifications
     where company_id = tests.get_uuid('company_ok') $$,
  $$ values (0) $$,
  'NEGATIVO: el owner de otra empresa no ve las solicitudes de company_ok');

select results_eq(
  $$ select count(*)::int from public.my_company_verification()
     where company_id = tests.get_uuid('company_ok') $$,
  $$ values (0) $$,
  'NEGATIVO: my_company_verification jamás devuelve una empresa ajena');

-- ===========================================================================
-- K. company_can_publish: el helper reutilizable de T-030
-- ===========================================================================

select tests.authenticate_as('user_empresa_ok');
select results_eq(
  $$ select public.company_can_publish(tests.get_uuid('company_pend')) $$,
  $$ values (true) $$,
  'POSITIVO: una empresa approved puede publicar');

select results_eq(
  $$ select public.company_can_publish(tests.get_uuid('company_ok')) $$,
  $$ values (false) $$,
  'NEGATIVO: una empresa pending no puede publicar');

reset role;
update public.company_profiles set verification_status = 'rejected'
where id = tests.get_uuid('company_ok');
select tests.authenticate_as('user_empresa_ok');
select results_eq(
  $$ select public.company_can_publish(tests.get_uuid('company_ok')) $$,
  $$ values (false) $$,
  'NEGATIVO: una empresa rejected no puede publicar');

reset role;
update public.company_profiles
set verification_status = 'approved', deleted_at = now()
where id = tests.get_uuid('company_ok');
select tests.authenticate_as('user_empresa_ok');
select results_eq(
  $$ select public.company_can_publish(tests.get_uuid('company_ok')) $$,
  $$ values (false) $$,
  'NEGATIVO: una empresa approved pero dada de baja tampoco puede publicar');

reset role;
update public.company_profiles set deleted_at = null
where id = tests.get_uuid('company_ok');

-- ===========================================================================
-- L. Bucket privado de la constancia
-- ===========================================================================

select results_eq(
  $$ select public, file_size_limit::bigint,
            'application/pdf' = any(allowed_mime_types)
     from storage.buckets where id = 'company-docs' $$,
  $$ values (false, 5242880::bigint, true) $$,
  'POSITIVO: company-docs es privado, con límite de 5 MiB y PDF permitido');

reset role;
select lives_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('company-docs', tests.get_uuid('company_ok') || '/constancia-arca.pdf'),
            ('company-docs', tests.get_uuid('company_pend') || '/constancia-arca.pdf') $$,
  'FIXTURE: hay una constancia de cada empresa (contexto privilegiado)');

select tests.authenticate_as('user_empresa_ok');
select results_eq(
  $$ select count(*)::int from storage.objects
     where bucket_id = 'company-docs'
       and name = tests.get_uuid('company_ok') || '/constancia-arca.pdf' $$,
  $$ values (1) $$,
  'POSITIVO: el owner lee la constancia de su empresa');

select results_eq(
  $$ select count(*)::int from storage.objects
     where bucket_id = 'company-docs'
       and name = tests.get_uuid('company_pend') || '/constancia-arca.pdf' $$,
  $$ values (0) $$,
  'NEGATIVO: el owner de una empresa no ve la constancia de otra, con UUID y todo');

select results_eq(
  $$ select count(*)::int from storage.objects where bucket_id = 'company-docs' $$,
  $$ values (1) $$,
  'NEGATIVO: listar el bucket entero solo devuelve lo propio');

select tests.authenticate_as('ver_recruiter');
select results_eq(
  $$ select count(*)::int from storage.objects
     where bucket_id = 'company-docs'
       and name = tests.get_uuid('company_ok') || '/constancia-arca.pdf' $$,
  $$ values (1) $$,
  'POSITIVO: un miembro del equipo lee la constancia de SU empresa');

select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('company-docs', tests.get_uuid('company_ok') || '/constancia-arca.png') $$,
  '42501', null,
  'NEGATIVO: un recruiter no puede subir ni reemplazar la constancia');

select tests.authenticate_as('user_cand_pub');
select results_eq(
  $$ select count(*)::int from storage.objects where bucket_id = 'company-docs' $$,
  $$ values (0) $$,
  'NEGATIVO: un candidato no ve ninguna constancia');

select tests.authenticate_as('user_empresa_otra');
select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('company-docs', tests.get_uuid('company_ok') || '/constancia-arca.png') $$,
  '42501', null,
  'NEGATIVO: el owner de otra empresa no puede escribir en esa carpeta');

-- El DELETE directo lo corta una guardia del propio esquema de Storage antes
-- de evaluar RLS ("Use the Storage API instead"), así que un delete falla igual
-- para todos y no distinguiría autorización. Donde sí se ve la diferencia es en
-- el UPDATE —RLS deja cero filas alcanzables— y en el predicado exacto que
-- comparten las policies de UPDATE y DELETE.
select results_eq(
  $$ with intento as (
       update storage.objects set name = name
       where bucket_id = 'company-docs'
         and name = tests.get_uuid('company_ok') || '/constancia-arca.pdf'
       returning 1)
     select count(*)::int from intento $$,
  $$ values (0) $$,
  'NEGATIVO: el owner de otra empresa no puede reemplazar la constancia ajena');

select results_eq(
  $$ select public.can_write_company_document(
              tests.get_uuid('company_ok') || '/constancia-arca.pdf') $$,
  $$ values (false) $$,
  'NEGATIVO: el predicado de escritura (UPDATE y DELETE) dice que no sobre la carpeta ajena');

do $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', 'anon', true);
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
end $$;
set local role anon;
select results_eq(
  $$ select count(*)::int from storage.objects where bucket_id = 'company-docs' $$,
  $$ values (0) $$,
  'NEGATIVO: anon no ve ninguna constancia');
reset role;

select tests.authenticate_as('ver_admin');
select results_eq(
  $$ select count(*)::int from storage.objects where bucket_id = 'company-docs' $$,
  $$ values (0) $$,
  'NEGATIVO: un admin SIN segundo factor no ve las constancias');

select tests.authenticate_as_aal('ver_admin', 'aal2');
select results_eq(
  $$ select count(*)::int from storage.objects where bucket_id = 'company-docs' $$,
  $$ values (2) $$,
  'POSITIVO: un admin con aal2 sí revisa las constancias');

select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('company-docs', tests.get_uuid('company_ok') || '/constancia-arca.png') $$,
  '42501', null,
  'NEGATIVO: revisar es leer: ni un admin con aal2 sustituye la constancia');

select tests.authenticate_as('user_empresa_ok');
select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('company-docs', tests.get_uuid('company_ok') || '/../otra/cosa.pdf') $$,
  '42501', null,
  'NEGATIVO: un path con forma rara no pasa aunque la carpeta sea la propia');

select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('company-docs', tests.get_uuid('company_ok') || '/cualquier-cosa.pdf') $$,
  '42501', null,
  'NEGATIVO: solo el nombre canónico de la constancia es escribible');

select lives_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('company-docs', tests.get_uuid('company_ok') || '/constancia-arca.webp') $$,
  'POSITIVO: el owner sí sube la constancia con un nombre canónico');

select results_eq(
  $$ select public.can_write_company_document(
              tests.get_uuid('company_ok') || '/constancia-arca.pdf') $$,
  $$ values (true) $$,
  'POSITIVO: el mismo predicado dice que sí sobre la carpeta propia (control del negativo de arriba)');

-- Fail-closed de los dos helpers ante paths que no tienen la forma canónica.
select results_eq(
  $$ select public.can_read_company_document('../../etc/passwd'),
            public.can_read_company_document('no-es-uuid/constancia-arca.pdf'),
            public.can_read_company_document(''),
            public.can_write_company_document(
              tests.get_uuid('company_ok') || '/sub/constancia-arca.pdf') $$,
  $$ values (false, false, false, false) $$,
  'NEGATIVO: los predicados del bucket fallan cerrados ante cualquier path raro');

-- Una empresa dada de baja: el owner ya no podía REEMPLAZAR la constancia
-- (is_company_owner filtra deleted_at) pero sus miembros la seguían LEYENDO,
-- porque is_company_member es un exists pelado sobre company_members. 0030
-- empareja las dos mitades.
reset role;
update public.company_profiles set deleted_at = now()
where id = tests.get_uuid('company_ok');
select tests.authenticate_as('user_empresa_ok');

select results_eq(
  $$ select public.can_read_company_document(
              tests.get_uuid('company_ok') || '/constancia-arca.pdf'),
            public.can_write_company_document(
              tests.get_uuid('company_ok') || '/constancia-arca.pdf') $$,
  $$ values (false, false) $$,
  'NEGATIVO: en una empresa dada de baja no se lee NI se escribe la constancia');

reset role;
update public.company_profiles set deleted_at = null
where id = tests.get_uuid('company_ok');
select tests.authenticate_as('user_empresa_ok');

select results_eq(
  $$ select public.can_read_company_document(
              tests.get_uuid('company_ok') || '/constancia-arca.pdf') $$,
  $$ values (true) $$,
  'POSITIVO: con la empresa activa vuelve a leerse (control del negativo de arriba)');

select * from finish();
rollback;
