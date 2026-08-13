# COST_DECISIONS.md — Registro de decisiones de costo · TalentFlash Argentina

**Última actualización:** 2026-08-12
**Estado:** aprobación parcial — D-004, D-014, D-015 y el bloque «Decisiones aprobadas — 12-08-2026» aprobados el 12-08-2026 por el fundador; el resto sigue en `propuesta`

> Documentos relacionados: [PRODUCT.md](PRODUCT.md) · [ARCHITECTURE.md](ARCHITECTURE.md) · [DATA_MODEL.md](DATA_MODEL.md) · [SECURITY.md](SECURITY.md) · [PRIVACY.md](PRIVACY.md) · [UX_FLOWS.md](UX_FLOWS.md) · [ROADMAP.md](ROADMAP.md)

---

## 1. Reglas del registro

1. **Este documento es el log TÉCNICO de decisiones de costo.** El modelo económico completo (proyecciones, márgenes, pricing B2B) vive en `02_business_e_costi/Costi_TalentFlash_Argentina.xlsx`, **fuera de `01_app/`**. Nunca copiar el Excel (ni extractos de sus hojas) dentro de este documento ni dentro de `01_app/`.
2. **Toda decisión que pase a estado "aprobada" debe reflejarse en el Excel** en el mismo commit/sesión en que se aprueba. Si el Excel no se actualizó, la decisión no está realmente aprobada.
3. **Nunca modificar un precio histórico sin nota de revisión.** Si un proveedor cambia su tarifa, se agrega una fila/nota "Revisión AAAA-MM-DD" con el precio nuevo, la fuente y la fecha; el precio anterior queda visible como historial.
4. **Ningún SaaS, API o dependencia externa nueva entra al proyecto sin una entrada D-0XX en este registro** (ver §5). Esto incluye upgrades de plan del mismo proveedor.
5. Estados posibles de una decisión: `propuesta` → `aprobada` | `rechazada` | `revisar` (cuando cambian precios, límites o supuestos).
6. Los importes de proveedores se registran en su moneda original (USD casi siempre). La conversión a ARS se hace solo en el Excel, con el tipo de cambio de referencia del día (12-08-2026: oficial BNA venta **ARS 1.515/USD**, MEP **~ARS 1.525/USD** — fuentes en D-010).
7. Los tres escenarios de estimación son los del [ROADMAP.md](ROADMAP.md):
   - **Validación** — fases 1–2 (entrevistas, prototipo, landing), ~0–100 usuarios de prueba.
   - **MVP Argentina** — fases 3–5 (MVP + beta privada 50 empresas / 500 candidatos + lanzamiento CABA/GBA), volumen supuesto ≤ ~5.000 MAU.
   - **Crecimiento** — fase 6 (meses 11–18), volumen supuesto ~30.000–50.000 MAU y ~300–1.000 empresas activas.
   Los volúmenes de los escenarios son **supuestos propios (estimación a validar)**; los precios unitarios, en cambio, están verificados en la fuente indicada en cada decisión.

---

## 2. Plantilla de decisión

Toda entrada nueva copia esta plantilla:

```
### D-0XX — <Servicio / concepto>
| Campo | Valor |
|---|---|
| ID | D-0XX |
| Fecha | AAAA-MM-DD |
| Estado | propuesta / aprobada / rechazada / revisar |
| Decisión | <qué se decide y para qué se usa> |
| Precio + unidad + moneda | <ej.: 25 USD/mes> |
| Free tier | <qué incluye y si sirve> |
| Costo estimado — Validación | <USD/mes> |
| Costo estimado — MVP Argentina | <USD/mes> |
| Costo estimado — Crecimiento | <USD/mes> |
| Límites incluidos | <cuotas del plan> |
| Extras posibles | <overages, add-ons> |
| Lock-in | <bajo/medio/alto + por qué> |
| Exportación de datos | <cómo se sacan los datos> |
| Alternativa más barata comparada | <quién y a qué precio> |
| Estrategia de migración/salida | <pasos concretos> |
| Fuente (URL) | <página oficial> |
| Fecha de verificación | AAAA-MM-DD |
| Oficial / estimación | oficial / a confirmar / estimación |
```

---

## 3. Decisiones iniciales

Las decisiones de esta sección se registraron el 2026-08-12 en estado **`propuesta`**. Las marcadas como **`aprobada`** fueron aprobadas el **12-08-2026 por el fundador** (ver también el bloque «Decisiones aprobadas — 12-08-2026»); el resto sigue **pendiente de aprobación del fundador**. Precios verificados el **2026-08-12** contra las fuentes indicadas.

---

### D-001 — Supabase (backend: Postgres + Auth + Storage + Realtime + Edge Functions)

| Campo | Valor |
|---|---|
| ID | D-001 |
| Fecha | 2026-08-12 |
| Estado | propuesta |
| Decisión | Usar **Supabase Pro** como backend único del MVP (Postgres con RLS, Auth, Storage para imágenes/thumbnails, Realtime para chat, Edge Functions para lógica server-side y proxy de Claude API). Plan Free solo para dev/staging. Ver [ARCHITECTURE.md](ARCHITECTURE.md) y [DATA_MODEL.md](DATA_MODEL.md). |
| Precio + unidad + moneda | **25 USD/mes** (plan Pro, por organización) |
| Free tier | 500 MB DB, 1 GB storage, 5 GB egress (+5 GB cached), 50.000 MAU, 500k invocaciones Edge Functions, Realtime 200 conexiones / 2M mensajes. Se pausa tras 1 semana de inactividad, máx. 2 proyectos. **No apto para producción**; sí para dev/staging. |
| Costo estimado — Validación | **0 USD/mes** (Free para el prototipo) |
| Costo estimado — MVP Argentina | **25–35 USD/mes** (Pro + crédito de compute de 10 USD incluido, cubre 1 instancia Micro) — estimación a validar |
| Costo estimado — Crecimiento | **60–150 USD/mes** (Pro + compute Small/Medium 15–110 USD + excedentes menores de disco/egress) — estimación a validar |
| Límites incluidos (Pro) | 8 GB disco DB por proyecto; 100 GB file storage; 250 GB egress (+250 GB cached); 100.000 MAU Auth; 2M invocaciones Edge Functions; Realtime 500 conexiones pico / 5M mensajes; 10 USD/mes de crédito de compute; backups diarios 7 días; logs 7 días. |
| Extras posibles | Excedentes (con spend cap desactivado): disco DB **0,125 USD/GB-mes**; storage **0,0213 USD/GB-mes**; egress **0,09 USD/GB** (cached 0,03); MAU **0,00325 USD/MAU**; Edge Functions **2 USD/1M**; Realtime **2,50 USD/1M mensajes** y **10 USD/1.000 conexiones pico**. Compute add-ons: Micro 10 USD/mes hasta 16XL 3.730+ USD/mes. |
| Lock-in | **Medio-bajo (el mejor de su categoría BaaS).** Postgres estándar exportable con `pg_dump` (incluye RLS, que es SQL estándar); Auth (GoTrue) con hashes bcrypt exportables; Edge Functions en Deno/TS portables; Storage S3-compatible. El punto pegajoso es **Realtime** (protocolo propio Phoenix). Todo el stack es open source y self-hosteable. |
| Exportación de datos | `pg_dump/pg_restore` completo (esquema + datos + RLS); export de hashes de Auth; `rclone` para Storage; captions/archivos vía API. |
| Alternativa más barata comparada | **Firebase Blaze** (pay-per-use, arranque casi gratis: Firestore 0,06 USD/100k lecturas, 0,18 USD/100k escrituras; Auth 50k MAU gratis y luego desde 0,0055 USD/MAU; Functions 0,40 USD/1M tras 2M gratis) — descartado por lock-in NoSQL total y costo por lectura que castiga feeds. **Appwrite Pro** 25 USD/mes con cuotas mayores (2 TB bandwidth, 200k MAU) pero DB no-Postgres. **Neon** (Postgres serverless, 0,106 USD/CU-hora + 0,35 USD/GB-mes) no reemplaza Auth/Storage/Realtime: es destino de migración, no alternativa integral. |
| Estrategia de migración/salida | (1) Esquema y RLS en migraciones SQL versionadas (`supabase/migrations/`) desde el día uno; (2) no usar features del dashboard sin representación SQL; (3) cliente Supabase abstraído en Flutter detrás de repositorios propios (interfaces auth/storage/realtime); (4) ensayo mensual: `pg_dump` restaurado contra un Postgres Neon; (5) salida: DB→Neon/RDS (días), Auth→Clerk/Auth0 con import de hashes (1–2 semanas), Storage→R2 con rclone (días), Edge Functions→Cloudflare Workers (1–2 semanas), Realtime→Ably (2–4 semanas, lo más largo). |
| Fuente (URL) | https://supabase.com/pricing |
| Fecha de verificación | 2026-08-12 |
| Oficial / estimación | **oficial** (plan y excedentes); estimaciones de escenario propias |

