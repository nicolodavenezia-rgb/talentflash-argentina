-- Bloque F — T-030: CRUD de ofertas laborales del lado del servidor (0032).
--
-- Lo que se prueba acá es que la oferta tiene UN solo ciclo de vida posible
-- desde el cliente, y que nadie lo esquiva: ni el `viewer` del equipo (D3), ni
-- una empresa ajena, ni un candidato, ni `anon`. Cubre la matriz completa de
-- transiciones (los 25 pares de estados y los 5 estados de alta), las columnas
-- que deriva el servidor, el descarte de borradores, cada regla de contenido
-- con su borde, y los requisitos de publicación de D1 (vencimiento a 60 días,
-- o sea 1440 h, en cualquier TimeZone de sesión) y D2 (barrio en localidades
-- con barrios).
--
-- Cada negativo de permiso va apareado con su positivo, y los fixtures se
-- afirman antes de los negativos, para que "falla" no pueda significar "el
-- fixture estaba mal". Las post-condiciones se leen como backend (`reset role`):
-- bajo el caller, la policy de SELECT haría verdadero cualquier cero. Un UPDATE
-- que RLS filtra no da error, así que un `lives_ok` sobre un UPDATE no prueba
-- nada por sí solo: cada UPDATE positivo cuenta su fila (`with … returning`) o
-- tiene una post-condición que lee lo que escribió.
--
-- Usuarios locales en el namespace 95000000, emails @tests.local (no
-- @dev.talentflash.test, para no contaminar los conteos de 009). Los helpers de
-- 018 no existen acá: 018 termina en rollback.
begin;
select plan(163);

-- --- Fixtures locales -------------------------------------------------------
-- Tres cuentas de empresa que se suman a company_ok, una por rol no-owner. El
-- owner es empresa1 del seed (`user_empresa_ok`); la empresa de afuera es la de
-- empresa3 (`user_empresa_otra`), también approved.
insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                        confirmation_token, recovery_token,
                        email_change_token_new, email_change, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '95000000-0000-4000-8000-000000000001',
   'authenticated', 'authenticated', 'oferta-admin@tests.local',
   crypt('password123', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"role":"company"}',
   '', '', '', '', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '95000000-0000-4000-8000-000000000002',
   'authenticated', 'authenticated', 'oferta-recruiter@tests.local',
   crypt('password123', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"role":"company"}',
   '', '', '', '', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '95000000-0000-4000-8000-000000000003',
   'authenticated', 'authenticated', 'oferta-viewer@tests.local',
   crypt('password123', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"role":"company"}',
   '', '', '', '', now(), now());

insert into tests.identifiers (identifier, id) values
  ('oferta_admin',           '95000000-0000-4000-8000-000000000001'),
  ('oferta_recruiter',       '95000000-0000-4000-8000-000000000002'),
  ('oferta_viewer',          '95000000-0000-4000-8000-000000000003'),
  ('oferta_sector_inactivo', '95000000-0000-4000-8000-000000000011'),
  ('oferta_video_pitch',     '95000000-0000-4000-8000-000000000021'),
  ('oferta_video_candidato', '95000000-0000-4000-8000-000000000022'),
  ('oferta_video_otra',      '95000000-0000-4000-8000-000000000023'),
  ('oferta_video_borrado',   '95000000-0000-4000-8000-000000000024'),
  ('oferta_video_no_pitch',  '95000000-0000-4000-8000-000000000025'),
  ('oferta_j_owner',         '95000000-0000-4000-8000-000000000031'),
  ('oferta_j_admin',         '95000000-0000-4000-8000-000000000032'),
  ('oferta_j_recruiter',     '95000000-0000-4000-8000-000000000033'),
  ('oferta_j_draft',         '95000000-0000-4000-8000-000000000034'),
  ('oferta_j_active',        '95000000-0000-4000-8000-000000000035'),
  ('oferta_j_paused',        '95000000-0000-4000-8000-000000000036'),
  ('oferta_j_expired',       '95000000-0000-4000-8000-000000000037'),
  ('oferta_j_legacy',        '95000000-0000-4000-8000-000000000038'),
  ('oferta_p_sueldo0',       '95000000-0000-4000-8000-000000000041'),
  ('oferta_p_vencida',       '95000000-0000-4000-8000-000000000042'),
  ('oferta_p_lejos',         '95000000-0000-4000-8000-000000000043'),
  ('oferta_p_borde',         '95000000-0000-4000-8000-000000000044'),
  ('oferta_p_sin_barrio',    '95000000-0000-4000-8000-000000000045'),
  ('oferta_p_reanudar',      '95000000-0000-4000-8000-000000000046')
on conflict (identifier) do update set id = excluded.id;

insert into tests.identifiers (identifier, id)
select 'oferta_company_otra', cp.id
from public.company_profiles cp
where cp.created_by = tests.get_uuid('user_empresa_otra')
on conflict (identifier) do update set id = excluded.id;

-- Geo: una localidad CON barrios (hoy CABA) y uno de sus barrios, y otra SIN
-- barrios con su provincia. Se buscan por la condición que importa (tener o no
-- barrios cargados, D2), no por nombre.
with con as (
  select l.id, l.provincia_id from public.geo_localidades l
  where exists (select 1 from public.geo_barrios b where b.localidad_id = l.id)
  order by l.id limit 1
), sin as (
  select l.id, l.provincia_id from public.geo_localidades l
  where not exists (select 1 from public.geo_barrios b where b.localidad_id = l.id)
  order by l.id limit 1
)
insert into tests.identifiers (identifier, id)
select 'oferta_loc_con', con.id from con
union all
select 'oferta_prov_con', con.provincia_id from con
union all
select 'oferta_barrio',
       (select b.id from public.geo_barrios b where b.localidad_id = con.id
        order by b.id limit 1)
from con
union all
select 'oferta_loc_sin', sin.id from sin
union all
select 'oferta_prov_sin', sin.provincia_id from sin
on conflict (identifier) do update set id = excluded.id;

-- Las membresías se crean como backend: el cliente ya no inserta en
-- company_members (0031).
insert into public.company_members (company_id, profile_id, member_role) values
  (tests.get_uuid('company_ok'), tests.get_uuid('oferta_admin'), 'admin'),
  (tests.get_uuid('company_ok'), tests.get_uuid('oferta_recruiter'), 'recruiter'),
  (tests.get_uuid('company_ok'), tests.get_uuid('oferta_viewer'), 'viewer');

-- Un sector del catálogo dado de baja, para el negativo de "sector inactivo"
-- sin desactivar uno real.
insert into public.sectors (id, code, sort_order, is_active)
values (tests.get_uuid('oferta_sector_inactivo'), 'oferta_sector_inactivo', 99, false);

-- Videos: un pitch del recruiter (válido), la presentación de un candidato (la
-- fuga que 0032 cierra), un pitch de alguien de OTRA empresa, un pitch borrado
-- y un video vivo del recruiter que NO es pitch. Este último es el que aísla la
-- condición `purpose = 'job_pitch'`: su dueño sí integra company_ok, así que
-- solo el propósito lo deja afuera (por RLS, un miembro puede subir videos
-- propios de cualquier propósito).
insert into public.videos (id, owner_profile_id, purpose, status, duration_seconds, deleted_at)
values
  (tests.get_uuid('oferta_video_pitch'), tests.get_uuid('oferta_recruiter'),
   'job_pitch', 'ready', 30, null),
  (tests.get_uuid('oferta_video_candidato'), tests.get_uuid('user_cand_pub'),
   'candidate_presentation', 'ready', 25, null),
  (tests.get_uuid('oferta_video_otra'), tests.get_uuid('user_empresa_otra'),
   'job_pitch', 'ready', 30, null),
  (tests.get_uuid('oferta_video_borrado'), tests.get_uuid('oferta_recruiter'),
   'job_pitch', 'ready', 30, now()),
  (tests.get_uuid('oferta_video_no_pitch'), tests.get_uuid('oferta_recruiter'),
   'application_answer', 'ready', 20, null);

