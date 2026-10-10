-- Bloque E — el criterio de aceptación de T-028 que 0028 había diferido:
-- "una empresa no verificada no puede publicar ofertas", ahora server-side.
--
-- Hasta 0031 `public.company_can_publish` existía, estaba probada contra los
-- cuatro estados… y no la llamaba nadie. `jobs_company_write` (0015) exigía
-- solo membresía, y `public.jobs` es superficie de PostgREST desde 0018: una
-- empresa `pending` podía insertar una oferta con `status = 'active'` y
-- publicarla. Este archivo prueba la puerta cerrada, sus dos lados, y de paso
-- las tres puertas de membresía que 0031 serializó.
--
-- Usuarios locales en el namespace 93000000, emails @tests.local (no
-- @dev.talentflash.test, para no contaminar los conteos de 009).
begin;
select plan(56);

-- --- Fixtures locales -------------------------------------------------------

insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                        confirmation_token, recovery_token,
                        email_change_token_new, email_change, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '93000000-0000-4000-8000-000000000001',
   'authenticated', 'authenticated', 'pub-staff-otra@tests.local',
   crypt('password123', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"role":"company"}',
   '', '', '', '', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '93000000-0000-4000-8000-000000000002',
   'authenticated', 'authenticated', 'pub-sin-empresa@tests.local',
   crypt('password123', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"role":"company"}',
   '', '', '', '', now(), now());

insert into tests.identifiers (identifier, id) values
  ('p_staff_otra', '93000000-0000-4000-8000-000000000001'),
  ('p_sin_empresa', '93000000-0000-4000-8000-000000000002')
on conflict (identifier) do update set id = excluded.id;

-- Geo válida para las ofertas nuevas: una localidad real y SU provincia (las
-- dos del mismo registro, si no el check de coherencia rechazaría el insert).
insert into tests.identifiers (identifier, id)
select 'geo_prov',
       (select l.provincia_id from public.geo_localidades l order by l.id limit 1)
union all
select 'geo_loc',
       (select l.id from public.geo_localidades l order by l.id limit 1)
-- Un barrio de ESA localidad. La primera por id es CABA, que tiene barrios
-- cargados, y desde 0032 (D2) una oferta `active` en una localidad con barrios
-- necesita el suyo: sin esto, las inserciones `active` de abajo morirían con
-- TFDAT en el validador antes de llegar a la puerta de publicación que este
-- archivo prueba, y los negativos pasarían por el motivo equivocado.
union all
select 'geo_barrio',
       (select b.id from public.geo_barrios b
        where b.localidad_id = (select l.id from public.geo_localidades l order by l.id limit 1)
        order by b.id limit 1)
on conflict (identifier) do update set id = excluded.id;

-- `p_staff_otra` integra company_ok como recruiter: es la cuenta que prueba
-- que "ya integro otra empresa" bloquea la creación de una segunda.
insert into public.company_members (company_id, profile_id, member_role)
values (tests.get_uuid('company_ok'), tests.get_uuid('p_staff_otra'), 'recruiter');

-- Statement de alta de oferta, parametrizado. Todas las columnas NOT NULL de
-- `jobs` (0007) van explícitas: si mañana se agrega una, este helper falla y
-- se ve, en vez de que los negativos empiecen a pasar por un error de columna.
create or replace function tests.sql_new_job(
  p_company_key text,
  p_status text,
  p_created_by_expr text default 'auth.uid()'
) returns text
language sql immutable as $$
  select format($f$
    insert into public.jobs (
      company_id, created_by, title, description,
      salary_min, salary_max, contract_type, jornada,
      schedule_days, schedule_detail, work_mode,
      provincia_id, localidad_id, barrio_id, experience, availability,
      expires_at, status)
    values (
      tests.get_uuid(%L), %s, 'Oferta de prueba', 'Descripción de prueba',
      100000, 200000, 'relacion_dependencia', 'full_time',
      array['lun','mar','mie','jue','vie'], '9 a 18 hs', 'presencial',
      tests.get_uuid('geo_prov'), tests.get_uuid('geo_loc'), tests.get_uuid('geo_barrio'),
      'sin_experiencia', 'inmediata',
      now() + interval '30 days', %L::public.job_status)
  $f$, p_company_key, p_created_by_expr, p_status);
