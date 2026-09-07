import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardas de arquitectura del Bloque B, verificadas sobre el código fuente.
///
/// Son reglas de `ARCHITECTURE.md` §2 y `SECURITY.md` §3 y §4 que conviene
/// romper en rojo, no en una revisión manual.
void main() {
  final libDirectory = Directory('lib');

  List<File> dartFiles(String relativePath) {
    final directory = Directory('lib/$relativePath');
    if (!directory.existsSync()) {
      return <File>[];
    }
    return directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();
  }

  test('la app existe y se analiza desde lib/', () {
    expect(libDirectory.existsSync(), isTrue);
  });

  test('ninguna pantalla habla directamente con el SDK de Supabase', () {
    final offenders = <String>[];
    for (final file in dartFiles('features')) {
      if (!file.path.contains('presentation')) {
        continue;
      }
      final source = file.readAsStringSync();
      if (source.contains('package:supabase_flutter/') ||
          source.contains('Supabase.instance')) {
        offenders.add(file.path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Las pantallas deben pasar por el repositorio de la feature '
          '(ARCHITECTURE.md §2), nunca por el SDK.',
    );
  });

  test('solo la capa de datos y el provider del cliente importan el SDK', () {
    final importers = <String>[];
    for (final file in dartFiles('')) {
      final source = file.readAsStringSync();
      if (source.contains('package:supabase_flutter/')) {
        importers.add(file.path.replaceAll(r'\', '/'));
      }
    }
    importers.sort();
    expect(importers, <String>[
      'lib/bootstrap.dart',
      'lib/core/networking/supabase_client_provider.dart',
      'lib/features/authentication/data/supabase_auth_repository.dart',
      'lib/features/authentication/domain/auth_failure.dart',
      'lib/features/companies/data/supabase_company_access_repository.dart',
      'lib/features/companies/data/supabase_company_verification_repository.dart',
      'lib/features/consents/data/supabase_consents_repository.dart',
      'lib/features/legal/data/supabase_legal_repository.dart',
      'lib/features/notifications/data/supabase_notification_prefs_repository.dart',
      'lib/features/onboarding/data/supabase_catalog_repository.dart',
      'lib/features/onboarding/data/supabase_onboarding_repository.dart',
      'lib/features/profiles/data/supabase_profile_repository.dart',
      'lib/shared/models/data_failure.dart',
    ]);
  });

  test('no hay credenciales privadas en el código de la app', () {
    // Se ignoran los comentarios: nombrar `service_role` para explicar que
    // nunca entra al cliente es correcto; usarlo como dato, no.
    String withoutComments(String source) => source
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');

    final offenders = <String>[];
    for (final file in dartFiles('')) {
      final code = withoutComments(file.readAsStringSync());
      final hasSecret =
          code.contains('service_role') ||
          code.contains('sb_secret_') ||
          code.contains('SUPABASE_SERVICE_ROLE') ||
          RegExp(r'eyJ[A-Za-z0-9_-]{10,}').hasMatch(code);
      if (hasSecret) {
        offenders.add(file.path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'SECURITY.md §4: cero secretos en el cliente.',
    );
  });

  test('ai_training no existe en el código de la app (SPEC §6)', () {
    // El MVP no solicita el consentimiento de entrenamiento: no debe existir
    // ninguna superficie capaz de otorgarlo. Los comentarios que explican la
    // regla no cuentan; el dato sí.
    String withoutComments(String source) => source
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');

    final offenders = <String>[
      for (final file in dartFiles(''))
        if (withoutComments(file.readAsStringSync()).contains('ai_training'))
          file.path,
    ];
    expect(
      offenders,
      isEmpty,
      reason: 'ai_training jamás se solicita ni aparece como dato en la app.',
    );
  });

  test('el registro público no puede pedir el rol admin', () {
    final source = File('lib/features/authentication/data/auth_repository.dart')
        .readAsStringSync();
    // El enum de alta solo declara candidate y company; `admin` aparece
    // únicamente en el catálogo de roles de negocio.
    expect(source.contains('SignUpRole'), isTrue);
    expect(RegExp(r'admin\(BusinessRole\.admin\)').hasMatch(source), isFalse);

    for (final file in dartFiles('features/authentication/presentation')) {
      final screenSource = file.readAsStringSync();
      expect(
        screenSource.contains("'admin'"),
        isFalse,
        reason: '${file.path} no debería nombrar el rol admin como dato',
      );
    }
  });
}
