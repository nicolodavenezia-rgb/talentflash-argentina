# TalentFlash Argentina — aplicación

Plataforma video-first que conecta candidatos y empresas (gastronomía y
hotelería, CABA + GBA). App Flutter multiplataforma + Supabase.

> Esta carpeta está reservada exclusivamente para el código, las pruebas y la
> documentación técnica de la aplicación. El presupuesto, las hipótesis
> comerciales y el archivo Excel se mantienen separados en
> `../02_business_e_costi/` (regla del workspace: nunca mezclar).

## Estado

**Bloque A — Fundaciones**, **Bloque B — Auth (primera parte)**, **Bloque C —
Onboarding + consentimientos** y **Bloque D — Perfiles** completos en local
(ver [docs/ROADMAP.md](docs/ROADMAP.md)): esquema SQL con RLS, tooling, CI,
autenticación con correo y contraseña, y el onboarding completo de candidato y
empresa — wizards con reanudación, verificación de mayoría de 18 server-side,
consentimientos versionados append-only con reconsentimiento automático,
preferencias de notificaciones con opt-in explícito y documentos legales
públicos en `/legal/*`.

Del Bloque D (migraciones `0023`–`0024`): CRUD del perfil profesional del
candidato con validación de contenido server-side y disponibilidad horaria
semanal (T-021); foto de perfil en bucket **privado** con thumbnail, URLs
firmadas de TTL corto y re-encoding sin EXIF vía la Edge Function `avatar`
(T-022); estado honesto de la presentación, sin ningún CTA falso — el video
real llega en el Bloque K (T-023); vista de candidato para empresas SOLO por
una proyección con whitelist de campos, fail-closed (la policy que dejaba leer
la fila cruda fue eliminada, T-024); y score de completitud calculado en el
cliente, separado del "listo para postularse" server-side (T-025).

Del Bloque E (migraciones `0025`–`0029`): validación de CUIT por dígito
verificador en cliente y servidor (T-027); CRUD de empresa y equipo por RPC con
la empresa resuelta server-side, e invitaciones de un solo uso (T-026);
verificación manual de empresa con constancia de ARCA en un bucket **privado**,
cola administrativa en `/admin/verificaciones` que exige **segundo factor**
(AAL2) y registro append-only de cada decisión (T-028); y el distintivo
"empresa verificada", que se muestra solo con el estado `approved` exacto
(T-029). Sigue pendiente conectar la verificación al permiso de publicar
ofertas: eso llega con T-030, junto con la oferta misma.

Todavía **no** están hechos (y no se simulan en la UI): Google y Apple (T-012),
la pantalla in-app de cambio de contraseña, que depende del enlace profundo
(T-013), MFA, CAPTCHA, la verificación real de CUIT contra ARCA (T-027/T-028),
FCM/APNs y cualquier proyecto remoto. Del Bloque D queda pendiente el soporte
de avatares WebP: la Edge Function los rechaza con `unsupported_format`
(la librería de imágenes no los decodifica), así que el whitelist efectivo hoy
es JPEG/PNG.

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

| Usuario | Correo | Rol | Estado de onboarding |
|---|---|---|---|
| Candidatos 1–15 | `candidato1@dev.talentflash.test` … | `candidate` | completo, perfil **publicado** (consentimiento de publicación otorgado) |
| Candidatos 16–18 | `candidato16@…` … | `candidate` | completo, **sin** publicar (no dieron ese consentimiento) |
| Candidatos 19–20 | `candidato19@…`, `candidato20@…` | `candidate` | **incompleto**: al entrar, el wizard retoma donde quedó |
| Empresas 1–5 | `empresa1@…` … `empresa5@…` | `company` | completo, empresa creada y verificada |
| Empresa 6 | `empresa6@dev.talentflash.test` | `company` | **incompleto**: al entrar abre el wizard de empresa |
| Empresa 7 | `empresa7@dev.talentflash.test` | `company` | completo, empresa creada **pendiente** de verificación (para probar los estados de la vista de candidato) |

El seed del Bloque D suma además: perfiles ricos para `candidato1` y
`candidato2` (este último con turnos que cruzan la medianoche), filas de
videos de presentación en estados `ready`/`processing`/`failed` para
candidato1/4/5 (solo filas: el pipeline real de video es del Bloque K) y un
bloqueo de `candidato15` al owner de `empresa1` (corta la proyección). Sin
binarios ni PII: los avatares reales los ejercita `npm run storage:test`.

La publicación de los candidatos 1–15 no está forzada en el seed: la deriva el
trigger de la migración `0022` a partir de los datos mínimos + el
consentimiento vigente, así el seed nunca puede contradecir la regla real. No
hay ninguna cuenta `admin` en el seed: el rol de administración se provisiona
solo desde un contexto con `service_role` (ver `docs/SECURITY.md` §3); al
hacerlo, la migración `0019` propaga el rol al claim del JWT y `0022` lo exime
del onboarding.

**Documentos legales:** `/legal/terminos` y `/legal/privacidad` se leen también
sin sesión. El texto vive versionado en la tabla `legal_documents` (única
fuente de verdad para la UI y para la versión que se registra en `consents`);
son borradores de trabajo y lo dicen explícitamente: ningún abogado los validó
todavía.

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

# Bloque D — requieren el stack local levantado (db:start) y Deno 2:
npm run functions:test   # deno test de la Edge Function avatar (magic bytes + parser EXIF)
npm run storage:test     # integración real contra el bucket avatars (upload, thumbnail,
                         # URL firmada vigente y vencida, permisos, DELETE)
```

La CI (`.github/workflows/ci.yml`) corre formato + analyze + tests Flutter,
reset/lint/pgTAP de Supabase, `functions:test` y `storage:test` (con
`denoland/setup-deno@v2`) y scan de secretos (gitleaks) en cada push/PR
cuando el repo tenga remoto en GitHub.

## Estructura

```
lib/
├── core/           # config (flavors), localization (ARB es-AR), routing,
│                   # security, theme, networking
├── features/       # feature-first: authentication, onboarding, consents,
│                   # legal, notifications, profiles, companies, moderation…
└── shared/         # widgets/modelos compartidos (fallos tipados, banners)
supabase/
├── migrations/     # 0001–0029 — esquema completo + RLS deny-by-default
├── tests/database/ # pgTAP (RLS + RPCs de onboarding + ledger de consents
│                   # + perfiles, proyección de empresa y storage de avatares)
├── seed/           # seed de desarrollo (T-008; estados de onboarding reales)
└── functions/      # Edge Functions (avatar — T-022; el resto llega con sus bloques)
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
