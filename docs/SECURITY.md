# TalentFlash Argentina — Seguridad (SECURITY.md)

**Última actualización:** 2026-08-12
**Estado:** propuesta inicial — pendiente de aprobación del fundador

Este documento define el modelo de amenazas, los controles de seguridad y los procesos operativos de seguridad de TalentFlash. Se complementa con `ARCHITECTURE.md` (topología y componentes), `DATA_MODEL.md` (tablas y RLS), `PAYMENTS.md` (flujo Mercado Pago), `PRIVACY.md` (datos personales, retención y comunicación de incidentes a usuarios/autoridades) y `OPERATIONS.md` (guardias y runbooks).

---

## 1. Modelo de amenazas por superficie

Principio general: asumimos que **todo lo que corre en el cliente es hostil o manipulable**. La única frontera de confianza es Postgres (RLS) + Edge Functions con verificación explícita.

### 1.1 App móvil / web (cliente)

| Amenaza | Vector | Mitigación principal |
|---|---|---|
| Scraping de perfiles de candidatos | Automatización del cliente / replay de llamadas a la API | Rate limiting por usuario e IP (§6), cursors opacos, paginación acotada, detección de patrones |
| Account takeover (ATO) | Credenciales filtradas, phishing, sesión robada | Políticas de contraseña + MFA (§2), rotación de refresh tokens, revocación de sesiones |
| Manipulación de lógica en el cliente | Modificar el bundle JS / app para saltear validaciones | Ninguna lógica de permisos en el cliente; todo se re-valida en RLS y Edge Functions (§3, §5) |
| Exposición de secretos | Claves embebidas en el bundle | Solo `anon key` pública en el cliente; nada más (§4) |

### 1.2 API Supabase (PostgREST directo)

| Amenaza | Vector | Mitigación principal |
|---|---|---|
| Lectura masiva de datos (scraping) | Consultas directas a PostgREST con anon key | RLS estricta por tabla, columnas sensibles fuera de las vistas públicas, límite de filas por request |
| Enumeración de recursos | IDs secuenciales adivinables | UUID v4 en todas las PK expuestas; nunca IDs autoincrementales en la API (§6) |
| Escalada horizontal (leer datos de otro usuario) | Manipular filtros del query | RLS con `auth.uid()` como única fuente de identidad (§3) |
| Abuso de filtros costosos | Queries pesadas para DoS | `statement_timeout` bajo para el rol `anon`/`authenticated`, índices sobre columnas filtrables |

### 1.3 Edge Functions

| Amenaza | Vector | Mitigación principal |
|---|---|---|
| Inyección / input malicioso | Bodies arbitrarios | Validación con esquemas (Zod) antes de cualquier lógica (§5) |
| Abuso de IA (prompt injection, uso masivo) | Llamadas repetidas a funciones que invocan LLM; texto de perfiles/chat inyectado en prompts | Rate limit por usuario, cuotas diarias, tratamiento del contenido de usuario como dato (nunca como instrucción), límites de tokens, logging de consumo |
| Uso indebido de service role | Bug que filtra privilegios | Service role **solo** dentro de Edge Functions, nunca en el cliente; cada función valida el JWT del llamador antes de operar (§3, §5) |
| SSRF | URLs provistas por el usuario | Allowlist de dominios salientes; nunca fetch a URLs arbitrarias del input |

### 1.4 Webhooks (Mercado Pago, Cloudflare)

| Amenaza | Vector | Mitigación principal |
|---|---|---|
| Inyección de webhooks falsos | POST forjado al endpoint | Verificación de firma obligatoria (MP `x-signature` HMAC; firma de webhooks de Cloudflare) antes de parsear el body (§5) |
| Fraude de pagos | Notificación falsa de pago aprobado | Nunca confiar en el payload: re-consultar el pago a la API de MP por ID y validar monto/moneda/estado contra la orden local (§5, ver `PAYMENTS.md`) |
| Replay | Reenvío de un webhook legítimo | Idempotencia por ID de evento persistido (§5) |

### 1.5 Panel admin

| Amenaza | Vector | Mitigación principal |
|---|---|---|
| ATO de cuenta admin | Phishing, credenciales débiles | MFA obligatoria, sesiones cortas, allowlist opcional de IP (propuesta a validar) |
| Abuso interno | Admin que consulta datos sin necesidad | Audit log de toda acción y de todo acceso a datos sensibles (§10), principio de mínimo privilegio por rol |
| Escalada desde rol de moderador | Roles mal separados | Roles diferenciados (moderador / admin / superadmin) aplicados vía RLS y claims, no en UI |

