-- Bloque D (auditoría): endurecimiento de helpers RLS preexistentes.
-- are_blocked ya no es un oráculo de terceros, has_active_subscription no
-- filtra suscripciones ajenas y el corte por bloqueo de conversaciones
-- funciona también para el lado empresa.
begin;
select plan(11);

-- --- are_blocked: solo responde a una parte involucrada -----------------------
-- El seed incluye un bloqueo real: candidato15 → owner de empresa1.
select tests.authenticate_as('user_empresa_otra');
select results_eq(
  $$ select public.are_blocked(tests.get_uuid('user_cand_blocker'),
                               tests.get_uuid('user_empresa_ok')) $$,
  $$ values (false) $$,
  'NEGATIVO: un tercero no puede sondear el bloqueo entre otras dos personas');

select tests.authenticate_as('user_empresa_ok');
select results_eq(
  $$ select public.are_blocked(tests.get_uuid('user_cand_blocker'), auth.uid()) $$,
  $$ values (true) $$,
  'POSITIVO: la parte involucrada sí obtiene la respuesta real');

-- Limpieza de los claims del authenticate_as previo: un anon real no trae
-- ningún sub (si quedaran, auth.uid() seguiría devolviendo al usuario).
do $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', 'anon', true);
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
end $$;
set local role anon;
select results_eq(
  $$ select public.are_blocked(tests.get_uuid('user_cand_blocker'),
                               tests.get_uuid('user_empresa_ok')) $$,
  $$ values (false) $$,
  'NEGATIVO: anon no obtiene nada del oráculo de bloqueos');

-- --- has_active_subscription: solo la propia empresa (o admin) ----------------
reset role;
insert into plans (id, code, audience, name)
values ('f0000000-0000-4000-8000-000000000001', 'test_plan_pgtap', 'company',
        'Plan de prueba pgTAP');
insert into plan_prices (id, plan_id, amount)
values ('f0000000-0000-4000-8000-000000000002',
        'f0000000-0000-4000-8000-000000000001', 1000);
insert into subscriptions (company_id, plan_id, plan_price_id, status,
                           current_period_start, current_period_end)
values (tests.get_uuid('company_ok'),
        'f0000000-0000-4000-8000-000000000001',
        'f0000000-0000-4000-8000-000000000002',
        'active', now(), now() + interval '30 days');

select tests.authenticate_as('user_empresa_ok');
select results_eq(
  $$ select public.has_active_subscription(tests.get_uuid('company_ok')) $$,
  $$ values (true) $$,
  'POSITIVO: un miembro consulta la suscripción de SU empresa');

select tests.authenticate_as('user_empresa_otra');
select results_eq(
  $$ select public.has_active_subscription(tests.get_uuid('company_ok')) $$,
  $$ values (false) $$,
  'NEGATIVO: la suscripción de una empresa ajena no se filtra');

-- --- El bloqueo corta conversaciones y mensajes también para la empresa -------
select tests.authenticate_as('user_empresa_ok');
select results_eq(
  $$ select count(*)::int from conversations
     where id = tests.get_uuid('conversation_A') $$,
  $$ values (1) $$,
  'POSITIVO: sin bloqueo, la empresa ve su conversación');

select results_eq(
  $$ select count(*)::int from messages
     where conversation_id = tests.get_uuid('conversation_A') $$,
  $$ values (1) $$,
  'POSITIVO: sin bloqueo, la empresa lee los mensajes');

reset role;
-- candidato1 bloquea al owner de empresa1 (la conversación fixture es de ellos).
insert into blocks (blocker_profile_id, blocked_profile_id)
values (tests.get_uuid('user_cand_pub'), tests.get_uuid('user_empresa_ok'));

select tests.authenticate_as('user_empresa_ok');
select results_eq(
  $$ select count(*)::int from conversations
     where id = tests.get_uuid('conversation_A') $$,
  $$ values (0) $$,
  'NEGATIVO: bloqueada, la conversación desaparece para la empresa');

select results_eq(
  $$ select count(*)::int from messages
     where conversation_id = tests.get_uuid('conversation_A') $$,
  $$ values (0) $$,
  'NEGATIVO: bloqueada, los mensajes históricos tampoco se leen');

select throws_ok(
  $$ insert into messages (conversation_id, sender_profile_id, body)
     values (tests.get_uuid('conversation_A'), auth.uid(), 'hola igual') $$,
  '42501', null,
  'NEGATIVO: bloqueada, la empresa tampoco puede seguir escribiendo');

-- El candidato que bloqueó conserva su acceso (el corte es para la empresa;
-- despublicar/romper el historial del bloqueante sería castigarlo a él).
select tests.authenticate_as('user_cand_pub');
select results_eq(
  $$ select count(*)::int from conversations
     where id = tests.get_uuid('conversation_A') $$,
  $$ values (1) $$,
  'POSITIVO: quien bloqueó sigue viendo su propio historial');

select * from finish();
rollback;