-- Statement de alta de oferta. Todas las columnas NOT NULL de `jobs` (0007) van
-- explícitas con un valor válido —CABA con un barrio suyo, sueldo > 0,
-- vencimiento a 30 días, ARS explícito—, y cada caso pisa solo lo que prueba
-- con `p_overrides` (un null en el jsonb deja la columna en NULL). Si mañana se
-- agrega una columna NOT NULL, este helper falla y se ve. `created_at` y
-- `updated_at` van en la lista para que un caso pueda mandarlos como lo haría
-- el cliente y comprobar que el servidor los pisa.
--
-- Los valores por defecto se calculan al ARMAR el statement, que ocurre en la
-- misma sentencia que lo ejecuta: `auth.uid()` es el de quien actúa y `now()` es
-- el de la transacción (el mismo que usan los triggers).
create or replace function tests.sql_job_insert(p_overrides jsonb default '{}'::jsonb)
returns text
language sql as $$
  select format($f$
    insert into public.jobs (
      id, company_id, created_by, title, description, sector_id,
      salary_min, salary_max, salary_currency, salary_period,
      contract_type, jornada, schedule_days, schedule_detail, work_mode,
      provincia_id, localidad_id, barrio_id, experience, availability,
      benefits, expires_at, vacancies, video_id, status,
      published_at, closed_at, deleted_at, created_at, updated_at)
    select
      r.id, r.company_id, r.created_by, r.title, r.description, r.sector_id,
      r.salary_min, r.salary_max, r.salary_currency, r.salary_period,
      r.contract_type, r.jornada, r.schedule_days, r.schedule_detail, r.work_mode,
      r.provincia_id, r.localidad_id, r.barrio_id, r.experience, r.availability,
      r.benefits, r.expires_at, r.vacancies, r.video_id, r.status,
      r.published_at, r.closed_at, r.deleted_at, r.created_at, r.updated_at
    from jsonb_populate_record(null::public.jobs, %L::jsonb) r
  $f$,
  jsonb_build_object(
    'id', gen_random_uuid(),
    'company_id', tests.get_uuid('company_ok'),
    'created_by', auth.uid(),
    'title', 'Oferta 019',
    'description', 'Descripción de prueba de la oferta',
    'salary_min', 900000,
    'salary_max', 1200000,
    'salary_currency', 'ARS',
    'salary_period', 'mensual',
    'contract_type', 'relacion_dependencia',
    'jornada', 'full_time',
    'schedule_days', jsonb_build_array('lun', 'mar', 'mie', 'jue', 'vie'),
    'schedule_detail', '9 a 18 hs',
    'work_mode', 'presencial',
    'provincia_id', tests.get_uuid('oferta_prov_con'),
    'localidad_id', tests.get_uuid('oferta_loc_con'),
    'barrio_id', tests.get_uuid('oferta_barrio'),
    'experience', 'sin_experiencia',
    'availability', 'inmediata',
    'benefits', jsonb_build_array(),
    'expires_at', now() + interval '30 days',
    'vacancies', 1,
    'status', 'draft',
    'created_at', now(),
    'updated_at', now()
  ) || coalesce(p_overrides, '{}'::jsonb));
$$;

-- ===========================================================================
-- A. Fixtures y estructura
-- ===========================================================================

select results_eq(
  $$ select
       (select cp.verification_status::text from public.company_profiles cp
        where cp.id = tests.get_uuid('company_ok')),
       (select cp.verification_status::text from public.company_profiles cp
        where cp.id = tests.get_uuid('oferta_company_otra')) $$,
  $$ values ('approved', 'approved') $$,
  'FIXTURE: company_ok y la empresa de afuera están approved (la puerta de 0031 no interviene)');

select results_eq(
  $$ select string_agg(cm.member_role::text, ',' order by cm.member_role)
     from public.company_members cm
     where cm.company_id = tests.get_uuid('company_ok')
       and cm.profile_id in (tests.get_uuid('user_empresa_ok'), tests.get_uuid('oferta_admin'),
                             tests.get_uuid('oferta_recruiter'), tests.get_uuid('oferta_viewer')) $$,
  $$ values ('owner,admin,recruiter,viewer'::text) $$,
  'FIXTURE: company_ok tiene un miembro de cada uno de los cuatro roles');

select results_eq(
  $$ select
       (select count(*)::int from public.geo_barrios b
        where b.localidad_id = tests.get_uuid('oferta_loc_con')) > 0,
       (select count(*)::int from public.geo_barrios b
        where b.localidad_id = tests.get_uuid('oferta_loc_sin')),
       (select b.localidad_id from public.geo_barrios b
        where b.id = tests.get_uuid('oferta_barrio')) = tests.get_uuid('oferta_loc_con'),
       tests.get_uuid('oferta_prov_con') <> tests.get_uuid('oferta_prov_sin') $$,
  $$ values (true, 0, true, true) $$,
  'FIXTURE: una localidad con barrios (y un barrio suyo) y otra sin barrios, de otra provincia');

select results_eq(
  $$ select
       (select v.purpose::text from public.videos v where v.id = tests.get_uuid('oferta_video_pitch')),
       (select v.purpose::text from public.videos v where v.id = tests.get_uuid('oferta_video_candidato')),
       exists (select 1 from public.company_members cm
               join public.videos v on v.owner_profile_id = cm.profile_id
               where v.id = tests.get_uuid('oferta_video_otra')
                 and cm.company_id = tests.get_uuid('company_ok')),
       (select v.deleted_at is not null from public.videos v
        where v.id = tests.get_uuid('oferta_video_borrado')) $$,
  $$ values ('job_pitch', 'candidate_presentation', false, true) $$,
  'FIXTURE: pitch válido, video de candidato, pitch de alguien ajeno a company_ok y pitch borrado');

select results_eq(
  $$ select v.purpose::text, v.deleted_at is null,
            exists (select 1 from public.company_members cm
                    where cm.company_id = tests.get_uuid('company_ok')
                      and cm.profile_id = v.owner_profile_id)
     from public.videos v where v.id = tests.get_uuid('oferta_video_no_pitch') $$,
  $$ values ('application_answer', true, true) $$,
  'FIXTURE: un video vivo de un miembro de company_ok que no es pitch (solo el propósito lo descalifica)');

-- `collate "default"`: los nombres del catálogo son `name` (collation "C") y
-- results_eq no puede comparar eso contra un literal de texto sin elegir una.
select results_eq(
  $$ select string_agg(t.tgname::text, ',' order by t.tgname) collate "default"
     from pg_catalog.pg_trigger t
     where t.tgrelid = 'public.jobs'::regclass and not t.tgisinternal $$,
  $$ values ('protect_job_lifecycle,protect_job_write,set_updated_at,validate_job_content'::text) $$,
  'ESTRUCTURA: protect_job_update (0018) ya no está; sí protect_job_lifecycle, protect_job_write y validate_job_content');

select results_eq(
  $$ select to_regprocedure('private.protect_job_update()') is null $$,
  $$ values (true) $$,
  'ESTRUCTURA: la función private.protect_job_update tampoco quedó colgada');

-- El protector tiene que ser INVOKER (su guarda mira `current_user`) y el
-- validador DEFINER (lee catálogos que el caller no ve); si alguien los da
-- vuelta, la mitad de las reglas deja de aplicarse sin que nada falle.
select results_eq(
  $$ select string_agg(p.proname || '=' || case when p.prosecdef then 'definer' else 'invoker' end,
                       ' ' order by p.proname) collate "default"
     from pg_catalog.pg_proc p
     join pg_catalog.pg_namespace n on n.oid = p.pronamespace
     where (n.nspname, p.proname) in (('private', 'protect_job_lifecycle'),
                                      ('private', 'validate_job_content'),
                                      ('public', 'discard_job_draft'),
                                      ('public', 'can_write_company_jobs')) $$,
  $$ values ('can_write_company_jobs=definer discard_job_draft=definer protect_job_lifecycle=invoker validate_job_content=definer'::text) $$,
  'ESTRUCTURA: protector INVOKER; validador, RPC de descarte y helper de escritura DEFINER');

