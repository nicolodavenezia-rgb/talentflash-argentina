-- Bloque D (T-021/T-025): lectura y edición del perfil propio por RPC,
-- validación de contenido server-side y preparación para postularse.
begin;
select plan(31);

-- --- Lectura del perfil propio -----------------------------------------------
select tests.authenticate_as('user_cand_pub');

select results_eq(
  $$ select ((public.get_my_candidate_profile())->>'candidate_profile_id')::uuid
            = tests.get_uuid('cand_pub') $$,
  $$ values (true) $$,
  'POSITIVO: get_my_candidate_profile devuelve el perfil del dueño');

select results_eq(
  $$ select (public.get_my_candidate_profile())->>'presentation_status' $$,
  $$ values ('ready') $$,
  'POSITIVO: el estado de presentación refleja el video listo del seed');

select results_eq(
  $$ select ((public.get_my_candidate_profile())->>'application_ready')::boolean $$,
  $$ values (true) $$,
  'POSITIVO: un perfil con mínimos completos está listo para postularse');

-- --- Edición por parche: whitelist, limpieza explícita e idempotencia --------
select lives_ok(
  $$ select public.update_my_candidate_profile(
       '{"headline": "Busco turno noche en salón", "bio": "   ",
         "skills": ["barismo", "latte art"],
         "expected_salary_min": 1200000, "expected_salary_max": 1500000}') $$,
  'POSITIVO: el parche actualiza el perfil propio');

select results_eq(
  $$ select headline, bio, skills from candidate_profiles
     where profile_id = auth.uid() $$,
  $$ values ('Busco turno noche en salón'::text, null::text,
             array['barismo', 'latte art']) $$,
  'POSITIVO: persiste el parche y la bio de solo espacios queda limpia (null)');

select lives_ok(
  $$ select public.update_my_candidate_profile(
       '{"headline": "Busco turno noche en salón", "bio": null,
         "skills": ["barismo", "latte art"],
         "expected_salary_min": 1200000, "expected_salary_max": 1500000}') $$,
  'POSITIVO: repetir el mismo parche es idempotente');

select lives_ok(
  $$ select public.update_my_candidate_profile(
       '{"expected_salary_min": null, "expected_salary_max": null,
         "weekly_availability": null}') $$,
  'POSITIVO: los campos opcionales se limpian de forma explícita con null');

select results_eq(
  $$ select expected_salary_min is null, expected_salary_max is null,
            weekly_availability
     from candidate_profiles where profile_id = auth.uid() $$,
  $$ values (true, true, '[]'::jsonb) $$,
  'POSITIVO: la limpieza deja el salario en null y las franjas vacías');

select lives_ok(
  $$ select public.update_my_candidate_profile('{"skills": null}') $$,
  'POSITIVO: "skills": null también limpia la lista (semántica del parche)');

select results_eq(
  $$ select skills from candidate_profiles where profile_id = auth.uid() $$,
  $$ values ('{}'::text[]) $$,
  'POSITIVO: la lista de habilidades quedó vacía tras el null explícito');

select lives_ok(
  $$ select public.update_my_candidate_profile('{"full_name": "  Ana María Prueba  "}') $$,
  'POSITIVO: el nombre se edita desde el perfil');

select results_eq(
  $$ select full_name from profiles where id = auth.uid() $$,
  $$ values ('Ana María Prueba'::text) $$,
  'POSITIVO: el nombre queda normalizado sin espacios sobrantes');

-- --- Claves no permitidas: fail-closed ---------------------------------------
select throws_ok(
  $$ select public.update_my_candidate_profile('{"is_published": true}') $$,
  'TFDAT', null,
  'NEGATIVO: is_published no se puede editar desde el parche');

select throws_ok(
  $$ select public.update_my_candidate_profile(
       format('{"video_id": "%s"}', gen_random_uuid())::jsonb) $$,
  'TFDAT', null,
  'NEGATIVO: video_id no se puede editar con un UUID arbitrario');

select throws_ok(
  $$ select public.update_my_candidate_profile('{"onboarding_completed": true}') $$,
  'TFDAT', null,
  'NEGATIVO: onboarding_completed no es editable desde el perfil');

-- --- Validación de contenido server-side -------------------------------------
select throws_ok(
  $$ select public.update_my_candidate_profile(
       '{"localidad_id": "b1000000-0000-4000-8000-000000000002"}') $$,
  'TFDAT', null,
  'NEGATIVO: una localidad de otra provincia se rechaza');

