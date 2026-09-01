-- Bloque C (T-018/T-020): contenido legal versionado, versiones vigentes de
-- cada consentimiento y reglas del ledger `consents`.

-- ---------------------------------------------------------------------------
-- Documentos legales vigentes (versión 2026-08-31).
--
-- Redactados en es-AR y lenguaje claro a partir de docs/PRIVACY.md. Son
-- borradores de trabajo: NO fueron revisados por un abogado y lo dicen
-- explícitamente. No afirman plazos que PRIVACY.md marca como "propuesta a
-- validar"; solo citan los que fija la propia Ley 25.326.
-- ---------------------------------------------------------------------------

insert into legal_documents (slug, version, title, body) values
('terminos', '2026-08-31', 'Términos y condiciones de TalentFlash', $tf$AVISO IMPORTANTE: este documento es un borrador de trabajo del equipo fundador. Todavía no fue revisado ni validado por un abogado. Antes del lanzamiento público va a ser reemplazado por una versión revisada profesionalmente. Lo publicamos igual porque preferimos que sepas desde el primer día qué reglas aplicamos.

1. Qué es TalentFlash

TalentFlash es una plataforma que conecta personas que buscan trabajo con empresas que buscan personal, con foco inicial en gastronomía y hotelería de CABA y GBA. Las personas candidatas se presentan con un perfil profesional y, si quieren, con un video corto de presentación. El video siempre es opcional: podés usar la plataforma completa sin grabarlo.

2. Quién puede usar TalentFlash

Solo personas mayores de 18 años. Al crear tu cuenta declarás que tenés 18 años o más. Si detectamos que una cuenta pertenece a una persona menor de edad, la suspendemos y eliminamos sus datos.

3. Tu cuenta

Sos responsable de mantener tu contraseña en secreto y de lo que se haga con tu cuenta. Podés cerrar sesión cuando quieras y pedir la eliminación de tu cuenta desde la aplicación. Los datos de tu perfil deben ser veraces: una empresa que se registra debe existir y el CUIT que declara debe ser propio.

4. Qué está prohibido

Publicar información falsa o engañosa; usar la plataforma para discriminar (la ley 23.592 prohíbe la discriminación, también en avisos de empleo); acosar, estafar o enviar spam a otras personas; intentar acceder a datos ajenos; usar los datos de candidatos fuera del proceso de selección concreto para el que los viste.

5. Empresas

Las empresas se verifican con su CUIT antes de poder publicar búsquedas. Una empresa que accede a perfiles de candidatos solo puede usarlos para su proceso de selección: no puede copiarlos, retenerlos una vez cerrada la búsqueda ni cederlos a terceros.

6. Contenido que subís

Lo que publicás (perfil, video, textos de ofertas) sigue siendo tuyo. Nos autorizás a mostrarlo dentro de la plataforma según tus consentimientos de privacidad. Podemos quitar contenido que viole estos términos, avisándote el motivo.

7. Lo que no prometemos

TalentFlash conecta partes: no somos parte de la relación laboral que se forme y no garantizamos que consigas trabajo o cubras una vacante.

8. Cambios en estos términos

Si cambiamos estos términos de forma sustancial, te vamos a pedir que los aceptes de nuevo antes de seguir usando la plataforma. Cada versión queda identificada con su fecha.

9. Contacto

Por dudas sobre estos términos podés escribirnos desde la aplicación. El canal formal de contacto legal se va a publicar junto con la versión revisada de este documento.$tf$),
('privacidad', '2026-08-31', 'Política de privacidad de TalentFlash', $tf$AVISO IMPORTANTE: este documento es un borrador de trabajo del equipo fundador. Todavía no fue revisado ni validado por un abogado especializado en protección de datos. Antes del lanzamiento público va a ser reemplazado por una versión revisada profesionalmente e inscripta ante la autoridad de control (AAIP).

1. Quién trata tus datos

TalentFlash Argentina es la responsable del tratamiento de tus datos personales en los términos de la Ley 25.326 de Protección de Datos Personales.

2. Qué datos tratamos

Para operar tu cuenta: correo electrónico y contraseña (guardada cifrada). Para tu perfil de candidato: nombre, fecha de nacimiento (solo para verificar que sos mayor de 18), zona donde buscás trabajo (provincia, localidad y barrio), sector de interés, disponibilidad y modalidad preferida. Para una empresa: razón social, nombre de fantasía, CUIT, rubro, tamaño, zona y datos de la persona solicitante. Si más adelante grabás un video o audio de presentación, ese contenido también es un dato personal y se rige por esta política.

3. Qué datos NO recolectamos

No pedimos DNI ni documentos de identidad. No tratamos datos sensibles del artículo 2 de la Ley 25.326 (origen étnico, opiniones políticas, religión, afiliación sindical, salud, vida sexual). No generamos identificadores biométricos a partir de tu video o tu voz. No usamos tu ubicación GPS: solo la zona que declarás. No leemos tus contactos ni tu historial. No usamos SDKs de publicidad ni rastreo entre aplicaciones.

4. Consentimientos separados

Cada finalidad tiene su propio consentimiento, independiente y revocable. Rechazar uno no bloquea los demás, salvo el de tratamiento base sin el cual no hay cuenta:

— Tratamiento de datos para operar tu cuenta (obligatorio para usar la plataforma; revocarlo equivale a eliminar la cuenta).
— Declaración de mayoría de edad (obligatoria: la plataforma es solo para mayores de 18).
— Publicación de tu perfil y video ante empresas (opcional: sin este consentimiento tu cuenta funciona igual, pero las empresas no te descubren; vos igual podés ver ofertas y postularte).
— Funciones de inteligencia artificial sobre tus propios datos (opcional: sin este consentimiento todo funciona en modo manual).

Cada aceptación o revocación queda registrada con fecha, versión del texto y canal, como exige la ley. Podés revocar los consentimientos opcionales cuando quieras y el efecto es inmediato.

5. Entrenamiento de modelos de IA

No usamos tus datos, tu video ni tu voz para entrenar modelos de inteligencia artificial. Ese uso requeriría un consentimiento adicional, específico y revocable que hoy la aplicación ni siquiera solicita. La IA de TalentFlash solo asiste (transcribe, sugiere, ordena resultados de forma explicable) y nunca toma decisiones de contratación.

6. Tus derechos

La Ley 25.326 te da derecho a acceder a tus datos (respuesta dentro de los 10 días corridos), y a rectificarlos, actualizarlos o suprimirlos (dentro de los 5 días hábiles). Vas a poder ejercerlos desde la aplicación (ver, corregir, exportar y eliminar) y también por el canal de contacto que se publique con la versión revisada de este documento. La Agencia de Acceso a la Información Pública (AAIP) es la autoridad de control ante la que podés reclamar.

7. Cuánto tiempo guardamos tus datos

Regla general: nada se guarda sin un criterio de baja. Los plazos concretos de retención por tipo de dato están todavía en definición con asesoramiento profesional y se publicarán en una próxima versión de esta política. Lo que ya está decidido: al eliminar tu cuenta, tu perfil deja de ser visible de inmediato y los datos se eliminan de los sistemas primarios, conservando únicamente lo que una obligación legal exija guardar, en forma disociada de tu identidad.

8. Con quién compartimos datos

Con las empresas que usan la plataforma, solo según tus consentimientos (una empresa ve tu perfil si vos elegiste publicarlo o te postulaste a su búsqueda). Con proveedores de infraestructura que procesan datos bajo nuestras instrucciones. Algunos proveedores están fuera de la Argentina: antes del lanzamiento vamos a documentar cada transferencia internacional con las garantías contractuales que exige el artículo 12 de la Ley 25.326.

9. Seguridad

Aplicamos control de acceso por fila en la base de datos (cada cuenta solo puede leer y escribir lo suyo), cifrado en tránsito, y registro de acciones administrativas. Si ocurriera un incidente de seguridad que afecte tus datos, nuestro plan es evaluarlo y comunicarlo a las personas afectadas y a la AAIP.

10. Cambios en esta política

Si esta política cambia de forma sustancial, te vamos a volver a pedir el consentimiento correspondiente antes de seguir. Cada versión queda identificada con su fecha y las anteriores se conservan como registro.$tf$);

