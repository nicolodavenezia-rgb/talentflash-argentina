# Dependencias locales de la Edge Function `avatar`

La función `avatar` arranca y procesa imágenes **sin descargar nada de
internet**: ni módulos, ni definiciones de tipos, ni binarios WASM. Todo lo que
antes se resolvía en `esm.sh` y `deno.land` vive en este directorio, con las
mismas versiones.

## Por qué

- Reproducibilidad: el grafo de la función queda fijado en el repo y no depende
  de la disponibilidad ni del contenido de un CDN.
- Entornos con TLS interceptado (antivirus o proxy corporativo): el edge runtime
  de Supabase corre en un contenedor Linux que no confía en esos certificados y
  no admite agregar una CA, así que cualquier descarga en tiempo de ejecución
  falla con `UnknownIssuer`. Con las dependencias locales el problema desaparece
  sin tocar TLS ni el antivirus.

## Qué hay acá

| Origen | Contenido | Archivos |
|---|---|---|
| `esm.sh/` | `@supabase/supabase-js@2.49.4` y sus dependencias, como bundles ESM `es2022` de esm.sh: `@supabase/auth-js@2.69.1`, `functions-js@2.4.4`, `postgrest-js@1.19.4`, `realtime-js@2.11.2`, `storage-js@2.7.1`, `@supabase/node-fetch@2.6.15`, el stub de navegador de `ws@8.21.3` y el polyfill `node/buffer.mjs` (proyecto `unenv`) | 9 |
| `deno.land/x/imagescript@1.3.0/` | ImageScript completo (28 módulos) más sus 7 binarios `utils/wasm/*.wasm` | 35 |
| `manifest.json` | URL de origen, ruta local, paquete, versión, licencia, SHA-256 y tamaño de cada archivo | 1 |
| `sync.mjs` | Verifica (`--check`) el conjunto exacto de archivos contra el manifest o los regenera (`--update`, con aceptación explícita) | 1 |
| `sync.spec.mjs` | Pruebas de `sync.mjs` sin red (`node --test`); el sufijo `.spec` evita que `deno test` las descubra | 1 |
| `types/supabase-js.d.ts` | Declaración mínima de tipos del cliente, escrita a mano (ver abajo) | 1 |
| `LICENSES.md` | Texto completo de cada licencia | 1 |

Las rutas replican la URL de origen, de modo que cada archivo se puede
comparar uno a uno con su fuente.

## Por qué la variante `es2022` y no `denonext`

esm.sh sirve variantes distintas según el User-Agent. A un agente Deno le
entrega bundles `denonext` que importan `node:buffer`, `node:http`, `node:tls`,
etc. Cualquier especificador `node:` en el grafo hace que el edge runtime de
Supabase inyecte `npm:@types/node` al construirlo
(`inject_synthetic_types_node_package`, fijado a `@types/node@22.5.4` en el
runtime 1.74.x) y lo descargue de `registry.npmjs.org` en cada arranque frío.
Eso viola el objetivo de cero descargas, así que se vendoriza la variante
`es2022` pedida con User-Agent de navegador, que no contiene ningún `node:`:

- `@supabase/node-fetch` reexporta el `fetch` global del runtime.
- `ws` es un stub que solo se evaluaría si no existiera `WebSocket` nativo;
  realtime-js usa el nativo y esta función no abre canales.
- `node/buffer.mjs` es el polyfill de `Buffer` que esm.sh inyecta para
  `storage-js`; no tiene versión en la URL, por eso el manifest lo fija por
  SHA-256.

Las versiones de los paquetes son exactamente las que la función usaba en
remoto.

## Cómo se resuelve

- `index.ts` importa `supabase-js` e ImageScript con rutas relativas a este
  directorio.
- Los bundles de esm.sh se importan entre sí con especificadores absolutos al
  origen (`/@supabase/auth-js@2.69.1/es2022/auth-js.mjs`,
  `/ws@^8.18.0?target=es2022`, `/node/buffer.mjs`). `../deno.json` es el
  import map que traduce cada uno de esos especificadores, tal cual aparece en
  los bundles, al archivo local correspondiente; los rangos se mapean al bundle
  exacto sin pasar por los stubs de redirección.
- ImageScript usa imports relativos y carga cada `.wasm` con
  `Deno.readFile(new URL(import.meta.url.replace('.js', '.wasm')))` cuando el
  módulo es local, así que los binarios se leen del disco.
- El CLI de Supabase detecta `deno.json` en el directorio de la función y lo
  pasa al edge runtime como import map, tanto en `supabase start` como en
  `functions serve` y `functions deploy`.