**Riesgos anotados:** spend cap Pro activado por defecto (protege presupuesto pero frena el servicio al tope — decidir explícitamente qué hacer, ver §4); el costo oculto es el **compute** (los 25 USD solo cubren Micro); a 300k MAU el Auth solo costaría ~650 USD/mes; el egress se mantiene bajo porque el video pesado va por Cloudflare Stream (D-002).

---

### D-002 — Cloudflare Stream (video-CVs: upload, encoding, HLS, subtítulos)

| Campo | Valor |
|---|---|
| ID | D-002 |
| Fecha | 2026-08-12 |
| Estado | propuesta |
| Decisión | Usar **Cloudflare Stream** para todo el ciclo de video (direct creator uploads con URL firmada de un solo uso, encoding gratis, HLS, thumbnails, subtítulos IA en español sin costo). Guardar **siempre** copia del archivo original en Cloudflare R2 (egress gratis) como seguro de migración — costos de R2 registrados en **D-011**; esta decisión **no puede aprobarse antes que D-011** (regla §1.4). Ver [ARCHITECTURE.md](ARCHITECTURE.md) y [SECURITY.md](SECURITY.md) (URLs firmadas). |
| Precio + unidad + moneda | Storage: **5 USD por 1.000 minutos almacenados/mes** (prepago en incrementos de 5 USD). Delivery: **1 USD por 1.000 minutos vistos** (postpago; el ancho de banda está incluido). |
| Free tier | No hay free tier de Stream. Piso práctico ≈ **5 USD/mes** (mínimo de storage prepago) — dato "a confirmar" en el dashboard: la doc no declara un mínimo mensual formal. Encoding, ingesta, player, signed URLs y captions IA (12 idiomas, incl. español) incluidos sin costo extra. |
| Costo estimado — Validación | **0–5 USD/mes** (prototipo con un puñado de videos) |
| Costo estimado — MVP Argentina | **10–30 USD/mes** (supuesto: ~500–2.000 videos de 30 s ≈ 250–1.000 min almacenados = 5 USD; delivery 5.000–25.000 min = 5–25 USD) — estimación a validar |
| Costo estimado — Crecimiento | **150–300 USD/mes** (supuesto: ~30.000 videos ≈ 15.000 min = 75 USD storage; delivery 100.000–200.000 min = 100–200 USD) — estimación a validar |
| Límites incluidos | Archivo máx. 30 GB; salida ABR H.264 hasta 1080p (vertical 1080×1920 soportado); 120 encodings simultáneos; 1 caption por idioma, archivo ≤10 MB, video en estado "ready". |
| Extras posibles | **Ojo:** cada descarga MP4 se factura como delivery por la duración completa del video. Volúmenes de millones de minutos: precio negociado con Ventas. |
| Lock-in | **Medio.** HLS es estándar (el player Flutter se abstrae); pero export MP4 es por-video, entrega una rendition (no el original) y **cada descarga paga delivery** (migrar 100.000 min ≈ 100 USD + re-subida). Signed URLs y webhooks propietarios. |
| Exportación de datos | MP4 por video vía API `/downloads` (habilitación individual); captions como VTT vía API; **mitigación: original siempre en R2 (D-011)**, así la migración es re-encodear desde R2 sin pagar egress. |
| Alternativa más barata comparada | **Bunny Stream** (por GB: storage desde 0,01 USD/GB-mes ≈ 0,40–0,80 USD/1.000 min; delivery desde 0,005 USD/GB ≈ 0,10–0,20 USD/1.000 min) — **5–10× más barato a escala**, pero menos integrado (captions/analytics básicos) y facturación dependiente del bitrate. **Mux**: storage ~3 USD/1.000 min, delivery 1 USD/1.000 min con **100.000 min/mes de delivery gratis** (interesante al inicio). **api.video**: storage 2,85 USD/1.000 min pero delivery 1,70 USD/1.000 min (más caro). |
| Estrategia de migración/salida | (1) Original en R2 al momento del upload; (2) `video_id` propio en Supabase mapeado a `provider_id` (nunca acoplar lógica a UIDs de Stream); (3) player detrás de interfaz propia (HLS funciona en los 4 proveedores); (4) revisar el mix de costos cuando el delivery supere ~500k min/mes — a ese volumen Bunny gana claramente. |
| Fuente (URL) | https://developers.cloudflare.com/stream/pricing/ · captions: https://blog.cloudflare.com/stream-automatic-captions-with-ai/ · uploads: https://developers.cloudflare.com/stream/uploading-videos/direct-creator-uploads/ |
| Fecha de verificación | 2026-08-12 |
| Oficial / estimación | **oficial** (tarifas); "mínimo mensual" **a confirmar**; estimaciones de escenario propias |

**Riesgos anotados:** el storage prepago es un **hard stop** — si se agota el cupo, los candidatos no pueden subir video-CVs (mitigación en §4: auto-compra + alarma); tope 1080p (aceptable para video-CVs móviles); si se habilita "descargar video" para empresas, cada descarga paga delivery completo; calidad de Whisper en español rioplatense a validar en beta.

---

### D-003 — Claude API (Anthropic) — mix de modelos por tarea + Batch + caching

