# TalentFlash Argentina — aplicación

Plataforma video-first que conecta candidatos y empresas (gastronomía y
hotelería, CABA + GBA). App Flutter multiplataforma + Supabase.

> Esta carpeta está reservada exclusivamente para el código, las pruebas y la
> documentación técnica de la aplicación. El presupuesto, las hipótesis
> comerciales y el archivo Excel se mantienen separados en
> `../02_business_e_costi/` (regla del workspace: nunca mezclar).

## Estado

**Bloque A — Fundaciones**, **Bloque B — Auth (primera parte)**, **Bloque C —
Onboarding + consentimientos**, **Bloque D — Perfiles** y **Bloque E — Empresas
+ verificación de CUIT** completos en local
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

Del Bloque E (migraciones `0025`–`0031`): validación de CUIT por dígito
verificador en cliente y servidor (T-027); CRUD de empresa y equipo por RPC con
la empresa resuelta server-side, e invitaciones de un solo uso (T-026);
verificación manual de empresa con constancia de ARCA en un bucket **privado**,
cola administrativa en `/admin/verificaciones` que exige **segundo factor**
(AAL2) y registro append-only de cada decisión (T-028); y el distintivo
"empresa verificada", que se muestra solo con el estado `approved` exacto
(T-029).

El criterio de publicación quedó **cerrado en `0031`**, no diferido:
`public.company_can_publish` —una lista blanca de `verification_status =
'approved'` exacto y `deleted_at is null`— gobierna las policies
`jobs_company_write`, `jobs_company_update`, `jobs_public_select` y la rama de
video de `videos_company_select`. Una empresa sin verificar puede tener
borradores pero no ofertas `active`, y una oferta activa deja de ser pública en
el mismo momento en que su empresa pierde la aprobación (evidencia: test pgTAP
`018`). La misma migración deja el alta de miembros **solo** por invitación de
un solo uso, bootstrap u onboarding, y serializa las tres puertas sobre la fila
de `profiles` de la cuenta. La oferta en sí llegó con T-030 (ver abajo).

Del **Bloque F — Ofertas**, T-030 está hecho en local (migración `0032`, con
las decisiones del fundador del 2026-10-10): CRUD de ofertas en el que
escriben solo `owner`, `admin` y `recruiter` —el `viewer` ve pero no escribe—,
una máquina de estados que el cliente no puede saltear (borrador, activa,
pausada, cerrada, y vencida solo por el sistema), fechas de publicación y
cierre derivadas por el servidor, validación de contenido server-side y
requisitos para publicar: sueldo mayor a cero, vencimiento a 60 días como
máximo y barrio cuando la localidad tiene barrios cargados (hoy, CABA). En la
app, `/empresa/ofertas` (lista, alta, edición, publicar, pausar, reanudar,
cerrar, descartar borrador y duplicar) y, para el candidato, una lista mínima de
ofertas publicadas en `/candidato/feed` con su detalle en
`/candidato/ofertas/:id`. El feed de verdad —ranking por zona y categoría,
búsqueda y filtros— sigue siendo del Bloque G (T-035, T-037, T-038), y el
resto del Bloque F también está pendiente: límite por plan (T-031), video de
oferta (T-032), vencimiento automático por `pg_cron` (T-033; hasta entonces la
app oculta del lado del cliente las ofertas con el vencimiento pasado) y
compartir (T-034).

Todavía **no** están hechos (y no se simulan en la UI): Google y Apple (T-012),
la pantalla in-app de cambio de contraseña, que depende del enlace profundo
(T-013), CAPTCHA, la verificación real de CUIT contra ARCA (T-027/T-028),
postularse a una oferta (T-040), FCM/APNs y cualquier proyecto remoto.

Del segundo factor conviene separar tres cosas. La **exigencia** es server-side:
revisar una verificación de empresa pide el claim `aal = aal2` del JWT además
del rol admin, con comparación exacta y fallo cerrado si el claim falta o trae
otro nivel, y `config.toml` habilita el enrolamiento TOTP para que ese nivel
sea alcanzable. La **experiencia de alta y verificación** existe en la app:
desde `/admin/verificaciones`, una sesión admin sin `aal2` tiene una acción que
lleva a `/admin/segundo-factor` sin cerrar sesión; sin factor verificado se
inicia el alta (QR y clave manual como alternativa) y se pide el primer
código; con un factor verificado se desafía ese factor sin crear otro; con
varios, se elige cuál usar. Al verificar, el SDK emite la sesión nueva (mismo
usuario, token `aal2`), el estado de sesión la propaga y la cola aparece sola.
Solo `currentLevel == aal2` habilita la cola: tener un factor verificado
(`nextLevel`) no dice nada sobre la sesión actual. Cerrar sesión descarta todo
lo sensible, y un nuevo inicio de sesión vuelve a pedir el código. Lo que
**no** existe, y la pantalla lo dice en vez de simularlo: recuperación por
pérdida del autenticador, baja o reemplazo de un factor verificado y códigos
de recuperación; una cuenta admin que pierde su app queda sin poder operar la
cola hasta que se defina ese circuito. El guard que se ve en la cola es visual:
esconde la cola y explica por qué, pero no autoriza nada — la autorización la
aplica el servidor. Del Bloque D queda pendiente el soporte
de avatares WebP: la Edge Function los rechaza con `unsupported_format`
(la librería de imágenes no los decodifica), así que el whitelist efectivo hoy
es JPEG/PNG.

## Cómo continuar con ChatGPT y Claude