### 1.6 Video pipeline (Cloudflare Stream)

| Amenaza | Vector | Mitigación principal |
|---|---|---|
| Upload de contenido malicioso o no-video | Subida directa manipulada | URLs de subida firmadas de un solo uso con restricciones (§7), validación server-side post-upload |
| Videos fuera de política (duración, contenido) | Bypass del cliente | Límite de 30s impuesto en la URL de upload y verificado por webhook al procesar; chequeos automáticos pre-publicación + revisión humana posterior por muestreo (§7, §9) |
| Hotlinking / scraping de videos | URLs públicas predecibles | Signed URLs de reproducción con expiración; tokens atados al usuario |

### 1.7 Amenazas transversales

- **Cuentas falsas de empresa:** verificación de empresa antes de habilitar contacto con candidatos (CUIT + email corporativo + revisión manual en cola de moderación). Hasta verificar: sin acceso a datos de contacto ni chat saliente.
- **Spam a candidatos:** cuota de primeros contactos por empresa/día, filtros anti-spam en chat (§8), throttling progresivo, suspensión automática ante reportes acumulados.

---

## 2. Autenticación

- **Proveedor:** Supabase Auth (email+contraseña, OAuth Google y Apple). Sign in with Apple es obligatorio en App Store al ofrecer login social de terceros (ver ROADMAP T-012 y UX_FLOWS §2.1). OTP por teléfono: **decisión aparte**, no incluida en el MVP salvo aprobación explícita del fundador. Nada de auth casera.
- **Contraseñas:** mínimo 10 caracteres, chequeo contra diccionarios de contraseñas filtradas (HaveIBeenPwned k-anonymity vía Edge Function), sin reglas de composición arbitrarias, sin expiración forzada.
- **Recuperación segura:** solo por magic link/OTP de Supabase con expiración corta (15 min, propuesta a validar); la respuesta del endpoint no revela si el email existe; rate limit agresivo (§6).
- **Sesiones:** refresh token rotation activada; logout global disponible ("cerrar todas las sesiones"); invalidación de sesiones al cambiar contraseña.
- **MFA:** TOTP vía Supabase Auth MFA. **Obligatoria** para cuentas admin/moderación; **ofrecida y recomendada** para cuentas de empresa (obligatoria para empresas con plan pago: propuesta a validar); opcional para candidatos.
- **Bloqueo progresivo:** backoff exponencial ante intentos fallidos por cuenta y por IP; nunca bloqueo permanente silencioso (evita DoS de cuentas ajenas).

---

## 3. Autorización = RLS

Regla de oro: **ninguna lógica de permisos vive en el cliente**. El cliente solo decide qué mostrar; qué se puede leer/escribir lo decide Postgres.

- RLS **habilitada en el 100% de las tablas** del schema expuesto, incluidas las "inofensivas". Tabla nueva sin políticas = tabla inaccesible por defecto.
- Identidad únicamente por `auth.uid()` y claims del JWT; jamás por parámetros del request.
- **Service role key solo en Edge Functions.** Nunca en el cliente, nunca en repositorio, nunca en funciones invocables sin verificación previa del JWT del llamador.
- Roles de negocio modelados según `DATA_MODEL.md` (modelo único para todos los docs): `profiles.role` enum (`candidate`, `company`, `admin`) más `verification_status` para el estado de verificación de empresas. No existe tabla `user_roles` ni rol `empresa_verificada`: "empresa verificada" = `role = 'company'` **y** `verification_status = 'verified'`. Ambas columnas se modifican **solo vía service role** y son consultadas por las políticas RLS.

Ejemplo ilustrativo (candidato lee/edita solo su perfil; empresas verificadas leen perfiles de candidato publicados), con las tablas y columnas reales de `DATA_MODEL.md` (`profiles.id`, `profiles.role`, `verification_status`, `candidate_profiles.is_published`):

```sql
alter table profiles enable row level security;
alter table candidate_profiles enable row level security;

create policy "own_profile_rw" on profiles
  for all using (auth.uid() = id);

create policy "verified_company_read" on candidate_profiles
  for select using (
    is_published = true
    and exists (
      select 1 from profiles p
      where p.id = auth.uid()
        and p.role = 'company'
        and p.verification_status = 'verified'
    )
  );
```

- Revisión obligatoria de políticas RLS en cada PR que toque el schema (checklist en `DATA_MODEL.md`).
- Tests automatizados de RLS: suite que intenta accesos cruzados (usuario A → datos de B) y debe fallar.

---

## 4. Gestión de secretos