| Campo | Valor |
|---|---|
| ID | D-003 |
| Fecha | 2026-08-12 |
| Estado | propuesta |
| Decisión | Toda llamada a Claude pasa por Edge Functions (nunca API key en el cliente — ver [SECURITY.md](SECURITY.md)). **Mix por tarea:** `claude-haiku-4-5` para clasificación/extracción/moderación de alto volumen; `claude-sonnet-5` como modelo principal (guiones de video, ofertas estructuradas, resúmenes de postulaciones, matching explicable — ver límites éticos en [PRIVACY.md](PRIVACY.md) y [PRODUCT.md](PRODUCT.md)); `claude-fable-5` **solo** si aparece un caso de razonamiento extremo que lo justifique. **Batch API (−50%)** para procesos nocturnos no interactivos. **Prompt caching** agresivo del system prompt (rúbricas largas). Límites de gasto por workspace y límites de uso por usuario final. |
| Precio + unidad + moneda | Por MTok (input/output): **Haiku 4.5: 1 / 5 USD** · **Sonnet 5: 3 / 15 USD** (cifra vigente por SPEC §4 — ver nota abajo) · **Fable 5: 10 / 50 USD**. Batch (−50%): Haiku 0,50/2,50 · Sonnet 1,50/7,50 · Fable 5/25. Caching: write 5 min = 1,25× input; write 1 h = 2× input; **read = 0,1× input** (Sonnet read: 0,30 USD/MTok). |
| Free tier | No hay free tier de producción relevante. |
| Costo estimado — Validación | **0–10 USD/mes** (pruebas de prompts) — estimación a validar |
| Costo estimado — MVP Argentina | **30–80 USD/mes** (supuesto: mayoría Haiku/Sonnet con caching, batch nocturno para re-scoring) — estimación a validar |
| Costo estimado — Crecimiento | **200–500 USD/mes** con límites duros por usuario y por feature — estimación a validar |
| Límites incluidos | Sonnet 5 y Fable 5: contexto 1M tokens, salida máx. 128K. Haiku 4.5: contexto 200K, salida 64K. Batch: hasta 100.000 requests o 256 MB por batch, la mayoría completa en <1 h (máx. 24 h), resultados 29 días. Caching: máx. 4 breakpoints por request; prefijo mínimo cacheable ~1024 tokens. |
| Extras posibles | Residencia de datos `inference_geo:"us"`: multiplicador 1,1×. Web search: 10 USD/1.000 búsquedas. Batch no compatible con fast mode. |
| Lock-in | **Moderado y gestionable.** API Messages propietaria; prompts tuneados por modelo; caché por-modelo (cambiar de modelo la invalida). Sin lock-in de datos (API stateless; el historial vive en Supabase). Mismos modelos disponibles vía Amazon Bedrock / Google Vertex (cambio de facturador sin cambiar de modelo). |
| Exportación de datos | No aplica (stateless); prompts y esquemas de salida versionados en el repo, nunca hardcodeados. |
| Alternativa más barata comparada | La palanca de ahorro más grande es **interna**: degradar tareas de Sonnet 5 a Haiku 4.5 (input 3× más barato, output 3× más barato) donde la calidad alcance + Batch + caching (ahorro efectivo >50% combinados). Externas: OpenAI/Gemini como segundo adaptador (requieren re-testear prompts y evals). |
| Estrategia de migración/salida | (1) Capa de abstracción `LLMService` con adaptadores por proveedor desde el día uno; (2) prompts/esquemas en archivos versionados; (3) set de evals propio para validar cualquier migración de modelo; (4) monitoreo del campo `usage` de cada respuesta con alertas de desvío; (5) Bedrock/Vertex como redundancia operativa. |
| Fuente (URL) | https://platform.claude.com/docs/en/about-claude/pricing |
| Fecha de verificación | 2026-08-12 |
| Oficial / estimación | **oficial** (tarifas); estimaciones de escenario propias |

**Notas de verificación importantes:**
- **Precio de Sonnet 5 — rige la SPEC §4 (fuente de verdad): 3/15 USD por MTok.** Es la **única cifra vigente** y la que se carga en el Excel. La verificación del 2026-08-12 encontró publicado un precio menor (2/10 USD, precio introductorio que el proveedor habría convertido en estándar); esa observación queda **escalada al fundador**: si la confirma, se actualiza primero la SPEC §4 y recién entonces [ARCHITECTURE.md](ARCHITECTURE.md) §5, este documento y el Excel pasan a 2/10 con nota de revisión (regla §1.3). Pendiente de esa decisión, ARCHITECTURE §5 (que hoy figura con 2/10) debe alinearse a 3/15 — en ningún caso conviven dos cifras.
- El tokenizer nuevo de Sonnet 5 produce **~30% más tokens** por el mismo texto vs. Sonnet 4.6: re-medir con `count_tokens`, no proyectar con conteos viejos.
- Fable 5 requiere retención de datos de 30 días (no disponible bajo zero data retention) — evaluar contra [PRIVACY.md](PRIVACY.md) antes de usarlo con datos de candidatos.

---

### D-004 — Mercado Pago Suscripciones (cobros B2B en ARS)

| Campo | Valor |
|---|---|
| ID | D-004 |
| Fecha | 2026-08-12 |
| Estado | **aprobada** — aprobado el 12-08-2026 por el fundador |
| Decisión | Cobrar los planes de empresa con **Mercado Pago Suscripciones**, vía web (checkout propio), **fuera de los stores** (0% de comisión Apple/Google — ver D-005). Webhooks idempotentes + verificación server-side + reconciliación según [ARCHITECTURE.md](ARCHITECTURE.md) y el modelo de datos de pagos de [DATA_MODEL.md](DATA_MODEL.md). **Fase inicial (aprobada): acreditación a 18 días, 3,39% + IVA** (costo efectivo ~4,10%). **Alternativa registrada: 35 días, 1,49% + IVA** (~1,80%), que se adoptará cuando la reserva de liquidez cubra al menos **2 meses de costos operativos**. La modalidad de acreditación debe ser **configurable server-side, no hardcodeada**. |
| Precio + unidad + moneda | Comisión por cobro **+ IVA 21% sobre la comisión** según plazo de liberación: inmediato **6,99%** (efectivo ~8,46%) · 10 días **4,49%** (~5,43%) · 18 días **3,39%** (~4,10%) · 35 días **1,49%** (~1,80%). |
| Free tier | No aplica: es % sobre ingresos, sin costo fijo mensual. |
| Costo estimado — Validación | **0 ARS** (sin cobros todavía) |
| Costo estimado — MVP Argentina | **~4,1% de los ingresos B2B** (a 18 días) + retenciones IIBB/SIRTAC según perfil fiscal — estimación a validar |
| Costo estimado — Crecimiento | Igual (% sobre ingresos); renegociar por volumen si aplica — estimación a validar |
| Límites incluidos | Cobros recurrentes con tarjeta de crédito / dinero en cuenta MP. |
| Extras posibles | Retenciones automáticas de IIBB/SIRTAC sobre los cobros según jurisdicción; percepciones de IVA/Ganancias según perfil fiscal. MP aclara que los costos "pueden variar de acuerdo a los impuestos provinciales". |
| Lock-in | **Alto en datos de pago.** MP tokeniza las tarjetas dentro de su ecosistema: migrar a otro procesador implica re-onboarding de todos los suscriptores (churn típico 10–30%). Sin permanencia contractual. |
| Exportación de datos | Los datos de suscripción/pagos propios se persisten en Supabase (campos mínimos de la SPEC §8); los tokens de tarjeta **no** son exportables. |
| Alternativa más barata comparada | Débito directo bancario/CBU (menor comisión, más fricción de alta); Pagos360, Payway/Prisma, dLocal. Stripe no opera cobros domésticos en ARS. La palanca real es el **plazo de acreditación** (8,46% → 1,80%). |
| Estrategia de migración/salida | Interfaz `PaymentProvider` (create_subscription, cancel, refund, verify_event, reconcile…) desde el día uno; toda la lógica de billing agnóstica del proveedor; aceptar que un cambio de procesador implica re-suscripción de la base. |
| Fuente (URL) | https://www.mercadopago.com.ar/herramientas-para-vender/suscripciones |
| Fecha de verificación | 2026-08-12 |
| Oficial / estimación | **oficial** (comisiones); plazo inicial y alternativa **aprobados el 12-08-2026 por el fundador**; estimaciones de escenario propias |

