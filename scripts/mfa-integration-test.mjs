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

/// Línea informativa que **no** cuenta como aserción (comentario TAP).
function note(message) {
  console.log(`# ${message}`);
}

/// `true` solo si la respuesta es un **200 con cuerpo de usuario de GoTrue**.
///
/// Sin esto, `res.json?.factors ?? []` convierte un 401, un 429 o un 500 en una
/// lista vacía y una comprobación del tipo «el factor desapareció» se aprueba
/// sola. GoTrue puede omitir `factors` cuando no hay ninguno, pero esa forma
/// solo se acepta **después** de validar que la respuesta fue exitosa.
function isUserBody(res) {
  return (
    res?.status === 200 &&
    res.json !== null &&
    typeof res.json === 'object' &&
    typeof res.json.id === 'string' &&
    typeof res.json.aud === 'string'
  );
}

/// Factores de una respuesta de `/user` **ya validada**, o `null` si la
/// respuesta no sirve. `null` hace fallar a quien lo consuma, en vez de
/// parecerse a «no hay factores».
function factorsOf(res) {
  return isUserBody(res) ? (res.json.factors ?? []) : null;
}

/// `true` solo si la respuesta es un **200 con sesión** (token + refresh).
/// Mismo criterio que [isUserBody]: de un cuerpo de error no se leen claims ni
/// se encadena otro refresco.
function isSessionBody(res) {
  return (
    res?.status === 200 &&
    res.json !== null &&
    typeof res.json === 'object' &&
    typeof res.json.access_token === 'string' &&
    typeof res.json.refresh_token === 'string'
  );
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

/// Renovación legítima de la sesión. GoTrue rota el refresh token, así que el
/// devuelto reemplaza al usado.
async function refreshSession(refreshToken) {
  return http('/auth/v1/token?grant_type=refresh_token', {
    method: 'POST',
    body: { refresh_token: refreshToken },
  });
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

  // R2 (preparación) · Una SEGUNDA sesión de la misma cuenta, abierta antes de
  // que exista ningún factor verificado. Más abajo se comprueba que la
  // primera verificación la borra: es la mitad del contrato del servidor sobre
  // la que se apoya `SecondFactorCleanupPolicy`.
  const admin1Otra = await login(ADMIN_EMAIL);
  ok(admin1Otra !== null, 'R2: se abre una segunda sesión de la misma cuenta');
  if (!admin1Otra) throw new Error('sin la segunda sesión no se puede probar R2');
  ok(claims(admin1Otra.token).session_id !== admin1Claims.session_id, 'R2: y es otra sesión, no otro token de la misma');
  ok((await getUser(admin1Otra.token)).status === 200, 'R2: las dos sesiones conviven mientras no haya factor verificado');

  // C6 · Renovación legítima ANTES de verificar. Es la premisa de
  // `sessionIdentityOf`: si el refresco cambiara el `session_id`, la app
  // trataría cada refresco como un cambio de sesión. Se comprueba el estado
  // HTTP antes de leer ningún campo.
  const refreshBefore = await refreshSession(admin1.refresh);
  // El estado HTTP se comprueba ANTES de leer ningún campo: de un cuerpo de
  // error no se sacan claims.
  const refreshBeforeOk = ok(isSessionBody(refreshBefore), `C6: refresco ANTES de verificar responde 200 con sesión (llegó ${refreshBefore.status})`);
  const refreshBeforeClaims = refreshBeforeOk ? claims(refreshBefore.json.access_token) : null;
  ok(refreshBeforeClaims?.session_id === admin1Claims.session_id, 'C6: el refresco en aal1 CONSERVA el session_id (misma sesión)');
  ok(refreshBeforeClaims?.aal === 'aal1', `C6: el refresco en aal1 conserva el nivel (llegó "${refreshBeforeClaims?.aal}")`);
  ok(refreshBeforeOk && refreshBefore.json.refresh_token !== admin1.refresh, 'C6: el refresh token rota (el anterior queda consumido)');
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
  ok(typeof admin1Claims.session_id === 'string' && admin1Claims.session_id.length > 0, 'el token trae session_id (identidad de la sesión que usa la app)');
  ok(admin2Claims.session_id === admin1Claims.session_id, 'verificar conserva el session_id: misma sesión, nivel nuevo');
  const verifiedFactor = (good.json.user?.factors ?? []).find((f) => f.id === factorId);
  ok(verifiedFactor?.status === 'verified', `el factor quedó "verified" (llegó "${verifiedFactor?.status}")`);

  // R2 · LA PRIMERA VERIFICACIÓN BORRA LAS DEMÁS SESIONES DE LA CUENTA.
  //
  // **No es una garantía de nada**, y la versión anterior de este comentario
  // la vendía como «media garantía» de `SecondFactorCleanupPolicy`. No lo es:
  // la garantía es que la app no manda bajas automáticas, y no depende de
  // esto. R2 acota un caso vecino —si la verificación la hizo OTRA sesión,
  // por ejemplo otro dispositivo con el secreto que se mostró en pantalla,
  // esa sesión ajena deja de existir—, pero **no toca a la sesión que
  // verificó**, que es justo la peligrosa en el caso central.
  //
  // Se fija igual, como contrato observado: describe el servidor contra el
  // que se diseñaría cualquier baja futura, y si una versión de GoTrue deja
  // de hacerlo hay que enterarse acá. Lo que se fija es la mitad que se ve
  // desde este recorrido; que a una sesión distinta ya en `aal2` tampoco la
  // toque está medido aparte, con una sonda, y no acá.
  const otraDespues = await getUser(admin1Otra.token);
  note(`R2: la otra sesión tras la primera verificación -> ${otraDespues.status}/${otraDespues.json?.error_code ?? ''}`);
  ok(otraDespues.status !== 200, `R2: la sesión que NO verificó deja de servir (llegó ${otraDespues.status})`);
  ok(otraDespues.json?.error_code === 'session_not_found', `R2: y el motivo es que el servidor la borró (llegó "${otraDespues.json?.error_code}")`);
  ok((await getUser(admin2Token)).status === 200, 'R2: la sesión que SÍ verificó sigue viva');

  // C6 · Renovación legítima DESPUÉS de verificar. Si el refresco bajara el
  // nivel, la cola se cerraría sola a mitad de sesión sin que nadie tocara
  // nada. Separado de cualquier baja de factor a propósito: una baja SÍ
  // cambia el nivel del token siguiente.
  const refreshAfter = await refreshSession(good.json.refresh_token);
  const refreshAfterOk = ok(isSessionBody(refreshAfter), `C6: refresco DESPUÉS de verificar responde 200 con sesión (llegó ${refreshAfter.status})`);
  const refreshAfterClaims = refreshAfterOk ? claims(refreshAfter.json.access_token) : null;
  ok(refreshAfterClaims?.session_id === admin1Claims.session_id, 'C6: el refresco posterior CONSERVA el session_id');
  ok(refreshAfterClaims?.aal === 'aal2', `C6: el refresco NO baja el nivel: sigue aal2 (llegó "${refreshAfterClaims?.aal}")`);
  // No se encadena otro refresco sobre una respuesta inválida: el token que
  // usaríamos vendría de un cuerpo de error.
  const refreshChained = refreshAfterOk ? await refreshSession(refreshAfter.json.refresh_token) : null;
  const refreshChainedOk = ok(isSessionBody(refreshChained), `C6: segundo refresco encadenado responde 200 con sesión (llegó ${refreshChained?.status ?? 'no se intentó'})`);
  ok(refreshChainedOk && claims(refreshChained.json.access_token).aal === 'aal2', 'C6: el nivel sigue aal2 tras encadenar refrescos');

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
  ok(claims(admin3.token).session_id !== admin1Claims.session_id, 'el reingreso de la misma cuenta es OTRA sesión: session_id distinto');
  const factorsAfterLogin = (await getUser(admin3.token)).json?.factors ?? [];
  const verifiedAfterLogin = factorsAfterLogin.filter((f) => f.status === 'verified' && f.factor_type === 'totp');
  ok(verifiedAfterLogin.length === 1 && verifiedAfterLogin[0].id === factorId, `la sesión nueva ve el factor verificado (nextLevel sería aal2; llegaron ${verifiedAfterLogin.length})`);
  const listRelogin = await rpcList(admin3.token);
  ok(listRelogin.json?.code === 'TFMFA', `tener un factor verificado NO alcanza: con aal1 la cola sigue rechazada (llegó ${listRelogin.status}/${listRelogin.json?.code})`);
  const enrollAal1 = await enroll(admin3.token, `Segundo ${RUN_ID}`);
  ok(enrollAal1.status === 403 && enrollAal1.json?.error_code === 'insufficient_aal', `con un factor verificado y sesión aal1, dar de alta OTRO factor se rechaza con insufficient_aal (llegó ${enrollAal1.status}/${enrollAal1.json?.error_code})`);

  // D1 · Con una sesión que el servidor tiene en `aal1` —`admin3` es un
  // reingreso, o sea una sesión NUEVA— la baja de un factor VERIFICADO se
  // rechaza y el factor sobrevive.
  //
  // OJO con lo que esto NO dice, porque la versión anterior de este comentario
  // lo decía mal: NO dice que un token cuyo claim diga `aal1` esté protegido.
  // El servidor resuelve por el nivel de la SESIÓN, no por el claim del token
  // que le mandaron; ver la aserción D1-bis más abajo, donde un token viejo
  // con claim `aal1` SÍ borra un factor verificado. Por eso la protección del
  // cliente no puede apoyarse en el claim —y tampoco en este rechazo, que no
  // es una baja condicional—: la da `SecondFactorCleanupPolicy`, y consiste
  // en **no pedir ninguna baja automática**
  // (`automaticUnenrollEnabled = false`).
  //
  // Esta aserción se conserva igual, como contrato observado del endpoint:
  // describe con qué habría que diseñar una baja futura. Fijate que lo que
  // se fija es «no fue 200 y el error_code es insufficient_aal», no el 422
  // exacto: el número se anota en la nota de arriba y no se convierte en
  // contrato.
  const unenrollAal1 = await unenroll(admin3.token, factorId);
  note(`D1: DELETE de un factor verificado con aal1 -> ${unenrollAal1.status}/${unenrollAal1.json?.error_code ?? ''}`);
  ok(unenrollAal1.status !== 200 && unenrollAal1.json?.error_code === 'insufficient_aal', `D1: con aal1 NO se puede dar de baja un factor verificado (llegó ${unenrollAal1.status}/${unenrollAal1.json?.error_code})`);
  // Un rechazo HTTP no alcanza: se vuelve a consultar el estado al servidor.
  const afterReject = await getUser(admin3.token);
  ok(isUserBody(afterReject), `D1: la consulta posterior al rechazo es un 200 con cuerpo de usuario (llegó ${afterReject.status})`);
  const survivors = (factorsOf(afterReject) ?? []).filter((f) => f.id === factorId);
  ok(factorsOf(afterReject) !== null && survivors.length === 1 && survivors[0].status === 'verified', `D1: tras el rechazo el factor SIGUE verified en el servidor (llegaron ${survivors.length}/"${survivors[0]?.status}")`);

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
  if (companyPending.status !== 200) throw new Error('sin alta pendiente de la empresa no se puede seguir');
  const discarded = await unenroll(company1.token, companyPending.json.id);
  ok(discarded.status === 200 && discarded.json?.id === companyPending.json.id, `un factor PENDIENTE se puede descartar con sesión aal1 (llegó ${discarded.status})`);
  const afterDiscard = (await getUser(company1.token)).json?.factors ?? [];
  ok(afterDiscard.length === 0, `tras descartar no queda ningún factor (llegaron ${afterDiscard.length})`);

  const companyEnroll = await enroll(company1.token, `Empresa ${RUN_ID}`);
  ok(companyEnroll.status === 200 && Boolean(companyEnroll.json?.totp?.secret), `alta TOTP de la cuenta de empresa para el segundo tramo (llegó ${companyEnroll.status}/${companyEnroll.json?.error_code ?? ''})`);
  if (companyEnroll.status !== 200) throw new Error('sin alta de la empresa no se puede seguir');
  const companyChallenge = await challenge(company1.token, companyEnroll.json.id);
  ok(companyChallenge.status === 200 && Boolean(companyChallenge.json?.id), `desafío del factor de la empresa (llegó ${companyChallenge.status}/${companyChallenge.json?.error_code ?? ''})`);
  if (companyChallenge.status !== 200) throw new Error('sin desafío de la empresa no se puede seguir');
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

  // D1-bis · EL HECHO QUE SOSTIENE TODO EL DISEÑO DEL CLIENTE, y el que
  // desmintió la versión anterior: el servidor resuelve el `insufficient_aal`
  // por el nivel de la SESIÓN, no por el claim `aal` del token que le
  // mandaron. Se usa a propósito `company1.token`, el token ORIGINAL de esa
  // misma sesión, emitido ANTES de verificar y cuyo claim sigue diciendo
  // `aal1`. Es la ventana de D1: el servidor aceptó el código y el cliente
  // conserva el token viejo porque la respuesta se perdió.
  //
  // Si esto dejara de ser 200, la protección del cliente se podría simplificar
  // muchísimo, así que hay que enterarse acá. Va al final y sobre la cuenta de
  // empresa, que ya no se usa para nada más, porque es destructivo.
  const companyOldToken = company1.token;
  ok(claims(companyOldToken).aal === 'aal1', `D1-bis: el token original de la empresa sigue diciendo aal1 (llegó "${claims(companyOldToken).aal}")`);
  ok(claims(companyOldToken).session_id === claims(companyVerify.json.access_token).session_id, 'D1-bis: y es la MISMA sesión que el servidor ya subió a aal2');
  const unenrollTokenViejo = await unenroll(companyOldToken, companyEnroll.json.id);
  note(`D1-bis: DELETE de un factor verificado con el token viejo (claim aal1) -> ${unenrollTokenViejo.status}/${unenrollTokenViejo.json?.error_code ?? ''}`);
  ok(unenrollTokenViejo.status === 200, `D1-bis: el servidor ACEPTA la baja aunque el claim del token diga aal1 (llegó ${unenrollTokenViejo.status})`);
  // Un 200 no alcanza: se vuelve a consultar el estado, y la respuesta se
  // valida antes de leerla (un 401 tampoco trae factores).
  const afterDelete = await getUser(companyOldToken);
  ok(isUserBody(afterDelete), `D1-bis: la consulta posterior al borrado es un 200 con cuerpo de usuario (llegó ${afterDelete.status})`);
  const factorsAfterDelete = factorsOf(afterDelete);
  ok(factorsAfterDelete !== null && !factorsAfterDelete.some((f) => f.id === companyEnroll.json.id), `D1-bis: y el factor verificado DESAPARECIÓ de verdad (quedaron ${factorsAfterDelete === null ? 'respuesta inválida' : factorsAfterDelete.length} factores)`);
  note('D1-bis: por eso el cliente no se apoya en el claim, sino en no pedir bajas que no pueda justificar');

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
  console.log(`1..${testNumber}`);
  console.error(`[mfa:test] timeout global de ${GLOBAL_TIMEOUT_MS} ms superado.`);
  cleanup();
  process.exit(1);
}, GLOBAL_TIMEOUT_MS);

try {
  await main();
} catch (error) {
  // El plan también en el camino de error: una salida TAP sin `1..N` se lee
  // como truncada y no dice cuántas aserciones llegaron a correr.
  console.log(`1..${testNumber}`);
  console.error('[mfa:test] error inesperado:', error);
  cleanup();
  process.exit(1);
} finally {
  clearTimeout(watchdog);
}
