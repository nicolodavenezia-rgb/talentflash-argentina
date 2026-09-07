import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/companies/data/company_access_repository.dart';
import 'package:talentflash_argentina/features/companies/data/company_verification_repository.dart';
import 'package:talentflash_argentina/features/companies/domain/company_verification.dart';
import 'package:talentflash_argentina/features/companies/providers/company_verification_providers.dart';
import 'package:talentflash_argentina/shared/models/data_failure.dart';

import '../../../support/fake_company_verification_repository.dart';

void main() {
  late FakeCompanyVerificationRepository repository;
  late FakeConstanciaPicker picker;
  late ProviderContainer container;

  CompanyVerificationController controller() =>
      container.read(companyVerificationControllerProvider.notifier);

  VerificationReviewController review() =>
      container.read(verificationReviewControllerProvider.notifier);

  setUp(() {
    repository = FakeCompanyVerificationRepository();
    picker = FakeConstanciaPicker();
    container = ProviderContainer.test(
      // Igual que el harness: sin el retry automático de Riverpod 3, los
      // errores de providers son finales y el test es determinista.
      retry: (retryCount, error) => null,
      overrides: [
        companyVerificationRepositoryProvider.overrideWithValue(repository),
        constanciaPickerProvider.overrideWithValue(picker),
      ],
    );
  });

  group('envío de la solicitud', () {
    test('manda el CUIT y refresca el estado propio', () async {
      await controller().submit(cuit: '30-70000001-6');

      expect(repository.lastCuit, '30-70000001-6');
      expect(
        repository.calls.where((c) => c == 'fetchMyVerification').length,
        greaterThanOrEqualTo(1),
        reason: 'tras enviar hay que releer el estado, no adivinarlo',
      );
    });

    test('el doble tap no manda dos solicitudes', () async {
      final completer = Completer<void>();
      // El primer envío queda colgado a propósito para simular el segundo tap
      // mientras el primero sigue en vuelo.
      final lenta = _RepositorioLento(repository, completer.future);
      container = ProviderContainer.test(
        retry: (retryCount, error) => null,
        overrides: [
          companyVerificationRepositoryProvider.overrideWithValue(lenta),
          constanciaPickerProvider.overrideWithValue(picker),
        ],
      );

      final primera = controller().submit(cuit: '30-70000001-6');
      final segunda = controller().submit(cuit: '30-70000001-6');
      completer.complete();
      await Future.wait<void>([primera, segunda]);

      expect(
        repository.calls.where((c) => c == 'requestVerification').length,
        1,
        reason: 'el segundo tap se ignora en vez de duplicar la solicitud',
      );
    });

    test('un fallo del servidor queda como DataFailure tipado', () async {
      repository.nextRequestFailure = const DataFailure(
        DataFailureCode.notAllowed,
        debugDetail: 'postgrest:42501',
      );

      await controller().submit(cuit: '30-70000001-6');

      final state = container.read(companyVerificationControllerProvider);
      expect(state.hasError, isTrue);
      expect(
        state.error,
        isA<DataFailure>().having(
          (f) => f.code,
          'code',
          DataFailureCode.notAllowed,
        ),
      );
    });

    test('un error crudo se envuelve igual en DataFailure', () async {
      repository.nextRequestFailure = Exception('cualquier cosa');

      await controller().submit(cuit: '30-70000001-6');

      expect(
        container.read(companyVerificationControllerProvider).error,
        isA<DataFailure>(),
      );
    });

    test('reset limpia el resultado anterior', () async {
      repository.nextRequestFailure = const DataFailure(
        DataFailureCode.network,
      );
      await controller().submit(cuit: '30-70000001-6');
      expect(
        container.read(companyVerificationControllerProvider).hasError,
        isTrue,
      );

      controller().reset();

      final state = container.read(companyVerificationControllerProvider);
      expect(state.hasError, isFalse);
      expect(state.value, isNull);
    });
  });

  group('adjuntar la constancia', () {
    test('cancelar el selector devuelve null y no sube nada', () async {
      final format = await controller().attachConstancia();

      expect(format, isNull);
      expect(picker.pickCount, 1);
      expect(
        repository.calls.where((c) => c.startsWith('uploadConstancia')),
        isEmpty,
      );
    });

    test('un formato admitido se sube y se devuelve normalizado', () async {
      picker.next = PickedConstancia(
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        fileName: 'constancia.JPEG',
      );

      final format = await controller().attachConstancia();

      expect(format, ConstanciaFormat.jpg);
      expect(repository.calls, contains('uploadConstancia:constancia.JPEG'));
    });

    test('un formato no admitido no llega al repositorio', () async {
      picker.next = PickedConstancia(
        bytes: Uint8List.fromList(<int>[1]),
        fileName: 'raro.exe',
      );

      final format = await controller().attachConstancia();

      expect(format, isNull);
      expect(
        repository.calls.where((c) => c.startsWith('uploadConstancia')),
        isEmpty,
      );
      expect(
        container.read(companyVerificationControllerProvider).error,
        isA<DataFailure>().having(
          (f) => f.code,
          'code',
          DataFailureCode.invalidData,
        ),
      );
    });

    test('un archivo por encima del límite tampoco se sube', () async {
      picker.next = PickedConstancia(
        bytes: Uint8List(constanciaMaxBytes + 1),
        fileName: 'grande.pdf',
      );

      final format = await controller().attachConstancia();

      expect(format, isNull);
      expect(
        repository.calls.where((c) => c.startsWith('uploadConstancia')),
        isEmpty,
      );
    });
  });

  group('revisión administrativa', () {
    test('aprobar no arrastra motivo y refresca la cola', () async {
      await review().approve('req-1');

      expect(repository.lastReviewedRequestId, 'req-1');
      expect(repository.lastApprove, isTrue);
      expect(repository.lastReason, isNull);
    });

    test('rechazar viaja con el motivo elegido', () async {
      await review().reject(
        'req-1',
        VerificationRejectionReason.empresaNoOperativa,
      );

      expect(repository.lastApprove, isFalse);
      expect(
        repository.lastReason,
        VerificationRejectionReason.empresaNoOperativa,
      );
    });

    test('TFMFA queda tipado como secondFactorRequired', () async {
      repository.nextReviewFailure = const DataFailure(
        DataFailureCode.secondFactorRequired,
      );

      await review().approve('req-1');

      expect(
        container.read(verificationReviewControllerProvider).error,
        isA<DataFailure>().having(
          (f) => f.code,
          'code',
          DataFailureCode.secondFactorRequired,
        ),
      );
    });

    test('el doble tap no resuelve dos veces la misma solicitud', () async {
      final completer = Completer<void>();
      final lenta = _RepositorioLento(repository, completer.future);
      container = ProviderContainer.test(
        retry: (retryCount, error) => null,
        overrides: [
          companyVerificationRepositoryProvider.overrideWithValue(lenta),
          constanciaPickerProvider.overrideWithValue(picker),
        ],
      );

      final primera = review().approve('req-1');
      final segunda = review().approve('req-1');
      completer.complete();
      await Future.wait<void>([primera, segunda]);

      expect(
        repository.calls.where((c) => c == 'reviewVerification').length,
        1,
      );
    });
  });

  group('filtro de la cola', () {
    test('arranca en pendientes y cambia con select', () {
      expect(
        container.read(verificationQueueFilterProvider),
        CompanyVerificationStatus.pending,
      );

      container
          .read(verificationQueueFilterProvider.notifier)
          .select(CompanyVerificationStatus.rejected);

      expect(
        container.read(verificationQueueFilterProvider),
        CompanyVerificationStatus.rejected,
      );
    });
  });
}

