// Pruebas de sync.mjs, sin red: cada caso arma un directorio temporal con un
// manifest y archivos propios, y las descargas se simulan con un `fetch`
// inyectado. Se ejecutan con Node (node:test), no con Deno:
//   node --test supabase/functions/avatar/deps/sync.spec.mjs
// El nombre `.spec.mjs` es deliberado: `deno test supabase/functions/avatar`
// descubre `*_test.*` y `*.test.*`, y este archivo no debe correr en Deno.
import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, before, beforeEach, describe, it } from "node:test";

import { check, download, MAX_REDIRECTS, sha256, update, validateUrl } from "./sync.mjs";

// --- fixture -----------------------------------------------------------------

const FILES = {
  "esm.sh/pkg@1.0.0/es2022/pkg.mjs": "export const pkg = 1;\n",
  "deno.land/x/lib@1.0.0/mod.js": "export const lib = 2;\n",
  "deno.land/x/lib@1.0.0/utils/wasm/x.wasm": "\0asm\x01\0\0\0",
};

let scratch;
let root;

const entryFor = (path, content, extra = {}) => ({
  url: `https://${path}`,
  path,
  package: path.split("/").at(-1),
  version: "1.0.0",
  license: "MIT",
  sha256: sha256(Buffer.from(content, "latin1")),
  bytes: Buffer.byteLength(content, "latin1"),
  ...extra,
});

function writeManifest(files) {
  writeFileSync(join(root, "manifest.json"), `${JSON.stringify({ note: "fixture", files }, null, 2)}\n`);
}

function resetFixture() {
  rmSync(root, { recursive: true, force: true });
  mkdirSync(root, { recursive: true });
  for (const [path, content] of Object.entries(FILES)) {
    const abs = join(root, ...path.split("/"));
    mkdirSync(join(abs, ".."), { recursive: true });
    writeFileSync(abs, Buffer.from(content, "latin1"));
  }
  // Archivos administrativos fuera del alcance del manifest: deben ignorarse.
  writeFileSync(join(root, "README.md"), "# fixture\n");
  writeFileSync(join(root, ".gitattributes"), "esm.sh/** -text\n");
  mkdirSync(join(root, "types"), { recursive: true });
  writeFileSync(join(root, "types", "x.d.ts"), "export {};\n");
  writeManifest(Object.entries(FILES).map(([path, content]) => entryFor(path, content)));
}

const snapshot = () => {
  const out = {};
  for (const path of Object.keys(FILES)) out[path] = sha256(readFileSync(join(root, ...path.split("/"))));
  out["manifest.json"] = sha256(readFileSync(join(root, "manifest.json")));
  return out;
};

/** fetch falso: `routes` mapea URL -> { status, body, location }. */
const fakeFetch = (routes, calls = []) => async (url) => {
  calls.push(url);
  const route = routes[url];
  if (!route) return { status: 404, ok: false, headers: new Headers(), arrayBuffer: async () => new ArrayBuffer(0) };
  const body = Buffer.from(route.body ?? "", "latin1");
  return {
    status: route.status ?? 200,
    ok: (route.status ?? 200) >= 200 && (route.status ?? 200) < 300,
    headers: new Headers(route.location ? { location: route.location } : {}),
    arrayBuffer: async () => body.buffer.slice(body.byteOffset, body.byteOffset + body.byteLength),
  };
};

const okRoutes = () =>
  Object.fromEntries(Object.entries(FILES).map(([path, content]) => [`https://${path}`, { body: content }]));

before(() => {
  scratch = mkdtempSync(join(tmpdir(), "avatar-sync-spec-"));
  root = join(scratch, "deps");
});
after(() => rmSync(scratch, { recursive: true, force: true }));
beforeEach(resetFixture);

// --- --check -----------------------------------------------------------------

