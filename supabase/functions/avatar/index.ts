// Edge Function `avatar` (Bloque D, T-022): alta/reemplazo/borrado del avatar.
//
// El bucket `avatars` es privado y SIN policies de escritura (migración 0024):
// toda escritura pasa por acá con el service role del runtime (env
// SUPABASE_SERVICE_ROLE_KEY, inyectada por `supabase start`; jamás literal).
// El original crudo del cliente nunca toca el bucket: se valida por magic
// bytes, se decodifica y se RE-ENCODEA server-side, lo que descarta metadata
// y EXIF por construcción (la orientación se aplica antes de tirarla).
//
// Layout estable (namespace por candidate_profile_id, NO por auth.uid()):
//   avatars/<cid>/avatar.jpg  (máx 512 px de lado mayor, JPEG q85)
//   avatars/<cid>/thumb.jpg   (128×128 cuadrado, recorte centrado)
// Reemplazar sobreescribe los mismos objetos: sin huérfanos.

// Dependencias vendorizadas (deps/README.md): el runtime no descarga módulos,
// tipos ni WASM al arrancar ni al procesar imágenes. Las versiones son las
// mismas que antes se resolvían en remoto; los imports internos de los
// bundles de esm.sh los resuelve el import map de ./deno.json. Los tipos del
// cliente son la declaración mínima de deps/types (ver ese archivo).
// @ts-types="./deps/types/supabase-js.d.ts"
import { createClient } from "./deps/esm.sh/@supabase/supabase-js@2.49.4/es2022/supabase-js.mjs";
import { decode, Image } from "./deps/deno.land/x/imagescript@1.3.0/mod.ts";
import { detectImageFormat } from "./lib/magic_bytes.ts";
import { readJpegOrientation } from "./lib/exif.ts";

const MAX_BYTES = 2097152; // 2 MiB, espejo del file_size_limit del bucket
const AVATAR_MAX_SIDE = 512;
const THUMB_SIDE = 128;
const JPEG_QUALITY = 85;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, DELETE, OPTIONS",
};

/** Respuesta JSON con los headers CORS siempre incluidos. */
function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

/** Decodifica base64 estricto o devuelve null (fail-closed, sin lanzar). */
function decodeBase64Strict(input: string): Uint8Array | null {
  // atob es permisivo con algunos inputs rotos; validamos la forma primero.
  if (input.length === 0 || input.length % 4 !== 0) return null;
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(input)) return null;
  try {
    const binary = atob(input);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    return bytes;
  } catch {
    return null;
  }
}

/**
 * Corrige la orientación EXIF (1..8) antes de re-encodear. Mapeo estándar
 * (transformación que endereza la imagen, expresada en grados HORARIOS):
 *   1 → nada
 *   2 → flip horizontal
 *   3 → rotar 180°
 *   4 → flip vertical
 *   5 → flip horizontal + rotar 270° horario (transposición diagonal)
 *   6 → rotar 90° horario
 *   7 → flip horizontal + rotar 90° horario (transposición antidiagonal)
 *   8 → rotar 270° horario
 * OJO: `Image.rotate(n)` de ImageScript rota en sentido ANTIHORARIO
 * (verificado empíricamente con píxeles marcados), así que acá cada rotación
 * horaria de N° se implementa como `rotate(360 - N)`.
 */
function applyExifOrientation(image: Image, orientation: number): Image {
  // Los tipos de ImageScript declaran `Image | Frame` en rotate/flip, pero
  // partiendo de un Image plano siempre vuelve un Image: el cast es honesto.
  switch (orientation) {
    case 2:
      return image.flip("horizontal") as Image;
    case 3:
      return image.rotate(180) as Image;
    case 4:
      return image.flip("vertical") as Image;
    case 5:
      return (image.flip("horizontal") as Image).rotate(90) as Image; // 270° horario
    case 6:
      return image.rotate(270) as Image; // 90° horario
    case 7:
      return (image.flip("horizontal") as Image).rotate(270) as Image; // 90° horario
    case 8:
      return image.rotate(90) as Image; // 270° horario
    default:
      return image; // 1 (o cualquier valor raro): sin transformación
  }
}

