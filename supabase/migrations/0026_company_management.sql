-- Bloque E — T-026: CRUD del perfil de empresa y gestión de miembros.
--
-- Arregla tres agujeros que venían del Bloque A y agrega el circuito de
-- edición y de equipo, siempre por RPC con whitelist de campos y con la
-- empresa resuelta server-side desde auth.uid(): el cliente nunca manda un
-- company_id que decida autoridad.

-- ---------------------------------------------------------------------------
-- 1. La policy `cm_manage` de 0015 no filtraba por empresa.
--
--   with check (exists (select 1 from company_members
--                       where company_id = company_members.company_id
--                         and profile_id = auth.uid()
--                         and member_role in ('owner','admin')))
--
-- Dentro de la subconsulta, `company_members` resuelve a la relación INTERNA,
-- así que `company_id = company_members.company_id` es la columna comparada
-- consigo misma: siempre verdadera. La condición efectiva quedaba en "quien
-- llama es owner o admin de ALGUNA empresa", de modo que el owner de una
-- empresa podía insertar miembros en CUALQUIER otra. `cm_delete`, tres líneas
-- más abajo, sí aliasa (`me`) y nunca tuvo el problema.
--
-- Se reemplaza por un helper SECURITY DEFINER, que además evita la
-- subconsulta de company_members sobre sí misma dentro de su propia policy
-- (el problema que 0018 tuvo que deshacer en profiles).
-- ---------------------------------------------------------------------------

create or replace function public.is_company_manager(p_company_id uuid)
returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.company_members cm
    join public.company_profiles cp on cp.id = cm.company_id
    where cm.company_id = p_company_id
      and cm.profile_id = auth.uid()
      and cm.member_role in ('owner'::public.company_member_role,
                             'admin'::public.company_member_role)
      and cp.deleted_at is null);
$$;

comment on function public.is_company_manager(uuid) is
  'Owner o admin de ESA empresa (T-026). is_company_member ignora member_role.';

drop policy if exists cm_manage on public.company_members;
create policy cm_manage on public.company_members for insert to authenticated
  with check (public.is_company_manager(company_id));

drop policy if exists cm_delete on public.company_members;
create policy cm_delete on public.company_members for delete to authenticated
  using (public.is_company_manager(company_id));

-- No existía policy de UPDATE: cambiar el rol de un miembro era imposible
-- incluso para el owner. El trigger de más abajo es el que decide qué cambios
-- de rol son legítimos; la policy solo acota las filas alcanzables.
create policy cm_update on public.company_members for update to authenticated
  using (public.is_company_manager(company_id))
  with check (public.is_company_manager(company_id));

-- ---------------------------------------------------------------------------
-- 2. `protect_company_profile_update` (0018) todavía gatea con `auth.role()`.
-- 0023 migró los otros dos protectores a `current_user in ('authenticated',
-- 'anon')`, que es la forma correcta: `auth.role()` lee el JWT, así que dentro
-- de una RPC SECURITY DEFINER sigue devolviendo 'authenticated' y el trigger
-- bloquearía a la propia RPC. Se reemplaza solo la función; el trigger de 0018
-- sigue apuntando acá.
--
-- Se suman `verification_status` (ya estaba), `created_by`, `deleted_at` y
-- ahora también `logo_url`: igual que `profiles.avatar_url` en 0023, el logo
-- lo escribe el pipeline de imágenes, no el cliente, para que nadie apunte la
-- columna a un objeto ajeno o a una URL arbitraria.
-- ---------------------------------------------------------------------------

create or replace function private.protect_company_profile_update() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user in ('authenticated', 'anon') and not public.is_admin() and (
    new.id is distinct from old.id
    or new.cuit is distinct from old.cuit
    or new.verification_status is distinct from old.verification_status
    or new.created_by is distinct from old.created_by
    or new.created_at is distinct from old.created_at
    or new.deleted_at is distinct from old.deleted_at
    or new.logo_url is distinct from old.logo_url
  ) then
    raise insufficient_privilege
      using message = 'No se pueden modificar columnas protegidas de company_profiles';
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. `size_range` era `text` sin restricción: el set cerrado vivía solo dentro
-- del PL/pgSQL de `complete_company_onboarding`, así que cualquier escritura
-- que no pasara por esa RPC podía dejar basura. Igual `relationship` en
-- company_members. Los valores son exactamente los que ya validaba 0022.
-- ---------------------------------------------------------------------------