describe("check", () => {
  it("manifest correcto: todo coincide y los archivos administrativos se ignoran", () => {
    const result = check(root);
    assert.equal(result.ok, true);
    assert.equal(result.matched, 3);
    assert.deepEqual(result.problems, []);
  });

  it("archivo modificado con el mismo tamaño: HASH", () => {
    writeFileSync(join(root, "esm.sh/pkg@1.0.0/es2022/pkg.mjs"), "export const pkg = 9;\n");
    const result = check(root);
    assert.equal(result.ok, false);
    assert.deepEqual(result.problems.map((p) => [p.kind, p.path]), [["HASH", "esm.sh/pkg@1.0.0/es2022/pkg.mjs"]]);
  });

  it("archivo modificado con otro tamaño: TAMAÑO, sin imprimir contenido", () => {
    writeFileSync(join(root, "deno.land/x/lib@1.0.0/utils/wasm/x.wasm"), Buffer.from("\0asm\x01\0\0\0\xff", "latin1"));
    const result = check(root);
    assert.equal(result.ok, false);
    assert.equal(result.problems[0].kind, "TAMAÑO");
    assert.match(result.problems[0].detail, /esperado 8 bytes, hay 9/);
    assert.ok(!result.problems[0].detail.includes("asm"));
  });

  it("archivo faltante: FALTA", () => {
    rmSync(join(root, "deno.land/x/lib@1.0.0/mod.js"));
    const result = check(root);
    assert.equal(result.ok, false);
    assert.deepEqual(result.problems.map((p) => [p.kind, p.path]), [["FALTA", "deno.land/x/lib@1.0.0/mod.js"]]);
  });

  it("archivo inesperado dentro de un directorio administrado: INESPERADO", () => {
    writeFileSync(join(root, "esm.sh", "colado.mjs"), "export {};\n");
    mkdirSync(join(root, "deno.land", "x", "otro@2.0.0"), { recursive: true });
    writeFileSync(join(root, "deno.land", "x", "otro@2.0.0", "mod.js"), "export {};\n");
    const result = check(root);
    assert.equal(result.ok, false);
    assert.deepEqual(result.problems.map((p) => [p.kind, p.path]), [
      ["INESPERADO", "deno.land/x/otro@2.0.0/mod.js"],
      ["INESPERADO", "esm.sh/colado.mjs"],
    ]);
  });

  it("symlink dentro de un directorio administrado: SYMLINK, sin seguirlo", (t) => {
    const link = join(root, "esm.sh", "enlace.mjs");
    try {
      symlinkSync(join(root, "README.md"), link, "file");
    } catch (error) {
      t.skip(`este host no permite crear symlinks (${error.code})`);
      return;
    }
    const result = check(root);
    assert.equal(result.ok, false);
    assert.deepEqual(result.problems.map((p) => [p.kind, p.path]), [["SYMLINK", "esm.sh/enlace.mjs"]]);
  });

  it("manifest con URL http: se rechaza antes de tocar archivos", () => {
    const files = Object.entries(FILES).map(([path, content]) => entryFor(path, content));
    files[0].url = files[0].url.replace("https://", "http://");
    writeManifest(files);
    assert.throws(() => check(root), /solo se admite HTTPS/);
  });

  it("manifest con ruta fuera de los directorios administrados: se rechaza", () => {
    const files = Object.entries(FILES).map(([path, content]) => entryFor(path, content));
    files[0].path = "types/pkg.mjs";
    writeManifest(files);
    assert.throws(() => check(root), /fuera de los directorios administrados/);
  });
});

// --- validación de URLs --------------------------------------------------------

describe("validateUrl", () => {
  it("acepta los hosts permitidos por HTTPS sin puerto", () => {
    assert.equal(validateUrl("https://esm.sh/x@1.0.0/es2022/x.mjs").hostname, "esm.sh");
    assert.equal(validateUrl("https://deno.land/x/y@1.0.0/mod.ts").hostname, "deno.land");
  });
  it("rechaza HTTP", () => {
    assert.throws(() => validateUrl("http://esm.sh/x.mjs"), /solo se admite HTTPS/);
  });
  it("rechaza hosts fuera de la lista cerrada", () => {
    assert.throws(() => validateUrl("https://cdn.jsdelivr.net/npm/x"), /host no permitido \(cdn\.jsdelivr\.net\)/);
    assert.throws(() => validateUrl("https://evil.esm.sh/x.mjs"), /host no permitido/);
  });
  it("rechaza credenciales embebidas y no las muestra en el mensaje", () => {
    assert.throws(
      () => validateUrl("https://user:s3cret@esm.sh/x.mjs"),
      (error) => /credenciales embebidas/.test(error.message) && !error.message.includes("s3cret"),
    );
  });
  it("rechaza puertos distintos del 443 implícito", () => {
    assert.throws(() => validateUrl("https://esm.sh:8443/x.mjs"), /puerto no autorizado \(8443\)/);
    assert.throws(() => validateUrl("https://deno.land:80/x.mjs"), /puerto no autorizado \(80\)/);
    // `:443` es el puerto por defecto de HTTPS: el parser lo normaliza y queda permitido.
    assert.equal(validateUrl("https://esm.sh:443/x.mjs").port, "");
  });
});