---

### D-005 — Push notifications: FCM + APNs (y fees de stores)

| Campo | Valor |
|---|---|
| ID | D-005 |
| Fecha | 2026-08-12 |
| Estado | propuesta |
| Decisión | **FCM** (Android/Web) + **APNs** (iOS), orquestados desde el backend (ver [ARCHITECTURE.md](ARCHITECTURE.md)). Ambos servicios son gratis a cualquier volumen; el costo real son las membresías de desarrollador: **Apple Developer 99 USD/año** (requerido para publicar en App Store y usar APNs) y **Google Play Console 25 USD pago único**. |
| Precio + unidad + moneda | FCM: **0 USD** ("No-cost" en Spark y Blaze, sin cuotas pagas). APNs: **0 USD** (incluido en la membresía Apple). Apple Developer: **99 USD/año**. Play Console: **25 USD una única vez**. |
| Free tier | Todo el servicio de push es free tier permanente. |
| Costo estimado — Validación | **0 USD** (aún sin cuentas de store si no se publica) |
| Costo estimado — MVP Argentina | **99 USD/año + 25 USD única vez** ≈ **8,25 USD/mes prorrateado** |
| Costo estimado — Crecimiento | **99 USD/año** (renovación Apple) ≈ 8,25 USD/mes |
| Límites incluidos | Membresía Apple incluye App Store Connect, TestFlight, certificados, APNs, Xcode Cloud básico. |
| Extras posibles | **Comisiones de stores solo si se cobra in-app:** App Store 30% (15% tras 1 año del suscriptor, o 15% siempre con Small Business Program si proceeds <1M USD/año — requiere inscripción); Play Store 15% para suscripciones auto-renovables (esquema nuevo 10%+5% ya vigente en EEA/UK/US desde 30-jun-2026, con rollout global anunciado). |
| Lock-in | Bajo en push (FCM/APNs son los canales estándar). **Alto en billing in-app**: una vez dentro de IAP no se puede redirigir a checkout externo sin restricciones. |
| Exportación de datos | Tokens de dispositivo almacenados en Supabase; regenerables en cualquier migración. |
| Alternativa más barata comparada | No hay más barato que gratis. (Capas de orquestación tipo OneSignal se evaluarían como D-0XX nueva si hiciera falta.) |
| Estrategia de migración/salida | Mantener el cobro B2B (empresas) 100% en la web con Mercado Pago (D-004), fuera de los stores, desde el día uno. Si algún día se monetiza B2C in-app (Candidato Plus), inscribirse antes en el Small Business Program de Apple. |
| Fuente (URL) | https://firebase.google.com/pricing · https://developer.apple.com/programs/whats-included/ · https://developer.apple.com/support/enrollment/ · https://support.google.com/googleplay/android-developer/answer/6112435 · comisiones: https://developer.apple.com/app-store/subscriptions/ · https://support.google.com/googleplay/android-developer/answer/112622 |
| Fecha de verificación | 2026-08-12 |
| Oficial / estimación | **oficial** |

---

### D-006 — Email transaccional: Resend (Free → Pro), con salida a Amazon SES

| Campo | Valor |
|---|---|
| ID | D-006 |
| Fecha | 2026-08-12 |
| Estado | propuesta |
| Decisión | Arrancar con **Resend Free** (3.000 emails/mes, máx. 100/día) para verificación de cuenta, recuperación de contraseña y notificaciones críticas (los avisos no críticos van por push, D-005). Pasar a **Resend Pro (20 USD/mes, 50.000 emails)** si el volumen lo exige, y evaluar migración a **Amazon SES (0,10 USD/1.000)** cuando el volumen mensual supere ~50.000 emails. |
| Precio + unidad + moneda | Resend Free: **0 USD/mes**. Resend Pro: **20 USD/mes** (50.000 emails; siguiente tier 35 USD/100.000; overage 0,90 USD/1.000). SES à la carte: **0,10 USD/1.000 emails** + 0,12 USD/GB adjuntos. |
| Free tier | Resend: 3.000/mes, 100/día. SES: hasta 200 USD en créditos AWS Free Tier por 6 meses para cuentas nuevas (el viejo free tier de 3.000/mes ya no existe). |
| Costo estimado — Validación | **0 USD/mes** |
| Costo estimado — MVP Argentina | **0–20 USD/mes** — estimación a validar |
| Costo estimado — Crecimiento | **20–35 USD/mes** (Resend) o **~5–15 USD/mes** si ya se migró a SES — estimación a validar |
| Límites incluidos | Ver free tier / planes arriba. |
| Extras posibles | Overage Resend 0,90 USD/1.000 (9× el precio de SES: es el trigger de migración). |
| Lock-in | **Bajo.** SMTP/API de envío intercambiables. |
| Exportación de datos | Plantillas y logs propios en el repo/Supabase; nada crítico vive en el proveedor. |
| Alternativa más barata comparada | **Amazon SES** (0,10 USD/1.000, el más barato a escala; requiere más setup: dominio verificado, salida del sandbox, manejo de bounces). Otras: Postmark 15 USD/mes por 10k, Brevo/Mailgun. |
| Estrategia de migración/salida | Capa de abstracción `EmailService` (interfaz + adaptador Resend) desde el día uno; plantillas en el repo; migrar a SES = escribir un adaptador + verificar dominio + warm-up. |
| Fuente (URL) | https://resend.com/pricing · https://aws.amazon.com/ses/pricing/ |
| Fecha de verificación | 2026-08-12 |
| Oficial / estimación | **oficial** (tarifas); estimaciones de escenario propias |

---

### D-007 — Sentry (error monitoring)

