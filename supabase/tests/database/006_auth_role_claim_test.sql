-- Contrato de autenticación del Bloque B: lo que la app cliente da por cierto.
--
-- La navegación por rol lee `app_metadata.role`; RLS lee `profiles.role`. Estos
-- tests fijan que los dos digan siempre lo mismo y que los usuarios del seed
-- sirvan de verdad para iniciar sesión en local.
begin;
select plan(9);

-- --- El claim confiable existe y coincide con el rol de negocio -------------

select is(
  (select count(*)::int
   from auth.users u
   join public.profiles p on p.id = u.id
   where coalesce(u.raw_app_meta_data ->> 'role', '') is distinct from p.role::text),
  0,
  'POSITIVO: todo usuario tiene el claim de rol alineado con profiles.role');

select is(
  (select count(*)::int
   from auth.users u
   where u.raw_app_meta_data ->> 'role' not in ('candidate', 'company', 'admin')),
  0,
  'POSITIVO: no existe ningún claim de rol fuera del enum user_role');

-- El alta que pidió admin en metadata no confiable quedó como candidate en
-- profiles (0004) y su claim acompaña: la app tampoco la vería como admin.
select is(
  (select u.raw_app_meta_data ->> 'role'
   from auth.users u
   where u.id = tests.get_uuid('user_requested_admin')),
  'candidate',
  'NEGATIVO: pedir admin en el signup no produce un claim de admin');

-- --- Sincronización al cambiar el rol desde un contexto privilegiado --------

update public.profiles
set role = 'admin'
where id = tests.get_uuid('user_requested_admin');

select is(
  (select u.raw_app_meta_data ->> 'role'
   from auth.users u
   where u.id = tests.get_uuid('user_requested_admin')),
  'admin',
  'POSITIVO: promover a admin propaga el claim al JWT');

update public.profiles
set role = 'candidate'
where id = tests.get_uuid('user_requested_admin');

select is(
  (select u.raw_app_meta_data ->> 'role'
   from auth.users u
   where u.id = tests.get_uuid('user_requested_admin')),
  'candidate',
  'POSITIVO: degradar el rol también propaga el claim');

-- Un update que no toca el rol no altera el resto de app_metadata.
update public.profiles
set full_name = 'Nombre de prueba'
where id = tests.get_uuid('user_cand_pub');

select is(
  (select u.raw_app_meta_data ->> 'provider'
   from auth.users u
   where u.id = tests.get_uuid('user_cand_pub')),
  'email',
  'POSITIVO: sincronizar el claim no pisa el resto de app_metadata');

-- --- El cliente no puede fabricarse un rol ---------------------------------

select tests.authenticate_as('user_cand_pub');

select throws_ok(
  $$ update profiles set role = 'admin' where id = auth.uid() $$,
  '42501', null,
  'NEGATIVO: una sesión authenticated no puede promoverse a admin');

reset role;

-- --- Los usuarios del seed pueden iniciar sesión de verdad ------------------
-- GoTrue lee estas columnas como texto no nulo: con NULL, cualquier lookup del
-- usuario falla con 500 y el login local queda roto solo para el seed.

select is(
  (select count(*)::int
   from auth.users u
   where u.email like '%@dev.talentflash.test'
     and (u.confirmation_token is null
       or u.recovery_token is null
       or u.email_change_token_new is null
       or u.email_change is null)),
  0,
  'POSITIVO: los usuarios del seed no tienen tokens de correo en NULL');

select is(
  (select count(*)::int
   from auth.users u
   where u.email like '%@dev.talentflash.test'
     and not exists (
       select 1 from auth.identities i
       where i.user_id = u.id and i.provider = 'email')),
  0,
  'POSITIVO: cada usuario del seed tiene su identidad de correo');

select * from finish();
rollback;
