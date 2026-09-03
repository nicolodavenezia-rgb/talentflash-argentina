-- Lockdown de pagos y ausencia de datos privados para anon.
begin;
select plan(10);

select tests.authenticate_as('user_cand_pub');
select throws_ok(
  $$ insert into payments (payer_profile_id, provider_payment_id, amount)
     values (auth.uid(), 'hack-1', 1) $$,
  '42501', null, 'NEGATIVO: authenticated no inserta payments');

select throws_ok(
  $$ update payments set amount = 0 where payer_profile_id = auth.uid() $$,
  '42501', null, 'NEGATIVO: authenticated no actualiza payments');

-- El pago fixture ('fixture-payment', 000_setup) pertenece a user_cand_pub:
-- el pagador tiene que verlo exactamente una vez, y otro usuario cero veces.
-- Un `count(*) >= 0` pasaría siempre, incluso sin fila.
select results_eq(
  $$ select count(*)::int from payments where provider_payment_id = 'fixture-payment' $$,
  $$ values (1) $$,
  'POSITIVO: el pagador ve exactamente su pago fixture');

select tests.authenticate_as('user_cand_priv');
select results_eq(
  $$ select count(*)::int from payments where provider_payment_id = 'fixture-payment' $$,
  $$ values (0) $$,
  'NEGATIVO: otro usuario no ve el pago ajeno');

reset role;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', 'anon', true);
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;

select throws_ok(
  $$ select count(*) from profiles $$,
  '42501', null,
  'NEGATIVO: anon no lee profiles');

select throws_ok(
  $$ select count(*) from candidate_profiles $$,
  '42501', null,
  'NEGATIVO: anon no lee candidate_profiles');

select throws_ok(
  $$ select count(*) from job_applications $$,
  '42501', null,
  'NEGATIVO: anon no lee postulaciones');

select throws_ok(
  $$ select count(*) from messages $$,
  '42501', null,
  'NEGATIVO: anon no lee mensajes');

select throws_ok(
  $$ select count(*) from payments $$,
  '42501', null,
  'NEGATIVO: anon no lee pagos');

select results_eq(
  $$ select count(*)::int > 0 from geo_provincias $$,
  $$ values (true) $$,
  'POSITIVO: anon puede leer el catálogo geográfico público');

select * from finish();
rollback;
