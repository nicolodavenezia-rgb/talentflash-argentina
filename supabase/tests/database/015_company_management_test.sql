-- Bloque E — T-026: perfil de empresa, equipo y roles.
--
-- El caso central de este archivo es la regresión de `cm_manage`: la policy de
-- 0015 comparaba `company_id` con la columna homónima de la relación interna
-- de su propia subconsulta, así que era siempre verdadera y cualquier owner
-- podía escribir en el equipo de cualquier empresa. Acá se prueba el cruce
-- entre empresas de verdad, con su control positivo al lado.
--
-- Todos los usuarios viven solo en esta transacción (namespace 92000000, con
-- emails @tests.local para no contaminar los conteos de 009, que filtran por
-- @dev.talentflash.test).
begin;
select plan(48);

-- --- Fixtures locales -------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                        confirmation_token, recovery_token,
                        email_change_token_new, email_change, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '92000000-0000-4000-8000-000000000001',
   'authenticated', 'authenticated', 'equipo-admin@tests.local',
   crypt('password123', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"role":"company"}',
   '', '', '', '', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '92000000-0000-4000-8000-000000000002',
   'authenticated', 'authenticated', 'equipo-recruiter@tests.local',
   crypt('password123', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"role":"company"}',
   '', '', '', '', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '92000000-0000-4000-8000-000000000003',
   'authenticated', 'authenticated', 'equipo-viewer@tests.local',
   crypt('password123', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"role":"company"}',
   '', '', '', '', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '92000000-0000-4000-8000-000000000004',
   'authenticated', 'authenticated', 'equipo-candidato@tests.local',
   crypt('password123', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"role":"candidate"}',
   '', '', '', '', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '92000000-0000-4000-8000-000000000005',
   'authenticated', 'authenticated', 'equipo-admin-global@tests.local',
   crypt('password123', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"role":"candidate"}',
   '', '', '', '', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '92000000-0000-4000-8000-000000000006',
   'authenticated', 'authenticated', 'equipo-segundo-owner@tests.local',
   crypt('password123', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"role":"company"}',
   '', '', '', '', now(), now());

-- El rol admin global no se otorga nunca desde metadata (0019 lo degrada): se
-- promueve desde un contexto privilegiado, como en producción.
update public.profiles set role = 'admin'::public.user_role
where id = '92000000-0000-4000-8000-000000000005';

insert into tests.identifiers (identifier, id) values
  ('m_admin', '92000000-0000-4000-8000-000000000001'),
  ('m_recruiter', '92000000-0000-4000-8000-000000000002'),
  ('m_viewer', '92000000-0000-4000-8000-000000000003'),
  ('m_candidato', '92000000-0000-4000-8000-000000000004'),
  ('m_admin_global', '92000000-0000-4000-8000-000000000005'),
  ('m_segundo_owner', '92000000-0000-4000-8000-000000000006')
on conflict (identifier) do update set id = excluded.id;

insert into public.company_members (company_id, profile_id, member_role) values
  (tests.get_uuid('company_ok'), tests.get_uuid('m_admin'), 'admin'),
  (tests.get_uuid('company_ok'), tests.get_uuid('m_recruiter'), 'recruiter'),
  (tests.get_uuid('company_ok'), tests.get_uuid('m_viewer'), 'viewer');

-- ===========================================================================
-- A. `cm_manage`: el cruce entre empresas
-- ===========================================================================

-- Sin este fixture, los negativos de abajo podrían pasar por no existir las
-- empresas o por ser el caller miembro de ambas.
select results_eq(
  $$ select
       (select count(*)::int from public.company_profiles
        where id in (tests.get_uuid('company_ok'), tests.get_uuid('company_pend'))),
       (select count(*)::int from public.company_members
        where company_id = tests.get_uuid('company_pend')
          and profile_id = tests.get_uuid('user_empresa_ok')) $$,
  $$ values (2, 0) $$,
  'FIXTURE: las dos empresas existen y el owner de company_ok no integra company_pend');

select tests.authenticate_as('user_empresa_ok');

select throws_ok(
  $$ insert into public.company_members (company_id, profile_id, member_role)
     values (tests.get_uuid('company_pend'), tests.get_uuid('m_recruiter'), 'recruiter') $$,
  '42501', null,
  'NEGATIVO: el owner de una empresa no puede sumar miembros a OTRA empresa');

select results_eq(
  $$ select count(*)::int from public.company_members
     where company_id = tests.get_uuid('company_pend')
       and profile_id = tests.get_uuid('m_recruiter') $$,
  $$ values (0) $$,
  'NEGATIVO: tras el rechazo no quedó ninguna membresía cruzada');

