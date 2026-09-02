# TalentFlash Argentina — Privacidad y Cumplimiento

**Última actualización:** 2026-09-02
**Estado:** propuesta inicial — pendiente de aprobación del fundador

> Este documento define el marco de privacidad y cumplimiento de TalentFlash Argentina. Es una propuesta de trabajo del equipo fundador: **nada de lo escrito acá reemplaza el asesoramiento de un abogado argentino especializado en protección de datos**. Los puntos que requieren validación profesional están marcados explícitamente. Referencias cruzadas: `ROADMAP.md` (gate de privacidad por feature), `ARCHITECTURE.md` (infraestructura y regiones), `DATA_MODEL.md` (esquema de tablas), `SECURITY.md` (medidas técnicas).

---

## 1. Marco legal aplicable

| Norma / organismo | Qué implica para TalentFlash |
|---|---|
| **Ley 25.326** de Protección de Datos Personales (y decreto reglamentario 1558/2001) | Ley marco vigente. Define datos personales, datos sensibles (art. 2), consentimiento (art. 5), derechos del titular (arts. 13–17) y transferencias internacionales (art. 12). |
| **AAIP** (Agencia de Acceso a la Información Pública) | Autoridad de control. Emite disposiciones y resoluciones que nos aplican (medidas de seguridad recomendadas — Resolución 47/2018; cláusulas modelo de transferencia — Disposición 60-E/2016). |
| **Registro Nacional de Bases de Datos** | Obligación de inscribir nuestras bases de datos ante la AAIP antes de operar (art. 21, Ley 25.326). El trámite es online y gratuito; hay que verificar el procedimiento y la periodicidad de renovación vigentes. **Acción: inscribir antes del lanzamiento — checklist §13.** |
| **Anteproyecto / proyecto de nueva ley de datos personales** | Existe un proyecto de reforma integral (estilo RGPD: notificación obligatoria de incidentes, DPO, evaluaciones de impacto, multas actualizadas). Su estado parlamentario cambia; **hay que verificar con abogado el estado actual y diseñar ya con el estándar más exigente para no re-trabajar**. |
| Normas laborales y antidiscriminación (Ley 23.592, LCT) | Relevantes porque intermediamos búsqueda laboral: refuerzan §10 (anti-discriminación). Verificar alcance con abogado. |

**Criterio de diseño:** cumplimos Ley 25.326 como piso y adoptamos voluntariamente prácticas del proyecto de reforma / RGPD (consentimiento granular, notificación de incidentes en 72 hs, privacy by design) como techo. Así el producto no necesita rediseño si la reforma se aprueba.

---

## 2. Rol: responsable del tratamiento

- **TalentFlash Argentina** es el **responsable de la base de datos / responsable del tratamiento** en los términos de la Ley 25.326: decide fines y medios del tratamiento de los datos de candidatos y empleadores.
- Nuestros proveedores (Supabase/AWS, Cloudflare, Anthropic, Google, Apple) actúan como **encargados del tratamiento**: procesan datos solo bajo nuestras instrucciones, con DPA firmado (ver §8).
- **Caso especial — empleadores:** cuando un empleador accede al perfil/video de un candidato, ese acceso ocurre dentro de la plataforma bajo nuestras reglas. Si el empleador **exporta o copia** datos fuera de la plataforma, se convierte en responsable independiente. Los Términos y Condiciones de empleadores deben: (a) prohibir uso de los datos fuera del proceso de selección concreto, (b) prohibir retención una vez cerrada la búsqueda, (c) prohibir cesión a terceros. **Redacción contractual a validar con abogado.**

**Estado de implementación (Bloque D, T-022/T-024).** La exposición del perfil
de candidato a empresas quedó implementada **por campo**, vía una proyección
server-side con whitelist (migración `0023`): la empresa recibe el nombre de
pila (nunca el nombre completo), sin fecha de nacimiento, sin datos de
contacto y sin expectativa salarial; ante cualquier condición fallida la
respuesta es indistinguible de "no existe" (fail-closed). La policy que le
permitía leer la fila cruda del perfil fue eliminada. La foto de perfil vive
en un bucket **privado**: solo URLs firmadas con vencimiento corto, metadata
EXIF eliminada server-side por re-encoding (la foto no filtra ubicación ni
dispositivo), y al quitar la foto se borran de inmediato el avatar y su
thumbnail.

