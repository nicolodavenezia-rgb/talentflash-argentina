import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/profiles/domain/avatar.dart';

Uint8List jpegBytes([int extra = 8]) {
  return Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, ...List.filled(extra, 0)]);
}

Uint8List pngBytes([int extra = 8]) {
  return Uint8List.fromList([
    0x89,
    0x50,
    0x4e,
    0x47,
    0x0d,
    0x0a,
    0x1a,
    0x0a,
    ...List.filled(extra, 0),
  ]);
}

Uint8List webpBytes() {
  // RIFF....WEBP: los bytes 4..7 (tamaño) son irrelevantes para la firma.
  return Uint8List.fromList([
    0x52,
    0x49,
    0x46,
    0x46,
    0x00,
    0x00,
    0x00,
    0x00,
    0x57,
    0x45,
    0x42,
    0x50,
  ]);
}

void main() {
  group('AvatarValidation.detectFormat', () {
    test('los magic bytes de JPEG se reconocen', () {
      expect(
        AvatarValidation.detectFormat(jpegBytes()),
        AvatarImageFormat.jpeg,
      );
    });

    test('los magic bytes de PNG se reconocen', () {
      expect(AvatarValidation.detectFormat(pngBytes()), AvatarImageFormat.png);
    });

    test('los magic bytes de WebP (RIFF....WEBP) se reconocen', () {
      expect(
        AvatarValidation.detectFormat(webpBytes()),
        AvatarImageFormat.webp,
      );
    });

    test('HTML disfrazado y bytes vacíos no son ninguna imagen', () {
      final html = Uint8List.fromList(
        utf8.encode('<html><body>no soy una imagen</body></html>'),
      );
      expect(AvatarValidation.detectFormat(html), isNull);
      expect(AvatarValidation.detectFormat(Uint8List(0)), isNull);
    });
  });

  group('AvatarValidation.validate', () {
    test('más de 2 MiB se rechaza antes de mirar el formato', () {
      final grande = Uint8List(AvatarValidation.maxBytes + 1);
      grande.setRange(0, 4, jpegBytes());
      expect(AvatarValidation.validate(grande), AvatarIssue.tooLarge);
    });

    test('WebP se rechaza como formato no soportado (límite honesto)', () {
      expect(
        AvatarValidation.validate(webpBytes()),
        AvatarIssue.unsupportedFormat,
      );
    });

    test('un PNG chico pasa; bytes irreconocibles son formato inválido', () {
      expect(AvatarValidation.validate(pngBytes()), isNull);
      expect(
        AvatarValidation.validate(Uint8List.fromList([1, 2, 3, 4])),
        AvatarIssue.invalidFormat,
      );
    });
  });

  group('AvatarFailure.fromFunctionCode', () {
    test('cada código de la Edge Function mapea a su fallo tipado', () {
      expect(
        AvatarFailure.fromFunctionCode('too_large').code,
        AvatarFailureCode.tooLarge,
      );
      expect(
        AvatarFailure.fromFunctionCode('invalid_image').code,
        AvatarFailureCode.invalidImage,
      );
      expect(
        AvatarFailure.fromFunctionCode('unsupported_format').code,
        AvatarFailureCode.unsupportedFormat,
      );
      expect(
        AvatarFailure.fromFunctionCode('unauthorized').code,
        AvatarFailureCode.notAllowed,
      );
      expect(
        AvatarFailure.fromFunctionCode('not_allowed').code,
        AvatarFailureCode.notAllowed,
      );
    });

    test('un código desconocido cae en unknown con detalle para logs', () {
      final failure = AvatarFailure.fromFunctionCode(
        'codigo_marciano',
        status: 500,
      );
      expect(failure.code, AvatarFailureCode.unknown);
      expect(failure.debugDetail, contains('codigo_marciano'));
      expect(failure.debugDetail, contains('500'));
    });
  });
}
