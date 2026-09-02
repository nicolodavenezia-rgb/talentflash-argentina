import 'package:file_selector/file_selector.dart';

import '../domain/avatar.dart';

/// Selector real de imagen de avatar, sobre `file_selector` (Web, Windows,
/// Android e iOS). Vive detrás de [AvatarImagePicker] para que los widgets y
/// sus tests nunca dependan del plugin de plataforma.
class FileSelectorAvatarPicker implements AvatarImagePicker {
  const FileSelectorAvatarPicker();

  static const _imagesGroup = XTypeGroup(
    label: 'Imágenes',
    extensions: ['jpg', 'jpeg', 'png', 'webp'],
    mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
    // En Web el filtro se hace por MIME; uniformTypeIdentifiers cubre iOS.
    uniformTypeIdentifiers: [
      'public.jpeg',
      'public.png',
      'org.webmproject.webp',
    ],
  );

  @override
  Future<PickedAvatarImage?> pickImage() async {
    final file = await openFile(acceptedTypeGroups: const [_imagesGroup]);
    if (file == null) {
      return null;
    }
    final bytes = await file.readAsBytes();
    return PickedAvatarImage(bytes: bytes, fileName: file.name);
  }
}
