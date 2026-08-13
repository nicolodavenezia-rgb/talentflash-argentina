# ROADMAP.md — TalentFlash Argentina: Roadmap y desglose del MVP

**Última actualización:** 2026-08-12
**Estado:** propuesta inicial — pendiente de aprobación del fundador

> **Nota:** la estructura de fases de la §1 sigue el **SPEC §12**. Todos los números de costos son orden de magnitud: la **fuente de verdad es el Excel de costos (`02_business_e_costi/Costi_TalentFlash_Argentina.xlsx`)**, con las decisiones económicas registradas en COST_DECISIONS.md. Precios citados verificados al 2026-08-12 según la investigación de precios del proyecto. Todo precio propio de TalentFlash (planes B2B) está marcado como *propuesta a validar*.

**Documentos relacionados:** SPEC (brief de producto compartido, fuente de verdad), PRODUCT.md (producto y métricas), UX_FLOWS.md (flujos de usuario), ARCHITECTURE.md (stack y decisiones técnicas), DATA_MODEL.md (esquema de datos), PRIVACY.md (privacidad, Ley 25.326, consentimientos), SECURITY.md (seguridad), COST_DECISIONS.md (decisiones económicas).

---

## 1. Fases (según SPEC §12)

| Fase | Objetivo | Duración est. | Entregables | Gate (go/no-go) | Costo (orden de magnitud — ver Excel de costos) |
|---|---|---|---|---|---|
| **1 — Validación** | Confirmar problema y disposición a pagar antes de escribir código de producto | ~2 meses | Entrevistas a empresas gastronómicas (CABA+GBA) y candidatos; prototipo no funcional (mockups navegables); landing con lista de espera | **GV:** señal clara de demanda (ver §5); decisión explícita del fundador de avanzar | Únicos: ~USD 10–15 (dominio .com ~10,44 + .com.ar ARS 8.500). Mensual: ~USD 0 (landing en hosting gratuito) |
| **2 — Prototipo** | Flujo de candidato + oferta hardcodeada, sobre fundaciones reales (repo, CI, entornos, esquema y RLS base) | ~2 meses | Monorepo Flutter + migraciones SQL versionadas, CI verde, dev/prod separados, RLS deny-by-default testeada, Sentry activo; flujo candidato end-to-end con oferta hardcodeada | **G0:** CI verde en PR de prueba; test automático demuestra que `anon` no lee ninguna tabla; secretos fuera del repo (scan limpio); prototipo navegable en dispositivo real | Únicos: ~USD 125 (Apple 99/año + Play 25). Mensual: USD 0–25 (Supabase Free en dev; Pro al abrir staging) |
| **3 — MVP** | Alcance completo del SPEC §5 funcionando end-to-end en staging | ~3 meses (solo-founder, full-time) | Bloques A–Q completos (ver §2); demo E2E: registro → video-CV → postulación → match → chat | **G1:** flujo E2E completo sin intervención manual en staging; DoD (§4) cumplida en todos los bloques; costo mensual real ≤ presupuesto del Excel de costos | ~USD 40–80/mes (Supabase Pro 25 + Stream 5–10 + IA 10–30 + free tiers de Resend/Sentry/CI) |
| **4 — Beta privada** | Validar con **50 empresas** y **500 candidatos** en CABA+GBA (SPEC §12; mismo volumen que usa COST_DECISIONS §1); pulir UX y moderación | ~2 meses | App en TestFlight + Play internal testing; panel admin operativo; cupones beta (billing apagado o 100% bonificado) | **G2:** métricas de activación del §5 alcanzadas; sin incidentes de seguridad/RLS; costo variable por empresa activa conocido y cargado en el Excel de costos | ~USD 80–150/mes (más compute Supabase, más minutos Stream) |
| **5 — Lanzamiento Argentina** | Cobrar: MP Suscripciones activo, stores públicos, SAS operativa | mes ~10 | Billing MP en producción con webhooks idempotentes; facturación fiscal definida con contador; fichas de stores aprobadas | **G3 (a los 90 días):** conversión free→pago y retención M2 del §5; unit economics por empresa ≥ 0 con plan entry | ~USD 150–300/mes + costos ARS: contador ~ARS 350.000/mes (estimación de mercado) y constitución SAS ~ARS 400.000 únicos (estimación); MP se lleva % de cada cobro (ver F-13) |
| **6 — Crecimiento** | Marketing; expandir a más sectores (comercio, ventas, logística, depósitos) y zonas; optimizar costos (revisar mix Stream vs alternativas); 2º canal de adquisición | meses 11–18 | Backlog post-MVP priorizado por datos | **G4:** gates trimestrales por métricas de PRODUCT.md | Escala con MAU/minutos; revisar el Excel de costos trimestralmente |
| **7 — Expansión internacional** | UY → CL → CO/PE → BR (Brasil = mercado separado: idioma, pagos, impuestos, categorías, hábitos) | año 2+ | Localización (es-UY, es-CL, es-CO, es-PE, pt-BR vía ARB), implementación de `PaymentProvider` por país, análisis legal/fiscal por mercado | Go/no-go por país, con unit economics de Argentina probados | A cotizar por mercado (legal, pagos, marketing) — ver Excel de costos |

**Supuesto de capacidad:** 1 fundador técnico full-time asistido por IA; sin equipo. Si se suma 1 dev, la fase MVP puede comprimirse a ~8–9 semanas (las dependencias de §2 marcan qué se paraleliza).

---

## 2. Desglose del MVP en tareas

Convenciones: cada tarea es chica (≤2–3 días), tiene **criterio verificable** (si no se puede demostrar, no está hecha) y lista sus dependencias por ID. El orden dentro de cada bloque es el orden sugerido de ejecución.

### Bloque A — Fundaciones

