import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/consents/domain/consent_snapshot.dart';
import 'package:talentflash_argentina/features/consents/domain/consent_type.dart';

import '../../../support/fake_onboarding_repositories.dart';

void main() {
  group('estado vigente del ledger', () {
    test('sin decisiones, todos los obligatorios están pendientes', () {
      final snapshot = ConsentSnapshot(
        requirements: defaultConsentRequirements(),
        latestByType: const {},
      );
      expect(snapshot.pendingMandatory.map((r) => r.type), [
        ConsentType.termsAcceptance,
        ConsentType.ageDeclaration,
        ConsentType.dataProcessing,
      ]);
      expect(
        snapshot.isCurrentlyGranted(ConsentType.videoProfilePublication),
        isFalse,
      );
    });

    test('otorgado en la versión vigente cuenta como vigente', () {
      final snapshot = ConsentSnapshot(
        requirements: defaultConsentRequirements(),
        latestByType: const {
          ConsentType.dataProcessing: ConsentDecision(
            type: ConsentType.dataProcessing,
            granted: true,
            version: testConsentVersion,
          ),
        },
      );
      expect(snapshot.isCurrentlyGranted(ConsentType.dataProcessing), isTrue);
      expect(snapshot.pendingMandatory.map((r) => r.type), [
        ConsentType.termsAcceptance,
        ConsentType.ageDeclaration,
      ]);
    });

    test('una versión vieja exige reconsentimiento (T-018)', () {
      final snapshot = ConsentSnapshot(
        requirements: defaultConsentRequirements(),
        latestByType: const {
          ConsentType.dataProcessing: ConsentDecision(
            type: ConsentType.dataProcessing,
            granted: true,
            version: '2020-01-01',
          ),
        },
      );
      expect(snapshot.isCurrentlyGranted(ConsentType.dataProcessing), isFalse);
      expect(
        snapshot.pendingMandatory.map((r) => r.type),
        contains(ConsentType.dataProcessing),
      );
    });

    test('la última decisión manda: revocado no está vigente', () {
      final snapshot = ConsentSnapshot(
        requirements: defaultConsentRequirements(),
        latestByType: const {
          ConsentType.videoProfilePublication: ConsentDecision(
            type: ConsentType.videoProfilePublication,
            granted: false,
            version: testConsentVersion,
          ),
        },
      );
      expect(
        snapshot.isCurrentlyGranted(ConsentType.videoProfilePublication),
        isFalse,
      );
      // Es opcional: revocarlo no genera pendientes obligatorios.
      expect(
        snapshot.pendingMandatory.map((r) => r.type),
        isNot(contains(ConsentType.videoProfilePublication)),
      );
    });
  });

  group('mapeo del enum de la base', () {
    test('correspondencia exacta o null (fail-closed)', () {
      expect(
        ConsentType.fromWire('data_processing'),
        ConsentType.dataProcessing,
      );
      expect(
        ConsentType.fromWire('terms_acceptance'),
        ConsentType.termsAcceptance,
      );
      expect(ConsentType.fromWire('DATA_PROCESSING'), isNull);
      expect(ConsentType.fromWire(' data_processing'), isNull);
      expect(ConsentType.fromWire(null), isNull);
    });

    test('el tipo de entrenamiento de IA no existe en la app', () {
      // SPEC §6: el MVP no lo solicita; que no haya ni forma de nombrarlo.
      expect(
        ConsentType.fromWire(
          'ai'
          '_training',
        ),
        isNull,
      );
      expect(
        ConsentType.values.map((t) => t.wireName),
        isNot(
          contains(
            'ai'
            '_training',
          ),
        ),
      );
    });
  });
}