---

## 3. Mayores de 18 años únicamente

**Política:** TalentFlash es solo para mayores de 18 años. No tratamos datos de menores, punto.

Medidas:

1. **Declaración en el registro:** checkbox obligatorio "Declaro ser mayor de 18 años" + fecha de nacimiento obligatoria. Cuentas con fecha < 18 años: registro bloqueado.
2. **Validación cruzada:** si el login es federado (Google/Apple) y el proveedor expone rango etario, se valida contra la declaración.
3. **Detección y baja:** cualquier reporte o indicio razonable de que un usuario es menor dispara suspensión inmediata del perfil y flujo de verificación; si se confirma, eliminación total de la cuenta y sus datos (sin ventana de gracia).
4. **Registro de la declaración:** la aceptación queda registrada en la tabla `consents` (tipo `age_declaration`) con timestamp y versión del texto, como prueba.
5. **Sin verificación documental en MVP** (no pedimos DNI — ver §7 minimización). Si más adelante se exige verificación de identidad, se documentará como feature con su propio análisis de privacidad (ver §12).

---

## 4. Consentimientos granulares y separados

Cada finalidad tiene su **propio consentimiento, independiente y no empaquetado**. Rechazar uno no bloquea los demás (salvo el de tratamiento base, sin el cual no hay cuenta).

| Tipo (`consent_type`) | Cubre | Obligatorio para usar la app | Revocable |
|---|---|---|---|
| `data_processing` | Tratamiento de datos para operar la cuenta (registro, perfil, postulaciones, chat) | Sí — es la base del servicio | Revocarlo = eliminar la cuenta (§5) |
| `video_profile_publication` | **Publicar** el video + perfil para que empleadores los vean | No — se puede tener cuenta sin publicar | Sí, efecto inmediato: despublicación |
| `ai_features` | Funciones IA sobre los datos propios (transcripción del video, sugerencias de perfil, matching asistido) | No — la app funciona en modo manual sin IA | Sí, efecto inmediato |
| `ai_training` | Uso de datos para **entrenar o mejorar modelos** (ver §9) | No — jamás es condición de uso | Sí, con efecto hacia adelante |
| `age_declaration` | Declaración de mayoría de edad (§3) | Sí | No aplica (es una declaración, no una autorización) |

Reglas de implementación:

- **Versionado:** cada texto de consentimiento tiene versión (`policy_version`). Si el texto cambia sustancialmente, se re-solicita el consentimiento; los consentimientos viejos quedan en la tabla como histórico, nunca se sobreescriben.
- **Prueba de consentimiento:** guardamos qué texto vio el usuario, cuándo, desde dónde y en qué idioma. Ante un requerimiento de la AAIP tenemos que poder demostrar cada consentimiento.
- **Revocación:** desde la app, en ≤ 3 taps, sin fricción ni "retención". La revocación inserta una fila nueva (no borra la del otorgamiento).

**Estado de implementación (Bloque C, T-018).** El ledger `consents` está
operativo: append-only real (sin UPDATE/DELETE ni para el propio usuario),
con versión, timestamp y canal por evento, versión vigente por tipo en
`consent_versions` (única fuente de verdad, atada por FK al documento legal
publicado) y reconsentimiento forzado en la app cuando un texto obligatorio
sube de versión. Las aceptaciones se registran recién con la sesión iniciada,
en el primer paso del onboarding — nunca desde `user_metadata` ni desde el
formulario de alta sin sesión, porque eso no serviría como prueba. A los
tipos de esta tabla se suma `terms_acceptance` (aceptación de TyC, exigida por
T-018): es aceptación contractual y no un consentimiento del art. 5, pero
comparte el mismo registro auditable. `ai_training` no se solicita en el MVP y
la base rechaza otorgarlo. Los textos publicados en `/legal/*` son borradores
en es-AR claro y lo declaran: la revisión de abogado del §13 sigue pendiente.

Esquema ilustrativo (detalle final en `DATA_MODEL.md`):

