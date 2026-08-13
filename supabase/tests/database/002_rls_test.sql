-- pgTAP — extraído de docs/DATA_MODEL.md §6 (T-007)

-- 040-applications.test.sql (extracto)
begin;
select plan(3);

select tests.authenticate_as('user_empresa_ok');   -- dueña del job_A
select results_eq(
  $$ select count(*)::int from job_applications where job_id = tests.get_uuid('job_A') $$,
  $$ values (1) $$,
  'POSITIVO: empresa ve postulaciones a SU oferta');

select tests.authenticate_as('user_empresa_otra'); -- otra empresa
select results_eq(
  $$ select count(*)::int from job_applications where job_id = tests.get_uuid('job_A') $$,
  $$ values (0) $$,
  'NEGATIVO: otra empresa no ve postulaciones ajenas');

select tests.authenticate_as('user_cand_pub');
select throws_ok(
  $$ insert into job_applications (job_id, candidate_profile_id)
     values (tests.get_uuid('job_draft'), candidate_id()) $$,
  '42501', null,
  'NEGATIVO: no se puede postular a una oferta en draft');

select * from finish();
rollback;