$$;

-- ===========================================================================
-- A. El fixture no es vacío
-- ===========================================================================

select results_eq(
  $$ select
       (select cp.verification_status::text from public.company_profiles cp
        where cp.id = tests.get_uuid('company_ok')),
       (select cp.verification_status::text from public.company_profiles cp
        where cp.id = tests.get_uuid('company_pend')) $$,
  $$ values ('approved', 'pending') $$,
  'FIXTURE: company_ok está approved y company_pend está pending');

select results_eq(
  $$ select public.company_can_publish(tests.get_uuid('company_ok')),
            public.company_can_publish(tests.get_uuid('company_pend')) $$,
  $$ values (true, false) $$,
  'FIXTURE: el helper ya distinguía los dos casos (lo que faltaba era usarlo)');

-- ===========================================================================
-- B. Empresa `pending`: prepara borradores, no publica
-- ===========================================================================

select tests.authenticate_as('user_empresa_pend');

select lives_ok(
  tests.sql_new_job('company_pend', 'draft'),
  'POSITIVO: una empresa sin verificar SÍ puede crear un borrador');

select throws_ok(
  tests.sql_new_job('company_pend', 'active'),
  '42501', null,
  'NEGATIVO: una empresa pending no puede insertar una oferta ya activa');

select throws_ok(
  $$ update public.jobs set status = 'active'
     where company_id = tests.get_uuid('company_pend') and status = 'draft' $$,
  '42501', null,
  'NEGATIVO: una empresa pending no puede pasar su borrador a active');

-- Se cuentan SOLO las ofertas que creo este archivo: el seed ya le dejo a
-- company_pend dos ofertas activas escritas como backend (0031 hace que dejen
-- de ser publicas, que es justo lo que prueba la seccion E).
select results_eq(
  $$ select count(*)::int, count(*) filter (where status = 'draft')::int
     from public.jobs
     where company_id = tests.get_uuid('company_pend')
       and title = 'Oferta de prueba' $$,
  $$ values (1, 1) $$,
  'NEGATIVO: tras los dos rechazos queda solo el borrador, y sigue en draft');

-- Los otros dos estados que no son `approved`.
reset role;
update public.company_profiles set verification_status = 'rejected'
where id = tests.get_uuid('company_pend');
select tests.authenticate_as('user_empresa_pend');

select throws_ok(
  tests.sql_new_job('company_pend', 'active'),
  '42501', null,
  'NEGATIVO: una empresa rejected tampoco publica');

reset role;
update public.company_profiles set verification_status = 'in_review'
where id = tests.get_uuid('company_pend');
select tests.authenticate_as('user_empresa_pend');

select throws_ok(
  tests.sql_new_job('company_pend', 'active'),
  '42501', null,
  'NEGATIVO: in_review no es approved y tampoco publica');

-- `verification_status` es un enum de cuatro valores: un estado "desconocido"
-- no es representable en la columna. Lo que hace que cualquier valor que no
-- sea `approved` caiga del lado del NO es la lista blanca del helper, no una
-- enumeración de los estados malos.
--
-- Se recorre el enum PONIENDO la empresa en cada estado. La versión anterior
-- de esta aserción filtraba el enum en el WHERE y llamaba al helper una sola
-- vez —`EXPLAIN` la mostraba como `One-Time Filter`—, así que el `unnest` era
-- decorativo y el resultado no dependía del estado recorrido.
reset role;
do $$
declare
  estado text;
  matriz text := '';
begin
  for estado in
    select x::text from unnest(enum_range(null::public.verification_status)) x order by 1
  loop
    update public.company_profiles set verification_status = estado::public.verification_status
     where id = tests.get_uuid('company_pend');
    matriz := matriz || estado || '='
              || public.company_can_publish(tests.get_uuid('company_pend'))::text || ' ';
  end loop;
  perform set_config('tests.matriz_publicacion', btrim(matriz), true);
end $$;

select results_eq(
  $$ select current_setting('tests.matriz_publicacion') $$,
  $$ values ('approved=true in_review=false pending=false rejected=false'::text) $$,
  'NEGATIVO: recorriendo los CUATRO estados, el helper dice true solo con approved');

