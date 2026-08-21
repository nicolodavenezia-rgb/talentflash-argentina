-- Los participantes leen el chat, pero solo el destinatario marca read_at.
begin;
select plan(6);

select tests.authenticate_as('user_empresa_ok');

select results_eq(
  $$ select count(*)::int from messages
     where id = tests.get_uuid('message_from_candidate') $$,
  $$ values (1) $$,
  'POSITIVO: la empresa participante ve el mensaje');

select lives_ok(
  $$ update messages set read_at = now()
     where id = tests.get_uuid('message_from_candidate') $$,
  'POSITIVO: el destinatario marca el mensaje como leído');

select throws_ok(
  $$ update messages set body = 'contenido alterado', read_at = now()
     where id = tests.get_uuid('message_from_candidate') $$,
  '42501', null,
  'NEGATIVO: el destinatario no altera el cuerpo del mensaje');

select tests.authenticate_as('user_cand_pub');
select throws_ok(
  $$ update messages set read_at = now()
     where id = tests.get_uuid('message_from_candidate') $$,
  '42501', null,
  'NEGATIVO: el remitente no marca su propio mensaje como leído');

select lives_ok(
  $$ update notifications set read_at = now()
     where id = tests.get_uuid('notification_cand') $$,
  'POSITIVO: el dueño marca su notificación como leída');

select throws_ok(
  $$ update notifications set body = 'alterado', read_at = now()
     where id = tests.get_uuid('notification_cand') $$,
  '42501', null,
  'NEGATIVO: el dueño no altera el payload de la notificación');

select * from finish();
rollback;
