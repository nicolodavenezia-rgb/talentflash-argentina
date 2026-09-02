import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/profiles/domain/avatar.dart';
import 'package:talentflash_argentina/features/profiles/domain/candidate_profile_patch.dart';
import 'package:talentflash_argentina/features/profiles/providers/profile_edit_controller.dart';
import 'package:talentflash_argentina/features/profiles/providers/profile_providers.dart';
import 'package:talentflash_argentina/shared/models/data_failure.dart';

import '../../../support/fake_profile_repositories.dart';

void main() {
  late FakeProfileRepository repository;
  late ProviderContainer container;

  ProfileEditController controller() =>
      container.read(profileEditControllerProvider.notifier);

  setUp(() {
    repository = FakeProfileRepository();
    container = ProviderContainer.test(
      // Igual que el harness: sin el retry automático de Riverpod 3, los
      // errores de providers son finales y el test es determinista.
      retry: (retryCount, error) => null,
      overrides: [profileRepositoryProvider.overrideWithValue(repository)],
    );
  });

  Uint8List pngBytes() => Uint8List.fromList([
    0x89,
    0x50,
    0x4e,
    0x47,
    0x0d,
    0x0a,
    0x1a,
    0x0a,
    1,
    2,
    3,
  ]);

  test('guardar aplica el parche y refresca el perfil propio', () async {
    final patch = CandidateProfilePatch()..setHeadline('Nuevo titular');
    await controller().save(patch);

    expect(repository.lastPatch, same(patch));
    expect(repository.calls, contains('updateMyProfile'));
    expect(repository.calls, contains('fetchMyProfile'));
    expect(
      container.read(profileEditControllerProvider).value,
      ProfileActionOutcome.saved,
    );
  });

  test('el doble submit se ignora mientras hay una acción en curso', () async {
    repository.pendingAction = Completer<void>();
    final first = controller().save(CandidateProfilePatch()..setBio('a'));
    final second = controller().save(CandidateProfilePatch()..setBio('b'));

    repository.pendingAction!.complete();
    await Future.wait([first, second]);

    expect(
      repository.calls.where((call) => call == 'updateMyProfile').length,
      1,
      reason: 'el segundo tap no debe duplicar la llamada',
    );
  });

  test('un error del servidor queda tipado como DataFailure', () async {
    repository.nextFailure = const DataFailure(DataFailureCode.invalidData);
    await controller().save(CandidateProfilePatch()..setBio('x'));

    final state = container.read(profileEditControllerProvider);
    expect(state.hasError, isTrue);
    expect((state.error! as DataFailure).code, DataFailureCode.invalidData);
  });

  test('subir un avatar válido pasa por el repositorio y refresca', () async {
    await controller().uploadAvatar(
      PickedAvatarImage(bytes: pngBytes(), fileName: 'foto.png'),
    );

    expect(repository.calls, contains('uploadAvatar'));
    expect(repository.lastUploadedContentType, 'image/png');
    expect(
      container.read(profileEditControllerProvider).value,
      ProfileActionOutcome.avatarUploaded,
    );
  });

  test(
    'una imagen demasiado grande se rechaza SIN llamar al servidor',
    () async {
      final huge = Uint8List(AvatarValidation.maxBytes + 1);
      huge.setRange(0, 3, const [0xff, 0xd8, 0xff]);
      await controller().uploadAvatar(
        PickedAvatarImage(bytes: huge, fileName: 'grande.jpg'),
      );

      final state = container.read(profileEditControllerProvider);
      expect((state.error! as AvatarFailure).code, AvatarFailureCode.tooLarge);
      expect(repository.calls, isNot(contains('uploadAvatar')));
    },
  );

  test(
    'WebP se rechaza localmente con el código honesto de no soportado',
    () async {
      final webp = Uint8List.fromList([
        0x52,
        0x49,
        0x46,
        0x46,
        0,
        0,
        0,
        0,
        0x57,
        0x45,
        0x42,
        0x50,
      ]);
      await controller().uploadAvatar(
        PickedAvatarImage(bytes: webp, fileName: 'foto.webp'),
      );

      final state = container.read(profileEditControllerProvider);
      expect(
        (state.error! as AvatarFailure).code,
        AvatarFailureCode.unsupportedFormat,
      );
      expect(repository.calls, isNot(contains('uploadAvatar')));
    },
  );

  test('eliminar el avatar informa el resultado y refresca', () async {
    await controller().deleteAvatar();

    expect(repository.calls, contains('deleteAvatar'));
    expect(
      container.read(profileEditControllerProvider).value,
      ProfileActionOutcome.avatarDeleted,
    );
  });

  test('reset limpia el resultado anterior', () async {
    await controller().deleteAvatar();
    controller().reset();

    expect(container.read(profileEditControllerProvider).value, isNull);
  });
}
