-- Bloque C (T-016…T-020): esquema de onboarding, consentimientos versionados,
-- preferencias de notificaciones y documentos legales.
--
-- Cambios de modelo documentados en DATA_MODEL.md (§1.1, §2.1, §2.5, §2.7).
-- Esta migración solo agrega DDL; el contenido legal, los triggers y las RPC
-- llegan en 0021/0022 porque el valor nuevo del enum `consent_type` no puede
-- usarse dentro de la misma transacción que lo crea.

-- T-018: ROADMAP pide registrar también la aceptación de TyC. PRIVACY.md §4 no
-- la lista porque es aceptación contractual y no un consentimiento de datos de
-- la Ley 25.326, pero el ledger `consents` es el registro auditable correcto
-- para ambas cosas (misma evidencia: versión + timestamp + canal).
alter type consent_type add value if not exists 'terms_acceptance';

-- T-016: el candidato declara UN sector de interés, desde el catálogo `sectors`
-- (sin IDs hardcodeados en la app). Decisión: columna única y no tabla puente,
-- igual que `jobs.sector_id` — el matching del MVP es 1 sector por candidato;
-- multi-sector sería una migración futura con su propia decisión.
alter table candidate_profiles
  add column sector_id uuid references sectors(id);
create index idx_candidate_profiles_sector on candidate_profiles(sector_id);

-- T-017: rubro normalizado de la empresa. `industry` (texto libre) queda como
-- columna legacy de solo lectura; la fuente pasa a ser el catálogo.
alter table company_profiles
  add column sector_id uuid references sectors(id);

-- T-017: cargo y relación del solicitante con la empresa. Viven en la
-- membresía (son datos de la relación persona↔empresa, no de la empresa).
-- `relationship` acepta un set cerrado validado server-side en la RPC de
-- onboarding: 'owner' | 'partner' | 'manager' | 'hr' | 'other'.
alter table company_members
  add column position_title text,
  add column relationship text;

-- T-019: opt-in explícito. El significado anterior "sin fila = todo habilitado"
-- contradecía el opt-in de T-019: a partir de acá, push y email arrancan
-- APAGADOS y solo se encienden por decisión del usuario. Las notificaciones
-- in-app necesarias para operar siguen activas por defecto.
alter table notification_prefs
  alter column push_enabled set default false,
  alter column email_enabled set default false;

-- T-018: orden total y determinista del ledger append-only. `created_at` puede
-- empatar dentro de una misma transacción; "la última fila por
-- (profile_id, consent_type)" se resuelve por `seq`.
alter table consents
  add column seq bigint generated always as identity;
create index idx_consents_latest_by_seq
  on consents(profile_id, consent_type, seq desc);

-- T-020: documentos legales versionados, en es-AR y lenguaje claro. Cada
-- versión es una fila nueva (append), la vigente es la de mayor published_at
-- por slug. El texto vive acá para que UI y DB no puedan divergir.
create table legal_documents (
  id           uuid primary key default gen_random_uuid(),
  slug         text not null,                  -- 'terminos' | 'privacidad'
  version      text not null,                  -- ej. '2026-08-31'
  title        text not null,
  body         text not null,                  -- texto plano con párrafos
  locale       text not null default 'es-AR',
  published_at timestamptz not null default now(),
  created_at   timestamptz not null default now(),
  unique (slug, version)
);

-- T-018: versión vigente de cada consentimiento — única fuente de verdad para
-- la UI, las RPC y los tests. `ai_training` NO tiene fila a propósito: sin
-- texto vigente no se puede otorgar (SPEC §6: el MVP no lo solicita); sumarlo
-- exigirá una migración y una decisión explícitas.
create table consent_versions (
  consent_type  consent_type primary key,
  version       text not null,
  document_slug text not null,                 -- documento legal que lo respalda
  is_mandatory  boolean not null default false,
  updated_at    timestamptz not null default now(),
  foreign key (document_slug, version) references legal_documents (slug, version)
);

create trigger set_updated_at before update on consent_versions
  for each row execute function set_updated_at();

-- RLS + privilegios de las tablas nuevas (0015 y 0018 corrieron antes de que
-- existieran): lectura pública —el copy legal debe ser accesible sin sesión—
-- y escritura solo por migraciones/service role.
alter table legal_documents enable row level security;
alter table consent_versions enable row level security;

create policy legal_documents_read on legal_documents for select using (true);
create policy consent_versions_read on consent_versions for select using (true);

revoke all on legal_documents from anon, authenticated;
revoke all on consent_versions from anon, authenticated;
grant select on legal_documents, consent_versions to anon, authenticated;
