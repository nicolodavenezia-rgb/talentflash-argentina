import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/core/routing/app_entry_point.dart';
import 'package:talentflash_argentina/core/routing/app_routes.dart';
import 'package:talentflash_argentina/core/routing/auth_redirect.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_status.dart';
import 'package:talentflash_argentina/features/authentication/domain/authenticated_user.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';

AuthStatus signedInAs(BusinessRole role) => AuthStatusSignedIn(
  AuthenticatedUser(
    id: 'user-1',
    email: 'persona@dev.talentflash.test',
    role: role,
  ),
);

String? redirect(
  AuthStatus status,
  String location, {
  AppEntryPoint entryPoint = AppEntryPoint.chooser,
}) => resolveAuthRedirect(
  status: status,
  entryPoint: entryPoint,
  location: Uri.parse(location),
);

void main() {
  group('sesión todavía sin resolver', () {
    test('cualquier ruta va a la pantalla de carga', () {
      expect(
        redirect(const AuthStatusUnknown(), '/candidato'),
        '/inicio?destino=%2Fcandidato',
      );
      expect(
        redirect(const AuthStatusUnknown(), '/empresa'),
        '/inicio?destino=%2Fempresa',
      );
    });

    test('el landing no se guarda como destino: es el default igual', () {
      expect(redirect(const AuthStatusUnknown(), '/'), '/inicio');
    });

    test('recuerda el destino pretendido, también el de una ruta pública', () {
      expect(
        redirect(const AuthStatusUnknown(), '/auth/registro/empresa'),
        '/inicio?destino=%2Fauth%2Fregistro%2Fempresa',
      );
    });

    test('la propia pantalla de carga se queda quieta (sin bucle)', () {
      expect(redirect(const AuthStatusUnknown(), '/inicio'), isNull);
      expect(
        redirect(const AuthStatusUnknown(), '/inicio?destino=%2Fempresa'),
        isNull,
      );
    });
  });

  group('sin sesión', () {
    test('las rutas públicas se muestran tal cual', () {
      for (final path in <String>[
        '/',
        '/auth/login',
        '/auth/registro',
        '/auth/registro/candidato',
        '/auth/registro/empresa',
        '/auth/recuperar',
      ]) {
        expect(
          redirect(const AuthStatusSignedOut(), path),
          isNull,
          reason: '$path debería ser pública',
        );
      }
    });

    test('una ruta privada manda al login guardando el destino', () {
      expect(
        redirect(const AuthStatusSignedOut(), '/candidato'),
        '/auth/login?destino=%2Fcandidato',
      );
      expect(
        redirect(const AuthStatusSignedOut(), '/empresa'),
        '/auth/login?destino=%2Fempresa',
      );
      expect(
        redirect(const AuthStatusSignedOut(), '/admin'),
        '/auth/login?destino=%2Fadmin',
      );
    });

    test('el binario general muestra la bienvenida', () {
      expect(redirect(const AuthStatusSignedOut(), '/inicio'), '/');
    });

    test('los binarios de candidato y empresa abren su login', () {
      expect(
        redirect(
          const AuthStatusSignedOut(),
          '/inicio',
          entryPoint: AppEntryPoint.candidate,
        ),
        '/auth/login?rol=candidato',
      );
      expect(
        redirect(
          const AuthStatusSignedOut(),
          '/inicio',
          entryPoint: AppEntryPoint.company,
        ),
        '/auth/login?rol=empresa',
      );
    });

    test('el destino privado sobrevive al paso por la pantalla de carga', () {
      expect(
        redirect(
          const AuthStatusSignedOut(),
          '/inicio?destino=%2Fcandidato',
          entryPoint: AppEntryPoint.candidate,
        ),
        '/auth/login?rol=candidato&destino=%2Fcandidato',
      );
    });

    test('un destino público se abre directamente', () {
      expect(
        redirect(
          const AuthStatusSignedOut(),
          '/inicio?destino=%2Fauth%2Frecuperar',
        ),
        '/auth/recuperar',
      );
    });

    test('salir de la pantalla de sesión inconsistente vuelve al arranque', () {
      expect(
        redirect(const AuthStatusSignedOut(), '/sesion-invalida?motivo=claim'),
        '/',
      );
    });
  });

  group('sesión con claim inconsistente', () {
    const inconsistent = AuthStatusInconsistent(
      userId: 'user-1',
      rawClaim: 'moderator',
    );

    test('todo va al estado seguro, sin elegir rol', () {
      for (final path in <String>[
        '/',
        '/inicio',
        '/auth/login',
        '/candidato',
        '/empresa',
        '/admin',
      ]) {
        expect(
          redirect(inconsistent, path),
          '/sesion-invalida?motivo=claim',
          reason: 'desde $path',
        );
      }
    });

    test('la pantalla de estado seguro no se redirige a sí misma', () {
      expect(redirect(inconsistent, '/sesion-invalida?motivo=claim'), isNull);
    });
  });

  group('sesión de candidato', () {
    final candidate = signedInAs(BusinessRole.candidate);

    test('se queda en su shell', () {
      expect(redirect(candidate, '/candidato'), isNull);
    });

    test('no entra al shell de empresa: vuelve al propio', () {
      expect(redirect(candidate, '/empresa'), '/candidato');
    });

    test('el intento de entrar al panel admin se responde explícito', () {
      expect(
        redirect(candidate, '/admin'),
        '/sesion-invalida?motivo=sin-permiso',
      );
    });

    test('no vuelve al login ni al registro estando autenticado', () {
      expect(redirect(candidate, '/auth/login'), '/candidato');
      expect(redirect(candidate, '/auth/registro/candidato'), '/candidato');
      expect(redirect(candidate, '/auth/recuperar'), '/candidato');
      expect(redirect(candidate, '/'), '/candidato');
      expect(redirect(candidate, '/inicio'), '/candidato');
    });

    test('respeta el destino pretendido si su rol lo permite', () {
      expect(
        redirect(candidate, '/auth/login?destino=%2Fcandidato'),
        '/candidato',
      );
    });

    test('ignora un destino de otro rol y va a su inicio', () {
      expect(
        redirect(candidate, '/auth/login?destino=%2Fempresa'),
        '/candidato',
      );
      expect(redirect(candidate, '/auth/login?destino=%2Fadmin'), '/candidato');
    });
  });

  group('sesión de empresa', () {
    final company = signedInAs(BusinessRole.company);

    test('se queda en su shell', () {
      expect(redirect(company, '/empresa'), isNull);
    });

    test('no entra al shell de candidato: vuelve al propio', () {
      expect(redirect(company, '/candidato'), '/empresa');
    });

    test('el destino guardado la lleva a su shell tras el login', () {
      expect(
        redirect(
          company,
          '/auth/login?rol=empresa&destino=%2Fempresa',
          entryPoint: AppEntryPoint.company,
        ),
        '/empresa',
      );
    });
  });

  group('sesión de administración', () {
    final admin = signedInAs(BusinessRole.admin);

    test('nunca se degrada a candidato ni a empresa', () {
      expect(redirect(admin, '/auth/login'), '/admin');
      expect(redirect(admin, '/inicio'), '/admin');
      expect(redirect(admin, '/'), '/admin');
      expect(redirect(admin, '/candidato'), '/admin');
      expect(redirect(admin, '/empresa'), '/admin');
    });

    test('entra a su propio panel', () {
      expect(redirect(admin, '/admin'), isNull);
    });

    test('un binario de candidato no lo degrada', () {
      expect(
        redirect(admin, '/candidato', entryPoint: AppEntryPoint.candidate),
        '/admin',
      );
    });
  });

  group('sanitizeDestination', () {
    test('acepta rutas internas', () {
      expect(sanitizeDestination('/candidato'), '/candidato');
      expect(
        sanitizeDestination('/empresa?filtro=activas'),
        '/empresa?filtro=activas',
      );
    });

    test('rechaza destinos externos (nada de redirección abierta)', () {
      for (final hostile in <String?>[
        null,
        '',
        'https://evil.example.com',
        '//evil.example.com',
        'javascript:alert(1)',
        'candidato',
      ]) {
        expect(
          sanitizeDestination(hostile),
          isNull,
          reason: 'debería rechazar "$hostile"',
        );
      }
    });

    test('descarta destinos que no aportan nada', () {
      expect(sanitizeDestination('/inicio'), isNull);
      expect(sanitizeDestination('/sesion-invalida?motivo=claim'), isNull);
      expect(sanitizeDestination('/'), isNull);
    });
  });

  group('catálogo de rutas', () {
    test('cada rol tiene un shell propio', () {
      expect(AppRoute.homeFor(BusinessRole.candidate), AppRoute.candidateHome);
      expect(AppRoute.homeFor(BusinessRole.company), AppRoute.companyHome);
      expect(AppRoute.homeFor(BusinessRole.admin), AppRoute.adminHome);
    });

    test('los paths siguen la nomenclatura de UX_FLOWS §1.1', () {
      expect(AppRoute.login.path, '/auth/login');
      expect(AppRoute.signupChooser.path, '/auth/registro');
      expect(AppRoute.passwordRecovery.path, '/auth/recuperar');
    });

    test('solo los tres shells exigen rol', () {
      final withRole = AppRoute.values
          .where((route) => route.requiredRole != null)
          .toList();
      expect(withRole, <AppRoute>[
        AppRoute.candidateHome,
        AppRoute.companyHome,
        AppRoute.adminHome,
      ]);
    });
  });
}