// --- --update ------------------------------------------------------------------

describe("update", () => {
  it("sin cambios y sin --accept: no escribe nada y no reporta cambios", async () => {
    const before = snapshot();
    const result = await update(root, { fetchImpl: fakeFetch(okRoutes()), log: () => {} });
    assert.equal(result.applied, false);
    assert.deepEqual(result.changes, []);
    assert.deepEqual(snapshot(), before);
  });

  it("con cambios y sin --accept: los muestra y no altera archivos ni manifest", async () => {
    const routes = okRoutes();
    routes["https://esm.sh/pkg@1.0.0/es2022/pkg.mjs"] = { body: "export const pkg = 2;\n" };
    const before = snapshot();
    const result = await update(root, { fetchImpl: fakeFetch(routes), log: () => {} });
    assert.equal(result.applied, false);
    assert.deepEqual(result.changes.map((c) => [c.status, c.path]), [["CAMBIA", "esm.sh/pkg@1.0.0/es2022/pkg.mjs"]]);
    assert.deepEqual(snapshot(), before);
  });

  it("con --accept: reemplaza solo lo cambiado, reescribe el manifest y --check vuelve a pasar", async () => {
    const routes = okRoutes();
    routes["https://esm.sh/pkg@1.0.0/es2022/pkg.mjs"] = { body: "export const pkg = 2;\n" };
    const before = snapshot();
    const result = await update(root, { fetchImpl: fakeFetch(routes), accept: true, log: () => {} });
    assert.equal(result.applied, true);
    assert.equal(result.changes.length, 1);
    const after = snapshot();
    assert.notEqual(after["esm.sh/pkg@1.0.0/es2022/pkg.mjs"], before["esm.sh/pkg@1.0.0/es2022/pkg.mjs"]);
    assert.equal(after["deno.land/x/lib@1.0.0/mod.js"], before["deno.land/x/lib@1.0.0/mod.js"]);
    assert.notEqual(after["manifest.json"], before["manifest.json"]);
    assert.equal(check(root).ok, true);
  });

  it("actualización parcial (una descarga falla): no altera ningún archivo existente", async () => {
    const routes = okRoutes();
    routes["https://esm.sh/pkg@1.0.0/es2022/pkg.mjs"] = { body: "export const pkg = 2;\n" };
    routes["https://deno.land/x/lib@1.0.0/mod.js"] = { status: 500, body: "" };
    const before = snapshot();
    await assert.rejects(
      () => update(root, { fetchImpl: fakeFetch(routes), accept: true, log: () => {} }),
      /HTTP 500/,
    );
    assert.deepEqual(snapshot(), before);
  });

  it("dependencia nueva en el manifest (sin archivo local): se rechaza salvo --allow-new", async () => {
    const files = Object.entries(FILES).map(([path, content]) => entryFor(path, content));
    files.push(entryFor("esm.sh/extra@1.0.0/es2022/extra.mjs", "export const extra = 3;\n"));
    writeManifest(files);
    const routes = okRoutes();
    routes["https://esm.sh/extra@1.0.0/es2022/extra.mjs"] = { body: "export const extra = 3;\n" };
    const before = snapshot();
    await assert.rejects(
      () => update(root, { fetchImpl: fakeFetch(routes), accept: true, log: () => {} }),
      /dependencias sin archivo local .*extra@1\.0\.0/,
    );
    assert.deepEqual(snapshot(), before);
    const result = await update(root, { fetchImpl: fakeFetch(routes), accept: true, allowNew: true, log: () => {} });
    assert.deepEqual(result.changes.map((c) => [c.status, c.path]), [["NUEVO", "esm.sh/extra@1.0.0/es2022/extra.mjs"]]);
    assert.equal(check(root).ok, true);
  });

  it("URL http, host no permitido, credenciales o puerto en el manifest: nada se descarga", async () => {
    for (const bad of [
      "http://esm.sh/pkg@1.0.0/es2022/pkg.mjs",
      "https://cdn.jsdelivr.net/pkg.mjs",
      "https://u:p@esm.sh/pkg@1.0.0/es2022/pkg.mjs",
      "https://esm.sh:8443/pkg@1.0.0/es2022/pkg.mjs",
    ]) {
      const files = Object.entries(FILES).map(([path, content]) => entryFor(path, content));
      files[0].url = bad;
      writeManifest(files);
      const calls = [];
      await assert.rejects(() => update(root, { fetchImpl: fakeFetch(okRoutes(), calls), accept: true, log: () => {} }));
      assert.deepEqual(calls, [], `no debe haber descargas con ${bad.replace(/\/\/[^@/]+@/, "//<cred>@")}`);
    }
  });
});

