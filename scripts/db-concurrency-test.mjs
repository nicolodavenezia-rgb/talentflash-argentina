// Carreras reales de las tres puertas que crean una membresía de empresa
// (migración 0031), con DOS SESIONES DE VERDAD.
//
// POR QUÉ NO ESTÁ EN pgTAP: cada archivo de `supabase/tests/database` corre
// entero dentro de un `begin; … rollback;`, o sea UNA transacción. Una carrera
// entre dos transacciones no se puede simular ahí: dos llamadas seguidas en la
// misma transacción comparten snapshot y locks, así que "pasan" aunque no haya
// ningún lock puesto. Este script abre procesos `psql` separados —conexiones
// distintas, backends distintos— y los cruza de verdad.
//
// Qué prueba, y cómo evita ser un test de temporizador:
//   1. Mientras la sesión A tiene el lock, se consulta `pg_stat_activity` desde
//      una TERCERA sesión y se exige que la sesión B esté esperando un Lock.
//      Eso es evidencia directa de serialización, no una inferencia del reloj.
//   2. Además se mide el tiempo de B: sin lock volvería enseguida.
//   3. Y sobre todo se mira el ESTADO FINAL: una sola membresía, la invitación
//      perdedora sin marcar, ninguna empresa duplicada.
//
// Fixtures propios en el namespace 94000000 con emails @tests.local. Se limpian
// al empezar y al terminar: el script es re-ejecutable.
//
// Correr: npm run db:concurrency   (requiere el stack local levantado)

import { spawn, spawnSync } from 'node:child_process';
import process from 'node:process';

const CONTAINER =
  process.env.SUPABASE_DB_CONTAINER ?? 'supabase_db_talentflash_argentina';

// --- Contadores TAP ---------------------------------------------------------
let testNumber = 0;
let failures = 0;

function ok(condition, description) {
  testNumber += 1;
  if (condition) {
    console.log(`ok ${testNumber} - ${description}`);
  } else {
    failures += 1;
    console.log(`not ok ${testNumber} - ${description}`);
  }
  return Boolean(condition);
}

// --- psql -------------------------------------------------------------------

/** Corre SQL y devuelve stdout. Lanza si psql sale distinto de 0. */
function psql(sql, { appName = 'conc_setup' } = {}) {
  const result = spawnSync(
    'docker',
    [
      'exec', '-e', `PGAPPNAME=${appName}`, '-i', CONTAINER,
      'psql', '-X', '-U', 'postgres', '-d', 'postgres',
      '-v', 'ON_ERROR_STOP=1', '-At',
    ],
    { input: sql, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 },
  );
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`psql salió ${result.status}: ${result.stderr}`);
  }
  return (result.stdout ?? '').trim();
}

/**
 * Lanza SQL en una sesión propia SIN esperarla. Devuelve una promesa con
 * { status, stdout, stderr, ms } y el `appName` con el que se la puede
 * identificar en pg_stat_activity.
 */
function psqlAsync(sql, appName) {
  const started = Date.now();
  const child = spawn(
    'docker',
    [
      'exec', '-e', `PGAPPNAME=${appName}`, '-i', CONTAINER,
      'psql', '-X', '-U', 'postgres', '-d', 'postgres', '-At',
    ],
    { stdio: ['pipe', 'pipe', 'pipe'] },
  );
  let stdout = '';
  let stderr = '';
  child.stdout.on('data', (d) => { stdout += d; });
  child.stderr.on('data', (d) => { stderr += d; });
  child.stdin.write(sql);
  child.stdin.end();
  return new Promise((resolve) => {
    child.on('close', (status) => {
      resolve({ status, stdout, stderr, ms: Date.now() - started });
    });
  });
}

const esperar = (ms) => new Promise((r) => setTimeout(r, ms));

/** Claims de sesión: lo mismo que hace `tests.authenticate_as`. */
const autenticar = (uid) => `
  select set_config('request.jwt.claim.sub', '${uid}', true);
  select set_config('request.jwt.claim.role', 'authenticated', true);
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', '${uid}'::uuid, 'role', 'authenticated')::text, true);
  set local role authenticated;
`;

