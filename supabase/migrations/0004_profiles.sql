-- Generado desde docs/DATA_MODEL.md (fuente de verdad; §8 define el orden).
-- No editar sin actualizar el documento. Bloque A: T-005/T-006/T-007.

-- Complemento explícito del Bloque A: DATA_MODEL.md §1 (convención updated_at)
-- y §8.4 (trigger desde auth.users) los referencian sin definir el SQL.

create or replace function set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- Extiende auth.users (Supabase). Fila creada por trigger on auth.users insert.

create table profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  role          user_role not null,
  email         text not null,                -- espejo de auth.users, para joins/admin
  full_name     text,
  avatar_url    text,
  phone         text,
  onboarding_completed boolean not null default false,
  suspended_until timestamptz,                -- seteado por moderación
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz
);

create trigger set_updated_at before update on profiles
  for each row execute function set_updated_at();

-- Fila de profiles creada automáticamente al registrarse (comentario en §2.1).
-- El rol llega en raw_user_meta_data.role desde el onboarding; fallback: candidate.
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, role, email)
  values (
    new.id,
    coalesce((new.raw_user_meta_data ->> 'role')::user_role, 'candidate'),
    new.email
  )
  on conflict (id) do nothing;
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();

