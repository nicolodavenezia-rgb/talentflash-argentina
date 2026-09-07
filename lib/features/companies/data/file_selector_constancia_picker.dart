import 'package:file_selector/file_selector.dart';

import '../domain/company_verification.dart';

/// Selector real de la constancia de ARCA, sobre `file_selector` (Web,
/// Windows, Android e iOS). Vive detrás de [ConstanciaPicker] para que las
/// pantallas y sus tests nunca dependan del plugin de plataforma.
///
/// Los tipos que ofrece el diálogo son exactamente los que acepta el bucket
/// `company-docs` (migración 0029). Filtrar acá es comodidad: el servidor
/// rechaza igual cualquier otra cosa.
class FileSelectorConstanciaPicker implements ConstanciaPicker {
  const FileSelectorConstanciaPicker();

  static const _documentsGroup = XTypeGroup(
    label: 'Constancia (PDF o imagen)',
    extensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    mimeTypes: ['application/pdf', 'image/jpeg', 'image/png', 'image/webp'],
    // En Web el filtro se hace por MIME; uniformTypeIdentifiers cubre iOS.
    uniformTypeIdentifiers: [
      'com.adobe.pdf',
      'public.jpeg',
      'public.png',
      'org.webmproject.webp',
    ],
  );

  @override
  Future<PickedConstancia?> pickDocument() async {
    final file = await openFile(acceptedTypeGroups: const [_documentsGroup]);
    if (file == null) {
      return null;
    }
    final bytes = await file.readAsBytes();
    return PickedConstancia(bytes: bytes, fileName: file.name);
  }
}
