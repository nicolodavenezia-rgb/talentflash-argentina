-- Generado desde docs/DATA_MODEL.md (fuente de verdad; §8 define el orden).
-- No editar sin actualizar el documento. Bloque A: T-005/T-006/T-007.

create table job_applications (
  id                   uuid primary key default gen_random_uuid(),
  job_id               uuid not null references jobs(id) on delete cascade,
  candidate_profile_id uuid not null references candidate_profiles(id) on delete cascade,
  status               application_status not null default 'submitted',
  cover_note           text,
  video_id             uuid references videos(id),  -- video-respuesta opcional
  viewed_at            timestamptz,                 -- evento de apertura del DETALLE por un recruiter (estado "vista"; ver nota arriba)
  status_history       jsonb not null default '[]', -- [{status, at, by}]
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  unique (job_id, candidate_profile_id)
);

create table invitations (
  id                   uuid primary key default gen_random_uuid(),
  job_id               uuid not null references jobs(id) on delete cascade,
  company_id           uuid not null references company_profiles(id) on delete cascade,
  candidate_profile_id uuid not null references candidate_profiles(id) on delete cascade,
  sent_by              uuid not null references profiles(id),
  status               invitation_status not null default 'sent',
  message              text,
  expires_at           timestamptz,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  unique (job_id, candidate_profile_id)
);

create table matches (
  id                   uuid primary key default gen_random_uuid(),
  job_id               uuid not null references jobs(id) on delete cascade,
  candidate_profile_id uuid not null references candidate_profiles(id) on delete cascade,
  score                numeric(5,4) not null check (score between 0 and 1),
  source               match_source not null default 'ai',
  features             jsonb not null default '{}', -- explicabilidad del score
  created_at           timestamptz not null default now(),
  unique (job_id, candidate_profile_id)
);
