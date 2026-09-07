import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/companies/data/company_access_repository.dart';
import 'package:talentflash_argentina/features/companies/domain/company_verification.dart';

void main() {
  group('ConstanciaFormat.fromFileName', () {
    test('reconoce las extensiones que acepta el bucket', () {
      expect(
        ConstanciaFormat.fromFileName('constancia.pdf'),
        ConstanciaFormat.pdf,
      );
      expect(ConstanciaFormat.fromFileName('foto.PNG'), ConstanciaFormat.png);
      expect(ConstanciaFormat.fromFileName('foto.webp'), ConstanciaFormat.webp);
    });

    test('jpeg y jpg colapsan al mismo valor, igual que en SQL', () {
      expect(ConstanciaFormat.fromFileName('a.jpeg'), ConstanciaFormat.jpg);
      expect(ConstanciaFormat.fromFileName('a.JPG'), ConstanciaFormat.jpg);
      expect(ConstanciaFormat.jpg.wireName, 'jpg');
    });

    test('rechaza lo que el servidor rechazaría', () {
      expect(ConstanciaFormat.fromFileName('script.exe'), isNull);
      expect(ConstanciaFormat.fromFileName('sin-extension'), isNull);
      expect(ConstanciaFormat.fromFileName('termina-en-punto.'), isNull);
      expect(ConstanciaFormat.fromFileName(''), isNull);
    });

    test('cada formato declara el content-type que admite el bucket', () {
      expect(ConstanciaFormat.pdf.contentType, 'application/pdf');
      expect(ConstanciaFormat.jpg.contentType, 'image/jpeg');
      expect(ConstanciaFormat.png.contentType, 'image/png');
      expect(ConstanciaFormat.webp.contentType, 'image/webp');
    });
  });

  group('PickedConstancia', () {
    test('el límite local es el mismo que declara el bucket (5 MiB)', () {
      expect(constanciaMaxBytes, 5 * 1024 * 1024);
      final justo = PickedConstancia(
        bytes: Uint8List(constanciaMaxBytes),
        fileName: 'c.pdf',
      );
      final pasado = PickedConstancia(
        bytes: Uint8List(constanciaMaxBytes + 1),
        fileName: 'c.pdf',
      );
      expect(justo.isTooLarge, isFalse);
      expect(pasado.isTooLarge, isTrue);
    });
  });

  group('VerificationRejectionReason.fromWire', () {
    test('mapea los seis motivos de la lista cerrada de 0028', () {
      const esperados = <String, VerificationRejectionReason>{
        'cuit_no_coincide': VerificationRejectionReason.cuitNoCoincide,
        'constancia_ilegible': VerificationRejectionReason.constanciaIlegible,
        'constancia_vencida': VerificationRejectionReason.constanciaVencida,
        'datos_incompletos': VerificationRejectionReason.datosIncompletos,
        'empresa_no_operativa': VerificationRejectionReason.empresaNoOperativa,
        'otro': VerificationRejectionReason.otro,
      };
      for (final entry in esperados.entries) {
        expect(
          VerificationRejectionReason.fromWire(entry.key),
          entry.value,
          reason: 'el motivo ${entry.key} tiene que mapear',
        );
      }
      // La lista del cliente no puede tener valores que el servidor no acepte.
      expect(
        VerificationRejectionReason.values.length,
        esperados.length,
        reason: 'si se agrega un motivo acá, hay que agregarlo también en 0028',
      );
    });

    test('un motivo desconocido no se inventa', () {
      expect(VerificationRejectionReason.fromWire('porque_si'), isNull);
      expect(VerificationRejectionReason.fromWire(null), isNull);
      expect(VerificationRejectionReason.fromWire(42), isNull);
    });
  });

  group('CompanyVerification.fromJson', () {
    Map<String, dynamic> fila({
      String companyStatus = 'pending',
      String? requestStatus = 'pending',
      String? reason,
    }) {
      return <String, dynamic>{
        'company_id': 'c-1',
        'company_status': companyStatus,
        'request_id': 'req-1',
        'request_status': requestStatus,
        'cuit_submitted': '30-70000001-6',
        'document_path': 'c-1/constancia-arca.pdf',
        'rejection_reason': reason,
        'submitted_at': '2026-09-01T10:00:00Z',
        'reviewed_at': null,
      };
    }

    test('parsea la fila que devuelve my_company_verification', () {
      final v = CompanyVerification.fromJson(fila());
      expect(v.companyId, 'c-1');
      expect(v.companyStatus, CompanyVerificationStatus.pending);
      expect(v.requestStatus, CompanyVerificationStatus.pending);
      expect(v.documentPath, 'c-1/constancia-arca.pdf');
      expect(v.submittedAt, DateTime.utc(2026, 9, 1, 10));
      expect(v.reviewedAt, isNull);
    });

    test('un estado desconocido queda en null, nunca en approved', () {
      final v = CompanyVerification.fromJson(
        fila(companyStatus: 'un_estado_futuro', requestStatus: null),
      );
      expect(v.companyStatus, isNull);
      expect(
        v.companyStatus,
        isNot(CompanyVerificationStatus.approved),
        reason: 'un estado que el cliente no conoce jamás cuenta como aprobado',
      );
      // Sin solicitud abierta y sin estado conocido, la salida honesta es
      // dejar pedir la verificación: nunca dar por buena una empresa.
      expect(v.canSubmit, isTrue);
    });

    test('un estado desconocido CON solicitud abierta no deja reenviar', () {
      final v = CompanyVerification.fromJson(
        fila(companyStatus: 'un_estado_futuro'),
      );
      expect(v.companyStatus, isNull);
      expect(v.hasOpenRequest, isTrue);
      expect(v.canSubmit, isFalse);
    });

    test('una empresa sin solicitud todavía no rompe el parseo', () {
      final v = CompanyVerification.fromJson(<String, dynamic>{
        'company_id': 'c-1',
        'company_status': 'pending',
        'request_id': null,
        'request_status': null,
        'cuit_submitted': null,
        'document_path': null,
        'rejection_reason': null,
        'submitted_at': null,
        'reviewed_at': null,
      });
      expect(v.requestId, isNull);
      expect(v.hasOpenRequest, isFalse);
      expect(v.canSubmit, isTrue);
    });

    test('con una solicitud abierta no se puede reenviar', () {
      for (final abierta in ['pending', 'in_review']) {
        final v = CompanyVerification.fromJson(fila(requestStatus: abierta));
        expect(v.hasOpenRequest, isTrue, reason: abierta);
        expect(v.canSubmit, isFalse, reason: abierta);
      }
    });

    test('una empresa aprobada no vuelve a pedir la verificación', () {
      final v = CompanyVerification.fromJson(
        fila(companyStatus: 'approved', requestStatus: 'approved'),
      );
      expect(v.canSubmit, isFalse);
      expect(v.hasOpenRequest, isFalse);
    });

    test(
      'tras un rechazo se puede volver a enviar, con el motivo a la vista',
      () {
        final v = CompanyVerification.fromJson(
          fila(
            companyStatus: 'rejected',
            requestStatus: 'rejected',
            reason: 'constancia_ilegible',
          ),
        );
        expect(v.canSubmit, isTrue);
        expect(
          v.rejectionReason,
          VerificationRejectionReason.constanciaIlegible,
        );
      },
    );
  });

  group('CompanyVerificationRequest.fromJson', () {
    test('parsea una fila de la cola administrativa', () {
      final r = CompanyVerificationRequest.fromJson(<String, dynamic>{
        'request_id': 'req-1',
        'company_id': 'c-1',
        'company_name': 'Parrilla Don Julio Dev',
        'company_status': 'pending',
        'request_status': 'pending',
        'cuit_submitted': '30-70000001-6',
        'document_path': 'c-1/constancia-arca.pdf',
        'rejection_reason': null,
        'submitted_at': '2026-09-01T10:00:00Z',
        'reviewed_at': null,
      });
      expect(r.companyName, 'Parrilla Don Julio Dev');
      expect(r.requestStatus, CompanyVerificationStatus.pending);
      expect(r.documentPath, isNotNull);
    });

    test('una fila incompleta no revienta la lista entera', () {
      final r = CompanyVerificationRequest.fromJson(<String, dynamic>{});
      expect(r.requestId, '');
      expect(r.companyName, '');
      expect(r.requestStatus, isNull);
      expect(r.documentPath, isNull);
    });
  });
}
