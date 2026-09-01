# Supabase — backend de TalentFlash

Estructura (ARCHITECTURE.md §3, DATA_MODEL.md §8):

- `migrations/` — 22 migraciones SQL versionadas (0001–0022), generadas desde
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
  lo crea.
- `functions/` — Edge Functions (llegan con los Bloques B+; catálogo en ARCHITECTURE.md §3).
- `tests/database/` — tests pgTAP (T-007): RLS, RPCs de onboarding (`007`),
  ledger de consentimientos y reconsentimiento (`008`), preferencias/legales y
  coherencia del seed con la derivación (`009`).
- `seed/seed.sql` — seed de DESARROLLO (T-008): 20 candidatos, 6 usuarios de
  empresa (5 con empresa) y 10 ofertas, con estados de onboarding reales:
  candidatos 1–15 publicados (la publicación la deriva el trigger de 0022 a
  partir de sus consentimientos, no se fuerza a mano), 16–18 completos sin
  publicar, 19–20 y empresa6 con el wizard a medio hacer. Solo local, jamás en
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
```

`db:test` ejecuta los mismos archivos pgTAP directamente dentro del contenedor
PostgreSQL y falla ante errores SQL o líneas TAP `not ok`. El runner alternativo
del CLI queda disponible como `npm run db:test:supabase`.

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
