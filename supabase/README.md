# Supabase — backend de TalentFlash

Estructura (ARCHITECTURE.md §3, DATA_MODEL.md §8):

- `migrations/` — 31 migraciones SQL versionadas (0001–0031), generadas desde
  `docs/DATA_MODEL.md` (fuente de verdad). Regla: ningún cambio de esquema por
  dashboard; siempre migración versionada (T-005). La `0019` (Bloque B, T-015)
  sincroniza `profiles.role` con el claim `app_metadata.role` del JWT. Las del
  Bloque C: `0020` (esquema de onboarding, `terms_acceptance`, defaults opt-in
  de `notification_prefs`, `legal_documents` + `consent_versions`), `0021`
  (textos legales vigentes y reglas del ledger de consentimientos: versión
  vigente obligatoria, sin duplicados, `ai_training` inotorgable) y `0022`
  (RPCs de onboarding `save_candidate_onboarding` /
  `complete_candidate_onboarding` / `complete_company_onboarding`, mayoría de
  18 server-side y derivación de `is_published`). El valor nuevo del enum vive
  solo en `0020` porque Postgres no permite usarlo en la misma transacción que
  lo crea. Las del Bloque D: `0023` (perfil profesional del candidato:
  `weekly_availability`, validación de contenido server-side, **eliminación**
  de la policy que dejaba a las empresas leer la fila cruda de
  `candidate_profiles` y proyección `get_candidate_public_profile` con
  whitelist, helpers `company_can_view_candidate` / `blocked_with_candidate`
  / `candidate_application_ready`, endurecimiento de `are_blocked` y
  `has_active_subscription` (sin oráculos a terceros), re-creación de
  `videos_company_select` (sin la rama de candidatos publicados) y de
  `conv_participants_select`, RPCs `get_my_candidate_profile` y
  `update_my_candidate_profile`) y `0024` (bucket `avatars` **privado**:
  lectura por `can_read_avatar_object`, escritura solo vía la Edge Function).
  Las del Bloque E: `0025` (dígito verificador del CUIT, con triggers que lo
  imponen por cualquier puerta y no solo por las RPC), `0026` (arreglo de
  `cm_manage`, resolución server-side de la empresa del caller con
  `private.caller_company` y RPC de edición de perfil y de equipo), `0027`
  (`company_invitations` con el código de un solo uso guardado como SHA-256),
  `0028` (circuito de verificación de empresa: guarda de segundo factor
  `private.caller_is_aal2`, revisión con rol admin leído de `profiles`, motivo
  de lista cerrada y escritura en `admin_audit_log`), `0029` (bucket privado
  `company-docs` para la constancia de ARCA, con el path derivado server-side),
  `0030` (endurecimiento salido de la auditoría: revoca `TRUNCATE`, `TRIGGER` y
  `REFERENCES` a `anon`/`authenticated` en `public`, y pone `for update` sobre
  la empresa en las dos RPC que la escriben) y `0031` (el alta de miembros solo
  por invitación, bootstrap u onboarding —sin policy y sin privilegio de
  `INSERT`—, las tres puertas serializadas sobre `profiles` con
  `private.lock_membership_slot`, y `company_can_publish` conectada a las
  policies de `jobs` y a la rama de video de `videos_company_select`).
- `functions/` — Edge Functions (catálogo en ARCHITECTURE.md §3.4). Existe
  `avatar/` (Bloque D, T-022): valida JWT + rol candidato y magic bytes,
  re-encodea la imagen sin EXIF, genera el thumbnail 128×128 y escribe el
  bucket privado; DELETE idempotente. El resto llega con sus bloques.
- `tests/database/` — tests pgTAP (T-007): RLS, RPCs de onboarding (`007`),
  ledger de consentimientos y reconsentimiento (`008`), preferencias/legales y
  coherencia del seed con la derivación (`009`), perfil de candidato y
  disponibilidad horaria (`010`), proyección para empresas con whitelist
  exacta de claves (`011`), lectura del bucket de avatares (`012`),
  endurecimiento de los helpers RLS del Bloque D (`013`), dígito verificador
  del CUIT con casos reales (`014`), empresa y equipo (`015`), invitaciones de
  un solo uso (`016`), verificación manual con su guarda de segundo factor
  (`017`) y puerta de publicación de ofertas (`018`). Ojo:
  `001_rls_test.sql` fue endurecido en el Bloque D — el test "empresa
  verificada ve perfil publicado" se **invirtió** deliberadamente a "la
  empresa ya no lee la fila cruda" (T-024).
