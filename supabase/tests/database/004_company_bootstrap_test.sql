-- Creación atómica de empresa + primer owner.
begin;
select plan(4);

select tests.authenticate_as('user_company_new');

select throws_ok(
  $$ insert into company_profiles (name, cuit, created_by)
     values ('Inserción directa', '30-70000009-9', auth.uid()) $$,
  '42501', null,
  'NEGATIVO: authenticated no inserta company_profiles directamente');

select lives_ok(
  $$ select create_company_with_owner('Empresa RPC', '30-70000008-8', 'Empresa RPC S.A.S.') $$,
  'POSITIVO: el RPC crea empresa y owner en una transacción');

select results_eq(
  $$ select count(*)::int
     from company_profiles cp
     join company_members cm on cm.company_id = cp.id
     where cp.created_by = auth.uid()
       and cm.profile_id = auth.uid()
       and cm.member_role = 'owner' $$,
  $$ values (1) $$,
  'POSITIVO: la empresa nueva tiene exactamente un owner inicial');

select throws_ok(
  $$ update company_profiles
     set verification_status = 'approved'
     where created_by = auth.uid() $$,
  '42501', null,
  'NEGATIVO: el owner no puede autoaprobar la empresa');

select * from finish();
rollback;
