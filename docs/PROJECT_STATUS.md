# PROJECT_STATUS.md — Estado del proyecto

> **Fecha de esta fotografía: 2026-09-05.**
> `origin/main` estaba en **`41b809e`**.
>
> Este documento **caduca solo**. Todo lo que dice acá era cierto en esa fecha y
> sobre esos commits. Antes de usarlo como base de una decisión, volvé a
> comprobarlo contra GitHub con los comandos de la
> [§6 «Cómo comprobar este documento»](#6-cómo-comprobar-este-documento). Las
> reglas de trabajo, que no caducan, están en [AI_WORKFLOW.md](AI_WORKFLOW.md).

---

## 1. Qué está integrado en `main`

`main` = **`41b809e`** (merge del PR #1, fusionado el 2026-09-03).

Contenido, según [ROADMAP.md](ROADMAP.md) y el [README](../README.md) de ese
commit: **Bloques A, C y D** completos en local y **Bloque B (Auth) en su
primera parte** — fundaciones, autenticación por correo y contraseña con
sesiones y roles, onboarding con consentimientos versionados y perfiles de
candidato. Del Bloque B siguen pendientes T-012 (Google y Apple) y la pantalla
in-app de nueva contraseña de T-013 (ver §5). El esquema llega hasta la
**migración `0024`**, con RLS deny-by-default y pruebas pgTAP por policy.

La Edge Function `avatar` forma parte de ese Bloque D (T-022). Lo que entró por
el PR #1 (`fix(edge): make avatar dependencies available offline`) fue la
**vendorización de sus dependencias** —`deps/`, el import map `deno.json`, los
`static_files` en `config.toml`— para que arranque sin red.

**CI sobre `41b809e`** — corrida
[33798598690](https://github.com/nicolodavenezia-rgb/talentflash-argentina/actions/runs/33798598690),
evento `push`, **verde** en sus 3 jobs (`Formato, análisis y tests`,
`Migraciones, lint y RLS`, `Scan de secretos (gitleaks)`):

| Suite | Resultado en esa corrida |
|---|---|
| Flutter | 321 pruebas |
| pgTAP | 184 aserciones en 14 archivos |
| Deno (Edge Function `avatar`) | 19 pruebas |
| Storage (integración real contra el bucket) | 27 aserciones |

Esos números son de **esa** corrida y de **ese** SHA. No son una garantía
permanente ni se pueden reutilizar para otro commit.

---

## 2. Qué existe solo en un PR abierto

Lo que sigue **no está en `main`**. Está publicado en una rama y esperando
decisión del fundador. Ninguno de los dos PR tiene autorización de merge.

### PR #2 — `ci(edge): enforce offline dependency graph`

- Enlace: <https://github.com/nicolodavenezia-rgb/talentflash-argentina/pull/2>
- Rama: `ci/edge-offline-dependency-guard` · cabeza **`d9e2a40`** · base `main`
- Qué agrega: `scripts/edge-offline-guard.mjs`, su suite de pruebas sin red, y
  un job de CI nuevo (`Grafo offline de la Edge Function`) que exige que todo
  especificador del grafo de la Edge Function sea `file:`. Toca además el
  README, `supabase/README.md` y el README de las dependencias vendorizadas.
- **CI sobre `d9e2a40`** — corrida
  [33822315863](https://github.com/nicolodavenezia-rgb/talentflash-argentina/actions/runs/33822315863),
  **verde** en sus 4 jobs: 321 Flutter · 184 pgTAP (14 archivos) · 19 Deno · 27
  Storage · 37 pruebas del guard · 23 pruebas del sincronizador de dependencias.

### PR #3 — `Bloque E — T-028 verificación manual de empresa + T-029 badge verificado`

- Enlace: <https://github.com/nicolodavenezia-rgb/talentflash-argentina/pull/3>
- Rama: `feat/company-management-and-verification` · cabeza **`47bdbaf`** · base `main`
- Qué agrega: migraciones **`0025` a `0031`** (validación de CUIT, gestión de
  empresa y equipo, invitaciones de un solo uso, verificación manual de empresa,
  bucket privado para la constancia, endurecimiento y, en `0031`, el cierre del
  alta directa de miembros más la conexión de la publicación), la pantalla de
  verificación de empresa, la cola administrativa `/admin/verificaciones`, el
  distintivo de empresa verificada y el script de pruebas de concurrencia.
- **CI sobre `47bdbaf`** — corrida
  [33932322509](https://github.com/nicolodavenezia-rgb/talentflash-argentina/actions/runs/33932322509),
  **verde** en sus 3 jobs: 439 Flutter · 437 pgTAP (19 archivos) · 20
  comprobaciones de concurrencia · 19 Deno · 27 Storage.
- **Ojo con esos 3 jobs:** el job `Grafo offline de la Edge Function` **no corre
  acá**, porque lo agrega el PR #2 y esta rama no lo tiene. Los dos PR corrieron
  con definiciones de CI distintas.

### Lo que NO está validado

**La combinación de los PR #2 y #3 no está validada.** Cada corrida probó su
rama contra `main`, nunca una contra la otra. Los dos verdes por separado no
autorizan a afirmar que juntos funcionan; eso necesita su propia validación, y
esa validación es una tarea aparte que todavía no se pidió.

---

## 3. Lo que ya está resuelto y conviene no volver a anotar como pendiente

**`0031` conecta la aprobación de la empresa con el permiso de publicar.**
Verificado el 2026-09-05 leyendo
`supabase/migrations/0031_membership_gate_and_publication.sql` en la cabeza del
PR #3: `public.company_can_publish(uuid)` —que exige el estado `approved`
exacto— quedó cableada a las policies `jobs_company_write`,
`jobs_company_update`, `jobs_public_select` y a la rama de video de
`videos_company_select`. La evidencia está en el test pgTAP
`018_publication_gate_test.sql`, y el ROADMAP del PR ya lo registra como
criterio cerrado.

Antes de `0031` esto no era una funcionalidad diferida sino un criterio
**incumplido**: `public.jobs` existía desde `0007` y `authenticated` tenía DML
por PostgREST, así que una empresa sin verificar podía insertar una oferta
activa. Conviene recordar la diferencia, porque explica por qué no alcanzaba con
dejarlo para T-030.

**Sigue siendo de T-030** (y no está hecho): el CRUD completo de la oferta, las
transiciones `paused`/`expired`/`closed`, el formulario y las reglas salariales.

---

## 4. Desfases y matices que hay que tener presentes

### El README del PR #3 quedó atrasado respecto de su propia rama

El commit `47bdbaf` —cabeza de la rama, asunto literal
«docs: cerrar el criterio de publicacion de T-028 y registrar 0031»— actualizó
`docs/ROADMAP.md` y `docs/DATA_MODEL.md`, pero **no** el README. Por eso el
README de esa rama todavía dice tres cosas que su propio código desmiente:

1. que el Bloque E son las migraciones «`0025`–`0029`» (hay hasta `0031`);
2. que «sigue pendiente conectar la verificación al permiso de publicar ofertas:
   eso llega con T-030» (lo cerró `0031`);
3. que el árbol de `supabase/migrations/` va de `0001` a `0030`.

Es un desfase **de la rama del PR #3**, no de `main`. El README de `main` no
menciona el Bloque E en absoluto, y está bien que no lo mencione: nada del
Bloque E está integrado. Corregir ese README es trabajo del PR #3 o de una tarea
posterior; **no** hay que adelantar a `main` afirmaciones sobre funcionalidades
que todavía no se fusionaron.

### AAL2 server-side no es «MFA implementado»

En el PR #3, la revisión de verificaciones **exige segundo factor del lado del
servidor**: `private.caller_is_aal2()` (migración `0028`) compara el claim `aal`
del JWT contra `aal2` de forma exacta y falla cerrado si no está. La app suma un
guard visual en `/admin/verificaciones`, que es UX y no autorización.

Lo que **no** existe es una experiencia de MFA: no hay pantalla de alta del
segundo factor, ni de gestión, ni de recuperación. El propio mensaje de la app
lo admite — le pide al admin que cierre sesión, active el segundo factor por
fuera y vuelva a entrar. Dicho de otro modo: **la exigencia está; la experiencia
de configuración y uso, no.** El README de `main` sigue listando MFA entre lo no
hecho, y eso continúa siendo correcto.

### Las decisiones de CUIT siguen abiertas y son del fundador

El ROADMAP del PR #3 (T-027) documenta **dos decisiones sin resolver**, ambas
explicadas en el encabezado de `lib/features/companies/domain/cuit.dart`:

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
- **CI:** corre en `ubuntu-latest`. Los disparadores son `push` a `main`/`develop`
  y `pull_request`. Consecuencia práctica: **pushear una rama no corre CI** — la
  corrida arranca recién cuando se abre el PR.
- **Despliegue remoto:** **no existe.** `env/staging.json` y `env/prod.json`
  están en `POR_CONFIGURAR`; no hay proyecto Supabase remoto ni entorno
  desplegado. Nada de lo verificado hasta hoy dice nada sobre producción.

---

## 5. Pendientes conocidos

De [ROADMAP.md](ROADMAP.md) y del README, sin integrar en `main`:

- **Decisión de fusión de los PR #2 y #3**, y validación previa de su
  combinación.
- **T-012** — Google y Apple: sin botones ni puntos de entrada en la UI.
- **T-013** — pantalla in-app de cambio de contraseña: depende de definir el
  esquema de enlace profundo.
- **MFA y CAPTCHA** como experiencia de usuario (ver
  [§4](#4-desfases-y-matices-que-hay-que-tener-presentes)).
- **Verificación automática de CUIT contra el padrón de ARCA**: la del Bloque E
  es manual, con constancia adjunta y revisión administrativa.
- **T-030** — CRUD de oferta y sus transiciones.
- **Avatares WebP**: la Edge Function los rechaza con `unsupported_format`; el
  whitelist efectivo es JPEG/PNG.
- **Identificadores de aplicación provisorios** (`com.talentflash…`): confirmarlos
  antes de publicar en los stores es decisión del fundador.
- **Proyectos remotos de Supabase y Sentry**: requieren aprobación por costo
  recurrente.

---

## 6. Cómo comprobar este documento

```bash
git fetch --all --prune
git log --oneline -1 origin/main
gh pr list --state open --json number,title,headRefName,headRefOid
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
2026-09-05 era:

| Si querés… | Rama |
|---|---|
| seguir el trabajo del PR #2 | `ci/edge-offline-dependency-guard` |
| seguir el trabajo del PR #3 | `feat/company-management-and-verification` |
| revisar o ajustar el método de trabajo | `codex/documentar-flujo-chatgpt-claude` (mientras su PR siga abierto) |
| empezar una tarea nueva | una rama nueva desde `origin/main` actualizado |
