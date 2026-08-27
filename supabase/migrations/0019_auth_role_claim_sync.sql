-- Bloque B (T-015): el claim de rol y `profiles.role` no pueden divergir.
--
-- La app cliente decide qué pantalla mostrar leyendo `app_metadata.role` del
-- JWT (SECURITY.md §3: `user_metadata` es input del cliente y no sirve para
-- autorizar). Postgres, en cambio, decide qué filas se pueden leer o escribir
-- mirando `profiles.role`. Al registrarse, `handle_new_user` (0004) escribe los
-- dos a la vez, pero después quedan desacoplados:
--
--   * provisionar un `admin` desde un contexto con service_role — la única vía
--     admitida (SECURITY.md §3) — se hace con un UPDATE sobre `profiles.role`;
--   * moderación puede cambiar el rol de una cuenta desde el panel admin
--     (Bloque P).
--
-- En ambos casos el JWT seguiría diciendo `candidate`: RLS daría acceso de
-- administración mientras la UI muestra el shell de candidato, o al revés. El
-- trigger de abajo cierra esa brecha propagando el rol al claim confiable en la
-- misma transacción que lo cambia.
--
-- No toca el camino del signup: solo se dispara cuando `profiles.role` cambia,
-- y ese cambio ya está bloqueado para `authenticated` no-admin por
-- `private.protect_profile_update` (0018).

create or replace function private.sync_profile_role_claim() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update auth.users
  set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
      || jsonb_build_object('role', new.role::text)
  where id = new.id;
  return null;
end;
$$;

revoke all on function private.sync_profile_role_claim() from public, anon, authenticated;

create trigger sync_profile_role_claim
after update of role on public.profiles
for each row
when (new.role is distinct from old.role)
execute function private.sync_profile_role_claim();

-- Reparación de datos existentes: cualquier fila cuyo claim no coincida con su
-- rol se realinea. Es idempotente y no toca a quien ya está bien.
update auth.users u
set raw_app_meta_data = coalesce(u.raw_app_meta_data, '{}'::jsonb)
    || jsonb_build_object('role', p.role::text)
from public.profiles p
where p.id = u.id
  and coalesce(u.raw_app_meta_data ->> 'role', '') is distinct from p.role::text;
