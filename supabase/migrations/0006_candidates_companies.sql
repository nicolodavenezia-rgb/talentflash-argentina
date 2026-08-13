-- Generado desde docs/DATA_MODEL.md (fuente de verdad; §8 define el orden).
-- No editar sin actualizar el documento. Bloque A: T-005/T-006/T-007.

create table candidate_profiles (
  id             uuid primary key default gen_random_uuid(),
  profile_id     uuid not null unique references profiles(id) on delete cascade,
  headline       text,                         -- "Vendedora con 3 años en retail"
  bio            text,
  birth_date     date,
  provincia_id   uuid references geo_provincias(id),
  localidad_id   uuid references geo_localidades(id),
  barrio_id      uuid references geo_barrios(id),
  work_mode_prefs work_mode[] not null default '{}',
  expected_salary_min numeric(12,2),
  expected_salary_max numeric(12,2),
  salary_currency char(3) not null default 'ARS',
  availability   availability_type,
  experience     experience_level,
  skills         text[] not null default '{}',
  languages      text[] not null default '{}',
  education      jsonb not null default '[]',  -- [{nivel, institucion, titulo, desde, hasta}]
  work_history   jsonb not null default '[]',  -- [{empresa, puesto, desde, hasta, descripcion}]
  cv_url         text,                         -- storage path (opcional, el video es lo central)
  video_id       uuid references videos(id),   -- video de presentación publicado
  is_published   boolean not null default false, -- visible para empresas verificadas
  published_at   timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz,
  constraint salary_range check (expected_salary_max is null or expected_salary_min is null
                                 or expected_salary_max >= expected_salary_min)
);

create table company_profiles (
  id             uuid primary key default gen_random_uuid(),
  name           text not null,                -- nombre de fantasía
  legal_name     text,                         -- razón social
  cuit           text not null unique
                 check (cuit ~ '^[0-9]{2}-?[0-9]{8}-?[0-9]$'),
  verification_status verification_status not null default 'pending',
  industry       text,
  size_range     text,                         -- '1-10','11-50',...
  description    text,
  logo_url       text,
  website        text,
  provincia_id   uuid references geo_provincias(id),
  localidad_id   uuid references geo_localidades(id),
  created_by     uuid not null references profiles(id),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz
);

create table company_members (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid not null references company_profiles(id) on delete cascade,
  profile_id   uuid not null references profiles(id) on delete cascade,
  member_role  company_member_role not null default 'recruiter',
  invited_by   uuid references profiles(id),
  created_at   timestamptz not null default now(),
  unique (company_id, profile_id)
);

create table company_verifications (
  id             uuid primary key default gen_random_uuid(),
  company_id     uuid not null references company_profiles(id) on delete cascade,
  status         verification_status not null default 'pending',
  cuit_submitted text not null,
  documents      jsonb not null default '[]',  -- paths en bucket privado (constancia AFIP, etc.)
  submitted_by   uuid not null references profiles(id),
  reviewed_by    uuid references profiles(id), -- admin
  reviewed_at    timestamptz,
  rejection_reason text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
