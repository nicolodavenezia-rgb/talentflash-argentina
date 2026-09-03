-- Bloque C (T-019/T-020): preferencias opt-in, documentos legales públicos y
-- coherencia del seed con la derivación server-side.
begin;
select plan(16);

-- --- Preferencias de notificaciones: opt-in y dueño único -------------------
select tests.authenticate_as('user_cand_pub');

select lives_ok(
  $$ insert into notification_prefs (profile_id, category)
     values (auth.uid(), 'invitation') $$,
  'POSITIVO: el usuario crea su preferencia con los defaults de la tabla');

select results_eq(
  $$ select push_enabled, email_enabled, in_app_enabled
     from notification_prefs
     where profile_id = auth.uid() and category = 'invitation' $$,
  $$ values (false, false, true) $$,
  'POSITIVO: sin decisión explícita, push y correo quedan APAGADOS (opt-in)');

select lives_ok(
  $$ insert into notification_prefs (profile_id, category, push_enabled, email_enabled, in_app_enabled)
     values (auth.uid(), 'invitation', true, false, true)
     on conflict (profile_id, category)
       do update set push_enabled = excluded.push_enabled,
                     email_enabled = excluded.email_enabled,
                     in_app_enabled = excluded.in_app_enabled $$,
  'POSITIVO: el guardado es un upsert idempotente');

select results_eq(
  $$ select count(*)::int from notification_prefs
     where profile_id = auth.uid() and category = 'invitation' $$,
  $$ values (1) $$,
  'POSITIVO: reintentar el guardado no duplica filas');

select throws_ok(
  $$ insert into notification_prefs (profile_id, category, in_app_enabled, email_enabled)
     values (auth.uid(), 'system', false, true) $$,
  '42501', null,
  'NEGATIVO: los avisos de cuenta no pueden apagarse in-app');

select throws_ok(
  $$ insert into notification_prefs (profile_id, category, in_app_enabled, email_enabled)
     values (auth.uid(), 'system', true, false) $$,
  '42501', null,
  'NEGATIVO: los avisos de cuenta no pueden apagarse por correo');

select lives_ok(
  $$ insert into notification_prefs (profile_id, category, push_enabled, in_app_enabled, email_enabled)
     values (auth.uid(), 'system', true, true, true) $$,
  'POSITIVO: el push de cuenta sí es una decisión del usuario');

select throws_ok(
  $$ insert into notification_prefs (profile_id, category)
     values (tests.get_uuid('user_cand_priv'), 'message') $$,
  '42501', null,
  'NEGATIVO: nadie configura preferencias ajenas (RLS)');

select results_eq(
  $$ select count(*)::int from notification_prefs
     where profile_id = tests.get_uuid('user_empresa_ok') $$,
  $$ values (0) $$,
  'NEGATIVO: las preferencias ajenas tampoco se leen');

-- --- Documentos legales: públicos de verdad, inmutables para clientes -------
-- Limpieza de los claims del authenticate_as previo: un anon real no trae
-- ningún sub (si quedaran, auth.uid() seguiría devolviendo al usuario).
do $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', 'anon', true);
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
end $$;
set local role anon;

select results_eq(
  $$ select count(*)::int from legal_documents where slug in ('terminos', 'privacidad') $$,
  $$ values (2) $$,
  'POSITIVO: anon lee los documentos legales (rutas /legal/* sin sesión)');

select results_eq(
  $$ select count(*)::int from consent_versions $$,
  $$ values (5) $$,
  'POSITIVO: anon lee las versiones vigentes; ai_training NO tiene versión');

select throws_ok(
  $$ insert into legal_documents (slug, version, title, body)
     values ('terminos', 'v-hack', 'x', 'x') $$,
  '42501', null,
  'NEGATIVO: anon no escribe documentos legales');

reset role;
select tests.authenticate_as('user_cand_pub');
select throws_ok(
  $$ update consent_versions set version = 'v-hack'
     where consent_type = 'data_processing' $$,
  '42501', null,
  'NEGATIVO: un cliente autenticado no cambia las versiones vigentes');

-- --- Seed coherente con la derivación (nunca estados imposibles) ------------
reset role;

select results_eq(
  $$ select count(*)::int
     from candidate_profiles cp
     join profiles p on p.id = cp.profile_id
     where cp.is_published is distinct from (
       p.onboarding_completed
       and p.deleted_at is null
       and private.candidate_min_data_complete(cp.profile_id)
       and private.consent_current(cp.profile_id, 'video_profile_publication')
       and exists (select 1 from auth.users u
                   where u.id = p.id and u.email_confirmed_at is not null)
     ) $$,
  $$ values (0) $$,
  'POSITIVO: cada is_published del seed coincide con la derivación server-side');

-- Solo los usuarios del seed (los fixtures de 000_setup agregan otros).
select results_eq(
  $$ select
       (select count(*)::int from candidate_profiles where is_published),
       (select count(*)::int from profiles p
        where p.role = 'candidate' and p.onboarding_completed
          and p.email like '%@dev.talentflash.test'),
       (select count(*)::int from profiles p
        where p.role = 'company' and not p.onboarding_completed
          and p.email like '%@dev.talentflash.test') $$,
  $$ values (15, 18, 1) $$,
  'POSITIVO: seed = 15 publicados, 18 candidatos completos, 1 empresa a medio hacer');

select results_eq(
  $$ select count(*)::int
     from profiles p
     left join company_members cm on cm.profile_id = p.id
     where p.email = 'empresa6@dev.talentflash.test' and cm.id is null $$,
  $$ values (1) $$,
  'POSITIVO: empresa6 existe, sin empresa creada (ejemplo de wizard pendiente)');

select * from finish();
rollback;
