# Supabase — backend de TalentFlash

Estructura (ARCHITECTURE.md §3, DATA_MODEL.md §8):

- `migrations/` — 17 migraciones SQL versionadas (0001–0017), generadas desde
  `docs/DATA_MODEL.md` (fuente de verdad). Regla: ningún cambio de esquema por
  dashboard; siempre migración versionada (T-005).
- `functions/` — Edge Functions (llegan con los Bloques B+; catálogo en ARCHITECTURE.md §3).
- `tests/database/` — tests pgTAP de RLS (T-007), extraídos de DATA_MODEL.md §6.
- `seed/seed.sql` — seed de DESARROLLO (T-008): 20 candidatos, 5 empresas,
  10 ofertas. Solo local, jamás en producción.

## Requisitos locales (PENDIENTES en esta máquina — 12-08-2026)

El CLI de Supabase y Docker **no están instalados**, así que las migraciones y
los tests todavía **no fueron ejecutados**. Para correr todo localmente:

```powershell
# 1. Docker Desktop: https://docs.docker.com/desktop/setup/install/windows-install/
# 2. Supabase CLI (scoop):
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase
# 3. Inicializar (una vez, desde 01_app/): genera supabase/config.toml
supabase init
# 4. En config.toml apuntar el seed: [db.seed] sql_paths = ["./seed/seed.sql"]
# 5. Levantar el stack local y aplicar migraciones + seed desde cero:
supabase start
supabase db reset
# 6. Tests de RLS (pgTAP):
supabase test db
```

`supabase start` imprime la `anon key` local → copiarla en `env/dev.json`
(`SUPABASE_ANON_KEY`). Es una clave pública de desarrollo, no un secreto.

## Entornos remotos (T-004 — requieren aprobación)

- dev/staging: proyecto Supabase Free/Pro con prefijo `stg-` (ver ARCHITECTURE.md §9).
- prod: Supabase Pro (USD 25/mes, decisión D-001 en COST_DECISIONS.md).
Crear proyectos remotos = costo recurrente ⇒ pedir aprobación antes (regla del SPEC).
