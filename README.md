# TalentFlash Argentina — aplicación

Plataforma video-first que conecta candidatos y empresas (gastronomía y
hotelería, CABA + GBA). App Flutter multiplataforma + Supabase.

> Esta carpeta está reservada exclusivamente para el código, las pruebas y la
> documentación técnica de la aplicación. El presupuesto, las hipótesis
> comerciales y el archivo Excel se mantienen separados en
> `../02_business_e_costi/` (regla del workspace: nunca mezclar).

## Estado

**Bloque A — Fundaciones** (ver [docs/ROADMAP.md](docs/ROADMAP.md)). No hay
features de producto todavía: bienvenida + puntos de entrada candidato/empresa,
esquema SQL completo con RLS, tooling y CI.

## Requisitos

| Herramienta | Versión usada | Nota |
|---|---|---|
| Flutter (stable) | 3.47.0 | Dart 3.13.0 incluido |
| Android SDK | 36 (Build Tools 36.0.0) | para Android |
| Visual Studio 2026 | workload C++ | para Windows desktop |
| Chrome | actual | para Web |
| Supabase CLI + Docker | — | **aún no instalados**; ver [supabase/README.md](supabase/README.md) |

## Setup (clon nuevo)

```powershell
flutter pub get
flutter gen-l10n                       # genera lib/core/localization/gen/
git config core.hooksPath .githooks    # activa el pre-commit (formato + analyze)
```

## Correr la app

Los flavors usan `--dart-define-from-file` (nunca valores hardcodeados):

```powershell
# Web (dev)
flutter run -d chrome --dart-define-from-file=env/dev.json
# Windows (dev)
flutter run -d windows --dart-define-from-file=env/dev.json
# Android (dev) — con un emulador/dispositivo conectado
flutter run -d android --dart-define-from-file=env/dev.json
```

- `env/dev.json` — Supabase local (la anon key la imprime `supabase start`).
- `env/staging.json`, `env/prod.json` — `POR_CONFIGURAR`: los proyectos remotos
  de Supabase y Sentry **requieren aprobación** (costo recurrente) y no existen
  todavía. Ningún archivo de `env/` contiene secretos: solo URLs y claves
  públicas por diseño. Overrides personales: `env/*.local.json` (gitignored).

## Verificación

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

La CI (`.github/workflows/ci.yml`) corre formato + analyze + tests + scan de
secretos (gitleaks) en cada push/PR cuando el repo tenga remoto en GitHub.

## Estructura

```
lib/
├── core/           # config (flavors), localization (ARB es-AR), routing,
│                   # security, theme, networking
├── features/       # feature-first: onboarding, profiles, companies, videos,
│                   # jobs, discovery, applications, matches, chat, billing,
│                   # notifications, moderation, authentication
└── shared/         # widgets/utilidades compartidas
supabase/
├── migrations/     # 0001–0017 — esquema completo + RLS deny-by-default
├── tests/database/ # pgTAP (RLS)
├── seed/           # seed de desarrollo (T-008)
└── functions/      # Edge Functions (Bloques B+)
docs/               # los 8 documentos técnicos (fuente de verdad)
env/                # flavors dev/staging/prod (sin secretos)
```

## Identificadores (⚠ provisorios)

`--org com.talentflash` ⇒ applicationId Android `com.talentflash.talentflash_argentina`
y bundle ID iOS equivalente. **Confirmar los identificadores definitivos antes
de publicar en los stores** (decisión del fundador pendiente; cambiarlos después
de publicar es costoso).

## Reglas de oro

1. Ningún secreto en el repo ni en el cliente (SECURITY.md §4; gitleaks en CI).
2. Ningún cambio de esquema sin migración versionada (T-005).
3. RLS es la única capa de autorización; cada policy con test pgTAP (T-007).
4. Cada pantalla cumple WCAG AA antes de cerrar su bloque — checklist en
   [CONTRIBUTING.md](CONTRIBUTING.md) y UX_FLOWS.md §20 (T-086).
5. Ninguna dependencia SaaS nueva sin registro en docs/COST_DECISIONS.md.
