-- Bloque E — T-026 (equipo): invitación por código de un solo uso.
--
-- Lo que se prueba acá es que la invitación no otorga NADA hasta que la
-- persona destinataria la acepta, que el código vive solo hasta que se muestra
-- (en la base queda su SHA-256) y que todos los rechazos son indistinguibles
-- entre sí, para que el endpoint no sirva para sondear códigos ajenos.
begin;
select plan(29);

-- --- Fixtures locales -------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                        confirmation_token, recovery_token,
                        email_change_token_new, email_change, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '93000000-0000-4000-8000-000000000001',
   'authenticated', 'authenticated', 'invitada@tests.local',
   crypt('password123', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"role":"company"}',
   '', '', '', '', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '93000000-0000-4000-8000-000000000002',
   'authenticated', 'authenticated', 'otra-persona@tests.local',
   crypt('password123', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"role":"company"}',
   '', '', '', '', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '93000000-0000-4000-8000-000000000003',
   'authenticated', 'authenticated', 'inv-candidato@tests.local',
   crypt('password123', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"role":"candidate"}',
   '', '', '', '', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '93000000-0000-4000-8000-000000000004',
   'authenticated', 'authenticated', 'inv-recruiter@tests.local',
   crypt('password123', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"role":"company"}',
   '', '', '', '', now(), now());

insert into tests.identifiers (identifier, id) values
  ('inv_invitada', '93000000-0000-4000-8000-000000000001'),
  ('inv_otra', '93000000-0000-4000-8000-000000000002'),
  ('inv_candidato', '93000000-0000-4000-8000-000000000003'),
  ('inv_recruiter', '93000000-0000-4000-8000-000000000004')
on conflict (identifier) do update set id = excluded.id;

insert into public.company_members (company_id, profile_id, member_role)
values (tests.get_uuid('company_ok'), tests.get_uuid('inv_recruiter'), 'recruiter');

-- El código solo existe en la respuesta de la RPC: se guarda acá para poder
-- canjearlo más abajo, igual que haría la UI al mostrarlo.
create temporary table codigos (etiqueta text primary key, code text not null)
on commit drop;
-- La tabla la crea el rol del runner; las RPC se llaman como `authenticated`,
-- así que necesita poder guardar ahí el código que le devuelven.
grant select, insert on codigos to authenticated;

-- ===========================================================================
-- A. La tabla no es superficie de API
-- ===========================================================================

select results_eq(
  $$ select count(*)::int
     from information_schema.role_table_grants
     where table_schema = 'public' and table_name = 'company_invitations'
       and grantee in ('anon', 'authenticated') $$,
  $$ values (0) $$,
  'FIXTURE: company_invitations nace sin ningún privilegio para anon ni authenticated');

select tests.authenticate_as('user_empresa_ok');

select throws_ok(
  $$ select count(*) from public.company_invitations $$,
  '42501', null,
  'NEGATIVO: ni el owner puede leer la tabla de invitaciones directamente');

-- ===========================================================================
-- B. Crear: quién puede, y qué queda guardado
-- ===========================================================================

select tests.authenticate_as('inv_recruiter');

select throws_ok(
  $$ select public.create_company_invitation('invitada@tests.local', 'viewer') $$,
  '42501', null,
  'NEGATIVO: un recruiter no puede invitar a nadie');

select tests.authenticate_as('user_empresa_ok');

select throws_ok(
  $$ select public.create_company_invitation('invitada@tests.local', 'owner') $$,
  'TFDAT', null,
  'NEGATIVO: no se puede invitar a alguien directamente como owner');

select throws_ok(
  $$ select public.create_company_invitation('no-es-un-email', 'viewer') $$,
  'TFDAT', null,
  'NEGATIVO: un email mal formado se rechaza');

select lives_ok(
  $$ insert into codigos (etiqueta, code)
     select 'principal', public.create_company_invitation('invitada@tests.local', 'recruiter') $$,
  'POSITIVO: el owner crea la invitación y recibe el código');

