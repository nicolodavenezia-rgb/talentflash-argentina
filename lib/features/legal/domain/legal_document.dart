/// Documentos legales publicados (T-020).
enum LegalSlug {
  terms('terminos'),
  privacy('privacidad');

  const LegalSlug(this.wireName);

  final String wireName;
}

/// Versión vigente de un documento legal, tal como vive en `legal_documents`.
/// La misma versión que muestra la pantalla es la que se registra en
/// `consents`: una única fuente de verdad para UI y base.
class LegalDocument {
  const LegalDocument({
    required this.slug,
    required this.version,
    required this.title,
    required this.body,
  });

  final String slug;
  final String version;
  final String title;

  /// Texto plano con párrafos separados por líneas en blanco.
  final String body;

  List<String> get paragraphs => [
    for (final part in body.split(RegExp(r'\n\s*\n')))
      if (part.trim().isNotEmpty) part.trim(),
  ];

  @override
  bool operator ==(Object other) =>
      other is LegalDocument &&
      other.slug == slug &&
      other.version == version &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(slug, version, title, body);
}
