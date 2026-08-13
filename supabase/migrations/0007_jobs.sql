-- Generado desde docs/DATA_MODEL.md (fuente de verdad; §8 define el orden).
-- No editar sin actualizar el documento. Bloque A: T-005/T-006/T-007.

create table jobs (
  id               uuid primary key default gen_random_uuid(),
  company_id       uuid not null references company_profiles(id) on delete cascade,
  created_by       uuid not null references profiles(id),
  title            text not null,
  description      text not null,
  sector_id        uuid references sectors(id),   -- rubro (catálogo localizable, §2.9 y ARCHITECTURE.md §8)
  -- §5: rango salarial obligatorio
  salary_min       numeric(12,2) not null check (salary_min >= 0),
  salary_max       numeric(12,2) not null,
  salary_currency  char(3) not null default 'ARS',
  salary_period    salary_period not null default 'mensual',
  -- §5: modalidad contractual (relación de dependencia / monotributo / etc.)
  contract_type    contract_type not null,
  -- §5: jornada + días y horarios
  jornada          jornada_type not null,
  schedule_days    text[] not null,               -- ['lun','mar','mie','jue','vie']
  schedule_detail  text not null,                 -- "9 a 18 hs, viernes hasta 15"
  -- §5: presencial / híbrido / remoto + geo
  work_mode        work_mode not null,
  provincia_id     uuid not null references geo_provincias(id),
  localidad_id     uuid not null references geo_localidades(id),
  barrio_id        uuid references geo_barrios(id), -- obligatorio solo en CABA/GBA (valida API)
  -- §5: experiencia, disponibilidad, beneficios, vencimiento
  experience       experience_level not null,
  availability     availability_type not null,
  benefits         text[] not null default '{}',
  expires_at       timestamptz not null,
  vacancies        integer not null default 1 check (vacancies > 0),
  video_id         uuid references videos(id),    -- pitch en video de la búsqueda
  status           job_status not null default 'draft',
  published_at     timestamptz,
  closed_at        timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  deleted_at       timestamptz,
  constraint salary_range check (salary_max >= salary_min)
);

create table saved_jobs (
  candidate_profile_id uuid not null references candidate_profiles(id) on delete cascade,
  job_id               uuid not null references jobs(id) on delete cascade,
  created_at           timestamptz not null default now(),
  primary key (candidate_profile_id, job_id)
);
