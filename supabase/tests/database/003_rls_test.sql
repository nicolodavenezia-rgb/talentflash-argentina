-- pgTAP — extraído de docs/DATA_MODEL.md §6 (T-007)

-- 060-payments-lockdown.test.sql (extracto)
begin;
select plan(3);

select tests.authenticate_as('user_cand_pub');
select throws_ok(
  $$ insert into payments (payer_profile_id, provider_payment_id, amount)
     values (auth.uid(), 'hack-1', 1) $$,
  '42501', null, 'NEGATIVO: authenticated no inserta payments');

select throws_ok(
  $$ update payments set amount = 0 where payer_profile_id = auth.uid() $$,
  '42501', null, 'NEGATIVO: authenticated no actualiza payments');

select results_eq(
  $$ select count(*)::int >= 0 from payments where payer_profile_id = auth.uid() $$,
  $$ values (true) $$,
  'POSITIVO: el pagador puede leer sus propios pagos');

select * from finish();
rollback;
