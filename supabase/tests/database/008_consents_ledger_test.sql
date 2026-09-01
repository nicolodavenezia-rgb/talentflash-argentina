-- Bloque C (T-018): ledger de consentimientos append-only, versiones
-- vigentes, reconsentimiento y derivación de la publicación.
begin;
select plan(15);

-- --- Append-only real -------------------------------------------------------
select tests.authenticate_as('user_cand_pub');

select throws_ok(
  $$ update consents set granted = false where profile_id = auth.uid() $$,
  '42501', null,
  'NEGATIVO: los consentimientos no se actualizan jamás (append-only)');

select throws_ok(
  $$ delete from consents where profile_id = auth.uid() $$,
  '42501', null,
  'NEGATIVO: los consentimientos no se borran jamás (append-only)');

select throws_ok(
  $$ insert into consents (profile_id, consent_type, granted, version)
     values (tests.get_uuid('user_cand_priv'), 'data_processing', true,
             (select version from consent_versions where consent_type = 'data_processing')) $$,
  '42501', null,
  'NEGATIVO: nadie registra consentimientos a nombre de otra persona');

-- --- Sin duplicados y sin versiones inventadas ------------------------------
select lives_ok(
  $$ insert into consents (profile_id, consent_type, granted, version, user_agent)
     select auth.uid(), 'data_processing', true, cv.version, 'pgtap'
     from consent_versions cv where cv.consent_type = 'data_processing' $$,
  'POSITIVO: repetir exactamente el mismo comando no falla…');

select results_eq(
  $$ select count(*)::int from consents
     where profile_id = auth.uid() and consent_type = 'data_processing' $$,
  $$ values (1) $$,
  '…y tampoco crea una fila duplicada (el seed ya tenía una)');

select throws_ok(
  $$ insert into consents (profile_id, consent_type, granted, version)
     values (auth.uid(), 'ai_features', true, 'version-inventada') $$,
  'TFCNS', null,
  'NEGATIVO: no se puede aceptar una versión que no es la vigente');

select throws_ok(
  $$ insert into consents (profile_id, consent_type, granted, version)
     values (auth.uid(), 'ai_training', true,
             (select version from consent_versions where consent_type = 'data_processing')) $$,
  '42501', null,
  'NEGATIVO: ai_training no se solicita en el MVP y no puede otorgarse');

-- --- Revocar despublica; volver a otorgar republica -------------------------
select lives_ok(
  $$ insert into consents (profile_id, consent_type, granted, version, user_agent)
     select auth.uid(), 'video_profile_publication', false, cv.version, 'pgtap'
     from consent_versions cv where cv.consent_type = 'video_profile_publication' $$,
  'POSITIVO: la revocación es una fila nueva');

select results_eq(
  $$ select is_published from candidate_profiles where profile_id = auth.uid() $$,
  $$ values (false) $$,
  'POSITIVO: revocar la publicación despublica el perfil al instante');

select lives_ok(
  $$ insert into consents (profile_id, consent_type, granted, version, user_agent)
     select auth.uid(), 'video_profile_publication', true, cv.version, 'pgtap'
     from consent_versions cv where cv.consent_type = 'video_profile_publication' $$,
  'POSITIVO: volver a otorgar también es una fila nueva');

select results_eq(
  $$ select is_published, published_at is not null
     from candidate_profiles where profile_id = auth.uid() $$,
  $$ values (true, true) $$,
  'POSITIVO: con el consentimiento vigente el perfil vuelve a publicarse');

select results_eq(
  $$ select count(*)::int from consents
     where profile_id <> auth.uid() $$,
  $$ values (0) $$,
  'NEGATIVO: los consentimientos ajenos no se ven');

-- --- Reconsentimiento por versión nueva -------------------------------------
reset role;

insert into legal_documents (slug, version, title, body)
values ('privacidad', '2099-01-01', 'Política de privacidad (nueva)', 'Texto nuevo de prueba.');

update consent_versions set version = '2099-01-01'
where consent_type = 'video_profile_publication';

select results_eq(
  $$ select count(*)::int from candidate_profiles where is_published $$,
  $$ values (0) $$,
  'POSITIVO: subir la versión del texto de publicación despublica a todos (fail-closed)');

update consent_versions set version = '2099-01-01'
where consent_type = 'data_processing';

select ok(
  not private.mandatory_consents_current(tests.get_uuid('user_cand_pub')),
  'POSITIVO: una versión nueva de un obligatorio exige reconsentimiento');

-- --- El flujo jamás concedió ai_training ------------------------------------
select results_eq(
  $$ select count(*)::int from consents where consent_type = 'ai_training' $$,
  $$ values (0) $$,
  'POSITIVO: no existe ni una fila de ai_training en toda la base');

select * from finish();
rollback;