alter table public.company_profiles
  add constraint company_size_range_valid
  check (size_range is null
         or size_range in ('1-10', '11-50', '51-200', '201-500', '501+'));

alter table public.company_members
  add constraint company_member_relationship_valid
  check (relationship is null
         or relationship in ('owner', 'partner', 'manager', 'hr', 'other'));

-- Índices que faltaban: la cola de verificación (T-028) filtra por estado y la
-- pantalla de cuenta lee el sector de la empresa.
create index idx_company_verifications_company
  on public.company_verifications(company_id);
create index idx_company_verifications_status
  on public.company_verifications(status, created_at desc);
create index idx_company_profiles_sector
  on public.company_profiles(sector_id) where deleted_at is null;

-- ---------------------------------------------------------------------------
-- 4. Resolución de la empresa del caller.
--
-- El cliente NO manda company_id en ninguna de las RPCs de este bloque: se
-- deduce de auth.uid() vía company_members. Si alguien integrara más de una
-- empresa, la función falla en vez de elegir una en silencio.
--
-- DECISIÓN PENDIENTE: las fuentes de verdad no definen la política
-- multiempresa. `complete_company_onboarding` toma `order by created_at limit
-- 1`, que de hecho asume una empresa por cuenta, pero nada lo impone. Acá se
-- implementa el mínimo seguro — fallar antes que adivinar — sin cerrar la
-- puerta a multiempresa: cuando exista la decisión, esta función pasa a
-- recibir el company_id elegido y a verificar la membresía. Ver
-- docs/DATA_MODEL.md §"Empresa y equipo".
-- ---------------------------------------------------------------------------

create or replace function private.caller_company() returns uuid
language plpgsql stable security definer set search_path = ''
as $$
declare
  companies uuid[];
begin
  -- array_agg y no min(): uuid no tiene operador de orden agregable.
  select array_agg(distinct cm.company_id) into companies
  from public.company_members cm
  join public.company_profiles cp on cp.id = cm.company_id
  where cm.profile_id = auth.uid() and cp.deleted_at is null;

  if companies is null or coalesce(array_length(companies, 1), 0) = 0 then
    raise sqlstate 'TFEMP' using message = 'Todavía no integrás ninguna empresa';
  end if;
  if array_length(companies, 1) > 1 then
    raise sqlstate 'TFEMP'
      using message = 'Tu cuenta integra más de una empresa: hace falta elegir cuál';
  end if;
  return companies[1];
end $$;

revoke all on function private.caller_company() from public, anon, authenticated;

create or replace function private.caller_member_role() returns public.company_member_role
language sql stable security definer set search_path = ''
as $$
  select cm.member_role
  from public.company_members cm
  join public.company_profiles cp on cp.id = cm.company_id
  where cm.profile_id = auth.uid() and cp.deleted_at is null
  limit 1;
$$;

revoke all on function private.caller_member_role() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5. Edición del perfil de empresa.
--
-- Whitelist explícita de campos: una clave que no esté en la lista hace
-- fallar la llamada entera en vez de ignorarse, para que un cliente viejo o
-- manipulado no crea que guardó algo que no se guardó. Las columnas
-- protegidas (id, cuit, verification_status, created_by, deleted_at, logo_url)
-- no están en la whitelist y además las corta el trigger.
--
-- El CUIT NO se edita acá: cambiarlo dispara reverificación y eso vive en
-- `request_company_verification` (T-028, migración 0028: 0027 terminó siendo
-- la de invitaciones).
--
-- Idempotente por construcción: es un UPDATE con los mismos valores. El doble
-- submit no duplica nada.
-- ---------------------------------------------------------------------------

