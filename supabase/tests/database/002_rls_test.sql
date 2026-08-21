-- Ownership y mutaciones permitidas en postulaciones.
begin;
select plan(7);

select tests.authenticate_as('user_empresa_ok');
select results_eq(
  $$ select count(*)::int from job_applications where job_id = tests.get_uuid('job_A') $$,
  $$ values (1) $$,
  'POSITIVO: empresa ve postulaciones a SU oferta');

select tests.authenticate_as('user_empresa_otra');
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

select throws_ok(
  $$ update job_applications
     set cover_note = 'alterada', status = 'withdrawn'
     where id = tests.get_uuid('application_A') $$,
  '42501', null,
  'NEGATIVO: candidato no altera el contenido de una postulación');

select lives_ok(
  $$ update job_applications
     set status = 'withdrawn'
     where id = tests.get_uuid('application_A') $$,
  'POSITIVO: candidato puede retirar su postulación');

select tests.authenticate_as('user_empresa_ok');
select lives_ok(
  $$ update job_applications
     set status = 'viewed', viewed_at = now()
     where id = tests.get_uuid('application_A') $$,
  'POSITIVO: empresa dueña actualiza estado y viewed_at');

select throws_ok(
  $$ update job_applications
     set cover_note = 'alterada por empresa'
     where id = tests.get_uuid('application_A') $$,
  '42501', null,
  'NEGATIVO: empresa no altera campos aportados por el candidato');

select * from finish();
rollback;
