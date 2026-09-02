// Test de integración de Storage + Edge Function `avatar` (Bloque D, T-022).
//
// Corre contra el stack local (`npm run db:start` + `npm run db:reset`) con
// Node 22 y SOLO fetch global: sin dependencias npm. Lee la URL y la clave
// publicable de env/dev.json (claves públicas; acá jamás entra el service
// role). Usuarios del seed, contraseña única `password123`:
//   - candidato3: sujeto (perfil publicado, candidatos 1-15 lo están)
//   - candidato2: otro candidato (no debe leer el avatar ajeno)
//   - empresa3:   empresa verificada (sí puede leer)
//   - empresa7:   empresa pendiente de verificación (no puede)
// Salida estilo TAP: `ok N - …` / `not ok N - …` + resumen; exit 1 si algo
// falla, exit 2 si el stack no está levantado.

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Buffer } from 'node:buffer';
import process from 'node:process';

const projectRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const env = JSON.parse(readFileSync(join(projectRoot, 'env', 'dev.json'), 'utf8'));
const BASE_URL = env.SUPABASE_URL;
const ANON_KEY = env.SUPABASE_ANON_KEY;

const PASSWORD = 'password123';
const SUJETO = 'candidato3@dev.talentflash.test';
const OTRO_CANDIDATO = 'candidato2@dev.talentflash.test';
const EMPRESA_VERIFICADA = 'empresa3@dev.talentflash.test';
const EMPRESA_PENDIENTE = 'empresa7@dev.talentflash.test';

const FETCH_TIMEOUT_MS = 15000;
const GLOBAL_TIMEOUT_MS = 180000;

// --- Fixtures embebidas (generadas con ImageScript, decodificables por la
// --- función; regenerables con cualquier encoder estándar) ---
// PNG real 16×16 rojo liso (101 bytes).
const PNG_B64 =
  'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAALElEQVR4Ae3RqQEAAABBUfsv7ZjhV0EkPLJkkg9UgACu24m/MAiSI1aAAK4bMMT+EA2OlsgAAAAASUVORK5CYII=';
// JPEG real 16×16 azul liso (673 bytes) con APP1 EXIF de orientación 6
// (little endian) spliceado tras el SOI: ejercita el parser de exif.ts.
const JPEG_B64 =
  '/9j/4QAiRXhpZgAASUkqAAgAAAABABIBAwABAAAABgAAAAAAAAD/4AAQSkZJRgABAgAAAQABAAD/wAARCAAQABADAREAAhEBAxEB/9sAQwAFAwQEBAMFBAQEBQUFBgcMCAcHBwcPCwsJDBEPEhIRDxERExYcFxMUGhURERghGBodHR8fHxMXIiQiHiQcHh8e/9sAQwEFBQUHBgcOCAgOHhQRFB4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4e/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD5hr+yz50KACgAoA//2Q==';

// --- Contadores TAP ---
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

// --- Helpers HTTP (fetch global, timeout por request) ---
async function http(path, options = {}) {
  return fetch(`${BASE_URL}${path}`, {
    ...options,
    signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
  });
}

async function login(email) {
  const res = await http('/auth/v1/token?grant_type=password', {
    method: 'POST',
    headers: { apikey: ANON_KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: PASSWORD }),
  });
  if (!res.ok) return null;
  const body = await res.json();
  if (!body.access_token || !body.user?.id) return null;
  return { token: body.access_token, userId: body.user.id };
}

async function uploadAvatar(token, dataB64, contentType) {
  return http('/functions/v1/avatar', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      apikey: ANON_KEY,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ data: dataB64, content_type: contentType }),
  });
}

async function signObject(objectPath, token, expiresIn) {
  const headers = { apikey: ANON_KEY, 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  return http(`/storage/v1/object/sign/avatars/${objectPath}`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ expiresIn }),
  });
}

async function downloadSigned(signedURL) {
  return http(`/storage/v1${signedURL}`, { method: 'GET' });
}