create or replace function public.update_my_company_profile(p_patch jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_company uuid;
  allowed constant text[] := array[
    'name', 'legal_name', 'description', 'sector_id', 'size_range',
    'provincia_id', 'localidad_id', 'website'];
  unknown_keys text[];
  new_name text;
  new_legal text;
  new_description text;
  new_sector uuid;
  new_size text;
  new_provincia uuid;
  new_localidad uuid;
  new_website text;
begin
  if auth.uid() is null then
    raise insufficient_privilege using message = 'Se requiere una sesión autenticada';
  end if;
  if p_patch is null or jsonb_typeof(p_patch) <> 'object' then
    raise sqlstate 'TFDAT' using message = 'El cambio tiene que ser un objeto';
  end if;

  select array_agg(k) into unknown_keys
  from jsonb_object_keys(p_patch) k
  where k <> all (allowed);
  if unknown_keys is not null then
    raise sqlstate 'TFDAT'
      using message = 'El cambio trae campos que no se pueden editar acá';
  end if;

  target_company := private.caller_company();
  if not public.is_company_manager(target_company) then
    raise insufficient_privilege
      using message = 'Solo owner o admin pueden editar los datos de la empresa';
  end if;

  -- Se lee el valor actual como default para que un patch parcial no borre lo
  -- que no menciona, y se distingue "no vino la clave" de "vino en null".
  select
    case when p_patch ? 'name'
         then nullif(btrim(coalesce(p_patch ->> 'name', '')), '') else cp.name end,
    case when p_patch ? 'legal_name'
         then nullif(btrim(coalesce(p_patch ->> 'legal_name', '')), '') else cp.legal_name end,
    case when p_patch ? 'description'
         then nullif(btrim(coalesce(p_patch ->> 'description', '')), '') else cp.description end,
    case when p_patch ? 'sector_id'
         then nullif(p_patch ->> 'sector_id', '')::uuid else cp.sector_id end,
    case when p_patch ? 'size_range'
         then nullif(btrim(coalesce(p_patch ->> 'size_range', '')), '') else cp.size_range end,
    case when p_patch ? 'provincia_id'
         then nullif(p_patch ->> 'provincia_id', '')::uuid else cp.provincia_id end,
    case when p_patch ? 'localidad_id'
         then nullif(p_patch ->> 'localidad_id', '')::uuid else cp.localidad_id end,
    case when p_patch ? 'website'
         then nullif(btrim(coalesce(p_patch ->> 'website', '')), '') else cp.website end
  into new_name, new_legal, new_description, new_sector, new_size,
       new_provincia, new_localidad, new_website
  from public.company_profiles cp
  where cp.id = target_company;

  -- Obligatorios: no se pueden vaciar.
  if new_name is null or new_legal is null then
    raise sqlstate 'TFDAT'
      using message = 'El nombre de fantasía y la razón social no pueden quedar vacíos';
  end if;
  if length(new_name) > 120 or length(new_legal) > 160 then
    raise sqlstate 'TFDAT' using message = 'El nombre de la empresa es demasiado largo';
  end if;
  if new_description is not null and length(new_description) > 2000 then
    raise sqlstate 'TFDAT' using message = 'La descripción es demasiado larga';
  end if;

  if new_sector is null or not exists (
    select 1 from public.sectors s where s.id = new_sector and s.is_active
  ) then
    raise sqlstate 'TFDAT' using message = 'El sector elegido no está disponible';
  end if;

  if coalesce(new_size, '') not in ('1-10', '11-50', '51-200', '201-500', '501+') then
    raise sqlstate 'TFDAT' using message = 'El tamaño de la empresa no es válido';
  end if;

  if new_provincia is null or new_localidad is null or not exists (
    select 1 from public.geo_localidades l
    where l.id = new_localidad and l.provincia_id = new_provincia
  ) then
    raise sqlstate 'TFDAT'
      using message = 'La localidad no pertenece a la provincia elegida';
  end if;

  if new_website is not null then
    if length(new_website) > 300 or new_website !~ '^https?://[^[:space:]]+$' then
      raise sqlstate 'TFDAT' using message = 'El sitio web no parece una URL válida';
    end if;
  end if;

  update public.company_profiles cp
  set name = new_name,
      legal_name = new_legal,
      description = new_description,
      sector_id = new_sector,
      size_range = new_size,
      provincia_id = new_provincia,
      localidad_id = new_localidad,
      website = new_website
  where cp.id = target_company;

  return target_company;
end $$;

revoke all on function public.update_my_company_profile(jsonb) from public;
grant execute on function public.update_my_company_profile(jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Reglas de equipo, en un trigger para que valgan también fuera de las
-- RPCs (un UPDATE directo bajo la policy `cm_update` pasa por acá).
--
--   - nunca puede quedar una empresa sin owner: el último no se baja de rango,
--     no se va y no se elimina;
--   - un admin no crea, no elimina ni degrada owners;
--   - recruiter y viewer no administran (ya lo corta `is_company_manager`);
--   - `company_id`, `profile_id`, `invited_by` y `created_at` no se editan;
--   - solo una cuenta con rol `company` puede ser miembro: ni un candidato ni
--     un admin global entran por una llamada del cliente.
-- ---------------------------------------------------------------------------

-- SECURITY DEFINER porque necesita leer filas que el caller no ve bajo RLS
-- (el perfil de la persona que se suma, y los owners de la empresa). Eso
-- descarta `current_user` como test de "esto lo pide un cliente": dentro de un
-- SECURITY DEFINER vale siempre el dueño de la función. Se usa `auth.role()`,
-- que lee el JWT y por eso sí distingue una llamada del cliente de una
-- escritura directa del backend.
--
-- Es al revés que en `protect_company_profile_update`, y a propósito: allá hay
-- una RPC de admin (T-028) que TIENE que poder escribir una columna protegida,
-- así que el test debe dejarla pasar. Acá no existe ninguna operación
-- legítima que necesite saltearse estas reglas.
--
-- CORRECCIÓN (0028): el razonamiento del párrafo anterior era equivocado. Esa
-- RPC de admin es SECURITY DEFINER, así que adentro `current_user` es el dueño
-- de la función y la guarda de `protect_company_profile_update` no se le
-- aplica nunca. El escape `and not public.is_admin()` no hacía falta, y sí
-- habilitaba que una cuenta admin-de-plataforma y owner-de-empresa a la vez se
-- aprobara sola por PostgREST. 0028 lo quita.
create or replace function private.protect_company_member_write() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  is_client boolean := auth.role() = 'authenticated';
  caller_role public.company_member_role;
  remaining_owners int;
  subject_company uuid;
begin
  -- En un trigger de DELETE, `new` no está asignado (y en uno de INSERT, `old`
  -- tampoco): la empresa afectada se resuelve una sola vez y por rama.
  if tg_op = 'DELETE' then
    subject_company := old.company_id;
  else
    subject_company := new.company_id;
  end if;

  if tg_op = 'UPDATE' then
    if is_client and (
      new.id is distinct from old.id
      or new.company_id is distinct from old.company_id
      or new.profile_id is distinct from old.profile_id
      or new.invited_by is distinct from old.invited_by
      or new.created_at is distinct from old.created_at
    ) then
      raise insufficient_privilege
        using message = 'No se pueden modificar columnas protegidas de company_members';
    end if;
  end if;

  -- El miembro tiene que ser una cuenta de empresa viva. Vale para cualquier
  -- escritura, también las del backend: un candidato o un admin global dentro
  -- de company_members sería una escalada de privilegios encubierta.
  if tg_op in ('INSERT', 'UPDATE') then
    if not exists (
      select 1 from public.profiles p
      where p.id = new.profile_id
        and p.role = 'company'::public.user_role
        and p.deleted_at is null
    ) then
      raise sqlstate 'TFMEM'
        using message = 'Solo una cuenta de empresa puede integrar un equipo';
    end if;
  end if;

  if is_client and not public.is_admin() then
    caller_role := (
      select cm.member_role from public.company_members cm
      where cm.company_id = subject_company
        and cm.profile_id = auth.uid());

    -- Un admin de empresa no toca owners, en ninguna dirección.
    if caller_role = 'admin'::public.company_member_role then
      if tg_op = 'INSERT' and new.member_role = 'owner'::public.company_member_role then
        raise insufficient_privilege
          using message = 'Un admin no puede crear owners';
      end if;
      if tg_op = 'DELETE' and old.member_role = 'owner'::public.company_member_role then
        raise insufficient_privilege
          using message = 'Un admin no puede eliminar a un owner';
      end if;
      if tg_op = 'UPDATE'
         and (old.member_role = 'owner'::public.company_member_role
              or new.member_role = 'owner'::public.company_member_role) then
        raise insufficient_privilege
          using message = 'Un admin no puede cambiar el rol de un owner ni nombrar uno';
      end if;
    end if;
  end if;

  -- Último owner: la regla vale para TODOS, incluido el backend. Una empresa
  -- sin owner no tiene quien la administre y queda muerta.
  if (tg_op = 'DELETE' and old.member_role = 'owner'::public.company_member_role)
     or (tg_op = 'UPDATE' and old.member_role = 'owner'::public.company_member_role
         and new.member_role <> 'owner'::public.company_member_role) then
    select count(*) into remaining_owners
    from public.company_members cm
    where cm.company_id = old.company_id
      and cm.member_role = 'owner'::public.company_member_role
      and cm.id <> old.id;
    if remaining_owners = 0 then
      raise sqlstate 'TFOWN'
        using message = 'La empresa no puede quedarse sin owner: nombrá otro primero';
    end if;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end $$;

create trigger protect_company_member_write
before insert or update or delete on public.company_members
for each row execute function private.protect_company_member_write();

revoke all on function private.protect_company_member_write() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 7. Cambio de rol y baja de un miembro, por RPC.
--
-- Se identifica al miembro por su profile_id (lo que la UI ya tiene de
-- `cm_select`), no por el id de la fila, y la empresa se resuelve del caller:
-- así no hay ningún identificador de autoridad que venga del cliente.
--
-- Ambas son idempotentes: poner el rol que ya tiene, o dar de baja a alguien
-- que ya no está, devuelven false sin romper nada.
-- ---------------------------------------------------------------------------

create or replace function public.set_company_member_role(
  p_member_profile_id uuid,
  p_role text
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_company uuid;
  target_role public.company_member_role;
  current_role_value public.company_member_role;
begin
  if auth.uid() is null then
    raise insufficient_privilege using message = 'Se requiere una sesión autenticada';
  end if;
  if coalesce(p_role, '') not in ('owner', 'admin', 'recruiter', 'viewer') then
    raise sqlstate 'TFDAT' using message = 'Ese rol de equipo no existe';
  end if;
  target_role := p_role::public.company_member_role;

  target_company := private.caller_company();
  if not public.is_company_manager(target_company) then
    raise insufficient_privilege
      using message = 'Solo owner o admin pueden cambiar roles del equipo';
  end if;

  select cm.member_role into current_role_value
  from public.company_members cm
  where cm.company_id = target_company and cm.profile_id = p_member_profile_id;

  if current_role_value is null then
    raise sqlstate 'TFMEM' using message = 'Esa persona no integra tu equipo';
  end if;
  if current_role_value = target_role then
    return false;   -- idempotencia: nada que cambiar
  end if;

  -- Solo un owner nombra o degrada owners. El trigger lo vuelve a comprobar.
  if (current_role_value = 'owner'::public.company_member_role
      or target_role = 'owner'::public.company_member_role)
     and private.caller_member_role() <> 'owner'::public.company_member_role then
    raise insufficient_privilege
      using message = 'Solo un owner puede nombrar o degradar a otro owner';
  end if;

  update public.company_members cm
  set member_role = target_role
  where cm.company_id = target_company and cm.profile_id = p_member_profile_id;

  return true;
end $$;

revoke all on function public.set_company_member_role(uuid, text) from public;
grant execute on function public.set_company_member_role(uuid, text) to authenticated;

create or replace function public.remove_company_member(p_member_profile_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_company uuid;
  target_role public.company_member_role;
begin
  if auth.uid() is null then
    raise insufficient_privilege using message = 'Se requiere una sesión autenticada';
  end if;

  target_company := private.caller_company();
  if not public.is_company_manager(target_company) then
    raise insufficient_privilege
      using message = 'Solo owner o admin pueden dar de baja a alguien del equipo';
  end if;

  select cm.member_role into target_role
  from public.company_members cm
  where cm.company_id = target_company and cm.profile_id = p_member_profile_id;

  if target_role is null then
    return false;   -- idempotencia: dar de baja dos veces no rompe
  end if;

  if target_role = 'owner'::public.company_member_role
     and private.caller_member_role() <> 'owner'::public.company_member_role then
    raise insufficient_privilege
      using message = 'Solo un owner puede dar de baja a otro owner';
  end if;

  delete from public.company_members cm
  where cm.company_id = target_company and cm.profile_id = p_member_profile_id;

  return true;
end $$;

revoke all on function public.remove_company_member(uuid) from public;
grant execute on function public.remove_company_member(uuid) to authenticated;