-- Control positivo apareado: la misma operación en la empresa propia sí anda,
-- así que el negativo de arriba no pasa porque el INSERT esté roto.
select lives_ok(
  $$ insert into public.company_members (company_id, profile_id, member_role)
     values (tests.get_uuid('company_ok'), tests.get_uuid('m_segundo_owner'), 'viewer') $$,
  'POSITIVO: el owner sí puede sumar a alguien a SU empresa');

-- ===========================================================================
-- B. Quién puede administrar el equipo
-- ===========================================================================

reset role;
select results_eq(
  $$ select count(*)::int, count(*) filter (where member_role = 'owner')::int
     from public.company_members where company_id = tests.get_uuid('company_ok') $$,
  $$ values (5, 1) $$,
  'FIXTURE: company_ok tiene 5 miembros y exactamente 1 owner');

select tests.authenticate_as('m_recruiter');

select throws_ok(
  $$ select public.set_company_member_role(tests.get_uuid('m_viewer'), 'admin') $$,
  '42501', null,
  'NEGATIVO: un recruiter no puede cambiar roles');

select tests.authenticate_as('m_viewer');

select throws_ok(
  $$ select public.remove_company_member(tests.get_uuid('m_recruiter')) $$,
  '42501', null,
  'NEGATIVO: un viewer no puede dar de baja a nadie');

reset role;
select results_eq(
  $$ select member_role::text from public.company_members
     where company_id = tests.get_uuid('company_ok')
       and profile_id = tests.get_uuid('m_viewer') $$,
  $$ values ('viewer'::text) $$,
  'NEGATIVO: tras los dos intentos el equipo quedó exactamente igual');

select tests.authenticate_as('user_empresa_ok');

select results_eq(
  $$ select public.set_company_member_role(tests.get_uuid('m_recruiter'), 'admin') $$,
  $$ values (true) $$,
  'POSITIVO: el owner promueve a un recruiter a admin');

select results_eq(
  $$ select public.set_company_member_role(tests.get_uuid('m_recruiter'), 'admin') $$,
  $$ values (false) $$,
  'POSITIVO: repetir el mismo rol es idempotente y devuelve false');

select throws_ok(
  $$ select public.set_company_member_role(tests.get_uuid('m_recruiter'), 'jefe') $$,
  'TFDAT', null,
  'NEGATIVO: un rol de equipo inexistente se rechaza');

-- --- Lo que un admin de empresa NO puede hacer con un owner ----------------
select tests.authenticate_as('m_admin');

select throws_ok(
  $$ select public.set_company_member_role(tests.get_uuid('m_viewer'), 'owner') $$,
  '42501', null,
  'NEGATIVO: un admin no puede nombrar a un owner');

select throws_ok(
  $$ select public.set_company_member_role(tests.get_uuid('user_empresa_ok'), 'viewer') $$,
  '42501', null,
  'NEGATIVO: un admin no puede degradar a un owner');

select throws_ok(
  $$ select public.remove_company_member(tests.get_uuid('user_empresa_ok')) $$,
  '42501', null,
  'NEGATIVO: un admin no puede dar de baja a un owner');

select results_eq(
  $$ select public.set_company_member_role(tests.get_uuid('m_viewer'), 'recruiter') $$,
  $$ values (true) $$,
  'POSITIVO: un admin sí puede cambiar el rol de quien no es owner');

reset role;
select results_eq(
  $$ select member_role::text from public.company_members
     where company_id = tests.get_uuid('company_ok')
       and profile_id = tests.get_uuid('user_empresa_ok') $$,
  $$ values ('owner'::text) $$,
  'NEGATIVO: tras los tres intentos del admin, el owner sigue siendo owner');

-- ===========================================================================
-- C. La empresa nunca se queda sin owner
-- ===========================================================================

select results_eq(
  $$ select count(*)::int from public.company_members
     where company_id = tests.get_uuid('company_ok') and member_role = 'owner' $$,
  $$ values (1) $$,
  'FIXTURE: queda exactamente un owner antes de intentar sacarlo');

select tests.authenticate_as('user_empresa_ok');

select throws_ok(
  $$ select public.set_company_member_role(tests.get_uuid('user_empresa_ok'), 'admin') $$,
  'TFOWN', null,
  'NEGATIVO: el último owner no puede degradarse a sí mismo');

select throws_ok(
  $$ select public.remove_company_member(tests.get_uuid('user_empresa_ok')) $$,
  'TFOWN', null,
  'NEGATIVO: el último owner no puede darse de baja');

