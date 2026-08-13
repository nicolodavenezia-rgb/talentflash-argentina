-- Generado desde docs/DATA_MODEL.md (fuente de verdad; §8 define el orden).
-- No editar sin actualizar el documento. Bloque A: T-005/T-006/T-007.

create table conversations (
  id                   uuid primary key default gen_random_uuid(),
  company_id           uuid not null references company_profiles(id) on delete cascade,
  candidate_profile_id uuid not null references candidate_profiles(id) on delete cascade,
  job_id               uuid references jobs(id) on delete set null,
  origin               conversation_origin not null,  -- chat solo post-postulación o post-invitación aceptada
  last_message_at      timestamptz,
  created_at           timestamptz not null default now(),
  unique (company_id, candidate_profile_id, job_id)
);

create table messages (
  id               uuid primary key default gen_random_uuid(),
  conversation_id  uuid not null references conversations(id) on delete cascade,
  sender_profile_id uuid not null references profiles(id),
  body             text not null check (length(body) <= 4000),
  attachments      jsonb not null default '[]',
  read_at          timestamptz,
  created_at       timestamptz not null default now(),
  deleted_at       timestamptz          -- "eliminar para todos" = soft delete, cuerpo se anonimiza
);