/// Envuelve al fake y hace esperar la primera escritura, para poder disparar
/// un segundo tap mientras la primera sigue en vuelo.
class _RepositorioLento implements CompanyVerificationRepository {
  _RepositorioLento(this._inner, this._gate);

  final FakeCompanyVerificationRepository _inner;
  final Future<void> _gate;

  @override
  Future<CompanyVerification> fetchMyVerification() =>
      _inner.fetchMyVerification();

  @override
  Future<String> uploadConstancia(PickedConstancia document) =>
      _inner.uploadConstancia(document);

  @override
  Future<String> requestVerification({
    required String cuit,
    ConstanciaFormat? format,
  }) async {
    await _gate;
    return _inner.requestVerification(cuit: cuit, format: format);
  }

  @override
  Future<String> createConstanciaSignedUrl(String path) =>
      _inner.createConstanciaSignedUrl(path);

  @override
  Future<bool> hasSecondFactor() => _inner.hasSecondFactor();

  @override
  Future<List<CompanyVerificationRequest>> fetchVerificationQueue(
    CompanyVerificationStatus status,
  ) => _inner.fetchVerificationQueue(status);

  @override
  Future<void> reviewVerification({
    required String requestId,
    required bool approve,
    VerificationRejectionReason? reason,
  }) async {
    await _gate;
    return _inner.reviewVerification(
      requestId: requestId,
      approve: approve,
      reason: reason,
    );
  }
}
