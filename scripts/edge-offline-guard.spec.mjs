// Pruebas del guard del grafo offline. No usan red.
//
// Cada caso arma un repositorio de mentira en un directorio temporal, con su
// entry y su import map, y le pide al guard que lo analice. Como el guard
// invoca a Deno con `--no-remote --no-npm` y con un DENO_DIR temporal y vacío,
// los fixtures con dependencias remotas se rechazan sin descargar nada: eso se
// comprueba explícitamente en cada caso negativo.
//
// Correr: node --test scripts/edge-offline-guard.spec.mjs
import { test, describe, before, after } from "node:test";
import assert from "node:assert/strict";
import { cpSync, existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import process from "node:process";

import {
  analyzeGraph,
  classifyCheckFailure,
  classifySpecifier,
  extractDownloads,
  guard,
  runDeno,
  validateLocalPath,
  REPO_ROOT,
} from "./edge-offline-guard.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const SYNC_REAL = resolve(REPO_ROOT, "supabase/functions/avatar/deps/sync.mjs");

const temporales = [];
function nuevoTemp(prefijo = "edge-guard-fx-") {
  const d = mkdtempSync(join(tmpdir(), prefijo));
  temporales.push(d);
  return d;
}

after(() => {
  for (const d of temporales) rmSync(d, { recursive: true, force: true });
});

/**
 * Arma un repositorio de mentira con la misma forma que el real:
 *   <raiz>/supabase/functions/avatar/{index.ts,deno.json}
 * `imports` es el contenido del import map; `extra` son archivos adicionales
 * (rutas relativas a la raíz) para armar imports locales.
 */
function armarRepo({ entry, imports = {}, extra = {}, raiz = nuevoTemp() } = {}) {
  const dirFn = join(raiz, "supabase", "functions", "avatar");
  mkdirSync(dirFn, { recursive: true });
  writeFileSync(join(dirFn, "index.ts"), entry, "utf8");
  writeFileSync(join(dirFn, "deno.json"), `${JSON.stringify({ imports }, null, 2)}\n`, "utf8");
  for (const [rel, contenido] of Object.entries(extra)) {
    const destino = join(raiz, ...rel.split("/"));
    mkdirSync(dirname(destino), { recursive: true });
    writeFileSync(destino, contenido, "utf8");
  }
  return raiz;
}

const correr = (raiz, opciones = {}) =>
  guard({
    repoRoot: raiz,
    entry: "supabase/functions/avatar/index.ts",
    importMap: "supabase/functions/avatar/deno.json",
    allowedDirs: ["supabase/functions/avatar"],
    skipSync: true,
    ...opciones,
  });

const tiposDe = (r) => [...new Set(r.problems.map((p) => p.kind))];
const detalles = (r) => r.problems.map((p) => `${p.kind} ${p.specifier} ${p.detail}`).join("\n");

// ---------------------------------------------------------------------------

describe("grafo local válido", () => {
  test("un grafo enteramente local pasa y no descarga nada", () => {
    const raiz = armarRepo({
      entry: `import { saludo } from "./lib/saludo.ts";\nexport const x: string = saludo;\n`,
      extra: { "supabase/functions/avatar/lib/saludo.ts": `export const saludo: string = "hola";\n` },
    });
    const r = correr(raiz);
    assert.equal(r.ok, true, detalles(r));
    assert.deepEqual(r.downloads, []);
    assert.ok(r.moduleCount >= 2, `esperaba al menos 2 módulos, hubo ${r.moduleCount}`);
  });

  test("el guard corre limpio contra la Edge Function real del repositorio", () => {
    const r = guard();
    assert.equal(r.ok, true, detalles(r));
    assert.deepEqual(r.downloads, []);
    assert.ok(r.moduleCount > 30, `el grafo real debería tener decenas de módulos, hubo ${r.moduleCount}`);
  });
});

describe("especificadores prohibidos", () => {
  const casos = [
    ["HTTPS", `import { x } from "https://esm.sh/@supabase/supabase-js@2.49.4";\nexport const y = x;\n`, "https"],
    ["HTTP", `import { x } from "http://example.invalid/mod.ts";\nexport const y = x;\n`, "http"],
    ["npm", `import ws from "npm:ws@8.21.3";\nexport const y = ws;\n`, "npm"],
    ["node", `import { Buffer } from "node:buffer";\nexport const y = Buffer;\n`, "node"],
    ["jsr", `import { assert } from "jsr:@std/assert";\nexport const y = assert;\n`, "jsr"],
  ];

  for (const [nombre, entry, esquema] of casos) {
    test(`${nombre}: se rechaza y no se descarga nada`, () => {
      const raiz = armarRepo({ entry });
      const r = correr(raiz);
      assert.equal(r.ok, false, `${nombre} debería ser rechazado`);
      assert.deepEqual(r.downloads, [], `${nombre} no debería disparar descargas`);
      const ofensores = r.problems.filter((p) => p.specifier.toLowerCase().startsWith(`${esquema}:`));
      assert.ok(ofensores.length > 0, `esperaba un problema sobre un especificador ${esquema}:\n${detalles(r)}`);
    });
  }

  test("node: se detecta por el grafo aunque deno check lo acepte", () => {
    // Es el caso que ninguna bandera de Deno ataja: --no-remote no lo toca y
    // `deno check` sale 0. Solo lo ve el grafo.
    const raiz = armarRepo({ entry: `import { Buffer } from "node:buffer";\nexport const y = Buffer;\n` });
    const r = correr(raiz);
    assert.equal(r.ok, false);
    const problema = r.problems.find((p) => p.specifier === "node:buffer");
    assert.ok(problema, detalles(r));
    assert.equal(problema.kind, "REMOTO");
    assert.ok(!r.problems.some((p) => p.kind === "TYPECHECK"), "deno check no debería ser el que lo detecta");
  });
});

describe("rutas", () => {
  test("un módulo que escapa del repositorio se rechaza", () => {
    // El repositorio de mentira vive en <workspace>/repo; el módulo ajeno queda
    // en <workspace>, un nivel por encima de la raíz. Desde
    // repo/supabase/functions/avatar/index.ts eso es ../../../../ajeno.ts.
    const workspace = nuevoTemp("edge-guard-ws-");
    writeFileSync(join(workspace, "ajeno.ts"), `export const ajeno: string = "afuera";\n`, "utf8");
    const raiz = join(workspace, "repo");
    mkdirSync(raiz, { recursive: true });
    armarRepo({
      raiz,
      entry: `import { ajeno } from "../../../../ajeno.ts";\nexport const y: string = ajeno;\n`,
    });
    const r = correr(raiz);
    assert.equal(r.ok, false, "un import que escapa del repositorio debe fallar");
    const problema = r.problems.find((p) => p.kind === "RUTA");
    assert.ok(problema, detalles(r));
    assert.match(problema.detail, /escapa del repositorio/);
    assert.deepEqual(r.downloads, []);
  });

  test("un módulo dentro del repositorio pero fuera de las rutas esperadas se rechaza", () => {
    const raiz = armarRepo({
      entry: `import { otro } from "../../../otro/mod.ts";\nexport const y: string = otro;\n`,
      extra: { "otro/mod.ts": `export const otro: string = "no es de la función";\n` },
    });
    const r = correr(raiz);
    assert.equal(r.ok, false);
    const problema = r.problems.find((p) => p.kind === "RUTA");
    assert.ok(problema, detalles(r));
    assert.match(problema.detail, /fuera de las rutas esperadas/);
  });

  test("validateLocalPath rechaza escapes y acepta lo esperado", () => {
    const opciones = { repoRoot: REPO_ROOT, allowedDirs: ["supabase/functions/avatar"] };
    assert.match(
      validateLocalPath(resolve(REPO_ROOT, "..", "ajeno.ts"), opciones) ?? "",
      /escapa del repositorio/,
    );
    assert.match(
      validateLocalPath(resolve(REPO_ROOT, "supabase/config.toml"), opciones) ?? "",
      /fuera de las rutas esperadas/,
    );
    assert.equal(validateLocalPath(resolve(REPO_ROOT, "supabase/functions/avatar/index.ts"), opciones), null);
    assert.match(validateLocalPath(null, opciones) ?? "", /no resolvió/);
  });
});

describe("import map", () => {
  test("si falta el import map, el guard falla antes de invocar a Deno", () => {
    const raiz = armarRepo({ entry: `export const y = 1;\n` });
    rmSync(join(raiz, "supabase", "functions", "avatar", "deno.json"));
    const r = correr(raiz);
    assert.equal(r.ok, false);
    assert.deepEqual(tiposDe(r), ["IMPORTMAP"]);
    assert.equal(r.steps.length, 0, "no debería haber llegado a ejecutar Deno");
  });

  test("un import map sin `imports` se rechaza", () => {
    const raiz = armarRepo({ entry: `export const y = 1;\n` });
    writeFileSync(join(raiz, "supabase", "functions", "avatar", "deno.json"), `{"nada":true}\n`, "utf8");
    const r = correr(raiz);
    assert.equal(r.ok, false);
    assert.deepEqual(tiposDe(r), ["IMPORTMAP"]);
  });
});

describe("type-check", () => {
  test("un error de tipos en index.ts hace fallar el guard", () => {
    const raiz = armarRepo({ entry: `const n: number = "esto no es un número";\nexport const y = n;\n` });
    const r = correr(raiz);
    assert.equal(r.ok, false);
    assert.ok(r.problems.some((p) => p.kind === "TYPECHECK"), detalles(r));
  });
});

describe("manifest de dependencias vendorizadas", () => {
  /** Arma un deps/ mínimo con el sync.mjs real y un único archivo declarado. */
  function armarDeps(raiz, { contenido = "export const a = 1;\n", romper = null } = {}) {
    const deps = join(raiz, "supabase", "functions", "avatar", "deps");
    const destino = join(deps, "esm.sh", "demo@1.0.0", "demo.mjs");
    mkdirSync(dirname(destino), { recursive: true });
    writeFileSync(destino, contenido, "utf8");
    cpSync(SYNC_REAL, join(deps, "sync.mjs"));
    const bytes = Buffer.from(contenido, "utf8");
    const manifest = {
      note: "fixture de prueba",
      files: [
        {
          path: "esm.sh/demo@1.0.0/demo.mjs",
          url: "https://esm.sh/demo@1.0.0/demo.mjs",
          sha256: createHash("sha256").update(bytes).digest("hex"),
          bytes: bytes.length,
          package: "demo",
          version: "1.0.0",
          license: "MIT",
        },
      ],
    };
    if (romper === "hash") manifest.files[0].sha256 = "0".repeat(64);
    if (romper === "incompleto") delete manifest.files[0].license;
    if (romper === "faltante") rmSync(destino);
    writeFileSync(join(deps, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`, "utf8");
    return deps;
  }

  const opcionesSync = {
    skipSync: false,
    depsDir: "supabase/functions/avatar/deps",
    syncScript: "supabase/functions/avatar/deps/sync.mjs",
  };

  test("un manifest íntegro no agrega problemas", () => {
    const raiz = armarRepo({ entry: `export const y = 1;\n` });
    armarDeps(raiz);
    const r = correr(raiz, opcionesSync);
    assert.ok(!r.problems.some((p) => p.kind === "MANIFEST"), detalles(r));
  });

  test("un archivo vendorizado alterado se rechaza", () => {
    const raiz = armarRepo({ entry: `export const y = 1;\n` });
    armarDeps(raiz, { romper: "hash" });
    const r = correr(raiz, opcionesSync);
    assert.equal(r.ok, false);
    assert.ok(r.problems.some((p) => p.kind === "MANIFEST"), detalles(r));
  });

  test("un archivo declarado que falta se rechaza", () => {
    const raiz = armarRepo({ entry: `export const y = 1;\n` });
    armarDeps(raiz, { romper: "faltante" });
    const r = correr(raiz, opcionesSync);
    assert.equal(r.ok, false);
    assert.ok(r.problems.some((p) => p.kind === "MANIFEST"), detalles(r));
  });

  test("un manifest incompleto (sin licencia) se rechaza", () => {
    const raiz = armarRepo({ entry: `export const y = 1;\n` });
    armarDeps(raiz, { romper: "incompleto" });
    const r = correr(raiz, opcionesSync);
    assert.equal(r.ok, false);
    assert.ok(r.problems.some((p) => p.kind === "MANIFEST"), detalles(r));
  });

  test("si falta sync.mjs se rechaza", () => {
    const raiz = armarRepo({ entry: `export const y = 1;\n` });
    const deps = armarDeps(raiz);
    rmSync(join(deps, "sync.mjs"));
    const r = correr(raiz, opcionesSync);
    assert.equal(r.ok, false);
    assert.ok(r.problems.some((p) => p.kind === "MANIFEST" && /sync\.mjs/.test(p.detail)), detalles(r));
  });
});

describe("una caché previa no puede ocultar una dependencia remota", () => {
  test("runDeno ignora el DENO_DIR del entorno y usa uno temporal y vacío", () => {
    const envenenado = nuevoTemp("edge-guard-cache-envenenada-");
    writeFileSync(join(envenenado, "marca.txt"), "caché previa", "utf8");
    const previo = process.env.DENO_DIR;
    process.env.DENO_DIR = envenenado;
    try {
      const r = runDeno(["--version"]);
      assert.notEqual(r.denoDir, envenenado, "el guard no debe reutilizar el DENO_DIR del entorno");
      assert.ok(r.denoDir.includes("edge-guard-denodir-"), `DENO_DIR inesperado: ${r.denoDir}`);
    } finally {
      if (previo === undefined) delete process.env.DENO_DIR;
      else process.env.DENO_DIR = previo;
    }
  });

  test("con un DENO_DIR poblado en el entorno, un import remoto se sigue rechazando", () => {
    const envenenado = nuevoTemp("edge-guard-cache-envenenada2-");
    mkdirSync(join(envenenado, "remote"), { recursive: true });
    writeFileSync(join(envenenado, "remote", "loquesea"), "contenido", "utf8");
    const raiz = armarRepo({
      entry: `import { x } from "https://esm.sh/@supabase/supabase-js@2.49.4";\nexport const y = x;\n`,
    });
    const previo = process.env.DENO_DIR;
    process.env.DENO_DIR = envenenado;
    try {
      const r = correr(raiz);
      assert.equal(r.ok, false, "la caché del entorno no debe poder ocultar el import remoto");
      assert.deepEqual(r.downloads, []);
      assert.ok(r.problems.some((p) => p.specifier.startsWith("https:")), detalles(r));
    } finally {
      if (previo === undefined) delete process.env.DENO_DIR;
      else process.env.DENO_DIR = previo;
    }
  });

  test("el DENO_DIR temporal se borra al terminar", () => {
    const r = runDeno(["--version"]);
    assert.equal(existsSync(r.denoDir), false, "el DENO_DIR temporal debería quedar borrado");
  });
});

describe("unidades auxiliares", () => {
  test("classifySpecifier reconoce cada esquema", () => {
    assert.deepEqual(classifySpecifier("file:///a/b.ts"), { scheme: "file", allowed: true });
    for (const s of ["http", "https", "npm", "jsr", "node"]) {
      assert.deepEqual(classifySpecifier(`${s}:algo`), { scheme: s, allowed: false });
    }
    assert.deepEqual(classifySpecifier("sin-esquema"), { scheme: null, allowed: false });
  });

  test("extractDownloads encuentra las líneas de descarga aunque tengan color", () => {
    const salida = "\u001b[0m\u001b[32mDownload\u001b[0m https://registry.npmjs.org/ws\nCheck algo\n  Download https://esm.sh/x\n";
    assert.deepEqual(extractDownloads(salida), ["https://registry.npmjs.org/ws", "https://esm.sh/x"]);
    assert.deepEqual(extractDownloads(""), []);
  });

  test("analyzeGraph marca npmPackages y redirecciones", () => {
    const base = { roots: [], modules: [], npmPackages: { "ws@8.21.3": {} }, redirects: { "https://a": "https://b" } };
    const r = analyzeGraph(base, { repoRoot: REPO_ROOT, allowedDirs: ["supabase"], entryAbs: null });
    assert.equal(r.ok, false);
    assert.ok(r.problems.some((p) => p.kind === "NPM"));
    assert.ok(r.problems.some((p) => p.kind === "REDIRECCION"));
  });
});

// ---------------------------------------------------------------------------
// Regresiones del PR #2
// ---------------------------------------------------------------------------

describe("compatibilidad con la versión de Deno que fija CI", () => {
  test("el type-check del guard no pasa `--cached-only`", () => {
    const raiz = armarRepo({ entry: `export const y: number = 1;\n` });
    const r = correr(raiz);
    const paso = r.steps.find((s) => s.name === "deno check");
    assert.ok(paso, `no se ejecutó el paso de type-check:\n${detalles(r)}`);
    assert.ok(
      !paso.args.includes("--cached-only"),
      `deno check no debe recibir --cached-only (Deno 2.7.14 no la acepta): ${paso.args.join(" ")}`,
    );
    // Las banderas que sí sostienen la invariante offline siguen ahí.
    for (const bandera of ["--no-remote", "--no-npm", "--no-lock"]) {
      assert.ok(paso.args.includes(bandera), `falta ${bandera} en ${paso.args.join(" ")}`);
    }
    assert.equal(paso.status, 0, `el type-check debería salir 0 en esta versión de Deno:\n${detalles(r)}`);
    assert.equal(r.ok, true, detalles(r));
  });

  test("`deno check --cached-only` real se clasifica como fallo de invocación, no de tipos", () => {
    // Prueba contra el binario de verdad de la máquina. En Deno 2.7.14 la
    // bandera no existe y `deno check` sale 1 sin type-checkear nada: el guard
    // no debe reportar eso como un error de tipos de index.ts.
    const raiz = armarRepo({ entry: `export const y: number = 1;\n` });
    const args = [
      "check",
      "--cached-only",
      "--no-remote",
      "--no-npm",
      "--no-lock",
      "--config",
      "supabase/functions/avatar/deno.json",
      "supabase/functions/avatar/index.ts",
    ];
    const r = runDeno(args, { cwd: raiz });
    assert.equal(r.spawnError, null, `deno debería poder ejecutarse: ${r.spawnError}`);
    if (r.status === 0) {
      // Versión de Deno donde la bandera sí existe: entonces no hay nada que
      // clasificar, pero sigue valiendo que no descargó nada.
      assert.deepEqual(r.downloads, [], "ni siquiera con --cached-only debería descargar");
    } else {
      const c = classifyCheckFailure(`${r.stderr}\n${r.stdout}`, r.status);
      assert.equal(c.kind, "DENO", `esperaba un fallo de invocación:\n${r.stderr}`);
      assert.match(c.detail, /invocación o de versión de Deno/);
    }
  });

  test("si el binario de deno no existe, el guard lo dice y no culpa a los tipos", () => {
    const raiz = armarRepo({ entry: `export const y: number = 1;\n` });
    const r = correr(raiz, { denoBin: "deno-que-no-existe-en-esta-maquina" });
    assert.equal(r.ok, false);
    assert.ok(
      r.problems.some((p) => p.kind === "DENO"),
      `esperaba un problema DENO:\n${detalles(r)}`,
    );
    assert.ok(
      !r.problems.some((p) => p.kind === "TYPECHECK"),
      `un binario ausente no es un error de tipos:\n${detalles(r)}`,
    );
  });
});

describe("clasificación de fallos de `deno check`", () => {
  const SALIDA_TIPOS = [
    "Check file:///repo/supabase/functions/avatar/index.ts",
    "TS2322 [ERROR]: Type 'string' is not assignable to type 'number'.",
    'const n: number = "no";',
    "      ^",
    "    at file:///repo/supabase/functions/avatar/index.ts:1:7",
    "",
    "error: Type checking failed.",
  ].join("\n");

  // Copia literal de lo que imprime Deno 2.7.14 ante la bandera inexistente.
  const SALIDA_INVOCACION = [
    "error: unexpected argument '--cached-only' found",
    "",
    "  tip: a similar argument exists: '--doc-only'",
    "",
    "Usage: deno check --doc-only [file]...",
  ].join("\n");

  test("un error real de tipos se clasifica como TYPECHECK", () => {
    const c = classifyCheckFailure(SALIDA_TIPOS, 1);
    assert.equal(c.kind, "TYPECHECK");
    assert.match(c.detail, /TS2322/);
  });

  test("una bandera inexistente se clasifica como fallo de Deno", () => {
    const c = classifyCheckFailure(SALIDA_INVOCACION, 1);
    assert.equal(c.kind, "DENO");
    assert.match(c.detail, /invocación o de versión de Deno/);
    assert.match(c.detail, /--cached-only/);
    assert.ok(!/TS\d/.test(c.detail), `no debe insinuar un error de tipos: ${c.detail}`);
  });

  test("una salida vacía no se hace pasar por un error de tipos", () => {
    const c = classifyCheckFailure("", 127);
    assert.equal(c.kind, "DENO");
    assert.match(c.detail, /status 127/);
  });

  test("el color ANSI no cambia la clasificación", () => {
    const conColor =
      "\u001b[0m\u001b[32mCheck\u001b[0m f/index.ts\n" +
      "\u001b[0m\u001b[1mTS2322 \u001b[0m[ERROR]: Type 'string' is not assignable to type 'number'.\n" +
      "\u001b[0m\u001b[1m\u001b[31merror\u001b[0m: Type checking failed.";
    const c = classifyCheckFailure(conColor, 1);
    assert.equal(c.kind, "TYPECHECK");
    assert.match(c.detail, /TS2322/);
  });
});