```sql
CREATE TABLE consents (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid NOT NULL REFERENCES users(id),
  consent_type   text NOT NULL,          -- 'data_processing' | 'video_profile_publication'
                                         -- | 'ai_features' | 'ai_training' | 'age_declaration'
  policy_version text NOT NULL,          -- p. ej. 'privacy-2026-08-v1'
  granted        boolean NOT NULL,       -- true = otorgado, false = revocado
  occurred_at    timestamptz NOT NULL DEFAULT now(),
  channel        text NOT NULL,          -- 'app_android' | 'app_ios' | 'web'
  locale         text NOT NULL,          -- 'es-AR'
  evidence       jsonb NOT NULL          -- hash del texto mostrado, user_agent, ip truncada/hasheada
);
-- Tabla append-only: sin UPDATE ni DELETE (enforzar por permisos/RLS).
-- Estado vigente = última fila por (user_id, consent_type).
```

---

## 5. Derechos del titular y flujos operativos

Plazos legales (Ley 25.326): **acceso: 10 días corridos** desde el pedido (art. 14); **rectificación / actualización / supresión: 5 días hábiles** (art. 16). Los flujos se diseñan para resolver en menos tiempo y de forma autogestionada.

| Derecho | Flujo operativo | Plazo objetivo (interno) | Plazo legal máx. |
|---|---|---|---|
| **Acceso** | Pantalla "Mis datos": el usuario ve todo lo que tenemos de él sin pedir nada a soporte | Inmediato (self-service) | 10 días corridos |
| **Rectificación** | Edición directa de perfil; para datos no editables (p. ej. registros de consentimiento) ticket a soporte | 48 hs para tickets (propuesta a validar) | 5 días hábiles |
| **Exportación** | Botón "Exportar mis datos": genera un ZIP con (a) JSON de perfil, postulaciones, chats propios y consentimientos, y (b) archivos de media (video, foto). Link de descarga temporal firmado | Generación asincrónica ≤ 24 hs | — (buena práctica) |
| **Eliminación total** | Botón "Eliminar mi cuenta" → ventana de gracia de **30 días (propuesta a validar)** con cuenta desactivada y despublicada desde el minuto cero → pasada la ventana, borrado definitivo de datos y media | Despublicación inmediata; borrado al cierre de la ventana | 5 días hábiles desde que el pedido es firme |

Detalles del flujo de eliminación:

1. Al solicitar la baja: perfil y video **despublicados de inmediato**, chats ocultos para contrapartes nuevas, sesión de empleadores no puede encontrarlo más.
2. Durante la ventana de gracia el usuario puede reactivar con login.
3. Al cierre: borrado de filas y de objetos en storage (video, foto, exports), invalidación de caché CDN (Cloudflare purge), y borrado en backups según ciclo de rotación (documentar el plazo real de expiración de backups en `SECURITY.md`).
4. **Excepciones que sobreviven al borrado:** datos fiscales/de facturación (§6, obligación legal) y el mínimo registro de auditoría necesario para probar que la eliminación se hizo (id anónimo + timestamp).
5. Los mensajes que el usuario envió a otros pueden persistir en la bandeja del receptor pero se **anonimizan** (autor = "usuario eliminado").

Canal para ejercer derechos también por email (casilla dedicada, p. ej. `privacidad@…`), porque la ley no exige que el titular use la app.

---

## 6. Retención por tipo de dato

Regla general: **no guardamos nada sin fecha de vencimiento o criterio de baja definido.** Todos los plazos siguientes son **propuestas a validar** con abogado/contador, salvo donde se indica obligación legal.

