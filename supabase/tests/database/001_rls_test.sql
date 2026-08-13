-- pgTAP — extraído de docs/DATA_MODEL.md §6 (T-007)

-- 020-candidate-visibility.test.sql
begin;
select plan(4);

-- seeds: empresa verificada (user_empresa_ok), empresa NO verificada (user_empresa_pend),
-- candidato publicado (cand_pub) y no publicado (cand_priv). Creados en 000-setup.sql
-- con tests.create_supabase_user() / tests.authenticate_as().

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

select * from finish();
rollback;