-- Versión vigente por consentimiento. `ai_training` queda fuera a propósito
-- (SPEC §6 / PRIVACY.md §9: el MVP no lo solicita y nada puede otorgarlo).
insert into consent_versions (consent_type, version, document_slug, is_mandatory) values
  ('terms_acceptance',          '2026-08-31', 'terminos',   true),
  ('age_declaration',           '2026-08-31', 'terminos',   true),
  ('data_processing',           '2026-08-31', 'privacidad', true),
  ('video_profile_publication', '2026-08-31', 'privacidad', false),
  ('ai_features',               '2026-08-31', 'privacidad', false);

-- ---------------------------------------------------------------------------
-- Reglas del ledger de consentimientos (T-018).
--
-- El trigger es SECURITY INVOKER a propósito: `current_user` distingue una
-- escritura de cliente ('authenticated'/'anon') de una server-side (seed,
-- service_role, RPC security definer), cosa que un SECURITY DEFINER no puede
-- hacer porque cambia el propio current_user. Bajo RLS solo puede leer los
-- consentimientos del propio usuario, que es exactamente lo que necesita.
-- ---------------------------------------------------------------------------

create or replace function private.guard_consent_write() returns trigger
language plpgsql
set search_path = ''
as $$
declare
  current_version text;
  last_granted boolean;
  last_version text;