-- ===========================================================================
-- B. Quién escribe (D3): owner, admin y recruiter sí; viewer no
-- ===========================================================================

select tests.authenticate_as('user_empresa_ok');

select lives_ok(
  tests.sql_job_insert(jsonb_build_object(
    'id', tests.get_uuid('oferta_j_owner'), 'title', 'Oferta 019 del owner')),
  'POSITIVO: el owner crea un borrador');

select tests.authenticate_as('oferta_admin');

select lives_ok(
  tests.sql_job_insert(jsonb_build_object(
    'id', tests.get_uuid('oferta_j_admin'), 'title', 'Oferta 019 del admin')),
  'POSITIVO: un admin de empresa crea un borrador');

-- La autoría no restringe la edición: es una oferta de la EMPRESA. Se cuenta la
-- fila: si la policy filtrara por autor, el UPDATE afectaría cero filas sin
-- error y un `lives_ok` pasaría igual.
select results_eq(
  $$ with edicion as (
       update public.jobs set description = 'Descripción revisada por el admin'
       where id = tests.get_uuid('oferta_j_owner')
       returning 1)
     select count(*)::int from edicion $$,
  $$ values (1) $$,
  'POSITIVO: un admin edita el borrador que creó otro miembro del equipo');

select tests.authenticate_as('oferta_recruiter');

select lives_ok(
  tests.sql_job_insert(jsonb_build_object(
    'id', tests.get_uuid('oferta_j_recruiter'), 'title', 'Oferta 019 del recruiter')),
  'POSITIVO: un recruiter crea un borrador');

select results_eq(
  $$ select public.is_company_member(tests.get_uuid('company_ok')),
            public.can_write_company_jobs(tests.get_uuid('company_ok')) $$,
  $$ values (true, true) $$,
  'POSITIVO: para el recruiter, el helper de escritura dice que sí');

select tests.authenticate_as('oferta_viewer');

select results_eq(
  $$ select public.is_company_member(tests.get_uuid('company_ok')),
            public.can_write_company_jobs(tests.get_uuid('company_ok')) $$,
  $$ values (true, false) $$,
  'NEGATIVO: el viewer integra la empresa, pero el helper de escritura le dice que no');

select throws_ok(
  tests.sql_job_insert(jsonb_build_object('title', 'Oferta 019 del viewer')),
  '42501', null,
  'NEGATIVO: el viewer no crea ofertas');

select results_eq(
  $$ with intento as (
       update public.jobs set title = 'Tomada por el viewer'
       where id = tests.get_uuid('oferta_j_owner')
       returning 1)
     select count(*)::int from intento $$,
  $$ values (0) $$,
  'NEGATIVO: el viewer no edita ofertas (cero filas, sin error)');

select results_eq(
  $$ select count(*)::int from public.jobs
     where id in (tests.get_uuid('oferta_j_owner'), tests.get_uuid('oferta_j_admin'),
                  tests.get_uuid('oferta_j_recruiter')) $$,
  $$ values (3) $$,
  'POSITIVO: el viewer sí ve los borradores de su empresa (D3: solo lectura)');

reset role;

select results_eq(
  $$ select
       (select count(*)::int from public.jobs where created_by = tests.get_uuid('oferta_viewer')),
       (select title from public.jobs where id = tests.get_uuid('oferta_j_owner')) $$,
  $$ values (0, 'Oferta 019 del owner') $$,
  'NEGATIVO: como backend, ninguna oferta quedó a nombre del viewer y su edición no tocó nada');

-- ===========================================================================
-- C. Alta: solo `draft` o `active`, y el servidor pone las fechas
-- ===========================================================================

select tests.authenticate_as('user_empresa_ok');

-- El `created_at` y el `updated_at` de 2020 los manda el cliente; el servidor
-- los pisa.
select lives_ok(
  tests.sql_job_insert(jsonb_build_object(
    'id', tests.get_uuid('oferta_j_active'), 'title', 'Oferta 019 activa',
    'status', 'active', 'created_at', '2020-01-01T00:00:00Z',
    'updated_at', '2020-01-01T00:00:00Z')),
  'POSITIVO: el owner de una empresa approved publica de una (INSERT active)');

select throws_ok(
  tests.sql_job_insert('{"status": "paused"}'),
  'TFJOB', null,
  'NEGATIVO: una oferta no nace pausada');

select throws_ok(
  tests.sql_job_insert('{"status": "closed"}'),
  'TFJOB', null,
  'NEGATIVO: una oferta no nace cerrada');

select throws_ok(
  tests.sql_job_insert('{"status": "expired"}'),
  'TFJOB', null,
  'NEGATIVO: una oferta no nace vencida');

select throws_ok(
  tests.sql_job_insert(jsonb_build_object('published_at', now() - interval '1 day')),
  '42501', null,
  'NEGATIVO: el cliente no manda published_at al crear');

select throws_ok(
  tests.sql_job_insert(jsonb_build_object('closed_at', now() - interval '1 day')),
  '42501', null,
  'NEGATIVO: el cliente no manda closed_at al crear');

select throws_ok(
  tests.sql_job_insert(jsonb_build_object('deleted_at', now())),
  '42501', null,
  'NEGATIVO: el cliente no manda deleted_at al crear');

reset role;

select results_eq(
  $$ select
       (select published_at is null from public.jobs where id = tests.get_uuid('oferta_j_owner')),
       (select published_at = now() from public.jobs where id = tests.get_uuid('oferta_j_active')),
       (select created_at = now() from public.jobs where id = tests.get_uuid('oferta_j_active')) $$,
  $$ values (true, true, true) $$,
  'POSITIVO: el borrador nace sin published_at; la publicada lo recibe del servidor, y created_at también');

-- `set_updated_at` (0017) corre solo en UPDATE: en el alta, el único que pisa
-- el `updated_at` del cliente es `protect_job_lifecycle`.
select results_eq(
  $$ select updated_at = now() from public.jobs where id = tests.get_uuid('oferta_j_active') $$,
  $$ values (true) $$,
  'POSITIVO: updated_at también lo pone el servidor en el alta (el 2020 del cliente no quedó)');

-- Todos los altas rechazadas usaron el título por defecto del helper.
select results_eq(
  $$ select count(*)::int from public.jobs where title = 'Oferta 019' $$,
  $$ values (0) $$,
  'NEGATIVO: ninguna de las altas rechazadas dejó fila');

-- ===========================================================================
-- D. Transiciones permitidas y columnas derivadas
-- ===========================================================================

select tests.authenticate_as('user_empresa_ok');

-- Los UPDATE positivos cuentan la fila cuando nada de lo que sigue la lee:
-- uno que RLS filtra termina en cero filas sin error.
select results_eq(
  $$ with edicion as (
       update public.jobs set title = 'Oferta 019 del owner (editada)'
       where id = tests.get_uuid('oferta_j_owner')
       returning 1)
     select count(*)::int from edicion $$,
  $$ values (1) $$,
  'POSITIVO: draft -> draft (editar el borrador)');

select lives_ok(
  $$ update public.jobs set status = 'active' where id = tests.get_uuid('oferta_j_owner') $$,
  'POSITIVO: draft -> active (publicar)');

reset role;

select results_eq(
  $$ select status::text, published_at = now()
     from public.jobs where id = tests.get_uuid('oferta_j_owner') $$,
  $$ values ('active', true) $$,
  'POSITIVO: publicar fija published_at en el servidor');

-- `now()` es el mismo en toda la transacción, así que "pausar y reanudar
-- conserva published_at" sería indistinguible de "lo vuelve a fijar". Se lo
-- retrocede como backend para que la diferencia se vea.
update public.jobs set published_at = now() - interval '3 days'
where id = tests.get_uuid('oferta_j_owner');

