import 'dart:async';

import 'package:talentflash_argentina/features/companies/data/company_access_repository.dart';
import 'package:talentflash_argentina/features/companies/data/company_verification_repository.dart';
import 'package:talentflash_argentina/features/companies/domain/company_verification.dart';

/// Doble del circuito de verificación (T-028). Escrito a mano, como el resto
/// de los fakes del proyecto: no hay mocktail ni mockito en el pubspec.
///
/// Registra cada llamada en [calls] para poder afirmar QUÉ se pidió, no solo
/// qué se dibujó, y `nextFailure` deja simular un rechazo del servidor una
/// sola vez (el siguiente intento vuelve a andar, como en la realidad).
class FakeCompanyVerificationRepository
    implements CompanyVerificationRepository {
  FakeCompanyVerificationRepository({
    CompanyVerification? verification,
    List<CompanyVerificationRequest>? queue,
  }) : verification =
           verification ??
           const CompanyVerification(
             companyId: 'c0000000-0000-4000-8000-000000000001',
             companyStatus: CompanyVerificationStatus.pending,
           ),
       queue = queue ?? <CompanyVerificationRequest>[];

  CompanyVerification verification;
  List<CompanyVerificationRequest> queue;

  /// Retiene la próxima lectura de la cola hasta que el test la complete,
  /// para simular una respuesta tardía.
  Completer<void>? pendingQueueFetch;

  /// Fallo a devolver la próxima vez que se llame a ESE método. Un
  /// `nextFailure` global se lo comía la primera lectura de la pantalla y
  /// terminaba probando el caso equivocado.
  Object? nextFetchFailure;
  Object? nextUploadFailure;
  Object? nextRequestFailure;
  Object? nextQueueFailure;
  Object? nextReviewFailure;

  final List<String> calls = <String>[];

  /// Último envío recibido, para afirmar qué viajó al servidor.
  String? lastCuit;
  ConstanciaFormat? lastFormat;
  String? lastReviewedRequestId;
  bool? lastApprove;
  VerificationRejectionReason? lastReason;

  void _maybeThrow(Object? failure, void Function() clear) {
    if (failure != null) {
      clear();
      // ignore: only_throw_errors -- los fakes relanzan los failures tipados.
      throw failure;
    }
  }

  @override
  Future<CompanyVerification> fetchMyVerification() async {
    calls.add('fetchMyVerification');
    _maybeThrow(nextFetchFailure, () => nextFetchFailure = null);
    return verification;
  }

  @override
  Future<String> uploadConstancia(PickedConstancia document) async {
    calls.add('uploadConstancia:${document.fileName}');
    _maybeThrow(nextUploadFailure, () => nextUploadFailure = null);
    return '${verification.companyId}/constancia-arca.'
        '${document.format?.wireName ?? 'pdf'}';
  }

  @override
  Future<String> requestVerification({
    required String cuit,
    ConstanciaFormat? format,
  }) async {
    calls.add('requestVerification');
    lastCuit = cuit;
    lastFormat = format;
    _maybeThrow(nextRequestFailure, () => nextRequestFailure = null);
    return 'req-0001';
  }

  @override
  Future<String> createConstanciaSignedUrl(String path) async {
    calls.add('createConstanciaSignedUrl:$path');
    _maybeThrow(nextFetchFailure, () => nextFetchFailure = null);
    return 'https://storage.local/firmada/$path';
  }

  @override
  Future<List<CompanyVerificationRequest>> fetchVerificationQueue(
    CompanyVerificationStatus status,
  ) async {
    calls.add('fetchVerificationQueue:${status.wireName}');
    // La respuesta se fija al momento de la llamada, como haría el servidor:
    // así una lectura retenida devuelve los datos de ENTONCES aunque el test
    // cambie la cola mientras tanto.
    final snapshot = queue
        .where((request) => request.requestStatus == status)
        .toList(growable: false);
    final pending = pendingQueueFetch;
    if (pending != null) {
      await pending.future;
    }
    _maybeThrow(nextQueueFailure, () => nextQueueFailure = null);
    return snapshot;
  }

  @override
  Future<void> reviewVerification({
    required String requestId,
    required bool approve,
    VerificationRejectionReason? reason,
  }) async {
    calls.add('reviewVerification');
    lastReviewedRequestId = requestId;
    lastApprove = approve;
    lastReason = reason;
    _maybeThrow(nextReviewFailure, () => nextReviewFailure = null);
  }
}

/// Selector de constancia falso: nunca abre UI nativa.
class FakeConstanciaPicker implements ConstanciaPicker {
  PickedConstancia? next;
  int pickCount = 0;

  @override
  Future<PickedConstancia?> pickDocument() async {
    pickCount++;
    return next;
  }
}
