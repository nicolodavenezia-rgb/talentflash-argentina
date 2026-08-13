-- Generado desde docs/DATA_MODEL.md (fuente de verdad; §8 define el orden).
-- No editar sin actualizar el documento. Bloque A: T-005/T-006/T-007.

create table sectors (
  id         uuid primary key default gen_random_uuid(),
  code       text not null unique,               -- 'gastronomia_hoteleria','comercio',...
  sort_order integer not null default 0,
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

create table sector_translations (
  sector_id  uuid not null references sectors(id) on delete cascade,
  locale     text not null,                      -- 'es-AR','pt-BR',...
  name       text not null,
  primary key (sector_id, locale)
);

-- Catálogo seed desde INDEC/Georef AR (solo lectura para la app).

create table geo_provincias (
  id         uuid primary key default gen_random_uuid(),
  indec_code text not null unique,               -- '02' CABA, '06' Buenos Aires...
  name       text not null
);

create table geo_localidades (
  id           uuid primary key default gen_random_uuid(),
  provincia_id uuid not null references geo_provincias(id),
  indec_code   text unique,
  name         text not null
);

create table geo_barrios (
  id           uuid primary key default gen_random_uuid(),
  localidad_id uuid not null references geo_localidades(id),
  name         text not null,
  unique (localidad_id, name)
);

-- ---------------------------------------------------------------------------
-- Seed inicial de catálogos (§8.3). SUBSET mínimo de desarrollo con UUIDs
-- fijos; el dataset completo INDEC/Georef se carga con el Bloque G
-- (discovery). Sectores según SPEC §2.
-- ---------------------------------------------------------------------------

insert into sectors (id, code, sort_order) values
  ('a0000000-0000-4000-8000-000000000001', 'gastronomia_hoteleria', 1),
  ('a0000000-0000-4000-8000-000000000002', 'comercio', 2),
  ('a0000000-0000-4000-8000-000000000003', 'ventas', 3),
  ('a0000000-0000-4000-8000-000000000004', 'logistica', 4),
  ('a0000000-0000-4000-8000-000000000005', 'depositos', 5);

insert into sector_translations (sector_id, locale, name) values
  ('a0000000-0000-4000-8000-000000000001', 'es-AR', 'Gastronomía y hotelería'),
  ('a0000000-0000-4000-8000-000000000002', 'es-AR', 'Comercio'),
  ('a0000000-0000-4000-8000-000000000003', 'es-AR', 'Ventas'),
  ('a0000000-0000-4000-8000-000000000004', 'es-AR', 'Logística'),
  ('a0000000-0000-4000-8000-000000000005', 'es-AR', 'Depósitos');

insert into geo_provincias (id, indec_code, name) values
  ('b0000000-0000-4000-8000-000000000001', '02', 'Ciudad Autónoma de Buenos Aires'),
  ('b0000000-0000-4000-8000-000000000002', '06', 'Buenos Aires');

insert into geo_localidades (id, provincia_id, indec_code, name) values
  ('b1000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', '02000010', 'Ciudad Autónoma de Buenos Aires'),
  ('b1000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000002', '06441030', 'La Plata'),
  ('b1000000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000002', '06035010', 'Avellaneda');

insert into geo_barrios (id, localidad_id, name) values
  ('b2000000-0000-4000-8000-000000000001', 'b1000000-0000-4000-8000-000000000001', 'Palermo'),
  ('b2000000-0000-4000-8000-000000000002', 'b1000000-0000-4000-8000-000000000001', 'San Telmo'),
  ('b2000000-0000-4000-8000-000000000003', 'b1000000-0000-4000-8000-000000000001', 'Recoleta');