- **Nunca** en el cliente, nunca commiteados al repo. Lo único público es la `anon key` y la URL del proyecto.
- Secretos de runtime (service role, tokens de MP, Cloudflare, proveedor de IA, Sentry) en **Supabase Edge Function secrets / env vars**, cargados por CLI o dashboard, jamás hardcodeados.
- `.env` en `.gitignore` desde el commit 1; escaneo de secretos en CI (gitleaks) sobre cada PR y sobre el historial.
- **Rotación:** calendario trimestral para claves de terceros; rotación inmediata ante sospecha de exposición o salida de una persona con acceso. Registrar cada rotación en el audit log.
- Acceso al dashboard de Supabase y a Cloudflare limitado a fundadores, con MFA.

---

## 5. Edge Functions: validación, firmas, idempotencia

- **Validación de input:** todo body/query se parsea con esquemas Zod al inicio de la función; ante fallo, 400 sin detalles internos. Nada de acceder a campos sin validar.
- **Verificación de firma de webhooks:**
  - *Mercado Pago:* validar `x-signature` (HMAC-SHA256 con el secret del webhook) y `x-request-id` antes de leer el payload; luego **re-consultar el recurso por ID a la API de MP** y validar monto, moneda y external_reference contra la orden local. El payload nunca es fuente de verdad.
  - *Cloudflare (Stream):* validar el header de firma del webhook con el secret configurado; descartar requests sin firma válida con 401 y alerta si el volumen es anómalo.
- **Idempotencia:** todo evento de webhook se persiste con su ID externo único **antes** de procesarse; si el evento ya existe, responder 200 sin re-procesar. Para pagos se usa la tabla `payment_events` definida en `DATA_MODEL.md` (ID de evento del proveedor con constraint `unique`, estado de procesamiento, timestamp); los webhooks de Cloudflare Stream siguen el mismo patrón (ID de evento único persistido). Aplica también a cualquier acción de pago iniciada por el cliente (idempotency key generada por el cliente y validada server-side).
- Respuestas de error genéricas hacia afuera; detalle completo solo en logs/Sentry.
- Timeout y límites de tamaño de body explícitos en cada función.

---

## 6. Rate limiting y anti-scraping

**Rate limiting** por IP **y** por usuario (contadores en Postgres o Upstash Redis; propuesta a validar), con límites diferenciados:

| Acción | Límite propuesto (a validar) |
|---|---|
| Login / recuperación de contraseña | 5/min por IP, 10/h por cuenta |
| Búsquedas de perfiles | 30/min por usuario; techo diario por plan |
| Mensajes de chat | 20/min; primeros contactos de empresa: cuota diaria por plan |
| Llamadas a funciones de IA | cuota diaria por usuario + techo global de gasto |
| Uploads de video | 3/h, 10/día por candidato |

Respuestas 429 con `Retry-After`; los límites se aplican en Edge Functions/gateway, nunca solo en el cliente.

**Anti-scraping:**

- **Cursors opacos** en toda paginación (cursor firmado/cifrado, no offsets): impiden saltar a páginas arbitrarias y enumerar el dataset.
- **UUIDs no enumerables** en todos los recursos expuestos.
- **Límites de paginación:** máximo de resultados por página (20) y techo de resultados totales por búsqueda por día según plan.
- **Detección de patrones:** job que analiza logs (volumen por IP/cuenta, secuencialidad, ausencia de eventos de UI, user-agents anómalos) y dispara: CAPTCHA progresivo → throttling → suspensión + alerta al admin.
- Datos de contacto de candidatos nunca en listados: solo se revelan tras acción explícita registrada (auditada) de una empresa verificada.

---

## 7. Uploads seguros (video pipeline)

- **URLs firmadas de un solo uso** (Cloudflare Stream direct upload) generadas por Edge Function tras validar sesión, rol y cuota; expiración corta (10 min, propuesta a validar).
- **Restricciones en la URL de upload:** tamaño máximo (100 MB, propuesta a validar) y **duración máxima 30 segundos** (`maxDurationSeconds`), impuestas por Cloudflare, no por el cliente.
- **Validación de tipo:** verificación server-side del contenido al procesarse (webhook de Stream); si no es video válido o excede duración → descartar y notificar.
- **Política de moderación de video (regla única, alineada con ROADMAP T-057, UX_FLOWS §16 y cierre de la decisión abierta 8 de PRODUCT; pendiente de aprobación del fundador como todo este documento):** el video debe pasar los **chequeos automáticos obligatorios** (tipo de contenido válido, duración ≤ 30 s, escaneo básico) antes de publicarse; superados esos chequeos, en beta se **auto-aprueba** y entra a **revisión humana posterior** por muestreo aleatorio de contenido nuevo más priorización por señales de riesgo (reportes, cuentas nuevas, flags automáticos) (§9). Si las métricas de abuso lo justifican, se conmuta a revisión previa total (el pipeline debe soportar ambos modos). Imágenes de avatar: validación de MIME real (magic bytes) + re-encoding server-side.
- Reproducción solo mediante signed URLs con expiración; sin URLs públicas permanentes.

