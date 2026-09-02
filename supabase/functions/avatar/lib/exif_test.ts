// Tests puros del parser de orientación EXIF (T-022). Los JPEG se arman
// byte a byte para controlar exactamente endianness, offsets y truncados.
// Sin red ni dependencias remotas: asserts a mano.

import { readJpegOrientation } from "./exif.ts";

function assertEquals(actual: unknown, expected: unknown, msg: string): void {
  if (actual !== expected) {
    throw new Error(`${msg}: se esperaba ${String(expected)}, llegó ${String(actual)}`);
  }
}

/** Payload TIFF little-endian ("II") con solo el tag 0x0112 en IFD0. */
function tiffLittleEndian(orientation: number): number[] {
  return [
    0x49, 0x49, // "II"
    0x2a, 0x00, // magic 42 LE
    0x08, 0x00, 0x00, 0x00, // offset IFD0 = 8 (relativo al header TIFF)
    0x01, 0x00, // 1 entrada
    0x12, 0x01, // tag 0x0112 LE
    0x03, 0x00, // tipo 3 (SHORT) LE
    0x01, 0x00, 0x00, 0x00, // count 1 LE
    orientation, 0x00, 0x00, 0x00, // valor en los primeros 2 bytes
    0x00, 0x00, 0x00, 0x00, // sin IFD siguiente
  ];
}

/** Payload TIFF big-endian ("MM") con solo el tag 0x0112 en IFD0. */
function tiffBigEndian(orientation: number): number[] {
  return [
    0x4d, 0x4d, // "MM"
    0x00, 0x2a, // magic 42 BE
    0x00, 0x00, 0x00, 0x08, // offset IFD0 = 8
    0x00, 0x01, // 1 entrada
    0x01, 0x12, // tag 0x0112 BE
    0x00, 0x03, // tipo 3 (SHORT) BE
    0x00, 0x00, 0x00, 0x01, // count 1 BE
    0x00, orientation, 0x00, 0x00, // valor en los primeros 2 bytes
    0x00, 0x00, 0x00, 0x00, // sin IFD siguiente
  ];
}

/** Arma un JPEG sintético: SOI + APP1(Exif + payload TIFF) + EOI. */
function jpegWithExif(tiffPayload: number[]): Uint8Array {
  const app1Payload = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00, ...tiffPayload]; // "Exif\0\0"
  const segLength = app1Payload.length + 2; // la longitud se incluye a sí misma
  return new Uint8Array([
    0xff, 0xd8, // SOI
    0xff, 0xe1, (segLength >> 8) & 0xff, segLength & 0xff, // APP1 + longitud BE
    ...app1Payload,
    0xff, 0xd9, // EOI
  ]);
}

Deno.test("orientación 6 en little endian (II)", () => {
  assertEquals(readJpegOrientation(jpegWithExif(tiffLittleEndian(6))), 6, "LE o=6");
});

Deno.test("orientación 3 en big endian (MM)", () => {
  assertEquals(readJpegOrientation(jpegWithExif(tiffBigEndian(3))), 3, "BE o=3");
});

Deno.test("APP0 (JFIF) antes del APP1 no molesta al recorrido", () => {
  const conExif = jpegWithExif(tiffLittleEndian(8));
  // Insertamos un APP0 JFIF mínimo entre SOI y APP1.
  const app0 = [
    0xff, 0xe0, 0x00, 0x10, // APP0, longitud 16
    0x4a, 0x46, 0x49, 0x46, 0x00, // "JFIF\0"
    0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
  ];
  const jpeg = new Uint8Array([0xff, 0xd8, ...app0, ...conExif.slice(2)]);
  assertEquals(readJpegOrientation(jpeg), 8, "APP0 + APP1 o=8");
});

Deno.test("JPEG sin EXIF devuelve 1", () => {
  const sinExif = new Uint8Array([
    0xff, 0xd8, // SOI
    0xff, 0xe0, 0x00, 0x10, // APP0 JFIF
    0x4a, 0x46, 0x49, 0x46, 0x00,
    0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
    0xff, 0xd9, // EOI
  ]);
  assertEquals(readJpegOrientation(sinExif), 1, "JPEG JFIF sin APP1");
});

Deno.test("no-JPEG (firma PNG) devuelve 1 sin lanzar", () => {
  const png = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  assertEquals(readJpegOrientation(png), 1, "PNG");
});

Deno.test("buffer vacío devuelve 1 sin lanzar", () => {
  assertEquals(readJpegOrientation(new Uint8Array(0)), 1, "vacío");
});

Deno.test("bytes truncados a mitad del APP1 devuelven 1 sin lanzar", () => {
  const completo = jpegWithExif(tiffLittleEndian(6));
  // Cortamos adentro del payload EXIF: la longitud declarada ya no entra.
  const truncado = completo.slice(0, 12);
  assertEquals(readJpegOrientation(truncado), 1, "APP1 truncado");
});

Deno.test("TIFF truncado a mitad de IFD0 devuelve 1 sin lanzar", () => {
  // APP1 con longitud consistente pero payload TIFF cortado: el offset de
  // IFD0 apunta más allá del segmento.
  const tiffCorto = [
    0x49, 0x49, 0x2a, 0x00,
    0xff, 0x00, 0x00, 0x00, // offset IFD0 absurdo (255): fuera del payload
  ];
  assertEquals(readJpegOrientation(jpegWithExif(tiffCorto)), 1, "IFD0 fuera de rango");
});

Deno.test("orientación fuera de rango (9) devuelve 1", () => {
  assertEquals(readJpegOrientation(jpegWithExif(tiffLittleEndian(9))), 1, "o=9 inválida");
});

Deno.test("segmento con longitud mentirosa devuelve 1 sin lanzar", () => {
  const mentiroso = new Uint8Array([
    0xff, 0xd8, // SOI
    0xff, 0xe1, 0xff, 0xff, // APP1 que declara 65535 bytes que no están
    0x45, 0x78,
  ]);
  assertEquals(readJpegOrientation(mentiroso), 1, "longitud > buffer");
});