reset role;
select results_eq(
  $$ select count(*)::int from public.company_members
     where company_id = tests.get_uuid('company_ok') and member_role = 'owner' $$,
  $$ values (1) $$,
  'NEGATIVO: tras los dos intentos sigue habiendo exactamente un owner');

-- La regla vale también para el dueño de la tabla: una empresa sin owner queda
-- sin nadie que la administre, así que el corte no es solo del cliente.
select throws_ok(
  $$ delete from public.company_members
     where company_id = tests.get_uuid('company_ok')
       and profile_id = tests.get_uuid('user_empresa_ok') $$,
  'TFOWN', null,
  'NEGATIVO: ni el dueño de la tabla puede dejar la empresa sin owner');

select tests.authenticate_as('user_empresa_ok');

select lives_ok(
  $$ select public.set_company_member_role(tests.get_uuid('m_segundo_owner'), 'owner') $$,
  'POSITIVO: el owner puede nombrar a un segundo owner');

select results_eq(
  $$ select public.remove_company_member(tests.get_uuid('user_empresa_ok')) $$,
  $$ values (true) $$,
  'POSITIVO: con un segundo owner, el primero sí puede irse');

-- ===========================================================================
-- D. Fronteras: otra empresa, candidato, anon y quién puede ser miembro
-- ===========================================================================

select tests.authenticate_as('user_empresa_otra');

select throws_ok(
  $$ select public.set_company_member_role(tests.get_uuid('m_admin'), 'viewer') $$,
  'TFMEM', null,
  'NEGATIVO: el owner de otra empresa no alcanza a un miembro ajeno');

select tests.authenticate_as('m_candidato');

select throws_ok(
  $$ select public.update_my_company_profile('{"name":"Mía"}'::jsonb) $$,
  'TFEMP', null,
  'NEGATIVO: un candidato no integra ninguna empresa y no puede editar ninguna');

select tests.authenticate_as('m_segundo_owner');

select throws_ok(
  $$ insert into public.company_members (company_id, profile_id, member_role)
     values (tests.get_uuid('company_ok'), tests.get_uuid('m_candidato'), 'viewer') $$,
  'TFMEM', null,
  'NEGATIVO: un candidato no puede entrar a un equipo de empresa');

select throws_ok(
  $$ insert into public.company_members (company_id, profile_id, member_role)
     values (tests.get_uuid('company_ok'), tests.get_uuid('m_admin_global'), 'viewer') $$,
  'TFMEM', null,
  'NEGATIVO: un admin global tampoco entra a un equipo por una llamada del cliente');

-- Columnas de la relación que no se editan.
select throws_ok(
  $$ update public.company_members set invited_by = auth.uid()
     where company_id = tests.get_uuid('company_ok')
       and profile_id = tests.get_uuid('m_admin') $$,
  '42501', null,
  'NEGATIVO: invited_by no es editable por el cliente');

select throws_ok(
  $$ update public.company_members set company_id = tests.get_uuid('company_pend')
     where company_id = tests.get_uuid('company_ok')
       and profile_id = tests.get_uuid('m_admin') $$,
  '42501', null,
  'NEGATIVO: un miembro no se puede mudar de empresa con un UPDATE');

-- Limpieza completa de rol y claims: un anon real no trae ningún sub.
do $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', 'anon', true);
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
end $$;
set local role anon;

select throws_ok(
  $$ select public.list_company_members() $$,
  '42501', null,
  'NEGATIVO: anon no puede leer el equipo de ninguna empresa');

-- ===========================================================================
-- E. Perfil de empresa: whitelist y columnas protegidas
-- ===========================================================================

reset role;
select tests.authenticate_as('m_recruiter');

-- m_recruiter fue promovido a admin en la sección B; se lo baja para probar el
-- corte por rol con un rol que no administra.
reset role;
update public.company_members set member_role = 'recruiter'
where company_id = tests.get_uuid('company_ok')
  and profile_id = tests.get_uuid('m_recruiter');

select results_eq(
  $$ select member_role::text from public.company_members
     where company_id = tests.get_uuid('company_ok')
       and profile_id = tests.get_uuid('m_recruiter') $$,
  $$ values ('recruiter'::text) $$,
  'FIXTURE: m_recruiter vuelve a ser recruiter para probar el corte por rol');

select tests.authenticate_as('m_recruiter');

select throws_ok(
  $$ select public.update_my_company_profile('{"name":"Renombrada"}'::jsonb) $$,
  '42501', null,
  'NEGATIVO: un recruiter no puede editar el perfil de la empresa');

select tests.authenticate_as('m_segundo_owner');