---

## 8. Chat: anti-spam y anti-phishing

- **Filtros al enviar:** detección de URLs (bloqueo de acortadores y dominios en denylist; advertencia sobre enlaces externos), detección de patrones de phishing (pedidos de pago, códigos, datos bancarios), límites de mensajes idénticos repetidos.
- **Primer contacto restringido:** solo empresas verificadas pueden iniciar conversación; cuota diaria de nuevos hilos.
- **Reporte desde el mensaje:** cada mensaje tiene acción "Reportar" (spam / phishing / inapropiado) que congela el hilo para revisión y encola en moderación con el contexto completo.
- Umbral de reportes → suspensión automática preventiva del emisor + revisión humana.
- Nunca renderizar HTML de mensajes: texto plano escapado (el contenido de chat es también vector de inyección hacia la UI y hacia prompts de IA, §1.3).

---

## 9. Moderación

- **Cola humana** en el panel admin: videos seleccionados para revisión posterior (muestreo aleatorio + priorizados por reportes o flags automáticos, según la política de §7), perfiles de empresa pendientes de verificación, reportes de chat, contenido flaggeado por IA.
- Cada ítem muestra contexto mínimo necesario (privacidad por diseño, ver `PRIVACY.md`).
- **Acciones auditadas** (§10): aprobar, rechazar con motivo, suspender cuenta, banear. Toda acción exige motivo seleccionado o texto.
- Doble control para acciones destructivas (ban permanente requiere segundo admin; propuesta a validar según tamaño del equipo).
- SLA interno de revisión: 24 h para verificación de empresas y videos (propuesta a validar).

---

## 10. Audit log

- Tabla `admin_audit_log` (nombre según `DATA_MODEL.md`; ROADMAP debe alinearse a este mismo naming) **append-only** (sin UPDATE/DELETE por RLS; escritura solo vía service role):

```sql
create table admin_audit_log (
  id uuid primary key default gen_random_uuid(),
  at timestamptz not null default now(),
  actor_id uuid not null,
  actor_role text not null,
  action text not null,          -- ej: 'admin.user.suspend', 'company.contact.reveal'
  target_type text,
  target_id uuid,
  metadata jsonb,                -- motivo, IP, request_id
  ip inet
);
```

- Se registra: **toda acción administrativa** (moderación, cambios de rol, rotación de secretos, cambios de configuración) y **todo acceso a datos sensibles** (revelado de contacto de un candidato, exportaciones, consultas admin sobre perfiles).
- Retención mínima 2 años (alinear con `PRIVACY.md`); revisión mensual de accesos admin.
- Alertas automáticas sobre patrones anómalos en el propio audit log (ej.: un admin revelando contactos en masa).

---

## 11. Backups y recuperación

**PITR de Supabase (decisión aprobada el 12-08-2026 por el fundador):** el PITR (recuperación punto-en-el-tiempo) **no es obligatorio en el primer MVP**. Se vuelve **obligatorio en la fase Crecimiento**, o antes si los datos o los ingresos alcanzan un nivel suficientemente crítico. Costo del add-on PITR 7 días: ~USD 100/mes (precio oficial), solo escenario Crecimiento — registrado en el Excel de costos (fila C22) y en `COST_DECISIONS.md` (D-015).

**Estrategia aprobada para Validación y MVP** (aprobado el 12-08-2026 por el fundador):

- **Backups diarios incluidos en Supabase Pro** (retención incluida de 7 días).
- **Export lógico cifrado semanal**: `pg_dump` cifrado guardado en almacenamiento separado, independiente del proveedor.
- **Prueba periódica de restauración documentada** (simulacro trimestral, documentado en `OPERATIONS.md`): restaurar a proyecto de staging, validar integridad, cronometrar.
- **Backup separado de los datos NO cubiertos por el backup de PostgreSQL**: p. ej. objetos de Storage. Los videos viven en Cloudflare Stream (durabilidad delegada), fuera de Postgres; sus **metadatos** (IDs, estados de moderación) se respaldan en Postgres, cubiertos por los backups diarios.

Objetivos propuestos a validar: **RPO ≤ 24 h** (backup diario) en Validación/MVP — con PITR en fase Crecimiento el objetivo pasa a **RPO ≤ 5 min** —; **RTO ≤ 4 h**.