select results_eq(
  $$ select code ~ '^[0-9A-F]{32}$' from codigos where etiqueta = 'principal' $$,
  $$ values (true) $$,
  'POSITIVO: el código son 32 dígitos hexadecimales (128 bits)');

reset role;

-- El código en claro no puede estar en ninguna columna de la fila.
select results_eq(
  $$ select count(*)::int,
            count(*) filter (where ci.token_hash
              = encode(extensions.digest((select code from codigos where etiqueta='principal'),
                                         'sha256'), 'hex'))::int,
            count(*) filter (where ci.token_hash
              = (select code from codigos where etiqueta='principal'))::int
     from public.company_invitations ci
     where ci.company_id = tests.get_uuid('company_ok') $$,
  $$ values (1, 1, 0) $$,
  'POSITIVO: en la base queda el SHA-256 del código, nunca el código');

-- Una invitación pendiente no otorga absolutamente nada.
select results_eq(
  $$ select count(*)::int from public.company_members
     where company_id = tests.get_uuid('company_ok')
       and profile_id = tests.get_uuid('inv_invitada') $$,
  $$ values (0) $$,
  'NEGATIVO: la invitación pendiente todavía no crea ninguna membresía');

-- ===========================================================================
-- C. Canjear: solo la persona destinataria, solo una vez
-- ===========================================================================

select tests.authenticate_as('inv_otra');

select throws_ok(
  $$ select public.accept_company_invitation(
       (select code from codigos where etiqueta = 'principal')) $$,
  'TFINV', null,
  'NEGATIVO: el código no sirve para una persona distinta de la invitada');

select throws_ok(
  $$ select public.accept_company_invitation('00000000000000000000000000000000') $$,
  'TFINV', null,
  'NEGATIVO: un código inexistente da el MISMO error que uno ajeno');

select tests.authenticate_as('inv_candidato');

select throws_ok(
  $$ select public.accept_company_invitation(
       (select code from codigos where etiqueta = 'principal')) $$,
  '42501', null,
  'NEGATIVO: una cuenta de candidato no puede sumarse a un equipo de empresa');

reset role;
select results_eq(
  $$ select count(*)::int from public.company_members
     where company_id = tests.get_uuid('company_ok')
       and profile_id in (tests.get_uuid('inv_otra'), tests.get_uuid('inv_candidato')) $$,
  $$ values (0) $$,
  'NEGATIVO: tras los tres intentos fallidos no se creó ninguna membresía');

select tests.authenticate_as('inv_invitada');

select results_eq(
  $$ select public.accept_company_invitation(
       (select code from codigos where etiqueta = 'principal')) $$,
  $$ select tests.get_uuid('company_ok') $$,
  'POSITIVO: la persona invitada canjea el código y entra a la empresa');

reset role;
select results_eq(
  $$ select cm.member_role::text, cm.invited_by = tests.get_uuid('user_empresa_ok')
     from public.company_members cm
     where cm.company_id = tests.get_uuid('company_ok')
       and cm.profile_id = tests.get_uuid('inv_invitada') $$,
  $$ values ('recruiter'::text, true) $$,
  'POSITIVO: entró con el rol invitado y con invited_by de quien la invitó');

select tests.authenticate_as('inv_invitada');

select lives_ok(
  $$ select public.accept_company_invitation(
       (select code from codigos where etiqueta = 'principal')) $$,
  'POSITIVO: canjear dos veces es idempotente (no duplica la membresía)');

reset role;
select results_eq(
  $$ select count(*)::int from public.company_members
     where company_id = tests.get_uuid('company_ok')
       and profile_id = tests.get_uuid('inv_invitada') $$,
  $$ values (1) $$,
  'POSITIVO: sigue habiendo exactamente una membresía tras el doble canje');

select tests.authenticate_as('inv_otra');

select throws_ok(
  $$ select public.accept_company_invitation(
       (select code from codigos where etiqueta = 'principal')) $$,
  'TFINV', null,
  'NEGATIVO: un código ya usado no sirve para otra persona');

-- ===========================================================================
-- D. Revocación, reemplazo y vencimiento
-- ===========================================================================

select tests.authenticate_as('user_empresa_ok');