select tests.authenticate_as('user_empresa_ok');

select results_eq(
  $$ with edicion as (
       update public.jobs set title = 'Oferta 019 del owner (activa)'
       where id = tests.get_uuid('oferta_j_owner')
       returning 1)
     select count(*)::int from edicion $$,
  $$ values (1) $$,
  'POSITIVO: active -> active (editar una publicada)');

-- El estado final de abajo es `active` igual que antes de pausar: sin contar
-- esta fila, una pausa que no ocurrió pasaría desapercibida.
select results_eq(
  $$ with pausa as (
       update public.jobs set status = 'paused'
       where id = tests.get_uuid('oferta_j_owner')
       returning 1)
     select count(*)::int from pausa $$,
  $$ values (1) $$,
  'POSITIVO: active -> paused');

select lives_ok(
  $$ update public.jobs set vacancies = 2 where id = tests.get_uuid('oferta_j_owner') $$,
  'POSITIVO: paused -> paused (editar una pausada)');

select lives_ok(
  $$ update public.jobs set status = 'active' where id = tests.get_uuid('oferta_j_owner') $$,
  'POSITIVO: paused -> active (reanudar)');

reset role;

select results_eq(
  $$ select status::text, published_at = now() - interval '3 days', vacancies
     from public.jobs where id = tests.get_uuid('oferta_j_owner') $$,
  $$ values ('active', true, 2) $$,
  'POSITIVO: editar, pausar y reanudar conservan published_at (no se sube en el feed)');

select tests.authenticate_as('user_empresa_ok');

select lives_ok(
  $$ update public.jobs set status = 'closed' where id = tests.get_uuid('oferta_j_owner') $$,
  'POSITIVO: active -> closed');

reset role;

select results_eq(
  $$ select status::text, closed_at = now()
     from public.jobs where id = tests.get_uuid('oferta_j_owner') $$,
  $$ values ('closed', true) $$,
  'POSITIVO: cerrar fija closed_at en el servidor');

-- ===========================================================================
-- E. Transiciones prohibidas al cliente
-- ===========================================================================
--
-- Una oferta propia en cada estado. `expired` se pone como backend: es lo que
-- va a hacer el cron de T-033, y el cliente no puede (ver más abajo).

select tests.authenticate_as('user_empresa_ok');

do $$
begin
  execute tests.sql_job_insert(jsonb_build_object(
    'id', tests.get_uuid('oferta_j_draft'), 'title', 'Oferta 019 borrador'));
  execute tests.sql_job_insert(jsonb_build_object(
    'id', tests.get_uuid('oferta_j_paused'), 'title', 'Oferta 019 pausada',
    'status', 'active'));
  update public.jobs set status = 'paused' where id = tests.get_uuid('oferta_j_paused');
  execute tests.sql_job_insert(jsonb_build_object(
    'id', tests.get_uuid('oferta_j_expired'), 'title', 'Oferta 019 vencida',
    'status', 'active'));
end $$;

reset role;
update public.jobs set status = 'expired' where id = tests.get_uuid('oferta_j_expired');

select results_eq(
  $$ select string_agg(j.status::text, ',' order by j.status)
     from public.jobs j
     where j.id in (tests.get_uuid('oferta_j_draft'), tests.get_uuid('oferta_j_active'),
                    tests.get_uuid('oferta_j_paused'), tests.get_uuid('oferta_j_owner'),
                    tests.get_uuid('oferta_j_expired')) $$,
  $$ values ('draft,active,paused,expired,closed'::text) $$,
  'FIXTURE: hay una oferta propia en cada uno de los cinco estados');

select tests.authenticate_as('user_empresa_ok');

-- Desde draft.
select throws_ok(
  $$ update public.jobs set status = 'paused' where id = tests.get_uuid('oferta_j_draft') $$,
  'TFJOB', null,
  'NEGATIVO: draft -> paused (lo que no se publicó no se pausa)');

select throws_ok(
  $$ update public.jobs set status = 'closed' where id = tests.get_uuid('oferta_j_draft') $$,
  'TFJOB', null,
  'NEGATIVO: draft -> closed (un borrador se descarta, no se cierra)');

select throws_ok(
  $$ update public.jobs set status = 'expired' where id = tests.get_uuid('oferta_j_draft') $$,
  '42501', null,
  'NEGATIVO: draft -> expired (vencer es del sistema)');

-- Desde active.
select throws_ok(
  $$ update public.jobs set status = 'draft' where id = tests.get_uuid('oferta_j_active') $$,
  'TFJOB', null,
  'NEGATIVO: active -> draft (una publicada no vuelve a borrador)');

select throws_ok(
  $$ update public.jobs set status = 'expired' where id = tests.get_uuid('oferta_j_active') $$,
  '42501', null,
  'NEGATIVO: active -> expired (vencer es del sistema)');

-- Desde paused.
select throws_ok(
  $$ update public.jobs set status = 'draft' where id = tests.get_uuid('oferta_j_paused') $$,
  'TFJOB', null,
  'NEGATIVO: paused -> draft');

select throws_ok(
  $$ update public.jobs set status = 'expired' where id = tests.get_uuid('oferta_j_paused') $$,
  '42501', null,
  'NEGATIVO: paused -> expired (vencer es del sistema)');

-- Desde closed: es historia.
select throws_ok(
  $$ update public.jobs set status = 'draft' where id = tests.get_uuid('oferta_j_owner') $$,
  'TFJOB', null,
  'NEGATIVO: closed -> draft');

select throws_ok(
  $$ update public.jobs set status = 'active' where id = tests.get_uuid('oferta_j_owner') $$,
  'TFJOB', null,
  'NEGATIVO: closed -> active (una cerrada no se republica)');

select throws_ok(
  $$ update public.jobs set status = 'paused' where id = tests.get_uuid('oferta_j_owner') $$,
  'TFJOB', null,
  'NEGATIVO: closed -> paused');

select throws_ok(
  $$ update public.jobs set status = 'expired' where id = tests.get_uuid('oferta_j_owner') $$,
  '42501', null,
  'NEGATIVO: closed -> expired (vencer es del sistema)');

select throws_ok(
  $$ update public.jobs set title = 'Cerrada pero editada' where id = tests.get_uuid('oferta_j_owner') $$,
  'TFJOB', null,
  'NEGATIVO: closed -> closed (una cerrada no se edita)');

-- Desde expired: la única salida es cerrarla tal cual.
select throws_ok(
  $$ update public.jobs set status = 'draft' where id = tests.get_uuid('oferta_j_expired') $$,
  'TFJOB', null,
  'NEGATIVO: expired -> draft');

select throws_ok(
  $$ update public.jobs set status = 'active' where id = tests.get_uuid('oferta_j_expired') $$,
  'TFJOB', null,
  'NEGATIVO: expired -> active (renovar es de T-033, no una edición del cliente)');

select throws_ok(
  $$ update public.jobs set status = 'paused' where id = tests.get_uuid('oferta_j_expired') $$,
  'TFJOB', null,
  'NEGATIVO: expired -> paused');

select throws_ok(
  $$ update public.jobs set title = 'Vencida pero editada' where id = tests.get_uuid('oferta_j_expired') $$,
  'TFJOB', null,
  'NEGATIVO: expired -> expired (una vencida no se edita)');

select throws_ok(
  $$ update public.jobs set status = 'closed', title = 'Cerrada y retocada'
     where id = tests.get_uuid('oferta_j_expired') $$,
  'TFJOB', null,
  'NEGATIVO: expired -> closed tocando otra columna en la misma edición');

-- Columnas que deriva el servidor, en UPDATE.
select throws_ok(
  $$ update public.jobs set published_at = now() + interval '1 day'
     where id = tests.get_uuid('oferta_j_active') $$,
  '42501', null,
  'NEGATIVO: el cliente no reescribe published_at (no se sube sola en el feed)');

