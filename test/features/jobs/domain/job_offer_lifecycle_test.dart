import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer_enums.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer_lifecycle.dart';

/// Espejo de `private.protect_job_lifecycle` (0032). Si la matriz del
/// servidor cambia, este test tiene que cambiar con ella: la UI no puede
/// ofrecer un botón que el servidor siempre rechaza.
void main() {
  group('transiciones que puede pedir el cliente', () {
    // Pares (desde, hasta) permitidos. Todo lo que no está acá es TFJOB o
    // 42501 en el servidor.
    const permitidas = {
      (JobStatus.draft, JobStatus.draft),
      (JobStatus.active, JobStatus.active),
      (JobStatus.paused, JobStatus.paused),
      (JobStatus.draft, JobStatus.active),
      (JobStatus.active, JobStatus.paused),
      (JobStatus.paused, JobStatus.active),
      (JobStatus.active, JobStatus.closed),
      (JobStatus.paused, JobStatus.closed),
      (JobStatus.expired, JobStatus.closed),
    };

    test('la matriz completa 5x5 coincide con la del servidor', () {
      for (final from in JobStatus.values) {
        for (final to in JobStatus.values) {
          expect(
            JobOfferLifecycle.canTransition(from, to),
            permitidas.contains((from, to)),
            reason: '${from.wireName} → ${to.wireName}',
          );
        }
      }
    });

    test('nadie del lado del cliente pasa una oferta a expired', () {
      for (final from in JobStatus.values) {
        expect(
          JobOfferLifecycle.canTransition(from, JobStatus.expired),
          isFalse,
          reason: from.wireName,
        );
      }
    });

    test('vencida o cerrada no se editan ni vuelven a activa', () {
      for (final from in [JobStatus.expired, JobStatus.closed]) {
        expect(JobOfferLifecycle.canTransition(from, from), isFalse);
        expect(
          JobOfferLifecycle.canTransition(from, JobStatus.active),
          isFalse,
        );
      }
    });

    test('solo se crea como borrador o activa', () {
      expect(JobOfferLifecycle.insertableStatuses, {
        JobStatus.draft,
        JobStatus.active,
      });
    });
  });

  group('acciones por estado', () {
    test('borrador: editar, publicar, descartar, duplicar', () {
      expect(JobOfferLifecycle.actionsFor(JobStatus.draft), {
        JobOfferAction.edit,
        JobOfferAction.publish,
        JobOfferAction.discard,
        JobOfferAction.duplicate,
      });
    });

    test('activa: editar, pausar, cerrar, duplicar', () {
      expect(JobOfferLifecycle.actionsFor(JobStatus.active), {
        JobOfferAction.edit,
        JobOfferAction.pause,
        JobOfferAction.close,
        JobOfferAction.duplicate,
      });
    });

    test('pausada: editar, reanudar, cerrar, duplicar', () {
      expect(JobOfferLifecycle.actionsFor(JobStatus.paused), {
        JobOfferAction.edit,
        JobOfferAction.resume,
        JobOfferAction.close,
        JobOfferAction.duplicate,
      });
    });

    test('vencida: cerrar o duplicar', () {
      expect(JobOfferLifecycle.actionsFor(JobStatus.expired), {
        JobOfferAction.close,
        JobOfferAction.duplicate,
      });
    });

    test('cerrada: solo duplicar', () {
      expect(JobOfferLifecycle.actionsFor(JobStatus.closed), {
        JobOfferAction.duplicate,
      });
    });

    test('un estado desconocido no habilita nada (fail-closed)', () {
      expect(JobOfferLifecycle.actionsFor(null), isEmpty);
      expect(JobOfferLifecycle.allows(null, JobOfferAction.duplicate), isFalse);
    });

    test('cada acción ofrecida es una transición que el servidor acepta', () {
      for (final status in JobStatus.values) {
        for (final action in JobOfferLifecycle.actionsFor(status)) {
          final target = switch (action) {
            JobOfferAction.edit => status,
            _ => action.targetStatus,
          };
          if (target == null) {
            continue;
          }
          expect(
            JobOfferLifecycle.canTransition(status, target),
            isTrue,
            reason: '${status.wireName} + ${action.name}',
          );
        }
      }
    });

    test('descartar solo existe para borradores', () {
      for (final status in JobStatus.values) {
        expect(
          JobOfferLifecycle.allows(status, JobOfferAction.discard),
          status == JobStatus.draft,
          reason: status.wireName,
        );
      }
    });
  });

  group('JobOfferAction', () {
    test('estado de destino de cada acción', () {
      expect(JobOfferAction.publish.targetStatus, JobStatus.active);
      expect(JobOfferAction.resume.targetStatus, JobStatus.active);
      expect(JobOfferAction.pause.targetStatus, JobStatus.paused);
      expect(JobOfferAction.close.targetStatus, JobStatus.closed);
      expect(JobOfferAction.edit.targetStatus, isNull);
      expect(JobOfferAction.discard.targetStatus, isNull);
      expect(JobOfferAction.duplicate.targetStatus, isNull);
    });

    test('solo entrar a activa exige la empresa verificada', () {
      expect(
        {
          for (final action in JobOfferAction.values)
            if (action.requiresApprovedCompany) action,
        },
        {JobOfferAction.publish, JobOfferAction.resume},
      );
    });
  });
}
