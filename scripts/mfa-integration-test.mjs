// Integración real del segundo factor TOTP para administración (T-028 / T-076
// parcial): alta, desafío y verificación contra el GoTrue del stack local, y
// las RPC de revisión rechazando ANTES y aceptando DESPUÉS de verificar.
//
// Corre contra el stack local (`npm run db:start`) con Node 22 y SOLO fetch
// global: sin dependencias npm. Lee la URL y la clave publicable de
// env/dev.json (claves públicas; acá jamás entra el service role). Las cuentas
// son SINTÉTICAS y se crean y borran en cada corrida: el único fixture
// privilegiado —promover una cuenta a `admin`— se hace con `psql` dentro del
// contenedor de la base, que es la vía que documenta SECURITY.md §3
// (`UPDATE profiles.role` desde un contexto privilegiado; el trigger 0019
// propaga el claim). Nada de esto toca el cliente ni las cuentas del seed.
//
// Qué NO reemplaza: los tests de widgets y de repositorio de Flutter cubren la
// app; esto prueba que el SERVIDOR se comporta como la app supone, con tokens
// reales y códigos TOTP calculados de verdad (RFC 6238, HMAC-SHA1, 30 s).
//
// Salida estilo TAP: `ok N - …` / `not ok N - …` + resumen; exit 1 si algo
// falla, exit 2 si el stack no está levantado. Nunca imprime secretos TOTP,
// códigos, tokens ni QR: solo estados, códigos de error y claims públicos.

import { createHmac, randomBytes } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import process from 'node:process';

const projectRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const env = JSON.parse(readFileSync(join(projectRoot, 'env', 'dev.json'), 'utf8'));
const BASE_URL = env.SUPABASE_URL;
const ANON_KEY = env.SUPABASE_ANON_KEY;
const CONTAINER =
  process.env.SUPABASE_DB_CONTAINER ?? 'supabase_db_talentflash_argentina';

const PASSWORD = 'password123';
const RUN_ID = randomBytes(4).toString('hex');
const ADMIN_EMAIL = `mfa-admin-${RUN_ID}@tests.local`;
const COMPANY_EMAIL = `mfa-empresa-${RUN_ID}@tests.local`;

const FETCH_TIMEOUT_MS = 15000;
const GLOBAL_TIMEOUT_MS = 240000;

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

