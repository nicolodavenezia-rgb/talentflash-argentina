import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_status.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';
import 'package:talentflash_argentina/features/profiles/domain/avatar.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_profile_repositories.dart';
import '../../../support/gestures.dart';
import '../../../support/pump_app.dart';

/// Edición del perfil (T-021) + avatar (T-022): parche completo, limpieza
/// explícita de opcionales, doble submit bloqueado y confirmación al salir.
void main() {
  Future<TalentFlashHarness> pumpEdit(
    WidgetTester tester, {
    FakeProfileRepository? profileRepository,
    FakeAvatarImagePicker? avatarPicker,
  }) async {
    final auth = FakeAuthRepository(initialStatus: const AuthStatusSignedOut());
    final harness = await pumpTalentFlashApp(
      tester,
      authRepository: auth,
      profileRepository: profileRepository,
      avatarPicker: avatarPicker,
    );
    await tester.pumpAndSettle();
    auth.emitSignedIn(BusinessRole.candidate);
    await tester.pumpAndSettle();
    harness.router.go('/candidato/perfil/editar');
    await tester.pumpAndSettle();
    return harness;
  }

  Finder fieldWithText(String value) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.controller?.text == value,
  );

  /// Un TextField enfocado vuelve a scrollear el formulario hacia sí mismo en
  /// cada frame: hay que soltar el foco antes de ir al botón de guardar.
  Future<void> tapSave(WidgetTester tester) async {
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await ensureAndTap(tester, find.text('Guardar cambios'));
  }

  testWidgets('el formulario carga los valores actuales del perfil', (
    tester,
  ) async {
    await pumpEdit(tester);

    expect(fieldWithText('Ana María Prueba'), findsOneWidget);
    expect(fieldWithText('Moza de salón con experiencia'), findsOneWidget);
    expect(find.text('atención al cliente'), findsOneWidget);
  });

  testWidgets('guardar arma un parche completo y lo aplica', (tester) async {
    final repository = FakeProfileRepository();
    final harness = await pumpEdit(tester, profileRepository: repository);

    await tester.enterText(
      fieldWithText('Moza de salón con experiencia'),
      'Busco turno noche',
    );
    await tapSave(tester);

    final patch = harness.profileRepository.lastPatch!.toJson();
    expect(patch['headline'], 'Busco turno noche');
    expect(patch['full_name'], 'Ana María Prueba');
    expect(patch['skills'], contains('atención al cliente'));
    expect(find.text('Cambios guardados.'), findsOneWidget);
  });

  testWidgets('vaciar un opcional viaja como null explícito (limpieza)', (
    tester,
  ) async {
    final repository = FakeProfileRepository();
    await pumpEdit(tester, profileRepository: repository);

    await tester.enterText(fieldWithText('Moza de salón con experiencia'), '');
    await tapSave(tester);

    final patch = repository.lastPatch!.toJson();
    expect(patch.containsKey('headline'), isTrue);
    expect(patch['headline'], isNull);
  });

  testWidgets('el doble submit no duplica el guardado', (tester) async {
    final repository = FakeProfileRepository();
    await pumpEdit(tester, profileRepository: repository);
    // Recién ahora se frena la próxima acción: el fetch inicial ya pasó.
    repository.pendingAction = Completer<void>();

    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar cambios'));
    await tester.pump();
    // El botón queda deshabilitado con spinner: no hay segundo tap posible,
    // y aunque lo hubiera el controller lo ignora.
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.byType(CircularProgressIndicator).last,
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );
    repository.pendingAction!.complete();
    await tester.pumpAndSettle();

    expect(
      repository.calls.where((call) => call == 'updateMyProfile').length,
      1,
    );
  });

  testWidgets('una habilidad duplicada muestra el error local', (tester) async {
    await pumpEdit(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Agregar habilidad'),
      'Caja',
    );
    await ensureAndTap(tester, find.text('Agregar').first);
    await tester.pumpAndSettle();

    expect(find.text('Ese valor ya está en la lista.'), findsOneWidget);
  });

  testWidgets('agregar una experiencia por diálogo la suma a la lista', (
    tester,
  ) async {
    final repository = FakeProfileRepository();
    await pumpEdit(tester, profileRepository: repository);

    await ensureAndTap(tester, find.text('Agregar experiencia'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Empresa o lugar'),
      'Hotel de Prueba',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Puesto'),
      'Recepcionista',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Desde (MM/AAAA)'),
      '05/2024',
    );
    await ensureAndTap(tester, find.text('Trabajo acá actualmente'));
    await ensureAndTap(tester, find.text('Guardar experiencia'));
    await tester.pumpAndSettle();

    expect(find.text('Recepcionista · Hotel de Prueba'), findsOneWidget);

    await tapSave(tester);
    final history = repository.lastPatch!.toJson()['work_history']! as List;
    expect(history, hasLength(2));
  });

  testWidgets('una franja horaria superpuesta se rechaza en el diálogo', (
    tester,
  ) async {
    await pumpEdit(tester);

    Future<void> addSlot(String start, String end) async {
      await ensureAndTap(tester, find.text('Agregar franja'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Desde (HH:MM)'),
        start,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Hasta (HH:MM)'),
        end,
      );
      await ensureAndTap(tester, find.text('Guardar franja'));
      await tester.pumpAndSettle();
    }

    await addSlot('09:00', '13:00');
    expect(find.text('Lunes de 09:00 a 13:00'), findsOneWidget);

    await addSlot('12:00', '15:00');
    expect(
      find.text('Esa franja se superpone con otra que ya cargaste.'),
      findsOneWidget,
    );
  });

  testWidgets('salir con cambios sin guardar pide confirmación', (
    tester,
  ) async {
    final harness = await pumpEdit(tester);

    await tester.enterText(
      fieldWithText('Moza de salón con experiencia'),
      'Cambio sin guardar',
    );
    await ensureAndTap(tester, find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('¿Salir sin guardar?'), findsOneWidget);
    await ensureAndTap(tester, find.text('Seguir editando'));
    await tester.pumpAndSettle();
    expect(harness.location, '/candidato/perfil/editar');

    await ensureAndTap(tester, find.byType(BackButton));
    await tester.pumpAndSettle();
    await ensureAndTap(tester, find.text('Salir sin guardar'));
    await tester.pumpAndSettle();
    expect(harness.location, '/candidato/perfil');
  });

  testWidgets('subir una foto pasa por el picker inyectado y avisa', (
    tester,
  ) async {
    final picker = FakeAvatarImagePicker()
      ..next = PickedAvatarImage(
        bytes: Uint8List.fromList([
          0x89,
          0x50,
          0x4e,
          0x47,
          0x0d,
          0x0a,
          0x1a,
          0x0a,
          1,
        ]),
        fileName: 'foto.png',
      );
    final repository = FakeProfileRepository();
    await pumpEdit(tester, profileRepository: repository, avatarPicker: picker);

    await ensureAndTap(tester, find.text('Agregar foto'));
    await tester.pumpAndSettle();

    expect(picker.pickCount, 1);
    expect(repository.calls, contains('uploadAvatar'));
    expect(repository.lastUploadedContentType, 'image/png');
    expect(find.text('Foto de perfil actualizada.'), findsOneWidget);
  });

  testWidgets('un archivo que no es imagen se rechaza sin subir nada', (
    tester,
  ) async {
    final picker = FakeAvatarImagePicker()
      ..next = PickedAvatarImage(
        bytes: Uint8List.fromList('<html>'.codeUnits),
        fileName: 'malicioso.html',
      );
    final repository = FakeProfileRepository();
    await pumpEdit(tester, profileRepository: repository, avatarPicker: picker);

    await ensureAndTap(tester, find.text('Agregar foto'));
    await tester.pumpAndSettle();

    expect(repository.calls, isNot(contains('uploadAvatar')));
    expect(
      find.text('El archivo no parece una imagen JPEG o PNG válida.'),
      findsOneWidget,
    );
  });
}
