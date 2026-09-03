// Guard del grafo offline de la Edge Function `avatar`.
//
// La rama fix/edge-runtime-local-dependencies estableció una invariante: la
// función no descarga NADA al arrancar. Todas sus dependencias están
// vendorizadas en supabase/functions/avatar/deps/ y el import map
// supabase/functions/avatar/deno.json las resuelve a archivos locales.
//
// Nada protegía esa invariante de una regresión: `deno test supabase/functions/avatar`
// solo corre los tests de lib/ y nunca carga index.ts, y el runner de GitHub
// tiene internet, así que un import remoto reintroducido resolvería bien y CI
// seguiría en verde. Este guard cierra esa brecha.
//
// Uso:
//   node scripts/edge-offline-guard.mjs
//
// Qué hace, en orden:
//   1. Exige que exista el import map.
//   2. Pide a Deno el grafo REALMENTE resuelto (`deno info --json`), no un grep
//      sobre el texto: un import indirecto, un re-export o una resolución vía
//      import map aparecen igual en el grafo.
//   3. Rechaza cualquier módulo cuyo especificador no sea `file:` — eso cubre
//      http:, https:, npm:, jsr: y node:.
//   4. Exige que cada archivo resuelto viva dentro del repositorio y dentro de
//      las rutas esperadas de la función.
//   5. Type-checkea index.ts con su configuración.
//   6. Verifica los archivos vendorizados contra el manifest (sync.mjs --check).
//
// Por qué no alcanza con las banderas de Deno (medido en deno 2.9.6):
//   - `--no-remote` NO frena `npm:`: `deno info` bajaba de registry.npmjs.org.
//   - `--cached-only` NO se aplica en `deno check`: con un DENO_DIR vacío bajó
//     48 archivos de esm.sh y salió 0.
//   - `node:` no produce error ni con `--no-remote` ni con `--cached-only`, y
//     `deno check` sale 0. Es justamente el especificador que hace que el edge
//     runtime inyecte `npm:@types/node` y lo baje del registro en cada arranque
//     frío (ver supabase/functions/avatar/deps/README.md).
//   Por eso la inspección del grafo es el control primario y las banderas son
//   defensa en profundidad.
//
// Garantía de cero descargas: cada invocación de Deno usa un DENO_DIR temporal
// y vacío (así una caché previa no puede hacer pasar una dependencia remota) y
// se le pasan `--no-remote` y `--no-npm`. Además se inspecciona la salida de
// Deno en busca de líneas `Download`: si hubo una sola, el guard falla.
//
// Pruebas (sin red): node --test scripts/edge-offline-guard.spec.mjs
import { spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync, statSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, isAbsolute, join, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import process from "node:process";

const here = dirname(fileURLToPath(import.meta.url));

/** Raíz del repositorio (este script vive en scripts/). */
export const REPO_ROOT = resolve(here, "..");

/** Único esquema de especificador admitido en el grafo. */
export const ALLOWED_SCHEME = "file";

/**
 * Esquemas prohibidos que se nombran explícitamente en los mensajes de error.
 * La regla real es una lista blanca (`file:`), no esta lista: cualquier otro
 * esquema también se rechaza.
 */
export const PROHIBITED_SCHEMES = ["http", "https", "npm", "jsr", "node"];

/** Configuración por defecto: la Edge Function `avatar`. */
export const DEFAULT_TARGET = {
  entry: "supabase/functions/avatar/index.ts",
  importMap: "supabase/functions/avatar/deno.json",
  depsDir: "supabase/functions/avatar/deps",
  syncScript: "supabase/functions/avatar/deps/sync.mjs",
  allowedDirs: ["supabase/functions/avatar"],
};

const ANSI = /\[[0-9;]*m/g;
const stripAnsi = (s) => String(s ?? "").replace(ANSI, "");

/** Deno imprime `Download <url>` por cada descarga. Una sola invalida la corrida. */
export function extractDownloads(output) {
  return stripAnsi(output)
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l.startsWith("Download "))
    .map((l) => l.slice("Download ".length).trim());
}

/** Crea un DENO_DIR temporal y vacío. Devuelve su ruta. */
function freshDenoDir() {
  return mkdtempSync(join(tmpdir(), "edge-guard-denodir-"));
}

/**
 * Ejecuta deno con un DENO_DIR temporal y vacío. El entorno heredado se limpia
 * de DENO_DIR a propósito: si el guard respetara una caché previa, una
 * dependencia remota ya cacheada podría pasar inadvertida.
 */
export function runDeno(args, { cwd = REPO_ROOT, denoBin = "deno" } = {}) {
  const denoDir = freshDenoDir();
  try {
    const env = { ...process.env, DENO_DIR: denoDir, DENO_NO_UPDATE_CHECK: "1" };
    const result = spawnSync(denoBin, args, {
      cwd,
      env,
      encoding: "utf8",
      shell: false,
      maxBuffer: 64 * 1024 * 1024,
    });
    const stdout = result.stdout ?? "";
    const stderr = result.stderr ?? "";
    return {
      status: result.status,
      stdout,
      stderr,
      denoDir,
      spawnError: result.error ? result.error.message : null,
      downloads: extractDownloads(`${stdout}\n${stderr}`),
    };
  } finally {
    rmSync(denoDir, { recursive: true, force: true });
  }
}

/** Clasifica el especificador de un módulo del grafo. */
export function classifySpecifier(specifier) {
  const match = /^([a-zA-Z][a-zA-Z0-9+.-]*):/.exec(specifier);
  const scheme = match ? match[1].toLowerCase() : null;
  return { scheme, allowed: scheme === ALLOWED_SCHEME };
}

/**
 * Verifica que una ruta local caiga dentro del repositorio y dentro de alguno
 * de los directorios esperados. Devuelve null si está bien, o el motivo.
 */
export function validateLocalPath(localPath, { repoRoot, allowedDirs }) {
  if (!localPath) return "el módulo no resolvió a ningún archivo local";
  const abs = resolve(localPath);
  const rel = relative(repoRoot, abs);
  if (rel === "" || rel.startsWith("..") || isAbsolute(rel)) {
    return "la ruta escapa del repositorio";
  }
  const relPosix = rel.split(sep).join("/");
  const dentro = allowedDirs.some((d) => relPosix === d || relPosix.startsWith(`${d}/`));
  if (!dentro) {
    return `la ruta queda fuera de las rutas esperadas (${allowedDirs.join(", ")})`;
  }
  if (!existsSync(abs) || !statSync(abs).isFile()) {
    return "la ruta no existe o no es un archivo regular";
  }
  return null;
}

/**
 * Analiza el grafo resuelto por Deno. Devuelve { ok, problems, moduleCount }.
 * `problems` es una lista de { kind, specifier, detail } lista para imprimir.
 */
export function analyzeGraph(graph, { repoRoot, allowedDirs, entryAbs }) {
  const problems = [];

  if (!graph || !Array.isArray(graph.modules)) {
    return { ok: false, moduleCount: 0, problems: [{ kind: "GRAFO", specifier: "-", detail: "deno info no devolvió una lista de módulos" }] };
  }
  if (graph.modules.length === 0) {
    problems.push({ kind: "GRAFO", specifier: "-", detail: "el grafo está vacío" });
  }

  const roots = Array.isArray(graph.roots) ? graph.roots : [];
  if (entryAbs) {
    const esperado = new URL(`file://${entryAbs.split(sep).join("/").replace(/^([A-Za-z]:)/, "/$1")}`).href;
    const coincide = roots.some((r) => decodeURIComponent(r).toLowerCase() === decodeURIComponent(esperado).toLowerCase());
    if (!coincide) {
      problems.push({ kind: "RAIZ", specifier: roots.join(", ") || "(ninguna)", detail: `la raíz del grafo no es el entry esperado (${esperado})` });
    }
  }

  for (const mod of graph.modules) {
    const spec = mod.specifier ?? "(sin especificador)";
    const { scheme, allowed } = classifySpecifier(spec);

    if (!allowed) {
      const nombrado = PROHIBITED_SCHEMES.includes(scheme) ? `esquema prohibido \`${scheme}:\`` : `esquema no admitido \`${scheme ?? "?"}:\``;
      problems.push({ kind: "REMOTO", specifier: spec, detail: `${nombrado}; solo se admiten módulos \`file:\`` });
      continue;
    }

    if (mod.error) {
      problems.push({ kind: "ERROR", specifier: spec, detail: String(mod.error).split(/\r?\n/)[0].slice(0, 200) });
      continue;
    }

    const motivo = validateLocalPath(mod.local, { repoRoot, allowedDirs });
    if (motivo) {
      problems.push({ kind: "RUTA", specifier: spec, detail: motivo });
    }
  }

  const npm = graph.npmPackages ? Object.keys(graph.npmPackages) : [];
  for (const p of npm) {
    problems.push({ kind: "NPM", specifier: p, detail: "el grafo arrastra un paquete npm" });
  }

  const redirects = graph.redirects ? Object.entries(graph.redirects) : [];
  for (const [from, to] of redirects) {
    problems.push({ kind: "REDIRECCION", specifier: from, detail: `el grafo redirige a ${to}` });
  }

  return { ok: problems.length === 0, moduleCount: graph.modules.length, problems };
}

/**
 * Corre el guard completo. Devuelve { ok, problems, moduleCount, downloads, steps }.
 * No imprime nada: la CLI se encarga de eso.
 */
export function guard({
  repoRoot = REPO_ROOT,
  entry = DEFAULT_TARGET.entry,
  importMap = DEFAULT_TARGET.importMap,
  depsDir = DEFAULT_TARGET.depsDir,
  syncScript = DEFAULT_TARGET.syncScript,
  allowedDirs = DEFAULT_TARGET.allowedDirs,
  denoBin = "deno",
  nodeBin = process.execPath,
  skipSync = false,
} = {}) {
  const problems = [];
  const downloads = [];
  const steps = [];
  const entryAbs = resolve(repoRoot, entry);
  const importMapAbs = resolve(repoRoot, importMap);

  // --- 1. El import map tiene que existir ------------------------------------
  if (!existsSync(importMapAbs) || !statSync(importMapAbs).isFile()) {
    problems.push({ kind: "IMPORTMAP", specifier: importMap, detail: "falta el import map de la función" });
    return { ok: false, problems, moduleCount: 0, downloads, steps };
  }
  try {
    const parsed = JSON.parse(readFileSync(importMapAbs, "utf8"));
    if (!parsed || typeof parsed.imports !== "object" || parsed.imports === null) {
      problems.push({ kind: "IMPORTMAP", specifier: importMap, detail: "el import map no declara un objeto `imports`" });
      return { ok: false, problems, moduleCount: 0, downloads, steps };
    }
  } catch (error) {
    problems.push({ kind: "IMPORTMAP", specifier: importMap, detail: `import map ilegible: ${error.message}` });
    return { ok: false, problems, moduleCount: 0, downloads, steps };
  }
  if (!existsSync(entryAbs)) {
    problems.push({ kind: "ENTRY", specifier: entry, detail: "no existe el módulo de entrada" });
    return { ok: false, problems, moduleCount: 0, downloads, steps };
  }

  // --- 2. Grafo realmente resuelto por Deno ----------------------------------
  const infoArgs = ["info", "--json", "--no-remote", "--no-npm", "--no-lock", "--config", importMap, entry];
  const info = runDeno(infoArgs, { cwd: repoRoot, denoBin });
  steps.push({ name: "deno info", args: infoArgs, status: info.status });
  downloads.push(...info.downloads);

  if (info.spawnError) {
    problems.push({ kind: "DENO", specifier: denoBin, detail: `no se pudo ejecutar deno: ${info.spawnError}` });
    return { ok: false, problems, moduleCount: 0, downloads, steps };
  }

  let graph = null;
  try {
    graph = JSON.parse(info.stdout);
  } catch {
    problems.push({
      kind: "DENO",
      specifier: "deno info --json",
      detail: `salida no parseable (status ${info.status}): ${stripAnsi(info.stderr).split(/\r?\n/)[0].slice(0, 200)}`,
    });
    return { ok: false, problems, moduleCount: 0, downloads, steps };
  }

  const analisis = analyzeGraph(graph, { repoRoot, allowedDirs, entryAbs });
  problems.push(...analisis.problems);

  // --- 3. Type-check con la configuración de la función ----------------------
  // `--cached-only` es el mecanismo oficial de Deno para exigir que lo remoto ya
  // esté cacheado; se usa junto con el DENO_DIR vacío. Medido en 2.9.6 no basta
  // por sí solo (ver cabecera), de ahí que el control primario sea el grafo.
  const checkArgs = ["check", "--cached-only", "--no-remote", "--no-npm", "--no-lock", "--config", importMap, entry];
  const check = runDeno(checkArgs, { cwd: repoRoot, denoBin });
  steps.push({ name: "deno check", args: checkArgs, status: check.status });
  downloads.push(...check.downloads);
  if (check.status !== 0) {
    const linea = stripAnsi(`${check.stderr}\n${check.stdout}`)
      .split(/\r?\n/)
      .find((l) => /error/i.test(l)) ?? `status ${check.status}`;
    problems.push({ kind: "TYPECHECK", specifier: entry, detail: linea.trim().slice(0, 200) });
  }

  // --- 4. Integridad de lo vendorizado --------------------------------------
  if (!skipSync) {
    const syncAbs = resolve(repoRoot, syncScript);
    if (!existsSync(syncAbs)) {
      problems.push({ kind: "MANIFEST", specifier: syncScript, detail: "falta el verificador sync.mjs" });
    } else {
      const sync = spawnSync(nodeBin, [syncAbs, "--check"], { cwd: repoRoot, encoding: "utf8", shell: false });
      steps.push({ name: "sync.mjs --check", args: [syncScript, "--check"], status: sync.status });
      if (sync.status !== 0) {
        const salida = stripAnsi(`${sync.stdout ?? ""}\n${sync.stderr ?? ""}`).trim().split(/\r?\n/).filter(Boolean);
        for (const l of salida.slice(0, 10)) {
          problems.push({ kind: "MANIFEST", specifier: depsDir, detail: l.slice(0, 200) });
        }
        if (salida.length === 0) {
          problems.push({ kind: "MANIFEST", specifier: depsDir, detail: `sync.mjs --check falló con status ${sync.status}` });
        }
      }
    }
  }

  // --- 5. Cero descargas -----------------------------------------------------
  for (const url of downloads) {
    problems.push({ kind: "DESCARGA", specifier: url, detail: "Deno descargó algo: el grafo no es totalmente local" });
  }

  return { ok: problems.length === 0, problems, moduleCount: analisis.moduleCount, downloads, steps };
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

function main() {
  const result = guard();
  for (const p of result.problems) {
    console.error(`${p.kind.padEnd(12)} ${p.specifier}\n${" ".repeat(13)}${p.detail}`);
  }
  if (result.ok) {
    console.log(
      `${result.moduleCount} módulos del grafo de la Edge Function \`avatar\` resuelven a archivos locales; ` +
        `sin especificadores ${PROHIBITED_SCHEMES.map((s) => `${s}:`).join(" / ")} y sin descargas.`,
    );
    return 0;
  }
  console.error(`\n${result.problems.length} problema(s): el grafo de la Edge Function ya no es offline.`);
  return 1;
}

const invokedDirectly =
  process.argv[1] && resolve(process.argv[1]).toLowerCase() === fileURLToPath(import.meta.url).toLowerCase();

if (invokedDirectly) {
  process.exit(main());
}