select throws_ok(
  $$ select public.update_my_candidate_profile(
       format('{"sector_id": "%s"}', gen_random_uuid())::jsonb) $$,
  'TFDAT', null,
  'NEGATIVO: un sector inexistente se rechaza');

select throws_ok(
  $$ select public.update_my_candidate_profile(
       '{"expected_salary_min": 2000000, "expected_salary_max": 1000000}') $$,
  '23514', null,
  'NEGATIVO: el salario invertido viola el check de rango');

select throws_ok(
  $$ select public.update_my_candidate_profile(
       '{"work_history": [{"empresa": "Bar X", "desde": "2020-01"}]}') $$,
  'TFDAT', null,
  'NEGATIVO: una experiencia sin puesto se rechaza');

select throws_ok(
  $$ select public.update_my_candidate_profile(
       '{"work_history": [{"empresa": "Bar X", "puesto": "Mozo",
          "desde": "2020-01", "sueldo": 1}]}') $$,
  'TFDAT', null,
  'NEGATIVO: una experiencia con campos no permitidos se rechaza');

select throws_ok(
  $$ select public.update_my_candidate_profile(
       '{"education": [{"nivel": "doctorado-honoris", "institucion": "X"}]}') $$,
  'TFDAT', null,
  'NEGATIVO: un nivel educativo fuera del catálogo se rechaza');

select throws_ok(
  $$ select public.update_my_candidate_profile(
       '{"weekly_availability": [
          {"day": "lun", "start": "09:00", "end": "13:00"},
          {"day": "lun", "start": "12:00", "end": "15:00"}]}') $$,
  'TFDAT', null,
  'NEGATIVO: dos franjas superpuestas el mismo día se rechazan');

select throws_ok(
  $$ select public.update_my_candidate_profile(
       '{"weekly_availability": [
          {"day": "vie", "start": "22:00", "end": "02:00"},
          {"day": "sab", "start": "01:00", "end": "03:00"}]}') $$,
  'TFDAT', null,
  'NEGATIVO: un turno que cruza la medianoche también choca con el día siguiente');

select lives_ok(
  $$ select public.update_my_candidate_profile(
       '{"weekly_availability": [
          {"day": "vie", "start": "22:00", "end": "02:00"},
          {"day": "sab", "start": "10:00", "end": "14:00"}]}') $$,
  'POSITIVO: un turno nocturno que cruza la medianoche sin chocar es válido');

select throws_ok(
  $$ select public.update_my_candidate_profile(
       '{"skills": ["café", "Café"]}') $$,
  'TFDAT', null,
  'NEGATIVO: las habilidades duplicadas (sin distinguir mayúsculas) se rechazan');

-- --- Ownership y columnas protegidas -----------------------------------------
select tests.authenticate_as('user_cand_priv');
select results_eq(
  $$ with intento as (
       update candidate_profiles set headline = 'hackeado'
       where id = tests.get_uuid('cand_pub')
       returning 1
     ) select count(*)::int from intento $$,
  $$ values (0) $$,
  'NEGATIVO: otro candidato no puede editar un perfil ajeno (RLS filtra la fila)');

select throws_ok(
  $$ update candidate_profiles set published_at = now()
     where profile_id = auth.uid() $$,
  '42501', null,
  'NEGATIVO: published_at es una columna protegida frente al cliente');

-- --- Cruce de roles y anon ----------------------------------------------------
select tests.authenticate_as('user_empresa_ok');
select throws_ok(
  $$ select public.get_my_candidate_profile() $$,
  '42501', null,
  'NEGATIVO: una empresa no puede leer el RPC de perfil de candidato');

select throws_ok(
  $$ select public.update_my_candidate_profile('{"headline": "x"}') $$,
  '42501', null,
  'NEGATIVO: una empresa no puede editar por el RPC de candidato');

-- --- Consistencia con el onboarding: mismo límite de nombre -------------------
select tests.authenticate_as('user_cand_priv');
select throws_ok(
  $$ select public.save_candidate_onboarding(
       repeat('x', 81), null, null, null, null, null, null, null) $$,
  'TFDAT', null,
  'NEGATIVO: el guardado del wizard también acota el nombre a 80 caracteres');

-- --- Preparación para postularse (helper server-side para T-040) --------------
reset role;
select results_eq(
  $$ select private.candidate_application_ready(tests.get_uuid('user_cand_pub')),
            private.candidate_application_ready('00000000-0000-4000-8000-000000000119'::uuid) $$,
  $$ values (true, false) $$,
  'POSITIVO: readiness true con mínimos completos y false con onboarding a medio');

select * from finish();
rollback;