| Dato | Retención | Qué pasa al vencer |
|---|---|---|
| **Videos de presentación** | Vencimiento **configurable por el usuario**: 30 / 60 / 90 días, default operativo 60 (**aprobado el 12-08-2026 por el fundador**). Aviso previo para renovar | Despublicación automática; borrado del archivo a los 30 días de vencido si no se renueva (propuesta a validar). Eliminación a pedido: regla aprobada debajo de esta tabla |
| **Perfil (datos de cuenta)** | Mientras la cuenta esté activa | Inactividad > 24 meses (propuesta a validar): aviso y luego flujo de eliminación §5 |
| **Chats** | Mientras ambas cuentas existan; máx. 24 meses desde el último mensaje del hilo (propuesta a validar) | Anonimización/borrado |
| **Postulaciones** | 24 meses desde el cierre de la búsqueda (propuesta a validar — plazo pensado para defensa ante reclamos; **validar con abogado laboralista**) | Anonimización (se conserva estadística agregada sin identificar) |
| **Logs de auditoría** (accesos, acciones sensibles) | 12 meses; los de seguridad, 24 meses (propuesta a validar) | Borrado |
| **Registros de consentimiento** (`consents`) | Vida de la cuenta + plazo de prescripción de acciones legales (**definir con abogado**) | Borrado |
| **Datos fiscales / facturación** (empleadores que pagan) | **10 años — obligación legal** (documentación comercial y fiscal; confirmar alcance exacto con contador) | Borrado al cumplirse el plazo |
| **Exports generados (§5)** | 7 días desde la generación (propuesta a validar) | Borrado automático del ZIP |

**Eliminación de videos y bajas de cuenta — aprobado el 12-08-2026 por el fundador.** Cuando un video se elimina o el titular pide la cancelación de su cuenta:

1. **Remoción inmediata de la visibilidad:** el video deja de ser accesible para empleadores desde el momento del pedido (despublicación + invalidación de caché CDN, §5).
2. **Borrado de los sistemas primarios** (base de datos y storage) dentro del plazo operativo previsto por la normativa aplicable (Ley 25.326, art. 16; plazos de §5).
3. **Backups:** las copias en backups deben expirar dentro del período de rotación documentado (`SECURITY.md`), salvo obligaciones legales de conservación.
4. **IA:** ningún video puede reutilizarse para entrenamiento de IA sin el consentimiento `ai_training`, específico y separado (§4, §9.1); la regla rige también durante cualquier ventana previa al borrado definitivo.

La implementación técnica de vencimientos (jobs, columnas `expires_at`) se especifica en `DATA_MODEL.md` y `ARCHITECTURE.md`.

---

## 7. Minimización: qué NO recolectamos

Lista explícita de datos que **no se piden, no se infieren y no se almacenan**:

- **DNI / pasaporte / documentos de identidad** (ni número ni escaneo) — en MVP no hay verificación documental.
- **Datos sensibles del art. 2, Ley 25.326:** origen racial o étnico, opiniones políticas, convicciones religiosas/filosóficas/morales, afiliación sindical, salud, vida sexual. Ver §10.
- **Datos biométricos como identificadores:** el video se almacena como archivo, pero **no se generan plantillas faciales ni de voz** para identificación o verificación biométrica.
- **Geolocalización precisa (GPS):** solo localidad/zona declarada por el usuario para el matching geográfico.
- **Contactos del teléfono, SMS, historial de llamadas.**
- **Historial salarial ni recibos de sueldo.**
- **Antecedentes penales o crediticios.**
- **Datos de terceros** (referencias laborales con datos de contacto de otras personas) — si más adelante se agregan referencias, requerirán su propio análisis (§12).
- Analytics: sin SDKs de publicidad ni tracking cross-app; solo métricas de producto propias y agregadas (detalle en `ARCHITECTURE.md`).

Si una feature futura necesita alguno de estos datos, no se agrega "porque puede servir": pasa por el gate de privacidad del `ROADMAP.md` (§12) y por revisión legal.

---

## 8. Transferencias internacionales

El art. 12 de la Ley 25.326 prohíbe transferir datos a países sin nivel adecuado de protección, salvo excepciones (consentimiento, cláusulas contractuales). La AAIP publica la lista de países adecuados y cláusulas modelo (Disposición 60-E/2016). **EE.UU. no está en la lista de países adecuados**, así que con cada proveedor necesitamos DPA con cláusulas contractuales equivalentes a las modelo.