-- Y una empresa dada de baja tampoco publica, ni estando approved.
update public.company_profiles
   set verification_status = 'approved'::public.verification_status, deleted_at = now()
 where id = tests.get_uuid('company_pend');

select results_eq(
  $$ select public.company_can_publish(tests.get_uuid('company_pend')) $$,
  $$ values (false) $$,
  'NEGATIVO: approved + deleted_at tampoco publica');

update public.company_profiles
   set verification_status = 'in_review'::public.verification_status, deleted_at = null
 where id = tests.get_uuid('company_pend');

-- ===========================================================================
-- C. Empresa `approved`: sí publica
-- ===========================================================================

-- `job_draft` es una oferta del seed que 000_setup pasó a borrador, y conserva
-- el `expires_at` que le dio el seed: `now() + 30 días` al momento de sembrar.
-- Desde 0032 (D1) publicar exige un vencimiento futuro y a no más de 60 días,
-- así que en una base local sembrada hace más de 30 días el POSITIVO de abajo
-- moriría con TFDAT por la edad del seed, no por la puerta de publicación que
-- prueba este archivo. Se renueva como backend: `protect_job_lifecycle` mira
-- `current_user` y deja pasar; `protect_job_write` mira el JWT (los claims
-- siguen puestos después de `reset role`), pero solo objeta cambios de
-- company_id, created_by o created_at; y el validador no pide nada de D1 a un
-- borrador.
reset role;
update public.jobs set expires_at = now() + interval '30 days'
where id = tests.get_uuid('job_draft');

select tests.authenticate_as('user_empresa_ok');

select lives_ok(
  tests.sql_new_job('company_ok', 'active'),
  'POSITIVO: una empresa approved sí puede insertar una oferta activa');

select lives_ok(
  $$ update public.jobs set status = 'active'
     where id = tests.get_uuid('job_draft') $$,
  'POSITIVO: una empresa approved sí puede pasar su borrador a active');

select results_eq(
  $$ select status::text from public.jobs where id = tests.get_uuid('job_draft') $$,
  $$ values ('active') $$,
  'POSITIVO: el borrador quedó realmente publicado');

-- ===========================================================================
-- D. Fronteras de escritura
-- ===========================================================================

select throws_ok(
  tests.sql_new_job('company_pend', 'draft'),
  '42501', null,
  'NEGATIVO: un miembro de company_ok no escribe ofertas de company_pend');

select throws_ok(
  tests.sql_new_job('company_ok', 'draft',
                    format('%L::uuid', tests.get_uuid('user_cand_pub'))),
  '42501', null,
  'NEGATIVO: el INSERT no puede firmar la oferta con el uuid de otra persona');

select throws_ok(
  $$ update public.jobs set company_id = tests.get_uuid('company_pend')
     where id = tests.get_uuid('job_A') $$,
  '42501', null,
  'NEGATIVO: un UPDATE no puede mudar la oferta a otra empresa');

select throws_ok(
  $$ update public.jobs set created_by = tests.get_uuid('user_cand_pub')
     where id = tests.get_uuid('job_A') $$,
  '42501', null,
  'NEGATIVO: un UPDATE no puede reescribir la autoría de la oferta');

-- El trigger de 0018 (`private.protect_job_update`) exime a `is_admin()`, así
-- que una cuenta que sea admin de plataforma Y miembro de la empresa podía
-- reescribir la autoría de una oferta suya. `private.protect_job_write` (0031)
-- no tiene esa exención. Se promueve al recruiter a admin de plataforma para
-- construir exactamente ese caso.
reset role;
update public.profiles set role = 'admin'::public.user_role
where id = tests.get_uuid('p_staff_otra');

select results_eq(
  $$ select public.is_company_member(tests.get_uuid('company_ok'))
     from public.company_members
     where profile_id = tests.get_uuid('p_staff_otra') $$,
  $$ values (true) $$,
  'FIXTURE: la cuenta es admin de plataforma Y sigue integrando company_ok');

select tests.authenticate_as('p_staff_otra');

select throws_ok(
  $$ update public.jobs set created_by = tests.get_uuid('user_cand_pub')
     where id = tests.get_uuid('job_A') $$,
  '42501', null,
  'NEGATIVO: ni un admin de plataforma que integra la empresa falsifica la autoría');

