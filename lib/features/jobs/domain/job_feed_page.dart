import 'job_offer.dart';

/// Tamaño de página del feed de candidatos: también es el máximo que acepta
/// el repositorio (`SECURITY.md` §6, a lo sumo 20 resultados por página).
const jobFeedPageSize = 20;

/// Posición desde la que sigue el feed: la última oferta entregada en el
/// orden `published_at desc, id desc` (paginación keyset, nunca offsets).
///
/// Para la UI es opaco: lo arma y lo consume el repositorio. [publishedAt] es
/// el valor CRUDO que devolvió el servidor y no un `DateTime`, porque
/// Postgres guarda microsegundos y en Web `DateTime` solo tiene milisegundos:
/// reconstruirlo podría saltear o repetir ofertas publicadas en el mismo
/// milisegundo.
class JobFeedCursor {
  const JobFeedCursor({required this.publishedAt, required this.id});

  final String publishedAt;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is JobFeedCursor &&
      other.publishedAt == publishedAt &&
      other.id == id;

  @override
  int get hashCode => Object.hash(JobFeedCursor, publishedAt, id);
}

/// Una página del feed.
class JobFeedPage {
  const JobFeedPage({required this.items, required this.nextCursor});

  final List<JobOffer> items;

  /// Desde dónde pedir la siguiente, o null si esta fue la última. Una página
  /// completa no garantiza que haya más: si la siguiente vuelve vacía, ahí
  /// termina la lista.
  final JobFeedCursor? nextCursor;

  bool get isLast => nextCursor == null;
}