select throws_ok(
  $$ update public.jobs set closed_at = now() where id = tests.get_uuid('oferta_j_active') $$,
  '42501', null,
  'NEGATIVO: el cliente no escribe closed_at');

select throws_ok(
  $$ update public.jobs set deleted_at = now() where id = tests.get_uuid('oferta_j_draft') $$,
  '42501', null,
  'NEGATIVO: el cliente no descarta escribiendo deleted_at (para eso está discard_job_draft)');

select throws_ok(
  $$ update public.jobs set id = gen_random_uuid() where id = tests.get_uuid('oferta_j_active') $$,
  '42501', null,
  'NEGATIVO: el cliente no cambia el id de una oferta');

reset role;

select results_eq(
  $$ select string_agg(j.status::text, ',' order by j.status)
     from public.jobs j
     where j.id in (tests.get_uuid('oferta_j_draft'), tests.get_uuid('oferta_j_active'),
                    tests.get_uuid('oferta_j_paused'), tests.get_uuid('oferta_j_owner'),
                    tests.get_uuid('oferta_j_expired')) $$,
  $$ values ('draft,active,paused,expired,closed'::text) $$,
  'NEGATIVO: después de todos los rechazos, ninguna oferta cambió de estado');

-- ===========================================================================
-- F. Visibilidad por estado
-- ===========================================================================

select tests.authenticate_as('user_cand_pub');

select results_eq(
  $$ select count(*)::int from public.jobs where id = tests.get_uuid('oferta_j_active') $$,
  $$ values (1) $$,
  'POSITIVO: el candidato ve la oferta activa de una empresa approved');

select results_eq(
  $$ select count(*)::int from public.jobs
     where id in (tests.get_uuid('oferta_j_draft'), tests.get_uuid('oferta_j_paused'),
                  tests.get_uuid('oferta_j_owner'), tests.get_uuid('oferta_j_expired')) $$,
  $$ values (0) $$,
  'NEGATIVO: pero no el borrador, la pausada, la cerrada ni la vencida de esa misma empresa');

-- Limpieza completa de rol y claims: un anon real no trae ningún sub.
do $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', 'anon', true);
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
end $$;
set local role anon;

select results_eq(
  $$ select count(*)::int from public.jobs where id = tests.get_uuid('oferta_j_active') $$,
  $$ values (1) $$,
  'POSITIVO: anon ve la oferta activa de una empresa approved');

select results_eq(
  $$ select count(*)::int from public.jobs
     where id in (tests.get_uuid('oferta_j_draft'), tests.get_uuid('oferta_j_paused'),
                  tests.get_uuid('oferta_j_owner'), tests.get_uuid('oferta_j_expired')) $$,
  $$ values (0) $$,
  'NEGATIVO: anon tampoco ve borrador, pausada, cerrada ni vencida');

select tests.authenticate_as('user_empresa_ok');

select results_eq(
  $$ select count(*)::int from public.jobs
     where id in (tests.get_uuid('oferta_j_draft'), tests.get_uuid('oferta_j_active'),
                  tests.get_uuid('oferta_j_paused'), tests.get_uuid('oferta_j_owner'),
                  tests.get_uuid('oferta_j_expired')) $$,
  $$ values (5) $$,
  'POSITIVO: la empresa dueña ve sus cinco ofertas, en cualquier estado');

select tests.authenticate_as('user_empresa_otra');

select results_eq(
  $$ select count(*)::int from public.jobs where id = tests.get_uuid('oferta_j_active') $$,
  $$ values (1) $$,
  'FIXTURE: la otra empresa ve la oferta activa (el cero de abajo no es invisibilidad)');

select results_eq(
  $$ with intento as (
       update public.jobs set title = 'Tomada por otra empresa'
       where id = tests.get_uuid('oferta_j_active')
       returning 1)
     select count(*)::int from intento $$,
  $$ values (0) $$,
  'NEGATIVO: otra empresa no edita una oferta ajena aunque la vea (cero filas)');

select throws_ok(
  tests.sql_job_insert('{"title": "Oferta 019 ajena"}'),
  '42501', null,
  'NEGATIVO: ni crea ofertas a nombre de company_ok');

reset role;

select results_eq(
  $$ select title from public.jobs where id = tests.get_uuid('oferta_j_active') $$,
  $$ values ('Oferta 019 activa') $$,
  'NEGATIVO: como backend, la oferta activa conserva su título');

-- ===========================================================================
-- G. Las dos salidas a `closed` que faltaban
-- ===========================================================================

select tests.authenticate_as('user_empresa_ok');

select lives_ok(
  $$ update public.jobs set status = 'closed' where id = tests.get_uuid('oferta_j_paused') $$,
  'POSITIVO: paused -> closed');

select lives_ok(
  $$ update public.jobs set status = 'closed' where id = tests.get_uuid('oferta_j_expired') $$,
  'POSITIVO: expired -> closed, sin tocar nada más');

reset role;

select results_eq(
  $$ select
       (select status::text || ':' || (closed_at = now())::text
        from public.jobs where id = tests.get_uuid('oferta_j_paused')),
       (select status::text || ':' || (closed_at = now())::text || ':' || (published_at is not null)::text
        from public.jobs where id = tests.get_uuid('oferta_j_expired')) $$,
  $$ values ('closed:true', 'closed:true:true') $$,
  'POSITIVO: las dos quedan cerradas con closed_at del servidor, y la vencida conserva su published_at');

-- ===========================================================================
-- H. Descartar un borrador (borrado lógico)
-- ===========================================================================

select tests.authenticate_as('oferta_admin');

select lives_ok(
  $$ select public.discard_job_draft(tests.get_uuid('oferta_j_admin')) $$,
  'POSITIVO: un admin de empresa descarta un borrador de su empresa');

reset role;

select results_eq(
  $$ select status::text, deleted_at = now()
     from public.jobs where id = tests.get_uuid('oferta_j_admin') $$,
  $$ values ('draft', true) $$,
  'POSITIVO: queda descartado con deleted_at del servidor (la fila no se borra)');

select tests.authenticate_as('user_empresa_ok');

select throws_ok(
  $$ select public.discard_job_draft(tests.get_uuid('oferta_j_active')) $$,
  'TFJOB', null,
  'NEGATIVO: una oferta activa no se descarta: se cierra');

select throws_ok(
  $$ select public.discard_job_draft(tests.get_uuid('oferta_j_admin')) $$,
  'TFJOB', null,
  'NEGATIVO: un borrador ya descartado no se descarta de nuevo');

select throws_ok(
  $$ update public.jobs set title = 'Resucitada' where id = tests.get_uuid('oferta_j_admin') $$,
  'TFJOB', null,
  'NEGATIVO: una oferta descartada ya no se edita');

select throws_ok(
  $$ select public.discard_job_draft('95000000-0000-4000-8000-0000000000ff') $$,
  '42501', null,
  'NEGATIVO: un id inexistente da 42501, el mismo error que uno ajeno (no se filtra qué existe)');

select tests.authenticate_as('user_empresa_otra');

select throws_ok(
  $$ select public.discard_job_draft(tests.get_uuid('oferta_j_draft')) $$,
  '42501', null,
  'NEGATIVO: otra empresa no descarta un borrador ajeno');

select tests.authenticate_as('oferta_viewer');

select throws_ok(
  $$ select public.discard_job_draft(tests.get_uuid('oferta_j_draft')) $$,
  '42501', null,
  'NEGATIVO: el viewer no descarta (D3)');

select tests.authenticate_as('user_cand_pub');

select throws_ok(
  $$ select public.discard_job_draft(tests.get_uuid('oferta_j_draft')) $$,
  '42501', null,
  'NEGATIVO: un candidato no descarta');

reset role;

select results_eq(
  $$ select deleted_at is null from public.jobs where id = tests.get_uuid('oferta_j_draft') $$,
  $$ values (true) $$,
  'NEGATIVO: después de esos tres intentos, el borrador sigue sin descartar');