reset role;
update public.profiles set role = 'company'::public.user_role
where id = tests.get_uuid('p_staff_otra');

select tests.authenticate_as('user_cand_pub');

select throws_ok(
  tests.sql_new_job('company_ok', 'active'),
  '42501', null,
  'NEGATIVO: un candidato no publica ofertas');

-- Limpieza completa de rol y claims: un anon real no trae ningún sub.
do $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', 'anon', true);
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
end $$;
set local role anon;

-- Para `anon` el 42501 llega antes de la policy: no tiene INSERT sobre `jobs`
-- (0018 se lo dio solo a `authenticated`). La aserción vale igual —anon no
-- publica— pero el motivo es el privilegio, no la puerta de publicación, y por
-- eso se comprueban las dos cosas por separado.
select results_eq(
  $$ select count(*)::int from information_schema.role_table_grants
     where table_schema = 'public' and table_name = 'jobs'
       and grantee = 'anon' and privilege_type = 'INSERT' $$,
  $$ values (0) $$,
  'ESTRUCTURA: anon no tiene INSERT sobre jobs (corta antes que la policy)');

select throws_ok(
  tests.sql_new_job('company_ok', 'active'),
  '42501', null,
  'NEGATIVO: y el intento de anon de publicar termina rechazado igual');

-- ===========================================================================
-- E. Visibilidad: la oferta activa deja de verse si la empresa cae
-- ===========================================================================

-- El video pitch de la oferta, para probar la rama de `videos_company_select`
-- que lo hacía visible a todos por estar la oferta `active`.
--
-- Es un `job_pitch` del owner de company_ok, creado acá. Antes se tomaba el
-- primer video `ready` del seed, que es la PRESENTACIÓN de un candidato: colgar
-- ese video de una oferta es justamente la fuga que 0032 cierra, y desde
-- entonces `validate_job_content` lo rechaza también como backend. Las
-- aserciones de esta sección no cambian: siguen probando la misma rama.
reset role;
with pitch as (
  insert into public.videos (owner_profile_id, purpose, status, duration_seconds)
  values (tests.get_uuid('user_empresa_ok'), 'job_pitch', 'ready', 30)
  returning id
)
insert into tests.identifiers (identifier, id)
select 'video_pitch', pitch.id from pitch
on conflict (identifier) do update set id = excluded.id;

update public.jobs set video_id = tests.get_uuid('video_pitch')
where id = tests.get_uuid('job_A');

select results_eq(
  $$ select
       (select j.status::text from public.jobs j where j.id = tests.get_uuid('job_A')),
       (select cp.verification_status::text from public.company_profiles cp
        where cp.id = tests.get_uuid('company_ok')),
       (select (j.video_id is not null) from public.jobs j
        where j.id = tests.get_uuid('job_A')) $$,
  $$ values ('active', 'approved', true) $$,
  'FIXTURE: job_A está activa, con video, y su empresa está approved');

-- `user_empresa_pend` mira desde afuera: no integra company_ok, su propia
-- empresa no está verificada (así que la rama de "candidato publicado" de
-- `videos_company_select` no le aplica) y no hay ninguna postulación suya.
select tests.authenticate_as('user_empresa_pend');

select results_eq(
  $$ select count(*)::int from public.jobs j where j.id = tests.get_uuid('job_A') $$,
  $$ values (1) $$,
  'POSITIVO: con la empresa approved, la oferta activa se ve desde afuera');

select results_eq(
  $$ select count(*)::int from public.videos v
     where v.id = tests.get_uuid('video_pitch') $$,
  $$ values (1) $$,
  'POSITIVO: y su video pitch también');

reset role;
update public.company_profiles set verification_status = 'rejected'
where id = tests.get_uuid('company_ok');
select tests.authenticate_as('user_empresa_pend');

select results_eq(
  $$ select count(*)::int from public.jobs j where j.id = tests.get_uuid('job_A') $$,
  $$ values (0) $$,
  'NEGATIVO: si la empresa deja de estar approved, su oferta activa deja de verse');

select results_eq(
  $$ select count(*)::int from public.videos v
     where v.id = tests.get_uuid('video_pitch') $$,
  $$ values (0) $$,
  'NEGATIVO: el video pitch de esa oferta tampoco queda visible');

