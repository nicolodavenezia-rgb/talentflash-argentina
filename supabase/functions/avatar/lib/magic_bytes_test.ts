// Tests puros de detección por magic bytes (T-022). Sin red, sin stack,
// sin dependencias remotas: asserts a mano para que `deno test` corra
// offline en cualquier máquina.

import { detectImageFormat } from "./magic_bytes.ts";

function assertEquals(actual: unknown, expected: unknown, msg: string): void {
  if (actual !== expected) {
    throw new Error(`${msg}: se esperaba ${String(expected)}, llegó ${String(actual)}`);
  }
}

function bytesOf(text: string): Uint8Array {
  return new TextEncoder().encode(text);
}

Deno.test("JPEG: ff d8 ff se detecta como jpeg", () => {
  const jpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46]);
  assertEquals(detectImageFormat(jpeg), "jpeg", "JPEG con APP0");
});

Deno.test("PNG: firma completa de 8 bytes se detecta como png", () => {
  const png = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00]);
  assertEquals(detectImageFormat(png), "png", "firma PNG");
});

Deno.test("PNG: firma incompleta (7 bytes) no alcanza", () => {
  const corto = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a]);
  assertEquals(detectImageFormat(corto), null, "PNG truncado");
});

Deno.test("WebP: RIFF....WEBP se detecta como webp", () => {
  const webp = new Uint8Array([
    0x52, 0x49, 0x46, 0x46, // "RIFF"
    0x24, 0x00, 0x00, 0x00, // tamaño (irrelevante para la firma)
    0x57, 0x45, 0x42, 0x50, // "WEBP"
    0x56, 0x50, 0x38, 0x20, // "VP8 "
  ]);
  assertEquals(detectImageFormat(webp), "webp", "contenedor WebP");
});

Deno.test("RIFF que no es WebP (WAVE) devuelve null", () => {
  const wav = new Uint8Array([
    0x52, 0x49, 0x46, 0x46, 0x24, 0x00, 0x00, 0x00,
    0x57, 0x41, 0x56, 0x45, // "WAVE"
  ]);
  assertEquals(detectImageFormat(wav), null, "RIFF/WAVE");
});

Deno.test("HTML devuelve null (nada de polyglots)", () => {
  assertEquals(detectImageFormat(bytesOf("<html><body>hola</body></html>")), null, "HTML");
});

Deno.test("SVG devuelve null aunque se declare imagen", () => {
  assertEquals(
    detectImageFormat(bytesOf('<svg xmlns="http://www.w3.org/2000/svg"></svg>')),
    null,
    "SVG",
  );
});

Deno.test("buffer vacío devuelve null", () => {
  assertEquals(detectImageFormat(new Uint8Array(0)), null, "vacío");
});

Deno.test("buffer demasiado corto devuelve null", () => {
  assertEquals(detectImageFormat(new Uint8Array([0xff, 0xd8])), null, "2 bytes");
});
