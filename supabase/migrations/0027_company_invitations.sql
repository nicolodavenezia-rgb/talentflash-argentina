-- Bloque E — T-026 (equipo): incorporación de miembros por código de un solo uso.
--
-- POR QUÉ UN CÓDIGO Y NO UN EMAIL: el proyecto no tiene proveedor de correo
-- transaccional (no hay `D-0XX` en COST_DECISIONS.md que lo cubra, y el
-- Inbucket local no es entrega real). Mostrar "invitación enviada" sin un
-- mecanismo de entrega sería mentirle a la empresa. Entonces la RPC devuelve
-- un código que la persona que invita copia y hace llegar por donde quiera; el
-- circuito de aceptación es idéntico al de un enlace por mail y el día que
-- exista proveedor solo hay que agregar el envío.
--
-- El código se muestra UNA sola vez, al crearlo: en la base queda únicamente
-- su SHA-256, así que ni un dump ni un admin pueden reconstruirlo.

create table public.company_invitations (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid not null references public.company_profiles(id) on delete cascade,
  -- Email de destino, normalizado. Se guarda para atar el código a una persona
  -- concreta: sin esto, quien interceptara el código entraría al equipo.
  email        text not null,
  member_role  public.company_member_role not null default 'recruiter',
  -- SHA-256 hex del código. Nunca se guarda el código en claro.
  token_hash   text not null unique,
  invited_by   uuid not null references public.profiles(id),
  expires_at   timestamptz not null,
  accepted_at  timestamptz,
  accepted_by  uuid references public.profiles(id),
  revoked_at   timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint company_invitation_email_shape check (email ~ '^[^@[:space:]]+@[^@[:space:]]+$'),
  constraint company_invitation_role_valid
    check (member_role <> 'owner'::public.company_member_role)
);

create index idx_company_invitations_company
  on public.company_invitations(company_id, created_at desc);
create index idx_company_invitations_pending
  on public.company_invitations(company_id)
  where accepted_at is null and revoked_at is null;

-- 0017 recorrió una sola vez las tablas que existían entonces: el trigger de
-- updated_at hay que engancharlo a mano.
create trigger set_updated_at before update on public.company_invitations
for each row execute function set_updated_at();

-- Fail-closed por partida doble. 0018 otorgó privilegios sobre las tablas que
-- existían entonces, así que ésta nace sin ninguno para anon/authenticated;
-- se deja explícito para que no dependa de ese detalle histórico. Todo el
-- acceso pasa por las RPCs de abajo, que jamás devuelven `token_hash`.
alter table public.company_invitations enable row level security;
revoke all on public.company_invitations from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Normalización del código: se acepta escrito con o sin guiones y en cualquier
-- caja, para que copiarlo a mano no falle por un detalle de tipeo.
-- ---------------------------------------------------------------------------

create or replace function private.invitation_code_hash(p_code text) returns text
language sql immutable set search_path = '' as $$
  select case
    when upper(regexp_replace(coalesce(p_code, ''), '[^0-9A-Za-z]', '', 'g')) ~ '^[0-9A-F]{32}$'
      then encode(
        extensions.digest(
          upper(regexp_replace(p_code, '[^0-9A-Za-z]', '', 'g')), 'sha256'),
        'hex')
    else null
  end;
$$;

