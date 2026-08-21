-- Bloque A.1: invariantes de seguridad que no pueden depender del cliente.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- Privilegios de API explícitos: los GRANT habilitan operaciones y RLS decide
-- qué filas. Anon solo recibe lectura de superficies deliberadamente públicas.
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;

revoke all on all tables in schema public from anon;
grant select on
  public.geo_provincias,
  public.geo_localidades,
  public.geo_barrios,
  public.sectors,
  public.sector_translations,
  public.plans,
  public.plan_prices,
  public.jobs,
  public.company_profiles,
  public.videos,
  public.transcripts
to anon;

-- Tablas append-only o exclusivas del backend conservan sus restricciones aun
-- cuando authenticated obtiene el set base de privilegios.
revoke update, delete on public.admin_audit_log from anon, authenticated;
revoke update, delete on public.consents from anon, authenticated;
revoke insert, update, delete on public.payments from anon, authenticated;
revoke all on public.payment_events from anon, authenticated;
revoke insert, update, delete on public.reconcile_log from anon, authenticated;

-- La primera empresa y su owner deben nacer en la misma transacción. El
-- cliente no recibe permiso de INSERT directo sobre company_profiles.
drop policy if exists comp_insert on public.company_profiles;
revoke insert on public.company_profiles from anon, authenticated;

create or replace function public.create_company_with_owner(
  p_name text,
  p_cuit text,
  p_legal_name text default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  company_id uuid;
begin
  if auth.uid() is null then
    raise insufficient_privilege using message = 'Se requiere una sesión autenticada';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'company'
      and p.deleted_at is null
  ) then
    raise insufficient_privilege using message = 'Solo un perfil de empresa puede crear una empresa';
  end if;

  if nullif(btrim(p_name), '') is null or nullif(btrim(p_cuit), '') is null then
    raise invalid_parameter_value using message = 'name y cuit son obligatorios';
  end if;

  insert into public.company_profiles (name, legal_name, cuit, created_by)
  values (btrim(p_name), nullif(btrim(p_legal_name), ''), btrim(p_cuit), auth.uid())
  returning id into company_id;

  insert into public.company_members (company_id, profile_id, member_role)
  values (company_id, auth.uid(), 'owner');

  return company_id;
end;
$$;

revoke all on function public.create_company_with_owner(text, text, text) from public;
grant execute on function public.create_company_with_owner(text, text, text) to authenticated;

-- Evita la subconsulta recursiva sobre profiles de la policy original. Las
-- columnas sensibles se protegen en el trigger que sigue.
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles for update to authenticated
  using (id = auth.uid() and deleted_at is null)
  with check (id = auth.uid() and deleted_at is null);

create or replace function private.protect_profile_update() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.role() = 'authenticated' and not public.is_admin() and (
    new.id is distinct from old.id
    or new.role is distinct from old.role
    or new.email is distinct from old.email
    or new.suspended_until is distinct from old.suspended_until
    or new.created_at is distinct from old.created_at
    or new.deleted_at is distinct from old.deleted_at
  ) then
    raise insufficient_privilege using message = 'No se pueden modificar columnas protegidas de profiles';
  end if;
  return new;
end;
$$;

create trigger protect_profile_update
before update on public.profiles
for each row execute function private.protect_profile_update();

create or replace function private.protect_candidate_profile_update() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.role() = 'authenticated' and not public.is_admin() and (
    new.id is distinct from old.id
    or new.profile_id is distinct from old.profile_id
    or new.created_at is distinct from old.created_at
    or new.deleted_at is distinct from old.deleted_at
  ) then
    raise insufficient_privilege using message = 'No se pueden modificar columnas protegidas de candidate_profiles';
  end if;
  return new;
end;
$$;

create trigger protect_candidate_profile_update
before update on public.candidate_profiles
for each row execute function private.protect_candidate_profile_update();