El trabajo se reparte entre el fundador (decide), ChatGPT/Codex (analiza y
prepara el próximo prompt) y Claude (ejecuta en una branch separada). El método,
sus límites de autorización y los pasos para retomar desde otra computadora o
una conversación nueva están versionados en el repositorio:

- [docs/AI_WORKFLOW.md](docs/AI_WORKFLOW.md) — el método y sus límites (reglas
  permanentes), incluido el procedimiento para retomar desde otra computadora.
- [docs/PROJECT_STATUS.md](docs/PROJECT_STATUS.md) — fotografía **fechada** del
  estado: qué está en `main`, qué existe solo en un PR, con SHA y evidencia.
- [docs/prompts/START_CHATGPT.md](docs/prompts/START_CHATGPT.md) — prompt para
  arrancar o retomar el análisis con ChatGPT.
- [docs/prompts/EXECUTE_CLAUDE.md](docs/prompts/EXECUTE_CLAUDE.md) — plantilla
  para pedirle una tarea a Claude.
- [AGENTS.md](AGENTS.md) y [CLAUDE.md](CLAUDE.md) — instrucciones breves por rol.

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

**Probar el segundo factor de administración:** el seed no trae ninguna cuenta
`admin`. Para probarlo a mano, registrá una cuenta desde la app (o con
`empresa`/`candidato` de prueba) y promovela desde `psql` dentro del
contenedor de la base — es la única vía admitida (`docs/SECURITY.md` §3) y el
trigger de la migración `0019` propaga el rol al claim:

```sql
-- Poné el correo de la cuenta que registraste (o una del seed, p. ej.
-- 'empresa7@dev.talentflash.test'): con un correo inexistente el UPDATE
-- afecta 0 filas y NO da error, así que conviene comprobarlo con el select.
update public.profiles set role = 'admin' where email = 'TU_CORREO_ACA';
select p.role::text || '/' || coalesce(u.raw_app_meta_data ->> 'role', '')
from public.profiles p join auth.users u on u.id = p.id
where p.email = 'TU_CORREO_ACA';  -- tiene que devolver admin/admin
```

Cerrá sesión y volvé a entrar para que el token traiga el rol nuevo. En
`/admin/verificaciones` vas a ver la acción **Verificar segundo factor**: la
primera vez muestra el QR y la clave manual para cargar en una app de
autenticación (Google Authenticator, Microsoft Authenticator, Aegis…); las
siguientes, solo pide el código. `npm run mfa:test` hace el mismo recorrido
con cuentas sintéticas y códigos calculados, y las borra al terminar.

## Verificación

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test

# Bloque D — requieren el stack local levantado (db:start) y Deno 2:
npm run functions:test   # deno test de la Edge Function avatar (magic bytes + parser EXIF)
npm run storage:test     # integración real contra el bucket avatars (upload, thumbnail,
                         # URL firmada vigente y vencida, permisos, DELETE)

# Bloque E — requiere el stack local levantado (db:start), sin Deno:
npm run db:concurrency   # carreras reales entre las tres puertas que crean una membresía
                         # (0031), con dos sesiones psql simultáneas: dos códigos para la
                         # misma cuenta, onboarding y bootstrap concurrentes, canje cruzado
npm run mfa:test         # segundo factor TOTP de administración contra el GoTrue real:
                         # alta, desafío y verificación con códigos calculados (RFC 6238),
                         # RPC rechazada con aal1 y aceptada con aal2, reingreso y nuevo
                         # desafío, aal2 sin rol admin rechazado; cuentas sintéticas que
                         # se crean y borran en la corrida (nunca imprime secretos)
```

La CI (`.github/workflows/ci.yml`) corre formato + analyze + tests Flutter,
reset/lint/pgTAP de Supabase, `db:concurrency`, `mfa:test`, `functions:test` y
`storage:test` (con `denoland/setup-deno@v2` fijado a la versión exacta
**v2.7.14** en los dos jobs que instalan Deno: una versión flotante cambia las
banderas aceptadas sin aviso), el guard del grafo offline de la Edge Function
(`scripts/edge-offline-guard.mjs`, documentado en
`supabase/functions/avatar/deps/README.md`) y scan de secretos (gitleaks).

Los disparadores son `push` a `main`/`develop` y `pull_request`. En la práctica:
una rama **sin PR abierto** no dispara ninguna corrida, y una rama **con el PR ya
abierto** dispara una corrida nueva en cada push.

## Estructura

```
lib/
├── core/           # config (flavors), localization (ARB es-AR), routing,
│                   # security, theme, networking
├── features/       # feature-first: authentication, onboarding, consents,
│                   # legal, notifications, profiles, companies, jobs,
│                   # moderation…
└── shared/         # widgets/modelos compartidos (fallos tipados, banners)
supabase/
├── migrations/     # 0001–0032 — esquema completo + RLS deny-by-default
├── tests/database/ # pgTAP (RLS + RPCs de onboarding + ledger de consents
│                   # + perfiles, proyección para empresas y storage de avatares
│                   # + CUIT, empresa y equipo, invitaciones, verificación
│                   # manual, puerta de publicación y ciclo de vida de ofertas)
├── seed/           # seed de desarrollo (T-008; estados de onboarding reales)
└── functions/      # Edge Functions (avatar — T-022; el resto llega con sus bloques)
docs/               # los 8 documentos técnicos (fuente de verdad) + método de
                    # trabajo con IA (AI_WORKFLOW, PROJECT_STATUS, prompts/)
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