| ID | Tarea | Criterio verificable | Dep. |
|---|---|---|---|
| T-001 | Crear monorepo: app Flutter + carpeta `supabase/` (migraciones, functions) + README con setup | Clone limpio + `flutter analyze` y `flutter test` corren OK siguiendo solo el README | — |
| T-002 | Tooling: lints estrictos, formatter, pre-commit hook | Un commit con analyze roto es rechazado por el hook | T-001 |
| T-003 | CI GitHub Actions: analyze + tests en cada PR (runner Linux; build iOS se difiere para no quemar minutos macOS 10x) | PR con test roto queda en rojo y bloquea merge | T-001 |
| T-004 | Entornos Supabase: proyecto dev (Free) + prod (Pro) y flavors dev/stg/prod en Flutter | La app en flavor dev apunta a dev y en prod a prod (verificado por endpoint) | T-001 |
| T-005 | Migraciones SQL versionadas (`supabase db diff`/`db push`); prohibido tocar esquema por dashboard sin migración | `supabase db reset` local reproduce el esquema completo desde cero | T-004 |
| T-006 | Esquema base: `profiles`, `companies`, `offers`, `applications`, `matches`, `conversations`/`messages`, `videos`, `consents`, `reports`, `blocks`, `subscriptions`, `notification_prefs`, `audit_log` | Migración aplica sin errores; ERD documentado en ARCHITECTURE.md | T-005 |
| T-007 | RLS deny-by-default en TODAS las tablas + políticas mínimas owner-only | Suite SQL/pgTAP en CI demuestra que `anon` no lee/escribe ninguna tabla | T-006 |
| T-008 | Seeds: comando único puebla dev con 20 candidatos, 5 empresas, 10 ofertas | Correr el seed deja la app dev navegable con datos | T-006 |
| T-009 | Gestión de secretos: dart-define + GitHub Secrets; scan de secretos (gitleaks) en CI | Scan en CI pasa; ningún secreto en historial del repo | T-003 |
| T-010 | Sentry en Flutter por flavor | Error de prueba lanzado desde staging aparece en el dashboard | T-004 |
| T-086 | Accesibilidad WCAG AA transversal (SPEC §10): adoptar el checklist de UX_FLOWS §20 — contraste suficiente, etiquetas semánticas/screen readers (TalkBack/VoiceOver), navegación por teclado en Web, tamaño de texto adaptable, reducción de animaciones, subtítulos en video, mensajes de error comprensibles — e integrarlo a la DoD (§4, ítem 9) | El checklist de UX_FLOWS §20 se aplica y verifica en cada pantalla del MVP antes de cerrar su bloque; auditoría de contraste + lector de pantalla pasa en los flujos principales (registro, feed, postulación, chat) | T-001 |

### Bloque B — Auth

| ID | Tarea | Criterio verificable | Dep. |
|---|---|---|---|
| T-011 | Email + password con verificación de correo (Supabase Auth) | Signup → mail → verificación → login, E2E en dev | T-006 |
| T-012 | OAuth Google y Apple (Sign in with Apple es obligatorio en App Store si hay login social) | Login con ambos proveedores en dispositivo real | T-011 |
| T-013 | Recuperación de contraseña con deep link a la app | Flujo completo desde el mail hasta el reset dentro de la app | T-011 |
| T-014 | Sesiones: refresh automático, logout, tokens en almacenamiento seguro del SO | Sesión sobrevive reinicio de la app; logout borra el token (verificado) | T-011 |
| T-015 | Roles candidato/empresa/admin (claims o tabla) + guards de navegación | Test de integración: una cuenta empresa no accede a pantallas de candidato y viceversa | T-011 |

### Bloque C — Onboarding + consentimientos

| ID | Tarea | Criterio verificable | Dep. |
|---|---|---|---|
| T-016 | Selector de tipo de cuenta + wizard candidato (datos mínimos, zona, rubro, disponibilidad) | Al terminar existe perfil mínimo válido en DB | T-015 |
| T-017 | Wizard empresa (razón social, fantasía, rubro, zona) | Al terminar existe empresa en estado `no_verificada` | T-015 |
| T-018 | Consentimientos versionados: TyC, privacidad, uso de video e IA — tabla `consents` (user, doc, versión, timestamp) | Cada aceptación queda registrada; al subir versión de un doc, la app re-solicita aceptación | T-016 |
| T-019 | Preferencias de notificaciones (opt-in explícito por canal) | Fila en `notification_prefs` respetada por el envío (test en T-064) | T-016 |
| T-020 | Copy legal es-AR enlazado desde onboarding y ajustes (ver PRIVACY.md, Ley 25.326) | Links accesibles y versionados junto con `consents` | T-018 |

### Bloque D — Perfiles

| ID | Tarea | Criterio verificable | Dep. |
|---|---|---|---|
| T-021 | CRUD perfil candidato (experiencia, disponibilidad horaria, zona/barrio, rubro) con RLS: dueño edita | Test RLS: otro usuario no puede editar; empresa ve solo campos públicos | T-016 |
| T-022 | Foto de perfil: bucket Storage con policies + thumbnail | Subir/reemplazar funciona; URL firmada vencida no sirve el archivo | T-021 |
| T-023 | Estado de perfil con/sin video-CV (el video real llega en Bloque K) | Banner "completá tu video-CV" aparece solo si falta video | T-021 |
| T-024 | Vista de perfil de candidato para empresa (campos limitados según reglas de PRODUCT.md) | Test RLS + snapshot: empresa sin match no ve datos de contacto | T-021 |
| T-025 | Score de completitud de perfil (gating de postulación) | Unit tests del cálculo con casos borde | T-021 |

### Bloque E — Empresas + verificación CUIT

| ID | Tarea | Criterio verificable | Dep. |
|---|---|---|---|
| T-026 | CRUD empresa + miembros (owner/staff) con RLS | Test RLS: staff de otra empresa no accede | T-017 |
| T-027 | Validación de CUIT (formato + dígito verificador) en cliente y servidor | Unit tests con CUITs válidos/inválidos; server rechaza aunque el cliente se saltee | T-026 |
| T-028 | Verificación CUIT: flujo `pendiente → verificada/rechazada` con revisión manual en panel admin (constancia ARCA adjunta). Verificación automática contra padrón: post-MVP, a evaluar | Empresa `no_verificada` no puede publicar ofertas (test server-side) | T-027, T-077 |
| T-029 | Badge "empresa verificada" en UI | Golden test del badge en tarjeta de empresa y oferta | T-028 |

### Bloque F — Ofertas

