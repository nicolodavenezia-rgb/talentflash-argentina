# TalentFlash — Documento de Producto

**Última actualización:** 2026-08-12
**Estado:** propuesta inicial — pendiente de aprobación del fundador

> **Nota metodológica:** este documento sigue el SPEC de TalentFlash Argentina (brief de producto compartido, fuente de verdad de `01_app/docs/`). Las secciones 6 (Alcance del MVP) y 8 (Reglas de IA) reproducen literalmente SPEC §5 y §6. Todos los precios de competencia y proveedores provienen de la investigación verificada el 12-08-2026 (fuentes citadas en cada caso). Documentos relacionados: `UX_FLOWS.md` (flujos de usuario), `ARCHITECTURE.md` (stack técnico), `DATA_MODEL.md` (modelo de datos), `PRIVACY.md` (datos personales, consentimientos y marco legal), `SECURITY.md` (seguridad), `COST_DECISIONS.md` (log técnico de decisiones de costo), `ROADMAP.md` (fases y fechas).

---

## 1. Visión y propuesta de valor

**Visión:** ser la forma estándar de conseguir y cubrir puestos operativos en gastronomía y hotelería de América Latina, reemplazando el CV en papel y el "mandame un WhatsApp" por una presentación breve — video **opcional** de **20–30 segundos**, con alternativa de **texto o audio de igual jerarquía** (SPEC §1/§5) — más un perfil profesional estructurado, y un match recíproco en horas, no semanas.

### Para el candidato (gratis, siempre)
- **Un solo perfil con presentación en video (opcional, 20–30 s)** que muestra lo que un papel no puede: actitud, presencia, manejo del idioma, energía — exactamente lo que un encargado de salón o un jefe de cocina evalúa en los primeros 2 minutos de una entrevista. El video **nunca es obligatorio**: el candidato puede presentarse con texto o audio, con igual jerarquía en el producto (ver `UX_FLOWS.md` §4).
- **Postulación en un tap**, desde el celular, sin PC ni formularios largos.
- **Respuesta rápida y trato digno:** estados de candidatura visibles (enviada · vista · entrevista propuesta · aceptada · rechazada · cerrada; aprobados el 12-08-2026 por el fundador), sin el silencio eterno de los portales tradicionales.

### Para la empresa (PyME gastronómica/hotelera)
- **Ver antes de citar:** la presentación en video (20–30 s) filtra en medio minuto lo que hoy requiere coordinar una entrevista presencial que la mitad de las veces se cae. Menos entrevistas fallidas, menor time-to-hire.
- **Acceso completo a los candidatos desde el plan de entrada** — lo que la competencia capa a propósito (Bumeran muestra solo 5 postulaciones en su plan gratis; Zonajobs oculta los datos de contacto; ver §5).
- **Suscripción mensual sin permanencia, más barata que un solo aviso suelto de la competencia**, pensada para un sector que contrata todo el año (rotación ~70% anual, ver §2).

**Diferenciador central:** video-first + IA (subtítulos automáticos en español, extracción de datos del video, matching explicable) + precio de entrada por debajo del aviso individual de Computrabajo/Bumeran.

---

## 2. Problema y oportunidad

**El problema (gastronomía/hotelería, CABA + GBA):**