/** Firma y descarga; devuelve { signStatus, getStatus, bytes, contentType }. */
async function signAndDownload(objectPath, token, expiresIn) {
  const signRes = await signObject(objectPath, token, expiresIn);
  if (!signRes.ok) {
    return { signStatus: signRes.status, getStatus: null, bytes: null, contentType: null };
  }
  const { signedURL } = await signRes.json();
  const getRes = await downloadSigned(signedURL);
  const bytes = getRes.ok ? Buffer.from(await getRes.arrayBuffer()) : null;
  return {
    signStatus: signRes.status,
    getStatus: getRes.status,
    bytes,
    contentType: getRes.headers.get('content-type'),
  };
}

async function fetchAvatarUrl(token, userId) {
  const res = await http(`/rest/v1/profiles?select=avatar_url&id=eq.${userId}`, {
    headers: { apikey: ANON_KEY, Authorization: `Bearer ${token}` },
  });
  if (!res.ok) return undefined;
  const rows = await res.json();
  return rows[0]?.avatar_url;
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// --- Chequeo previo: ¿está levantado el stack? ---
async function checkStack() {
  try {
    const res = await http('/auth/v1/health', { headers: { apikey: ANON_KEY } });
    return res.status === 200;
  } catch {
    return false;
  }
}

async function main() {
  if (!(await checkStack())) {
    console.error(`El stack local no responde en ${BASE_URL} — levantá el stack con npm run db:start`);
    process.exit(2);
  }

  // --- 1. Login de los 4 usuarios del seed ---
  const sujeto = await login(SUJETO);
  ok(sujeto !== null, `login de ${SUJETO}`);
  const otroCandidato = await login(OTRO_CANDIDATO);
  ok(otroCandidato !== null, `login de ${OTRO_CANDIDATO}`);
  const empresaVerificada = await login(EMPRESA_VERIFICADA);
  ok(empresaVerificada !== null, `login de ${EMPRESA_VERIFICADA}`);
  const empresaPendiente = await login(EMPRESA_PENDIENTE);
  ok(empresaPendiente !== null, `login de ${EMPRESA_PENDIENTE}`);
  if (!sujeto || !otroCandidato || !empresaVerificada || !empresaPendiente) {
    console.error('Sin los 4 logins no se puede seguir. ¿Corriste npm run db:reset?');
    process.exit(1);
  }

  // --- 2. Upload de un PNG válido → 200 con paths canónicos ---
  const uploadRes = await uploadAvatar(sujeto.token, PNG_B64, 'image/png');
  const uploadBody = uploadRes.ok ? await uploadRes.json() : {};
  const cidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
  const avatarPath = uploadBody.avatar_path ?? '';
  const cid = avatarPath.split('/')[0] ?? '';
  ok(uploadRes.status === 200, `upload PNG válido devuelve 200 (llegó ${uploadRes.status})`);
  ok(
    cidPattern.test(cid) && avatarPath === `${cid}/avatar.jpg`,
    `avatar_path canónico <cid>/avatar.jpg (llegó "${avatarPath}")`,
  );
  ok(
    uploadBody.thumb_path === `${cid}/thumb.jpg`,
    `thumb_path canónico <cid>/thumb.jpg (llegó "${uploadBody.thumb_path}")`,
  );
  if (!uploadRes.ok || !cidPattern.test(cid)) {
    console.error('Sin upload no tiene sentido seguir.');
    process.exit(1);
  }

  // --- 3. profiles.avatar_url del sujeto = path canónico ---
  const avatarUrl = await fetchAvatarUrl(sujeto.token, sujeto.userId);
  ok(avatarUrl === avatarPath, `profiles.avatar_url = "${avatarPath}" (llegó "${avatarUrl}")`);

  // --- 4. Signed URL del avatar → 200, re-encodeado a JPEG ---
  const avatarDescarga = await signAndDownload(avatarPath, sujeto.token, 120);
  ok(avatarDescarga.getStatus === 200, `signed URL del avatar descarga 200 (sign ${avatarDescarga.signStatus}, GET ${avatarDescarga.getStatus})`);
  const bytesPaso4 = avatarDescarga.bytes;
  ok(
    bytesPaso4 !== null && bytesPaso4[0] === 0xff && bytesPaso4[1] === 0xd8 && bytesPaso4[2] === 0xff,
    'el contenido arranca con ff d8 ff: subimos PNG y quedó re-encodeado a JPEG',
  );
  ok(
    (avatarDescarga.contentType ?? '').startsWith('image/jpeg'),
    `content-type image/jpeg (llegó "${avatarDescarga.contentType}")`,
  );

  // --- 5. Signed URL del thumb → 200 ---
  const thumbDescarga = await signAndDownload(`${cid}/thumb.jpg`, sujeto.token, 120);
  ok(thumbDescarga.getStatus === 200, `signed URL del thumb descarga 200 (GET ${thumbDescarga.getStatus})`);

  // --- 6. URL firmada vencida NO sirve el archivo (criterio T-022) ---
  const signCorto = await signObject(avatarPath, sujeto.token, 1);
  let vencidaStatus = null;
  if (signCorto.ok) {
    const { signedURL } = await signCorto.json();
    await sleep(3000);
    vencidaStatus = (await downloadSigned(signedURL)).status;
  }
  ok(
    signCorto.ok && vencidaStatus !== 200,
    `URL firmada con expiresIn=1 vencida no devuelve 200 (llegó ${vencidaStatus})`,
  );

  // --- 7. Reemplazo: subir JPEG (con EXIF) → mismo path, contenido nuevo ---
  const reemplazoRes = await uploadAvatar(sujeto.token, JPEG_B64, 'image/jpeg');
  const reemplazoBody = reemplazoRes.ok ? await reemplazoRes.json() : {};
  ok(
    reemplazoRes.status === 200 && reemplazoBody.avatar_path === avatarPath,
    `reemplazo con JPEG devuelve 200 y el MISMO path (llegó ${reemplazoRes.status}, "${reemplazoBody.avatar_path}")`,
  );
  const avatarNuevo = await signAndDownload(avatarPath, sujeto.token, 120);
  const cambio =
    avatarNuevo.bytes !== null &&
    bytesPaso4 !== null &&
    (avatarNuevo.bytes.length !== bytesPaso4.length || !avatarNuevo.bytes.equals(bytesPaso4));
  ok(cambio, 'el contenido descargado cambió respecto del paso 4 (sobreescritura real)');

  // --- 8. Archivo inválido (HTML) → 415 invalid_image ---
  const htmlB64 = Buffer.from('<html><body>no soy una imagen</body></html>').toString('base64');
  const invalidoRes = await uploadAvatar(sujeto.token, htmlB64, 'image/png');
  const invalidoBody = await invalidoRes.json().catch(() => ({}));
  ok(
    invalidoRes.status === 415 && invalidoBody.code === 'invalid_image',
    `HTML disfrazado → 415 invalid_image (llegó ${invalidoRes.status}/${invalidoBody.code})`,
  );

  // --- 9. Payload > 2 MiB → 413 too_large ---
  const grandeB64 = Buffer.alloc(Math.round(2.1 * 1024 * 1024), 0xab).toString('base64');
  const grandeRes = await uploadAvatar(sujeto.token, grandeB64, 'image/jpeg');
  const grandeBody = await grandeRes.json().catch(() => ({}));
  ok(
    grandeRes.status === 413 && grandeBody.code === 'too_large',
    `payload de 2.1 MB → 413 too_large (llegó ${grandeRes.status}/${grandeBody.code})`,
  );

  // --- 10. Escritura DIRECTA a storage → 4xx (sin policy de INSERT) ---
  // El cid de candidato2 se obtiene con SU propio JWT (RLS cand_owner_all).
  const cid2Res = await http(
    `/rest/v1/candidate_profiles?select=id&profile_id=eq.${otroCandidato.userId}`,
    { headers: { apikey: ANON_KEY, Authorization: `Bearer ${otroCandidato.token}` } },
  );
  const cid2 = cid2Res.ok ? (await cid2Res.json())[0]?.id : undefined;
  ok(Boolean(cid2), `candidato2 lee su propio candidate_profile_id (${cid2 ?? 'sin fila'})`);
  const directoRes = await http(`/storage/v1/object/avatars/${cid2 ?? cid}/hack.jpg`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${sujeto.token}`,
      apikey: ANON_KEY,
      'Content-Type': 'image/jpeg',
    },
    body: Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x00]),
  });
  ok(
    directoRes.status >= 400 && directoRes.status < 500,
    `POST directo a storage con JWT de cliente → 4xx (llegó ${directoRes.status})`,
  );

  // --- 11. Matriz de lectura firmada (misma regla que la proyección T-024) ---
  const lecturaEmpresa = await signAndDownload(avatarPath, empresaVerificada.token, 120);
  ok(
    lecturaEmpresa.getStatus === 200,
    `empresa verificada (empresa3) firma y descarga el avatar → 200 (sign ${lecturaEmpresa.signStatus}, GET ${lecturaEmpresa.getStatus})`,
  );
  const lecturaPendiente = await signAndDownload(avatarPath, empresaPendiente.token, 120);
  ok(
    lecturaPendiente.getStatus !== 200,
    `empresa pendiente (empresa7) NO puede leer (sign ${lecturaPendiente.signStatus}, GET ${lecturaPendiente.getStatus})`,
  );
  const lecturaCandidato2 = await signAndDownload(avatarPath, otroCandidato.token, 120);
  ok(
    lecturaCandidato2.getStatus !== 200,
    `otro candidato (candidato2) NO puede leer (sign ${lecturaCandidato2.signStatus}, GET ${lecturaCandidato2.getStatus})`,
  );
  const lecturaAnon = await signAndDownload(avatarPath, null, 120);
  ok(
    lecturaAnon.getStatus !== 200,
    `sin Authorization (anon) NO puede leer (sign ${lecturaAnon.signStatus}, GET ${lecturaAnon.getStatus})`,
  );

  // --- 12. DELETE vía función: borra, limpia avatar_url y es idempotente ---
  const deleteRes = await http('/functions/v1/avatar', {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${sujeto.token}`, apikey: ANON_KEY },
  });
  ok(deleteRes.status === 200, `DELETE del avatar → 200 (llegó ${deleteRes.status})`);
  const avatarUrlPostDelete = await fetchAvatarUrl(sujeto.token, sujeto.userId);
  ok(avatarUrlPostDelete === null, `profiles.avatar_url volvió a null (llegó ${JSON.stringify(avatarUrlPostDelete)})`);
  const firmaPostDelete = await signAndDownload(avatarPath, sujeto.token, 120);
  ok(
    firmaPostDelete.getStatus !== 200,
    `firmar el objeto borrado falla (sign ${firmaPostDelete.signStatus}, GET ${firmaPostDelete.getStatus})`,
  );
  const deleteOtraVez = await http('/functions/v1/avatar', {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${sujeto.token}`, apikey: ANON_KEY },
  });
  ok(deleteOtraVez.status === 200, `DELETE repetido sigue siendo 200: idempotente (llegó ${deleteOtraVez.status})`);

  // --- Resumen ---
  console.log(`1..${testNumber}`);
  if (failures > 0) {
    console.error(`\n[storage:test] ${failures} de ${testNumber} aserciones fallaron.`);
    process.exit(1);
  }
  console.log(`\n[storage:test] ${testNumber} aserciones aprobadas.`);
}

// Watchdog global: si algo se cuelga más allá de los timeouts por request,
// cortamos con error en vez de dejar el CI clavado.
const watchdog = setTimeout(() => {
  console.error(`[storage:test] timeout global de ${GLOBAL_TIMEOUT_MS} ms superado.`);
  process.exit(1);
}, GLOBAL_TIMEOUT_MS);

try {
  await main();
} catch (error) {
  console.error('[storage:test] error inesperado:', error);
  process.exit(1);
} finally {
  clearTimeout(watchdog);
}
