# Supabase — backend de TalentFlash

Estructura (ARCHITECTURE.md §3, DATA_MODEL.md §8):

- `migrations/` — 18 migraciones SQL versionadas (0001–0018), generadas desde
  `docs/DATA_MODEL.md` (fuente de verdad). Regla: ningún cambio de esquema por
  dashboard; siempre migración versionada (T-005).
- `functions/` — Edge Functions (llegan con los Bloques B+; catálogo en ARCHITECTURE.md §3).
- `tests/database/` — tests pgTAP de RLS (T-007), extraídos de DATA_MODEL.md §6.
- `seed/seed.sql` — seed de DESARROLLO (T-008): 20 candidatos, 5 empresas,
  10 ofertas. Solo local, jamás en producción.

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

## Entornos remotos (T-004 — requieren aprobación)

- dev/staging: proyecto Supabase Free/Pro con prefijo `stg-` (ver ARCHITECTURE.md §9).
- prod: Supabase Pro (USD 25/mes, decisión D-001 en COST_DECISIONS.md).
Crear proyectos remotos = costo recurrente ⇒ pedir aprobación antes (regla del SPEC).
