-- Generado desde docs/DATA_MODEL.md (fuente de verdad; §8 define el orden).
-- No editar sin actualizar el documento. Bloque A: T-005/T-006/T-007.

create table videos (
  id             uuid primary key default gen_random_uuid(),
  owner_profile_id uuid not null references profiles(id) on delete cascade,
  purpose        video_purpose not null,
  status         video_status not null default 'uploading',
  provider       text not null default 'cloudflare_stream',
  stream_uid     text unique,                  -- UID en Cloudflare Stream
  duration_seconds integer check (duration_seconds between 1 and 120),
  thumbnail_url  text,
  playback_url   text,                         -- HLS
  size_bytes     bigint,
  expires_at     timestamptz,                  -- vencimiento: 30/60/90 días a elección del usuario, default 60
                                               -- (aprobado el 12-08-2026 por el fundador; PRIVACY §6, SPEC §9)
  error_reason   text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz
);

create table transcripts (
  id            uuid primary key default gen_random_uuid(),
  video_id      uuid not null unique references videos(id) on delete cascade,
  language      char(2) not null default 'es',
  full_text     text not null,
  segments      jsonb not null default '[]',   -- [{start,end,text}]
  model         text not null,                 -- ej. whisper-large-v3
  status        text not null default 'ready',
  created_at    timestamptz not null default now()
);
