// Parser mínimo de orientación EXIF para JPEG (T-022).
//
// ImageScript ignora el tag de orientación al decodificar, así que sin esto
// las fotos sacadas con el teléfono rotado quedarían acostadas. Este módulo
// recorre los segmentos JPEG hasta el APP1 "Exif\0\0", lee el header TIFF
// (endianness + offset de IFD0) y devuelve el valor del tag 0x0112.
//
// Contrato: puro, sin dependencias, y NUNCA lanza — ante cualquier cosa rara
// (no es JPEG, EXIF truncado, offsets fuera de rango) devuelve 1 (sin
// transformación), que es el default seguro.

const ORIENTATION_TAG = 0x0112;

/**
 * Devuelve la orientación EXIF (1..8) de un JPEG, o 1 si no hay EXIF,
 * el valor está fuera de rango o los bytes no son un JPEG válido.
 */
export function readJpegOrientation(bytes: Uint8Array): number {
  try {
    // SOI obligatorio: si no arranca con ff d8 no es JPEG.
    if (bytes.length < 4 || bytes[0] !== 0xff || bytes[1] !== 0xd8) return 1;

    let offset = 2;
    while (offset + 4 <= bytes.length) {
      if (bytes[offset] !== 0xff) return 1; // stream corrupto: no seguimos

      const marker = bytes[offset + 1];

      // Padding: puede haber ff de relleno entre segmentos.
      if (marker === 0xff) {
        offset += 1;
        continue;
      }

      // Markers sin payload: otro SOI, TEM o RSTn.
      if (marker === 0xd8 || marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7)) {
        offset += 2;
        continue;
      }

      // SOS (empieza el bitstream comprimido) o EOI: ya no va a aparecer APP1.
      if (marker === 0xda || marker === 0xd9) return 1;

      // Segmento con longitud (big-endian, incluye los 2 bytes de longitud).
      const segLength = (bytes[offset + 2] << 8) | bytes[offset + 3];
      if (segLength < 2 || offset + 2 + segLength > bytes.length) return 1;

      if (marker === 0xe1) {
        const payloadStart = offset + 4;
        const payloadEnd = offset + 2 + segLength;
        const orientation = parseExifPayload(bytes, payloadStart, payloadEnd);
        if (orientation !== null) return orientation;
        // APP1 que no es EXIF (p. ej. XMP): seguimos buscando.
      }

      offset += 2 + segLength;
    }
    return 1;
  } catch {
    // Cinturón y tiradores: el contrato es no lanzar jamás.
    return 1;
  }
}

/**
 * Parsea el payload de un APP1: header "Exif\0\0" + TIFF (II/MM) + IFD0.
 * Devuelve la orientación (1..8) o `null` si no se encuentra / no aplica.
 */
function parseExifPayload(bytes: Uint8Array, start: number, end: number): number | null {
  // Header "Exif\0\0" (6 bytes).
  if (end - start < 6 + 8) return null;
  if (
    bytes[start] !== 0x45 || bytes[start + 1] !== 0x78 || bytes[start + 2] !== 0x69 ||
    bytes[start + 3] !== 0x66 || bytes[start + 4] !== 0x00 || bytes[start + 5] !== 0x00
  ) {
    return null;
  }

  // Header TIFF: byte order + magic 0x002a + offset a IFD0 (relativo al TIFF).
  const tiff = start + 6;
  let little: boolean;
  if (bytes[tiff] === 0x49 && bytes[tiff + 1] === 0x49) little = true; // "II"
  else if (bytes[tiff] === 0x4d && bytes[tiff + 1] === 0x4d) little = false; // "MM"
  else return null;

  const u16 = (at: number): number | null => {
    if (at < 0 || at + 2 > end) return null;
    return little ? bytes[at] | (bytes[at + 1] << 8) : (bytes[at] << 8) | bytes[at + 1];
  };
  const u32 = (at: number): number | null => {
    if (at < 0 || at + 4 > end) return null;
    // >>> 0 para mantenerlo unsigned.
    return little
      ? (bytes[at] | (bytes[at + 1] << 8) | (bytes[at + 2] << 16) | (bytes[at + 3] << 24)) >>> 0
      : ((bytes[at] << 24) | (bytes[at + 1] << 16) | (bytes[at + 2] << 8) | bytes[at + 3]) >>> 0;
  };

  if (u16(tiff + 2) !== 0x002a) return null;
  const ifd0Offset = u32(tiff + 4);
  if (ifd0Offset === null) return null;

  // IFD0: cantidad de entradas + entradas de 12 bytes.
  const ifd0 = tiff + ifd0Offset;
  const entryCount = u16(ifd0);
  if (entryCount === null) return null;

  for (let i = 0; i < entryCount; i++) {
    const entry = ifd0 + 2 + i * 12;
    const tag = u16(entry);
    if (tag === null) return null; // entrada truncada
    if (tag !== ORIENTATION_TAG) continue;

    const type = u16(entry + 2);
    const count = u32(entry + 4);
    if (type !== 3 || count !== 1) return null; // SHORT, un solo valor

    // Un SHORT entra en el campo value/offset: son los primeros 2 bytes
    // (respetando el endianness declarado).
    const value = u16(entry + 8);
    if (value === null || value < 1 || value > 8) return null;
    return value;
  }

  return null; // IFD0 sin tag de orientación
}
