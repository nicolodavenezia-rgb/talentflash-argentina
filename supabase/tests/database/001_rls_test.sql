-- Visibilidad de candidatos y confianza del rol de negocio.
begin;
select plan(7);

select tests.authenticate_as('user_empresa_ok');
select results_eq(
  $$ select count(*)::int from candidate_profiles where id = tests.get_uuid('cand_pub') $$,
  $$ values (1) $$,
  'POSITIVO: empresa verificada ve perfil de candidato publicado');

select results_eq(
  $$ select count(*)::int from candidate_profiles where id = tests.get_uuid('cand_priv') $$,
  $$ values (0) $$,
  'NEGATIVO: empresa verificada NO ve perfil no publicado');

select tests.authenticate_as('user_empresa_pend');
select results_eq(
  $$ select count(*)::int from candidate_profiles where id = tests.get_uuid('cand_pub') $$,
  $$ values (0) $$,
  'NEGATIVO: empresa NO verificada no ve ningún candidato');

select tests.authenticate_as('user_cand_pub');
select lives_ok(
  $$ update candidate_profiles set headline = 'nuevo' where profile_id = auth.uid() $$,
  'POSITIVO: candidato edita su propio perfil');

select throws_ok(
  $$ update profiles set role = 'admin' where id = auth.uid() $$,
  '42501', null,
  'NEGATIVO: un usuario no puede promover su propio profile a admin');

select tests.authenticate_as('user_requested_admin');
select results_eq(
  $$ select role::text from profiles where id = tests.get_uuid('user_requested_admin') $$,
  $$ values ('candidate') $$,
  'NEGATIVO: solicitar admin en user_metadata crea un profile candidate');

reset role;
select results_eq(
  $$ select raw_app_meta_data ->> 'role'
     from auth.users where id = tests.get_uuid('user_requested_admin') $$,
  $$ values ('candidate') $$,
  'POSITIVO: el claim confiable de app_metadata coincide con el rol saneado');

select * from finish();
rollback;
