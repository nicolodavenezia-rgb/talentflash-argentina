# TalentFlash Argentina — aplicación

Plataforma video-first que conecta candidatos y empresas (gastronomía y
hotelería, CABA + GBA). App Flutter multiplataforma + Supabase.

> Esta carpeta está reservada exclusivamente para el código, las pruebas y la
> documentación técnica de la aplicación. El presupuesto, las hipótesis
> comerciales y el archivo Excel se mantienen separados en
> `../02_business_e_costi/` (regla del workspace: nunca mezclar).

## Estado

**Bloque A — Fundaciones** completo y **Bloque B — Auth, primera parte** (ver
[docs/ROADMAP.md](docs/ROADMAP.md)): esquema SQL completo con RLS, tooling, CI y
autenticación local con correo y contraseña — alta de candidato y de empresa,
login, sesión persistente, cierre de sesión, solicitud de recuperación y
navegación protegida por rol.

Todavía **no** están hechos (y no se simulan en la UI): Google y Apple (T-012),
la pantalla in-app de cambio de contraseña, que depende del enlace profundo
(T-013), MFA, CAPTCHA y cualquier proyecto remoto.

## Requisitos

| Herramienta | Versión usada | Nota |
|---|---|---|
| Flutter (stable) | 3.47.0 | Dart 3.13.0 incluido |
| Android SDK | 36 (Build Tools 36.0.0) | para Android |
| Visual Studio 2026 | workload C++ | para Windows desktop |
| Chrome | actual | para Web |
| Supabase CLI | 2.115.0 (devDependency) | ejecutar con scripts `npm run db:*` |
| Docker Desktop | 4.87.0 | backend WSL 2 para Supabase local |

## Setup (clon nuevo)

```powershell
flutter pub get
npm install                           # CLI de Supabase fijado por proyecto
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

# Entry points directos (mismo bootstrap y misma app)
flutter run -t lib/main_candidato.dart --dart-define-from-file=env/dev.json
flutter run -t lib/main_empresa.dart --dart-define-from-file=env/dev.json
```

- `env/dev.json` — Supabase local con URL y publishable key públicas.
- `env/staging.json`, `env/prod.json` — `POR_CONFIGURAR`: los proyectos remotos
  de Supabase y Sentry **requieren aprobación** (costo recurrente) y no existen
  todavía. Ningún archivo de `env/` contiene secretos: solo URLs y claves
  públicas por diseño. Overrides personales: `env/*.local.json` (gitignored).

## Probar la autenticación en local

Levantá el stack (`npm run db:start` y, si hace falta, `npm run db:reset`) y
corré la app con el flavor dev. Todo ocurre contra `http://127.0.0.1:54321`; no
hay ningún proyecto remoto.

**Usuarios del seed** (contraseña única: `password123`):

| Usuario | Correo | Rol |
|---|---|---|
| Candidatos 1–20 | `candidato1@dev.talentflash.test` … `candidato20@…` | `candidate` |
| Empresas 1–5 | `empresa1@dev.talentflash.test` … `empresa5@…` | `company` |

Los candidatos 1–15 tienen el perfil publicado y las 5 empresas están
verificadas. No hay ninguna cuenta `admin` en el seed: el rol de administración
se provisiona solo desde un contexto con `service_role` (ver `docs/SECURITY.md`
§3); al hacerlo, la migración `0019` propaga el rol al claim del JWT.

**Correos locales (verificación de cuenta y recuperación de contraseña):** el
stack local no envía nada afuera. Todos los correos quedan en el buzón de
pruebas — **Mailpit**, en `http://127.0.0.1:54324` (el contenedor conserva el
nombre histórico `supabase_inbucket_*`). Ahí se ve el mail "Reset your password"
que dispara `/auth/recuperar`.

Recordá que `supabase/config.toml` limita a **2 correos por hora**
(`auth.rate_limit.email_sent`): al probar recuperación varias veces seguidas la
API responde 429 y la app muestra el mensaje de "muchos intentos".

En dev, `auth.email.enable_confirmations` está en `false`: el alta deja sesión
iniciada al toque. Con confirmaciones activadas (staging/prod) la misma pantalla
muestra el aviso de "revisá tu correo" en vez de navegar.

**Qué queda pendiente del flujo de recuperación:** la app implementa la primera
etapa (pedir el correo de restablecimiento). La segunda —cambiar la contraseña
dentro de la app— necesita el enlace profundo de T-013, que todavía no está
definido: no hay esquema de deep link ni URL de redirección en la allowlist de
`config.toml`. Por eso no existe una pantalla de "nueva contraseña": sería un
formulario que no podría funcionar.

## Verificación

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

La CI (`.github/workflows/ci.yml`) corre formato + analyze + tests Flutter,
reset/lint/pgTAP de Supabase y scan de secretos (gitleaks) en cada push/PR
cuando el repo tenga remoto en GitHub.

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
├── migrations/     # 0001–0019 — esquema completo + RLS deny-by-default
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
   Los guards de navegación son UX: esconden pantallas, no protegen datos.
4. Cada pantalla cumple WCAG AA antes de cerrar su bloque — checklist en
   [CONTRIBUTING.md](CONTRIBUTING.md) y UX_FLOWS.md §20 (T-086).
5. Ninguna dependencia SaaS nueva sin registro en docs/COST_DECISIONS.md.
