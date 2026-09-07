-- Bloque E — cierre de los cuatro agujeros que la auditoría del PR #3 dejó
-- abiertos. Nada de esto es cosmético: cada sección hace FALSA hoy una
-- afirmación escrita en 0026, 0027 o 0028.
--
--   1. La invitación de un solo uso era opcional: `cm_manage` dejaba a un
--      manager insertar en `company_members` por PostgREST.
--   2. El lock de `accept_company_invitation` era el de la invitación, no el de
--      la cuenta: dos códigos distintos para la misma persona podían entrar a
--      la vez y dejarla en dos empresas.
--   3. `company_can_publish` no lo llamaba nadie: una empresa `pending` podía
--      insertar en `public.jobs` con `status = 'active'`.
--   4. `private.caller_company()` señalaba con el MISMO sqlstate "no integrás
--      ninguna empresa" y "integrás más de una", así que el cliente no podía
--      fallar cerrado de forma distinta.

-- ===========================================================================
-- 1. La membresía solo nace por invitación, bootstrap u onboarding
-- ===========================================================================
--
-- `cm_manage` (0026) es una policy de INSERT: `with check
-- (public.is_company_manager(company_id))`. Corrigió el cruce entre empresas
-- del Bloque A, pero dejó en pie la escritura directa: un owner o un admin de
-- empresa podía hacer
--
--   POST /rest/v1/company_members {company_id, profile_id, member_role}
--
-- sobre SU empresa y sumar a cualquier cuenta con rol `company` sin pasar por
-- ninguna invitación. Todo el circuito de 0027 —código de un solo uso, atado a
-- un email, con vencimiento y revocación— quedaba como un camino opcional y
-- más incómodo que el atajo. El test 015 llegaba a usar ese INSERT como
-- "control positivo", así que la suite fijaba el bypass en vez de prohibirlo.
--
-- Se cierra por partida doble, y a propósito:
--
--   - Se ELIMINA la policy. Sin policy de INSERT, RLS deniega la operación
--     aunque alguien reponga el privilegio más adelante.
--   - Se REVOCA el privilegio. Sin INSERT, PostgREST corta antes de llegar a
--     RLS y el error es 42501 en vez de una violación de policy.
--
-- Ninguna de las dos alcanza sola: un `grant insert` futuro (0018 concedió DML
-- en bloque a `authenticated`, ese patrón puede repetirse) reabriría el agujero
-- si la policy siguiera ahí, y una policy nueva lo reabriría si solo hubiera
-- REVOKE. Las tres puertas legítimas son SECURITY DEFINER, corren como
-- `postgres` (rolbypassrls) y no dependen ni de la policy ni del grant:
--
--   - public.create_company_with_owner  (0018/0025 — bootstrap del owner)
--   - public.complete_company_onboarding (0022 — onboarding del owner)
--   - public.accept_company_invitation   (0027 — el resto del equipo)
--
-- UPDATE y DELETE se dejan como estaban (`cm_update`, `cm_delete`, ambas
-- gateadas por `is_company_manager` y revalidadas por
-- `private.protect_company_member_write`): ahí no hay un circuito paralelo que
-- se estuviera salteando.

drop policy if exists cm_manage on public.company_members;

revoke insert on public.company_members from anon, authenticated;

comment on table public.company_members is
  'Equipo de la empresa. El alta NO es escritura directa: nace solo en '
  'create_company_with_owner, complete_company_onboarding o '
  'accept_company_invitation (0031).';