Deno.serve(async (req: Request): Promise<Response> => {
  // Preflight CORS.
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  if (req.method !== "POST" && req.method !== "DELETE") {
    return json(405, { code: "method_not_allowed" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    console.error("avatar: faltan variables de entorno del runtime");
    return json(500, { code: "internal" });
  }

  // --- Autenticación: Bearer JWT obligatorio ---
  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.startsWith("Bearer ") ? authHeader.slice("Bearer ".length).trim() : "";
  if (!jwt) return json(401, { code: "unauthorized" });

  const anonClient = createClient(supabaseUrl, anonKey);
  const { data: userData, error: userError } = await anonClient.auth.getUser(jwt);
  if (userError || !userData?.user) return json(401, { code: "unauthorized" });
  const user = userData.user;

  // El rol de negocio vive SOLO en app_metadata (el cliente no puede tocarla).
  if (user.app_metadata?.role !== "candidate") {
    return json(403, { code: "not_allowed" });
  }

  // --- Perfil de candidato del caller (cliente service role) ---
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const { data: candidate, error: candidateError } = await admin
    .from("candidate_profiles")
    .select("id")
    .eq("profile_id", user.id)
    .is("deleted_at", null)
    .maybeSingle();
  if (candidateError) {
    console.error("avatar: error buscando candidate_profile", candidateError.message);
    return json(500, { code: "internal" });
  }
  // Sin perfil de candidato: mismo 403 opaco, no filtramos detalles.
  if (!candidate) return json(403, { code: "not_allowed" });

  const cid: string = candidate.id;
  const avatarPath = `${cid}/avatar.jpg`;
  const thumbPath = `${cid}/thumb.jpg`;

  // --- DELETE: borra ambos objetos y limpia avatar_url (idempotente) ---
  if (req.method === "DELETE") {
    // `remove` de objetos inexistentes no es error: borrar sin avatar → 200.
    const { error: removeError } = await admin.storage
      .from("avatars")
      .remove([avatarPath, thumbPath]);
    if (removeError) {
      console.error("avatar: error borrando objetos", removeError.message);
      return json(500, { code: "internal" });
    }
    const { error: clearError } = await admin
      .from("profiles")
      .update({ avatar_url: null })
      .eq("id", user.id);
    if (clearError) {
      console.error("avatar: error limpiando avatar_url", clearError.message);
      return json(500, { code: "internal" });
    }
    return json(200, {});
  }

  // --- POST: validaciones fail-closed, en orden ---
  // 1) JSON bien formado con `data` string. El `content_type` declarado se
  //    acepta en el body por contrato pero NO se usa para decidir nada: el
  //    formato real sale de los magic bytes.
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return json(400, { code: "invalid_request" });
  }
  const data = (body as { data?: unknown })?.data;
  if (typeof data !== "string") return json(400, { code: "invalid_request" });

  // 2) Base64 estricto.
  const bytes = decodeBase64Strict(data);
  if (bytes === null) return json(400, { code: "invalid_request" });

  // 3) Tamaño (espejo del límite del bucket, medido sobre bytes reales).
  if (bytes.length > MAX_BYTES) return json(413, { code: "too_large" });

  // 4) Magic bytes: SVG, HTML, polyglots y demás yerba mala quedan afuera.
  const format = detectImageFormat(bytes);
  if (format === null) return json(415, { code: "invalid_image" });

  // Limitación honesta y documentada: ImageScript 1.3.0 NO decodifica WebP,
  // y sin decodificar no podemos re-encodear (que es lo que garantiza que la
  // metadata muere acá). Antes que subir bytes crudos sin sanitizar,
  // rechazamos: el whitelist efectivo hoy es JPEG/PNG. Cuando el pipeline
  // tenga un decoder WebP real, este branch se reemplaza por soporte pleno.
  if (format === "webp") return json(415, { code: "unsupported_format" });

  // --- Decodificar (archivo corrupto → invalid_image) ---
  let image: Image;
  try {
    const decoded = await decode(bytes);
    if (!(decoded instanceof Image)) throw new Error("formato animado o no soportado");
    image = decoded;
  } catch {
    return json(415, { code: "invalid_image" });
  }

  try {
    // Orientación EXIF: aplicarla ANTES de re-encodear (después se pierde el
    // tag, que es justamente la idea). Solo aplica a JPEG.
    if (format === "jpeg") {
      image = applyExifOrientation(image, readJpegOrientation(bytes));
    }

    // Avatar: máx 512 px de lado mayor. Solo achicar, nunca agrandar, y con
    // el aspecto intacto (RESIZE_AUTO calcula el otro lado).
    let avatarImage = image;
    if (Math.max(image.width, image.height) > AVATAR_MAX_SIDE) {
      avatarImage = image.width >= image.height
        ? image.clone().resize(AVATAR_MAX_SIDE, Image.RESIZE_AUTO)
        : image.clone().resize(Image.RESIZE_AUTO, AVATAR_MAX_SIDE);
    }

    // Thumbnail 128×128: `cover` escala hasta cubrir y recorta centrado.
    const thumbImage = image.clone().cover(THUMB_SIDE, THUMB_SIDE);

    // Re-encodear como JPEG q85: el original crudo (y su metadata) muere acá.
    const avatarBytes = await avatarImage.encodeJPEG(JPEG_QUALITY);
    const thumbBytes = await thumbImage.encodeJPEG(JPEG_QUALITY);

    // --- Subida con service role (upsert: nombres estables, sin huérfanos) ---
    const { error: avatarUploadError } = await admin.storage
      .from("avatars")
      .upload(avatarPath, avatarBytes, { contentType: "image/jpeg", upsert: true });
    if (avatarUploadError) throw new Error(`upload avatar: ${avatarUploadError.message}`);

    const { error: thumbUploadError } = await admin.storage
      .from("avatars")
      .upload(thumbPath, thumbBytes, { contentType: "image/jpeg", upsert: true });
    if (thumbUploadError) throw new Error(`upload thumb: ${thumbUploadError.message}`);

    // avatar_url guarda SOLO el path canónico (columna protegida: la escribe
    // únicamente esta función; el trigger de 0023 bloquea a los clientes).
    const { error: profileError } = await admin
      .from("profiles")
      .update({ avatar_url: avatarPath })
      .eq("id", user.id);
    if (profileError) throw new Error(`update profiles: ${profileError.message}`);

    return json(200, { avatar_path: avatarPath, thumb_path: thumbPath });
  } catch (err) {
    // Nada de detalles internos al cliente; el log local sí puede decir más.
    console.error("avatar: fallo interno procesando la subida", err);
    return json(500, { code: "internal" });
  }
});