begin
  if current_user not in ('authenticated', 'anon') or public.is_admin() then
    return new;
  end if;

  select cv.version into current_version
  from public.consent_versions cv
  where cv.consent_type = new.consent_type;

  -- Sin texto vigente no hay nada que aceptar ni revocar. Esto es lo que
  -- impide, a nivel base de datos, que `ai_training` se otorgue jamás desde
  -- el cliente (SPEC §6).
  if current_version is null then
    raise insufficient_privilege
      using message = 'Este consentimiento no se solicita en la aplicación';
  end if;

  select c.granted, c.version into last_granted, last_version
  from public.consents c
  where c.profile_id = new.profile_id
    and c.consent_type = new.consent_type
  order by c.seq desc
  limit 1;

  -- Otorgar exige la versión vigente del texto: nunca se registra la
  -- aceptación de un texto que el usuario no pudo haber visto.
  if new.granted and new.version is distinct from current_version then
    raise sqlstate 'TFCNS'
      using message = 'La versión aceptada no es la vigente';
  end if;

  -- Revocar puede referirse a la versión vigente o a la que se había
  -- aceptado; cualquier otra cosa es un dato inventado.
  if not new.granted
     and new.version is distinct from current_version
     and new.version is distinct from last_version then
    raise sqlstate 'TFCNS'
      using message = 'La versión revocada no corresponde a ninguna aceptación';
  end if;

  -- Repetir exactamente el último comando no crea filas: el ledger es
  -- append-only pero sin duplicados (T-018).
  if last_version is not null
     and last_granted = new.granted
     and last_version = new.version then
    return null;
  end if;

  return new;
end $$;

create trigger guard_consent_write
before insert on consents
for each row execute function private.guard_consent_write();

-- ---------------------------------------------------------------------------
-- Preferencias de notificaciones (T-019): los avisos de cuenta y seguridad
-- (categoría 'system') no se pueden desactivar en los canales de registro
-- (in-app y correo); el push de 'system' sí es opcional como el resto.
-- ---------------------------------------------------------------------------

create or replace function private.guard_notification_prefs() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user in ('authenticated', 'anon') and not public.is_admin() then
    if new.category = 'system'::public.notification_type
       and (not new.in_app_enabled or not new.email_enabled) then
      raise insufficient_privilege
        using message = 'Los avisos de cuenta y seguridad no se pueden desactivar';
    end if;
  end if;
  return new;
end $$;

create trigger guard_notification_prefs
before insert or update on notification_prefs
for each row execute function private.guard_notification_prefs();
