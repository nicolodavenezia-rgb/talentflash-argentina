-- Bloque E — T-027: dígito verificador del CUIT en el servidor.
--
-- Dos capas y las dos se prueban acá: el algoritmo (`private.cuit_*`) y el
-- TRIGGER que lo impone sobre las tablas. El trigger es lo que hace que la
-- validación no se pueda saltear: estos casos escriben con el rol del runner
-- (dueño de las tablas, sin RLS de por medio), que es el escenario más
-- permisivo posible, y aun así el CUIT inválido no entra.
--
-- Todos los CUIT de este archivo son sintéticos, con el dígito verificador
-- calculado; ninguno corresponde a una empresa real.
begin;
select plan(17);

-- --- El algoritmo -----------------------------------------------------------

-- Antes que nada: el seed tiene que haber entrado ya normalizado y válido. Si
-- este fixture fallara, todos los negativos de abajo probarían sobre una base
-- vacía y pasarían de casualidad.
select results_eq(
  $$ select count(*)::int,
            count(*) filter (where private.cuit_is_valid(cuit))::int,
            count(*) filter (where cuit ~ '^[0-9]{2}-[0-9]{8}-[0-9]$')::int
     from public.company_profiles $$,
  $$ values (6, 6, 6) $$,
  'FIXTURE: las 6 empresas del seed tienen CUIT válido y en forma canónica');

select results_eq(
  $$ select count(*)::int
     from (values ('30-71234567-1'), ('20-12345678-6'), ('33-99999999-4'),
                  ('30-70000001-6'), ('30-70000005-9')) v(cuit)
     where private.cuit_is_valid(v.cuit) $$,
  $$ values (5) $$,
  'POSITIVO: los CUIT sintéticos con verificador correcto se aceptan');

-- Control negativo apareado: para cada CUIT válido se prueban los otros nueve
-- verificadores posibles. El total (27) va en la aserción para que "0 válidos"
-- no pueda pasar por no haber generado ningún caso.
select results_eq(
  $$ select count(*)::int,
            count(*) filter (where private.cuit_is_valid(
              substr(v.cuit, 1, 12) || d::text))::int
     from (values ('30-71234567-1'), ('20-12345678-6'), ('33-99999999-4')) v(cuit)
     cross join generate_series(0, 9) d
     where d <> substr(v.cuit, 13, 1)::int $$,
  $$ values (27, 0) $$,
  'NEGATIVO: ninguno de los 27 verificadores alterados pasa');

-- 11 - (suma % 11) da 11 cuando la suma es múltiplo de 11: el verificador es 0.
select results_eq(
  $$ select private.cuit_check_digit('2712345678'),
            private.cuit_is_valid('27-12345678-0') $$,
  $$ values (0, true) $$,
  'POSITIVO: caso especial del algoritmo, 11 se informa como 0');

-- 11 - (suma % 11) da 10 cuando la suma es ≡ 1 (mod 11): el verificador es 9.
select results_eq(
  $$ select private.cuit_check_digit('2000000001'),
            private.cuit_is_valid('20-00000001-9') $$,
  $$ values (9, true) $$,
  'POSITIVO: caso especial del algoritmo, 10 se informa como 9');

select results_eq(
  $$ select private.cuit_is_valid('20-00000001-0') $$,
  $$ values (false) $$,
  'NEGATIVO: confundir el 10 con 0 en el caso especial se rechaza');

select results_eq(
  $$ select private.cuit_format('30712345671'),
            private.cuit_format('30-71234567-1'),
            private.cuit_format('30 71234567 1'),
            private.cuit_format('  30-71234567-1  ') $$,
  $$ values ('30-71234567-1'::text, '30-71234567-1'::text,
             '30-71234567-1'::text, '30-71234567-1'::text) $$,
  'POSITIVO: las cuatro escrituras dan la misma forma canónica');

