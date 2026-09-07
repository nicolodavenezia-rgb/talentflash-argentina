-- Bloque C (T-016/T-017): RPCs de onboarding, edad server-side, atomicidad
-- e idempotencia. Los usuarios de este archivo viven solo en su transacción.
begin;
select plan(31);

-- --- Fixtures locales -------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                        confirmation_token, recovery_token,
                        email_change_token_new, email_change, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '91000000-0000-4000-8000-000000000001',
   'authenticated', 'authenticated', 'cand-nuevo@tests.local',
   crypt('password123', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"role":"candidate"}',
   '', '', '', '', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '91000000-0000-4000-8000-000000000002',
   'authenticated', 'authenticated', 'empresa-nueva-c@tests.local',
   crypt('password123', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"role":"company"}',
   '', '', '', '', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '91000000-0000-4000-8000-000000000003',
   'authenticated', 'authenticated', 'empresa-sin-consents@tests.local',
   crypt('password123', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"role":"company"}',
   '', '', '', '', now(), now());

insert into tests.identifiers (identifier, id) values
  ('cand_nuevo', '91000000-0000-4000-8000-000000000001'),
  ('empresa_nueva_c', '91000000-0000-4000-8000-000000000002'),
  ('empresa_sin_consents', '91000000-0000-4000-8000-000000000003')
on conflict (identifier) do update set id = excluded.id;

-- --- Mayoría de edad por calendario (helper puro, casos frontera) ----------
select ok(private.is_adult(date '1990-06-15'), 'is_adult: una persona adulta pasa');
select ok(
  private.is_adult((current_date - interval '18 years')::date),
  'is_adult: quien cumple 18 exactamente HOY puede');
select ok(
  not private.is_adult(((current_date - interval '18 years') + interval '1 day')::date),
  'is_adult: quien cumple 18 MAÑANA todavía no puede');
select ok(
  not private.is_adult(date '2008-02-29', date '2026-02-28'),
  'is_adult: nacida un 29/2 no es mayor el 28/2 del año 18');
select ok(
  private.is_adult(date '2008-02-29', date '2026-03-01'),
  'is_adult: nacida un 29/2 es mayor recién el 1/3 (mismo redondeo que Flutter)');

-- --- Candidato: guardado, edad, geo, consentimientos y finalización --------
select tests.authenticate_as('cand_nuevo');

select lives_ok(
  $$ select save_candidate_onboarding(
       'Nombre De Prueba', date '1995-04-10',
       'b0000000-0000-4000-8000-000000000001',
       'b1000000-0000-4000-8000-000000000001',
       'b2000000-0000-4000-8000-000000000001',
       'a0000000-0000-4000-8000-000000000001',
       'inmediata', array['presencial']::work_mode[]) $$,
  'POSITIVO: el candidato guarda el avance de su wizard');

select results_eq(
  $$ select p.full_name, cp.birth_date
     from profiles p join candidate_profiles cp on cp.profile_id = p.id
     where p.id = auth.uid() $$,
  $$ values ('Nombre De Prueba'::text, date '1995-04-10') $$,
  'POSITIVO: el guardado persiste nombre y nacimiento');

select throws_ok(
  $$ select save_candidate_onboarding(
       'Persona Menor', (current_date - interval '15 years')::date,
       null, null, null, null, null, null) $$,
  'TF018', null,
  'NEGATIVO: una persona menor de 18 es rechazada server-side');

select results_eq(
  $$ select full_name from profiles where id = auth.uid() $$,
  $$ values ('Nombre De Prueba'::text) $$,
  'NEGATIVO: tras detectar minoría NADA de esa llamada queda persistido');

select throws_ok(
  $$ select save_candidate_onboarding(
       'Nombre De Prueba', date '1995-04-10',
       'b0000000-0000-4000-8000-000000000001',
       'b1000000-0000-4000-8000-000000000002',
       null,
       'a0000000-0000-4000-8000-000000000001',
       'inmediata', array['presencial']::work_mode[]) $$,
  'TFDAT', null,
  'NEGATIVO: una localidad de otra provincia se rechaza (cascada geo)');

