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
-- raw_user_meta_data es controlado por el cliente: solo puede elegir entre los
-- flujos candidate/company. El claim confiable se copia a raw_app_meta_data,
-- que el cliente no puede modificar. Admin se provisiona exclusivamente desde
-- un contexto privilegiado y nunca mediante signup.
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  requested_role text := new.raw_user_meta_data ->> 'role';
  trusted_role public.user_role;
begin
  trusted_role := case requested_role
    when 'company' then 'company'::public.user_role
    else 'candidate'::public.user_role
  end;

  insert into public.profiles (id, role, email)
  values (new.id, trusted_role, new.email)
  on conflict (id) do nothing;

  update auth.users
  set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
      || jsonb_build_object('role', trusted_role::text)
  where id = new.id;

  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();
