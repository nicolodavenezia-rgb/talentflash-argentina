-- ===========================================================================
-- Seed de DESARROLLO (T-008): 20 candidatos, 6 usuarios de empresa (5 con
-- empresa creada), 10 ofertas activas. SOLO para entorno local
-- (`supabase db reset` lo aplica). Jamás en prod.
-- Contraseña de todos los usuarios de prueba: password123
--
-- Bloque B: los usuarios sembrados tienen que poder INICIAR SESIÓN de verdad.
-- Para eso hacen falta dos cosas que un insert ingenuo omite:
--   1) los tokens de correo (`confirmation_token`, `recovery_token`,
--      `email_change_token_new`, `email_change`) deben ser cadena vacía y no
--      NULL: GoTrue los lee como texto no nulo y, si encuentra NULL, cualquier
--      lookup del usuario falla con 500 "Database error querying schema";
--   2) cada usuario necesita su fila en `auth.identities` con provider
--      `email`, igual que la que crea un alta real.
-- Sin esto, login y recuperación fallan solo para los usuarios del seed.
--
-- Bloque C: estados de onboarding coherentes con la derivación server-side:
--   candidatos 1–15  onboarding completo + consentimiento de publicación
--                    → el trigger de 0022 los publica (no se fuerza a mano);
--   candidatos 16–18 onboarding completo SIN consentimiento de publicación
--                    → cuentas usables pero no descubribles;
--   candidatos 19–20 onboarding INCOMPLETO (sin nacimiento/sector/consents)
--                    → el wizard retoma donde quedó;
--   empresas 1–5     onboarding completo, empresa creada y verificada;
--   empresa6         onboarding INCOMPLETO (usuario sin empresa creada);
--   empresa7         onboarding completo, empresa creada PENDIENTE de
--                    verificación (no puede ver candidatos — Bloque D).
--
-- Bloque D: candidato1 y candidato2 tienen perfil profesional rico
-- (experiencia, educación, idiomas, franjas horarias — candidato2 con un
-- turno que cruza la medianoche); candidato1/4/5 tienen video de presentación
-- en estados ready/processing/failed (T-023; el pipeline real es Bloque K);
-- candidato15 bloqueó al owner de empresa1 (el bloqueo corta la proyección).
-- Avatares: no se siembran binarios — `npm run storage:test` ejercita el
-- flujo real de subida contra el stack local.
-- ===========================================================================

-- --- 20 candidatos (auth.users; el trigger handle_new_user crea profiles) ---
insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                        confirmation_token, recovery_token,
                        email_change_token_new, email_change,
                        created_at, updated_at)
select
  '00000000-0000-0000-0000-000000000000',
  ('00000000-0000-4000-8000-0000000001' || lpad(i::text, 2, '0'))::uuid,
  'authenticated', 'authenticated',
  'candidato' || i || '@dev.talentflash.test',
  crypt('password123', gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb,
  '{"role":"candidate"}'::jsonb,
  '', '', '', '',
  now(), now()
from generate_series(1, 20) as i;

-- --- 7 usuarios de empresa (empresa6 sin empresa: onboarding a medio;
-- --- empresa7 con empresa pendiente de verificación) ---
insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                        confirmation_token, recovery_token,
                        email_change_token_new, email_change,
                        created_at, updated_at)