| Campo | Valor |
|---|---|
| ID | D-007 |
| Fecha | 2026-08-12 |
| Estado | propuesta |
| Decisión | **Sentry Developer (gratis)** durante Validación y MVP (5.000 errores/mes, 1 usuario). Pasar a **Team (26 USD/mes, facturación anual)** cuando el equipo supere 1 persona o el volumen de eventos lo exija. |
| Precio + unidad + moneda | Developer: **0 USD/mes**. Team: **26 USD/mes** (anual, con volumen prepago por defecto; el precio mes a mes puede ser mayor, ~29 USD histórico — **a confirmar en checkout**). |
| Free tier | 5.000 errores/mes, 1 usuario. |
| Costo estimado — Validación | **0 USD/mes** |
| Costo estimado — MVP Argentina | **0–26 USD/mes** — estimación a validar |
| Costo estimado — Crecimiento | **26+ USD/mes** (escala con el volumen de eventos contratado) — estimación a validar |
| Límites incluidos | Team: usuarios ilimitados; el costo escala por eventos. |
| Extras posibles | Volumen de eventos adicional según contrato. |
| Lock-in | **Bajo.** SDK estándar; alternativas compatibles. |
| Exportación de datos | Los eventos son telemetría desechable; no hay datos de negocio en Sentry. |
| Alternativa más barata comparada | **GlitchTip** (compatible con el SDK de Sentry, self-hosted gratis) — implica costo operativo propio de hosting/mantenimiento. |
| Estrategia de migración/salida | Cambiar el DSN del SDK a GlitchTip o Sentry self-hosted; sin migración de datos necesaria. |
| Fuente (URL) | https://sentry.io/pricing/ |
| Fecha de verificación | 2026-08-12 |
| Oficial / estimación | **oficial** (Developer y Team anual); precio mensual **a confirmar** |

---

### D-008 — GitHub Actions (CI/CD)

| Campo | Valor |
|---|---|
| ID | D-008 |
| Fecha | 2026-08-12 |
| Estado | propuesta |
| Decisión | **GitHub Actions plan Free** en repo privado para CI (analyze, tests, builds Android/Web). **Atención al multiplicador macOS 10×** para builds iOS: los 2.000 min/mes gratis equivalen a ~200 min reales de macOS. Si el CI de iOS se vuelve cuello de botella, evaluar **Codemagic** (especializado Flutter, 500 min gratis en macOS M-series) como D-0XX nueva. |
| Precio + unidad + moneda | **0 USD/mes** dentro del free tier: 2.000 min/mes + 500 MB storage de artifacts (repos privados; runners Linux 1×, Windows 2×, macOS 10×; cache 10 GB por repo). |
| Free tier | El descrito. En repos públicos los runners estándar son gratis e ilimitados. |
| Costo estimado — Validación | **0 USD/mes** |
| Costo estimado — MVP Argentina | **0–20 USD/mes** (si los builds iOS exceden el cupo; minutos extra al precio vigente de GitHub) — estimación a validar |
| Costo estimado — Crecimiento | **0–50 USD/mes** — estimación a validar |
| Límites incluidos | Ver free tier. |
| Extras posibles | Minutos adicionales facturados por uso; planes Pro/Team con más cupo (3.000 min). |
| Lock-in | **Bajo.** Workflows YAML portables con esfuerzo moderado a otros CI. |
| Exportación de datos | Workflows viven en el repo; artifacts regenerables. |
| Alternativa más barata comparada | **Codemagic** para iOS (500 min gratis en macOS M-series, sin multiplicador 10×). |
| Estrategia de migración/salida | Mantener la lógica de build en scripts del repo (no en YAML gigantes) para portar a Codemagic/otros CI con cambios mínimos. |
| Fuente (URL) | https://docs.github.com/en/billing/managing-billing-for-your-products/about-billing-for-github-actions |
| Fecha de verificación | 2026-08-12 |
| Oficial / estimación | **oficial** (free tier); estimaciones de escenario propias |

---

### D-009 — Dominios: .com (Cloudflare Registrar) + .com.ar (NIC.ar)

| Campo | Valor |
|---|---|
| ID | D-009 |
| Fecha | 2026-08-12 |
| Estado | propuesta |
| Decisión | Registrar el **.com en Cloudflare Registrar** (modelo at-cost verificado, sin markup) y el **.com.ar en NIC.ar** para presencia local. |
| Precio + unidad + moneda | .com: **~10,44 USD/año** (estimación: mayorista Verisign 10,26 + fee ICANN 0,18; renovación al mismo precio; **confirmar el número exacto en el dashboard de Cloudflare**). .com.ar: **ARS 8.500/año** (alta y renovación, oficial NIC.ar). |
| Free tier | No aplica. |
| Costo estimado — Validación | **~10,44 USD + ARS 8.500 (una vez al año)** ≈ 1,3 USD/mes prorrateado |
| Costo estimado — MVP Argentina | Igual |
| Costo estimado — Crecimiento | Igual + dominios de expansión (UY/CL/…) cuando toque — cada uno con su D-0XX |
| Límites incluidos | — |
| Extras posibles | Verisign sube el mayorista de .com a 10,97 USD desde el **1-nov-2026** (renovación pasaría a ~11,15–11,17 USD/año). Aranceles NIC.ar en ARS se actualizan por inflación. |
| Lock-in | **Bajo.** Dominios transferibles sin penalidad. |
| Exportación de datos | Transferencia estándar de dominio (auth code). |
| Alternativa más barata comparada | Porkbun / Namecheap (~10–13 USD/año, a veces promo primer año) si no se quiere atar el registro a Cloudflare. |
| Estrategia de migración/salida | Transferencia estándar; DNS gestionado en Cloudflare (gratuito) independiente del registrador. |
| Fuente (URL) | https://www.cloudflare.com/products/registrar/ · https://nic.ar/es/dominios/aranceles |
| Fecha de verificación | 2026-08-12 |
| Oficial / estimación | .com: **estimación** (modelo at-cost oficial, número exacto en dashboard); .com.ar: **oficial** |

---

### D-010 — Impuestos Argentina (reserva prudencial) — A CONFIRMAR CON CONTADOR

| Campo | Valor |
|---|---|
| ID | D-010 |
| Fecha | 2026-08-12 |
| Estado | propuesta |
| Decisión | Constituir una **reserva prudencial de impuestos** en el Excel y **validar todo este bloque con un contador argentino antes de facturar el primer peso** (requisito ya previsto en [PRIVACY.md](PRIVACY.md) / SPEC §9: abogado + contador antes del lanzamiento). Nada de esta entrada es asesoramiento fiscal. |
| Precio + unidad + moneda | Ver desglose abajo — todos **a confirmar**. |
| Free tier | No aplica. |
| Costo estimado — Validación | **0 ARS de impuestos sobre ventas** (sin facturación) + percepción 30% sobre SaaS del exterior si se paga con tarjeta AR (recuperable) + honorarios contador si ya hay SAS (~ARS 350.000/mes, estimación) |
| Costo estimado — MVP Argentina | Reserva propuesta a validar: **IVA 21% sobre lo facturado** (neto de créditos fiscales) + **IIBB ~3%** + provisión de Ganancias + contador — estimación a validar en el Excel |
| Costo estimado — Crecimiento | Igual, con escala de Ganancias (25→30%) según ganancia neta — estimación a validar |
| Lock-in | No aplica. |
| Exportación de datos | No aplica. |
| Alternativa más barata comparada | Para los pagos de SaaS del exterior: **pagar el resumen de la tarjeta directamente en USD** (comprados vía MEP) evita la percepción del 30% y suele ser más barato que el dólar tarjeta. |
| Estrategia de migración/salida | No aplica (obligación legal). |
| Fuente (URL) | Ver desglose. |
| Fecha de verificación | 2026-08-12 |
| Oficial / estimación | **a confirmar con contador** (alícuotas citadas de fuentes oficiales/prensa; aplicación al caso concreto pendiente) |

