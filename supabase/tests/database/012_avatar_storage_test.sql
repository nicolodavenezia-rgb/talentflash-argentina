-- Bloque D (T-022): bucket privado de avatares y su policy de lectura.
-- Las escrituras van SOLO por la Edge Function (service role): no existe
-- ninguna policy de INSERT/UPDATE/DELETE para clientes. La expiración real de
-- las URLs firmadas y el pipeline de bytes se prueban en `npm run storage:test`
-- (pgTAP no puede vencer una URL firmada).
begin;
select plan(16);

-- --- El bucket es privado y acotado ------------------------------------------
select results_eq(
  $$ select public, file_size_limit::bigint from storage.buckets where id = 'avatars' $$,
  $$ values (false, 2097152::bigint) $$,
  'POSITIVO: el bucket avatars es privado con límite de 2 MiB');

-- Objetos sintéticos para ejercitar la policy de lectura (los bytes reales
-- los sube la Edge Function; acá solo interesan las filas y el RLS).
reset role;
select lives_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('avatars', tests.get_uuid('cand_pub') || '/avatar.jpg'),
            ('avatars', tests.get_uuid('cand_pub') || '/thumb.jpg'),
            ('avatars', tests.get_uuid('cand_blocker') || '/avatar.jpg') $$,
  'POSITIVO: fixtures de objetos creadas (contexto privilegiado)');

-- --- Lectura: dueño sí, ajenos no --------------------------------------------
select tests.authenticate_as('user_cand_pub');
select results_eq(
  $$ select count(*)::int from storage.objects
     where bucket_id = 'avatars'
       and name like tests.get_uuid('cand_pub') || '/%' $$,
  $$ values (2) $$,
  'POSITIVO: el dueño ve su avatar y su thumbnail');

select results_eq(
  $$ select count(*)::int from storage.objects
     where bucket_id = 'avatars'
       and name like tests.get_uuid('cand_blocker') || '/%' $$,
  $$ values (0) $$,
  'NEGATIVO: un candidato no ve el avatar de otro candidato');

select tests.authenticate_as('user_empresa_ok');
select results_eq(
  $$ select count(*)::int from storage.objects
     where bucket_id = 'avatars'
       and name like tests.get_uuid('cand_pub') || '/%' $$,
  $$ values (2) $$,
  'POSITIVO: una empresa verificada lee el avatar de un candidato que puede ver');

select results_eq(
  $$ select count(*)::int from storage.objects
     where bucket_id = 'avatars'
       and name like tests.get_uuid('cand_blocker') || '/%' $$,
  $$ values (0) $$,
  'NEGATIVO: el bloqueo también corta el acceso al avatar');

select tests.authenticate_as('user_empresa_pend_seed');
select results_eq(
  $$ select count(*)::int from storage.objects where bucket_id = 'avatars' $$,
  $$ values (0) $$,
  'NEGATIVO: una empresa pendiente de verificación no lee ningún avatar');

set local role anon;
select results_eq(
  $$ select count(*)::int from storage.objects where bucket_id = 'avatars' $$,
  $$ values (0) $$,
  'NEGATIVO: anon no lee ningún avatar');

-- --- Escrituras de clientes: cerradas ----------------------------------------
select tests.authenticate_as('user_cand_pub');
select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('avatars', tests.get_uuid('cand_pub') || '/hack.jpg') $$,
  '42501', null,
  'NEGATIVO: ni siquiera el dueño escribe directo en el bucket (solo la Edge Function)');

select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('avatars', tests.get_uuid('cand_priv') || '/avatar.jpg') $$,
  '42501', null,
  'NEGATIVO: escribir en el namespace de otra persona también falla');

-- Sin policies de UPDATE/DELETE, RLS no expone ninguna fila para mutar:
-- la sentencia "funciona" pero afecta exactamente cero objetos.
select results_eq(
  $$ with intento as (
       update storage.objects set name = name || '.hack'
       where bucket_id = 'avatars'
       returning 1
     ) select count(*)::int from intento $$,
  $$ values (0) $$,
  'NEGATIVO: un cliente no puede actualizar ningún objeto del bucket');

-- El borrado directo lo bloquea además una guardia propia del esquema de
-- Storage ("Use the Storage API instead"), con 42501 antes de evaluar filas.
select throws_ok(
  $$ delete from storage.objects where bucket_id = 'avatars' $$,
  '42501', null,
  'NEGATIVO: un cliente no puede borrar ningún objeto del bucket');

-- --- Paths maliciosos: la función de lectura falla cerrada --------------------
select results_eq(
  $$ select public.can_read_avatar_object('../../etc/passwd'),
            public.can_read_avatar_object('no-es-uuid/avatar.jpg'),
            public.can_read_avatar_object('') $$,
  $$ values (false, false, false) $$,
  'NEGATIVO: paths malformados o de travesía devuelven false, nunca error');

select results_eq(
  $$ select public.can_read_avatar_object(tests.get_uuid('cand_pub') || '/avatar.jpg') $$,
  $$ values (true) $$,
  'POSITIVO: el dueño puede leer su propio path canónico');

-- --- Revocar la publicación corta el avatar para empresas ---------------------
select lives_ok(
  $$ insert into consents (profile_id, consent_type, granted, version)
     select auth.uid(), 'video_profile_publication', false, cv.version
     from consent_versions cv
     where cv.consent_type = 'video_profile_publication' $$,
  'POSITIVO: el candidato revoca la publicación');

select tests.authenticate_as('user_empresa_ok');
select results_eq(
  $$ select count(*)::int from storage.objects
     where bucket_id = 'avatars'
       and name like tests.get_uuid('cand_pub') || '/%' $$,
  $$ values (0) $$,
  'NEGATIVO: revocado el consentimiento, la empresa pierde también el avatar');

select * from finish();
rollback;
