# Supabase — backend de TalentFlash

Estructura (ARCHITECTURE.md §3, DATA_MODEL.md §8):

- `migrations/` — 19 migraciones SQL versionadas (0001–0019), generadas desde
  `docs/DATA_MODEL.md` (fuente de verdad). Regla: ningún cambio de esquema por
  dashboard; siempre migración versionada (T-005). La `0019` (Bloque B, T-015)
  sincroniza `profiles.role` con el claim `app_metadata.role` del JWT: provisionar
  un admin con `service_role` es un `UPDATE` sobre `profiles.role` y el claim se
  propaga solo.
- `functions/` — Edge Functions (llegan con los Bloques B+; catálogo en ARCHITECTURE.md §3).
- `tests/database/` — tests pgTAP de RLS (T-007), extraídos de DATA_MODEL.md §6.
- `seed/seed.sql` — seed de DESARROLLO (T-008): 20 candidatos, 5 empresas,
  10 ofertas. Solo local, jamás en producción. Contraseña única: `password123`.
  Los usuarios sembrados se crean con sus tokens de correo en cadena vacía (no
  NULL) y con su fila en `auth.identities`: sin eso GoTrue falla con 500 al
  buscarlos y el login local queda roto solo para el seed. El test pgTAP
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