// --- Identidades del fixture ------------------------------------------------
const U = {
  target: '94000000-0000-4000-8000-000000000001', // la cuenta que se disputan
  ownerA: '94000000-0000-4000-8000-000000000002',
  ownerB: '94000000-0000-4000-8000-000000000003',
  onboarding: '94000000-0000-4000-8000-000000000004', // carrera de onboarding
  bootstrap: '94000000-0000-4000-8000-000000000005', // carrera de bootstrap
};
const C = {
  a: '94000000-0000-4000-8000-00000000000a',
  b: '94000000-0000-4000-8000-00000000000b',
};
// 32 hex, que es la forma que valida `private.invitation_code_hash`.
const CODE_A = 'AAAAAAAABBBBBBBBCCCCCCCCDDDDDDD1';
const CODE_B = 'AAAAAAAABBBBBBBBCCCCCCCCDDDDDDD2';

const EMAILS = [
  'conc-target@tests.local',
  'conc-owner-a@tests.local',
  'conc-owner-b@tests.local',
  'conc-onboarding@tests.local',
  'conc-bootstrap@tests.local',
];

// CUIT con dígito verificador válido y NO usados por el seed.
//
// UNO POR SESIÓN, no uno por carrera. Con el mismo CUIT en las dos sesiones,
// lo que las serializaba era el índice único de `company_profiles.cuit` y no
// `private.lock_membership_slot`: la carrera quedaba verde aunque se sacara el
// lock. Con CUIT distintos, el único mecanismo que puede serializarlas es el
// lock de la cuenta.
const CUIT_ONBOARDING_A = '30-70000008-3';
const CUIT_ONBOARDING_B = '30-75000200-1';
const CUIT_BOOTSTRAP_A = '30-71234569-8';
const CUIT_BOOTSTRAP_B = '30-75000201-9';

function limpiar() {
  // El trigger `protect_company_member_write` impide dar de baja al último
  // owner de una empresa — a propósito: una empresa sin owner queda muerta.
  // Para desarmar un fixture hay que apagarlo. Va todo en UNA transacción, así
  // que si algo falla el ALTER también vuelve atrás y el trigger nunca queda
  // desactivado en la base.
  psql(`
    begin;
    alter table public.company_members disable trigger protect_company_member_write;
    delete from public.company_members
     where profile_id in (${Object.values(U).map((u) => `'${u}'`).join(',')})
        or company_id in ('${C.a}','${C.b}');
    delete from public.company_invitations
     where company_id in ('${C.a}','${C.b}');
    delete from public.company_profiles
     where id in ('${C.a}','${C.b}')
        or created_by in (${Object.values(U).map((u) => `'${u}'`).join(',')});
    delete from public.consents
     where profile_id in (${Object.values(U).map((u) => `'${u}'`).join(',')});
    delete from auth.users where email in (${EMAILS.map((e) => `'${e}'`).join(',')});
    alter table public.company_members enable trigger protect_company_member_write;
    commit;
  `);
}

function sembrar() {
  const usuario = (id, email) => `
    ('00000000-0000-0000-0000-000000000000', '${id}', 'authenticated', 'authenticated',
     '${email}', crypt('password123', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}', '{"role":"company"}',
     '', '', '', '', now(), now())`;

  psql(`
    insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                            email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                            confirmation_token, recovery_token,
                            email_change_token_new, email_change, created_at, updated_at)
    values ${[
      usuario(U.target, EMAILS[0]),
      usuario(U.ownerA, EMAILS[1]),
      usuario(U.ownerB, EMAILS[2]),
      usuario(U.onboarding, EMAILS[3]),
      usuario(U.bootstrap, EMAILS[4]),
    ].join(',')};

    -- Dos empresas, cada una con su owner.
    insert into public.company_profiles (id, name, legal_name, cuit, created_by) values
      ('${C.a}', 'Concurrencia A', 'Concurrencia A SA', '30-71234567-1', '${U.ownerA}'),
      ('${C.b}', 'Concurrencia B', 'Concurrencia B SA', '30-71234568-9', '${U.ownerB}');
    insert into public.company_members (company_id, profile_id, member_role) values
      ('${C.a}', '${U.ownerA}', 'owner'),
      ('${C.b}', '${U.ownerB}', 'owner');

    -- Una invitación viva de CADA empresa para la MISMA persona. Es el estado
    -- que el lock de la invitación (0027) no cubría: son filas distintas.
    insert into public.company_invitations
      (company_id, email, member_role, token_hash, invited_by, expires_at) values
      ('${C.a}', '${EMAILS[0]}', 'recruiter',
       private.invitation_code_hash('${CODE_A}'), '${U.ownerA}', now() + interval '7 days'),
      ('${C.b}', '${EMAILS[0]}', 'viewer',
       private.invitation_code_hash('${CODE_B}'), '${U.ownerB}', now() + interval '7 days');

    -- Consentimientos obligatorios para las cuentas que corren el onboarding.
    insert into public.consents (profile_id, consent_type, granted, version, user_agent)
    select u.id, cv.consent_type, true, cv.version, 'concurrency'
    from (values ('${U.onboarding}'::uuid), ('${U.bootstrap}'::uuid)) u(id)
    cross join public.consent_versions cv
    where cv.is_mandatory;
  `);
}

