-- ===========================================================================
-- Seed de DESARROLLO (T-008): 20 candidatos, 5 empresas, 10 ofertas activas.
-- SOLO para entorno local (`supabase db reset` lo aplica). Jamás en prod.
-- Contraseña de todos los usuarios de prueba: password123
-- Verificado localmente mediante `npm run db:reset`.
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

-- --- 5 usuarios de empresa ---
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
from generate_series(1, 5) as i;

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

-- --- Perfiles de candidato (15 publicados, 5 en borrador) ---
insert into candidate_profiles (profile_id, headline, bio, provincia_id,
                                localidad_id, barrio_id, work_mode_prefs,
                                expected_salary_min, expected_salary_max,
                                availability, experience, skills,
                                is_published, published_at)
select
  ('00000000-0000-4000-8000-0000000001' || lpad(i::text, 2, '0'))::uuid,
  (array['Moza/o de salón con experiencia', 'Cocinero/a de línea',
         'Recepcionista de hotel', 'Bartender', 'Ayudante de cocina'])[1 + (i % 5)],
  'Perfil de prueba generado por el seed de desarrollo.',
  'b0000000-0000-4000-8000-000000000001',
  'b1000000-0000-4000-8000-000000000001',
  ('b2000000-0000-4000-8000-00000000000' || (1 + (i % 3))::text)::uuid,
  array['presencial']::work_mode[],
  1000000, 1600000,
  (array['inmediata','en_1_semana','en_2_semanas'])[1 + (i % 3)]::availability_type,
  (array['sin_experiencia','hasta_1_anio','1_a_3_anios','3_a_5_anios'])[1 + (i % 4)]::experience_level,
  array['atención al cliente','trabajo en equipo'],
  i <= 15, case when i <= 15 then now() end
from generate_series(1, 20) as i;

-- --- 5 empresas verificadas + membresía owner ---
insert into company_profiles (id, name, legal_name, cuit, verification_status,
                              industry, size_range, description, provincia_id,
                              localidad_id, created_by)
select
  ('c0000000-0000-4000-8000-0000000000' || lpad(i::text, 2, '0'))::uuid,
  (array['Parrilla Don Julio Dev','Hotel Palermo Suites Dev','Café Martínez Dev',
         'Bodegón San Telmo Dev','Hostel Recoleta Dev'])[i],
  'Empresa de prueba ' || i || ' S.A.S.',
  '30-7000000' || i || '-' || (i % 10),
  'approved',
  'Gastronomía y hotelería', '11-50',
  'Empresa de prueba generada por el seed de desarrollo.',
  'b0000000-0000-4000-8000-000000000001',
  'b1000000-0000-4000-8000-000000000001',
  ('00000000-0000-4000-8000-0000000002' || lpad(i::text, 2, '0'))::uuid
from generate_series(1, 5) as i;

insert into company_members (company_id, profile_id, member_role)
select
  ('c0000000-0000-4000-8000-0000000000' || lpad(i::text, 2, '0'))::uuid,
  ('00000000-0000-4000-8000-0000000002' || lpad(i::text, 2, '0'))::uuid,
  'owner'
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