-- Regresión del Bloque D: 0023 eliminó de esta misma policy la rama de "video
-- de candidato publicado" porque entregaba la fila COMPLETA de `videos` —con
-- `owner_profile_id`, que es el id de auth del candidato, y `playback_url`— y
-- permitía enumerar candidatos publicados por REST. Cualquier migración futura
-- que recree la policy partiendo de 0015 la reintroduce en silencio, y quedaría
-- inerte solo por accidente (0023 también le sacó a la empresa el SELECT sobre
-- candidate_profiles). Este par de aserciones es lo que lo agarra.
reset role;

select results_eq(
  $$ select count(*)::int from pg_policies
     where schemaname = 'public' and tablename = 'videos'
       and policyname = 'videos_company_select'
       and qual like '%candidate_profiles%' $$,
  $$ values (0) $$,
  'ESTRUCTURA: videos_company_select no volvió a mirar candidate_profiles (0023)');

select results_eq(
  $$ select count(*)::int from pg_policies
     where schemaname = 'public' and tablename = 'videos'
       and policyname = 'videos_company_select'
       and qual like '%company_can_publish%' $$,
  $$ values (1) $$,
  'ESTRUCTURA: y sí filtra el video pitch por company_can_publish (0031)');

select tests.authenticate_as('user_empresa_pend');

-- El uuid ya lo conoce: el filtro es la policy, no el desconocimiento.
select results_eq(
  $$ select count(*)::int from public.jobs j
     where j.id = tests.get_uuid('job_A') and j.status = 'active' $$,
  $$ values (0) $$,
  'NEGATIVO: conocer el uuid exacto de la oferta no cambia el resultado');

do $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', 'anon', true);
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
end $$;
set local role anon;

select results_eq(
  $$ select count(*)::int from public.jobs j where j.id = tests.get_uuid('job_A') $$,
  $$ values (0) $$,
  'NEGATIVO: anon tampoco ve la oferta de una empresa que perdió la aprobación');

-- La empresa sigue viendo lo suyo: la oferta no "desaparece" de su panel.
select tests.authenticate_as('user_empresa_ok');

select results_eq(
  $$ select count(*)::int from public.jobs j where j.id = tests.get_uuid('job_A') $$,
  $$ values (1) $$,
  'POSITIVO: la propia empresa sigue viendo su oferta aunque ya no se publique');

reset role;
update public.company_profiles set verification_status = 'approved'
where id = tests.get_uuid('company_ok');

-- ===========================================================================
-- F. Las tres puertas de membresía
-- ===========================================================================

select results_eq(
  $$ select count(*)::int from pg_policies
     where schemaname = 'public' and tablename = 'company_members' and cmd = 'INSERT' $$,
  $$ values (0) $$,
  'ESTRUCTURA: company_members no tiene ninguna policy de INSERT (0031)');

select results_eq(
  $$ select count(*)::int from information_schema.role_table_grants
     where table_schema = 'public' and table_name = 'company_members'
       and privilege_type = 'INSERT' and grantee in ('anon', 'authenticated') $$,
  $$ values (0) $$,
  'ESTRUCTURA: ni anon ni authenticated tienen INSERT sobre company_members');

select results_eq(
  $$ select count(*)::int from information_schema.role_table_grants
     where table_schema = 'public' and table_name = 'company_members'
       and privilege_type in ('UPDATE', 'DELETE') and grantee = 'authenticated' $$,
  $$ values (2) $$,
  'ESTRUCTURA: UPDATE y DELETE siguen concedidos (las RPC de equipo los usan)');

-- Idempotencia del bootstrap: la cuenta ya es owner de company_ok.
select tests.authenticate_as('user_empresa_ok');

select results_eq(
  $$ select public.create_company_with_owner('Segunda Empresa', '30-70000008-3')
            = tests.get_uuid('company_ok') $$,
  $$ values (true) $$,
  'POSITIVO: create_company_with_owner es idempotente para quien ya es owner');

reset role;

select results_eq(
  $$ select count(*)::int from public.company_members cm
     where cm.profile_id = tests.get_uuid('user_empresa_ok') $$,
  $$ values (1) $$,
  'POSITIVO: y no creó ninguna segunda membresía');