| ID | Tarea | Criterio verificable | Dep. |
|---|---|---|---|
| T-030 | CRUD oferta (puesto, categoría, horario, zona, modalidad, **sueldo o rango salarial obligatorio** — `salary_min`/`salary_max` NOT NULL según DATA_MODEL y SPEC §5 —, requisitos) con estados draft/activa/pausada/cerrada | Tests de transiciones + RLS: candidatos solo ven `activa`; solo la empresa dueña edita; **publicar sin sueldo/rango falla server-side (test)** | T-028 |
| T-031 | Límite de ofertas activas por plan (server-side) — free: N, pago: según plan (N según PRODUCT.md; *propuesta a validar*) | Test: crear oferta por encima del límite falla en servidor | T-030 |
| T-032 | Video de oferta (opcional, grabado por la empresa) | Video reproduce en el detalle de la oferta | T-030, T-054 |
| T-033 | Expiración/renovación automática de ofertas (pg_cron) | En test, una oferta vence a los X días y desaparece del feed | T-030 |
| T-034 | Compartir oferta: deep link + preview web pública mínima | El link abre la app (instalada) o una preview web | T-030 |

### Bloque G — Discovery (feeds, búsqueda, filtros)

| ID | Tarea | Criterio verificable | Dep. |
|---|---|---|---|
| T-035 | Feed de ofertas para candidato (recencia + zona + categoría), paginación keyset | Test de integración con seeds: orden y paginación estables | T-030 |
| T-036 | Feed de candidatos para empresa (alcance según plan) | Test RLS + test de límites por plan | T-024, T-031 |
| T-037 | Búsqueda full-text en español (tsvector + trigram para typos) | Buscar "moso" encuentra "mozo" (test) | T-035 |
| T-038 | Filtros combinables: zona/barrio, categoría, disponibilidad, experiencia | Tests de combinaciones de filtros contra seeds | T-035 |
| T-039 | Feed de tarjetas con video embebido (UX_FLOWS §6.1): tarjeta de oferta/candidato con player integrado, precarga acotada y modo ahorro de datos | En gama media: scroll fluido; nunca precarga más de N videos (verificado por logs de red) | T-054, T-035 |
| T-083 | Ofertas guardadas (SPEC §5; UX_FLOWS §13): guardar/quitar desde feed y detalle, lista "Guardadas" + aviso de vencimiento próximo de una oferta guardada | Guardar/quitar persiste y solo el dueño ve su lista (test RLS); el aviso de vencimiento llega según `notification_prefs` (test) | T-035, T-033, T-064 |

### Bloque H — Postulaciones + invitaciones