select
  '00000000-0000-0000-0000-000000000000',
  ('00000000-0000-4000-8000-0000000002' || lpad(i::text, 2, '0'))::uuid,
  'authenticated', 'authenticated',
  'empresa' || i || '@dev.talentflash.test',
  crypt('password123', gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb,
  '{"role":"company"}'::jsonb,
  '', '', '', '',
  now(), now()
from generate_series(1, 7) as i;

-- --- Identidad `email` de cada usuario sembrado (la crea un alta real) ---
insert into auth.identities (provider_id, user_id, identity_data, provider,
                             last_sign_in_at, created_at, updated_at)
select
  u.id::text, u.id,
  jsonb_build_object(
    'sub', u.id::text,
    'email', u.email,
    'email_verified', true,
    'phone_verified', false
  ),
  'email', now(), now(), now()
from auth.users u
where u.email like '%@dev.talentflash.test'
on conflict (provider_id, provider) do nothing;

-- --- Nombre y estado de onboarding en profiles (Bloque C) ---
-- Candidatos 1–18 y empresas 1–5 terminaron el onboarding; el resto no.
update profiles p
set full_name = 'Candidato de Prueba ' || substring(u.email from 'candidato([0-9]+)@'),
    onboarding_completed = substring(u.email from 'candidato([0-9]+)@')::int <= 18
from auth.users u
where u.id = p.id and u.email like 'candidato%@dev.talentflash.test';

update profiles p
set full_name = case
      when substring(u.email from 'empresa([0-9]+)@')::int <> 6
      then 'Referente Empresa ' || substring(u.email from 'empresa([0-9]+)@')
    end,
    onboarding_completed = substring(u.email from 'empresa([0-9]+)@')::int <> 6
from auth.users u
where u.id = p.id and u.email like 'empresa%@dev.talentflash.test';

-- --- Perfiles de candidato ---
-- La publicación NO se fuerza acá: la deriva `refresh_candidate_publication`
-- (0022) cuando más abajo se insertan los consentimientos. Así el seed no
-- puede divergir de la regla real.
insert into candidate_profiles (profile_id, headline, bio, birth_date,
                                provincia_id, localidad_id, barrio_id,
                                sector_id, work_mode_prefs,
                                expected_salary_min, expected_salary_max,
                                availability, experience, skills)
select
  ('00000000-0000-4000-8000-0000000001' || lpad(i::text, 2, '0'))::uuid,
  (array['Moza/o de salón con experiencia', 'Cocinero/a de línea',
         'Recepcionista de hotel', 'Bartender', 'Ayudante de cocina'])[1 + (i % 5)],
  'Perfil de prueba generado por el seed de desarrollo.',
  case when i <= 18 then date '1990-01-01' + (i * 211) end,
  'b0000000-0000-4000-8000-000000000001',
  'b1000000-0000-4000-8000-000000000001',
  ('b2000000-0000-4000-8000-00000000000' || (1 + (i % 3))::text)::uuid,
  case when i <= 18 then 'a0000000-0000-4000-8000-000000000001'::uuid end,
  array['presencial']::work_mode[],
  1000000, 1600000,
  case when i <= 18
    then (array['inmediata','en_1_semana','en_2_semanas'])[1 + (i % 3)]::availability_type
  end,
  (array['sin_experiencia','hasta_1_anio','1_a_3_anios','3_a_5_anios'])[1 + (i % 4)]::experience_level,
  array['atención al cliente','trabajo en equipo']
from generate_series(1, 20) as i;

-- --- 5 empresas verificadas + membresía owner con cargo y relación ---
insert into company_profiles (id, name, legal_name, cuit, verification_status,
                              industry, sector_id, size_range, description,
                              provincia_id, localidad_id, created_by)
select
  ('c0000000-0000-4000-8000-0000000000' || lpad(i::text, 2, '0'))::uuid,
  (array['Parrilla Don Julio Dev','Hotel Palermo Suites Dev','Café Martínez Dev',
         'Bodegón San Telmo Dev','Hostel Recoleta Dev'])[i],
  'Empresa de prueba ' || i || ' S.A.S.',
  '30-7000000' || i || '-' || (i % 10),
  'approved',
  'Gastronomía y hotelería',
  'a0000000-0000-4000-8000-000000000001',
  '11-50',
  'Empresa de prueba generada por el seed de desarrollo.',
  'b0000000-0000-4000-8000-000000000001',
  'b1000000-0000-4000-8000-000000000001',
  ('00000000-0000-4000-8000-0000000002' || lpad(i::text, 2, '0'))::uuid
from generate_series(1, 5) as i;

insert into company_members (company_id, profile_id, member_role,
                             position_title, relationship)
select
  ('c0000000-0000-4000-8000-0000000000' || lpad(i::text, 2, '0'))::uuid,
  ('00000000-0000-4000-8000-0000000002' || lpad(i::text, 2, '0'))::uuid,
  'owner',
  (array['Dueño','Gerente general','Encargada de RRHH','Socio gerente','Dueña'])[i],
  (array['owner','manager','hr','partner','owner'])[i]
from generate_series(1, 5) as i;

-- --- 10 ofertas activas (2 por empresa) con TODOS los campos obligatorios ---
insert into jobs (company_id, created_by, title, description, sector_id,
                  salary_min, salary_max, salary_period, contract_type,
                  jornada, schedule_days, schedule_detail, work_mode,
                  provincia_id, localidad_id, barrio_id, experience,
                  availability, benefits, expires_at, status, published_at)
select
  ('c0000000-0000-4000-8000-0000000000' || lpad((1 + ((i - 1) % 5))::text, 2, '0'))::uuid,
  ('00000000-0000-4000-8000-0000000002' || lpad((1 + ((i - 1) % 5))::text, 2, '0'))::uuid,
  (array['Moza/o de salón — turno noche','Cocinero/a de línea','Recepcionista nocturno',
         'Bartender con experiencia','Ayudante de cocina','Camarera/o de pisos',
         'Encargado/a de salón','Barista','Pastelero/a','Runner de salón'])[i],
  'Búsqueda de prueba generada por el seed de desarrollo. Sueldo según convenio UTHGRA + propinas.',
  'a0000000-0000-4000-8000-000000000001',
  1100000 + (i * 10000), 1500000 + (i * 10000), 'mensual',
  (array['relacion_dependencia','monotributo'])[1 + (i % 2)]::contract_type,
  (array['full_time','part_time','por_turnos'])[1 + (i % 3)]::jornada_type,
  array['lun','mar','mie','jue','vie'],
  'Lunes a viernes de 18 a 2 hs (rotativo de prueba)',
  'presencial',
  'b0000000-0000-4000-8000-000000000001',
  'b1000000-0000-4000-8000-000000000001',
  ('b2000000-0000-4000-8000-00000000000' || (1 + (i % 3))::text)::uuid,
  (array['sin_experiencia','hasta_1_anio','1_a_3_anios'])[1 + (i % 3)]::experience_level,
  (array['inmediata','a_convenir'])[1 + (i % 2)]::availability_type,
  array['comida incluida','propinas'],
  now() + interval '30 days', 'active', now()
from generate_series(1, 10) as i;

-- --- Consentimientos (Bloque C, T-018) ---
-- La versión se toma de `consent_versions` (única fuente de verdad): si una
-- migración sube la versión, el seed sigue siendo coherente.

-- Obligatorios (TyC + tratamiento de datos + mayoría de edad) para quienes
-- completaron el onboarding: candidatos 1–18 y empresas 1–5.
insert into consents (profile_id, consent_type, granted, version, user_agent)
select u.id, cv.consent_type, true, cv.version, 'seed'
from auth.users u
cross join consent_versions cv
where cv.is_mandatory
  and (
    (u.email like 'candidato%@dev.talentflash.test'
     and substring(u.email from 'candidato([0-9]+)@')::int <= 18)
    or
    (u.email like 'empresa%@dev.talentflash.test'
     and substring(u.email from 'empresa([0-9]+)@')::int <> 6)
  );

-- Publicación del perfil (opcional): solo candidatos 1–15. Al insertarse,
-- el trigger de 0022 recalcula y publica esos perfiles.
insert into consents (profile_id, consent_type, granted, version, user_agent)
select u.id, cv.consent_type, true, cv.version, 'seed'
from auth.users u
join consent_versions cv on cv.consent_type = 'video_profile_publication'
where u.email like 'candidato%@dev.talentflash.test'
  and substring(u.email from 'candidato([0-9]+)@')::int <= 15;

-- Funciones de IA (opcional): un solo ejemplo, para probar la revocación.
insert into consents (profile_id, consent_type, granted, version, user_agent)
select u.id, cv.consent_type, true, cv.version, 'seed'
from auth.users u
join consent_versions cv on cv.consent_type = 'ai_features'
where u.email = 'candidato2@dev.talentflash.test';

-- --- Preferencias de notificaciones (Bloque C, T-019) ---
-- Opt-in explícito: sin fila, push y email quedan APAGADOS. Ejemplos:
insert into notification_prefs (profile_id, category, push_enabled,
                                email_enabled, in_app_enabled)
select u.id, x.category::notification_type, x.push_on, x.email_on, true
from (values
  ('candidato1@dev.talentflash.test', 'application_update', true,  false),
  ('candidato1@dev.talentflash.test', 'message',            true,  true),
  ('empresa1@dev.talentflash.test',   'new_application',    false, true)
) as x(user_email, category, push_on, email_on)
join auth.users u on u.email = x.user_email;

-- ===========================================================================
-- Bloque D — Perfiles (T-021…T-024)
-- ===========================================================================

-- --- Empresa 7: empresa creada y PENDIENTE de verificación ---
-- Su usuaria terminó el onboarding, pero hasta que un admin apruebe el CUIT
-- (T-028) no puede ver candidatos: la proyección de T-024 devuelve vacío.
insert into company_profiles (id, name, legal_name, cuit, verification_status,
                              industry, sector_id, size_range, description,
                              provincia_id, localidad_id, created_by)
values ('c0000000-0000-4000-8000-000000000007',
        'Cantina Puerto Madero Dev',
        'Empresa de prueba 7 S.A.S.',
        '30-70000007-7',
        'pending',
        'Gastronomía y hotelería',
        'a0000000-0000-4000-8000-000000000001',
        '1-10',
        'Empresa pendiente de verificación generada por el seed de desarrollo.',
        'b0000000-0000-4000-8000-000000000001',
        'b1000000-0000-4000-8000-000000000001',
        '00000000-0000-4000-8000-000000000207');

insert into company_members (company_id, profile_id, member_role,
                             position_title, relationship)
values ('c0000000-0000-4000-8000-000000000007',
        '00000000-0000-4000-8000-000000000207',
        'owner', 'Dueña', 'owner');

-- --- Perfiles profesionales ricos (validados por validate_candidate_content) ---
update candidate_profiles set
  work_history = '[
    {"empresa": "Parrilla La Cabrera", "puesto": "Moza de salón", "desde": "2021-03", "hasta": "2023-11", "descripcion": "Atención de salón y manejo de caja en servicio nocturno."},
    {"empresa": "Café Tortoni", "puesto": "Camarera", "desde": "2024-02", "hasta": null}
  ]'::jsonb,
  education = '[
    {"nivel": "secundario", "institucion": "Escuela Normal 1", "titulo": "Bachiller", "desde": "2013-03", "hasta": "2018-12"}
  ]'::jsonb,
  languages = array['español', 'inglés básico'],
  skills = array['atención al cliente', 'trabajo en equipo', 'manejo de caja', 'protocolo de servicio'],
  weekly_availability = '[
    {"day": "lun", "start": "18:00", "end": "23:30"},
    {"day": "mar", "start": "18:00", "end": "23:30"},
    {"day": "sab", "start": "10:00", "end": "16:00"}
  ]'::jsonb