select results_eq(
  $$ select count(*)::int from public.company_profiles
     where name = 'Segunda Empresa' $$,
  $$ values (0) $$,
  'POSITIVO: tampoco quedó una company_profiles huérfana');

-- Staff de otra empresa: no puede crear la suya por ninguna de las dos puertas.
select tests.authenticate_as('p_staff_otra');

select throws_ok(
  $$ select public.create_company_with_owner('Empresa del recruiter', '30-70000008-3') $$,
  'TFEMP', null,
  'NEGATIVO: quien ya es staff de otra empresa no puede crear una propia');

-- Los consentimientos obligatorios primero: sin ellos el onboarding corta con
-- TFCNS antes de llegar a la guarda de membresia, y el negativo pasaria por el
-- motivo equivocado.
select lives_ok(
  $$ insert into public.consents (profile_id, consent_type, granted, version, user_agent)
     select auth.uid(), cv.consent_type, true, cv.version, 'pgtap'
     from public.consent_versions cv where cv.is_mandatory $$,
  'FIXTURE: la cuenta registra sus consentimientos obligatorios');

select throws_ok(
  $$ select public.complete_company_onboarding(
       'Razón Social SA', 'Nombre', '30-70000008-3',
       (select id from public.sectors where is_active order by id limit 1),
       '1-10', tests.get_uuid('geo_prov'), tests.get_uuid('geo_loc'),
       null, 'Quien Solicita', 'Gerente', 'manager') $$,
  'TFEMP', null,
  'NEGATIVO: el onboarding tampoco le crea una segunda empresa');

reset role;

select results_eq(
  $$ select count(*)::int from public.company_profiles
     where name in ('Empresa del recruiter', 'Nombre') $$,
  $$ values (0) $$,
  'NEGATIVO: ningún rechazo dejó una company_profiles huérfana');

select results_eq(
  $$ select count(*)::int from public.company_members
     where profile_id = tests.get_uuid('p_staff_otra') $$,
  $$ values (1) $$,
  'NEGATIVO: la cuenta sigue con su única membresía original');

-- El lock que serializa las altas no es superficie de API.
select tests.authenticate_as('user_empresa_ok');

select throws_ok(
  $$ select private.lock_membership_slot(auth.uid()) $$,
  '42501', null,
  'NEGATIVO: lock_membership_slot no es ejecutable desde el cliente');

-- Estado partido: `caller_company` lo señala con un sqlstate PROPIO, para que
-- el cliente pueda fallar cerrado sin leer el texto del mensaje.
reset role;
insert into public.company_members (company_id, profile_id, member_role)
values (tests.get_uuid('company_pend'), tests.get_uuid('user_empresa_ok'), 'viewer');

select tests.authenticate_as('user_empresa_ok');

select throws_ok(
  $$ select public.my_company_verification() $$,
  'TFMUL', null,
  'NEGATIVO: con dos empresas, la lectura falla con TFMUL y no elige una');

select throws_ok(
  $$ select public.list_company_members() $$,
  'TFMUL', null,
  'NEGATIVO: TFMUL vale para todas las RPC que resuelven la empresa del caller');

reset role;
delete from public.company_members
where company_id = tests.get_uuid('company_pend')
  and profile_id = tests.get_uuid('user_empresa_ok');

select tests.authenticate_as('user_empresa_ok');

-- company_ok tiene su owner del seed mas el recruiter que agrego este archivo.
select results_eq(
  $$ select count(*)::int from public.list_company_members() $$,
  $$ values (2) $$,
  'POSITIVO: deshecho el estado partido, caller_company vuelve a resolver');

-- Y una cuenta sin ninguna empresa sigue distinguiéndose con TFEMP.
select tests.authenticate_as('p_sin_empresa');

select throws_ok(
  $$ select public.my_company_verification() $$,
  'TFEMP', null,
  'NEGATIVO: sin ninguna empresa el sqlstate es TFEMP, no TFMUL');

select lives_ok(
  $$ select public.create_company_with_owner('Empresa flamante', '30-70000008-3') $$,
  'POSITIVO: una cuenta sin empresa sí puede crear la suya (bootstrap intacto)');

reset role;