**Desglose (todo A CONFIRMAR con contador):**

| Concepto | Valor | Tipo | Fuente |
|---|---|---|---|
| IVA — alícuota general (facturación B2B de TalentFlash como responsable inscripto; el IVA de comisiones MP e insumos es crédito fiscal) | **21%** | a confirmar | https://www.afip.gob.ar/iva/ |
| IIBB CABA — servicios (SAS tecnológica; si ingresos anuales < ~$2.154,3 M; software puede tener alícuota reducida / beneficios economía del conocimiento — confirmar código NAES) | **3,00%** | a confirmar | https://documentosboletinoficial.buenosaires.gob.ar/publico/PL-LEY-LCABA-LCBA-6927-25-ANX.pdf (Ley 6927 mod. 6948, vigente 01/06/2026) |
| Ganancias sociedades — escala ejercicios iniciados 2026 (+7% sobre dividendos distribuidos; tramos ~$133,2 M / ~$1.332 M según prensa especializada, PDF oficial no extraíble) | **25% / 30% / 35%** | a confirmar | https://www.afip.gob.ar/gananciasYBienes/ganancias/personas-juridicas/determinacion/documentos/Ganancias-Escala-PJ-2026.pdf |
| Percepción RG 5617 sobre pagos de SaaS al exterior con tarjeta AR (Cloudflare, Supabase, Anthropic…) — **a cuenta de Ganancias, recuperable**; el impuesto PAIS fue eliminado (dic-2024) y no se reemplazó; se evita pagando el resumen en USD | **30%** | a confirmar | https://www.bancopatagonia.com.ar/preguntas-frecuentes/tarjetas/credito/percepcion.php |
| IVA por importación de servicios digitales del exterior (reverse charge para responsables inscriptos) — puede sumarse sobre los SaaS del exterior | **21%** | a confirmar | https://www.afip.gob.ar/iva/ |
| Honorarios contador (SAS chica CABA: IVA, IIBB, Ganancias, sueldos básicos; rango $200.000–$500.000) | **~ARS 350.000/mes** | estimación | https://ellaburante.com/blog/contador-precios-2026 |
| Constitución SAS CABA (única vez; honorarios + tasas IGJ/edictos; aparte capital social mínimo 2 SMVM — capital, no costo hundido) | **~ARS 400.000** (rango 335–470 mil) | estimación | https://www.quieromisas.com/blog/costos-constituir-empresa-argentina-2026 |
| Tipo de cambio de referencia (12-08-2026): oficial BNA compra/venta **1.465/1.515**; MEP **~1.525** (brecha <1%) | — | oficial / estimación | https://www.bna.com.ar/Personas · prensa financiera |

**Regla de presupuesto asociada:** los costos en USD del stack se proyectan en el Excel con un **buffer cambiario del 15–30%** sobre el TC del día (propuesta a validar), por el historial de saltos discretos del peso.

---

### D-011 — Cloudflare R2 (storage de originales de video — requisito de D-002)

| Campo | Valor |
|---|---|
| ID | D-011 |
| Fecha | 2026-08-12 |
| Estado | propuesta |
| Decisión | Usar **Cloudflare R2** como almacenamiento obligatorio del **archivo original** de cada video-CV al momento del upload ("copia del original SIEMPRE en R2", [ARCHITECTURE.md](ARCHITECTURE.md) §4.1), como seguro de migración de Cloudflare Stream (D-002). **D-002 no puede aprobarse sin esta entrada aprobada** (regla §1.4). Resuelve el pendiente "a cotizar" de [ROADMAP.md](ROADMAP.md) T-055. |
| Precio + unidad + moneda | Storage (Standard): **0,015 USD/GB-mes**. Operaciones Clase A (escrituras/listados): **4,50 USD/millón**; Clase B (lecturas): **0,36 USD/millón**. **Egress: 0 USD** a cualquier volumen (la razón principal de elegir R2). |
| Free tier | Permanente: 10 GB-mes de storage, 1 M operaciones Clase A/mes, 10 M operaciones Clase B/mes. |
| Costo estimado — Validación | **0 USD/mes** (el free tier cubre de sobra el prototipo) |
| Costo estimado — MVP Argentina | **0–1 USD/mes** (supuesto: 500–2.000 originales de 30 s ≈ 8–15 MB c/u = 5–30 GB) — estimación a validar |
| Costo estimado — Crecimiento | **4–8 USD/mes** (supuesto: ~30.000 originales ≈ 300–450 GB ≈ 4,5–6,8 USD + operaciones marginales) — estimación a validar |
| Límites incluidos | Sin cargo de egress ni ancho de banda; API S3-compatible; objetos de gran tamaño vía multipart. |
| Extras posibles | Clase **Infrequent Access** (0,01 USD/GB-mes, con cargo por retrieval) — candidata para originales antiguos según la política de retención/vencimiento de videos de [PRIVACY.md](PRIVACY.md). |
| Lock-in | **Bajo.** API S3-compatible (`rclone`, `aws s3` funcionan tal cual); egress gratis = sacar todos los datos no cuesta nada. |
| Exportación de datos | `rclone sync` hacia cualquier S3/almacenamiento alternativo, sin costo de egress. |
| Alternativa más barata comparada | **Backblaze B2** (0,006 USD/GB-mes, egress gratis hasta 3× el storage medio): más barato por GB pero agrega un proveedor nuevo. **AWS S3** (0,023 USD/GB-mes + egress 0,09 USD/GB) descartado por egress caro. R2 gana por egress 0 e integración con Stream (mismo proveedor, sin tráfico externo). |
| Estrategia de migración/salida | (1) Claves propias (`videos/originals/{video_id}`) mapeadas en Supabase, nunca acopladas a UIDs del proveedor; (2) salida = `rclone sync` a B2/S3 (egress 0) + cambio de endpoint S3 en la config — días de trabajo, sin costo de transferencia. |
| Fuente (URL) | https://developers.cloudflare.com/r2/pricing/ |
| Fecha de verificación | 2026-08-12 |
| Oficial / estimación | **oficial** (tarifas y free tier); estimaciones de escenario propias |

---

### D-012 — Rate limiting y contadores: Postgres (D-001) como default; Upstash Redis registrado como opción