create or replace function private.protect_company_profile_update() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.role() = 'authenticated' and not public.is_admin() and (
    new.id is distinct from old.id
    or new.cuit is distinct from old.cuit
    or new.verification_status is distinct from old.verification_status
    or new.created_by is distinct from old.created_by
    or new.created_at is distinct from old.created_at
    or new.deleted_at is distinct from old.deleted_at
  ) then
    raise insufficient_privilege using message = 'No se pueden modificar columnas protegidas de company_profiles';
  end if;
  return new;
end;
$$;

create trigger protect_company_profile_update
before update on public.company_profiles
for each row execute function private.protect_company_profile_update();

create or replace function private.protect_job_update() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.role() = 'authenticated' and not public.is_admin() and (
    new.id is distinct from old.id
    or new.company_id is distinct from old.company_id
    or new.created_by is distinct from old.created_by
    or new.created_at is distinct from old.created_at
    or new.deleted_at is distinct from old.deleted_at
  ) then
    raise insufficient_privilege using message = 'No se pueden modificar columnas protegidas de jobs';
  end if;
  return new;
end;
$$;

create trigger protect_job_update
before update on public.jobs
for each row execute function private.protect_job_update();

create or replace function private.protect_application_update() returns trigger
language plpgsql
set search_path = ''
as $$
declare
  is_candidate boolean;
  is_company boolean;
begin
  if auth.role() <> 'authenticated' or public.is_admin() then
    return new;
  end if;

  is_candidate := old.candidate_profile_id = public.candidate_id();
  select public.is_company_member(j.company_id)
    into is_company
    from public.jobs j
    where j.id = old.job_id;

  if is_candidate then
    if new.status <> 'withdrawn'
      or row(new.id, new.job_id, new.candidate_profile_id, new.cover_note,
             new.video_id, new.viewed_at, new.status_history, new.created_at)
         is distinct from
         row(old.id, old.job_id, old.candidate_profile_id, old.cover_note,
             old.video_id, old.viewed_at, old.status_history, old.created_at)
    then
      raise insufficient_privilege using message = 'El candidato solo puede retirar su postulación';
    end if;
  elsif coalesce(is_company, false) then
    if row(new.id, new.job_id, new.candidate_profile_id, new.cover_note,
           new.video_id, new.created_at)
       is distinct from
       row(old.id, old.job_id, old.candidate_profile_id, old.cover_note,
           old.video_id, old.created_at)
    then
      raise insufficient_privilege using message = 'La empresa solo puede actualizar el estado del proceso';
    end if;
  else
    raise insufficient_privilege using message = 'No se puede actualizar esta postulación';
  end if;

  return new;
end;
$$;

create trigger protect_application_update
before update on public.job_applications
for each row execute function private.protect_application_update();

create or replace function private.protect_message_update() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.role() = 'authenticated' and not public.is_admin() then
    if row(new.id, new.conversation_id, new.sender_profile_id, new.body,
           new.attachments, new.created_at, new.deleted_at)
       is distinct from
       row(old.id, old.conversation_id, old.sender_profile_id, old.body,
           old.attachments, old.created_at, old.deleted_at)
       or new.read_at is null
       or (old.read_at is not null and new.read_at is distinct from old.read_at)
    then
      raise insufficient_privilege using message = 'El destinatario solo puede marcar el mensaje como leído';
    end if;
  end if;
  return new;
end;
$$;

create trigger protect_message_update
before update on public.messages
for each row execute function private.protect_message_update();

create or replace function private.protect_notification_update() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.role() = 'authenticated' and not public.is_admin() then
    if row(new.id, new.profile_id, new.type, new.title, new.body, new.data, new.created_at)
       is distinct from
       row(old.id, old.profile_id, old.type, old.title, old.body, old.data, old.created_at)
       or new.read_at is null
       or (old.read_at is not null and new.read_at is distinct from old.read_at)
    then
      raise insufficient_privilege using message = 'Solo se puede marcar la notificación como leída';
    end if;
  end if;
  return new;
end;
$$;

create trigger protect_notification_update
before update on public.notifications
for each row execute function private.protect_notification_update();