select results_eq(
  $$ select count(*)::int, count(*) filter (where member_role = 'owner')::int
     from public.company_members where profile_id = tests.get_uuid('p_sin_empresa') $$,
  $$ values (1, 1) $$,
  'POSITIVO: el bootstrap creó exactamente una membresía, y como owner');

-- ===========================================================================
-- G. Las tres puertas cuentan LO MISMO: membresías vivas
-- ===========================================================================
--
-- Salió de la auditoría adversarial de 0031. `accept_company_invitation` era la
-- única de las tres que contaba membresías sin descartar las empresas dadas de
-- baja, y esa asimetría la introdujo esta misma migración al agregarle el join
-- a las otras dos. Consecuencias, las dos reales: una cuenta cuya única empresa
-- fue dada de baja quedaba sin poder sumarse a NINGÚN equipo (acá veía "ya
-- integrás otra") mientras las otras dos puertas la dejaban empezar de cero; y
-- una invitación emitida antes de la baja seguía siendo canjeable, metiendo a
-- la persona en un equipo que `private.caller_company()` ya no resuelve.

reset role;
update public.company_profiles set deleted_at = now()
where created_by = tests.get_uuid('p_sin_empresa');

select results_eq(
  $$ select count(*)::int,
            count(*) filter (where cp.deleted_at is not null)::int
     from public.company_members cm
     join public.company_profiles cp on cp.id = cm.company_id
     where cm.profile_id = tests.get_uuid('p_sin_empresa') $$,
  $$ values (1, 1) $$,
  'FIXTURE: la cuenta tiene una única membresía, y a una empresa dada de baja');

-- Invitación fabricada a mano desde la empresa MUERTA: `create_company_invitation`
-- ya no la dejaría emitir, y lo que se prueba es el canje de una emitida ANTES
-- de la baja.
insert into public.company_invitations
  (company_id, email, member_role, token_hash, invited_by, expires_at)
select cp.id, 'pub-staff-otra@tests.local', 'viewer',
       private.invitation_code_hash('FFFFFFFFEEEEEEEEDDDDDDDDCCCCCCC1'),
       tests.get_uuid('p_sin_empresa'), now() + interval '7 days'
from public.company_profiles cp
where cp.created_by = tests.get_uuid('p_sin_empresa');

select tests.authenticate_as('p_staff_otra');

select throws_ok(
  $$ select public.accept_company_invitation('FFFFFFFFEEEEEEEEDDDDDDDDCCCCCCC1') $$,
  'TFEMP', null,
  'NEGATIVO: no se canjea una invitación de una empresa dada de baja');

-- Y la cuenta cuya única membresía está dada de baja SÍ puede sumarse a un
-- equipo vivo: exactamente lo que ya hacían las otras dos puertas. Sin el join
-- de 0031 esta llamada moría con TFEMP.
select tests.authenticate_as('user_empresa_ok');

select lives_ok(
  $$ do $do$
     declare codigo text;
     begin
       codigo := public.create_company_invitation('pub-sin-empresa@tests.local', 'viewer');
       perform set_config('tests.codigo_viva', codigo, true);
     end $do$ $$,
  'FIXTURE: company_ok (viva) emite una invitación para esa cuenta');

select tests.authenticate_as('p_sin_empresa');

select lives_ok(
  format($$ select public.accept_company_invitation(%L) $$,
         current_setting('tests.codigo_viva')),
  'POSITIVO: una cuenta cuya única empresa fue dada de baja sí se suma a un equipo vivo');

reset role;

select results_eq(
  $$ select count(*)::int,
            count(*) filter (where cp.deleted_at is null)::int
     from public.company_members cm
     join public.company_profiles cp on cp.id = cm.company_id
     where cm.profile_id = tests.get_uuid('p_sin_empresa') $$,
  $$ values (2, 1) $$,
  'POSITIVO: quedan dos filas pero UNA sola empresa viva, así que no hay estado partido');

select tests.authenticate_as('p_sin_empresa');

select results_eq(
  $$ select count(*)::int from public.list_company_members() $$,
  $$ values (3) $$,
  'POSITIVO: caller_company resuelve sin ambigüedad (la empresa muerta no cuenta)');

reset role;
update public.company_profiles set deleted_at = null
where created_by = tests.get_uuid('p_sin_empresa');

reset role;
select * from finish();
rollback;