select throws_ok(
  $$ select save_candidate_onboarding(
       'Nombre De Prueba', date '1995-04-10',
       'b0000000-0000-4000-8000-000000000001',
       'b1000000-0000-4000-8000-000000000001',
       'b2000000-0000-4000-8000-000000000001',
       '99999999-9999-4999-8999-999999999999',
       'inmediata', array['presencial']::work_mode[]) $$,
  'TFDAT', null,
  'NEGATIVO: un sector inexistente se rechaza');

select throws_ok(
  $$ select complete_candidate_onboarding() $$,
  'TFCNS', null,
  'NEGATIVO: sin consentimientos obligatorios el onboarding no se completa');

-- El candidato registra sus consentimientos obligatorios (versión vigente).
select lives_ok(
  $$ insert into consents (profile_id, consent_type, granted, version, user_agent)
     select auth.uid(), cv.consent_type, true, cv.version, 'pgtap'
     from consent_versions cv where cv.is_mandatory $$,
  'POSITIVO: el usuario registra sus consentimientos obligatorios');

select lives_ok(
  $$ select complete_candidate_onboarding() $$,
  'POSITIVO: con datos y consentimientos completos el onboarding cierra');

select results_eq(
  $$ select onboarding_completed from profiles where id = auth.uid() $$,
  $$ values (true) $$,
  'POSITIVO: onboarding_completed quedó en true');

select lives_ok(
  $$ select complete_candidate_onboarding() $$,
  'POSITIVO: repetir la finalización es idempotente (doble submit)');

select throws_ok(
  $$ update profiles set onboarding_completed = false where id = auth.uid() $$,
  '42501', null,
  'NEGATIVO: el cliente no puede tocar onboarding_completed directamente');

select throws_ok(
  $$ update candidate_profiles set is_published = true
     where profile_id = auth.uid() $$,
  '42501', null,
  'NEGATIVO: el cliente no puede forzar is_published (se deriva server-side)');

select throws_ok(
  $$ select complete_company_onboarding(
       'Razón Social SA', 'Fantasía', '30-71234567-1',
       'a0000000-0000-4000-8000-000000000001', '1-10',
       'b0000000-0000-4000-8000-000000000001',
       'b1000000-0000-4000-8000-000000000001',
       null, 'Nombre', 'Cargo', 'owner') $$,
  '42501', null,
  'NEGATIVO: un candidato no puede completar el onboarding de empresa');

-- --- Empresa: atomicidad, pending e idempotencia ---------------------------
select tests.authenticate_as('empresa_nueva_c');

select lives_ok(
  $$ insert into consents (profile_id, consent_type, granted, version, user_agent)
     select auth.uid(), cv.consent_type, true, cv.version, 'pgtap'
     from consent_versions cv where cv.is_mandatory $$,
  'POSITIVO: la empresa registra sus consentimientos obligatorios');

select throws_ok(
  $$ select save_candidate_onboarding('X', date '1990-01-01',
       null, null, null, null, null, null) $$,
  '42501', null,
  'NEGATIVO: una empresa no puede usar el wizard de candidato');

select throws_ok(
  $$ select complete_company_onboarding(
       'Razón Social SA', 'Fantasía', '123',
       'a0000000-0000-4000-8000-000000000001', '1-10',
       'b0000000-0000-4000-8000-000000000001',
       'b1000000-0000-4000-8000-000000000001',
       null, 'Nombre Solicitante', 'Dueño', 'owner') $$,
  'TFCUI', null,
  'NEGATIVO: un CUIT que no tiene 11 números se rechaza');

select throws_ok(
  $$ select complete_company_onboarding(
       'Razón Social SA', 'Fantasía', '30-70000001-6',
       'a0000000-0000-4000-8000-000000000001', '1-10',
       'b0000000-0000-4000-8000-000000000001',
       'b1000000-0000-4000-8000-000000000001',
       null, 'Nombre Solicitante', 'Dueño', 'owner') $$,
  '23505', null,
  'NEGATIVO: un CUIT ya registrado (seed) se rechaza por unicidad');