- **Rotación altísima:** estimaciones LatAm sitúan la rotación anual del sector en ~70% (rango 50–100%+; en A&B hasta 80–130%). Dirigentes gremiales argentinos (UTHGRA) confirman que los empleados jóvenes duran en promedio ~3 meses en el puesto ([fuente](https://gestiondetalentohumano.com.mx/alta-rotacion-dpersonal-restaurantes-hoteles/), estimación — no hay estadística oficial argentina). Un local con 10 empleados hace del orden de **5 a 10 contrataciones por año**.
- **Procesos informales:** el reclutamiento real pasa por grupos de Facebook/WhatsApp, cartel en la vidriera, Instagram del local y boca a boca. Es gratis pero sin filtro: el dueño recibe 80 mensajes, entrevista a 10, se presentan 4.
- **Los portales formales no sirven al segmento:** el aviso individual pago de Computrabajo AR cuesta **desde ARS 48.145 a 70.395** ("a confirmar", [fuente](https://empresa.ar.computrabajo.com/Home/ProductsAndServices)) y los planes gratis están capados a propósito (§5). Para una PyME que contrata 5-10 veces al año, eso son ARS 250.000–700.000 anuales por un producto pensado para búsquedas de oficina, no para cubrir un turno de salón el viernes.
- **El costo de la vacante sin cubrir es alto:** el básico de convenio de un mozo/cocinero en CABA ronda ARS 1,3 M brutos/mes (estimación, escala UTHGRA jun-sep 2026, [fuente](https://estudiovilaplana.com.ar/sueldos-gastronomicos/)). Un aviso de Computrabajo cuesta apenas ~4-5% de ese sueldo: hay espacio de pricing, el problema del incumbente es el producto, no el precio absoluto.

**La oportunidad:** un producto móvil, video-first, con acceso completo a candidatos desde el primer peso, con pricing de suscripción alineado a la frecuencia real de contratación del sector. Nadie está atendiendo específicamente este vertical en Argentina.

---

## 3. Usuarios objetivo y jobs-to-be-done

### Candidato tipo
Persona de 18–35 años, CABA/GBA, busca trabajo de mozo/a, cocinero/a, bachero/a, barista, recepcionista, housekeeping, delivery interno. Usa el celular para todo, no tiene CV actualizado (o no tiene CV), se mueve por transporte público (la zona/turno importa tanto como el sueldo).

**JTBD candidato:**
1. "Cuando necesito trabajo ya, quiero postularme a muchos lugares cerca mío sin armar un CV, para empezar a trabajar esta semana."
2. "Cuando me postulo, quiero que me vean como soy en persona, para que no me descarten por un papel flojo."
3. "Cuando espero respuesta, quiero saber si me vieron y en qué quedó, para no quedarme colgado."

### Empresa tipo
Dueño/a o encargado/a de un local gastronómico o hotel de 5–50 empleados en CABA/GBA. Sin área de RRHH. Contrata bajo presión (se fue alguien, el turno queda descubierto). Decide con el instinto de la primera impresión.

**JTBD empresa:**
1. "Cuando se me va un empleado, quiero candidatos filtrados y ver cómo son antes de citarlos, para cubrir el puesto en días y no quemar horas en entrevistas fallidas."
2. "Cuando publico una búsqueda, quiero acceso completo a todos los que se postulan, para no pagar extra por desbloquear contactos."
3. "Cuando contrato seguido, quiero un costo mensual previsible, para no pagar un aviso caro cada vez."

**Usuario secundario (fase 2):** cadenas y grupos gastronómicos multi-sucursal, consultoras de RRHH del sector.

---

## 4. Mercado inicial y plan de expansión

**Secuencia: AR → UY → CL → CO/PE → BR (Brasil como mercado separado).**

| Fase | Mercado | Racional | Prerrequisitos |
|---|---|---|---|
| 0–1 | **CABA + GBA** | Densidad máxima de locales gastronómicos/hoteles del país; equipo en el terreno; validación del modelo con un solo idioma, una sola moneda y un solo régimen fiscal. | MVP + billing Mercado Pago (ver `COST_DECISIONS.md`). |
| 1.5 | Interior AR (Córdoba, Rosario, Mendoza, MDQ) | Mismo producto, mismo billing; estacionalidad turística (MDQ, Mendoza) genera picos de contratación. | Tracción demostrada en CABA+GBA. |
| 2 | **Uruguay** | Proximidad cultural y horaria; Montevideo + Punta del Este (estacionalidad fuerte); mercado chico ideal para ensayar playbook de internacionalización (pagos locales, soporte). | Medio de pago local (MP opera en UY); ajuste de convenios/terminología. |
| 3 | **Chile** | Mercado formal más grande, mayor poder adquisitivo B2B; Santiago concentra el sector. | Entidad o partner local; pricing en CLP. |
| 4 | **Colombia / Perú** | Escala (Bogotá, Medellín, Lima); sector gastronómico en crecimiento; español rioplatense → neutro en producto y prompts de IA. | Localización de contenido y matching; medios de pago locales. |
| 5 | **Brasil (mercado separado)** | El mercado más grande de la región pero **otro producto-país**: portugués (UI, prompts, subtítulos Whisper pt-BR), competencia local fuerte (Catho, Gupy, InfoJobs BR), Pix como medio de pago, entidad legal propia y régimen fiscal distinto. Se planifica como unidad de negocio independiente, no como "un país más". | P&L propio, equipo local o partner, re-evaluación completa de pricing. |

**Regla de expansión:** no se abre un mercado nuevo sin que el anterior tenga retención de empresas ≥ objetivo de fase (ver §10) y payback de CAC < 6 meses (propuesta a validar).

---

## 5. Competencia y benchmarking

Datos verificados el 12-08-2026 (tipo: oficial / a confirmar / estimación según la fuente).

| Competidor | Producto | Precio | Tipo | Limitaciones clave | Fuente |
|---|---|---|---|---|---|
| **Bumeran** | Aviso gratis | ARS 0 | Oficial | Solo **5 postulaciones visibles**; máx. 3 avisos/mes; 30 días | [bumeran.com.ar/productos/gratis](https://www.bumeran.com.ar/productos/gratis/) |
| **Bumeran** | Aviso pago (Simple/Destacado/Superdestacado) | ~ARS 80.000 (rango est. 50.000–150.000) | A confirmar (login requerido; estimado por paridad con Computrabajo, mismo grupo Jobint que Zonajobs) | 60 días; CVs por 90 días | [landing e-commerce](https://www.bumeran.com.ar/empresas/ecommerce/landingProductos) |
| **Computrabajo** | Aviso ESSENTIAL | desde ARS 48.145 | A confirmar (página oficial vista vía índice; fetch directo 403) | 60 días; CVs por 30 días; precio "desde", + IVA probable | [empresa.ar.computrabajo.com](https://empresa.ar.computrabajo.com/Home/ProductsAndServices) |
| **Computrabajo** | Aviso PRO | desde ARS 58.145 | A confirmar | 60 días; contactos ilimitados | ídem |
| **Computrabajo** | Aviso PREMIUM | desde ARS 70.395 | A confirmar | 60 días; destacado + urgente | ídem |
| **Zonajobs** | Aviso gratis | ARS 0 | Oficial | **Sin datos de contacto** de postulantes | [zonajobs.com.ar/productos/gratis](https://www.zonajobs.com.ar/productos/gratis/) |
| **Zonajobs** | Aviso pago (Classic/Gold) | ~ARS 80.000 (rango est. 50.000–150.000) | A confirmar | Solo 30 días de publicación | [condiciones](https://www.zonajobs.com.ar/empresas/condicionesDeContratacion) |
| **LinkedIn** | Job post gratis | USD 0 | Oficial | 1 solo aviso activo, visibilidad limitada | [ayuda LinkedIn](https://www.linkedin.com/help/linkedin/answer/a518781/publica-empleos-gratis-con-linkedin?lang=es) |
| **LinkedIn** | Job post promocionado (PPC) | ~USD 15/día (rango 5–30) ≈ USD 300–450/mes por aviso | Estimación (el modelo PPC es oficial; el monto no se publica) | Un orden de magnitud más caro; no compite en este segmento | [precios anuncios de empleo](https://www.linkedin.com/help/linkedin/answer/a519464/precios-de-los-anuncios-de-empleo?lang=es) |
| **Canales informales** (Facebook/WhatsApp/Instagram/cartel) | — | ARS 0 | — | Sin filtro, sin estados, sin video estructurado; es la competencia real del tier gratis | — |
| **Consultoras del sector** | Búsqueda | 50–100% de un sueldo mensual (est.) | Estimación | Solo puestos jerárquicos; fuera del presupuesto PyME | — |

**Lecturas para el pricing de TalentFlash:**
1. El **precio ancla** del mercado es el aviso individual de Computrabajo: ARS 48.145–70.395 (~USD 32–46 al oficial BNA de $1.515, verificado 12-08-2026 en [bna.com.ar](https://www.bna.com.ar/Personas)).
2. Los planes gratis de los incumbentes están **capados en el acceso a candidatos** — ahí está el hueco: TalentFlash da acceso completo a candidatos en todos los tiers y limita por cantidad de ofertas activas.
3. Regla de oro: **el plan mensual de entrada debe costar menos que UN aviso suelto de la competencia** (< ~ARS 48.000/mes).
4. Los incumbentes hacen lock-in con packs y membresías con vencimiento; TalentFlash se diferencia con **mensual sin permanencia**.

---

## 6. Alcance del MVP

Alcance completo según **SPEC §5** (fuente de verdad). El MVP incluye:

1. Autenticación y recuperación de cuenta.
2. Onboarding diferenciado candidato/empresa.
3. Perfil de candidato.
4. Perfil de empresa.
5. Verificación de empresa con CUIT.
6. Grabación o subida de video (**20–30 s, opcional, con alternativa de texto o audio** de igual jerarquía).
7. Transcripción y subtítulos.
8. Perfil profesional estructurado.
9. Publicación de ofertas.
10. Feed de ofertas.
11. Feed de candidatos para empresas.
12. Búsqueda.
13. Filtros.
14. Postulación.
15. Invitaciones de empresas.
16. Match recíproco.
17. Chat.
18. Notificaciones.
19. Ofertas guardadas.
20. Estados de postulación — visibles para el candidato: **enviada, vista, entrevista propuesta, aceptada, rechazada y cerrada** (aprobado el 12-08-2026 por el fundador). `vista` se registra cuando el reclutador abre el detalle de la candidatura; nunca se registra ni se infiere atención, interés, emoción ni calidad de visualización (ver `UX_FLOWS.md` §12).
21. Bloqueo de usuarios.
22. Denuncias.
23. Moderación.
24. Panel administrativo.
25. Exportación de datos.
26. Eliminación de cuenta.

**Regla del chat:** el chat entre candidato y empresa existe únicamente como **consecuencia del match recíproco** (ítems 14–17): la empresa acepta una postulación o el candidato acepta una invitación. Sin match no hay chat, ninguna parte puede iniciar mensajes fríos y cada conversación queda vinculada a una oferta concreta (ver `UX_FLOWS.md` §10–11).

### Campos OBLIGATORIOS de toda oferta (SPEC §5 — sin excepciones)

Sueldo o rango salarial; modalidad contractual; relación de dependencia o monotributo; jornada completa o parcial; días y horarios; presencial / híbrido / remoto; provincia; localidad; barrio (cuando aplique); experiencia requerida; disponibilidad; beneficios; fecha de vencimiento.

(Formulario, validaciones campo a campo y camino asistido por IA: `UX_FLOWS.md` §5.)

### Notas de implementación (no amplían ni recortan el alcance del SPEC)

- Frontend Flutter (Android, iOS y web responsive); la empresa opera también desde la web.
- Video: subida directa a Cloudflare Stream (URLs firmadas), subtítulos automáticos en español con revisión editable por el candidato antes de publicar.
- Matching asistido con coincidencias **explicables** y redacción asistida de ofertas, siempre dentro de las reglas de IA (§8).
- Billing B2B **100% web con Mercado Pago Suscripciones** (fuera de los stores: 0% de comisión Apple/Google; ver `COST_DECISIONS.md`).
- Moderación de contenido (video y texto) con IA + cola de revisión humana (supervisión humana siempre).
- Emails transaccionales (Resend, free tier al inicio); analytics de producto y monitoreo de errores (Sentry).
- Español rioplatense (`es-AR`) como único idioma del MVP.

---

## 7. No-objetivos del MVP

- **No** liquidación de sueldos, alta temprana AFIP/ARCA ni ningún feature de gestión post-contratación.
- **No** video-entrevistas en vivo (llamadas): el MVP es video asíncrono. Realtime encarece y complica (ver riesgos de Realtime en `COST_DECISIONS.md`).
- **No** tests psicométricos ni evaluaciones automatizadas de personalidad (además prohibido por §8).
- **No** otros verticales (retail, logística, oficina): solo gastronomía/hotelería.
- **No** otros idiomas ni países: solo es-AR, CABA+GBA.
- **No** scraping ni importación de CVs de otros portales.
- **No** app de escritorio nativa: empresa usa web responsive.
- **No** IAP en stores para B2B (decisión de margen, ver §9); B2C in-app queda para evaluar recién si se aprueba Candidato Plus.
- **No** marketplace de shifts/extras por día (modelo "gig") — posible fase futura, distinto modelo de negocio.

---

## 8. Reglas de IA: permitido / prohibido

Texto según **SPEC §6** (fuente de verdad). Principio rector (SPEC §1): la IA asiste a ambos lados pero **nunca toma decisiones automáticas de contratación**; supervisión humana siempre.

### Permitido

Ayudar al candidato a preparar su presentación; generar guion del video; teleprompter; mejorar textos; subtítulos; traducciones; transformar info informal en oferta estructurada; generar CV; sugerir preguntas de entrevista; resumir postulaciones; señalar coincidencias EXPLICABLES; asistir a moderación con supervisión humana.

### Prohibido

Decidir a quién contratar; rechazar candidatos automáticamente; puntajes ocultos; análisis de emociones; análisis de personalidad por cara o voz; reconocimiento facial; inferir salud, etnia, religión, orientación sexual, discapacidad u otras características sensibles; usar popularidad/likes como índice de capacidad profesional.

**Entrenamiento de modelos:** no se entrenan modelos con videos, audio o perfiles **sin consentimiento separado, específico y revocable**. Ese consentimiento es el `ai_training` de `PRIVACY.md` §4/§9: jamás es condición de uso de la app, es independiente del consentimiento de funciones de IA (`ai_features`) y se revoca con efecto hacia adelante.

---

## 9. Modelo de negocio

**Principio:** candidatos gratis, siempre. Monetiza la empresa. Los precios **se muestran y cobran en ARS** vía Mercado Pago Suscripciones, con referencia configurable en USD y revisión trimestral (inflación + benchmark); **nunca hardcodeados en el cliente — siempre desde el backend** (SPEC §7).

### Planes de empresa — precios aprobados el 12-08-2026 por el fundador **como hipótesis a validar con empresas reales, NO como precios definitivos**

> **Nota (regla de `COST_DECISIONS.md` §1):** esta tabla es solo **referencia de producto**. El pricing B2B vive únicamente en el Excel `02_business_e_costi/Costi_TalentFlash_Argentina.xlsx` (nunca dentro de `01_app/`); los montos de abajo están aprobados el 12-08-2026 por el fundador **solo como hipótesis a validar con empresas reales**; cuando se confirmen los precios definitivos, la decisión se registra como entrada **D-0XX** en `COST_DECISIONS.md` y se refleja en el Excel en el mismo commit.

| Plan | Precio ref./mes | Incluye | Para quién |
|---|---|---|---|
| **Gratuito** | 0 | Prueba limitada: 1 oferta activa, funciones base, acceso completo a candidatos y videos, pipeline básico. Sin IA de matching ni redacción. | El local que hoy usa Facebook/WhatsApp. Captura y activación. |
| **PyME** | **USD 25 (~ARS 37.900 al TC $1.515)** *(aprobado el 12-08-2026 por el fundador como hipótesis a validar; dentro del rango ARS 25.000–40.000 de `ROADMAP.md` F-13)* | 3 ofertas activas, filtros, **invitaciones a candidatos (búsqueda proactiva)**, chat, gestión de postulaciones, IA de matching + redacción asistida, panel de métricas. | Local único, 5–50 empleados. **Queda por debajo del aviso suelto más barato de Computrabajo (ARS 48.145).** |
| **Profesional** | **USD 70 (~ARS 106.100)** *(aprobado el 12-08-2026 por el fundador como hipótesis a validar)* | 10 ofertas activas, hasta 3 reclutadores, destacado de 2 ofertas/mes, analytics avanzado, herramientas IA, gestión avanzada, export de candidatos. | Grupos de 2–3 locales, hoteles medianos. Cuesta ~lo que 1,5–2 avisos sueltos de la competencia. |
| **Empresa** | **USD 180 (~ARS 272.700)** *(aprobado el 12-08-2026 por el fundador como hipótesis a validar)* | Ofertas ilimitadas, **multi-sede**, usuarios ilimitados, roles/permisos y administración, **API**, **reportes**, soporte prioritario, onboarding asistido. | Cadenas y grupos gastronómicos, hoteles grandes. |

**Los cuatro precios (incluido Candidato Plus, abajo) fueron aprobados el 12-08-2026 por el fundador como hipótesis a validar con empresas reales; no son precios definitivos.**

Justificación de anclas: PyME < 1 aviso Computrabajo Essential; Profesional ≈ 1,5 avisos Premium; Empresa ≪ el gasto anual real de un grupo (5–10 contrataciones/año/local × ARS 48–70 mil). El cliente compara "12 cuotas del plan vs 5–10 avisos/año (ARS 250–700 mil)".

### Ingresos adicionales (todos "propuesta a validar")
- **Destacado de oferta** one-shot para cualquier plan: USD 5–10 por 7 días.
- **Pack de avisos sin suscripción** (empresa que contrata una vez): 1 oferta 30 días, USD 15–20 — siempre más caro por unidad que el plan PyME, para empujar a suscripción.
- **Búsqueda proactiva** en la base de candidatos (invitar a postularse): **incluida desde el plan PyME** (las invitaciones son parte del plan PyME según SPEC §7), sin add-on.
- Otras líneas previstas por el SPEC §7: ofertas patrocinadas claramente identificadas; paquetes de ofertas; verificación prioritaria; página de empresa personalizada; servicios para agencias de recruiting; onboarding asistido; servicio manual "te ayudamos a contratar".
- Futuro (fase 2+): employer branding en video.

### Candidato Plus (opcional — ver decisión abierta §12)
- **USD 5/mes** (cobro in-app), aprobado el 12-08-2026 por el fundador **como hipótesis a validar, no como precio definitivo**; limitado a las **herramientas accesorias** que lista el SPEC §7: coach IA, teleprompter, portfolio avanzado, traducciones, estadísticas, CV.
- Quedan fuera "alertas prioritarias" y "quién vio tu perfil": no están en la lista del SPEC y rozan el principio de que el candidato **nunca paga por aumentar su probabilidad de ser contratado** (SPEC §7).
- **Límite duro:** nunca puede comprar posiciones en el ranking de una búsqueda ni ventaja alguna en el matching (rompería la confianza de la empresa y la equidad). Si no se puede garantizar esa percepción, no se lanza.

### Estructura de cobro
- B2B: web + Mercado Pago Suscripciones. Comisión según plazo de liberación: 6,99% inmediato → 1,49% a 35 días, siempre + IVA sobre la comisión (efectivo 8,46% → 1,80%; [fuente oficial](https://www.mercadopago.com.ar/herramientas-para-vender/suscripciones), verificado 12-08-2026). Plazo elegido: decisión abierta (§12).
- B2C (si se aprueba Candidato Plus): IAP en stores — Play 15% suscripciones ([fuente](https://support.google.com/googleplay/android-developer/answer/112622)), App Store 30%/15% con Small Business Program ([fuente](https://developer.apple.com/app-store/subscriptions/)).
- Detalle completo de costos e infraestructura: ver `COST_DECISIONS.md` y el Excel de `02_business_e_costi/`.

---

## 10. Métricas de éxito por fase

| Métrica | Definición | Fase 0 — Beta CABA (meses 1–3) | Fase 1 — Lanzamiento CABA+GBA (meses 4–9) | Fase 2 — Consolidación (meses 10–18) |
|---|---|---|---|---|
| Activación candidato | % de registrados que completan su presentación (video de 20–30 s, texto o audio) en 7 días | ≥ 40% | ≥ 50% | ≥ 55% |
| Activación empresa | % de empresas registradas que publican 1ª oferta en 7 días | ≥ 50% | ≥ 60% | ≥ 60% |
| Ofertas activas | ofertas vigentes simultáneas | 100 | 500 | 2.000 |
| Postulaciones/oferta | mediana en primeros 7 días de la oferta | ≥ 5 | ≥ 10 | ≥ 15 |
| Matches | matches (la candidatura pasa a "entrevista propuesta") / oferta | ≥ 2 | ≥ 3 | ≥ 4 |
| Time-to-hire | mediana publicación → "aceptada" | < 14 días | < 10 días | < 7 días |
| Retención empresas | churn mensual de empresas pagas | — (aún sin cobro) | < 10% | < 6% |
| Conversión free→pago | % de empresas free que pasan a plan pago en 60 días | — | ≥ 8% | ≥ 12% |

Umbrales: **propuesta a validar** con los primeros datos de la beta. La métrica norte (north star) propuesta: **contrataciones confirmadas por mes**.

---

## 11. Riesgos de producto

1. **Doble red (huevo-gallina):** sin ofertas no vienen candidatos y viceversa. Mitigación: lanzamiento barrio por barrio (empezar por 2–3 polos gastronómicos de CABA), venta directa a los primeros 50 locales, tier gratis de empresa sin fricción.
2. **Fricción del video:** grabar un video intimida más que subir un CV. Mitigación de base: el video es **opcional** (20–30 s), con presentación por **texto o audio de igual jerarquía** (SPEC §1/§5). Además: guion guiado in-app, teleprompter, re-grabación ilimitada, ejemplos, y perfil utilizable sin video.
3. **Sesgo y discriminación percibida o real:** el video expone atributos protegidos antes que un CV. Es el riesgo reputacional y legal más serio del producto. Mitigación: reglas de IA (§8), motivos de descarte estructurados, auditoría periódica de tasas de preselección por segmento, asesoría legal (ver `PRIVACY.md`).
4. **Calidad del ASR en español rioplatense:** las captions de Cloudflare Stream usan Whisper; la calidad con acento local y jerga gastronómica está por validar (marcado como riesgo en la investigación de proveedores). Mitigación: eval propia en beta; corrección manual del candidato sobre su transcripción.
5. **Competir contra "gratis":** el canal real hoy es Facebook/WhatsApp a costo cero. El tier gratis tiene que ser claramente superior a esa experiencia, no solo a los portales pagos.
6. **Inflación y pricing en ARS:** precios en USD de referencia protegen el ingreso pero pueden percibirse como aumentos bruscos en ARS. Mitigación: revisión trimestral comunicada, tope de ajuste por ciclo (propuesta a validar).
7. **Dependencia de proveedores:** Anthropic (IA), Cloudflare Stream (video), Supabase (backend), Mercado Pago (cobros). Estrategias de abstracción y salida documentadas en `ARCHITECTURE.md` y `COST_DECISIONS.md`. Riesgo operativo puntual: el storage de Stream es prepago — si se agota el cupo, **los candidatos no pueden subir video** (monitoreo + auto-compra obligatorios).
8. **Churn estructural de candidatos:** el candidato que consigue trabajo deja de usar la app (¡éxito!) pero vuelve en ~3 meses por la rotación del sector. El producto debe tratar la re-activación como flujo de primera clase (perfil persistente, "avisame cuando haya algo mejor").
9. **Reacción de incumbentes:** Jobint (Bumeran/Zonajobs) o Computrabajo pueden bajar precios o copiar el video. La defensa es el foco vertical (taxonomía, turnos, tono) y la velocidad, no una patente.

---

## 12. Decisiones abiertas que requieren aprobación del fundador

1. **Precios definitivos de los planes** (§9) — el 12-08-2026 el fundador aprobó **como hipótesis a validar con empresas reales** (no como precios definitivos): PyME **USD 25/mes**, Profesional **USD 70/mes**, Empresa **USD 180/mes** y Candidato Plus **USD 5/mes** (solo herramientas accesorias). Queda abierta la validación con empresas reales y la fijación final; al confirmarse, el pricing se registra como entrada **D-0XX** en `COST_DECISIONS.md` y el detalle vive en el Excel de `02_business_e_costi/`.
2. **Límites exactos del plan Gratuito de empresa** (el SPEC §7 lo define como "prueba limitada, 1 oferta activa, funciones base"): confirmar límites finos vs alternativa de trial de 30 días del plan PyME.
3. **Candidato Plus: ¿se lanza o se descarta?** Riesgo de percepción "pay-to-play" vs ingreso incremental. Recomendación del equipo: posponer a fase 2.
4. **Plazo de acreditación de Mercado Pago:** 35 días al 1,80% efectivo (mejor margen, peor caja) vs 10 días al 5,43% (equilibrio) vs inmediato al 8,46%. Recomendación: 10 días al inicio, migrar a 18–35 al ganar colchón de caja.
5. **Orden de expansión UY antes que CL** (§4) — confirmar contra apetito de inversión y partners disponibles.
6. **Política de moderación:** umbral de revisión humana (todo video nuevo vs solo flagged por IA) — impacta costo operativo y tiempo de publicación del perfil.
7. **Naming comercial de los planes** — el SPEC §7 los nombra Gratuito/PyME/Profesional/Empresa; confirmar si se mantienen como nombres comerciales o solo como identificadores internos.

---

*Documentos relacionados: `UX_FLOWS.md` · `ARCHITECTURE.md` · `DATA_MODEL.md` · `PRIVACY.md` · `SECURITY.md` · `COST_DECISIONS.md` · `ROADMAP.md`*
