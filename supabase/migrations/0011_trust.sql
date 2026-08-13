-- Generado desde docs/DATA_MODEL.md (fuente de verdad; §8 define el orden).
-- No editar sin actualizar el documento. Bloque A: T-005/T-006/T-007.

create table reports (
  id                  uuid primary key default gen_random_uuid(),
  reporter_profile_id uuid not null references profiles(id) on delete cascade,
  target_type         report_target not null,
  target_id           uuid not null,             -- FK lógica, validada en API
  reason              text not null,             -- catálogo cerrado en app
  details             text,
  status              report_status not null default 'open',
  resolved_by         uuid references profiles(id),
  resolved_at         timestamptz,
  created_at          timestamptz not null default now()
);

create table blocks (
  id                  uuid primary key default gen_random_uuid(),
  blocker_profile_id  uuid not null references profiles(id) on delete cascade,
  blocked_profile_id  uuid not null references profiles(id) on delete cascade,
  created_at          timestamptz not null default now(),
  unique (blocker_profile_id, blocked_profile_id),
  check (blocker_profile_id <> blocked_profile_id)
);

create table moderation_actions (
  id                uuid primary key default gen_random_uuid(),
  actor_profile_id  uuid not null references profiles(id),    -- admin
  target_profile_id uuid references profiles(id),
  target_company_id uuid references company_profiles(id),
  report_id         uuid references reports(id),
  action            moderation_action_type not null,
  reason            text not null,
  expires_at        timestamptz,                 -- suspensiones temporales
  created_at        timestamptz not null default now(),
  check (target_profile_id is not null or target_company_id is not null)
);

create table admin_audit_log (
  id           uuid primary key default gen_random_uuid(),
  admin_id     uuid not null references profiles(id),
  action       text not null,                    -- 'company.verify','user.ban',...
  entity_type  text not null,
  entity_id    uuid,
  before       jsonb,
  after        jsonb,
  ip           inet,
  created_at   timestamptz not null default now()
);  -- append-only: sin UPDATE/DELETE (revocados por GRANT y sin policy)

create table consents (
  id           uuid primary key default gen_random_uuid(),
  profile_id   uuid not null references profiles(id) on delete cascade,
  consent_type consent_type not null,
  granted      boolean not null,                 -- true = otorga; false = revoca
  version      text not null,                    -- versión del documento, ej. '2026-08-01'
  ip           inet,
  user_agent   text,
  created_at   timestamptz not null default now()
);