| Proveedor | Para qué | Ubicación de datos | Cobertura contractual requerida |
|---|---|---|---|
| **Supabase (sobre AWS)** | Base de datos, auth, storage de media | Elegir región al crear el proyecto: **propuesta `sa-east-1` (San Pablo, Brasil)** para minimizar transferencia y latencia. Brasil tampoco está en la lista de adecuados → se necesitan cláusulas igual | DPA de Supabase + verificación de subencargados (AWS) |
| **Cloudflare** | CDN, protección, entrega de video | Red global (edge en múltiples países, incluido nodo en Argentina); caché efímera | DPA de Cloudflare; configurar TTLs de caché coherentes con §6 |
| **Anthropic** | Funciones IA (§9) vía API | EE.UU. | DPA / términos comerciales; verificar que la API **no use los datos para entrenamiento** por defecto y dejarlo asentado contractualmente |
| **Google** | Login federado, push (Android), Play Store | EE.UU. / global | Términos de datos de Google + DPA aplicable |
| **Apple** | Login federado, push (iOS), App Store | EE.UU. / global | Términos de Apple Developer Program |

Acciones concretas:

1. Inventariar y archivar los **DPAs firmados/aceptados** de los cinco proveedores antes del lanzamiento (checklist §13).
2. Documentar en `ARCHITECTURE.md` la región elegida de cada servicio y los subencargados declarados.
3. Informar las transferencias internacionales en la Política de Privacidad pública (proveedor, país, garantía).
4. **Validar con abogado** si, además de los DPAs, conviene incorporar las cláusulas modelo de la Disposición 60-E/2016 como anexo contractual propio.

---

## 9. Reglas para las funciones de IA

Principios no negociables, aplicables a toda feature IA presente o futura:

1. **Sin entrenamiento sin consentimiento específico.** Ningún dato de usuario — **incluidos los videos** — se usa para entrenar o ajustar modelos (propios o de terceros) sin el consentimiento `ai_training`: separado, específico, revocable y jamás condición de uso (§4). La revocación corta el uso hacia adelante. Con los proveedores (Anthropic) debe estar contractualmente garantizado que las llamadas de API no alimentan entrenamiento (§8).
2. **Sin decisiones automatizadas de contratación.** La IA nunca decide contratar, rechazar ni descartar a un candidato. Solo asiste: transcribe, resume, sugiere y ordena resultados. La decisión es siempre de una persona (el empleador). La UI no debe presentar salidas de IA como veredictos ("apto/no apto" está prohibido).
3. **Coincidencias siempre explicables.** Cada match o ranking guarda y puede mostrar sus factores (p. ej. "coincide en: skill X, zona, disponibilidad horaria"). Si no podemos explicar un resultado en términos que el usuario entienda, esa lógica no se shippea.
4. **Insumos limitados.** Los modelos solo reciben los campos necesarios para la función concreta; nunca reciben los campos vedados de §10 (que además no existen en la base).
5. **Registro:** cada uso de IA sobre datos de un usuario queda trazado en logs de auditoría (§6) — qué función, cuándo, sobre qué datos.

---

## 10. Anti-discriminación

Campos que **jamás se recolectan, infieren (por IA o heurísticas) ni almacenan**, y que jamás participan del matching o ranking:

- Origen racial o étnico
- Opiniones políticas
- Religión o convicciones
- Afiliación sindical
- Salud, discapacidad y embarazo
- Vida u orientación sexual
- Género como factor de ranking (si el usuario declara un género/pronombre para su perfil, es solo presentación; prohibido como filtro o variable de matching)
- Nacionalidad / condición migratoria como factor de ranking
- Estado civil y cargas de familia

Reglas operativas:

1. **Prohibición de inferencia:** ningún proceso (IA incluida) intenta deducir estos atributos a partir del video, la voz, la foto o el nombre. Está prohibido a nivel de diseño y se verifica en la revisión de cada feature (§12).
2. **Filtros de empleadores:** la búsqueda de empleadores no ofrece ni acepta filtros sobre estos campos. La edad solo existe como gate binario 18+ (§3), no como filtro de búsqueda (propuesta a validar con abogado laboralista: hay búsquedas con requisitos etarios legales legítimos; si se admite alguna excepción, debe estar justificada norma por norma).
3. **Moderación de avisos:** los textos de búsquedas laborales que pidan requisitos discriminatorios (Ley 23.592) se rechazan o moderan.
4. **Auditoría del matching:** revisar periódicamente que el ranking no genere disparidades sistemáticas (sesgo indirecto); dejar constancia de cada revisión.

