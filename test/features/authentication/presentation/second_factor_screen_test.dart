import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_failure.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_status.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';
import 'package:talentflash_argentina/features/authentication/domain/second_factor.dart';
import 'package:talentflash_argentina/features/authentication/domain/session_assurance.dart';
import 'package:talentflash_argentina/features/authentication/presentation/login_screen.dart';
import 'package:talentflash_argentina/features/authentication/presentation/second_factor_screen.dart';
import 'package:talentflash_argentina/features/authentication/presentation/session_issue_screen.dart';
import 'package:talentflash_argentina/features/authentication/providers/auth_providers.dart';
import 'package:talentflash_argentina/features/companies/data/company_access_repository.dart';
import 'package:talentflash_argentina/features/companies/domain/company_verification.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_company_verification_repository.dart';
import '../../../support/gestures.dart';
import '../../../support/pump_app.dart';

/// `/admin/segundo-factor`: alta y verificación TOTP desde la cola admin.
///
/// Todo corre con repositorios falsos: lo que pasa contra el GoTrue real está
/// en `npm run mfa:test`. Acá se prueba la pantalla: qué muestra, qué pide,
/// qué nunca muestra, y cómo vuelve a la cola cuando la sesión sube a aal2.
void main() {
  // Secretos de prueba, inventados. Además de falsos son **de baja entropía a
  // propósito**: el scan de secretos de la CI (gitleaks, regla
  // `generic-api-key`) marca cualquier literal cerca de la palabra `secret`
  // que pase de 3.5 bits por carácter, y un fixture con las 16 letras
  // distintas lo supera y rompe la CI. Si hace falta otro, que repita
  // caracteres como estos dos.
  const secret = 'JBSWY3DPEHPK3PXP';

  CompanyVerificationRequest solicitud() => const CompanyVerificationRequest(
    requestId: 'req-1',
    companyId: 'c-1',
    companyName: 'Parrilla Don Julio Dev',
    requestStatus: CompanyVerificationStatus.pending,
    cuitSubmitted: '30-70000001-6',
    companyStatus: CompanyVerificationStatus.pending,
  );

  /// Todo el texto que la pantalla dibuja: `Text`, `SelectableText` y los
  /// `RichText` a los que ambos delegan (así una clave mostrada por cualquier
  /// vía queda cubierta).
  String textoVisible(WidgetTester tester) => [
    ...tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? ''),
    ...tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((t) => t.data ?? ''),
    ...tester
        .widgetList<RichText>(find.byType(RichText))
        .map((t) => t.text.toPlainText()),
  ].join('\n');

  Finder codeField() => find.byType(TextFormField);

  /// Admin con sesión aal1 parada en la cola, que toca la acción de segundo
  /// factor. Devuelve el harness con la pantalla ya cargada.
  Future<TalentFlashHarness> abrirSegundoFactor(
    WidgetTester tester, {
    FakeAuthRepository? auth,
    FakeCompanyVerificationRepository? verification,
    bool desdeLaCola = true,
  }) async {
    final repository =
        auth ?? FakeAuthRepository(initialStatus: const AuthStatusSignedOut());
    final harness = await pumpTalentFlashApp(
      tester,
      authRepository: repository,
      companyVerificationRepository:
          verification ??
          FakeCompanyVerificationRepository(queue: [solicitud()]),
    );
    await tester.pumpAndSettle();
    if (repository.currentStatus is AuthStatusSignedOut) {
      repository.emitSignedIn(BusinessRole.admin);
      await tester.pumpAndSettle();
    }
    if (desdeLaCola) {
      harness.router.go('/admin/verificaciones');
      await tester.pumpAndSettle();
      await ensureAndTap(tester, find.text('Verificar segundo factor'));
    } else {
      harness.router.go('/admin/segundo-factor');
      await tester.pumpAndSettle();
    }
    return harness;
  }

  group('el alta venció mientras la persona se tomaba su tiempo', () {
    testWidgets(
      'se rehace el alta, se ve el aviso, el QR cambia y el código anterior '
      'no se manda contra el factor nuevo',
      (tester) async {
        // Es el costo conocido de pedir el desafío recién al mandar el
        // código: el factor pudo haberlo recolectado el servidor. La pantalla
        // tiene que decir que el QR cambió, no reutilizar nada, y no dejar el
        // código viejo cargado.
        final auth = FakeAuthRepository(
          initialStatus: const AuthStatusSignedOut(),
        );
        auth.queuedEnrollments.addAll(const [
          TotpEnrollment(
            factorId: 'factor-pendiente',
            friendlyName: 'TalentFlash · 08/09/2026 14:32',
            secret: secret,
            uri:
                'otpauth://totp/TalentFlash%20Argentina:persona?secret=$secret',
          ),
          TotpEnrollment(
            factorId: 'factor-rehecho',
            friendlyName: 'TalentFlash · 08/09/2026 14:40',
            secret: 'KRSXG5CTKRSXG5CT',
            uri:
                'otpauth://totp/TalentFlash%20Argentina:persona'
                '?secret=KRSXG5CTKRSXG5CT',
          ),
        ]);
        final harness = await abrirSegundoFactor(tester, auth: auth);
        expect(find.text('JBSW Y3DP EHPK 3PXP'), findsOneWidget);

        // El servidor ya no conoce el factor cuando se pide el desafío.
        harness.authRepository.nextChallengeFailure = const AuthFailure(
          AuthFailureCode.mfaFactorNotFound,
        );
        await tester.enterText(codeField(), '123456');
        await ensureAndTap(tester, find.text('Activar segundo factor'));
        await tester.pumpAndSettle();

        expect(harness.location, '/admin/segundo-factor');
        expect(
          find.text('La configuración anterior venció'),
          findsOneWidget,
          reason: 'el aviso se ve, no solo existe en el estado',
        );
        expect(
          textoVisible(tester),
          contains('Este código QR es NUEVO'),
          reason: 'y dice qué tiene que hacer la persona',
        );
        expect(
          find.text('KRSX G5CT KRSX G5CT'),
          findsOneWidget,
          reason: 'la clave manual es la del factor nuevo',
        );
        expect(find.text('JBSW Y3DP EHPK 3PXP'), findsNothing);
        expect(find.byType(QrImageView), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller?.text,
          isEmpty,
          reason:
              'el código anterior era para el factor viejo: no puede quedar '
              'cargado contra el nuevo',
        );
        expect(
          harness.authRepository.calls.where((c) => c.startsWith('verify')),
          isEmpty,
          reason: 'no se mandó ningún código contra el factor nuevo',
        );
        expect(
          harness.authRepository.calls.where((c) => c == 'enrollTotp').length,
          2,
          reason: 'exactamente un alta nueva: sin bucle',
        );

        // Y desde acá el recorrido normal termina bien con el QR nuevo.
        await tester.enterText(codeField(), '123456');
        await ensureAndTap(tester, find.text('Activar segundo factor'));
        await tester.pumpAndSettle();
        expect(harness.location, '/admin/verificaciones');
      },
    );
  });

  group('alta (sin factor verificado)', () {
    testWidgets('muestra el QR, la clave manual y el campo de código', (
      tester,
    ) async {
      final harness = await abrirSegundoFactor(tester);

      expect(harness.location, '/admin/segundo-factor');
      expect(find.byType(SecondFactorScreen), findsOneWidget);
      expect(find.text('Configurá tu autenticador'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Clave manual'), findsOneWidget);
      expect(find.text('JBSW Y3DP EHPK 3PXP'), findsOneWidget);
      expect(
        find.text('Copiar clave'),
        findsNothing,
        reason: 'la clave no se manda al portapapeles del sistema',
      );
      expect(find.text('Código de 6 dígitos'), findsOneWidget);
      expect(find.text('Activar segundo factor'), findsOneWidget);
      expect(
        textoVisible(tester),
        contains('queda activo recién cuando ingresás un código válido'),
        reason: 'un factor pendiente no se presenta como configurado',
      );
      expect(
        textoVisible(tester),
        contains('no permite recuperar, dar de baja ni reemplazar'),
        reason: 'los límites se dicen, no se inventa un circuito de soporte',
      );
      expect(harness.authRepository.calls, <String>[
        'listVerifiedSecondFactors',
        'enrollTotp',
      ], reason: 'el desafío se pide recién al mandar el código');
    });

    testWidgets('el QR y la clave tienen alternativa accesible', (
      tester,
    ) async {
      await abrirSegundoFactor(tester);

      final qr = tester.widget<QrImageView>(find.byType(QrImageView));
      expect(qr.semanticsLabel, contains('Código QR'));
      expect(qr.semanticsLabel, contains('clave manual'));

      final key = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(key.data, 'JBSW Y3DP EHPK 3PXP');
      expect(key.semanticsLabel, contains('J B S W Y 3 D P'));
      expect(
        find.bySemanticsLabel(RegExp('Código QR')),
        findsOneWidget,
        reason: 'el lector de pantalla encuentra el QR por su etiqueta',
      );
    });

    testWidgets(
      'el secreto crudo y la URI no aparecen por ninguna vía de texto',
      (tester) async {
        await abrirSegundoFactor(tester);

        final texto = textoVisible(tester);
        expect(texto, contains('JBSW Y3DP EHPK 3PXP'));
        expect(texto, isNot(contains(secret)));
        expect(texto, isNot(contains('otpauth')));
        // Tampoco viaja al portapapeles sin que la persona lo pida: no hay
        // ningún botón que lo haga.
        String? copiado;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copiado =
                  (call.arguments as Map<Object?, Object?>)['text'] as String?;
            }
            return null;
          },
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
        });
        for (final button in tester.widgetList<ButtonStyleButton>(
          find.byType(ButtonStyleButton),
        )) {
          button.onPressed?.call();
        }
        await tester.pumpAndSettle();
        expect(copiado, isNull);
      },
    );

    testWidgets('el campo de código es numérico, de un solo uso y de 6', (
      tester,
    ) async {
      await abrirSegundoFactor(tester);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.number);
      expect(field.autofillHints, contains(AutofillHints.oneTimeCode));
      expect(field.textInputAction, TextInputAction.done);
      expect(field.inputFormatters, isNotEmpty);
      expect(
        field.autofocus,
        isFalse,
        reason: 'en el alta lo primero que se ve es el QR, no el teclado',
      );

      await tester.enterText(codeField(), '12ab34567');
      await tester.pump();
      expect(find.text('123456'), findsOneWidget);
    });

    testWidgets('mientras se prepara el alta se puede volver', (tester) async {
      final auth = FakeAuthRepository(
        initialStatus: const AuthStatusSignedOut(),
      )..pendingSecondFactorAction = Completer<void>();
      final harness = await pumpTalentFlashApp(
        tester,
        authRepository: auth,
        companyVerificationRepository: FakeCompanyVerificationRepository(),
      );
      await tester.pumpAndSettle();
      auth.emitSignedIn(BusinessRole.admin);
      await tester.pumpAndSettle();
      harness.router.go('/admin/segundo-factor');
      await tester.pump();
      await tester.pump();

      expect(find.text('Preparando el segundo factor…'), findsOneWidget);
      await tester.tap(find.text('Cancelar y volver'));
      await tester.pump();
      await tester.pump();

      expect(harness.location, '/admin/verificaciones');
    });

    testWidgets('un envío vacío o corto se valida en el campo', (tester) async {
      final harness = await abrirSegundoFactor(tester);

      await ensureAndTap(tester, find.text('Activar segundo factor'));
      expect(find.text('Ingresá el código de tu app.'), findsOneWidget);

      await tester.enterText(codeField(), '123');
      await ensureAndTap(tester, find.text('Activar segundo factor'));
      expect(find.text('El código tiene 6 dígitos.'), findsOneWidget);

      expect(
        harness.authRepository.calls,
        isNot(contains(startsWith('verify'))),
        reason: 'lo que no tiene forma de código no viaja al servidor',
      );
    });

    testWidgets(
      'con el código correcto verifica y vuelve a la cola con el mismo '
      'usuario',
      (tester) async {
        final harness = await abrirSegundoFactor(tester);
        // Identidad según la APP (provider), no según el fake.
        final antes = harness.container.read(currentAuthUserProvider);
        expect(antes, isNotNull);

        await tester.enterText(codeField(), '123456');
        await ensureAndTap(tester, find.text('Activar segundo factor'));

        expect(harness.authRepository.lastVerifiedCode, '123456');
        expect(harness.authRepository.lastVerifiedFactorId, 'factor-pendiente');
        expect(harness.location, '/admin/verificaciones');
        expect(find.byType(SecondFactorScreen), findsNothing);
        expect(
          find.text('Segundo factor verificado. Ya podés revisar la cola.'),
          findsOneWidget,
        );
        expect(find.text('Parrilla Don Julio Dev'), findsOneWidget);
        expect(harness.container.read(currentAuthUserProvider), antes);
        expect(
          harness.container.read(sessionAssuranceProvider),
          SessionAssurance.aal2,
        );
        expect(
          harness.authRepository.calls,
          isNot(contains('signOut')),
          reason: 'nada se reinició',
        );
      },
    );

    testWidgets('enviar con Enter también verifica', (tester) async {
      final harness = await abrirSegundoFactor(tester);

      await tester.enterText(codeField(), '123456');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(harness.authRepository.lastVerifiedCode, '123456');
      expect(harness.location, '/admin/verificaciones');
    });

    testWidgets('un código incorrecto se explica y el alta sigue en pie', (
      tester,
    ) async {
      final harness = await abrirSegundoFactor(tester);
      harness.authRepository.nextVerifyFailure = const AuthFailure(
        AuthFailureCode.mfaInvalidCode,
        debugDetail: 'AuthException(code: mfa_verification_failed)',
      );

      await tester.enterText(codeField(), '000000');
      await ensureAndTap(tester, find.text('Activar segundo factor'));

      expect(harness.location, '/admin/segundo-factor');
      expect(find.text('No pudimos verificar el código'), findsOneWidget);
      expect(textoVisible(tester), contains('El código no es válido'));
      expect(textoVisible(tester), isNot(contains('mfa_verification_failed')));
      expect(find.byType(QrImageView), findsOneWidget);
      expect(
        harness.authRepository.calls.where((c) => c == 'enrollTotp').length,
        1,
        reason: 'no se crea otro factor por un código mal tipeado',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
        isTrue,
        reason: 'el foco vuelve al campo para corregir',
      );

      // Con el código bueno termina igual.
      await tester.enterText(codeField(), '123456');
      await ensureAndTap(tester, find.text('Activar segundo factor'));
      expect(harness.location, '/admin/verificaciones');
    });

    testWidgets('el desafío vencido, el límite y la red tienen su texto', (
      tester,
    ) async {
      final harness = await abrirSegundoFactor(tester);
      final casos = <AuthFailureCode, String>{
        AuthFailureCode.mfaChallengeExpired: 'Se venció el tiempo',
        AuthFailureCode.rateLimited: 'muchos intentos',
        AuthFailureCode.network: 'No pudimos conectarnos',
        AuthFailureCode.mfaRejected: 'fue rechazada',
      };
      for (final entry in casos.entries) {
        harness.authRepository.nextVerifyFailure = AuthFailure(entry.key);
        await tester.enterText(codeField(), '123456');
        await ensureAndTap(tester, find.text('Activar segundo factor'));
        expect(
          textoVisible(tester),
          contains(entry.value),
          reason: 'para ${entry.key}',
        );
      }
    });

    testWidgets('mientras el código viaja no se puede reenviar', (
      tester,
    ) async {
      final harness = await abrirSegundoFactor(tester);
      final gate = Completer<void>();
      harness.authRepository.pendingSecondFactorAction = gate;

      await tester.enterText(codeField(), '123456');
      await tester.ensureVisible(find.text('Activar segundo factor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Activar segundo factor'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();

      expect(
        harness.authRepository.calls.where((c) => c.startsWith('verify')),
        hasLength(1),
      );
    });

    testWidgets('cancelar descarta el factor pendiente y vuelve a la cola', (
      tester,
    ) async {
      final harness = await abrirSegundoFactor(tester);

      await ensureAndTap(tester, find.text('Cancelar y volver'));

      expect(harness.location, '/admin/verificaciones');
      expect(find.text('Necesitás segundo factor'), findsOneWidget);
      expect(harness.authRepository.discardedFactorIds, <String>[
        'factor-pendiente',
      ]);
    });

    testWidgets('volver a entrar tras cancelar inicia un alta nueva', (
      tester,
    ) async {
      final harness = await abrirSegundoFactor(tester);
      await ensureAndTap(tester, find.text('Cancelar y volver'));

      await ensureAndTap(tester, find.text('Verificar segundo factor'));

      expect(find.byType(QrImageView), findsOneWidget);
      expect(
        harness.authRepository.calls.where((c) => c == 'enrollTotp').length,
        2,
      );
    });
  });

  group('desafío (con factor ya verificado)', () {
    testWidgets('pide el código del factor existente y no crea otro', (
      tester,
    ) async {
      final auth =
          FakeAuthRepository(initialStatus: const AuthStatusSignedOut())
            ..verifiedFactors = [
              SecondFactor(
                id: 'factor-ok',
                friendlyName: 'Mi celular',
                createdAt: DateTime(2026, 9, 1),
              ),
            ];
      final harness = await abrirSegundoFactor(tester, auth: auth);

      expect(find.text('Confirmá tu segundo factor'), findsOneWidget);
      expect(textoVisible(tester), contains('para Mi celular'));
      expect(
        textoVisible(tester),
        isNot(contains('01/09/2026')),
        reason: 'con etiqueta propia no se repite la fecha',
      );
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Clave manual'), findsNothing);
      expect(find.text('Usar otro autenticador'), findsNothing);
      expect(auth.calls, isNot(contains('enrollTotp')));
      expect(
        tester.widget<TextField>(find.byType(TextField)).autofocus,
        isTrue,
        reason: 'acá solo hay que tipear: el campo toma foco al abrir',
      );

      await tester.enterText(codeField(), '654321');
      await ensureAndTap(tester, find.text('Verificar'));

      expect(auth.lastVerifiedFactorId, 'factor-ok');
      expect(harness.location, '/admin/verificaciones');
      expect(find.text('Parrilla Don Julio Dev'), findsOneWidget);
    });

    testWidgets('con varios factores se elige cuál usar', (tester) async {
      final auth =
          FakeAuthRepository(initialStatus: const AuthStatusSignedOut())
            ..verifiedFactors = const [
              SecondFactor(id: 'factor-a', friendlyName: 'Celular'),
              SecondFactor(id: 'factor-b', friendlyName: 'Tablet'),
            ];
      await abrirSegundoFactor(tester, auth: auth);

      expect(find.text('¿Qué autenticador vas a usar?'), findsOneWidget);
      expect(find.text('Celular'), findsOneWidget);
      expect(find.text('Tablet'), findsOneWidget);

      await ensureAndTap(tester, find.text('Tablet'));
      expect(textoVisible(tester), contains('para Tablet'));

      await ensureAndTap(tester, find.text('Usar otro autenticador'));
      expect(find.text('¿Qué autenticador vas a usar?'), findsOneWidget);

      await ensureAndTap(tester, find.text('Celular'));
      await tester.enterText(codeField(), '111111');
      await ensureAndTap(tester, find.text('Verificar'));
      expect(auth.lastVerifiedFactorId, 'factor-a');
    });

    testWidgets('un factor sin nombre se lista con un rótulo propio', (
      tester,
    ) async {
      final auth =
          FakeAuthRepository(initialStatus: const AuthStatusSignedOut())
            ..verifiedFactors = [
              const SecondFactor(id: 'factor-a'),
              SecondFactor(id: 'factor-c', createdAt: DateTime(2026, 9, 1)),
              const SecondFactor(id: 'factor-b', friendlyName: 'Tablet'),
            ];
      await abrirSegundoFactor(tester, auth: auth);

      expect(find.text('Autenticador sin nombre'), findsOneWidget);
      expect(
        find.text('Autenticador sin nombre, registrado el 01/09/2026'),
        findsOneWidget,
        reason: 'la fecha distingue a los factores sin etiqueta',
      );
    });
  });

  group('estados de sesión', () {
    testWidgets('si la sesión ya es aal2 vuelve a la cola sin desafiar', (
      tester,
    ) async {
      final auth = FakeAuthRepository(
        initialStatus: const AuthStatusSignedOut(),
      );
      final harness = await pumpTalentFlashApp(
        tester,
        authRepository: auth,
        companyVerificationRepository: FakeCompanyVerificationRepository(
          queue: [solicitud()],
        ),
      );
      await tester.pumpAndSettle();
      auth.emitSignedIn(BusinessRole.admin, assurance: SessionAssurance.aal2);
      await tester.pumpAndSettle();

      harness.router.go('/admin/segundo-factor');
      await tester.pumpAndSettle();

      expect(harness.location, '/admin/verificaciones');
      expect(
        find.text('Tu sesión ya tiene el segundo factor verificado.'),
        findsOneWidget,
      );
      expect(auth.calls, isEmpty, reason: 'ni un desafío de más');
    });

    testWidgets('si no se pueden leer los factores se explica y se reintenta', (
      tester,
    ) async {
      final auth = FakeAuthRepository(
        initialStatus: const AuthStatusSignedOut(),
      )..nextListFactorsFailure = const AuthFailure(AuthFailureCode.network);
      final harness = await abrirSegundoFactor(tester, auth: auth);

      expect(
        find.text('No pudimos preparar el segundo factor'),
        findsOneWidget,
      );
      expect(textoVisible(tester), contains('No pudimos conectarnos'));
      expect(find.byType(QrImageView), findsNothing);

      await ensureAndTap(tester, find.text('Reintentar'));

      expect(find.byType(QrImageView), findsOneWidget);
      expect(
        harness.authRepository.calls
            .where((c) => c == 'listVerifiedSecondFactors')
            .length,
        2,
      );
    });

    testWidgets('cerrar sesión durante el alta descarta la pantalla', (
      tester,
    ) async {
      final harness = await abrirSegundoFactor(tester);
      expect(find.byType(QrImageView), findsOneWidget);

      harness.authRepository.emit(const AuthStatusSignedOut());
      await tester.pumpAndSettle();

      expect(find.byType(SecondFactorScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('JBSW Y3DP EHPK 3PXP'), findsNothing);
      expect(
        harness.authRepository.discardedFactorIds,
        isEmpty,
        reason: 'sin sesión no se llama al servidor',
      );
    });

    testWidgets('una cuenta sin rol admin no llega a la pantalla', (
      tester,
    ) async {
      final auth = FakeAuthRepository(
        initialStatus: const AuthStatusSignedOut(),
      );
      final harness = await pumpTalentFlashApp(tester, authRepository: auth);
      await tester.pumpAndSettle();
      auth.emitSignedIn(BusinessRole.company);
      await tester.pumpAndSettle();

      harness.router.go('/admin/segundo-factor');
      await tester.pumpAndSettle();

      expect(find.byType(SessionIssueScreen), findsOneWidget);
      expect(find.byType(SecondFactorScreen), findsNothing);
      expect(auth.calls, isEmpty);
    });

    testWidgets('sin sesión la ruta manda al login guardando el destino', (
      tester,
    ) async {
      final harness = await pumpTalentFlashApp(
        tester,
        authRepository: FakeAuthRepository(
          initialStatus: const AuthStatusSignedOut(),
        ),
      );
      await tester.pumpAndSettle();

      harness.router.go('/admin/segundo-factor');
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(harness.location, contains('destino=%2Fadmin%2Fsegundo-factor'));
    });

    testWidgets('el texto escala al 200 % sin perder el QR ni el campo', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await abrirSegundoFactor(tester);

      expect(find.byType(QrImageView), findsOneWidget);
      await tester.ensureVisible(find.text('Activar segundo factor'));
      expect(find.text('Activar segundo factor'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'el mensaje de error del campo puede ocupar varias líneas: al 200 % no '
      'se corta con elipsis',
      (tester) async {
        await abrirSegundoFactor(tester);

        final decoration = tester
            .widget<TextField>(
              find.descendant(
                of: codeField(),
                matching: find.byType(TextField),
              ),
            )
            .decoration!;
        // `errorMaxLines` por defecto es null, que en Flutter significa UNA
        // línea con `TextOverflow.ellipsis` (no «sin límite»): el mensaje que
        // dice cómo corregir se cortaría justo donde hace falta leerlo.
        expect(decoration.errorMaxLines, isNotNull);
        expect(decoration.errorMaxLines, greaterThan(1));
        expect(decoration.helperMaxLines, greaterThan(1));
      },
    );

    testWidgets('un cambio a otra sesión admin no deja la pantalla anunciando '
        '«preparando» para siempre: explica y ofrece reintentar', (
      tester,
    ) async {
      final harness = await abrirSegundoFactor(tester);
      expect(find.byType(QrImageView), findsOneWidget);

      // Otra sesión admin (otra pestaña, u otra cuenta admin) sin pasar por
      // SignedOut: el router no mueve la pantalla, así que si el flujo
      // volviera a `Idle` se quedaría con el spinner de «preparando».
      harness.authRepository.emitSignedIn(
        BusinessRole.admin,
        id: 'admin-2',
        email: 'otra@dev.talentflash.test',
        sessionId: 'sesion-2',
      );
      await tester.pumpAndSettle();

      expect(find.byType(SecondFactorScreen), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('JBSW Y3DP EHPK 3PXP'), findsNothing);
      expect(
        textoVisible(tester),
        isNot(contains('Preparando el segundo factor')),
        reason: 'no puede anunciar un trabajo que no está ocurriendo',
      );
      expect(
        textoVisible(tester),
        contains('La sesión cambió mientras preparábamos el segundo factor'),
      );
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });
}
