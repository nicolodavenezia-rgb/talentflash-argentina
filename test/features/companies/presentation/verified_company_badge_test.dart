import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/core/localization/gen/app_localizations.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_status.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';
import 'package:talentflash_argentina/features/companies/data/company_access_repository.dart';
import 'package:talentflash_argentina/features/companies/presentation/widgets/verified_company_badge.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_profile_repositories.dart';
import '../../../support/pump_app.dart';

/// T-029: distintivo "empresa verificada".
///
/// El test se corre sobre la superficie de empresa que YA existe —el shell
/// `/empresa`— y no sobre una tarjeta inventada para la ocasión. La tarjeta de
/// oferta, que el ROADMAP también nombra, se difiere a T-030 junto con la
/// oferta misma: hoy `lib/features/jobs/` está vacío y montar una tarjeta
/// ficticia solo para tener un golden sería probar el andamio, no el producto.
///
/// Tampoco se usa `matchesGoldenFile`: no hay infraestructura de goldens en el
/// repo (ni golden_toolkit ni alchemist) y un PNG generado en Windows no
/// coincide con el render del runner Linux de CI, así que sería un test rojo
/// por razones ajenas al badge. Lo que importa —cuándo aparece, cuándo no, y
/// qué anuncia el lector de pantalla— se afirma acá directamente.
void main() {
  const etiqueta = 'Empresa verificada';

  Widget montar(CompanyVerificationStatus? status) {
    return MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: VerifiedCompanyBadge(status: status)),
    );
  }

  group('unidad', () {
    testWidgets('se dibuja solo con approved exacto', (tester) async {
      await tester.pumpWidget(montar(CompanyVerificationStatus.approved));
      await tester.pumpAndSettle();
      expect(find.text(etiqueta), findsOneWidget);
    });

    testWidgets('no se dibuja en ningún otro estado conocido', (tester) async {
      for (final status in const [
        CompanyVerificationStatus.pending,
        CompanyVerificationStatus.inReview,
        CompanyVerificationStatus.rejected,
      ]) {
        await tester.pumpWidget(montar(status));
        await tester.pumpAndSettle();
        expect(
          find.text(etiqueta),
          findsNothing,
          reason: 'no debería aparecer con ${status.wireName}',
        );
      }
    });

    testWidgets('no se dibuja con null (estado ausente o desconocido)', (
      tester,
    ) async {
      // `CompanyVerificationStatus.fromWire` devuelve null tanto cuando el
      // servidor no mandó nada como cuando mandó un estado que esta versión no
      // conoce: los dos casos tienen que verse igual, sin insignia.
      await tester.pumpWidget(montar(null));
      await tester.pumpAndSettle();
      expect(find.text(etiqueta), findsNothing);
      expect(find.byType(Chip), findsNothing);
    });

    testWidgets('ocupa cero espacio cuando no corresponde', (tester) async {
      await tester.pumpWidget(montar(CompanyVerificationStatus.pending));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(VerifiedCompanyBadge)), Size.zero);
    });

    testWidgets('anuncia el significado completo, no el ícono', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(montar(CompanyVerificationStatus.approved));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(
          RegExp('Empresa verificada: verificamos su CUIT'),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('el modo compacto sigue mostrando la misma etiqueta', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: VerifiedCompanyBadge(
              status: CompanyVerificationStatus.approved,
              compact: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(etiqueta), findsOneWidget);
    });
  });

  group('integrado en la superficie de empresa (/empresa)', () {
    Future<void> entrarComoEmpresa(
      WidgetTester tester,
      CompanyVerificationStatus? status,
    ) async {
      final auth = FakeAuthRepository(
        initialStatus: const AuthStatusSignedOut(),
      );
      await pumpTalentFlashApp(
        tester,
        authRepository: auth,
        companyAccessRepository: FakeCompanyAccessRepository(status: status),
      );
      await tester.pumpAndSettle();
      auth.emitSignedIn(BusinessRole.company);
      await tester.pumpAndSettle();
    }

    testWidgets('una empresa aprobada ve el distintivo en su shell', (
      tester,
    ) async {
      await entrarComoEmpresa(tester, CompanyVerificationStatus.approved);
      expect(find.text(etiqueta), findsOneWidget);
    });

    testWidgets('una empresa pendiente NO lo ve', (tester) async {
      await entrarComoEmpresa(tester, CompanyVerificationStatus.pending);
      expect(find.text(etiqueta), findsNothing);
    });

    testWidgets('una empresa rechazada NO lo ve', (tester) async {
      await entrarComoEmpresa(tester, CompanyVerificationStatus.rejected);
      expect(find.text(etiqueta), findsNothing);
    });

    testWidgets('sin dato de estado NO lo ve', (tester) async {
      await entrarComoEmpresa(tester, null);
      expect(find.text(etiqueta), findsNothing);
    });

    testWidgets('si la consulta de estado falla, tampoco lo ve', (
      tester,
    ) async {
      // El caso que más importa: un error de red no puede degradar a
      // "verificada". El provider queda en error y el badge recibe null.
      final auth = FakeAuthRepository(
        initialStatus: const AuthStatusSignedOut(),
      );
      final access = FakeCompanyAccessRepository()
        ..nextFailure = Exception('sin red');
      await pumpTalentFlashApp(
        tester,
        authRepository: auth,
        companyAccessRepository: access,
      );
      await tester.pumpAndSettle();
      auth.emitSignedIn(BusinessRole.company);
      await tester.pumpAndSettle();

      expect(find.text(etiqueta), findsNothing);
    });
  });
}