---

## 11. Incidentes de seguridad

Contexto legal: la Ley 25.326 no impone hoy una notificación obligatoria general de brechas, pero la AAIP la recomienda entre sus medidas de seguridad (Resolución 47/2018) y el proyecto de reforma la haría obligatoria. **Adoptamos voluntariamente el estándar exigente:**

**Plan de respuesta (resumen; runbook completo en `SECURITY.md`):**

1. **Detección y triage** — cualquier miembro del equipo que detecte un posible incidente lo reporta de inmediato; se designa un responsable del incidente.
2. **Contención** — revocar credenciales/keys comprometidas, aislar el servicio afectado, preservar evidencia (logs).
3. **Evaluación** — en ≤ 48 hs: qué datos, cuántos titulares, qué riesgo real (¿datos publicados? ¿videos? ¿chats? ¿credenciales?).
4. **Notificación** — si hay riesgo para los titulares: notificar a la **AAIP** y a los **afectados** dentro de las **72 hs** de confirmado (propuesta voluntaria alineada al proyecto de reforma; formato y obligatoriedad exacta **a validar con abogado**). La comunicación a afectados debe decir: qué pasó, qué datos, qué hicimos, qué puede hacer el usuario.
5. **Post-mortem** — informe interno con causa raíz y correcciones; se archiva como evidencia de diligencia.

Registro de incidentes: todos los incidentes (notificados o no) quedan en un registro interno con evaluación y decisión fundada de notificar o no.

---

## 12. Privacy by design en cada feature

Regla de proceso, atada al `ROADMAP.md`: **ninguna feature entra al roadmap sin su declaración de impacto de privacidad.** Cada entrada de feature en `ROADMAP.md` incluye una sección fija:

- **Datos nuevos que toca o crea** (campos, media, logs)
- **Base legal / consentimiento requerido** (¿alcanza `data_processing` o necesita consentimiento nuevo? — si necesita uno nuevo, se agrega tipo a la tabla `consents`)
- **Retención** (fila nueva o existente en la tabla de §6)
- **Terceros involucrados** (¿sale algún dato a un proveedor nuevo? → §8)
- **Riesgos de §10** (¿puede introducir sesgo o inferencia prohibida?)

Features sin esta declaración se rechazan en la revisión de producto. Los cambios que amplían el uso de datos existentes cuentan como feature a estos efectos.

---

## 13. Checklist pre-lanzamiento

Bloqueantes — no se lanza sin tildar todo:

- [ ] **Abogado argentino especializado en datos personales:** revisión integral de este documento, Política de Privacidad pública, T&C (candidatos y empleadores), cláusulas de transferencia internacional (§8), plazos de retención (§6), estado del proyecto de reforma (§1) y excepciones etarias (§10.2).
- [ ] **Abogado laboralista (puede ser el mismo estudio):** postulaciones, anti-discriminación, retención para defensa de reclamos.
- [ ] **Especialista en privacidad/seguridad:** revisión técnica de RLS, cifrado, control de accesos, borrado efectivo (incl. backups y CDN), y prueba end-to-end de los flujos de derechos de §5.
- [ ] **Contador:** confirmación de plazos y alcance de conservación de datos fiscales/facturación (§6).
- [ ] Inscripción de las bases de datos en el **Registro Nacional de Bases de Datos (AAIP)**.
- [ ] **DPAs** de Supabase, Cloudflare, Anthropic, Google y Apple archivados; regiones de hosting documentadas en `ARCHITECTURE.md`.
- [ ] Tabla `consents` operativa, append-only, con versionado y flujos de otorgamiento/revocación probados.
- [ ] Política de Privacidad y T&C publicados, versionados, en es-AR y en lenguaje claro.
- [ ] Flujo de eliminación total probado: verificación manual de que no queda nada (DB, storage, CDN, backups vencidos).
- [ ] Plan de incidentes (§11) ensayado con un simulacro.
- [ ] Casilla `privacidad@` operativa y monitoreada, con responsable asignado.

---

*Documento vivo: toda modificación sustancial incrementa la versión (`policy_version`) y puede requerir re-consentimiento (§4). Cambios se registran en el historial del repositorio.*