- `seed/seed.sql` — seed de DESARROLLO (T-008): 20 candidatos, 7 usuarios de
  empresa (6 con empresa) y 10 ofertas, con estados de onboarding reales:
  candidatos 1–15 publicados (la publicación la deriva el trigger de 0022 a
  partir de sus consentimientos, no se fuerza a mano), 16–18 completos sin
  publicar, 19–20 y empresa6 con el wizard a medio hacer, y empresa7 con
  empresa creada **pendiente** de verificación. El Bloque D suma perfiles
  ricos para candidato1 y candidato2 (este último con turnos que cruzan la
  medianoche), filas de videos de presentación en `ready`/`processing`/
  `failed` para candidato1/4/5 (solo filas: el pipeline real es del Bloque K)
  y un bloqueo de candidato15 al owner de empresa1. Sin binarios ni PII: los
  avatares reales los ejercita `storage:test`. Solo local, jamás en
  producción. Contraseña única: `password123`. Los usuarios sembrados se crean
  con sus tokens de correo en cadena vacía (no NULL) y con su fila en
  `auth.identities`: sin eso GoTrue falla con 500 al buscarlos y el login
  local queda roto solo para el seed. El test pgTAP
  `006_auth_role_claim_test.sql` protege esas dos condiciones.

## Desarrollo local

Docker Desktop y el CLI de Supabase están configurados localmente. El CLI queda
fijado como `devDependency` del proyecto; no hace falta una instalación global.

```powershell
npm install
npm run db:start
npm run db:reset
npm run db:lint
npm run db:test
npm run db:concurrency   # Bloque E: carreras con dos sesiones psql reales (0031)
npm run functions:test   # Bloque D: deno test de la Edge Function avatar (requiere Deno 2)
npm run storage:test     # Bloque D: integración real contra el stack local
```

`db:test` ejecuta los mismos archivos pgTAP directamente dentro del contenedor
PostgreSQL y falla ante errores SQL, ante líneas TAP `not ok` y ante un
`plan(N)` que no coincida con las aserciones corridas. El runner alternativo
del CLI queda disponible como `npm run db:test:supabase`.

`db:concurrency` (`scripts/db-concurrency-test.mjs`) cubre lo que pgTAP no
puede: cada archivo de `tests/database/` corre dentro de **una** transacción, y
una carrera entre dos transacciones no se puede simular ahí adentro porque dos
llamadas seguidas comparten snapshot y locks. El script abre procesos `psql`
separados y los cruza de verdad, comprobando en `pg_stat_activity` que la
segunda sesión esté esperando un lock y no infiriéndolo del reloj.

`functions:test` corre los tests unitarios de la Edge Function `avatar` (magic
bytes + parser EXIF) con Deno. `storage:test` (`scripts/storage-test.mjs`)
ejercita el flujo completo de avatares contra el stack local levantado:
upload, thumbnail, URL firmada vigente y **vencida**, reemplazo, archivo
inválido, >2 MiB, escritura directa denegada, permisos de empresa
verificada/pendiente/otro candidato/anon y DELETE. La CI corre ambos junto al
resto (con `denoland/setup-deno@v2`).

La Edge Function `avatar` no descarga nada en tiempo de ejecución: sus
dependencias (`@supabase/supabase-js@2.49.4` con sus transitivas, tal como las
sirve esm.sh, e ImageScript 1.3.0 con sus binarios WASM) están vendorizadas en
`functions/avatar/deps/` y `functions/avatar/deno.json` es el import map que
las resuelve. Esto hace reproducible el arranque del edge runtime y lo
independiza de cualquier antivirus o proxy que intercepte TLS en la máquina de
desarrollo. Verificación sin red: `node supabase/functions/avatar/deps/sync.mjs
--check`; detalles y actualización en `functions/avatar/deps/README.md`.

Esa invariante la protege `scripts/edge-offline-guard.mjs`, que CI corre en el
job `edge-guard`: le pide a Deno el grafo realmente resuelto de `index.ts` y
falla si aparece cualquier especificador `http:`, `https:`, `npm:`, `jsr:` o
`node:`, si algún módulo resuelve fuera del directorio de la función, si el
type-check se rompe o si los archivos vendorizados dejan de coincidir con el
manifest. Usa un `DENO_DIR` temporal y vacío para que una caché previa no
pueda ocultar una dependencia remota.

`env/dev.json` contiene solo la URL y la publishable/anon key del stack local.
Es información pública de desarrollo; nunca se guarda la `service_role`.

## Correos locales

El stack no envía nada afuera: todos los correos (confirmación de cuenta,
restablecimiento de contraseña) quedan en **Mailpit**, en
`http://127.0.0.1:54324`. El contenedor conserva el nombre histórico
`supabase_inbucket_*`. Ojo con `auth.rate_limit.email_sent = 2` (por hora) al
probar recuperación varias veces seguidas: la API responde 429.

## Entornos remotos (T-004 — requieren aprobación)

- dev/staging: proyecto Supabase Free/Pro con prefijo `stg-` (ver ARCHITECTURE.md §9).
- prod: Supabase Pro (USD 25/mes, decisión D-001 en COST_DECISIONS.md).
Crear proyectos remotos = costo recurrente ⇒ pedir aprobación antes (regla del SPEC).