select throws_ok(
  $$ select complete_company_onboarding(
       'Razón Social SA', 'Fantasía', '30-71234567-1',
       'a0000000-0000-4000-8000-000000000001', 'gigante',
       'b0000000-0000-4000-8000-000000000001',
       'b1000000-0000-4000-8000-000000000001',
       null, 'Nombre Solicitante', 'Dueño', 'owner') $$,
  'TFDAT', null,
  'NEGATIVO: un tamaño fuera del set cerrado se rechaza');

select throws_ok(
  $$ select complete_company_onboarding(
       'Razón Social SA', 'Fantasía', '30-71234567-1',
       'a0000000-0000-4000-8000-000000000001', '1-10',
       'b0000000-0000-4000-8000-000000000001',
       'b1000000-0000-4000-8000-000000000002',
       null, 'Nombre Solicitante', 'Dueño', 'owner') $$,
  'TFDAT', null,
  'NEGATIVO: geografía incoherente se rechaza también para empresas');

-- El CUIT llega con espacios: la RPC lo normaliza a XX-XXXXXXXX-X.
select lives_ok(
  $$ select complete_company_onboarding(
       'Razón Social SA', 'Fantasía Gastro', '30 71234567 1',
       'a0000000-0000-4000-8000-000000000001', '11-50',
       'b0000000-0000-4000-8000-000000000001',
       'b1000000-0000-4000-8000-000000000001',
       'https://talentflash.test', 'Nombre Solicitante', 'Dueño', 'owner') $$,
  'POSITIVO: la empresa nace con la RPC atómica');

select results_eq(
  $$ select cp.cuit, cp.verification_status::text, cm.member_role::text,
            cm.position_title, cm.relationship
     from company_profiles cp
     join company_members cm on cm.company_id = cp.id
     where cm.profile_id = auth.uid() $$,
  $$ values ('30-71234567-1'::text, 'pending'::text, 'owner'::text,
             'Dueño'::text, 'owner'::text) $$,
  'POSITIVO: CUIT normalizado, estado pending y owner con cargo/relación');

select results_eq(
  $$ select public.complete_company_onboarding(
       'Otra Razón SA', 'Otra Fantasía', '30-79999999-9',
       'a0000000-0000-4000-8000-000000000001', '1-10',
       'b0000000-0000-4000-8000-000000000001',
       'b1000000-0000-4000-8000-000000000001',
       null, 'Nombre Solicitante', 'Dueño', 'owner') $$,
  $$ select cm.company_id from company_members cm
     where cm.profile_id = auth.uid() and cm.member_role = 'owner' $$,
  'POSITIVO: reintentar devuelve la MISMA empresa, sin duplicar nada');

select results_eq(
  $$ select count(*)::int from company_profiles where created_by = auth.uid() $$,
  $$ values (1) $$,
  'POSITIVO: el doble submit dejó exactamente una empresa');

-- --- Sin consentimientos, la empresa no nace -------------------------------
select tests.authenticate_as('empresa_sin_consents');
select throws_ok(
  $$ select complete_company_onboarding(
       'Razón Social SA', 'Fantasía', '30-78888888-8',
       'a0000000-0000-4000-8000-000000000001', '1-10',
       'b0000000-0000-4000-8000-000000000001',
       'b1000000-0000-4000-8000-000000000001',
       null, 'Nombre', 'Cargo', 'owner') $$,
  'TFCNS', null,
  'NEGATIVO: sin consentimientos obligatorios la empresa no se crea');

-- --- Anon no llega a ninguna RPC de onboarding ------------------------------
-- Limpieza de los claims del authenticate_as previo: un anon real no trae
-- ningún sub (si quedaran, auth.uid() seguiría devolviendo al usuario).
do $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', 'anon', true);
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
end $$;
set local role anon;
select throws_ok(
  $$ select complete_candidate_onboarding() $$,
  '42501', null,
  'NEGATIVO: anon no puede ejecutar las RPC de onboarding');
reset role;

select * from finish();
rollback;