/** ¿Hay algún backend con este application_name esperando un Lock? */
function esperandoLock(appName) {
  const out = psql(`
    select count(*)::int
    from pg_stat_activity
    where application_name = '${appName}'
      and wait_event_type = 'Lock';
  `, { appName: 'conc_watch' });
  return Number.parseInt(out, 10) > 0;
}

async function carreraInvitaciones() {
  console.log('# Carrera 1: dos códigos distintos, misma cuenta, empresas distintas');

  // A toma el lock de la cuenta y lo retiene 4 segundos antes de confirmar.
  const a = psqlAsync(
    `begin;
     ${autenticar(U.target)}
     select public.accept_company_invitation('${CODE_A}');
     select pg_sleep(4);
     commit;`,
    'conc_a',
  );

  await esperar(1000);

  const b = psqlAsync(
    `begin;
     ${autenticar(U.target)}
     select public.accept_company_invitation('${CODE_B}');
     commit;`,
    'conc_b',
  );

  // Mientras A sigue adentro: B tiene que estar DETENIDA en un lock.
  await esperar(1500);
  const bBloqueada = esperandoLock('conc_b');
  ok(
    bBloqueada,
    'la segunda sesión queda esperando un Lock mientras la primera no confirma',
  );

  const [ra, rb] = await Promise.all([a, b]);

  ok(
    ra.status === 0 && !/^ERROR:/m.test(ra.stderr),
    `la sesión ganadora confirma sin error${ra.stderr ? `: ${ra.stderr.trim()}` : ''}`,
  );
  ok(
    rb.ms > 1500,
    `la sesión perdedora esperó de verdad (${rb.ms} ms, sin lock volvería enseguida)`,
  );

  const filas = psql(`
    select
      (select count(*)::int from public.company_members where profile_id = '${U.target}'),
      (select count(*)::int from public.company_invitations
        where email = '${EMAILS[0]}' and accepted_at is not null),
      (select count(*)::int from public.company_invitations
        where email = '${EMAILS[0]}' and accepted_at is null and revoked_at is null);
  `).split('|').map((n) => Number.parseInt(n, 10));

  ok(filas[0] === 1, `la cuenta quedó en EXACTAMENTE una empresa (fueron ${filas[0]})`);
  ok(
    filas[1] === 1,
    `se marcó como aceptada UNA sola invitación (fueron ${filas[1]})`,
  );
  ok(
    filas[2] === 1,
    'la invitación perdedora sigue pendiente y canjeable, no marcada como aceptada',
  );

  // Y la cuenta queda operativa: `private.caller_company()` resuelve.
  // Dentro de una transacción: `set_config(..., true)` y `set local role` son
  // locales a la transacción, y fuera de una no hacen nada.
  // La salida trae los tags de psql (BEGIN, SET, ROLLBACK) mezclados con los
  // valores, así que el resultado se marca y se busca por su marca.
  const salida = psql(`
    begin;
    ${autenticar(U.target)}
    select 'EQUIPO=' || count(*)::text from public.list_company_members();
    rollback;
  `);
  const marca = /EQUIPO=(\d+)/.exec(salida);
  ok(
    marca !== null && Number.parseInt(marca[1], 10) >= 1,
    'después de la carrera, caller_company vuelve a resolver una sola empresa '
      + `(equipo de ${marca ? marca[1] : 'sin resultado'})`,
  );
}