select results_eq(
  $$ select has_function_privilege('anon', 'public.discard_job_draft(uuid)', 'execute'),
            has_function_privilege('authenticated', 'public.discard_job_draft(uuid)', 'execute') $$,
  $$ values (false, true) $$,
  'ESTRUCTURA: discard_job_draft no es ejecutable por anon, sí por authenticated');

do $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', 'anon', true);
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
end $$;
set local role anon;

select throws_ok(
  $$ select public.discard_job_draft(tests.get_uuid('oferta_j_draft')) $$,
  '42501', null,
  'NEGATIVO: y el intento de anon termina en 42501');

-- ===========================================================================
-- I. Contenido: cada regla con su negativo y su borde positivo
-- ===========================================================================
--
-- Sobre el borrador del recruiter, así ninguna regla de publicación se mezcla.
-- Cada negativo vuelve atrás solo (throws_ok corre en un subtransacción).

select tests.authenticate_as('oferta_recruiter');

-- "Vacío" es vacío después del recorte de `String.trim()` del cliente, no solo
-- de U+0020 (`private.job_trim`). Van antes del borde de 120 para que el título
-- final, que lee la post-condición, sea ese.
select throws_ok(
  $$ update public.jobs set title = E'\t\r\n' where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: un puesto de solo tabulaciones y saltos de línea cuenta como vacío');

select throws_ok(
  $$ update public.jobs set description = E'\n\n\u2028' where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: una descripción de solo saltos de línea (también el Unicode U+2028) no');

select throws_ok(
  $$ update public.jobs set schedule_detail = E'\u3000\u00A0\t'
     where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: un detalle de horario de espacio ideográfico, NBSP y tabulación no');

select throws_ok(
  $$ update public.jobs set benefits = array[E'\u2003\uFEFF'] where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: un beneficio de solo espacio largo y BOM no');

select results_eq(
  $$ with edicion as (
       update public.jobs set title = E'\u00A0Puesto con bordes Unicode\u3000\t'
       where id = tests.get_uuid('oferta_j_recruiter')
       returning title)
     select title from edicion $$,
  $$ values ('Puesto con bordes Unicode'::text) $$,
  'POSITIVO: un puesto con NBSP, espacio ideográfico y tabulación en los bordes se guarda recortado');

select lives_ok(
  $$ update public.jobs set title = repeat('a', 120) where id = tests.get_uuid('oferta_j_recruiter') $$,
  'POSITIVO: un puesto de 120 caracteres entra');

select throws_ok(
  $$ update public.jobs set title = repeat('a', 121) where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: un puesto de 121 caracteres no');

select throws_ok(
  $$ update public.jobs set title = '   ' where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: un puesto de solo espacios cuenta como vacío');

select lives_ok(
  $$ update public.jobs set description = repeat('d', 4000) where id = tests.get_uuid('oferta_j_recruiter') $$,
  'POSITIVO: una descripción de 4000 caracteres entra');

select throws_ok(
  $$ update public.jobs set description = repeat('d', 4001) where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: una descripción de 4001 caracteres no');

select throws_ok(
  $$ update public.jobs set description = '  ' where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: una descripción vacía no');

select lives_ok(
  $$ update public.jobs set schedule_detail = repeat('h', 200) where id = tests.get_uuid('oferta_j_recruiter') $$,
  'POSITIVO: un detalle de horario de 200 caracteres entra');

select throws_ok(
  $$ update public.jobs set schedule_detail = repeat('h', 201) where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: un detalle de horario de 201 caracteres no');

select throws_ok(
  $$ update public.jobs set schedule_detail = '' where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: un detalle de horario vacío no');

select lives_ok(
  $$ update public.jobs set schedule_days = array['lun','mar','mie','jue','vie','sab','dom']
     where id = tests.get_uuid('oferta_j_recruiter') $$,
  'POSITIVO: los siete días de lun a dom entran');

select throws_ok(
  $$ update public.jobs set schedule_days = '{}' where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: sin ningún día de trabajo no (el NOT NULL no lo veía)');

select throws_ok(
  $$ update public.jobs set schedule_days = array['lun','lun'] where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: días repetidos no');

select throws_ok(
  $$ update public.jobs set schedule_days = array['lunes'] where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: un día fuera del vocabulario lun..dom no');

select throws_ok(
  $$ update public.jobs set schedule_days = array['lun', null] where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: un día NULL no');

-- El positivo de la moneda es cada alta de este archivo: el helper manda 'ARS'
-- explícito.
select throws_ok(
  $$ update public.jobs set salary_currency = 'USD' where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: un sueldo en USD no');

select throws_ok(
  $$ update public.jobs set salary_currency = 'ars' where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: ni en minúsculas (no se normaliza el código de moneda)');

select lives_ok(
  $$ update public.jobs set salary_max = 999999999 where id = tests.get_uuid('oferta_j_recruiter') $$,
  'POSITIVO: un sueldo máximo de 999.999.999 entra');

select throws_ok(
  $$ update public.jobs set salary_max = 1000000000 where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: uno de 1.000.000.000 no');

-- Quince beneficios: uno de exactamente 60 caracteres y otro con espacios en
-- los bordes, que se guarda recortado.
select lives_ok(
  $$ update public.jobs
     set benefits = array(select 'Beneficio ' || i from generate_series(1, 13) i)
                    || array[repeat('b', 60), '  Propinas  ']
     where id = tests.get_uuid('oferta_j_recruiter') $$,
  'POSITIVO: quince beneficios, uno de 60 caracteres, entran');

select throws_ok(
  $$ update public.jobs
     set benefits = array(select 'Beneficio ' || i from generate_series(1, 16) i)
     where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: dieciséis beneficios no');

select throws_ok(
  $$ update public.jobs set benefits = array[repeat('b', 61)] where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: un beneficio de 61 caracteres no');

select throws_ok(
  $$ update public.jobs set benefits = array['  '] where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: un beneficio vacío no');

select throws_ok(
  $$ update public.jobs set benefits = array['Propinas', ' propinas '] where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: beneficios repetidos ignorando mayúsculas y espacios no');

select throws_ok(
  $$ update public.jobs set benefits = array['Propinas', null] where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: un beneficio NULL no');

select lives_ok(
  $$ update public.jobs set vacancies = 100 where id = tests.get_uuid('oferta_j_recruiter') $$,
  'POSITIVO: 100 vacantes entran');

select throws_ok(
  $$ update public.jobs set vacancies = 101 where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: 101 vacantes no');

select throws_ok(
  $$ update public.jobs
     set provincia_id = tests.get_uuid('oferta_prov_con'),
         localidad_id = tests.get_uuid('oferta_loc_sin'),
         barrio_id = null
     where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: una localidad que no es de la provincia elegida no');

select throws_ok(
  $$ update public.jobs
     set provincia_id = tests.get_uuid('oferta_prov_sin'),
         localidad_id = tests.get_uuid('oferta_loc_sin'),
         barrio_id = tests.get_uuid('oferta_barrio')
     where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: un barrio que no es de la localidad elegida no (ni en borrador, D2)');

select lives_ok(
  $$ update public.jobs
     set provincia_id = tests.get_uuid('oferta_prov_sin'),
         localidad_id = tests.get_uuid('oferta_loc_sin'),
         barrio_id = null
     where id = tests.get_uuid('oferta_j_recruiter') $$,
  'POSITIVO: una localidad sin barrios, con su provincia y sin barrio, entra');

select throws_ok(
  $$ update public.jobs set sector_id = tests.get_uuid('oferta_sector_inactivo')
     where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: un sector inactivo no');

select throws_ok(
  $$ update public.jobs set sector_id = '95000000-0000-4000-8000-0000000000fe'
     where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: un sector inexistente es TFDAT (el validador corre antes que la FK)');

select lives_ok(
  $$ update public.jobs
     set sector_id = (select s.id from public.sectors s where s.is_active order by s.id limit 1)
     where id = tests.get_uuid('oferta_j_recruiter') $$,
  'POSITIVO: un sector activo entra');

select throws_ok(
  $$ update public.jobs set video_id = tests.get_uuid('oferta_video_candidato')
     where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: el video de un candidato no se cuelga de una oferta (la fuga de videos_company_select)');

select throws_ok(
  $$ update public.jobs set video_id = tests.get_uuid('oferta_video_otra')
     where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: ni el pitch de alguien de otra empresa');

select throws_ok(
  $$ update public.jobs set video_id = tests.get_uuid('oferta_video_borrado')
     where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: ni un pitch borrado');

-- El dueño integra company_ok y el video está vivo: lo único que lo deja afuera
-- es `purpose = 'job_pitch'`.
select throws_ok(
  $$ update public.jobs set video_id = tests.get_uuid('oferta_video_no_pitch')
     where id = tests.get_uuid('oferta_j_recruiter') $$,
  'TFDAT', null,
  'NEGATIVO: ni un video vivo de un miembro de la empresa que no es pitch (la regla mira el propósito)');

select lives_ok(
  $$ update public.jobs set video_id = tests.get_uuid('oferta_video_pitch')
     where id = tests.get_uuid('oferta_j_recruiter') $$,
  'POSITIVO: un pitch de alguien de la empresa sí');

-- En INSERT se valida todo, no solo lo que "cambió".
select throws_ok(
  tests.sql_job_insert(jsonb_build_object('title', repeat('a', 121))),
  'TFDAT', null,
  'NEGATIVO: el alta también valida (puesto de 121 caracteres)');

select throws_ok(
  tests.sql_job_insert(jsonb_build_object('video_id', tests.get_uuid('oferta_video_candidato'))),
  'TFDAT', null,
  'NEGATIVO: el alta tampoco acepta el video de un candidato');

reset role;

select results_eq(
  $$ select length(title), length(description), length(schedule_detail),
            cardinality(schedule_days), salary_max = 999999999,
            cardinality(benefits), benefits @> array['Propinas'], vacancies,
            localidad_id = tests.get_uuid('oferta_loc_sin'), sector_id is not null,
            video_id = tests.get_uuid('oferta_video_pitch')
     from public.jobs where id = tests.get_uuid('oferta_j_recruiter') $$,
  $$ values (120, 4000, 200, 7, true, 15, true, 100, true, true, true) $$,
  'POSITIVO: como backend, el borrador quedó con cada valor de borde y el beneficio recortado');

-- Una fila "anterior al validador": se escribe como backend con el validador
-- apagado. El DDL es transaccional y el rollback del final lo deja como estaba.
alter table public.jobs disable trigger validate_job_content;

do $$
begin
  execute tests.sql_job_insert(jsonb_build_object(
    'id', tests.get_uuid('oferta_j_legacy'), 'title', repeat('x', 200)));
end $$;

alter table public.jobs enable trigger validate_job_content;

select results_eq(
  $$ select length(title) from public.jobs where id = tests.get_uuid('oferta_j_legacy') $$,
  $$ values (200) $$,
  'FIXTURE: hay una oferta vieja con un puesto de 200 caracteres, inválido hoy');

select tests.authenticate_as('oferta_recruiter');

select results_eq(
  $$ with edicion as (
       update public.jobs set description = 'Descripción corregida'
       where id = tests.get_uuid('oferta_j_legacy')
       returning 1)
     select count(*)::int from edicion $$,
  $$ values (1) $$,
  'POSITIVO: igual se puede editar en otro campo: en UPDATE solo se valida lo que cambió');

select throws_ok(
  $$ update public.jobs set title = repeat('x', 199) where id = tests.get_uuid('oferta_j_legacy') $$,
  'TFDAT', null,
  'NEGATIVO: pero el puesto inválido no se puede volver a escribir inválido');

-- ===========================================================================
-- J. Requisitos para publicar (sueldo, D1 vencimiento, D2 barrio)
-- ===========================================================================

select tests.authenticate_as('user_empresa_ok');

select lives_ok(
  tests.sql_job_insert(jsonb_build_object(
    'id', tests.get_uuid('oferta_p_sueldo0'), 'title', 'Oferta 019 sueldo cero', 'salary_min', 0)),
  'POSITIVO: un borrador con sueldo 0 se guarda (es incompleto por definición)');

select throws_ok(
  $$ update public.jobs set status = 'active' where id = tests.get_uuid('oferta_p_sueldo0') $$,
  'TFDAT', null,
  'NEGATIVO: publicarlo con sueldo 0 falla server-side');

select throws_ok(
  tests.sql_job_insert('{"status": "active", "salary_min": 0}'),
  'TFDAT', null,
  'NEGATIVO: crearla ya publicada con sueldo 0 también');

select lives_ok(
  tests.sql_job_insert(jsonb_build_object(
    'id', tests.get_uuid('oferta_p_vencida'), 'title', 'Oferta 019 vencimiento pasado',
    'expires_at', now() - interval '1 day')),
  'POSITIVO: un borrador con vencimiento pasado se guarda');

select throws_ok(
  $$ update public.jobs set status = 'active' where id = tests.get_uuid('oferta_p_vencida') $$,
  'TFDAT', null,
  'NEGATIVO: publicarlo con el vencimiento en el pasado falla (D1)');

-- Los 60 días de D1 son 1440 horas exactas (ver la sección K): los bordes se
-- escriben en horas para no depender del TimeZone de la sesión.
select lives_ok(
  tests.sql_job_insert(jsonb_build_object(
    'id', tests.get_uuid('oferta_p_lejos'), 'title', 'Oferta 019 vencimiento lejano',
    'expires_at', now() + interval '1440 hours 1 second')),
  'POSITIVO: un borrador que vence a 60 días y un segundo se guarda');

select throws_ok(
  $$ update public.jobs set status = 'active' where id = tests.get_uuid('oferta_p_lejos') $$,
  'TFDAT', null,
  'NEGATIVO: publicarlo falla: el máximo es 60 días (D1)');

select lives_ok(
  tests.sql_job_insert(jsonb_build_object(
    'id', tests.get_uuid('oferta_p_borde'), 'title', 'Oferta 019 vencimiento en el borde',
    'expires_at', now() + interval '1440 hours')),
  'POSITIVO: un borrador que vence exactamente a 60 días se guarda');

select lives_ok(
  $$ update public.jobs set status = 'active' where id = tests.get_uuid('oferta_p_borde') $$,
  'POSITIVO: y se publica: el borde de 60 días es inclusivo');

select lives_ok(
  tests.sql_job_insert(jsonb_build_object(
    'id', tests.get_uuid('oferta_p_sin_barrio'), 'title', 'Oferta 019 sin barrio',
    'barrio_id', null)),
  'POSITIVO: un borrador en una localidad con barrios, sin barrio, se guarda');

select throws_ok(
  $$ update public.jobs set status = 'active' where id = tests.get_uuid('oferta_p_sin_barrio') $$,
  'TFDAT', null,
  'NEGATIVO: publicarlo sin barrio falla (D2)');

select lives_ok(
  tests.sql_job_insert(jsonb_build_object(
    'title', 'Oferta 019 localidad sin barrios', 'status', 'active',
    'provincia_id', tests.get_uuid('oferta_prov_sin'),
    'localidad_id', tests.get_uuid('oferta_loc_sin'),
    'barrio_id', null)),
  'POSITIVO: en una localidad sin barrios se publica sin barrio');

-- Editar una oferta que queda activa vuelve a pedir lo que la edición toca.
select throws_ok(
  $$ update public.jobs set expires_at = now() + interval '61 days'
     where id = tests.get_uuid('oferta_p_borde') $$,
  'TFDAT', null,
  'NEGATIVO: a una activa no se le estira el vencimiento más allá de 60 días');

select throws_ok(
  $$ update public.jobs set barrio_id = null where id = tests.get_uuid('oferta_p_borde') $$,
  'TFDAT', null,
  'NEGATIVO: ni se le saca el barrio');

select throws_ok(
  $$ update public.jobs set salary_min = 0 where id = tests.get_uuid('oferta_p_borde') $$,
  'TFDAT', null,
  'NEGATIVO: ni se le baja el sueldo a cero');

select results_eq(
  $$ with edicion as (
       update public.jobs set expires_at = now() + interval '45 days'
       where id = tests.get_uuid('oferta_p_borde')
       returning 1)
     select count(*)::int from edicion $$,
  $$ values (1) $$,
  'POSITIVO: dentro del rango, el vencimiento de una activa sí se mueve');

-- "Publicar sin sueldo/rango falla server-side" (ROADMAP T-030): la tabla lo
-- corta con NOT NULL, igual para un borrador que para una publicada.
select throws_ok(
  tests.sql_job_insert('{"status": "active", "salary_min": null}'),
  '23502', null,
  'NEGATIVO: publicar sin sueldo mínimo falla (NOT NULL)');

select throws_ok(
  tests.sql_job_insert('{"status": "active", "salary_max": null}'),
  '23502', null,
  'NEGATIVO: publicar sin sueldo máximo, o sea sin rango, también');

-- Reanudar es "entrar a active": vuelve a pedir los requisitos. Una pausada
-- cuyo vencimiento ya pasó no vuelve sola; hay que moverlo en la misma edición.
do $$
begin
  execute tests.sql_job_insert(jsonb_build_object(
    'id', tests.get_uuid('oferta_p_reanudar'), 'title', 'Oferta 019 para reanudar',
    'status', 'active'));
  update public.jobs set status = 'paused' where id = tests.get_uuid('oferta_p_reanudar');
end $$;

reset role;
update public.jobs set expires_at = now() - interval '1 hour'
where id = tests.get_uuid('oferta_p_reanudar');

select results_eq(
  $$ select status::text, expires_at < now()
     from public.jobs where id = tests.get_uuid('oferta_p_reanudar') $$,
  $$ values ('paused', true) $$,
  'FIXTURE: hay una oferta pausada con el vencimiento ya pasado');

select tests.authenticate_as('user_empresa_ok');

select throws_ok(
  $$ update public.jobs set status = 'active' where id = tests.get_uuid('oferta_p_reanudar') $$,
  'TFDAT', null,
  'NEGATIVO: reanudar una pausada cuyo vencimiento ya pasó falla');

-- Devuelve el estado con que quedó la fila: una fila y `active`.
select results_eq(
  $$ with reanudacion as (
       update public.jobs set status = 'active', expires_at = now() + interval '10 days'
       where id = tests.get_uuid('oferta_p_reanudar')
       returning status::text)
     select status from reanudacion $$,
  $$ values ('active'::text) $$,
  'POSITIVO: moviendo el vencimiento en la misma edición, reanuda');

reset role;

select results_eq(
  $$ select
       (select string_agg(j.status::text, ',')
        from public.jobs j
        where j.id in (tests.get_uuid('oferta_p_sueldo0'), tests.get_uuid('oferta_p_vencida'),
                       tests.get_uuid('oferta_p_lejos'), tests.get_uuid('oferta_p_sin_barrio'))),
       (select status::text || ':' || (published_at = now())::text
        from public.jobs where id = tests.get_uuid('oferta_p_borde')) $$,
  $$ values ('draft,draft,draft,draft', 'active:true') $$,
  'NEGATIVO: los cuatro borradores rechazados siguen en draft; el del borde quedó publicado');

-- ===========================================================================
-- K. D1 en horas exactas, sea cual sea el TimeZone de la sesión
-- ===========================================================================
--
-- PostgREST deja que el cliente elija el TimeZone de la sesión
-- (`Prefer: timezone`), y sumar `days` a un timestamptz es aritmética de
-- calendario en esa zona: si en la ventana cae un cambio de horario, "60 días"
-- son 1439 o 1441 horas. El tope de D1 se suma en horas (1440 h, lo mismo que
-- `Duration(days: 60)` del cliente), así que el borde es el mismo instante en
-- cualquier zona: 1440 h entra y 1440 h y un segundo no.
--
-- Tres zonas. Buenos Aires no tiene horario de verano. Madrid sí, pero que su
-- cambio caiga o no en los próximos 60 días depende del día en que corre la
-- suite. La tercera es una zona POSIX armada acá, que adelanta la hora dentro
-- de 20 días contados desde hoy: con ella este bloque detecta una vuelta a
-- `make_interval(days => ...)` cualquiera sea la fecha. Son altas ya
-- publicadas: en INSERT los requisitos de publicación se piden siempre, y un
-- alta no puede "pasar" con cero filas.

select tests.authenticate_as('user_empresa_ok');

set local timezone = 'America/Argentina/Buenos_Aires';

select lives_ok(
  tests.sql_job_insert(jsonb_build_object(
    'title', 'Oferta 019 D1 en horas', 'status', 'active',
    'expires_at', now() + interval '1440 hours')),
  'POSITIVO: con la sesión en Buenos Aires se publica a 1440 h exactas');

select throws_ok(
  tests.sql_job_insert(jsonb_build_object(
    'title', 'Oferta 019 D1 en horas', 'status', 'active',
    'expires_at', now() + interval '1440 hours 1 second')),
  'TFDAT', null,
  'NEGATIVO: con la sesión en Buenos Aires, 1440 h y un segundo no');

set local timezone = 'Europe/Madrid';

select lives_ok(
  tests.sql_job_insert(jsonb_build_object(
    'title', 'Oferta 019 D1 en horas', 'status', 'active',
    'expires_at', now() + interval '1440 hours')),
  'POSITIVO: con la sesión en Madrid se publica a 1440 h exactas');

select throws_ok(
  tests.sql_job_insert(jsonb_build_object(
    'title', 'Oferta 019 D1 en horas', 'status', 'active',
    'expires_at', now() + interval '1440 hours 1 second')),
  'TFDAT', null,
  'NEGATIVO: con la sesión en Madrid, 1440 h y un segundo no');

-- `Jn` cuenta los días del año sin el 29 de febrero: un día de diferencia no
-- importa con 20 de margen. La vuelta al horario normal queda a 200 días,
-- fuera de la ventana, así que en ella hay un solo cambio.
do $$
declare
  dia integer := extract(doy from now() at time zone 'UTC')::int;
begin
  perform set_config('TimeZone',
    format('TFE3TFV,J%s/2,J%s/2', (dia - 1 + 20) % 365 + 1, (dia - 1 + 200) % 365 + 1),
    true);
end $$;

select results_eq(
  $$ select (now() + interval '60 days') - (now() + interval '1440 hours') $$,
  $$ values (interval '-1 hour') $$,
  'FIXTURE: en la zona armada, 60 días de calendario desde ahora son 1439 h (el cambio cae en la ventana)');

select lives_ok(
  tests.sql_job_insert(jsonb_build_object(
    'title', 'Oferta 019 D1 en horas', 'status', 'active',
    'expires_at', now() + interval '1440 hours')),
  'POSITIVO: con la sesión en esa zona también se publica a 1440 h exactas (en días de calendario el tope serían 1439 h)');

select throws_ok(
  tests.sql_job_insert(jsonb_build_object(
    'title', 'Oferta 019 D1 en horas', 'status', 'active',
    'expires_at', now() + interval '1440 hours 1 second')),
  'TFDAT', null,
  'NEGATIVO: con la sesión en esa zona, 1440 h y un segundo no');

set local timezone to default;
reset role;

select results_eq(
  $$ select count(*)::int,
            count(*) filter (where status = 'active'
                               and expires_at = published_at + interval '1440 hours')::int
     from public.jobs where title = 'Oferta 019 D1 en horas' $$,
  $$ values (3, 3) $$,
  'POSITIVO: como backend, quedaron solo las tres altas aceptadas, publicadas con vencimiento a 1440 h exactas');

reset role;
select * from finish();
rollback;