| ID | Tarea | Criterio verificable | Dep. |
|---|---|---|---|
| T-040 | Postulación 1-tap con video-CV adjunto; estados enviada/vista/preseleccionada/rechazada/**retirada** (`withdrawn`, ya previsto en DATA_MODEL); el candidato puede **retirar su postulación** (UX_FLOWS §8.4) | Tests de transiciones + RLS (solo candidato y empresa dueña ven la postulación); retirar pasa a `withdrawn` y la saca de la bandeja activa de la empresa (test) | T-039, T-025 |
| T-041 | Anti-spam: tope diario de postulaciones y no-duplicadas por oferta | Test: la N+1 del día falla server-side; repostular a la misma oferta falla | T-040 |
| T-042 | Invitación de empresa a candidato a postular | Invitación genera notificación y aparece en bandeja del candidato | T-036, T-064 |
| T-043 | Bandeja de gestión para empresa (columnas por estado) | Mover un candidato de estado persiste y notifica según prefs | T-040 |

### Bloque I — Match

| ID | Tarea | Criterio verificable | Dep. |
|---|---|---|---|
| T-044 | Regla de match (UX_FLOWS §10, dos caminos): **postulación del candidato + aceptación de la empresa**, o **invitación de empresa aceptada por el candidato** — sin pasos extra | Ambos caminos crean una única fila `match`; operación idempotente (test de doble tap por cada camino) | T-040, T-042 |
| T-045 | Desbloqueo de contacto/chat solo con match | Test RLS: sin match no existe conversación posible | T-044 |
| T-046 | Notificación de match a ambas partes | Push + entrada in-app en ambos dispositivos de prueba | T-044, T-064 |

### Bloque J — Chat

| ID | Tarea | Criterio verificable | Dep. |
|---|---|---|---|
| T-047 | Chat 1-a-1 texto sobre Supabase Realtime | Mensaje llega en <2 s entre dos dispositivos en staging | T-045 |
| T-048 | RLS de mensajes: solo participantes de la conversación | Suite RLS: un tercero no lee ni escribe | T-047 |
| T-049 | Leído/no leído + badge de no leídos | Contador correcto en tests (incluye mensajes offline) | T-047 |
| T-050 | Acceso a "bloquear" y "denunciar" desde el chat — **sin adjuntos en la primera versión** (UX_FLOWS §11.2; adjuntos = post-MVP) | Bloquear corta el chat (ver T-073); denunciar desde el chat crea caso en admin (ver T-072) | T-047, T-073 |

### Bloque K — Video pipeline (Cloudflare Stream)

| ID | Tarea | Criterio verificable | Dep. |
|---|---|---|---|
| T-051 | Edge Function que crea direct creator upload URL de Stream y mapea `video_id` propio ↔ `uid` de Stream (con `maxDurationSeconds` acotado) | URL de un solo uso generada server-side; el API token jamás llega al cliente (revisión de tráfico) | T-006, T-009 |
| T-052 | Grabación in-app (cámara frontal, límite **20–30 s** según SPEC §5 y UX_FLOWS, retakes) + subida con progreso y reintentos (POST simple: clips cortos <100 MB, límite unificado con SECURITY.md §7) | Subida exitosa bajo red móvil inestable simulada; grabar más de 30 s es imposible en UI y rechazado por `maxDurationSeconds` (test); reserva de minutos se libera si se cancela | T-051 |
| T-053 | Webhook de Stream → estado `procesando/listo/error` en DB (+ polling de fallback) | Al terminar el encoding, el video pasa a `listo` sin acción manual | T-051 |
| T-054 | Playback HLS detrás de una interfaz propia de player (abstracción anti lock-in) + signed URLs | Video privado no reproducible con URL vencida (test); swap de player no toca lógica de negocio | T-053 |
| T-055 | Copia del archivo original a almacenamiento propio (R2/Storage) al subir — estrategia de salida de ARCHITECTURE.md. *Decisión a validar por costo (R2 a cotizar; no incluido en la investigación de precios)* | Tras un upload, el objeto original existe fuera de Stream | T-052 |
| T-056 | Captions automáticas en español (generated captions de Stream, sin costo extra) + toggle en player | VTT disponible vía API y subtítulos renderizados en el player | T-053 |
| T-057 | Estado de moderación de video (`pendiente/aprobado/rechazado`); en beta auto-aprobar con revisión posterior | Video `rechazado` no aparece en ningún feed (test RLS/query) | T-053, T-077 |
| T-084 | Alternativas de presentación en **audio o texto con igual jerarquía que el video** (SPEC §5; UX_FLOWS §4): grabar audio o escribir presentación como reemplazo pleno del video-CV | Un perfil con presentación solo en audio o solo en texto se muestra completo y sin penalización en feed y detalle (widget test); audio servido con URL firmada; el banner de T-023 no aparece si hay alternativa cargada | T-021, T-023 |

### Bloque L — IA (Anthropic)

| ID | Tarea | Criterio verificable | Dep. |
|---|---|---|---|
| T-058 | Capa `LLMService`: interfaz propia + adaptador Anthropic; prompts versionados en archivos; logging de `usage` (tokens/costo) por request | Cambiar de modelo es un cambio de config; cada llamada loguea costo | T-006 |
| T-059 | Teleprompter IA: guion personalizado para el video-CV a partir del perfil (Haiku 4.5: USD 1/5 por MTok in/out) | Guion es-AR <400 palabras en <5 s p95, sobre 20 perfiles de prueba | T-058, T-021 |
| T-060 | Oferta estructurada: texto libre de la empresa → JSON validado del esquema de oferta (Sonnet 5: USD 2/10 por MTok, con prompt caching del system prompt) | ≥95% de 50 casos de prueba parsean al esquema sin corrección manual | T-058, T-030 |
| T-061 | Ingesta de transcripción (VTT de T-056) → resumen + keywords del video-CV para búsqueda, vía Batch API nocturna (−50%) | Campos poblados en DB tras el job; costo por video registrado | T-056, T-058 |
| T-062 | Guardrails de costo IA: presupuesto mensual, alertas de desvío, kill-switch por feature | Superar el umbral en staging dispara alerta y apaga la feature no crítica | T-058 |

### Bloque M — Notificaciones

| ID | Tarea | Criterio verificable | Dep. |
|---|---|---|---|
| T-063 | FCM + APNs (firebase_messaging) con registro de tokens por dispositivo | Push de prueba llega a Android e iOS reales | T-014 |
| T-064 | Edge Function de envío + plantillas por evento (match, mensaje, postulación, invitación) respetando `notification_prefs` | Cada evento genera push solo si el usuario tiene el canal activado (tests) | T-063, T-019 |
| T-065 | Emails transaccionales con Resend (verificación, resumen semanal a empresas) — Free: 3.000/mes, máx 100/día | Emails entregados y renderizados OK en Gmail/Outlook | T-011 |
| T-066 | Centro de notificaciones in-app con histórico | Histórico persistido y marcable como leído | T-064 |

### Bloque N — Billing (Mercado Pago Suscripciones)

| ID | Tarea | Criterio verificable | Dep. |
|---|---|---|---|
| T-067 | Capa `BillingService` abstracta + tablas `subscriptions`/`invoices` (estados: trial, activa, morosa, cancelada) | Máquina de estados testeada sin tocar MP | T-006 |
| T-068 | Alta de suscripción vía MP (preapproval) desde checkout **web** — fuera de los stores (0% comisión de store) | Suscripción de prueba en sandbox cobra y activa el plan | T-067 |
| T-069 | Webhooks MP idempotentes: aprobado/rechazado/cancelado → activación/gracia/downgrade automáticos | Reenviar el mismo webhook N veces produce un solo cambio de estado (test) | T-068 |
| T-070 | Enforcement de plan server-side (límites de ofertas, alcance de feed de candidatos) | Tests por plan: free capado, pago habilitado; nada se decide solo en el cliente | T-069, T-031 |
| T-071 | Datos fiscales del cliente al suscribir + circuito de facturación (MVP: emisión manual con contador; automatizar post-MVP) — *a validar con contador* | No se puede suscribir sin CUIT/condición fiscal completos | T-068 |

### Bloque O — Moderación + denuncias + bloqueos

| ID | Tarea | Criterio verificable | Dep. |
|---|---|---|---|
| T-072 | Denuncias sobre usuario, oferta, video o mensaje, con motivos tipificados | La denuncia crea fila `reports` y aparece en el panel admin | T-006, T-077 |
| T-073 | Bloqueo usuario↔empresa: oculta contenido mutuo y corta el chat | Suite RLS: el bloqueado no ve ni escribe nada del bloqueante | T-047 |
| T-074 | Moderación IA de textos (ofertas, perfiles, mensajes) con Haiku: score + cola de revisión. Foco: avisos discriminatorios (riesgo legal en avisos de empleo) | Set de casos de prueba discriminatorios detectados ≥ umbral definido | T-058 |
| T-075 | Flujo de sanciones (advertencia, suspensión, ban) con auditoría de quién/cuándo/por qué | Cada sanción queda en `audit_log`; usuario suspendido no opera (test) | T-072, T-077 |
| T-085 | Apelación de sanciones (UX_FLOWS §16.6): el sancionado ve el motivo y puede apelar; la apelación entra a una cola de revisión humana en el panel admin; resolución (mantener/revertir) notificada y auditada | La apelación crea caso en la cola admin; resolver impacta el estado del usuario, lo notifica y queda en `audit_log` (test) | T-075, T-077 |

### Bloque P — Panel admin

| ID | Tarea | Criterio verificable | Dep. |
|---|---|---|---|
| T-076 | Panel admin web con rol admin + 2FA | Solo rol admin entra (test de integración) | T-015 |
| T-077 | Colas operativas: verificación CUIT, denuncias, moderación de videos | Aprobar/rechazar desde el panel impacta el estado en la app | T-076 |
| T-078 | Métricas operativas: usuarios, ofertas, matches, videos, costo IA/Stream del mes | Números del dashboard coinciden con queries SQL de control | T-076 |
| T-079 | Gestión de suscripciones: estado, baja manual, cupones beta | Toda acción queda auditada en `audit_log` | T-076, T-069 |

### Bloque Q — Exportación / eliminación de cuenta

| ID | Tarea | Criterio verificable | Dep. |
|---|---|---|---|
| T-080 | Exportación de datos del usuario (JSON + links a media) — derecho de acceso, Ley 25.326 (ver PRIVACY.md) | Export generado en <48 h y completo contra checklist de tablas con PII | T-006 |
| T-081 | Eliminación de cuenta **in-app** (requisito de App Store y Play): soft-delete + purga programada ≤30 días que borra DB, Storage, tokens y videos en Stream | Tras la purga, query de verificación no encuentra PII ni media del usuario | T-080, T-053 |
| T-082 | Log de auditoría de eliminaciones sin PII (qué se borró, cuándo, por qué vía) | Registro existe y no contiene datos personales | T-081 |

---

## 3. Fichas por feature del MVP

Los costos "mensual: cero (dentro de Supabase Pro)" refieren a la base de **USD 25/mes** del plan Pro (única para todo el producto, cargada una sola vez en el Excel de costos). Todos los valores citados: verificados 2026-08-12; detalle y proyecciones en el Excel de costos.

### F-01 Auth
- **Objetivo:** cuentas confiables con mínimo rebote (email + Google/Apple), base de identidad para RLS.
- **Dependencias:** Bloque A (T-011…T-015 dependen de T-006).
- **Acceptance criteria:** ☐ signup/login email verificado ☐ OAuth Google y Apple en dispositivos reales ☐ reset de password E2E ☐ sesión persiste y logout limpia tokens ☐ roles aplicados en navegación y en RLS.
- **Tests:** unit (validaciones), widget (formularios), integration (flujos E2E), RLS (roles y ownership).
- **Riesgos:** deep links mal configurados (iOS Universal Links); rechazo de App Store si falta Sign in with Apple junto a Google.
- **Costos:** inicial cero · mensual cero (dentro de Supabase Pro, incluye 100.000 MAU) · variable: USD 0,00325/MAU por encima de 100.000 (Supabase).
- **Privacidad:** email, hash de password, proveedor OAuth. Consentimiento: TyC + privacidad en registro (T-018). Retención: hasta eliminación de cuenta (F-16).

### F-02 Onboarding + consentimientos
- **Objetivo:** que candidato y empresa lleguen a "perfil útil" en <3 minutos, con base legal registrada.
- **Dependencias:** F-01.
- **Acceptance criteria:** ☐ wizard candidato y empresa completos ☐ cada consentimiento queda versionado con timestamp ☐ cambio de versión de un doc re-solicita aceptación ☐ opt-in de notificaciones explícito.
- **Tests:** widget (wizards), integration (persistencia), unit (versionado de consents), RLS (consents solo del dueño).
- **Riesgos:** fricción de onboarding mata activación (medir drop-off por paso, PRODUCT.md §métricas).
- **Costos:** inicial cero · mensual cero · variable cero.
- **Privacidad:** es la feature que **crea** la base de consentimiento (video, IA, notificaciones). Retención de `consents`: mientras exista la cuenta + lo que exija PRIVACY.md como prueba.

### F-03 Perfiles
- **Objetivo:** perfil de candidato orientado a gastronomía (disponibilidad, zona, experiencia) que alimenta discovery e IA.
- **Dependencias:** F-02.
- **Acceptance criteria:** ☐ CRUD completo con RLS ☐ foto con thumbnail y URL firmada ☐ score de completitud correcto ☐ empresa sin match no ve contacto.
- **Tests:** unit (score), widget (edición), integration, RLS (visibilidad por rol y por match).
- **Riesgos:** exponer de más un perfil (privacidad) o de menos (matching pobre) — las reglas de visibilidad viven en PRODUCT.md y se testean acá.
- **Costos:** inicial cero · mensual cero (fotos dentro de los 100 GB de Storage incluidos) · variable: USD 0,0213/GB-mes por encima de 100 GB (Supabase Storage).
- **Privacidad:** nombre, foto, zona, historial laboral. Consentimiento: privacidad (registro). Retención: hasta eliminación; export incluido en F-16.

### F-04 Empresas + verificación CUIT
- **Objetivo:** solo empresas reales publican — confianza es el activo del marketplace.
- **Dependencias:** F-02; panel admin (F-15) para la revisión.
- **Acceptance criteria:** ☐ CUIT validado por dígito verificador en server ☐ estado `pendiente→verificada` operable desde admin ☐ empresa no verificada no publica ☐ badge visible.
- **Tests:** unit (algoritmo CUIT), integration (flujo de estados), RLS (miembros de empresa), widget (badge).
- **Riesgos:** verificación manual no escala (aceptable en MVP: decenas/semana); API de padrón ARCA post-MVP a cotizar.
- **Costos:** inicial cero · mensual cero · variable cero (MVP manual; tiempo del founder).
- **Privacidad:** CUIT y razón social (datos societarios, sensibilidad baja; igualmente exportables). Retención: mientras la empresa exista.

### F-05 Ofertas
- **Objetivo:** publicar una búsqueda en <3 minutos (con ayuda de IA en F-11), con límites por plan.
- **Dependencias:** F-04; límites dependen de F-13 (planes).
- **Acceptance criteria:** ☐ estados draft/activa/pausada/cerrada ☐ sueldo o rango salarial obligatorio (publicar sin salario falla server-side) ☐ candidatos solo ven activas ☐ límite por plan server-side ☐ expiración automática ☐ deep link público.
- **Tests:** unit (transiciones), integration (expiración con pg_cron), RLS (dueña edita, resto lee activas), widget (form).
- **Riesgos:** ofertas basura/duplicadas degradan el feed → moderación IA (F-14) y límites free.
- **Costos:** inicial cero · mensual cero · variable cero.
- **Privacidad:** contenido público de la empresa; sin PII de candidatos.

### F-06 Discovery (feeds, búsqueda, filtros)
- **Objetivo:** el corazón del producto: feed de tarjetas con video embebido (UX_FLOWS §6.1) para candidatos y feed de candidatos para empresas.
- **Dependencias:** F-05, F-10 (playback), F-03.
- **Acceptance criteria:** ☐ feeds paginados estables ☐ búsqueda tolera typos en español ☐ filtros combinables ☐ scroll fluido en gama media ☐ precarga acotada (ahorro de datos) ☐ ofertas guardadas con aviso de vencimiento (T-083).
- **Tests:** integration (orden/paginación/filtros contra seeds), RLS (alcance por plan), widget (feed), performance manual en dispositivo de gama media.
- **Riesgos:** costo de delivery crece con el scroll (cada minuto visto se paga — ver F-10); mitigación: precarga acotada + thumbnails.
- **Costos:** inicial cero · mensual cero · variable: el video visto se paga en F-10 (USD 1/1.000 min); egress de API/imágenes dentro de los 250 GB de Supabase (excedente USD 0,09/GB, cached USD 0,03/GB).
- **Privacidad:** expone perfiles según reglas de visibilidad de PRODUCT.md; sin datos de contacto pre-match.

### F-07 Postulaciones + invitaciones
- **Objetivo:** postulación 1-tap con video, gestión tipo pipeline para la empresa.
- **Dependencias:** F-06, F-03 (score de completitud como gating).
- **Acceptance criteria:** ☐ estados completos y notificados ☐ el candidato puede retirar su postulación (`withdrawn`, UX_FLOWS §8.4) ☐ anti-spam (tope diario, no duplicados) ☐ invitaciones empresa→candidato ☐ bandeja kanban persiste.
- **Tests:** unit (reglas anti-spam), integration (flujo completo), RLS (solo las partes ven la postulación), widget (bandeja).
- **Riesgos:** spam de postulaciones degrada la experiencia empresa (métrica de calidad en PRODUCT.md).
- **Costos:** inicial cero · mensual cero · variable cero.
- **Privacidad:** vincula candidato↔empresa; visible solo para las partes. Retención: histórico mientras exista la cuenta; anonimizar al eliminar (F-16).

### F-08 Match
- **Objetivo:** interés mutuo explícito como compuerta de contacto — el momento "wow" del producto.
- **Dependencias:** F-07.
- **Acceptance criteria:** ☐ match único e idempotente ☐ sin match no hay chat (RLS) ☐ notificación a ambas partes.
- **Tests:** unit (idempotencia), integration, RLS (compuerta de chat).
- **Riesgos:** reglas de match confusas matan la conversión — validar copy en beta.
- **Costos:** inicial cero · mensual cero · variable cero.
- **Privacidad:** el match desbloquea datos de contacto: es un evento de consentimiento implícito documentado en PRIVACY.md.

### F-09 Chat
- **Objetivo:** coordinación de entrevista dentro de la app (retención + datos de conversión).
- **Dependencias:** F-08.
- **Acceptance criteria:** ☐ entrega <2 s ☐ solo participantes leen/escriben ☐ leído/no leído ☐ sin adjuntos en la primera versión (UX_FLOWS §11.2; adjuntos = post-MVP) ☐ bloquear y denunciar accesibles desde el chat; bloquear corta el chat.
- **Tests:** integration (dos dispositivos), RLS (terceros excluidos), unit (badges), widget.
- **Riesgos:** Realtime es la pieza más propietaria de Supabase (plan de salida en ARCHITECTURE.md); conexiones pico se pagan caras a escala.
- **Costos:** inicial cero · mensual cero (incluye 500 conexiones pico y 5M mensajes) · variable: USD 2,50/1M mensajes y USD 10/1.000 conexiones pico extra (Supabase Realtime).
- **Privacidad:** contenido de conversaciones (PII probable). Retención: mientras dure la cuenta; incluido en export y purga (F-16).

### F-10 Video pipeline
- **Objetivo:** grabar, subir, procesar y reproducir video-CVs verticales de 20–30 s (opcionales, con alternativa de audio/texto de igual jerarquía — SPEC §5) con captions en español, sin exponer tokens.
- **Dependencias:** Bloque A; el resto del producto depende de esto.
- **Acceptance criteria:** ☐ direct upload sin token en cliente ☐ límite 20–30 s aplicado en UI y server ☐ webhook actualiza estado ☐ HLS con signed URLs ☐ captions es automáticas ☐ alternativa de presentación en audio/texto con igual jerarquía (T-084) ☐ (si se aprueba T-055) original copiado fuera de Stream.
- **Tests:** integration (upload→ready→playback), unit (máquina de estados), RLS (metadata de videos), manual en red móvil mala.
- **Riesgos:** **storage prepago = hard stop**: si se agota el cupo comprado, nadie puede subir videos hasta comprar más (monitoreo + auto-compra de incrementos de USD 5); descargas MP4 se facturan como delivery completo (cuidado con "descargar CV"); tope 1080p (suficiente para móvil).
- **Costos:** inicial cero · mensual: piso práctico USD 5 (mínimo de storage prepago) · variable: **USD 5/1.000 min almacenados-mes + USD 1/1.000 min vistos** (Cloudflare Stream; encoding, ingesta, ancho de banda y captions incluidos). Alternativas a revisar si delivery >500k min/mes: Bunny ~5–10x más barato, Mux con 100k min/mes gratis (ver el Excel de costos).
- **Privacidad:** el video-CV es el dato personal más sensible del producto (imagen + voz). Consentimiento específico de video (T-018). Retención: hasta eliminación; la purga (F-16) debe borrar en Stream y en la copia propia.

### F-11 IA (teleprompter, oferta estructurada, transcripción)
- **Objetivo:** bajar la fricción de crear video-CVs y ofertas, y hacer los videos buscables.
- **Dependencias:** F-03, F-05, F-10 (captions como insumo de T-061).
- **Acceptance criteria:** ☐ guion en <5 s p95 ☐ ≥95% de ofertas parsean al esquema ☐ resúmenes/keywords poblados por job nocturno ☐ presupuesto con alertas y kill-switch ☐ proveedor detrás de interfaz propia.
- **Tests:** unit (parsers/esquemas), integration (jobs batch), evals propios (set de casos por prompt, corre en CI nightly).
- **Riesgos:** dependencia de un proveedor (mitigada por capa de abstracción + prompts versionados + evals); el tokenizer de Sonnet 5 produce ~30% más tokens que la generación anterior — medir con `count_tokens`, no estimar de memoria.
- **Costos:** inicial cero · mensual cero fijo · variable: Sonnet 5 USD 2/10 por MTok (in/out), Haiku 4.5 USD 1/5, Fable 5 USD 10/50 (solo si un caso lo justifica); Batch API −50%; cache read 0,1× input. Estrategia: Sonnet para estructurar, Haiku para clasificar, Batch+caching para lo nocturno. Proyección de consumo: ver el Excel de costos.
- **Privacidad:** perfiles y transcripciones pasan por la API de Anthropic (stateless; requiere retención de 30 días del proveedor para Fable 5). Consentimiento de procesamiento por IA (T-018). No enviar datos de contacto en prompts.

### F-12 Notificaciones
- **Objetivo:** traer de vuelta al usuario en los 4 momentos que importan: match, mensaje, postulación, invitación.
- **Dependencias:** F-01; consumida por F-07/F-08/F-09.
- **Acceptance criteria:** ☐ push llega a Android e iOS reales ☐ prefs respetadas por evento ☐ emails transaccionales entregados ☐ centro in-app con histórico.
- **Tests:** integration (envío por evento), unit (plantillas y prefs), manual en dispositivos.
- **Riesgos:** exceso de notificaciones → opt-out masivo; límite diario de Resend Free (100/día) puede quedar corto en beta → pasar a Pro o SES.
- **Costos:** inicial cero · mensual cero (FCM gratis a cualquier volumen; APNs incluido en la membresía Apple ya contada; Resend Free 3.000/mes) · variable: al superar Free, Resend Pro USD 20/mes (50k emails) o SES USD 0,10/1.000 — decisión en el Excel de costos.
- **Privacidad:** tokens de dispositivo y email. Consentimiento: opt-in por canal (T-019). Retención: tokens purgados al logout/eliminación.

### F-13 Billing (Mercado Pago Suscripciones)
- **Objetivo:** cobrar suscripciones B2B en ARS por **web** (fuera de los stores → 0% de comisión Apple/Google).
- **Dependencias:** F-05 (límites), F-15 (gestión); empresa verificada (F-04).
- **Acceptance criteria:** ☐ alta en sandbox cobra y activa ☐ webhooks idempotentes con gracia y downgrade ☐ enforcement server-side por plan ☐ datos fiscales obligatorios al suscribir.
- **Tests:** unit (máquina de estados), integration (webhooks simulados, incluyendo replays), RLS (subscriptions solo de la empresa).
- **Riesgos:** lock-in de tarjetas tokenizadas en MP (migrar = re-onboarding con churn 10–30% → capa `BillingService` desde el día uno); MP cambia comisiones unilateralmente; retenciones IIBB/SIRTAC reducen el neto acreditado.
- **Costos:** inicial cero · mensual cero · variable: comisión MP por cobro según plazo de liberación — 6,99% (inmediato), 4,49% (10 días), 3,39% (18 días), 1,49% (35 días), **siempre + IVA 21% sobre la comisión** (efectivos: 8,46% / 5,43% / 4,10% / 1,80%). Recomendación inicial: 18 días (4,10% efectivo) como balance margen/caja — *propuesta a validar*. Precio del plan entry sugerido por benchmark: ARS 25.000–40.000/mes, por debajo del aviso suelto de la competencia (~ARS 48.000–70.000) — *propuesta a validar*.
- **Privacidad:** TalentFlash no ve tarjetas (tokenización en MP); guarda CUIT y datos fiscales. Retención: obligaciones fiscales (definir con contador en PRIVACY.md).

### F-14 Moderación + denuncias + bloqueos
- **Objetivo:** confianza y cumplimiento: sin avisos discriminatorios, sin acoso, con trazabilidad.
- **Dependencias:** F-05, F-09, F-10 (videos), F-15 (colas de revisión), F-11 (clasificador).
- **Acceptance criteria:** ☐ denunciar cualquier objeto crea caso en admin ☐ bloqueo corta visibilidad y chat (RLS) ☐ clasificador detecta el set de casos discriminatorios ☐ sanciones auditadas ☐ apelación de sanciones con revisión humana y resolución auditada (T-085).
- **Tests:** RLS (bloqueos), unit (motivos/estados), integration (denuncia→revisión→sanción), evals del clasificador.
- **Riesgos:** legal: un aviso discriminatorio publicado es responsabilidad reputacional/regulatoria; humano-en-el-loop obligatorio para sanciones en MVP.
- **Costos:** inicial cero · mensual cero · variable: clasificación con Haiku 4.5 (USD 1/5 por MTok — orden de centavos por mil textos; referencia oficial: ~10.000 textos cortos ≈ USD 37 con Haiku).
- **Privacidad:** denuncias contienen PII de denunciante y denunciado; acceso solo admin; retención según PRIVACY.md (prueba ante disputas).

### F-15 Panel admin
- **Objetivo:** operar el marketplace (verificaciones, moderación, métricas, suscripciones) sin tocar la DB a mano.
- **Dependencias:** F-01 (rol admin); da servicio a F-04, F-10, F-13, F-14.
- **Acceptance criteria:** ☐ solo admin con 2FA ☐ colas de CUIT/denuncias/videos operativas ☐ métricas coinciden con SQL de control ☐ acciones auditadas.
- **Tests:** integration (cada acción admin impacta la app), RLS (rol admin), unit (auditoría).
- **Riesgos:** el admin es superficie de ataque: 2FA obligatorio, sin URLs públicas, auditoría total.
- **Costos:** inicial cero · mensual cero (hosting dentro del stack existente) · variable cero.
- **Privacidad:** acceso amplio a PII → mínimo privilegio, logs de acceso, cuentas nominales.

### F-16 Exportación / eliminación de cuenta
- **Objetivo:** cumplir Ley 25.326 y requisitos de App Store/Google Play (eliminación in-app obligatoria).
- **Dependencias:** transversal a todas las tablas; F-10 (borrar videos en Stream).
- **Acceptance criteria:** ☐ export completo contra checklist de tablas con PII ☐ eliminación in-app con purga ≤30 días ☐ purga borra DB + Storage + Stream + tokens ☐ auditoría sin PII.
- **Tests:** integration (export y purga E2E), unit (checklist de tablas generada del esquema), query de verificación post-purga en CI.
- **Riesgos:** olvidar una tabla/bucket nueva en la purga → la checklist debe generarse del esquema, no mantenerse a mano.
- **Costos:** inicial cero · mensual cero · variable: si el export incluye descarga MP4 de los videos, cada descarga se factura como minutos entregados en Stream (USD 1/1.000 min) — preferir links firmados temporales.
- **Privacidad:** es la feature que garantiza los derechos ARCO; su DoD incluye revisión contra PRIVACY.md.

---

## 4. Definition of Done (global, por tarea y por feature)

Una tarea/feature está terminada solo si:

1. `flutter analyze` limpio (cero warnings nuevos) y formatter aplicado.
2. Tests verdes en CI: unit + widget de lo tocado; integration si toca flujo; **RLS testeada si toca datos** (política nueva o cambiada = test nuevo).
3. Sin secretos en código ni en historial (scan de CI verde).
4. Migraciones SQL versionadas (nada aplicado por dashboard sin migración).
5. Docs actualizados si cambió el contrato: ARCHITECTURE.md (diseño), PRODUCT.md/UX_FLOWS.md (comportamiento), este ROADMAP.md (estado de la tarea).
6. **Impacto de costos registrado en COST_DECISIONS.md y en el Excel de costos** (`02_business_e_costi/Costi_TalentFlash_Argentina.xlsx`) si la feature agrega consumo variable (Stream, IA, email, MP) — con el driver y el precio unitario citado.
7. Errores manejados y visibles en Sentry (sin `catch` silenciosos en flujos críticos).
8. Copys en es-AR revisados.
9. **Pasada de accesibilidad AA** (contraste, lector de pantalla, teclado en Web) sobre las pantallas tocadas, con el checklist de UX_FLOWS §20 (ver T-086).

---

## 5. Hitos y gates de decisión

Las métricas objetivo son **propuestas a validar** contra PRODUCT.md §métricas (fuente de verdad de definiciones y valores). Cada gate es una decisión explícita del fundador: seguir, corregir o frenar.

| Gate | Cuándo | Métrica / evidencia | Umbral propuesto (*a validar*) | No-go → acción |
|---|---|---|---|---|
| **GV** | Fin Validación (fase 1) | Entrevistas realizadas; empresas dispuestas a probar la beta; lista de espera de la landing | ≥30 entrevistas · ≥10 empresas comprometidas · tracción en lista de espera | Repensar segmento/propuesta de valor antes de construir |
| **G0** | Fin Prototipo (fase 2) | CI verde; suite RLS pasa; secretos limpios; prototipo navegable | 100% binario | No se construye features sobre fundaciones rotas |
| **G1** | Fin MVP (fase 3) | Demo E2E sin intervención manual; DoD en todos los bloques; costo mensual real | E2E completo; costo ≤ presupuesto del Excel de costos | Recortar alcance del MVP (candidato natural: video de oferta T-032; el resto del alcance está exigido por SPEC §5) |
| **G2** | Fin Beta privada (fase 4) | Activación: % empresas que publican ≥1 oferta en 7 días; % candidatos con video-CV; % ofertas con ≥1 match en 14 días; tiempo a primer candidato | ≥50% · ≥40% · ≥30% · <48 h | Iterar onboarding/discovery 4 semanas más; no lanzar billing sin activación |
| **G3** | Lanzamiento (fase 5) + 90 días | Conversión free→pago; retención empresa M2; churn mensual; costo variable por empresa activa | ≥8% · ≥60% · <10% · margen positivo con plan entry | Revisar pricing/planes (PRODUCT.md), costos (mix Stream/IA) o segmento |
| **G4** | Trimestral (Crecimiento, fase 6) | Métricas norte de PRODUCT.md + revisión de precios de proveedores (los precios citados cambian) | según PRODUCT.md | Re-priorizar backlog; renegociar/migrar proveedores según plan de salida de ARCHITECTURE.md |

---

## 6. Riesgos de plan

| # | Riesgo | Impacto | Mitigación |
|---|---|---|---|
| 1 | **Solo-founder**: bus factor 1, estimaciones de §1 sin holgura de equipo | Retrasos en cadena; burnout | Tareas ≤2–3 días con criterio verificable (§2); recortes pre-acordados en G1; docs al día para poder sumar ayuda rápido |
| 2 | **Presupuesto en USD con ingresos en ARS**: riesgo cambiario + percepción 30% (RG 5617) en pagos al exterior con tarjeta | Costos suben sin aviso en ARS | Buffer 15–30% sobre TC en el Excel de costos; pagar resúmenes en USD (MEP) para evitar la percepción; revisar TC mensual |
| 3 | **Cadena de dependencias técnica**: video (Bloque K) bloquea discovery, postulaciones e IA | Un problema con Stream frena el corazón del producto | Bloque K empieza apenas termina A (paralelo a B–F); spike de upload/playback en la semana 3 como prueba de riesgo |
| 4 | **Storage prepago de Stream = hard stop de uploads** | UGC frenado en pleno crecimiento | Alerta de cupo + auto-compra de incrementos (USD 5/1.000 min); métrica en panel admin (T-078) |
| 5 | **Dependencia de proveedores** (Supabase, Stream, Anthropic, MP) con precios que ya cambiaron históricamente | Margen erosionado; migraciones forzadas | Capas de abstracción (player, LLMService, BillingService, repositorio de datos); planes de salida documentados en ARCHITECTURE.md; revisión trimestral de precios (G4) |
| 6 | **Regulatorio/fiscal AR**: comisiones MP + IIBB + Ganancias + normas que cambian a mitad de año | Unit economics distintos a lo proyectado | Contador desde el Lanzamiento (fase 5; estimación ARS 200–500 mil/mes); todos los valores fiscales marcados "a confirmar" en el Excel de costos |
| 7 | **Los incumbentes tienen tier gratis** (Bumeran/Zonajobs/LinkedIn capados): TalentFlash no compite solo contra avisos pagos | Adquisición más difícil de lo previsto | Tier gratuito propio limitado en ofertas activas pero con acceso completo a candidatos (regla de PRODUCT.md); el gate G3 valida el pricing entry *propuesta a validar* |
| 8 | **Calidad Whisper/captions en español rioplatense** sin validar | Transcripciones pobres → búsqueda e IA degradadas | Validar en semana 1 del Bloque K con 20 videos reales; fallback: transcripción propia vía Batch API (costo en el Excel de costos) |

---

*Fin del documento. Próximo paso: revisión del fundador — fijar los umbrales del §5 con PRODUCT.md y aprobar los ítems marcados "propuesta a validar".*