No se vendorizan las definiciones de tipos (`.d.ts`) que esm.sh anuncia por
cabecera HTTP: encadenan `@types/ws` y de ahí `npm:@types/node`, con el mismo
problema de red. En su lugar, `types/supabase-js.d.ts` (escrito a mano, fuera
del manifest) declara interfaces mínimas y explícitas para lo que `index.ts`
usa de verdad: `auth.getUser`, `from("candidate_profiles")` /
`from("profiles")` con `select`, `update`, `eq`, `is` y `maybeSingle`, y
`storage.from("avatars")` con `upload` y `remove`, con las formas de
respuesta `{ data, error }` de supabase-js 2.49. Se enlaza con `// @ts-types`
sobre el import; `deno check` funciona sin red y cualquier tabla, bucket o
método fuera de ese contrato es un error de tipos que obliga a ampliar la
declaración a conciencia. El contrato HTTP de la función no cambia.

## Archivos estáticos: los WASM

El edge runtime empaqueta cada función copiando a un directorio temporal los
módulos de su grafo de imports (en local, `/var/tmp/sb-compile-edge-runtime/
avatar/`; al desplegar, el bundle). Los `.wasm` no son módulos, así que no
viajan solos: `supabase/config.toml` los declara como archivos estáticos de la
función y el runtime los copia junto al resto.

```toml
[functions.avatar]
static_files = ["./functions/avatar/deps/deno.land/x/imagescript@1.3.0/utils/wasm/*.wasm"]
```

Sin esa entrada la función arranca pero falla al procesar la primera imagen
con `NotFound: path not found: .../utils/wasm/zlib.wasm`. Vale igual para
`supabase start`, `functions serve` y `functions deploy`; el import map
(`../deno.json`) no necesita configuración porque el CLI lo detecta en el
directorio de la función.

## Verificar y actualizar

```powershell
node supabase/functions/avatar/deps/sync.mjs --check              # sin red: conjunto exacto de archivos, tamaños y SHA-256
node supabase/functions/avatar/deps/sync.mjs --update             # descarga a un temporal y MUESTRA qué cambiaría; no escribe
node supabase/functions/avatar/deps/sync.mjs --update --accept    # aplica los cambios mostrados, solo si todas las descargas fueron válidas
node --test supabase/functions/avatar/deps/sync.spec.mjs          # pruebas del sincronizador, sin red
deno check --config supabase/functions/avatar/deno.json supabase/functions/avatar/index.ts
deno info --config supabase/functions/avatar/deno.json supabase/functions/avatar/index.ts   # no debe listar ningún https:// ni node:
```

Qué garantiza `--check`: recorre `esm.sh/` y `deno.land/` sin seguir enlaces
y exige que el conjunto real de archivos sea exactamente el del manifest.
Falla, con salida 1 y sin imprimir contenido, ante un archivo faltante
(`FALTA`), un tamaño distinto (`TAMAÑO`), un hash distinto (`HASH`), un
archivo que no figura en el manifest (`INESPERADO`), un enlace simbólico
(`SYMLINK`) o cualquier cosa que no sea un archivo regular (`TIPO`). También
rechaza un manifest malformado: rutas fuera de esos dos directorios o con
`..`, URLs que no cumplan las reglas de abajo, hashes o tamaños inválidos,
entradas sin paquete, versión o licencia. Fuera del alcance del manifest
quedan solo los archivos administrativos de este directorio: `manifest.json`,
`README.md`, `LICENSES.md`, `.gitattributes`, `types/`, `sync.mjs` y
`sync.spec.mjs`.

Qué garantiza `--update`: acepta únicamente URLs `https://` de la lista
cerrada de hosts (`esm.sh`, `deno.land`), sin credenciales embebidas ni
puerto explícito. No sigue redirecciones automáticamente: si el origen
redirige, procesa el salto a mano, registra origen y destino, vuelve a
aplicar las mismas reglas al destino y corta a partir del cuarto salto. Solo
refresca dependencias que ya tienen archivo local: una entrada nueva en el
manifest se rechaza salvo con `--allow-new`, para que incorporar una
dependencia sea siempre una decisión explícita. Descarga todo a un directorio
temporal; si una sola descarga falla, no toca ningún archivo. Sin `--accept`
solo informa (`CAMBIA` / `NUEVO`, con hash y tamaño viejos y nuevos) y sale
con 3 si hay cambios pendientes; con `--accept` reemplaza cada archivo
cambiado escribiendo primero un temporal junto al destino y reescribe el
manifest al final.

Para cambiar de versión: editar `manifest.json` (URL y ruta de cada archivo
del paquete), ajustar las claves de `../deno.json` y los imports de
`index.ts`, correr `--update --accept --allow-new`, revisar el diff,
comprobar con `deno info` que el grafo siga sin módulos remotos ni `node:`, y
volver a ejecutar `npm run storage:test` y `npm run functions:test`. Si el
host está detrás de un TLS interceptado, `--update` necesita
`NODE_OPTIONS=--use-system-ca`.
