// Verifica o regenera las dependencias vendorizadas de la Edge Function `avatar`.
//
// El edge runtime local NO debe descargar nada de internet al arrancar ni al
// procesar imágenes (ver README.md de este directorio). Todo lo que la función
// importa desde esm.sh y deno.land vive acá, con su URL de origen y su SHA-256
// registrados en manifest.json.
//
// Uso (Node 22, sin dependencias npm):
//   node supabase/functions/avatar/deps/sync.mjs --check
//       Sin red. Recorre esm.sh/ y deno.land/ y exige que el conjunto real de
//       archivos sea EXACTAMENTE el del manifest: falla ante faltantes,
//       tamaños o hashes distintos, archivos inesperados, symlinks o tipos de
//       archivo no permitidos. Los archivos administrativos de este
//       directorio (manifest, README, LICENSES, .gitattributes, types/, este
//       script y sus pruebas) están fuera del alcance del manifest.
//   node supabase/functions/avatar/deps/sync.mjs --update
//       Descarga cada URL del manifest a un directorio temporal, la valida y
//       MUESTRA qué cambiaría. No toca ningún archivo. Sale con 3 si hay
//       cambios pendientes.
//   node supabase/functions/avatar/deps/sync.mjs --update --accept
//       Igual, pero al final reemplaza los archivos cambiados y reescribe el
//       manifest, solo si TODAS las descargas fueron válidas.
//   node supabase/functions/avatar/deps/sync.mjs --update --accept --allow-new
//       Además permite entradas del manifest que todavía no tienen archivo
//       local (incorporar una dependencia es una decisión explícita).
//
// Reglas de red (--update): solo HTTPS, sin credenciales embebidas, sin
// puerto explícito, únicamente los hosts de ALLOWED_HOSTS; las redirecciones
// no se siguen automáticamente: se procesan a mano, se registran origen y
// destino, y el destino tiene que pasar las mismas reglas, con un máximo de
// MAX_REDIRECTS saltos.
//
// Detrás de un antivirus o proxy que intercepta TLS, el host necesita su
// almacén de certificados: NODE_OPTIONS=--use-system-ca node ... --update
//
// Pruebas (sin red): node --test supabase/functions/avatar/deps/sync.spec.mjs
import { createHash } from "node:crypto";
import {
  lstatSync,
  mkdirSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  renameSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import process from "node:process";

/** Directorios de este directorio cuyo contenido administra el manifest. */
export const MANAGED_DIRS = ["esm.sh", "deno.land"];

/** Lista cerrada de hosts de origen, también válida como destino de redirección. */
export const ALLOWED_HOSTS = new Set(["esm.sh", "deno.land"]);

/** Saltos máximos de redirección que --update procesa a mano. */
export const MAX_REDIRECTS = 3;

// esm.sh elige la variante del build según el User-Agent: a un agente Deno le
// sirve módulos con imports `node:*`, y cualquier especificador `node:` en el
// grafo hace que el edge runtime inyecte `npm:@types/node` y lo descargue del
// registro al arrancar (ver README.md). Con un agente de navegador y
// `target=es2022` los bundles no traen ningún `node:`; se fija para que el
// resultado sea reproducible.
export const USER_AGENT =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Safari/537.36";

const REDIRECT_STATUSES = new Set([301, 302, 303, 307, 308]);
const SHA256_RE = /^[0-9a-f]{64}$/;

export const sha256 = (bytes) => createHash("sha256").update(bytes).digest("hex");

/** Oculta credenciales embebidas antes de mostrar una URL. */
export function redactUrl(raw) {
  return String(raw).replace(/\/\/[^/@]+@/, "//<credenciales>@");
}

/**
 * Valida una URL de origen o de redirección. Devuelve la URL parseada o lanza
 * un Error cuyo mensaje nunca incluye credenciales.
 */
export function validateUrl(raw) {
  let url;
  try {
    url = new URL(raw);
  } catch {
    throw new Error(`URL inválida: ${redactUrl(raw)}`);
  }
  if (url.protocol !== "https:") {
    throw new Error(`solo se admite HTTPS: ${redactUrl(raw)}`);
  }
  if (url.username !== "" || url.password !== "") {
    throw new Error(`credenciales embebidas no permitidas: ${redactUrl(raw)}`);
  }
  if (url.port !== "") {
    throw new Error(`puerto no autorizado (${url.port}): ${redactUrl(raw)}`);
  }
  if (!ALLOWED_HOSTS.has(url.hostname)) {
    throw new Error(`host no permitido (${url.hostname}): ${redactUrl(raw)}`);
  }
  return url;
}

/** Ruta relativa POSIX dentro de un directorio administrado, sin escapes. */
export function validatePath(path) {
  if (typeof path !== "string" || path.length === 0) {
    throw new Error("ruta vacía en el manifest");
  }
  if (path.includes("\\") || path.startsWith("/") || /^[A-Za-z]:/.test(path)) {
    throw new Error(`ruta no relativa o con separadores inválidos: ${path}`);
  }
  const segments = path.split("/");
  if (segments.some((s) => s === "" || s === "." || s === "..")) {
    throw new Error(`ruta con segmentos vacíos o de escape: ${path}`);
  }
  if (!MANAGED_DIRS.includes(segments[0]) || segments.length < 2) {
    throw new Error(`ruta fuera de los directorios administrados (${MANAGED_DIRS.join(", ")}): ${path}`);
  }
  return path;
}

/** Lee y valida manifest.json. Falla ante cualquier entrada malformada. */
export function loadManifest(rootDir) {
  const manifestPath = join(rootDir, "manifest.json");
  const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
  if (!manifest || !Array.isArray(manifest.files)) {
    throw new Error("manifest.json: falta la lista `files`");
  }
  const seen = new Set();
  for (const entry of manifest.files) {
    validatePath(entry.path);
    if (seen.has(entry.path)) throw new Error(`ruta duplicada en el manifest: ${entry.path}`);
    seen.add(entry.path);
    validateUrl(entry.url);
    if (typeof entry.sha256 !== "string" || !SHA256_RE.test(entry.sha256)) {
      throw new Error(`sha256 inválido para ${entry.path}`);
    }
    if (!Number.isInteger(entry.bytes) || entry.bytes < 0) {
      throw new Error(`tamaño inválido para ${entry.path}`);
    }
    for (const field of ["package", "version", "license"]) {
      if (typeof entry[field] !== "string" || entry[field].trim() === "") {
        throw new Error(`falta \`${field}\` para ${entry.path}`);
      }
    }
  }
  return manifest;
}

const localPath = (rootDir, path) => join(rootDir, ...path.split("/"));

/**
 * Recorre los directorios administrados sin seguir symlinks. Devuelve el
 * conjunto de archivos regulares (rutas POSIX relativas) y los problemas
 * estructurales encontrados (symlinks, tipos no permitidos).
 */
export function walkManaged(rootDir) {
  const files = new Set();
  const problems = [];
  const visit = (dirAbs, prefix) => {
    let entries;
    try {
      entries = readdirSync(dirAbs, { withFileTypes: true });
    } catch (error) {
      if (error.code === "ENOENT") return; // directorio ausente: sus entradas saldrán como FALTA
      throw error;
    }
    for (const dirent of entries) {
      const rel = `${prefix}/${dirent.name}`;
      if (dirent.isSymbolicLink()) {
        problems.push({ kind: "SYMLINK", path: rel, detail: "enlace simbólico no permitido" });
      } else if (dirent.isDirectory()) {
        visit(join(dirAbs, dirent.name), rel);
      } else if (dirent.isFile()) {
        files.add(rel);
      } else {
        problems.push({ kind: "TIPO", path: rel, detail: "no es un archivo regular" });
      }
    }
  };
  for (const dir of MANAGED_DIRS) visit(join(rootDir, dir), dir);
  return { files, problems };
}

/**
 * Verificación completa sin red: conjunto exacto de archivos, tamaños y
 * SHA-256. Devuelve { ok, matched, problems, total } con `problems` como
 * lista de { kind, path, detail } lista para imprimir (nunca contenido).
 */
export function check(rootDir) {
  const manifest = loadManifest(rootDir);
  const { files: actual, problems } = walkManaged(rootDir);
  const declared = new Set();
  let matched = 0;

  for (const entry of manifest.files) {
    declared.add(entry.path);
    if (!actual.has(entry.path)) {
      problems.push({ kind: "FALTA", path: entry.path, detail: "no existe o no es un archivo regular" });
      continue;
    }
    const bytes = readFileSync(localPath(rootDir, entry.path));
    if (bytes.length !== entry.bytes) {
      problems.push({
        kind: "TAMAÑO",
        path: entry.path,
        detail: `esperado ${entry.bytes} bytes, hay ${bytes.length}`,
      });
      continue;
    }
    const digest = sha256(bytes);
    if (digest !== entry.sha256) {
      problems.push({
        kind: "HASH",
        path: entry.path,
        detail: `esperado ${entry.sha256.slice(0, 16)}…, hay ${digest.slice(0, 16)}…`,
      });
      continue;
    }
    matched += 1;
  }

  for (const path of [...actual].sort()) {
    if (!declared.has(path)) {
      problems.push({ kind: "INESPERADO", path, detail: "no figura en manifest.json" });
    }
  }

  problems.sort((a, b) => a.path.localeCompare(b.path));
  return { ok: problems.length === 0, matched, total: manifest.files.length, problems };
}

/**
 * Descarga una URL procesando las redirecciones a mano: cada destino se
 * valida con las mismas reglas y se registra con `log`.
 */
export async function download(rawUrl, { fetchImpl = globalThis.fetch, log = console.log } = {}) {
  let current = validateUrl(rawUrl);
  for (let hop = 0; hop <= MAX_REDIRECTS; hop += 1) {
    const response = await fetchImpl(current.href, {
      headers: { "user-agent": USER_AGENT },
      redirect: "manual",
    });
    if (REDIRECT_STATUSES.has(response.status)) {
      const location = response.headers.get("location");
      if (!location) throw new Error(`${current.href}: redirección ${response.status} sin Location`);
      let next;
      try {
        next = validateUrl(new URL(location, current).href);
      } catch (error) {
        throw new Error(`redirección no autorizada desde ${current.href}: ${error.message}`);
      }
      log(`redirección ${current.href} -> ${next.href}`);
      current = next;
      continue;
    }
    if (!response.ok) throw new Error(`${current.href}: HTTP ${response.status}`);
    return { bytes: Buffer.from(await response.arrayBuffer()), finalUrl: current.href, hops: hop };
  }
  throw new Error(`más de ${MAX_REDIRECTS} redirecciones desde ${redactUrl(rawUrl)}`);
}

const writeAtomic = (target, data) => {
  mkdirSync(dirname(target), { recursive: true });
  const temp = `${target}.tmp-${process.pid}`;
  writeFileSync(temp, data);
  renameSync(temp, target);
};

/**
 * Descarga todas las entradas del manifest a un directorio temporal y calcula
 * qué cambiaría. Sin `accept` no escribe nada. Con `accept`, y solo si todas
 * las descargas fueron válidas, reemplaza los archivos cambiados y reescribe
 * el manifest. Las entradas sin archivo local se rechazan salvo `allowNew`.
 */
export async function update(
  rootDir,
  { fetchImpl = globalThis.fetch, accept = false, allowNew = false, log = console.log } = {},
) {
  const manifest = loadManifest(rootDir);

  const isRegularFile = (path) => {
    try {
      return lstatSync(localPath(rootDir, path)).isFile();
    } catch {
      return false;
    }
  };
  const missing = manifest.files.filter((entry) => !isRegularFile(entry.path)).map((e) => e.path);
  if (missing.length > 0 && !allowNew) {
    throw new Error(
      `el manifest declara dependencias sin archivo local (incorporarlas exige --allow-new): ${missing.join(", ")}`,
    );
  }

  const staging = mkdtempSync(join(tmpdir(), "avatar-deps-"));
  try {
    const downloaded = [];
    for (const [index, entry] of manifest.files.entries()) {
      const { bytes, finalUrl, hops } = await download(entry.url, { fetchImpl, log });
      const stagedFile = join(staging, `${index}.bin`);
      writeFileSync(stagedFile, bytes);
      downloaded.push({ entry, stagedFile, sha256: sha256(bytes), bytes: bytes.length, finalUrl, hops });
    }

    const changes = [];
    for (const item of downloaded) {
      const { entry } = item;
      const isNew = !isRegularFile(entry.path);
      if (isNew || item.sha256 !== entry.sha256 || item.bytes !== entry.bytes) {
        changes.push({
          path: entry.path,
          status: isNew ? "NUEVO" : "CAMBIA",
          from: isNew ? null : { sha256: entry.sha256, bytes: entry.bytes },
          to: { sha256: item.sha256, bytes: item.bytes },
          finalUrl: item.finalUrl,
        });
      }
    }

    if (!accept) {
      return { applied: false, changes, checked: downloaded.length };
    }

    for (const item of downloaded) {
      const change = changes.find((c) => c.path === item.entry.path);
      if (!change) continue;
      writeAtomic(localPath(rootDir, item.entry.path), readFileSync(item.stagedFile));
      item.entry.sha256 = item.sha256;
      item.entry.bytes = item.bytes;
    }
    if (changes.length > 0) {
      writeAtomic(join(rootDir, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`);
    }
    return { applied: true, changes, checked: downloaded.length };
  } finally {
    rmSync(staging, { recursive: true, force: true });
  }
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

function printCheck(result) {
  for (const p of result.problems) {
    console.log(`${p.kind.padEnd(10)} ${p.path}  (${p.detail})`);
  }
  if (result.ok) {
    console.log(`${result.matched} archivos coinciden con manifest.json y no hay archivos inesperados.`);
  } else {
    console.error(
      `${result.problems.length} problema(s): ${result.matched}/${result.total} archivos del manifest verificados.`,
    );
  }
}

function printChanges(result) {
  for (const c of result.changes) {
    const from = c.from ? `${c.from.sha256.slice(0, 12)}… (${c.from.bytes} bytes)` : "(sin archivo local)";
    console.log(`${c.status.padEnd(7)} ${c.path}: ${from} -> ${c.to.sha256.slice(0, 12)}… (${c.to.bytes} bytes)`);
  }
}

async function main(argv) {
  const [mode, ...rest] = argv;
  const flags = new Set(rest);
  const usage = "Uso: node sync.mjs --check | --update [--accept] [--allow-new]";
  if (mode === "--check" && rest.length === 0) {
    const result = check(here);
    printCheck(result);
    return result.ok ? 0 : 1;
  }
  if (mode === "--update" && [...flags].every((f) => f === "--accept" || f === "--allow-new")) {
    const result = await update(here, {
      accept: flags.has("--accept"),
      allowNew: flags.has("--allow-new"),
    });
    printChanges(result);
    if (result.applied) {
      console.log(`${result.checked} descargas válidas; ${result.changes.length} archivo(s) reemplazado(s).`);
      return 0;
    }
    if (result.changes.length === 0) {
      console.log(`${result.checked} descargas válidas; nada cambia respecto del manifest.`);
      return 0;
    }
    console.log(`${result.changes.length} cambio(s) pendiente(s). Nada se escribió: repetir con --accept para aplicarlos.`);
    return 3;
  }
  console.error(usage);
  return 2;
}

const here = dirname(fileURLToPath(import.meta.url));
const invokedDirectly = process.argv[1] &&
  resolve(process.argv[1]).toLowerCase() === fileURLToPath(import.meta.url).toLowerCase();

if (invokedDirectly) {
  main(process.argv.slice(2)).then(
    (code) => process.exit(code),
    (error) => {
      console.error(`error: ${error.message}`);
      process.exit(1);
    },
  );
}