| Campo | Valor |
|---|---|
| ID | D-012 |
| Fecha | 2026-08-12 |
| Estado | propuesta |
| Decisión | Implementar rate limiting y contadores de uso ([SECURITY.md](SECURITY.md) §6) con **contadores en Postgres/Supabase (D-001)** — costo marginal cero dentro del plan ya presupuestado — como default del MVP. **Upstash Redis** queda registrado aquí como opción de upgrade SOLO si Postgres se vuelve cuello de botella (latencia/contención a escala). Esta entrada existe porque SECURITY §6 mencionaba Upstash sin registro D-0XX, en violación de SPEC §13 y de la regla §1.4; activar Upstash requiere pasar esta decisión a `revisar` y nueva aprobación del fundador. |
| Precio + unidad + moneda | Postgres: **0 USD adicionales** (incluido en D-001). Upstash Redis pay-as-you-go: **0,20 USD por 100.000 comandos** + storage 0,25 USD/GB-mes; plan Fixed 250 MB: 10 USD/mes. |
| Free tier | Upstash Free: 256 MB y 500.000 comandos/mes — cubriría todo el MVP si se activara. |
| Costo estimado — Validación | **0 USD/mes** (Postgres) |
| Costo estimado — MVP Argentina | **0 USD/mes** (Postgres; si se activara Upstash, 0 USD dentro del free tier) — estimación a validar |
| Costo estimado — Crecimiento | **0–10 USD/mes** (0 si Postgres alcanza; ~2–10 USD si se activa Upstash pay-as-you-go o Fixed) — estimación a validar |
| Límites incluidos | Postgres: los del plan Supabase (D-001). Upstash Free: 256 MB, 500k comandos/mes. |
| Extras posibles | Upstash: réplicas globales (multiplican el costo por comando) — no necesarias para AR. |
| Lock-in | **Bajo.** Contadores en SQL estándar; Upstash es Redis-compatible (migrable a cualquier Redis). |
| Exportación de datos | Contadores = datos efímeros/reconstruibles; nada crítico que exportar. |
| Alternativa más barata comparada | La default YA es la más barata (Postgres, 0 USD). Si hiciera falta Redis: Redis Cloud free 30 MB; Redis self-hosted en VM (~5 USD/mes + operación propia). |
| Estrategia de migración/salida | Rate limiter detrás de interfaz propia (`RateLimiter`) en las Edge Functions; cambiar de backend (Postgres ↔ Redis) = escribir un adaptador, sin migración de datos. |
| Fuente (URL) | https://upstash.com/pricing · https://supabase.com/pricing (D-001) |
| Fecha de verificación | 2026-08-12 |
| Oficial / estimación | **oficial** (tarifas Upstash); estimaciones de escenario propias |

**Nota de alineación:** [SECURITY.md](SECURITY.md) §6 debe actualizarse para referenciar esta entrada — contadores en Postgres como default y Upstash solo como opción registrada en D-012 (ninguna dependencia nueva sin D-0XX).

---

## Decisiones aprobadas — 12-08-2026

Bloque de decisiones **aprobadas el 12-08-2026 por el fundador**. Incluye las entradas nuevas D-014 y D-015 (plantilla §2) y otras decisiones aprobadas que no incorporan proveedor nuevo. Además, en esta misma fecha se aprobó **D-004** (ver §3, estado actualizado allí).

---

### D-014 — Pentest externo pre-lanzamiento (Seguridad)

| Campo | Valor |
|---|---|
| ID | D-014 |
| Fecha | 2026-08-12 |
| Estado | **aprobada** — aprobado el 12-08-2026 por el fundador — **SOLICITAR PRESUPUESTOS antes del gasto** |
| Decisión | Contratar un **penetration test externo** antes del lanzamiento público (categoría **Seguridad**, gasto **una tantum**), ubicado en el **mes 9 del Flujo** (pre-lanzamiento). Aplica a los escenarios **MVP Argentina** y **Crecimiento** (no a Validación). Registrada en el Excel: fila **C21**, nombre **P_PENTEST**, mes 9 del Flujo, **incluida en el costo inicial del Resumen** (regla §1.2 cumplida). |
| Precio + unidad + moneda | **USD 2.500 una tantum** (estimación central; rango indicativo **USD 1.500–4.000**) |
| Free tier | No aplica. |
| Costo estimado — Validación | **0 USD** (no aplica al escenario) |
| Costo estimado — MVP Argentina | **USD 2.500 una tantum** (mes 9 del Flujo) — estimación |
| Costo estimado — Crecimiento | **USD 2.500 una tantum** (ya computado en el costo inicial; re-tests futuros requieren D-0XX nueva) — estimación |
| Límites incluidos | Alcance a definir con los presupuestos solicitados (app Flutter, Edge Functions, RLS, APIs, storage/URLs firmadas). |
| Extras posibles | Re-test post-remediación; pentests periódicos futuros (cada uno con su D-0XX). |
| Lock-in | No aplica (servicio profesional puntual). |
| Exportación de datos | Informe de pentest archivado en repositorio privado de seguridad. |
| Alternativa más barata comparada | Escaneo automatizado / bug bounty acotado — más baratos pero no reemplazan un pentest manual pre-lanzamiento; se usarán como complemento, no sustituto. |
| Estrategia de migración/salida | No aplica (gasto una tantum). |
| Fuente (URL) | — (estimación de mercado; presupuestos reales a solicitar antes del gasto) |
| Fecha de verificación | 2026-08-12 |
| Oficial / estimación | **estimación** — SOLICITAR PRESUPUESTOS antes del gasto |

---

### D-015 — Supabase Point-in-Time Recovery (PITR, 7 días)

| Campo | Valor |
|---|---|
| ID | D-015 |
| Fecha | 2026-08-12 |
| Estado | **aprobada** — aprobado el 12-08-2026 por el fundador |
| Decisión | Activar **Point-in-Time Recovery de Supabase con 7 días de retención** SOLO en el escenario **Crecimiento**. Para **Validación y MVP Argentina** rige en cambio: backups diarios incluidos en Supabase Pro (retención 7 días, D-001) + **export lógico cifrado semanal** + **prueba periódica de restauración** + **backup separado de los datos no cubiertos por el backup de PostgreSQL**. Registrada en el Excel (fila **C22**; regla §1.2 cumplida). Referencia cruzada: [SECURITY.md](SECURITY.md). |
| Precio + unidad + moneda | **~100 USD/mes** (PITR, retención 7 días) |
| Free tier | No aplica (add-on pago; los backups diarios ya están incluidos en Pro, D-001). |
| Costo estimado — Validación | **0 USD/mes** (no se activa; aplican las mitigaciones sin costo extra) |
| Costo estimado — MVP Argentina | **0 USD/mes** (no se activa; aplican las mitigaciones sin costo extra) |
| Costo estimado — Crecimiento | **~100 USD/mes** — precio oficial |
| Límites incluidos | Restauración a un punto en el tiempo dentro de la ventana de 7 días. |
| Extras posibles | Retenciones mayores (14/28 días) a mayor costo — requerirían D-0XX de revisión. |
| Lock-in | **Bajo.** Complemento de D-001; la salida es la misma que la de Supabase (`pg_dump` + export lógico propio). |
| Exportación de datos | El export lógico cifrado semanal es independiente del proveedor y funciona como seguro adicional. |
| Alternativa más barata comparada | La adoptada para Validación/MVP: backups diarios de Pro + export lógico cifrado semanal + prueba de restauración (costo marginal ~0). |
| Estrategia de migración/salida | Igual a D-001; desactivar PITR no requiere migración de datos. |
| Fuente (URL) | https://supabase.com/docs/guides/platform/manage-your-usage/point-in-time-recovery |
| Fecha de verificación | 2026-08-12 |
| Oficial / estimación | **PRECIO OFICIAL** (verificado 2026-08-12); estimaciones de escenario propias |

