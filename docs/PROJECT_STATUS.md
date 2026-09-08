# PROJECT_STATUS.md — Estado del proyecto

> **Fecha de esta fotografía: 2026-09-06.**
> `origin/main` estaba en **`327883c`**.
>
> Este documento **caduca solo**. Todo lo que dice acá era cierto en esa fecha y
> sobre esos commits. Antes de usarlo como base de una decisión, volvé a
> comprobarlo contra GitHub con los comandos de la
> [§6 «Cómo comprobar este documento»](#6-cómo-comprobar-este-documento). Las
> reglas de trabajo, que no caducan, están en [AI_WORKFLOW.md](AI_WORKFLOW.md).

---

## 1. Qué está integrado en `main`

`main` = **`327883c`**, merge del PR #3. En esa fecha `main` acumulaba tres
fusiones, todas con merge commit normal y en este orden:

| PR | Título | Cabeza fusionada | Merge commit | Fecha |
|---|---|---|---|---|
| [#1](https://github.com/nicolodavenezia-rgb/talentflash-argentina/pull/1) | `fix(edge): make avatar dependencies available offline` | `0443f92` | `41b809e` | 2026-09-03 |
| [#2](https://github.com/nicolodavenezia-rgb/talentflash-argentina/pull/2) | `ci(edge): enforce offline dependency graph` | `d9e2a40` | `73d1f29` | 2026-09-06 |
| [#3](https://github.com/nicolodavenezia-rgb/talentflash-argentina/pull/3) | `Bloque E — T-028 verificación manual de empresa + T-029 badge verificado` | `bbc4de8` | `327883c` | 2026-09-06 |

Contenido: **Bloques A, C, D y E** completos en local y **Bloque B (Auth) en su
primera parte** — fundaciones, autenticación por correo y contraseña con
sesiones y roles, onboarding con consentimientos versionados, perfiles de
candidato, gestión de empresa y equipo, invitaciones de un solo uso,
verificación manual de empresa con constancia adjunta, distintivo de empresa
verificada y la puerta de publicación de ofertas. Del Bloque B siguen
pendientes T-012 (Google y Apple) y la pantalla in-app de nueva contraseña de
T-013 (ver [§5](#5-pendientes-conocidos)).

El esquema llega hasta la **migración `0031`** (árbol `0001`–`0031`, 31
archivos) y la suite pgTAP tiene **19 archivos** (`000`–`018`), con RLS
deny-by-default y pruebas por policy.

La CI de `main` sobre `327883c` corre los **cuatro** jobs: `Formato, análisis y
tests`, `Migraciones, lint y RLS`, `Grafo offline de la Edge Function` y `Scan
de secretos (gitleaks)`.

---

## 2. Qué existe solo en un PR abierto

> **Adenda del 2026-09-08.** El PR #4 de abajo ya se fusionó (merge
> `6d9c173`, 2026-09-07): `main` pasó de `327883c` a `6d9c173` y este
> documento vive en `main`. Lo que hoy existe **solo en un PR abierto** es el
> PR #5.

### PR #5 — `feat(auth): alta y verificación TOTP para operar la cola admin`

- Enlace: <https://github.com/nicolodavenezia-rgb/talentflash-argentina/pull/5>
- Rama: `feat/admin-mfa-enrollment` · base `main` (`6d9c173`)
- Qué agrega: la **experiencia** de segundo factor que la [§4](#4-desfases-y-matices-que-hay-que-tener-presentes)
  marcaba como inexistente — alta TOTP (QR + clave manual), desafío y
  verificación desde `/admin/segundo-factor`, con acción desde
  `/admin/verificaciones` sin cerrar sesión; el nivel de la sesión
  (`SessionAssurance`, claim `aal` exacto) pasa a ser parte de `AuthStatus`
  y la cola aparece sola al llegar a `aal2`. Suma `npm run mfa:test`
  (integración real contra el GoTrue local, también en CI), `qr_flutter`, y
  actualiza README, SECURITY, ROADMAP (T-076) y UX_FLOWS.
- Qué **no** agrega, a propósito: recuperación por pérdida del autenticador,
  baja o reemplazo de un factor verificado, códigos de recuperación. No toca
  migraciones, RLS ni la exigencia AAL2.
- **Está abierto al momento de esta adenda y no se fusionó.** Si querés
  saber si ya lo está, corré los comandos de la
  [§6](#6-cómo-comprobar-este-documento).

### PR #4 — `docs: versionar el método de trabajo con ChatGPT y Claude` (fusionado el 2026-09-07)

- Enlace: <https://github.com/nicolodavenezia-rgb/talentflash-argentina/pull/4>
- Rama: `codex/documentar-flujo-chatgpt-claude` · base `main`
- Qué agrega: este documento y el resto del método —`docs/AI_WORKFLOW.md`,
  `docs/prompts/START_CHATGPT.md`, `docs/prompts/EXECUTE_CLAUDE.md`,
  `AGENTS.md`, `CLAUDE.md`— más el enlace desde el README y las correcciones
  documentales de `docs/ARCHITECTURE.md` y `docs/DATA_MODEL.md` descritas en la
  [§3](#3-lo-que-ya-está-resuelto-y-conviene-no-volver-a-anotar-como-pendiente).
- **Es solo documentación**: no toca código de producto, migraciones ni CI.
- **Está abierto al momento de esta foto.** Que este archivo viva en su rama no
  significa que el PR esté fusionado; si querés saber si ya lo está, corré los
  comandos de la [§6](#6-cómo-comprobar-este-documento).

No hay ningún otro PR abierto.

---

## 3. Lo que ya está resuelto y conviene no volver a anotar como pendiente

**La combinación de los PR #2 y #3 quedó validada y fusionada.** Era el punto
que este documento marcaba como no validado el 2026-09-05, y dejó de serlo. El
commit `bbc4de8` —merge de `origin/main` (que ya traía el PR #2) dentro de la
rama del PR #3— corrió por primera vez las dos mitades juntas y con la
definición de CI completa, en la corrida
[34070725731](https://github.com/nicolodavenezia-rgb/talentflash-argentina/actions/runs/34070725731),
**verde en sus 4 jobs**:

| Suite | Resultado en esa corrida |
|---|---|
| Flutter | 439 pruebas |
| pgTAP | 437 aserciones en 19 archivos |
| Concurrencia (`db:concurrency`) | 20 comprobaciones |
| Deno (Edge Function `avatar`) | 19 pruebas |
| Storage (integración real contra el bucket) | 27 aserciones |
| Guard del grafo offline | 37 pruebas |
| Sincronizador de dependencias | 23 pruebas · 44 archivos contra el manifest |

Esos números son de **esa** corrida y de **ese** SHA. No son una garantía
permanente ni se pueden reutilizar para otro commit.

**El único conflicto de la integración fue documental y de CI, y se resolvió
conservando las dos versiones.** `.github/workflows/ci.yml` recibía un paso
nuevo de cada PR después de `npm run db:test`; quedaron los dos, primero
`npm run db:concurrency` (PR #3) y después el `denoland/setup-deno@v2` fijado a
`v2.7.14` (PR #2). El párrafo del README que describe la CI recibía datos
distintos de cada PR y quedó con los dos: nombra `db:concurrency`, la versión
fija de Deno en los dos jobs que lo instalan, y el guard del grafo offline. No
se descartó ninguna de las dos versiones.

**`0031` conecta la aprobación de la empresa con el permiso de publicar.**
`public.company_can_publish(uuid)` —que exige el estado `approved` exacto— está
cableada a las policies `jobs_company_write`, `jobs_company_update`,
`jobs_public_select` y a la rama de video de `videos_company_select`. La
evidencia está en el test pgTAP `018_publication_gate_test.sql`. Antes de `0031`
esto no era una funcionalidad diferida sino un criterio **incumplido**:
`public.jobs` existía desde `0007` y `authenticated` tenía DML por PostgREST,
así que una empresa sin verificar podía insertar una oferta activa.

**El README ya no está desfasado.** El desfase que este documento registraba el
2026-09-05 (Bloque E descrito como `0025`–`0029`, árbol `0001`–`0030`, y la
publicación anotada como pendiente de T-030) lo cerraron los commits `207de67`
y `7fee1a8` dentro del propio PR #3, junto con `supabase/README.md`,
`docs/ROADMAP.md` y `docs/DATA_MODEL.md`.

**Correcciones documentales hechas en el PR #4**, contrastadas contra el
repositorio ya integrado:

- `docs/ARCHITECTURE.md` §9 describía un pipeline de CI de cinco puntos que
  nunca existió como tal (build de Android, build de iOS y deploy de Edge
  Functions no están en ningún workflow). Sigue siendo una **propuesta**, y como
  tal se conserva, pero ahora lleva al lado una nota fechada con los cuatro jobs
  que la CI corre de verdad y con los comandos reales.
- `docs/DATA_MODEL.md` §6 mostraba un árbol de pruebas inventado
  (`010-profiles.test.sql` y compañía, con guiones y sufijo `.test.sql`) que no
  coincide con ningún archivo del repositorio. Se conserva como propuesta
  original y se agrega la lista real de los 19 archivos
  `NNN_nombre_test.sql` de `supabase/tests/database/`, con el comando que los
  corre de verdad. Además, la «Nota (Bloque D)» enumeraba tres suites nuevas
  del bloque y eran cuatro: faltaba `013_privacy_hardening_test.sql`.
- La regla sobre cuándo corre la CI estaba mal enunciada en este documento y en
  `AI_WORKFLOW.md`; ver la [§4](#4-desfases-y-matices-que-hay-que-tener-presentes).

**Sigue siendo de T-030** (y no está hecho): el CRUD completo de la oferta, las
transiciones `paused`/`expired`/`closed`, el formulario y las reglas salariales.

---

## 4. Desfases y matices que hay que tener presentes

### Cuándo corre la CI (corregido)

Hasta esta foto, este documento y `AI_WORKFLOW.md` decían que «pushear una rama
no corre CI: la corrida arranca recién cuando se abre el PR». **La segunda mitad
es falsa.** `.github/workflows/ci.yml` declara:

```yaml
on:
  push:
    branches: [main, develop]
  pull_request:
```

`pull_request` sin `types:` toma el valor por defecto
`opened`/`synchronize`/`reopened`. O sea:

- pushear una rama **que todavía no tiene PR abierto** no dispara nada, porque
  el disparador `push` solo cubre `main` y `develop`;
- pero con el PR **ya abierto**, cada push dispara una corrida nueva por
  `synchronize`.

La evidencia está en el propio PR #3: se abrió el 2026-09-04T17:57:20Z y sobre
su rama hay seis corridas `pull_request`, cinco de ellas posteriores a la
apertura, cada una de un push distinto (`d45f67a`, `c23de38`, `62a0907`,
`47bdbaf`, `7fee1a8`, `bbc4de8`). La consecuencia práctica que sí vale es la
otra, y no cambia: **el resultado de CI que se reporta es el del último commit
publicado**, nunca el verde de un SHA anterior.

### AAL2 server-side no es «MFA implementado»

La revisión de verificaciones **exige segundo factor del lado del servidor**:
`private.caller_is_aal2()` (migración `0028`) compara el claim `aal` del JWT
contra `aal2` de forma exacta y falla cerrado si no está. La app suma un guard
visual en `/admin/verificaciones`, que es UX y no autorización.

Lo que **no** existe es una experiencia de MFA. En todo `lib/` el único uso de
`auth.mfa` es `getAuthenticatorAssuranceLevel()`, que es una **lectura**: no hay
alta (`enroll`), ni desafío (`challenge`), ni verificación (`verify`), ni
pantalla de gestión o recuperación. Consecuencia concreta y medida: la sesión de
la app nunca llega a `aal2`, así que **`/admin/verificaciones` no se puede
operar desde la app**, aunque la guarda server-side sea correcta. Por eso es la
siguiente prioridad (ver [§5](#5-pendientes-conocidos)).

> **Adenda del 2026-09-08.** Lo anterior sigue siendo cierto para `main`
> (`6d9c173`). La experiencia de **alta y verificación** existe en el PR #5
> ([§2](#2-qué-existe-solo-en-un-pr-abierto)), sin fusionar. Lo que ese PR
> tampoco resuelve, y queda como decisión de circuito del fundador: qué pasa
> cuando un admin pierde su app de autenticación (hoy no hay recuperación,
> baja ni reemplazo del factor).

### Las decisiones de CUIT siguen abiertas y son del fundador

El ROADMAP (T-027) documenta **dos decisiones sin resolver**, ambas explicadas
en el encabezado de `lib/features/companies/domain/cuit.dart`:

1. **El «caso 10».** No hay documentación oficial de ARCA/AFIP del algoritmo y
   las librerías de referencia se contradicen. Hoy rige la regla **permisiva**
   (10 → 9), fijada con un test apareado SQL/Dart.
2. **Los prefijos.** Hoy se aceptan **todos**. Restringir a `30/33/34` dejaría
   afuera a empleadores legalmente válidos; aceptar todo deja entrar los CUIT
   genéricos de país.

**Ninguna de las dos se cambia sin una decisión explícita del fundador.** Están
anotadas como decisiones abiertas, no como bugs ni como pendientes técnicos: no
hay que «resolverlas» por iniciativa de un asistente.

### Prueba local, CI y despliegue remoto son tres cosas distintas

- **Local:** requiere Docker y el stack de Supabase levantado. En algunas
  máquinas la suite de base de datos no arranca por conflictos de puertos o por
  interferencia del antivirus con TLS dentro de los contenedores; eso es un
  problema del entorno, no del repositorio, y **no se arregla tocando el
  proyecto**.
- **CI:** corre en `ubuntu-latest`, con los disparadores de arriba.
- **Despliegue remoto:** **no existe.** `env/staging.json` y `env/prod.json`
  están en `POR_CONFIGURAR`; no hay proyecto Supabase remoto ni entorno
  desplegado. Nada de lo verificado hasta hoy dice nada sobre producción.

---

## 5. Pendientes conocidos

De [ROADMAP.md](ROADMAP.md) y del README:

- **Siguiente prioridad — segundo factor para el administrador.** Sin alta y
  verificación de MFA en la app, la cola de empresas
  (`/admin/verificaciones`) queda inoperable: la guarda `aal2` es correcta y
  nadie puede satisfacerla desde la app. Es la tarea que desbloquea el Bloque E
  ya integrado. El nivel `aal2` **es alcanzable**: `supabase/config.toml` ya
  habilita el enrolamiento TOTP, así que falta la superficie de la app (alta,
  desafío, verificación y recuperación), no la configuración del servidor.

  > **Adenda del 2026-09-08.** Sigue siendo cierto para `main` (`6d9c173`).
  > **Alta, desafío y verificación** existen en el PR #5, sin fusionar
  > ([§2](#2-qué-existe-solo-en-un-pr-abierto)). Lo que queda pendiente y sin
  > circuito definido, también después de ese PR, es la **recuperación**:
  > pérdida del autenticador, baja o reemplazo de un factor verificado y
  > códigos de recuperación.
- **T-012** — Google y Apple: sin botones ni puntos de entrada en la UI.
- **T-013** — pantalla in-app de cambio de contraseña: depende de definir el
  esquema de enlace profundo.
- **CAPTCHA** como experiencia de usuario.
- **Verificación automática de CUIT contra el padrón de ARCA**: la del Bloque E
  es manual, con constancia adjunta y revisión administrativa.
- **T-030** — CRUD de oferta y sus transiciones. La expiración automática de
  ofertas sigue sin `pg_cron` (T-033): una oferta `active` con `expires_at`
  vencido se sigue publicando.
- **T-034** — compartir oferta con preview web pública. De ahí cuelga la
  visibilidad deslogueada del video pitch: hoy, para `anon`, la lectura de
  `public.videos` muere con 42501 en vez de devolver lista vacía, porque la
  primera rama de `videos_company_select` mira `job_applications`. Es
  preexistente (pasa igual con las policies de `0015` y `0023`) y está
  documentado en el cuerpo de `0031`.
- **Avatares WebP**: la Edge Function los rechaza con `unsupported_format`; el
  whitelist efectivo es JPEG/PNG.
- **Identificadores de aplicación provisorios** (`com.talentflash…`):
  confirmarlos antes de publicar en los stores es decisión del fundador.
- **Proyectos remotos de Supabase y Sentry**: requieren aprobación por costo
  recurrente.

---

## 6. Cómo comprobar este documento

```bash
git fetch --all --prune
git log --oneline -1 origin/main
gh pr list --state open --json number,title,headRefName,headRefOid
gh pr list --state merged --json number,title,mergeCommit
gh run list --commit <headRefOid-completo-de-la-cabeza-del-PR>
```

Un detalle que hace perder tiempo: `gh run list --commit` **quiere el SHA
completo** (el `headRefOid` de 40 caracteres que devuelve el comando anterior).
Con un SHA corto devuelve una lista vacía sin error, que se parece demasiado a
«no hay corridas» y no lo es.

Si algo de acá no coincide con lo que devuelven esos comandos, mandan los
comandos. Este archivo es una foto, no el original.

---

## 7. Para retomar desde otra computadora

El procedimiento (clonar con historial, autenticarse sin copiar credenciales,
elegir la rama, verificar herramientas, contrastar el estado y abrir la
conversación nueva) es permanente y está en
[AI_WORKFLOW.md §10](AI_WORKFLOW.md#10-continuidad-entre-computadoras-y-entre-conversaciones).
Lo único que cambia con el tiempo es **qué rama corresponde retomar**, y eso al
2026-09-06 era:

| Si querés… | Rama |
|---|---|
| revisar o ajustar el método de trabajo | `codex/documentar-flujo-chatgpt-claude` (mientras su PR siga abierto) |
| empezar una tarea nueva — incluido el segundo factor de la §5 | una rama nueva desde `origin/main` actualizado |

> **Adenda del 2026-09-08.** El método ya está en `main` (PR #4 fusionado).
> Para retomar el segundo factor mientras su PR siga abierto, la rama es
> `feat/admin-mfa-enrollment` (PR #5); para cualquier otra tarea, una rama
> nueva desde `origin/main` actualizado.

Las ramas de los PR #2 y #3 (`ci/edge-offline-dependency-guard` y
`feat/company-management-and-verification`) ya están fusionadas: sirven para
leer historia, no para seguir trabajando encima.