revoke all on function private.invitation_code_hash(text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Crear la invitación. Devuelve el código en claro, y es la única vez que
-- existe fuera de la cabeza de quien invita.
--
-- NO se consulta si la cuenta existe: la respuesta es idéntica para un email
-- registrado y para uno que no, así que este endpoint no sirve para enumerar
-- usuarios. Que el destinatario tenga rol `company` se comprueba recién al
-- aceptar, que es cuando hay una sesión real que lo demuestra.
-- ---------------------------------------------------------------------------

create or replace function public.create_company_invitation(
  p_email text,
  p_role text
) returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_company uuid;
  target_role public.company_member_role;
  clean_email text;
  code text;
begin
  if auth.uid() is null then
    raise insufficient_privilege using message = 'Se requiere una sesión autenticada';
  end if;
  if coalesce(p_role, '') not in ('admin', 'recruiter', 'viewer') then
    raise sqlstate 'TFDAT'
      using message = 'Solo se puede invitar como admin, recruiter o viewer';
  end if;
  target_role := p_role::public.company_member_role;

  clean_email := lower(btrim(coalesce(p_email, '')));
  if clean_email !~ '^[^@[:space:]]+@[^@[:space:]]+$' or length(clean_email) > 254 then
    raise sqlstate 'TFDAT' using message = 'Ese email no parece válido';
  end if;

  target_company := private.caller_company();
  if not public.is_company_manager(target_company) then
    raise insufficient_privilege
      using message = 'Solo owner o admin pueden invitar a alguien al equipo';
  end if;
  -- Un admin de empresa no puede fabricar otro admin.
  if target_role = 'admin'::public.company_member_role
     and private.caller_member_role() <> 'owner'::public.company_member_role then
    raise insufficient_privilege
      using message = 'Solo un owner puede invitar a alguien como admin';
  end if;

  -- Una invitación viva por email y empresa: pedir de nuevo revoca la anterior
  -- en vez de dejar dos códigos válidos dando vueltas.
  update public.company_invitations ci
  set revoked_at = now()
  where ci.company_id = target_company
    and ci.email = clean_email
    and ci.accepted_at is null
    and ci.revoked_at is null;

  code := upper(encode(extensions.gen_random_bytes(16), 'hex'));

  insert into public.company_invitations
    (company_id, email, member_role, token_hash, invited_by, expires_at)
  values
    (target_company, clean_email, target_role,
     private.invitation_code_hash(code), auth.uid(), now() + interval '7 days');

  return code;
end $$;

revoke all on function public.create_company_invitation(text, text) from public;
grant execute on function public.create_company_invitation(text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Aceptar. La membresía NACE ACÁ: antes de que la persona acepte no existe
-- ninguna fila en company_members, así que una invitación pendiente no otorga
-- absolutamente nada.
--
-- Todos los rechazos devuelven el mismo SQLSTATE y el mismo mensaje: un código
-- inexistente, vencido, ya usado, revocado o dirigido a otra persona son
-- indistinguibles desde afuera, para que nadie pueda sondear códigos ajenos.
-- ---------------------------------------------------------------------------

create or replace function public.accept_company_invitation(p_code text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  caller_email text;
  invitation public.company_invitations;
  already_member uuid;
begin
  if uid is null then
    raise insufficient_privilege using message = 'Se requiere una sesión autenticada';
  end if;

  if not exists (
    select 1 from public.profiles p
    where p.id = uid and p.role = 'company'::public.user_role and p.deleted_at is null
  ) then
    raise insufficient_privilege
      using message = 'Solo una cuenta de empresa puede sumarse a un equipo';
  end if;

  select lower(u.email) into caller_email from auth.users u where u.id = uid;

  -- `for update` serializa dos canjes simultáneos del mismo código: el segundo
  -- espera y encuentra accepted_at ya puesto.
  select ci.* into invitation
  from public.company_invitations ci
  where ci.token_hash = private.invitation_code_hash(p_code)
  for update;

  if invitation.id is null
     or invitation.revoked_at is not null
     or invitation.email is distinct from caller_email then
    raise sqlstate 'TFINV'
      using message = 'Ese código no sirve: puede estar vencido, ya usado o no ser para vos';
  end if;

  -- Idempotencia del doble tap: si la aceptó ESTA misma persona, se devuelve
  -- la empresa sin tocar nada. Va antes del vencimiento a propósito — una
  -- invitación ya canjeada no vuelve a estar pendiente cuando pasa su fecha, y
  -- la membresía que creó sigue existiendo.
  if invitation.accepted_at is not null then
    if invitation.accepted_by = uid then
      return invitation.company_id;
    end if;
    raise sqlstate 'TFINV'
      using message = 'Ese código no sirve: puede estar vencido, ya usado o no ser para vos';
  end if;

  if invitation.expires_at <= now() then
    raise sqlstate 'TFINV'
      using message = 'Ese código no sirve: puede estar vencido, ya usado o no ser para vos';
  end if;

  -- Mientras no exista política multiempresa (ver `private.caller_company`),
  -- una cuenta integra una sola empresa. No se degrada a un cambio silencioso
  -- de equipo: se rechaza y se explica.
  select cm.company_id into already_member
  from public.company_members cm
  where cm.profile_id = uid
  limit 1;

  if already_member is not null then
    if already_member = invitation.company_id then
      -- Idempotencia: aceptar dos veces no duplica ni rompe.
      update public.company_invitations ci
      set accepted_at = coalesce(ci.accepted_at, now()), accepted_by = uid
      where ci.id = invitation.id;
      return invitation.company_id;
    end if;
    raise sqlstate 'TFEMP'
      using message = 'Tu cuenta ya integra otra empresa';
  end if;

  insert into public.company_members
    (company_id, profile_id, member_role, invited_by)
  values
    (invitation.company_id, uid, invitation.member_role, invitation.invited_by);

  update public.company_invitations ci
  set accepted_at = now(), accepted_by = uid
  where ci.id = invitation.id;

  return invitation.company_id;
end $$;

revoke all on function public.accept_company_invitation(text) from public;
grant execute on function public.accept_company_invitation(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Listar y revocar. `token_hash` no sale nunca de la base.
-- ---------------------------------------------------------------------------

create or replace function public.list_company_invitations()
returns table (
  id uuid,
  email text,
  member_role text,
  invited_by uuid,
  expires_at timestamptz,
  accepted_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  target_company uuid;
begin
  if auth.uid() is null then
    raise insufficient_privilege using message = 'Se requiere una sesión autenticada';
  end if;
  target_company := private.caller_company();
  if not public.is_company_manager(target_company) then
    raise insufficient_privilege
      using message = 'Solo owner o admin pueden ver las invitaciones del equipo';
  end if;

  return query
    select ci.id, ci.email, ci.member_role::text, ci.invited_by, ci.expires_at,
           ci.accepted_at, ci.revoked_at, ci.created_at
    from public.company_invitations ci
    where ci.company_id = target_company
    order by ci.created_at desc;
end $$;

revoke all on function public.list_company_invitations() from public;
grant execute on function public.list_company_invitations() to authenticated;

create or replace function public.revoke_company_invitation(p_invitation_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_company uuid;
  affected int;
begin
  if auth.uid() is null then
    raise insufficient_privilege using message = 'Se requiere una sesión autenticada';
  end if;
  target_company := private.caller_company();
  if not public.is_company_manager(target_company) then
    raise insufficient_privilege
      using message = 'Solo owner o admin pueden revocar una invitación';
  end if;

  update public.company_invitations ci
  set revoked_at = now()
  where ci.id = p_invitation_id
    and ci.company_id = target_company
    and ci.accepted_at is null
    and ci.revoked_at is null;

  get diagnostics affected = row_count;
  return affected > 0;   -- revocar dos veces devuelve false, no rompe
end $$;

revoke all on function public.revoke_company_invitation(uuid) from public;
grant execute on function public.revoke_company_invitation(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Lectura del equipo. `cm_select` ya deja a un miembro ver las filas de SU
-- empresa, pero company_members no trae ni el nombre ni el email de la
-- persona, y `profiles` no es legible en bloque. Esta RPC arma la vista del
-- equipo con lo mínimo indispensable.
-- ---------------------------------------------------------------------------

create or replace function public.list_company_members()
returns table (
  profile_id uuid,
  full_name text,
  email text,
  member_role text,
  position_title text,
  relationship text,
  invited_by uuid,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  target_company uuid;
begin
  if auth.uid() is null then
    raise insufficient_privilege using message = 'Se requiere una sesión autenticada';
  end if;
  target_company := private.caller_company();

  return query
    select cm.profile_id, p.full_name, p.email, cm.member_role::text,
           cm.position_title, cm.relationship, cm.invited_by, cm.created_at
    from public.company_members cm
    join public.profiles p on p.id = cm.profile_id
    where cm.company_id = target_company
    order by
      case cm.member_role
        when 'owner'::public.company_member_role then 0
        when 'admin'::public.company_member_role then 1
        when 'recruiter'::public.company_member_role then 2
        else 3
      end,
      cm.created_at;
end $$;

revoke all on function public.list_company_members() from public;
grant execute on function public.list_company_members() to authenticated;
