// Detección de formato de imagen por magic bytes (T-022).
//
// NUNCA confiamos en el `content_type` que declara el cliente: un atacante
// puede mandar un SVG con scripts o un polyglot HTML declarado como JPEG.
// Acá se mira el contenido real y punto. Módulo puro, sin dependencias:
// testeable con `deno test` sin red ni stack.

export type ImageFormat = "jpeg" | "png" | "webp";

const PNG_SIGNATURE = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];

/**
 * Devuelve el formato real de la imagen según sus primeros bytes, o `null`
 * si no coincide con ninguno de los formatos permitidos (fail-closed).
 */
export function detectImageFormat(bytes: Uint8Array): ImageFormat | null {
  // JPEG: ff d8 ff (SOI + primer marker).
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return "jpeg";
  }

  // PNG: firma completa de 8 bytes.
  if (bytes.length >= PNG_SIGNATURE.length && PNG_SIGNATURE.every((b, i) => bytes[i] === b)) {
    return "png";
  }

  // WebP: contenedor RIFF con fourcc WEBP ("RIFF" + tamaño + "WEBP").
  if (
    bytes.length >= 12 &&
    bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x46 && // "RIFF"
    bytes[8] === 0x57 && bytes[9] === 0x45 && bytes[10] === 0x42 && bytes[11] === 0x50 // "WEBP"
  ) {
    return "webp";
  }

  return null;
}
