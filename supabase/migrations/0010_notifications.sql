-- Generado desde docs/DATA_MODEL.md (fuente de verdad; §8 define el orden).
-- No editar sin actualizar el documento. Bloque A: T-005/T-006/T-007.

create table notifications (
  id          uuid primary key default gen_random_uuid(),
  profile_id  uuid not null references profiles(id) on delete cascade,
  type        notification_type not null,
  title       text not null,
  body        text,
  data        jsonb not null default '{}',   -- deep link payload
  read_at     timestamptz,
  created_at  timestamptz not null default now()
);

create table push_devices (
  id           uuid primary key default gen_random_uuid(),
  profile_id   uuid not null references profiles(id) on delete cascade,
  platform     push_platform not null,
  token        text not null unique,
  last_seen_at timestamptz not null default now(),
  created_at   timestamptz not null default now()
);

-- Preferencias por categoría (UX_FLOWS.md §14, ARCHITECTURE.md §6, ROADMAP.md T-019).
-- Sin fila = defaults (todo habilitado); el backend consulta antes de despachar.

create table notification_prefs (
  id             uuid primary key default gen_random_uuid(),
  profile_id     uuid not null references profiles(id) on delete cascade,
  category       notification_type not null,
  push_enabled   boolean not null default true,
  email_enabled  boolean not null default true,
  in_app_enabled boolean not null default true,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (profile_id, category)
);