---

## 12. Gestión de dependencias

- **Lockfiles commiteados** siempre (`package-lock.json` / `deno.lock`); CI instala con lockfile estricto (`npm ci`).
- **Dependabot** activo para npm, GitHub Actions y Docker (si aplica): parches de seguridad auto-mergeados tras CI verde; majors con revisión manual.
- `npm audit` (o equivalente) como gate en CI para severidad high/critical.
- Minimizar dependencias en Edge Functions; preferir std/Deno y SDKs oficiales (Supabase, MP, Cloudflare).

---

## 13. Monitoreo

- **Sentry** en cliente (web/móvil) y Edge Functions: errores, releases, source maps privados. Scrubbing de PII activado (no enviar emails/tokens en breadcrumbs; ver `PRIVACY.md`).
- **Alertas de anomalías** (canal de alertas del equipo):
  - picos de 401/403/429 (posible scraping o credential stuffing),
  - webhooks con firma inválida por encima de umbral,
  - gasto de IA fuera de banda,
  - tasa de registro de empresas anómala (cuentas falsas en masa),
  - errores de pago repetidos.
- Logs de Edge Functions con `request_id` correlacionable con Sentry y `admin_audit_log`.
- Uptime check externo sobre endpoints críticos (login, búsqueda, webhook MP).

---

## 14. Respuesta a incidentes

**Severidades:**

| Sev | Definición | Ejemplos | Primera respuesta |
|---|---|---|---|
| SEV-1 | Exposición de datos personales, compromiso de credenciales/secretos, fraude de pagos activo | Filtración de perfiles, service role expuesta | Inmediata, 24/7 |
| SEV-2 | Vulnerabilidad explotable sin evidencia de explotación; caída de un control crítico | Bug de RLS detectado, firma de webhook desactivada por error | < 4 h |
| SEV-3 | Debilidad menor, hardening pendiente | Dependencia vulnerable sin exploit conocido | Próximo sprint |

**Pasos (runbook resumido; detalle en `OPERATIONS.md`):**

1. **Contener:** rotar secretos comprometidos, revocar sesiones, deshabilitar la superficie afectada (feature flag / pausar función).
2. **Evaluar:** alcance, datos afectados, ventana temporal (usar `admin_audit_log`, logs, Sentry).
3. **Erradicar y recuperar:** fix, restore desde backup diario / export cifrado si hubo corrupción (vía PITR en fase Crecimiento, §11), verificación.
4. **Comunicar:** si hay datos personales involucrados, seguir el plan de notificación a usuarios y autoridades definido en `PRIVACY.md` (Ley 25.326 y AAIP). Un solo vocero designado.
5. **Post-mortem sin culpas** dentro de los 5 días hábiles: causa raíz, acciones, dueños, fechas.

Cada incidente SEV-1/SEV-2 queda registrado con timeline en el repositorio interno.

---

## 15. Checklist de seguridad pre-lanzamiento

- [ ] RLS habilitada y testeada en el 100% de las tablas (suite de accesos cruzados en verde).
- [ ] Service role ausente del cliente y del repo (escaneo gitleaks del historial completo).
- [ ] MFA obligatoria activa en todas las cuentas admin.
- [ ] Verificación de firma activa y testeada en webhooks de MP y Cloudflare (incluye test de replay e idempotencia).
- [ ] Rate limits activos en login, búsqueda, chat, IA y uploads; probados con carga sintética.
- [ ] Cursors opacos y límites de paginación verificados en todos los listados.
- [ ] Upload de video: URL de un solo uso, límite 30s y tamaño máximo verificados end-to-end.
- [ ] Audit log registrando acciones admin y accesos a contactos (verificación manual de 10 acciones).
- [ ] Backups diarios de Supabase Pro activos + export lógico cifrado semanal configurado + un restore de prueba exitoso documentado (PITR no requerido para el MVP: solo desde fase Crecimiento, D-015, aprobado el 12-08-2026 por el fundador).
- [ ] Dependabot activo, cero vulnerabilidades high/critical abiertas.
- [ ] Sentry con scrubbing de PII verificado (ningún email/token en eventos de prueba).
- [ ] Runbook de incidentes revisado por ambos fundadores; secretos con plan de rotación escrito.
- [ ] **Pentest externo básico** (alcance: auth, RLS/API, webhooks, panel admin; proveedor y costo: propuesta a validar) con hallazgos critical/high corregidos antes del go-live.
- [ ] Revisión cruzada con `PRIVACY.md`: minimización de datos y textos de consentimiento en producción.