-- ===========================================================================
-- 2. Un único lock por cuenta para todas las altas de membresía
-- ===========================================================================
--
-- `accept_company_invitation` (0027) tomaba `for update` sobre la fila de la
-- INVITACIÓN. Eso serializa dos canjes del MISMO código, que es lo que ese
-- comentario prometía, pero no serializa dos códigos DISTINTOS dirigidos a la
-- misma cuenta: cada transacción bloquea una fila diferente, las dos leen
-- "cero membresías" en el `select ... limit 1` de más abajo y las dos insertan.
-- Resultado: una cuenta en dos empresas, que es exactamente el estado que
-- `private.caller_company()` no sabe resolver y que deja al equipo entero sin
-- poder operar.
--
-- El objeto que hay que serializar no es la invitación: es la CUENTA. Por eso
-- el lock se toma sobre la fila de `public.profiles` del interesado, y lo toman
-- las TRES puertas, no solo la de invitaciones — si no, `create_company_with_owner`
-- corriendo en paralelo con un canje produce el mismo estado partido.
--
-- Por qué la fila de `profiles` y no un advisory lock: la fila ya existe, ya
-- tiene el ciclo de vida correcto (se borra con la cuenta), no hay que elegir
-- un espacio de claves ni preocuparse por colisiones de hash, y el lock muere
-- con la transacción sin `unlock` explícito. `for update` sobre `profiles` no
-- bloquea ninguna lectura: en Postgres los lectores no esperan a los escritores.
--
-- ORDEN DE LOCKS. `create_company_with_owner` y `complete_company_onboarding`
-- toman una sola fila de `profiles` (la de la cuenta) y después escriben filas
-- nuevas, así que no pueden formar ciclo entre ellas.
--
-- `accept_company_invitation` es el caso delicado y merece su propia regla,
-- porque toma DOS filas de `profiles` sin saberlo: el `insert into
-- company_members` lleva `invited_by`, y esa FK hace que Postgres tome un
-- `for key share` sobre la fila de `profiles` del INVITADOR, al final de todo.
-- Con dos canjes cruzados —X invitó a Y, Y invitó a X, y a los dos los dieron
-- de baja de sus empresas después de invitar, todo con RPC de la app— cada
-- transacción termina esperando la fila que tiene la otra:
--
--   ERROR: deadlock detected … while locking tuple in relation "profiles"
--   SQL statement "SELECT 1 FROM ONLY public.profiles x WHERE id = $1 FOR KEY SHARE"
--
-- Postgres aborta una de las dos, así que no queda estado partido, pero el
-- canje se pierde con un SQLSTATE 40P01 que no está en el contrato de la
-- función (TFINV / TFEMP / 42501) ni lo mapea el cliente.
--
-- La regla que lo cierra: cuando hacen falta las dos filas, se toman SIEMPRE en
-- el mismo orden total —el del uuid, con `least`/`greatest`— antes del insert.
-- Dos transacciones que quieran las mismas dos filas las piden en el mismo
-- orden, así que una espera y la otra pasa; nunca se cruzan.
--
-- HAY UN SEGUNDO CICLO, y necesita su propia regla. El `insert into
-- company_members` también lleva `company_id`, así que toma un `for key share`
-- sobre `company_profiles`. Y `request_company_verification` (0030) hace lo
-- contrario: toma `company_profiles` con `for update` en su PRIMERA sentencia y
-- después necesita la fila de `profiles` del owner, por la FK `submitted_by`
-- del insert en `company_verifications`. Cuando el invitador ES el owner —el
-- caso normal— las dos transacciones se cruzan. Reproducido:
--
--   [B] request_company_verification -> ERROR: deadlock detected
--
-- ORDEN GLOBAL, entonces: `company_profiles` SIEMPRE antes que `profiles`.
-- `accept_company_invitation` toma la fila de la empresa (con `for key share`)
-- antes de las de `profiles`, y así queda del mismo lado que
-- `request_company_verification` y `admin_review_company_verification`.
--
-- EXCEPCIÓN, y por qué es segura: `create_company_with_owner` y
-- `complete_company_onboarding` toman `profiles` y recién después INSERTAN su
-- `company_profiles`. Es el orden inverso, pero la fila de empresa es nueva y
-- creada en la misma transacción: ninguna otra transacción puede tenerla ni
-- quererla, así que no hay ciclo que formar.

