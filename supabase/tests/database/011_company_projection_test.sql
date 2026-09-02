-- Bloque D (T-024): proyección pública del candidato para empresas.
-- La empresa NUNCA lee la tabla cruda: solo esta whitelist, fail-closed.
begin;
select plan(17);

-- --- Empresa verificada: accede a la proyección, y solo a la whitelist -------
select tests.authenticate_as('user_empresa_ok');

select results_eq(
  $$ select public.get_candidate_public_profile(tests.get_uuid('cand_pub')) is not null $$,
  $$ values (true) $$,
  'POSITIVO: empresa verificada obtiene la proyección de un candidato publicado');

-- La aserción más importante del bloque: el conjunto EXACTO de claves.
-- Si mañana alguien agrega un campo a la proyección, este test lo hace
-- explícito (y obliga a revisarlo contra PRIVACY/UX_FLOWS).
select results_eq(
  $$ select array_agg(k order by k)
     from jsonb_object_keys(
       public.get_candidate_public_profile(tests.get_uuid('cand_pub'))) as k $$,
  $$ values (array['availability', 'avatar_path', 'avatar_thumb_path', 'barrio',
                   'bio', 'candidate_profile_id', 'display_name', 'education',
                   'experience', 'headline', 'languages', 'localidad',
                   'presentation_available', 'provincia', 'sector', 'skills',
                   'weekly_availability', 'work_history', 'work_modes'
                  ]::text[]) $$,
  'POSITIVO: la proyección expone exactamente la whitelist aprobada de campos');

select results_eq(
  $$ select (public.get_candidate_public_profile(tests.get_uuid('cand_pub')))->>'display_name' $$,
  $$ values ('Candidato') $$,
  'POSITIVO: se muestra el nombre de pila, no el nombre completo (UX_FLOWS §6.2)');

select results_eq(
  $$ select ((public.get_candidate_public_profile(tests.get_uuid('cand_pub')))->>'presentation_available')::boolean $$,
  $$ values (true) $$,
  'POSITIVO: la proyección informa si hay presentación lista, sin detalles internos');

select results_eq(
  $$ select p ? 'birth_date' or p ? 'email' or p ? 'phone'
         or p ? 'expected_salary_min' or p ? 'expected_salary_max'
         or p ? 'is_published' or p ? 'profile_id' or p ? 'cv_url' or p ? 'video_id'
     from public.get_candidate_public_profile(tests.get_uuid('cand_pub')) as p $$,
  $$ values (false) $$,
  'NEGATIVO: nacimiento, contacto, salario y columnas internas jamás viajan');

-- --- Fail-closed indistinguible ----------------------------------------------
select results_eq(
  $$ select public.get_candidate_public_profile(tests.get_uuid('cand_priv')) is null $$,
  $$ values (true) $$,
  'NEGATIVO: un candidato no publicado devuelve null');

select tests.authenticate_as('user_empresa_pend_seed');
select results_eq(
  $$ select public.get_candidate_public_profile(tests.get_uuid('cand_pub')) is null
        and public.get_candidate_public_profile(gen_random_uuid()) is null $$,
  $$ values (true) $$,
  'NEGATIVO: empresa pendiente recibe null igual para candidato real e inexistente');

-- --- Bloqueo mutuo -------------------------------------------------------------
select tests.authenticate_as('user_empresa_ok');
select results_eq(
  $$ select public.get_candidate_public_profile(tests.get_uuid('cand_blocker')) is null $$,
  $$ values (true) $$,
  'NEGATIVO: el bloqueo del candidato corta la proyección para esa empresa');

select tests.authenticate_as('user_empresa_otra');
select results_eq(
  $$ select public.get_candidate_public_profile(tests.get_uuid('cand_blocker')) is not null $$,
  $$ values (true) $$,
  'POSITIVO: otra empresa sin bloqueo sí ve al mismo candidato');

-- --- Roles sin acceso -----------------------------------------------------------
select tests.authenticate_as('user_cand_priv');
select results_eq(
  $$ select public.get_candidate_public_profile(tests.get_uuid('cand_pub')) is null $$,
  $$ values (true) $$,
  'NEGATIVO: un candidato no puede usar la proyección empresarial');

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
  $$ select public.get_candidate_public_profile('00000000-0000-4000-8000-000000000101'::uuid) $$,
  '42501', null,
  'NEGATIVO: anon no puede ejecutar la proyección');

-- --- La tabla cruda quedó cerrada ----------------------------------------------
select tests.authenticate_as('user_empresa_ok');
select results_eq(
  $$ select count(*)::int from candidate_profiles $$,
  $$ values (0) $$,
  'NEGATIVO: una empresa no lee NINGUNA fila cruda de candidate_profiles');

-- --- Videos: la fila cruda quedó fuera del alcance de la empresa ----------------
-- La rama "candidato publicado" de videos_company_select se eliminó en 0023:
-- exponía owner_profile_id (el id de auth del candidato) y permitía enumerar
-- candidatos por REST. La reproducción para empresas llega con el Bloque K
-- (URLs firmadas, T-054); hoy la empresa solo conoce el booleano
-- presentation_available de la proyección.
select results_eq(
  $$ select count(*)::int from videos
     where id = 'd0000000-0000-4000-8000-000000000004' $$,
  $$ values (0) $$,
  'NEGATIVO: un video en processing no es visible para la empresa');

select tests.authenticate_as('user_empresa_otra');
select results_eq(
  $$ select count(*)::int from videos
     where id = 'd0000000-0000-4000-8000-000000000001' $$,
  $$ values (0) $$,
  'NEGATIVO: ni el video LISTO de un candidato publicado se lee por REST (Bloque K)');

select results_eq(
  $$ select count(*)::int from videos $$,
  $$ values (0) $$,
  'NEGATIVO: cero filas de videos para la empresa: sin enumeración de candidatos');

-- --- Revocar el consentimiento corta la proyección al instante ------------------
select tests.authenticate_as('user_cand_pub');
select lives_ok(
  $$ insert into consents (profile_id, consent_type, granted, version)
     select auth.uid(), 'video_profile_publication', false, cv.version
     from consent_versions cv
     where cv.consent_type = 'video_profile_publication' $$,
  'POSITIVO: el candidato revoca la publicación de su perfil');

select tests.authenticate_as('user_empresa_ok');
select results_eq(
  $$ select public.get_candidate_public_profile(tests.get_uuid('cand_pub')) is null $$,
  $$ values (true) $$,
  'NEGATIVO: revocado el consentimiento, la proyección devuelve null');

select * from finish();
rollback;
