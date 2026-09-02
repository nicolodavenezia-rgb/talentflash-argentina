import 'dart:typed_data';

/// Imagen elegida por la persona para su avatar (T-022).
class PickedAvatarImage {
  const PickedAvatarImage({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

/// Selector de imagen inyectable: la implementación real usa el plugin de
/// plataforma; los tests inyectan un doble sin abrir UI nativa.
abstract interface class AvatarImagePicker {
  Future<PickedAvatarImage?> pickImage();
}

enum AvatarImageFormat { jpeg, png, webp }

enum AvatarIssue { tooLarge, invalidFormat, unsupportedFormat }

/// Fallos tipados del pipeline de avatar (Edge Function `avatar`).
enum AvatarFailureCode {
  tooLarge,
  invalidImage,
  unsupportedFormat,
  notAllowed,
  network,
  unknown,
}

class AvatarFailure implements Exception {
  const AvatarFailure(this.code, {this.debugDetail = ''});

  final AvatarFailureCode code;

  /// Diagnóstico para logs; jamás se muestra en la UI.
  final String debugDetail;

  static AvatarFailure fromFunctionCode(Object? code, {int? status}) {
    return switch (code) {
      'too_large' => const AvatarFailure(AvatarFailureCode.tooLarge),
      'invalid_image' ||
      'invalid_request' => const AvatarFailure(AvatarFailureCode.invalidImage),
      'unsupported_format' => const AvatarFailure(
        AvatarFailureCode.unsupportedFormat,
      ),
      'unauthorized' ||
      'not_allowed' => const AvatarFailure(AvatarFailureCode.notAllowed),
      _ => AvatarFailure(
        AvatarFailureCode.unknown,
        debugDetail: 'function:$code status:$status',
      ),
    };
  }

  @override
  String toString() => 'AvatarFailure(${code.name})';
}

/// Validación local previa al envío. El servidor es la autoridad (magic
/// bytes + re-encoding en la Edge Function); esto solo evita subir de más.
abstract final class AvatarValidation {
  /// Mismo límite que el bucket (2 MiB) y que la Edge Function.
  static const maxBytes = 2 * 1024 * 1024;

  static AvatarImageFormat? detectFormat(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return AvatarImageFormat.jpeg;
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a) {
      return AvatarImageFormat.png;
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && // R
        bytes[1] == 0x49 && // I
        bytes[2] == 0x46 && // F
        bytes[3] == 0x46 && // F
        bytes[8] == 0x57 && // W
        bytes[9] == 0x45 && // E
        bytes[10] == 0x42 && // B
        bytes[11] == 0x50) {
      return AvatarImageFormat.webp;
    }
    return null;
  }

  static AvatarIssue? validate(Uint8List bytes) {
    if (bytes.length > maxBytes) {
      return AvatarIssue.tooLarge;
    }
    final format = detectFormat(bytes);
    if (format == null) {
      return AvatarIssue.invalidFormat;
    }
    // Limitación local honesta: la Edge Function todavía no decodifica WebP
    // (la librería de re-encoding no lo soporta); mejor avisar acá que
    // fallar después de subir.
    if (format == AvatarImageFormat.webp) {
      return AvatarIssue.unsupportedFormat;
    }
    return null;
  }

  static String contentTypeFor(AvatarImageFormat format) => switch (format) {
    AvatarImageFormat.jpeg => 'image/jpeg',
    AvatarImageFormat.png => 'image/png',
    AvatarImageFormat.webp => 'image/webp',
  };
}