async function carreraOnboarding() {
  console.log('# Carrera 2: dos ejecuciones simultáneas del onboarding de empresa');

  const sector = psql(
    "select id from public.sectors where is_active order by id limit 1;",
  );
  const loc = psql(
    'select id::text || \'|\' || provincia_id::text from public.geo_localidades order by id limit 1;',
  ).split('|');

  const llamada = (nombre, cuit) => `
    select public.complete_company_onboarding(
      '${nombre} SRL', '${nombre}', '${cuit}',
      '${sector}'::uuid, '1-10',
      '${loc[1]}'::uuid, '${loc[0]}'::uuid,
      null, 'Quien Solicita', 'Gerente', 'manager');`;

  const a = psqlAsync(
    `begin; ${autenticar(U.onboarding)} ${llamada('Onboarding Uno', CUIT_ONBOARDING_A)} select pg_sleep(4); commit;`,
    'conc_onb_a',
  );
  await esperar(1000);
  const b = psqlAsync(
    `begin; ${autenticar(U.onboarding)} ${llamada('Onboarding Dos', CUIT_ONBOARDING_B)} commit;`,
    'conc_onb_b',
  );

  await esperar(1500);
  ok(
    esperandoLock('conc_onb_b'),
    'el segundo onboarding queda esperando el lock de la cuenta',
  );

  const [ra, rb] = await Promise.all([a, b]);
  ok(
    !/^ERROR:/m.test(ra.stderr),
    `el primer onboarding corre sin ningún error${ra.stderr ? `: ${ra.stderr.trim()}` : ''}`,
  );
  ok(
    !/^ERROR:/m.test(rb.stderr),
    `el segundo onboarding termina de forma idempotente, sin error${rb.stderr ? `: ${rb.stderr.trim()}` : ''}`,
  );

  const empresas = Number.parseInt(psql(`
    select count(*)::int from public.company_members where profile_id = '${U.onboarding}';
  `), 10);
  ok(empresas === 1, `el onboarding concurrente creó UNA sola empresa (fueron ${empresas})`);

  const huerfanas = Number.parseInt(psql(`
    select count(*)::int from public.company_profiles
    where created_by = '${U.onboarding}';
  `), 10);
  ok(
    huerfanas === 1,
    `no quedó ninguna company_profiles huérfana (hay ${huerfanas}, esperaba 1)`,
  );
}

async function carreraBootstrap() {
  console.log('# Carrera 3: dos create_company_with_owner simultáneos');

  const llamada = (nombre, cuit) =>
    `select public.create_company_with_owner('${nombre}', '${cuit}');`;

  const a = psqlAsync(
    `begin; ${autenticar(U.bootstrap)} ${llamada('Bootstrap Uno', CUIT_BOOTSTRAP_A)} select pg_sleep(4); commit;`,
    'conc_boot_a',
  );
  await esperar(1000);
  const b = psqlAsync(
    `begin; ${autenticar(U.bootstrap)} ${llamada('Bootstrap Dos', CUIT_BOOTSTRAP_B)} commit;`,
    'conc_boot_b',
  );

  await esperar(1500);
  ok(
    esperandoLock('conc_boot_b'),
    'el segundo bootstrap queda esperando el lock de la cuenta',
  );

  const [ra, rb] = await Promise.all([a, b]);
  // `status` no alcanza: sin ON_ERROR_STOP psql sigue y sale 0 aunque un
  // statement haya fallado. Lo que decide es que no haya ningún ERROR.
  ok(
    !/^ERROR:/m.test(ra.stderr),
    `el primer bootstrap corre sin ningún error${ra.stderr ? `: ${ra.stderr.trim()}` : ''}`,
  );
  ok(
    rb.status === 0 && !/^ERROR:/m.test(rb.stderr),
    `el segundo bootstrap termina de forma idempotente, sin error${rb.stderr ? `: ${rb.stderr.trim()}` : ''}`,
  );

  const filas = psql(`
    select
      (select count(*)::int from public.company_members where profile_id = '${U.bootstrap}'),
      (select count(*)::int from public.company_profiles where created_by = '${U.bootstrap}');
  `).split('|').map((n) => Number.parseInt(n, 10));

  ok(filas[0] === 1, `quedó UNA sola membresía (fueron ${filas[0]})`);
  ok(filas[1] === 1, `y UNA sola empresa, sin huérfanas (fueron ${filas[1]})`);
}

/**
 * Carrera 4: dos canjes CRUZADOS. Salió de la auditoría adversarial.
 *
 * El `insert into company_members` lleva `invited_by`, y esa FK hace que
 * Postgres tome un `for key share` sobre la fila de `profiles` del INVITADOR,
 * al final de la transacción. Si X invitó a Y y Y invitó a X, y a los dos los
 * dieron de baja de sus empresas después de invitar, cada canje termina
 * esperando la fila que tiene el otro: deadlock 40P01.
 *
 * El fixture se arma con las RPC de la app (crear empresa, invitar, aceptar,
 * dar de baja), no a mano: el estado es alcanzable por un cliente.
 */