---

### Otras decisiones aprobadas — 12-08-2026 (sin proveedor nuevo)

- **Precios comerciales — aprobada como HIPÓTESIS** (aprobado el 12-08-2026 por el fundador): **PyME 25 / Profesional 70 / Empresa 180 / Candidato Plus 5** USD de referencia por mes. **A validar con empresas reales — no definitivos.** Se muestran y cobran en **ARS**; **nunca hardcodeados en el client**. (El modelo económico completo vive en el Excel, regla §1.1.)
- **Retención de video — aprobada** (aprobado el 12-08-2026 por el fundador): default **60 días**, configurable **30/60/90**; **remoción inmediata de visibilidad** al eliminar; borrado de sistemas primarios dentro del plazo normativo; los backups expiran en el período documentado **salvo obligación legal**; **sin training de IA sin consentimiento separado**. (Impacta los supuestos de volumen de D-002/D-011 y la política de [PRIVACY.md](PRIVACY.md).)
- **Estado "vista" — aprobada** (aprobado el 12-08-2026 por el fundador): se registra **al abrir el detalle**; **sin inferencias** (atención/interés/emoción); estados visibles para el candidato: **enviada, vista, entrevista propuesta, aceptada, rechazada, cerrada**.
- **Capital disponible — POR CONFIRMAR** (registrado el 12-08-2026): el valor **USD 15.000** del Excel es **SOLO un ejemplo**; el runway calculado con ese valor **no es un dato real**.

---

## 4. Presupuesto máximo mensual por servicio y alarmas

Los topes son **propuestas a validar** por el fundador junto con el Excel. La regla operativa: **ningún servicio puede gastar por encima de su tope sin una decisión D-0XX de revisión**.

### 4.1 Topes propuestos (USD/mes, sin impuestos AR)

| Servicio | Validación | MVP Argentina | Crecimiento | Mecanismo de tope |
|---|---:|---:|---:|---|
| D-001 Supabase | 0 | 40 | 160 | Spend cap ON en Validación/MVP; en producción con tráfico real, decidir OFF + alertas (ver 4.2) |
| D-002 Cloudflare Stream | 5 | 35 | 320 | Prepago de storage (tope natural) + alerta de delivery |
| D-003 Claude API | 10 | 90 | 550 | Límite de gasto del workspace Anthropic + límites por usuario/feature |
| D-004 Mercado Pago | — | % de ingresos | % de ingresos | No es gasto fijo; monitorear % efectivo vs. plan elegido |
| D-005 Stores/push | 0 | 9 | 9 | Fijo anual prorrateado |
| D-006 Email | 0 | 20 | 40 | Tope de plan Resend; trigger de migración a SES |
| D-007 Sentry | 0 | 26 | 40 | Cuota de eventos del plan |
| D-008 GitHub Actions | 0 | 20 | 50 | Límite de gasto de Actions en 0 al inicio (falla el build antes que facturar) |
| D-009 Dominios | 2 | 2 | 4 | Fijo anual prorrateado |
| D-011 Cloudflare R2 | 0 | 1 | 10 | Free tier permanente + alerta de facturación Cloudflare |
| D-012 Rate limiting (Postgres / Upstash) | 0 | 0 | 10 | 0 mientras sea Postgres (dentro de D-001); activar Upstash exige D-012 en `revisar` |
| **Total stack (sin MP ni impuestos)** | **~17** | **~243** | **~1.193** | |

### 4.2 Alarmas (obligatorias antes del lanzamiento — ver [ROADMAP.md](ROADMAP.md), fase MVP)

1. **Regla general 80/100:** alerta a las personas fundadoras al **80%** del tope mensual de cada servicio; al **100%**, decisión explícita (subir tope vía D-0XX de revisión, o degradar el servicio).
2. **Supabase:** definir explícitamente la política de spend cap por entorno. Propuesta: staging ON (que frene); producción OFF **solo** con alertas de facturación configuradas y tope 4.1 vigilado semanalmente.
3. **Cloudflare Stream:** el storage prepago es un hard stop de producto (bloquea subida de video-CVs). Propuesta: auto-compra de un incremento de 5 USD cuando el cupo restante < 20%, con alerta; revisar mensualmente el ratio delivery/storage.
4. **Claude API:** límite de gasto duro en el workspace de Anthropic = tope 4.1; límites de uso por usuario final y por feature (SPEC §4); dashboard de costo por request desde el campo `usage` con alerta de desvío >30% semana contra semana.
5. **Mercado Pago:** reconciliación periódica (SPEC §8) que incluya verificación del % de comisión efectivo + retenciones; alerta si el efectivo supera en >1 punto lo previsto por el plan elegido.
6. **GitHub Actions:** límite de gasto en 0 USD hasta que una D-0XX habilite pagar minutos extra.
7. **Revisión trimestral de precios:** todos los proveedores de este registro se re-verifican cada 3 meses (Supabase y Google Play tienen historial de cambios; Verisign sube .com en nov-2026). Cada re-verificación actualiza "Fecha de verificación" y, si hay cambio, pasa la decisión a estado `revisar`.

---

## 5. Qué requiere análisis antes de agregarse

**Regla dura (SPEC §13): ningún SaaS, API, SDK pago o dependencia externa nueva entra al proyecto sin registro D-0XX en este documento, aprobado por el fundador.**

Requieren entrada D-0XX previa (lista no exhaustiva):

- Cualquier **proveedor nuevo** (analytics, CDP, A/B testing, mapas/geocoding, verificación de identidad/CUIT, antifraude, herramientas de moderación, SMS/WhatsApp, videollamadas, CDN extra, hosting web).
- **Upgrades de plan** de proveedores existentes (p. ej. Supabase compute add-on, Sentry con más eventos, Resend Pro→Scale).
- **Features pagas nuevas** de proveedores ya aprobados (p. ej. web search de Anthropic, dominio custom de api.video).
- Todo lo que toque **datos personales de candidatos** requiere además el checklist de [PRIVACY.md](PRIVACY.md) (base legal, DPA, transferencia internacional) y de [SECURITY.md](SECURITY.md) antes de aprobarse.
- **Dominios y cuentas de store adicionales** para expansión internacional (UY/CL/CO/PE/BR).

Contenido mínimo del análisis (los campos de la plantilla §2, con énfasis en):
1. Free tier real y en qué momento se agota con nuestros volúmenes.
2. Costo en los 3 escenarios con supuestos explícitos.
3. Lock-in y **estrategia de salida documentada** (obligatoria por SPEC §13 — sin plan de salida no hay aprobación).
4. Alternativa más barata comparada (mínimo una).
5. Impacto impositivo AR (¿se paga al exterior? ¿aplica percepción RG 5617 / IVA importación de servicios? — ver D-010).
6. Tope mensual propuesto y alarma asociada (se agrega a la tabla §4.1).

---

*Fin del registro. Próxima revisión programada: 2026-11-12 (trimestral) o ante cualquier cambio de precios/límites de los proveedores listados.*
