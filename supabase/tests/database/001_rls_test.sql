-- Visibilidad de candidatos y confianza del rol de negocio.
begin;
select plan(10);

-- Los negativos de abajo cuentan 0 filas. Para que un fixture ausente no los
-- haga pasar de casualidad, primero se comprueba con privilegios (rol del
-- runner, sin RLS) que ambos candidatos existen y tienen el estado de
-- publicación que cada caso presupone.
select results_eq(
  $$ select count(*)::int from candidate_profiles
     where id in (tests.get_uuid('cand_pub'), tests.get_uuid('cand_priv')) $$,
  $$ values (2) $$,
  'FIXTURE: cand_pub y cand_priv existen (lectura privilegiada)');

select results_eq(
  $$ select is_published from candidate_profiles where id = tests.get_uuid('cand_pub') $$,
  $$ values (true) $$,
  'FIXTURE: cand_pub está publicado');

select results_eq(
  $$ select is_published from candidate_profiles where id = tests.get_uuid('cand_priv') $$,
  $$ values (false) $$,
  'FIXTURE: cand_priv no está publicado');

select tests.authenticate_as('user_empresa_ok');
-- Endurecido en el Bloque D (T-024): la policy de lectura empresarial directa
-- sobre candidate_profiles se eliminó (exponía birth_date y otras columnas
-- privadas). La empresa accede SOLO a la proyección con whitelist de campos
-- (get_candidate_public_profile, cubierta en 011_company_projection_test.sql).
-- Con los fixtures verificados arriba, este count=0 es significativo por sí
-- solo.
select results_eq(
  $$ select count(*)::int from candidate_profiles where id = tests.get_uuid('cand_pub') $$,
  $$ values (0) $$,
  'NEGATIVO: la empresa ya no lee la fila cruda de un candidato publicado (T-024)');

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