select throws_ok(
  $$ select public.update_my_company_profile(
       '{"verification_status":"approved"}'::jsonb) $$,
  'TFDAT', null,
  'NEGATIVO: un campo fuera de la whitelist hace fallar el cambio entero');

select throws_ok(
  $$ select public.update_my_company_profile('{"cuit":"20-12345678-6"}'::jsonb) $$,
  'TFDAT', null,
  'NEGATIVO: el CUIT no se edita por esta RPC (cambiarlo es reverificación)');

select throws_ok(
  $$ select public.update_my_company_profile('{"legal_name":"   "}'::jsonb) $$,
  'TFDAT', null,
  'NEGATIVO: la razón social no se puede vaciar');

select throws_ok(
  $$ select public.update_my_company_profile('{"size_range":"gigante"}'::jsonb) $$,
  'TFDAT', null,
  'NEGATIVO: un tamaño fuera del set cerrado se rechaza');

select throws_ok(
  $$ select public.update_my_company_profile(
       ('{"provincia_id":"b0000000-0000-4000-8000-000000000001",'
        || '"localidad_id":"b1000000-0000-4000-8000-000000000002"}')::jsonb) $$,
  'TFDAT', null,
  'NEGATIVO: una localidad que no pertenece a la provincia se rechaza');

select throws_ok(
  $$ select public.update_my_company_profile('{"website":"javascript:alert(1)"}'::jsonb) $$,
  'TFDAT', null,
  'NEGATIVO: un sitio web que no es http(s) se rechaza');

reset role;
select results_eq(
  $$ select name, verification_status::text from public.company_profiles
     where id = tests.get_uuid('company_ok') $$,
  $$ values ('Parrilla Don Julio Dev'::text, 'approved'::text) $$,
  'NEGATIVO: tras los siete rechazos el perfil quedó intacto');

select tests.authenticate_as('m_segundo_owner');

select lives_ok(
  $$ select public.update_my_company_profile(
       ('{"name":"Parrilla Renombrada","description":"Texto nuevo",'
        || '"website":"https://ejemplo.test"}')::jsonb) $$,
  'POSITIVO: el owner edita los campos de la whitelist');

select results_eq(
  $$ select name, description, website, size_range from public.company_profiles
     where id = tests.get_uuid('company_ok') $$,
  $$ values ('Parrilla Renombrada'::text, 'Texto nuevo'::text,
             'https://ejemplo.test'::text, '11-50'::text) $$,
  'POSITIVO: se guardó lo editado y lo que el patch no mencionó quedó igual');

-- Columnas protegidas, por UPDATE directo bajo `comp_member_update`.
-- Sobre la empresa PROPIA: apuntar a una ajena daría cero filas por RLS y el
-- test pasaría sin haber ejercitado el trigger.
select throws_ok(
  $$ update public.company_profiles set verification_status = 'rejected'
     where id = tests.get_uuid('company_ok') $$,
  '42501', null,
  'NEGATIVO: el cliente no puede tocar verification_status ni en su propia empresa');

select throws_ok(
  $$ update public.company_profiles set logo_url = 'https://malicioso.test/x.png'
     where id = tests.get_uuid('company_ok') $$,
  '42501', null,
  'NEGATIVO: logo_url es columna protegida (la escribe el pipeline, no el cliente)');

select throws_ok(
  $$ update public.company_profiles set cuit = '20-12345678-6'
     where id = tests.get_uuid('company_ok') $$,
  '42501', null,
  'NEGATIVO: el CUIT es columna protegida para el cliente');

reset role;
select results_eq(
  $$ select cuit, logo_url from public.company_profiles
     where id = tests.get_uuid('company_ok') $$,
  $$ values ('30-70000001-6'::text, null::text) $$,
  'NEGATIVO: tras los tres intentos el CUIT y el logo siguen intactos');

-- ===========================================================================
-- F. Doble alta y doble baja
-- ===========================================================================

select tests.authenticate_as('m_segundo_owner');

select results_eq(
  $$ select public.remove_company_member(tests.get_uuid('m_viewer')) $$,
  $$ values (true) $$,
  'POSITIVO: la primera baja de un miembro devuelve true');

select results_eq(
  $$ select public.remove_company_member(tests.get_uuid('m_viewer')) $$,
  $$ values (false) $$,
  'POSITIVO: repetir la baja devuelve false y no rompe (idempotente)');

select throws_ok(
  $$ insert into public.company_members (company_id, profile_id, member_role)
     values (tests.get_uuid('company_ok'), tests.get_uuid('m_admin'), 'viewer') $$,
  '23505', null,
  'NEGATIVO: sumar dos veces a la misma persona no duplica la membresía');

reset role;
select * from finish();
rollback;
