// Regenera o verifica las dependencias vendorizadas de la Edge Function `avatar`.
//
// El edge runtime local NO debe descargar nada de internet al arrancar ni al
// procesar imágenes (ver README.md de este directorio). Todo lo que la función
// importa desde esm.sh y deno.land vive acá, con su URL de origen y su SHA-256
// registrados en manifest.json.
//
// Uso (Node 22, sin dependencias npm):
//   node supabase/functions/avatar/deps/sync.mjs --check    verifica cada archivo local contra el manifest (sin red)
//   node supabase/functions/avatar/deps/sync.mjs --update   vuelve a descargar cada URL y reescribe archivos y hashes
//
// Detrás de un antivirus o proxy que intercepta TLS, el host necesita su
// almacén de certificados: NODE_OPTIONS=--use-system-ca node ... --update
import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import process from "node:process";

const here = dirname(fileURLToPath(import.meta.url));
const manifestPath = join(here, "manifest.json");
const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
const mode = process.argv[2];

// esm.sh elige la variante del build según el User-Agent: a un agente Deno le
// sirve módulos con imports `node:*`, y cualquier especificador `node:` en el
// grafo hace que el edge runtime inyecte `npm:@types/node` y lo descargue del
// registro al arrancar (ver README.md). Con un agente de navegador y
// `target=es2022` los bundles no traen ningún `node:`; se fija para que el
// resultado sea reproducible.
const USER_AGENT =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Safari/537.36";

const sha256 = (bytes) => createHash("sha256").update(bytes).digest("hex");

if (mode !== "--check" && mode !== "--update") {
  console.error("Uso: node sync.mjs --check | --update");
  process.exit(2);
}

let failures = 0;

for (const entry of manifest.files) {
  const file = join(here, entry.path);

  if (mode === "--update") {
    const response = await fetch(entry.url, {
      headers: { "user-agent": USER_AGENT },
      redirect: "follow",
    });
    if (!response.ok) {
      throw new Error(`${entry.url}: HTTP ${response.status}`);
    }
    if (response.redirected) {
      console.warn(`aviso: ${entry.url} redirigió a ${response.url}`);
    }
    const bytes = Buffer.from(await response.arrayBuffer());
    mkdirSync(dirname(file), { recursive: true });
    writeFileSync(file, bytes);
    entry.sha256 = sha256(bytes);
    entry.bytes = bytes.length;
    console.log(`ok  ${entry.path} (${bytes.length} bytes)`);
    continue;
  }

  let bytes;
  try {
    bytes = readFileSync(file);
  } catch {
    console.log(`FALTA    ${entry.path}`);
    failures += 1;
    continue;
  }
  if (sha256(bytes) !== entry.sha256 || bytes.length !== entry.bytes) {
    console.log(`DIFIERE  ${entry.path}`);
    failures += 1;
    continue;
  }
  console.log(`ok  ${entry.path}`);
}

if (mode === "--update") {
  writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
}

if (failures > 0) {
  console.error(`${failures} archivo(s) faltan o difieren del manifest.`);
  process.exit(1);
}

console.log(`${manifest.files.length} archivos coinciden con manifest.json.`);