-- Once dígitos y verificador correcto, pero el separador corrido: se rechaza
-- porque un guion fuera de lugar casi siempre es un dígito mal tipeado.
select results_eq(
  $$ select count(*)::int
     from (values ('30-7123456-71'), ('3-071234567-1'), ('307-1234567-1')) v(cuit)
     where private.cuit_is_valid(v.cuit) $$,
  $$ values (0) $$,
  'NEGATIVO: el separador fuera de posición no se acepta');

-- Fail-closed: ninguna de estas entradas devuelve null ni revienta, todas
-- devuelven false.
select results_eq(
  $$ select count(*)::int,
            count(*) filter (where private.cuit_is_valid(v.cuit) is null)::int,
            count(*) filter (where private.cuit_is_valid(v.cuit))::int
     from (values ('30-7123456A-1'), ('30.71234567.1'), ('123'),
                  ('3071234567'), ('307123456712'), (''), (null),
                  ('30-71234567-8')) v(cuit) $$,
  $$ values (8, 0, 0) $$,
  'NEGATIVO: letras, largo distinto, vacío, null y verificador malo dan false');

-- --- El trigger sobre company_profiles --------------------------------------

-- Fixture explícito antes del negativo: la empresa existe y su CUIT de partida
-- es exactamente el que después se comprueba que no cambió.
select results_eq(
  $$ select cuit from public.company_profiles
     where id = tests.get_uuid('company_ok') $$,
  $$ values ('30-70000001-6'::text) $$,
  'FIXTURE: company_ok existe y arranca con su CUIT del seed');

-- El rol del runner es dueño de la tabla: no hay RLS que lo frene. Aun así el
-- trigger rechaza el CUIT.
select throws_ok(
  $$ update public.company_profiles set cuit = '30-71234567-8'
     where id = tests.get_uuid('company_ok') $$,
  'TFCUI', null,
  'NEGATIVO: ni el dueño de la tabla puede guardar un verificador inválido');

select results_eq(
  $$ select cuit from public.company_profiles
     where id = tests.get_uuid('company_ok') $$,
  $$ values ('30-70000001-6'::text) $$,
  'NEGATIVO: tras el rechazo el CUIT quedó intacto (el UPDATE no ocurrió)');

select results_eq(
  $$ with escrito as (
       update public.company_profiles set cuit = '30712345671'
       where id = tests.get_uuid('company_ok')
       returning cuit
     ) select cuit from escrito $$,
  $$ values ('30-71234567-1'::text) $$,
  'POSITIVO: un CUIT válido sin separadores se guarda ya normalizado');

-- --- El trigger sobre company_verifications ---------------------------------

select throws_ok(
  $$ insert into public.company_verifications
       (company_id, cuit_submitted, submitted_by)
     values (tests.get_uuid('company_ok'), '20-12345678-9',
             tests.get_uuid('user_empresa_ok')) $$,
  'TFCUI', null,
  'NEGATIVO: una solicitud de verificación con CUIT inválido se rechaza');

select results_eq(
  $$ select count(*)::int from public.company_verifications
     where company_id = tests.get_uuid('company_ok') $$,
  $$ values (0) $$,
  'NEGATIVO: tras el rechazo no quedó ninguna solicitud (el INSERT no ocurrió)');

select results_eq(
  $$ with creada as (
       insert into public.company_verifications
         (company_id, cuit_submitted, submitted_by)
       values (tests.get_uuid('company_ok'), '20 12345678 6',
               tests.get_uuid('user_empresa_ok'))
       returning cuit_submitted
     ) select cuit_submitted from creada $$,
  $$ values ('20-12345678-6'::text) $$,
  'POSITIVO: una solicitud con CUIT válido se guarda normalizada');

-- --- El algoritmo no se expone por la API -----------------------------------

-- Limpieza completa de rol y claims: un anon real no trae ningún sub.
do $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', 'anon', true);
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
end $$;
set local role anon;

select throws_ok(
  $$ select private.cuit_is_valid('30-71234567-1') $$,
  '42501', null,
  'NEGATIVO: anon no alcanza el esquema private (el algoritmo no es superficie de API)');

reset role;
select * from finish();
rollback;