// --- redirecciones -------------------------------------------------------------

describe("download", () => {
  it("no sigue redirecciones a hosts fuera de la lista", async () => {
    const routes = {
      "https://esm.sh/pkg@1.0.0/es2022/pkg.mjs": { status: 302, location: "https://cdn.example.net/pkg.mjs" },
      "https://cdn.example.net/pkg.mjs": { body: "x" },
    };
    const calls = [];
    await assert.rejects(
      () => download("https://esm.sh/pkg@1.0.0/es2022/pkg.mjs", { fetchImpl: fakeFetch(routes, calls), log: () => {} }),
      /redirección no autorizada .*host no permitido \(cdn\.example\.net\)/,
    );
    assert.deepEqual(calls, ["https://esm.sh/pkg@1.0.0/es2022/pkg.mjs"]);
  });

  it("procesa a mano una redirección legítima, la registra y revalida el destino", async () => {
    const routes = {
      "https://esm.sh/pkg@1.0.0/es2022/pkg.mjs": { status: 301, location: "/pkg@1.0.0/es2022/pkg.v2.mjs" },
      "https://esm.sh/pkg@1.0.0/es2022/pkg.v2.mjs": { body: "export const pkg = 2;\n" },
    };
    const log = [];
    const result = await download("https://esm.sh/pkg@1.0.0/es2022/pkg.mjs", {
      fetchImpl: fakeFetch(routes),
      log: (line) => log.push(line),
    });
    assert.equal(result.hops, 1);
    assert.equal(result.finalUrl, "https://esm.sh/pkg@1.0.0/es2022/pkg.v2.mjs");
    assert.deepEqual(log, ["redirección https://esm.sh/pkg@1.0.0/es2022/pkg.mjs -> https://esm.sh/pkg@1.0.0/es2022/pkg.v2.mjs"]);
  });

  it("rechaza redirecciones a http aunque el host esté permitido", async () => {
    const routes = { "https://esm.sh/a.mjs": { status: 302, location: "http://esm.sh/a.mjs" } };
    await assert.rejects(
      () => download("https://esm.sh/a.mjs", { fetchImpl: fakeFetch(routes), log: () => {} }),
      /redirección no autorizada .*solo se admite HTTPS/,
    );
  });

  it("corta tras el máximo de saltos", async () => {
    const routes = {};
    for (let i = 0; i <= MAX_REDIRECTS + 1; i += 1) {
      routes[`https://esm.sh/hop${i}.mjs`] = { status: 302, location: `https://esm.sh/hop${i + 1}.mjs` };
    }
    await assert.rejects(
      () => download("https://esm.sh/hop0.mjs", { fetchImpl: fakeFetch(routes), log: () => {} }),
      new RegExp(`más de ${MAX_REDIRECTS} redirecciones`),
    );
  });
});