// --- HTTP -------------------------------------------------------------------
async function http(path, { token, method = 'GET', body } = {}) {
  const headers = { apikey: ANON_KEY, 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(`${BASE_URL}${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
  });
  const text = await res.text();
  let json = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = null;
  }
  return { status: res.status, json };
}

/** Claims del access token, decodificados sin verificar (solo lectura local). */
function claims(token) {
  const payload = token.split('.')[1];
  return JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
}

async function signUp(email, role) {
  const res = await http('/auth/v1/signup', {
    method: 'POST',
    body: { email, password: PASSWORD, data: { role } },
  });
  return res;
}

async function login(email) {
  const res = await http('/auth/v1/token?grant_type=password', {
    method: 'POST',
    body: { email, password: PASSWORD },
  });
  if (res.status !== 200 || !res.json?.access_token) return null;
  return { token: res.json.access_token, refresh: res.json.refresh_token, user: res.json.user };
}

async function logout(token) {
  return http('/auth/v1/logout?scope=global', { method: 'POST', token });
}

async function enroll(token, friendlyName) {
  return http('/auth/v1/factors', {
    method: 'POST',
    token,
    body: { factor_type: 'totp', friendly_name: friendlyName, issuer: 'TalentFlash Argentina' },
  });
}

async function challenge(token, factorId) {
  return http(`/auth/v1/factors/${factorId}/challenge`, { method: 'POST', token });
}

async function verify(token, factorId, challengeId, code) {
  return http(`/auth/v1/factors/${factorId}/verify`, {
    method: 'POST',
    token,
    body: { challenge_id: challengeId, code },
  });
}

async function unenroll(token, factorId) {
  return http(`/auth/v1/factors/${factorId}`, { method: 'DELETE', token });
}

async function getUser(token) {
  return http('/auth/v1/user', { token });
}

async function rpcList(token) {
  return http('/rest/v1/rpc/admin_list_company_verifications', {
    method: 'POST',
    token,
    body: { p_status: 'pending' },
  });
}

async function rpcReview(token) {
  return http('/rest/v1/rpc/admin_review_company_verification', {
    method: 'POST',
    token,
    body: {
      p_request_id: '00000000-0000-4000-8000-000000000000',
      p_decision: 'approved',
      p_reason: null,
    },
  });
}

// --- TOTP (RFC 6238 sobre HOTP RFC 4226): HMAC-SHA1, 30 s, 6 dígitos --------
function base32Decode(input) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  const clean = input.toUpperCase().replace(/=+$/, '').replace(/\s/g, '');
  let bits = 0;
  let value = 0;
  const out = [];
  for (const char of clean) {
    const index = alphabet.indexOf(char);
    if (index < 0) throw new Error('secreto base32 inválido');
    value = (value << 5) | index;
    bits += 5;
    if (bits >= 8) {
      out.push((value >>> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  return Buffer.from(out);
}

function totpStep(nowMs = Date.now()) {
  return Math.floor(nowMs / 1000 / 30);
}

function totpCode(secretBase32, step) {
  const key = base32Decode(secretBase32);
  const counter = Buffer.alloc(8);
  counter.writeBigUInt64BE(BigInt(step));
  const digest = createHmac('sha1', key).update(counter).digest();
  const offset = digest[digest.length - 1] & 0x0f;
  const binary =
    ((digest[offset] & 0x7f) << 24) |
    ((digest[offset + 1] & 0xff) << 16) |
    ((digest[offset + 2] & 0xff) << 8) |
    (digest[offset + 3] & 0xff);
  return String(binary % 1_000_000).padStart(6, '0');
}

/** Un código de 6 dígitos distinto del vigente (para probar el rechazo). */
function wrongCode(secretBase32) {
  const current = totpCode(secretBase32, totpStep());
  const previous = totpCode(secretBase32, totpStep() - 1);
  const next = totpCode(secretBase32, totpStep() + 1);
  for (const candidate of ['000000', '123456', '999999', '111111']) {
    if (candidate !== current && candidate !== previous && candidate !== next) {
      return candidate;
    }
  }
  return '424242';
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/** Espera a que el reloj TOTP cambie de paso respecto de `usedStep`. */
async function waitForFreshStep(usedStep) {
  while (totpStep() === usedStep) {
    await sleep(1000);
  }
}

// --- psql (fixture privilegiado, SOLO en el entorno de pruebas) -------------
function psql(sql) {
  const result = spawnSync(
    'docker',
    ['exec', '-i', CONTAINER, 'psql', '-X', '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1', '-At'],
    { input: sql, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 },
  );
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`psql salió ${result.status}: ${result.stderr}`);
  }
  return (result.stdout ?? '').trim();
}

function promoteToAdmin(userId) {
  // psql imprime la etiqueta del UPDATE aun con -At; la última línea es la
  // del SELECT.
  return psql(
    `update public.profiles set role = 'admin' where id = '${userId}';\n` +
      `select p.role::text || '/' || coalesce(u.raw_app_meta_data ->> 'role', '')\n` +
      `from public.profiles p join auth.users u on u.id = p.id where p.id = '${userId}';`,
  )
    .split('\n')
    .pop();
}

function cleanup() {
  try {
    const rows = psql(
      `delete from auth.users where email in ('${ADMIN_EMAIL}', '${COMPANY_EMAIL}');\n` +
        `select count(*) from auth.users where email in ('${ADMIN_EMAIL}', '${COMPANY_EMAIL}');`,
    );
    return rows.split('\n').pop();
  } catch (error) {
    console.error('[mfa:test] no se pudieron borrar las cuentas sintéticas:', error.message);
    return null;
  }
}

async function checkStack() {
  try {
    const res = await http('/auth/v1/health');
    return res.status === 200;
  } catch {
    return false;
  }
}

// --- Escenario ----------------------------------------------------------------
async function main() {
  if (!(await checkStack())) {
    console.error(`El stack local no responde en ${BASE_URL} — levantá el stack con npm run db:start`);
    process.exit(2);
  }

  // 1. Cuentas sintéticas. La futura admin nace como `company` (el registro
  //    público no puede pedir admin) y se promueve por psql.
  const adminSignUp = await signUp(ADMIN_EMAIL, 'company');
  ok(adminSignUp.status === 200 && Boolean(adminSignUp.json?.access_token), `alta sintética de la futura admin (llegó ${adminSignUp.status})`);
  const companySignUp = await signUp(COMPANY_EMAIL, 'company');
  ok(companySignUp.status === 200 && Boolean(companySignUp.json?.access_token), `alta sintética de la cuenta de empresa sin rol admin (llegó ${companySignUp.status})`);
  if (adminSignUp.status !== 200 || companySignUp.status !== 200) {
    throw new Error('Sin las dos altas no se puede seguir.');
  }
  const adminId = adminSignUp.json.user.id;

  const promoted = promoteToAdmin(adminId);
  ok(promoted === 'admin/admin', `profiles.role = admin y el claim quedó sincronizado por 0019 (llegó "${promoted}")`);

  // 2. Sesión nueva de la admin: un factor, claim aal1, sin factores.
  const admin1 = await login(ADMIN_EMAIL);
  ok(admin1 !== null, 'login de la admin con contraseña');
  if (!admin1) throw new Error('sin login de la admin no se puede seguir');
  const admin1Claims = claims(admin1.token);
  ok(admin1Claims.app_metadata?.role === 'admin', `el JWT trae app_metadata.role = admin (llegó "${admin1Claims.app_metadata?.role}")`);
  ok(admin1Claims.aal === 'aal1', `una sesión de contraseña sola es aal1 (llegó "${admin1Claims.aal}")`);
  const factorsBefore = (await getUser(admin1.token)).json?.factors ?? [];
  ok(factorsBefore.length === 0, `la cuenta arranca sin factores (llegaron ${factorsBefore.length})`);

  // 3. Las RPC rechazan al admin aal1 ANTES de cualquier alta.
  const listBefore = await rpcList(admin1.token);
  ok(listBefore.status !== 200 && listBefore.json?.code === 'TFMFA', `admin aal1: listar la cola se rechaza con TFMFA (llegó ${listBefore.status}/${listBefore.json?.code})`);
  const reviewBefore = await rpcReview(admin1.token);
  ok(reviewBefore.status !== 200 && reviewBefore.json?.code === 'TFMFA', `admin aal1: resolver se rechaza con TFMFA antes de tocar datos (llegó ${reviewBefore.status}/${reviewBefore.json?.code})`);

  // 4. Alta TOTP: factor pendiente con secreto y URI. No se imprimen.
  const enrolled = await enroll(admin1.token, `Autenticador ${RUN_ID}`);
  const totp = enrolled.json?.totp;
  ok(enrolled.status === 200 && enrolled.json?.type === 'totp' && Boolean(enrolled.json?.id), `alta TOTP devuelve un factor pendiente (llegó ${enrolled.status}/${enrolled.json?.type})`);
  ok(typeof totp?.secret === 'string' && totp.secret.length >= 16, 'el alta trae un secreto base32 (no se imprime)');
  ok(typeof totp?.uri === 'string' && totp.uri.startsWith('otpauth://totp/'), 'el alta trae la URI otpauth para el QR (no se imprime)');
  ok(typeof totp?.qr_code === 'string' && totp.qr_code.includes('<svg'), 'el alta trae el QR como SVG (no se imprime)');
  if (enrolled.status !== 200) throw new Error('sin alta TOTP no se puede seguir');
  const factorId = enrolled.json.id;
  const secret = totp.secret;

  const pendingUser = await getUser(admin1.token);
  const pendingFactor = (pendingUser.json?.factors ?? []).find((f) => f.id === factorId);
  ok(pendingFactor?.status === 'unverified', `el factor recién dado de alta figura "unverified" (llegó "${pendingFactor?.status}")`);
  const listPending = await rpcList(admin1.token);
  ok(listPending.json?.code === 'TFMFA', `un factor PENDIENTE no habilita nada: la cola sigue rechazada con TFMFA (llegó ${listPending.status}/${listPending.json?.code})`);

  const duplicated = await enroll(admin1.token, `Autenticador ${RUN_ID}`);
  ok(duplicated.status === 422 && duplicated.json?.error_code === 'mfa_factor_name_conflict', `repetir el nombre del factor se rechaza con mfa_factor_name_conflict (llegó ${duplicated.status}/${duplicated.json?.error_code})`);

  // 5. Desafío + código incorrecto + código correcto.
  const challenged = await challenge(admin1.token, factorId);
  ok(challenged.status === 200 && Boolean(challenged.json?.id) && typeof challenged.json?.expires_at === 'number', `el desafío devuelve id y expires_at numérico (llegó ${challenged.status})`);
  if (challenged.status !== 200) throw new Error('sin desafío no se puede seguir');
  const challengeId = challenged.json.id;

  const bad = await verify(admin1.token, factorId, challengeId, wrongCode(secret));
  ok(bad.status === 422 && bad.json?.error_code === 'mfa_verification_failed', `un código incorrecto se rechaza con mfa_verification_failed (llegó ${bad.status}/${bad.json?.error_code})`);
  const listAfterBad = await rpcList(admin1.token);
  ok(listAfterBad.json?.code === 'TFMFA', `tras el código incorrecto la cola sigue rechazada con TFMFA (llegó ${listAfterBad.status}/${listAfterBad.json?.code})`);

  const step1 = totpStep();
  const good = await verify(admin1.token, factorId, challengeId, totpCode(secret, step1));
  ok(good.status === 200 && Boolean(good.json?.access_token), `el código correcto verifica el factor (llegó ${good.status}/${good.json?.error_code ?? ''})`);
  if (good.status !== 200) throw new Error('sin verificación no se puede seguir');
  const admin2Token = good.json.access_token;
  const admin2Claims = claims(admin2Token);
  ok(admin2Claims.aal === 'aal2', `el token nuevo es aal2 (llegó "${admin2Claims.aal}")`);
  ok(Array.isArray(admin2Claims.amr) && admin2Claims.amr.some((m) => m.method === 'totp'), 'el amr del token nuevo incluye totp');
  ok(admin2Claims.sub === admin1Claims.sub, 'mismo usuario antes y después de verificar (mismo sub)');
  ok(admin2Claims.app_metadata?.role === 'admin', 'mismo rol antes y después de verificar');
  const verifiedFactor = (good.json.user?.factors ?? []).find((f) => f.id === factorId);
  ok(verifiedFactor?.status === 'verified', `el factor quedó "verified" (llegó "${verifiedFactor?.status}")`);

  // 6. Con aal2 la RPC acepta.
  const listAfter = await rpcList(admin2Token);
  ok(listAfter.status === 200 && Array.isArray(listAfter.json), `admin aal2: listar la cola responde 200 con una lista (llegó ${listAfter.status}/${listAfter.json?.code ?? ''})`);
  const reviewAfter = await rpcReview(admin2Token);
  ok(reviewAfter.status !== 200 && reviewAfter.json?.code !== 'TFMFA' && reviewAfter.json?.code !== '42501', `admin aal2: resolver pasa la puerta de sesión y falla recién por la solicitud inexistente (llegó ${reviewAfter.status}/${reviewAfter.json?.code})`);

  // 7. Cierre de sesión y reingreso: vuelve a aal1 y hay que desafiar de nuevo
  //    el factor ya verificado; no se crea otro.
  const loggedOut = await logout(admin2Token);
  ok(loggedOut.status === 204, `cierre de sesión global (llegó ${loggedOut.status})`);
  const admin3 = await login(ADMIN_EMAIL);
  ok(admin3 !== null, 'reingreso de la admin con contraseña');
  if (!admin3) throw new Error('sin reingreso de la admin no se puede seguir');
  ok(claims(admin3.token).aal === 'aal1', `la sesión nueva vuelve a ser aal1 (llegó "${claims(admin3.token).aal}")`);
  const factorsAfterLogin = (await getUser(admin3.token)).json?.factors ?? [];
  const verifiedAfterLogin = factorsAfterLogin.filter((f) => f.status === 'verified' && f.factor_type === 'totp');
  ok(verifiedAfterLogin.length === 1 && verifiedAfterLogin[0].id === factorId, `la sesión nueva ve el factor verificado (nextLevel sería aal2; llegaron ${verifiedAfterLogin.length})`);
  const listRelogin = await rpcList(admin3.token);
  ok(listRelogin.json?.code === 'TFMFA', `tener un factor verificado NO alcanza: con aal1 la cola sigue rechazada (llegó ${listRelogin.status}/${listRelogin.json?.code})`);
  const enrollAal1 = await enroll(admin3.token, `Segundo ${RUN_ID}`);
  ok(enrollAal1.status === 403 && enrollAal1.json?.error_code === 'insufficient_aal', `con un factor verificado y sesión aal1, dar de alta OTRO factor se rechaza con insufficient_aal (llegó ${enrollAal1.status}/${enrollAal1.json?.error_code})`);

  const challenge2 = await challenge(admin3.token, factorId);
  ok(challenge2.status === 200, `nuevo desafío sobre el factor existente (llegó ${challenge2.status})`);
  await waitForFreshStep(step1);
  const step2 = totpStep();
  const good2 = await verify(admin3.token, factorId, challenge2.json.id, totpCode(secret, step2));
  ok(good2.status === 200 && claims(good2.json.access_token).aal === 'aal2', `el reingreso llega a aal2 con el mismo factor (llegó ${good2.status}/${good2.json?.error_code ?? ''})`);
  const listRelogin2 = await rpcList(good2.json?.access_token ?? '');
  ok(listRelogin2.status === 200, `tras el nuevo desafío la cola vuelve a responder 200 (llegó ${listRelogin2.status})`);

  // 8. Sin rol admin, aal2 no otorga nada: la cuenta de empresa se enrola y
  //    verifica igual que la admin y las RPC la rechazan con 42501.
  const company1 = await login(COMPANY_EMAIL);
  ok(company1 !== null, 'login de la cuenta de empresa');
  if (!company1) throw new Error('sin login de la empresa no se puede seguir');
  const companyPending = await enroll(company1.token, `Empresa ${RUN_ID}`);
  ok(companyPending.status === 200, `la cuenta de empresa puede dar de alta un factor (llegó ${companyPending.status})`);
  const discarded = await unenroll(company1.token, companyPending.json.id);
  ok(discarded.status === 200 && discarded.json?.id === companyPending.json.id, `un factor PENDIENTE se puede descartar con sesión aal1 (llegó ${discarded.status})`);
  const afterDiscard = (await getUser(company1.token)).json?.factors ?? [];
  ok(afterDiscard.length === 0, `tras descartar no queda ningún factor (llegaron ${afterDiscard.length})`);

  const companyEnroll = await enroll(company1.token, `Empresa ${RUN_ID}`);
  const companyChallenge = await challenge(company1.token, companyEnroll.json.id);
  const companyVerify = await verify(
    company1.token,
    companyEnroll.json.id,
    companyChallenge.json.id,
    totpCode(companyEnroll.json.totp.secret, totpStep()),
  );
  ok(companyVerify.status === 200 && claims(companyVerify.json.access_token).aal === 'aal2', `la cuenta de empresa llega a aal2 (llegó ${companyVerify.status})`);
  const companyList = await rpcList(companyVerify.json.access_token);
  ok(companyList.status !== 200 && companyList.json?.code === '42501', `aal2 sin rol admin: listar la cola se rechaza con 42501 (llegó ${companyList.status}/${companyList.json?.code})`);
  const companyReview = await rpcReview(companyVerify.json.access_token);
  ok(companyReview.status !== 200 && companyReview.json?.code === '42501', `aal2 sin rol admin: resolver se rechaza con 42501 (llegó ${companyReview.status}/${companyReview.json?.code})`);

  // 9. Limpieza de las cuentas sintéticas.
  const remaining = cleanup();
  ok(remaining === '0', `las cuentas sintéticas se borraron (quedan ${remaining})`);

  console.log(`1..${testNumber}`);
  if (failures > 0) {
    console.error(`\n[mfa:test] ${failures} de ${testNumber} aserciones fallaron.`);
    process.exit(1);
  }
  console.log(`\n[mfa:test] ${testNumber} aserciones aprobadas.`);
}

const watchdog = setTimeout(() => {
  console.error(`[mfa:test] timeout global de ${GLOBAL_TIMEOUT_MS} ms superado.`);
  cleanup();
  process.exit(1);
}, GLOBAL_TIMEOUT_MS);

try {
  await main();
} catch (error) {
  console.error('[mfa:test] error inesperado:', error);
  cleanup();
  process.exit(1);
} finally {
  clearTimeout(watchdog);
}