async function carreraCruzada() {
  console.log('# Carrera 4: dos canjes cruzados (deadlock por la FK invited_by)');

  const OA = '94000000-0000-4000-8000-00000000001a';
  const OB = '94000000-0000-4000-8000-00000000001b';
  const X = '94000000-0000-4000-8000-00000000001c';
  const Y = '94000000-0000-4000-8000-00000000001d';
  const CODE_X = '99999999888888887777777766666661'; // de la empresa B, invitó Y
  const CODE_Y = '99999999888888887777777766666662'; // de la empresa A, invitó X
  const CA = '94000000-0000-4000-8000-00000000002a';
  const CB = '94000000-0000-4000-8000-00000000002b';
  const mails = {
    [OA]: 'cruz-oa@tests.local',
    [OB]: 'cruz-ob@tests.local',
    [X]: 'cruz-x@tests.local',
    [Y]: 'cruz-y@tests.local',
  };

  const usuario = (id) => `
    ('00000000-0000-0000-0000-000000000000', '${id}', 'authenticated', 'authenticated',
     '${mails[id]}', crypt('password123', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}', '{"role":"company"}',
     '', '', '', '', now(), now())`;

  psql(`
    insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                            email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                            confirmation_token, recovery_token,
                            email_change_token_new, email_change, created_at, updated_at)
    values ${[OA, OB, X, Y].map(usuario).join(',')};

    insert into public.company_profiles (id, name, legal_name, cuit, created_by) values
      ('${CA}', 'Cruzada A', 'Cruzada A SA', '30-75000202-8', '${OA}'),
      ('${CB}', 'Cruzada B', 'Cruzada B SA', '30-75000203-6', '${OB}');
    insert into public.company_members (company_id, profile_id, member_role) values
      ('${CA}', '${OA}', 'owner'),
      ('${CB}', '${OB}', 'owner');

    -- X invitó a Y (a la empresa A) e Y invitó a X (a la empresa B): el
    -- \`invited_by\` cruzado es lo que cierra el ciclo de locks. Después los dos
    -- quedan SIN membresía, que es lo que los deja llegar al insert.
    insert into public.company_invitations
      (company_id, email, member_role, token_hash, invited_by, expires_at) values
      ('${CA}', '${mails[Y]}', 'recruiter',
       private.invitation_code_hash('${CODE_Y}'), '${X}', now() + interval '7 days'),
      ('${CB}', '${mails[X]}', 'recruiter',
       private.invitation_code_hash('${CODE_X}'), '${Y}', now() + interval '7 days');
  `);

  const a = psqlAsync(
    `begin; ${autenticar(X)} select public.accept_company_invitation('${CODE_X}'); commit;`,
    'cruz_a',
  );
  const b = psqlAsync(
    `begin; ${autenticar(Y)} select public.accept_company_invitation('${CODE_Y}'); commit;`,
    'cruz_b',
  );
  const [ra, rb] = await Promise.all([a, b]);

  const salida = `${ra.stderr}\n${rb.stderr}`;
  ok(
    !/deadlock detected/i.test(salida),
    `ningún canje cruzado termina en deadlock 40P01${/deadlock/i.test(salida) ? `: ${salida.trim().split('\n')[0]}` : ''}`,
  );

  const filas = psql(`
    select
      (select count(*)::int from public.company_members where profile_id = '${X}'),
      (select count(*)::int from public.company_members where profile_id = '${Y}');
  `).split('|').map((n) => Number.parseInt(n, 10));

  ok(filas[0] === 1, `X entró a UNA empresa (fueron ${filas[0]})`);
  ok(filas[1] === 1, `Y entró a UNA empresa (fueron ${filas[1]})`);

  psql(`
    begin;
    alter table public.company_members disable trigger protect_company_member_write;
    delete from public.company_members where company_id in ('${CA}','${CB}');
    delete from public.company_invitations where company_id in ('${CA}','${CB}');
    delete from public.company_profiles where id in ('${CA}','${CB}');
    delete from auth.users where email in (${Object.values(mails).map((m) => `'${m}'`).join(',')});
    alter table public.company_members enable trigger protect_company_member_write;
    commit;
  `);
}

// --- Main -------------------------------------------------------------------

async function main() {
  try {
    psql('select 1;');
  } catch (error) {
    console.error(`# El stack local no responde: ${error.message}`);
    console.error('# Levantalo con `npm run db:start` y volvé a intentar.');
    process.exit(2);
  }

  limpiar();
  sembrar();
  try {
    await carreraInvitaciones();
    await carreraOnboarding();
    await carreraBootstrap();
    await carreraCruzada();
  } finally {
    limpiar();
  }

  console.log(`1..${testNumber}`);
  if (failures > 0) {
    console.error(`\n# ${failures} de ${testNumber} comprobaciones fallaron.`);
    process.exit(1);
  }
  console.log(`\n# ${testNumber} comprobaciones de concurrencia, todas verdes.`);
}

await main();