create or replace function private.lock_membership_slot(p_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  locked uuid;
begin
  if p_profile_id is null then
    raise insufficient_privilege using message = 'Se requiere una sesión autenticada';
  end if;

  -- `for update` y no `for share`: dos altas concurrentes tienen que excluirse
  -- mutuamente, no coexistir.
  select p.id into locked
  from public.profiles p
  where p.id = p_profile_id
  for update;

  if locked is null then
    raise sqlstate 'TFMEM' using message = 'La cuenta no existe';
  end if;
end $$;

comment on function private.lock_membership_slot(uuid) is
  'Serializa TODAS las altas de membresía de una cuenta (0031). Se toma antes '
  'de contar membresías, nunca después.';

revoke all on function private.lock_membership_slot(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- `caller_company` distingue "ninguna" de "más de una".
--
-- 0026 usaba `TFEMP` para los dos casos. Son situaciones opuestas: la primera
-- es normal (una cuenta recién creada) y la segunda es un estado partido que
-- el cliente NO puede resolver eligiendo una. Con el mismo sqlstate, la única
-- forma de distinguirlas desde Flutter era mirar el texto del mensaje.
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
    -- Sqlstate propio: el cliente tiene que fallar cerrado, no elegir la
    -- primera. Con las tres puertas serializadas y contando lo mismo, este
    -- estado no se alcanza por ninguna secuencia de llamadas de un cliente;
    -- sí se alcanza con una escritura privilegiada por fuera de las tres
    -- puertas (service_role, un fix a mano, o dar de baja una empresa —el
    -- `deleted_at` de company_profiles solo lo escribe el backend, porque
    -- `private.protect_company_profile_update` lo corta para 'authenticated').
    -- La función es la última línea para ese caso.
    raise sqlstate 'TFMUL'
      using message = 'Tu cuenta integra más de una empresa: hace falta elegir cuál';
  end if;
  return companies[1];
end $$;

revoke all on function private.caller_company() from public, anon, authenticated;

-- ===========================================================================
-- 3. Las tres puertas toman el lock antes de contar membresías
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 3.a Canje de la invitación.
--
-- Cambia solo el orden: el lock de la cuenta va ANTES del `for update` de la
-- invitación. Todo lo demás (mensajes indistinguibles, idempotencia del doble
-- tap, la membresía naciendo acá) queda igual que en 0027.
--
-- La invitación perdedora NO queda marcada como aceptada: el `raise` de
-- 'TFEMP' ocurre antes de cualquier `update`, así que la transacción entera
-- vuelve atrás y la fila queda intacta y canjeable por su destinatario real.
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
  -- Las dos filas de `profiles` que esta función necesita, en orden de uuid.
  lock_primero uuid;
  lock_segundo uuid;
  empresa_viva uuid;
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

  -- `for update` sobre la invitación sigue haciendo falta: serializa dos
  -- canjes del MISMO código.
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

  -- La empresa que invita tiene que seguir viva. 0027 no lo miraba: una
  -- invitación emitida antes de la baja seguía siendo canjeable, y quien la
  -- canjeaba entraba a una empresa que `private.caller_company()` ya no
  -- resuelve — quedaba adentro de un equipo muerto y sin poder operar.
  --
  -- Y se toma CON LOCK, antes que las filas de `profiles`: ver la regla de
  -- orden global en la cabecera de esta sección. `for key share` es lo mínimo
  -- que hace falta (que la fila siga existiendo) y alcanza para el orden,
  -- porque entra en conflicto con el `for update` que toma
  -- `request_company_verification`.
  select cp.id into empresa_viva
  from public.company_profiles cp
  where cp.id = invitation.company_id and cp.deleted_at is null
  for key share;

  if empresa_viva is null then
    raise sqlstate 'TFEMP' using message = 'Esa empresa ya no está activa';
  end if;

  -- LOCK DE LA CUENTA (y del invitador), en orden de uuid.
  --
  -- Va acá y no antes de leer la invitación porque hasta este punto no se sabe
  -- quién es el invitador, y las dos filas tienen que pedirse en un orden que
  -- no dependa de cuál es "la propia". Sigue estando ANTES de contar
  -- membresías, que es lo que la serialización tiene que proteger.
  --
  -- La fila del invitador se toma acá a propósito, aunque el `insert` de más
  -- abajo la tomaría igual por la FK `invited_by`: pedirla ahí, al final y en
  -- un orden que decide el dato de la invitación, es exactamente lo que
  -- produce el deadlock cruzado descripto en la cabecera.
  lock_primero := least(uid, invitation.invited_by);
  lock_segundo := greatest(uid, invitation.invited_by);
  perform private.lock_membership_slot(lock_primero);
  if lock_segundo is distinct from lock_primero then
    perform private.lock_membership_slot(lock_segundo);
  end if;

  -- Bajo el lock: el conteo que se lee acá ya no puede quedar viejo.
  --
  -- El join con company_profiles NO es decorativo: sin él esta puerta filtraba
  -- las empresas dadas de baja distinto que `create_company_with_owner` y
  -- `complete_company_onboarding`, que sí las descartan. La asimetría dejaba a
  -- una cuenta cuya única empresa fue dada de baja sin poder sumarse a ningún
  -- equipo (acá veía "ya integrás otra") mientras las otras dos puertas la
  -- dejaban empezar de cero. Las tres cuentan lo mismo: membresías VIVAS.
  select cm.company_id into already_member
  from public.company_members cm
  join public.company_profiles cp on cp.id = cm.company_id
  where cm.profile_id = uid
    and cp.deleted_at is null
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
-- 3.b Bootstrap del owner.
--
-- 0018/0025 no comprobaban NADA sobre membresías previas: cada llamada creaba
-- una empresa y una membresía más. Una cuenta podía terminar en tres empresas
-- llamando tres veces, y ahí `private.caller_company()` la dejaba sin poder
-- editar el perfil, ni invitar, ni pedir la verificación.
--
-- Resultado definido para cada caso, bajo el lock:
--   - ya es OWNER de una empresa viva  → devuelve esa empresa (idempotente,
--     mismo contrato que `complete_company_onboarding`);
--   - ya es STAFF de otra empresa      → TFEMP, no se crea nada;
--   - no integra ninguna               → crea empresa + membresía owner.
--
-- El chequeo va ANTES del `insert into company_profiles`, así que un rechazo
-- no puede dejar una empresa huérfana ni siquiera por un instante. (El `raise`
-- ya abortaba la sentencia entera y revertía el insert, pero depender de eso
-- obliga a razonar sobre la atomicidad de PL/pgSQL en cada lectura futura.)
-- ---------------------------------------------------------------------------

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
  clean_cuit text;
  existing_company uuid;
  existing_role public.company_member_role;
begin
  if auth.uid() is null then
    raise insufficient_privilege using message = 'Se requiere una sesión autenticada';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'company'::public.user_role and p.deleted_at is null
  ) then
    raise insufficient_privilege
      using message = 'Solo un perfil de empresa puede crear una empresa';
  end if;
  if nullif(btrim(coalesce(p_name, '')), '') is null then
    raise sqlstate 'TFDAT' using message = 'La empresa necesita un nombre';
  end if;

  clean_cuit := private.cuit_format(p_cuit);
  if clean_cuit is null then
    raise sqlstate 'TFCUI'
      using message = 'El CUIT no es válido: revisá el dígito verificador';
  end if;

  -- La validación barata va primero; el lock se toma lo más tarde posible y se
  -- suelta con la transacción.
  perform private.lock_membership_slot(auth.uid());

  -- Se miran solo empresas VIVAS, igual que `private.caller_company()`: si la
  -- única empresa de la cuenta está dada de baja, la cuenta puede volver a
  -- empezar. Si se filtraran las bajas de forma distinta acá y allá, una cuenta
  -- podría quedar bloqueada para crear y a la vez sin empresa que resolver.
  select cm.company_id, cm.member_role into existing_company, existing_role
  from public.company_members cm
  join public.company_profiles cp on cp.id = cm.company_id
  where cm.profile_id = auth.uid()
    and cp.deleted_at is null
  order by (cm.member_role = 'owner'::public.company_member_role) desc, cm.created_at
  limit 1;

  if existing_company is not null then
    if existing_role = 'owner'::public.company_member_role then
      return existing_company;
    end if;
    raise sqlstate 'TFEMP'
      using message = 'Tu cuenta ya integra otra empresa: no podés crear una nueva';
  end if;

  insert into public.company_profiles (name, legal_name, cuit, created_by)
  values (btrim(p_name), nullif(btrim(coalesce(p_legal_name, '')), ''),
          clean_cuit, auth.uid())
  returning id into company_id;

  insert into public.company_members (company_id, profile_id, member_role)
  values (company_id, auth.uid(), 'owner'::public.company_member_role);

  return company_id;
end $$;

revoke all on function public.create_company_with_owner(text, text, text) from public;
grant execute on function public.create_company_with_owner(text, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 3.c Onboarding de empresa.
--
-- 0022 ya era idempotente, pero su guarda miraba `member_role = 'owner'`: una
-- cuenta que fuera `recruiter` de otra empresa pasaba de largo y creaba una
-- empresa SEGUNDA. Ahora se mira CUALQUIER membresía viva, y bajo el lock.
-- ---------------------------------------------------------------------------

create or replace function public.complete_company_onboarding(
  p_legal_name text,
  p_trade_name text,
  p_cuit text,
  p_sector_id uuid,
  p_size_range text,
  p_provincia_id uuid,
  p_localidad_id uuid,
  p_website text,
  p_applicant_full_name text,
  p_applicant_position text,
  p_applicant_relationship text
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  existing_company uuid;
  existing_role public.company_member_role;
  new_company uuid;
  clean_cuit text;
  clean_website text;
begin
  if uid is null then
    raise insufficient_privilege using message = 'Se requiere una sesión autenticada';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = uid and p.role = 'company'::public.user_role and p.deleted_at is null
  ) then
    raise insufficient_privilege
      using message = 'Solo un perfil de empresa puede terminar este onboarding';
  end if;

  if not private.mandatory_consents_current(uid) then
    raise sqlstate 'TFCNS'
      using message = 'Faltan consentimientos obligatorios de la versión vigente';
  end if;

  -- LOCK DE LA CUENTA antes de la guarda de idempotencia: dos envíos
  -- simultáneos del formulario se serializan y el segundo ve la empresa que
  -- creó el primero.
  perform private.lock_membership_slot(uid);

  -- Idempotencia: reintentos y dobles taps devuelven la empresa ya creada. Se
  -- mira CUALQUIER rol, no solo `owner`.
  select cm.company_id, cm.member_role into existing_company, existing_role
  from public.company_members cm
  join public.company_profiles cp on cp.id = cm.company_id
  where cm.profile_id = uid
    and cp.deleted_at is null
  order by (cm.member_role = 'owner'::public.company_member_role) desc, cm.created_at
  limit 1;

  if existing_company is not null then
    if existing_role <> 'owner'::public.company_member_role then
      raise sqlstate 'TFEMP'
        using message = 'Tu cuenta ya integra otra empresa: no podés crear una nueva';
    end if;
    update public.profiles
    set onboarding_completed = true
    where id = uid and not onboarding_completed;
    return existing_company;
  end if;

  if nullif(btrim(coalesce(p_legal_name, '')), '') is null
     or nullif(btrim(coalesce(p_trade_name, '')), '') is null
     or nullif(btrim(coalesce(p_applicant_full_name, '')), '') is null
     or nullif(btrim(coalesce(p_applicant_position, '')), '') is null then
    raise sqlstate 'TFDAT'
      using message = 'Faltan datos obligatorios de la empresa o del solicitante';
  end if;

  -- T-027: 11 dígitos Y dígito verificador. La verificación contra el padrón
  -- de ARCA sigue fuera de alcance (revisión humana, T-028).
  -- OJO: esta es la versión de 0025, no la de 0022. `create or replace` pisa la
  -- definición ENTERA, así que rehacer la función desde una migración vieja
  -- revierte en silencio todo lo que le hicieron las intermedias.
  clean_cuit := private.cuit_format(p_cuit);
  if clean_cuit is null then
    raise sqlstate 'TFCUI'
      using message = 'El CUIT no es válido: revisá el dígito verificador';
  end if;

  if p_sector_id is null or not exists (
    select 1 from public.sectors s where s.id = p_sector_id and s.is_active
  ) then
    raise sqlstate 'TFDAT' using message = 'El sector elegido no está disponible';
  end if;

  if coalesce(p_size_range, '') not in ('1-10', '11-50', '51-200', '201-500', '501+') then
    raise sqlstate 'TFDAT' using message = 'El tamaño de la empresa no es válido';
  end if;

  if p_provincia_id is null or p_localidad_id is null or not exists (
    select 1 from public.geo_localidades l
    where l.id = p_localidad_id and l.provincia_id = p_provincia_id
  ) then
    raise sqlstate 'TFDAT'
      using message = 'La localidad no pertenece a la provincia elegida';
  end if;

  if coalesce(p_applicant_relationship, '')
     not in ('owner', 'partner', 'manager', 'hr', 'other') then
    raise sqlstate 'TFDAT'
      using message = 'La relación del solicitante con la empresa no es válida';
  end if;

  clean_website := nullif(btrim(coalesce(p_website, '')), '');
  if clean_website is not null and clean_website !~ '^https?://[^[:space:]]+$' then
    raise sqlstate 'TFDAT' using message = 'El sitio web no parece una URL válida';
  end if;

  insert into public.company_profiles
    (name, legal_name, cuit, sector_id, size_range,
     provincia_id, localidad_id, website, created_by)
  values
    (btrim(p_trade_name), btrim(p_legal_name), clean_cuit, p_sector_id, p_size_range,
     p_provincia_id, p_localidad_id, clean_website, uid)
  returning id into new_company;

  insert into public.company_members
    (company_id, profile_id, member_role, position_title, relationship)
  values
    (new_company, uid, 'owner'::public.company_member_role,
     btrim(p_applicant_position), p_applicant_relationship);

  update public.profiles
  set full_name = btrim(p_applicant_full_name),
      onboarding_completed = true
  where id = uid;

  return new_company;
end $$;

revoke all on function public.complete_company_onboarding(text, text, text, uuid, text, uuid, uuid, text, text, text, text) from public;
grant execute on function public.complete_company_onboarding(text, text, text, uuid, text, uuid, uuid, text, text, text, text) to authenticated;

-- ===========================================================================
-- 4. `company_can_publish` conectada a `public.jobs`
-- ===========================================================================
--
-- 0028 dejó el helper escrito, probado contra los cuatro estados… y sin llamar
-- desde ningún lado, con un comentario que difería la conexión a T-030. Eso era
-- un error de hecho: `public.jobs` existe desde 0007 y 0018 le concedió DML a
-- `authenticated`, así que la tabla YA es superficie de PostgREST. Diferirlo no
-- dejaba el criterio "empresa no verificada no publica" sin implementar: lo
-- dejaba INCUMPLIDO en una tabla escribible.
--
-- Lo que se cierra acá es exactamente el criterio de aceptación de T-028. El
-- CRUD de oferta, las transiciones completas (`paused`/`expired`/`closed`), el
-- formulario y las reglas salariales siguen siendo T-030.
--
-- Qué queda permitido sin verificación: crear y editar BORRADORES. Una empresa
-- puede preparar sus búsquedas mientras espera la revisión; lo único que no
-- puede es que se vean.
--
-- `active` es el único estado que `jobs_public_select` publica, así que es el
-- único que se gatea. `paused`, `expired` y `closed` no son visibles para
-- terceros y no hay forma de llegar a `active` desde ellos sin pasar por el
-- `with check` del UPDATE.
--
-- NOTA sobre "estado desconocido": `verification_status` es un enum de cuatro
-- valores, así que un estado fuera del conjunto no es representable en la
-- columna. La lista blanca de `company_can_publish` (exactamente `approved`, y
-- además `deleted_at is null`) es lo que hace que cualquier valor que no sea
-- `approved` —incluido `in_review`— caiga del lado del NO.

drop policy if exists jobs_company_write on public.jobs;
create policy jobs_company_write on public.jobs for insert to authenticated
  with check (
    public.is_company_member(company_id)
    -- El cliente no puede firmar la oferta con el uuid de otra persona.
    and created_by = auth.uid()
    and (status <> 'active'::public.job_status
         or public.company_can_publish(company_id))
  );

drop policy if exists jobs_company_update on public.jobs;
create policy jobs_company_update on public.jobs for update to authenticated
  using (public.is_company_member(company_id))
  with check (
    -- Sobre la fila NUEVA: sin esto, `with check` hereda el `using` y un
    -- borrador podía pasar a `active` sin verificación.
    public.is_company_member(company_id)
    and (status <> 'active'::public.job_status
         or public.company_can_publish(company_id))
  );

-- La oferta activa de una empresa que perdió la aprobación deja de ser pública
-- en el instante en que cambia `verification_status`: no hace falta ningún job
-- que salga a despublicar ofertas, y no hay ventana entre el rechazo y el
-- ocultamiento. La empresa la sigue viendo (rama `is_company_member`), así que
-- no "desaparece" de su panel.
drop policy if exists jobs_public_select on public.jobs;
create policy jobs_public_select on public.jobs for select
  using (
    (status = 'active'::public.job_status
     and deleted_at is null
     and public.company_can_publish(company_id))
    or public.is_company_member(company_id)
    or public.is_admin()
  );

-- ---------------------------------------------------------------------------
-- Columnas de autoría e identidad de la oferta: inmutables desde el cliente.
--
-- La policy de UPDATE ya impide mover la oferta a una empresa que el caller no
-- integra, pero `with check` no puede comparar contra la fila VIEJA: no vería
-- una mudanza entre dos empresas que el caller sí integra. Mientras rija "una
-- empresa por cuenta" ese caso no existe, pero la regla no debería depender de
-- una política de producto que sigue abierta. El trigger sí ve `old`.
--
-- RELACIÓN CON `private.protect_job_update` (0018), que YA existe sobre esta
-- misma tabla y no se toca: aquél cubre las mismas columnas en UPDATE (y además
-- `id` y `deleted_at`), pero lleva `and not public.is_admin()` — el mismo
-- escape que 0028 tuvo que sacarle a `protect_company_profile_update`. Con esa
-- exención, una cuenta que sea a la vez admin de plataforma y miembro de la
-- empresa puede reescribir `created_by` de una oferta suya por PostgREST y
-- falsificar la autoría. Este trigger NO tiene la exención, así que la
-- inmutabilidad de `company_id` y `created_by` vale para todos.
--
-- Lo que se deja como está, a propósito: `id` y `deleted_at` siguen cubiertos
-- solo por 0018, con su escape. Cerrarlo tocaría el borrado lógico de ofertas,
-- que es de T-030 y podría hacer falta para la moderación de T-077; no se
-- adelanta acá.
--
-- El paso por INSERT sí es nuevo: 0018 solo tiene trigger de UPDATE.
-- ---------------------------------------------------------------------------

create or replace function private.protect_job_write() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- `auth.role()` lee el JWT: distingue una llamada del cliente de una
  -- escritura del backend (service_role) o de una migración. Mismo criterio
  -- que `private.protect_company_member_write` (0026).
  --
  -- `is distinct from` y no `<>`: sin JWT (seed, migración, psql directo)
  -- `auth.role()` devuelve NULL y `NULL <> 'authenticated'` es NULL, que en un
  -- `if` NO entra — el guard se habría aplicado justamente a las escrituras que
  -- tiene que dejar pasar. Es el mismo motivo por el que 0026 escribe
  -- `is_client and …` en vez de `not is_client`.
  if auth.role() is distinct from 'authenticated' then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.created_by is distinct from auth.uid() then
      raise insufficient_privilege
        using message = 'La oferta se firma con la cuenta que la crea';
    end if;
  elsif tg_op = 'UPDATE' then
    if new.company_id is distinct from old.company_id
       or new.created_by is distinct from old.created_by
       or new.created_at is distinct from old.created_at then
      raise insufficient_privilege
        using message = 'No se pueden modificar columnas protegidas de jobs';
    end if;
  end if;

  return new;
end $$;

revoke all on function private.protect_job_write() from public, anon, authenticated;

drop trigger if exists protect_job_write on public.jobs;
create trigger protect_job_write
before insert or update on public.jobs
for each row execute function private.protect_job_write();

-- ---------------------------------------------------------------------------
-- El video pitch de la oferta hereda la misma regla.
--
-- `videos_company_select` tenía una rama que hacía visible a CUALQUIERA el
-- video de una oferta `active`. Con la policy de jobs corregida, la oferta de
-- una empresa no aprobada deja de verse pero su video seguía visible: el
-- contenido publicitario de una empresa sin verificar quedaba accesible por su
-- uuid. Postgres no permite parchear una rama, así que hay que recrear la
-- policy entera.
--
-- OJO CON DE QUÉ VERSIÓN SE PARTE: la definición vigente es la de **0023**, no
-- la de 0015. 0023 ELIMINÓ a propósito la rama de "video de candidato
-- publicado" —entregaba la fila completa de `videos` (con `owner_profile_id`,
-- que es el id de auth del candidato, y `playback_url`) y permitía enumerar
-- candidatos publicados por REST— y dejó solo dos ramas. Recrear desde 0015
-- reintroduce esa fuga en silencio: hoy quedaría inerte, porque 0023 también
-- le sacó a la empresa el SELECT sobre `candidate_profiles` y la subconsulta no
-- devuelve nada, pero volvería a abrirse sola el día que alguna policy vuelva a
-- dar lectura sobre esa tabla. Se parte de 0023 y se le agrega SOLO el filtro
-- de publicabilidad.
-- ---------------------------------------------------------------------------

drop policy if exists videos_company_select on public.videos;
create policy videos_company_select on public.videos for select
  using (
    deleted_at is null and status = 'ready'::public.video_status and (
      exists (select 1 from public.job_applications a
              join public.jobs j on j.id = a.job_id
              where a.video_id = videos.id and public.is_company_member(j.company_id))
      -- Video pitch de la propia oferta, SOLO mientras la oferta sea realmente
      -- publicable.
      --
      -- "Visible a todos" hay que leerlo como "a cualquier sesión
      -- autenticada": `anon` no llega a evaluar esta policy porque la rama de
      -- arriba mira `job_applications`, tabla sobre la que no tiene SELECT, y
      -- la lectura entera muere con 42501. Es PREEXISTENTE —se comprobó que
      -- pasa igual con la policy de 0023— y su arreglo (dar visibilidad
      -- deslogueada al pitch) es de T-034, la preview web pública. Acá solo se
      -- deja dicho para que la frase no prometa algo que no ocurre.
      or exists (select 1 from public.jobs j
                 where j.video_id = videos.id
                   and j.status = 'active'::public.job_status
                   and j.deleted_at is null
                   and public.company_can_publish(j.company_id))
    )
  );

comment on function public.company_can_publish(uuid) is
  'Autorización de publicación. Conectada a jobs_company_write/update, '
  'jobs_public_select y videos_company_select en 0031 (T-028).';