select lives_ok(
  $$ insert into codigos (etiqueta, code)
     select 'viejo', public.create_company_invitation('otra-persona@tests.local', 'viewer') $$,
  'POSITIVO: se crea una invitación para otra-persona');

select lives_ok(
  $$ insert into codigos (etiqueta, code)
     select 'nuevo', public.create_company_invitation('otra-persona@tests.local', 'viewer') $$,
  'POSITIVO: pedir otra invitación para el mismo email vuelve a andar');

select tests.authenticate_as('inv_otra');

select throws_ok(
  $$ select public.accept_company_invitation(
       (select code from codigos where etiqueta = 'viejo')) $$,
  'TFINV', null,
  'NEGATIVO: pedir una invitación nueva revoca la anterior (el código viejo muere)');

-- El código nuevo se vence a mano para probar el corte por expiración.
reset role;
update public.company_invitations ci
set expires_at = now() - interval '1 minute'
where ci.token_hash = private.invitation_code_hash(
  (select code from codigos where etiqueta = 'nuevo'));

select tests.authenticate_as('inv_otra');

select throws_ok(
  $$ select public.accept_company_invitation(
       (select code from codigos where etiqueta = 'nuevo')) $$,
  'TFINV', null,
  'NEGATIVO: una invitación vencida no se canjea');

reset role;
select results_eq(
  $$ select count(*)::int from public.company_members
     where company_id = tests.get_uuid('company_ok')
       and profile_id = tests.get_uuid('inv_otra') $$,
  $$ values (0) $$,
  'NEGATIVO: ni el código revocado ni el vencido crearon membresía');

-- El id se busca con el rol del runner: como `authenticated` no tiene ningún
-- privilegio sobre la tabla (y eso es justamente lo que prueba la sección A),
-- leerlo desde la sesión de la empresa fallaría por permisos.
reset role;
create temporary table ids (etiqueta text primary key, id uuid not null)
on commit drop;
grant select on ids to authenticated;
insert into ids (etiqueta, id)
select 'viva', ci.id from public.company_invitations ci
where ci.company_id = tests.get_uuid('company_ok')
  and ci.email = 'otra-persona@tests.local'
  and ci.revoked_at is null
limit 1;

select results_eq(
  $$ select count(*)::int from ids where etiqueta = 'viva' $$,
  $$ values (1) $$,
  'FIXTURE: queda una invitación viva para revocar (si no, el positivo de abajo sería vacío)');

select tests.authenticate_as('user_empresa_ok');

select results_eq(
  $$ select public.revoke_company_invitation(
       (select id from ids where etiqueta = 'viva')) $$,
  $$ values (true) $$,
  'POSITIVO: revocar una invitación viva devuelve true');

select results_eq(
  $$ select public.revoke_company_invitation(
       (select id from ids where etiqueta = 'viva')) $$,
  $$ values (false) $$,
  'POSITIVO: revocar la misma invitación otra vez devuelve false (idempotente)');

select results_eq(
  $$ select public.revoke_company_invitation(
       '00000000-0000-4000-8000-0000000000ff'::uuid) $$,
  $$ values (false) $$,
  'POSITIVO: revocar algo que no está vivo devuelve false y no rompe');

-- ===========================================================================
-- E. El listado no expone el hash
-- ===========================================================================

-- information_schema filtra por privilegios: como `authenticated` no tiene
-- ninguno sobre la tabla, hay que volver al rol del runner para poder ver sus
-- columnas.
reset role;

select results_eq(
  $$ select count(*)::int
     from information_schema.columns
     where table_schema = 'public'
       and table_name = 'company_invitations'
       and column_name = 'token_hash' $$,
  $$ values (1) $$,
  'FIXTURE: la columna token_hash existe (si no, el chequeo de abajo sería vacío)');

select results_eq(
  $$ select count(*)::int
     from information_schema.parameters
     where specific_schema = 'public'
       and specific_name like 'list_company_invitations%'
       and parameter_name = 'token_hash' $$,
  $$ values (0) $$,
  'POSITIVO: list_company_invitations no devuelve token_hash entre sus columnas');

reset role;
select * from finish();
rollback;