where profile_id = '00000000-0000-4000-8000-000000000101';

-- candidato2: turnos nocturnos que cruzan la medianoche (caso límite real).
update candidate_profiles set
  work_history = '[
    {"empresa": "Bar Notable", "puesto": "Bartender", "desde": "2022-06", "hasta": null, "descripcion": "Barra clásica y coctelería de autor."}
  ]'::jsonb,
  languages = array['español', 'portugués'],
  weekly_availability = '[
    {"day": "vie", "start": "22:00", "end": "02:00"},
    {"day": "sab", "start": "22:00", "end": "02:00"},
    {"day": "dom", "start": "11:00", "end": "15:00"}
  ]'::jsonb
where profile_id = '00000000-0000-4000-8000-000000000102';

-- --- Estados de presentación (T-023; el pipeline real llega en Bloque K) ---
insert into videos (id, owner_profile_id, purpose, status, duration_seconds, error_reason)
values
  ('d0000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000101',
   'candidate_presentation', 'ready', 25, null),
  ('d0000000-0000-4000-8000-000000000004', '00000000-0000-4000-8000-000000000104',
   'candidate_presentation', 'processing', null, null),
  ('d0000000-0000-4000-8000-000000000005', '00000000-0000-4000-8000-000000000105',
   'candidate_presentation', 'failed', null, 'Encoding de prueba fallido (seed)');

update candidate_profiles set video_id = 'd0000000-0000-4000-8000-000000000001'
where profile_id = '00000000-0000-4000-8000-000000000101';
update candidate_profiles set video_id = 'd0000000-0000-4000-8000-000000000004'
where profile_id = '00000000-0000-4000-8000-000000000104';
update candidate_profiles set video_id = 'd0000000-0000-4000-8000-000000000005'
where profile_id = '00000000-0000-4000-8000-000000000105';

-- --- Bloqueo de ejemplo: candidato15 bloqueó al owner de empresa1 ---
-- empresa1 no puede ver su proyección ni su avatar; empresa3 sí.
insert into blocks (blocker_profile_id, blocked_profile_id)
values ('00000000-0000-4000-8000-000000000115',
        '00000000-0000-4000-8000-000000000201');
