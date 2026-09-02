import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/profiles/domain/weekly_availability.dart';

/// Franja de utilería armada desde horarios legibles.
AvailabilitySlot slot(WeekDay day, String start, String end) {
  return AvailabilitySlot(
    day: day,
    startMinutes: AvailabilitySlot.parseTime(start)!,
    endMinutes: AvailabilitySlot.parseTime(end)!,
  );
}

void main() {
  group('AvailabilitySlot.parseTime', () {
    test('HH:MM válido se convierte a minutos desde las 00:00', () {
      expect(AvailabilitySlot.parseTime('18:30'), 1110);
      expect(AvailabilitySlot.parseTime('00:00'), 0);
      expect(AvailabilitySlot.parseTime('23:59'), 1439);
    });

    test('formatos inválidos devuelven null', () {
      expect(AvailabilitySlot.parseTime('24:00'), isNull);
      expect(AvailabilitySlot.parseTime('9:00'), isNull, reason: 'exige HH');
      expect(AvailabilitySlot.parseTime('basura'), isNull);
      expect(AvailabilitySlot.parseTime(''), isNull);
      expect(AvailabilitySlot.parseTime(1830), isNull);
      expect(AvailabilitySlot.parseTime(null), isNull);
    });
  });

  group('AvailabilitySlot.fromJson / listFromJson', () {
    test('una entrada bien formada parsea día y horarios', () {
      final parsed = AvailabilitySlot.fromJson(<String, dynamic>{
        'day': 'vie',
        'start': '22:00',
        'end': '02:00',
      });
      expect(parsed, slot(WeekDay.vie, '22:00', '02:00'));
    });

    test('las entradas malformadas se ignoran sin romper (fail-safe)', () {
      expect(AvailabilitySlot.fromJson('no soy un mapa'), isNull);
      expect(
        AvailabilitySlot.fromJson(<String, dynamic>{
          'day': 'viernes',
          'start': '10:00',
          'end': '12:00',
        }),
        isNull,
        reason: 'día fuera del catálogo',
      );
      final slots = AvailabilitySlot.listFromJson(<dynamic>[
        <String, dynamic>{'day': 'lun', 'start': '09:00', 'end': '12:00'},
        <String, dynamic>{'day': 'lun', 'start': '24:00', 'end': '12:00'},
        <String, dynamic>{'day': 'lun', 'end': '12:00'},
        'basura',
        42,
        null,
      ]);
      expect(slots, [slot(WeekDay.lun, '09:00', '12:00')]);
      expect(AvailabilitySlot.listFromJson('nada'), isEmpty);
    });
  });

  group('cruce de medianoche y duración', () {
    test('22:00–02:00 cruza la medianoche y dura 240 minutos', () {
      final nocturna = slot(WeekDay.vie, '22:00', '02:00');
      expect(nocturna.crossesMidnight, isTrue);
      expect(nocturna.durationMinutes, 240);
      expect(nocturna.startLabel, '22:00');
      expect(nocturna.endLabel, '02:00');
    });

    test('una franja diurna no cruza y su duración es directa', () {
      final diurna = slot(WeekDay.mar, '09:00', '17:00');
      expect(diurna.crossesMidnight, isFalse);
      expect(diurna.durationMinutes, 480);
    });
  });

  group('WeeklyAvailabilityValidator.validate', () {
    test('lista vacía es válida (sin disponibilidad declarada)', () {
      expect(WeeklyAvailabilityValidator.validate(const []), isNull);
    });

    test('más de 21 franjas se rechaza en bloque', () {
      final demasiadas = List<AvailabilitySlot>.generate(
        22,
        (i) => AvailabilitySlot(
          day: WeekDay.values[i % 7],
          startMinutes: (i ~/ 7) * 120,
          endMinutes: (i ~/ 7) * 120 + 60,
        ),
      );
      expect(
        WeeklyAvailabilityValidator.validate(demasiadas),
        WeeklyAvailabilityIssue.tooManySlots,
      );
    });

    test('cuarta franja del mismo día se rechaza', () {
      final cuatroElMismoDia = [
        slot(WeekDay.jue, '08:00', '09:00'),
        slot(WeekDay.jue, '10:00', '11:00'),
        slot(WeekDay.jue, '12:00', '13:00'),
        slot(WeekDay.jue, '14:00', '15:00'),
      ];
      expect(
        WeeklyAvailabilityValidator.validate(cuatroElMismoDia),
        WeeklyAvailabilityIssue.tooManySlotsPerDay,
      );
    });

    test('inicio igual a fin es una franja de largo cero', () {
      expect(
        WeeklyAvailabilityValidator.validate([
          slot(WeekDay.lun, '10:00', '10:00'),
        ]),
        WeeklyAvailabilityIssue.zeroLength,
      );
    });

    test('dos franjas del mismo día que se pisan chocan; contiguas no', () {
      expect(
        WeeklyAvailabilityValidator.validate([
          slot(WeekDay.lun, '09:00', '12:00'),
          slot(WeekDay.lun, '11:00', '13:00'),
        ]),
        WeeklyAvailabilityIssue.overlap,
      );
      expect(
        WeeklyAvailabilityValidator.validate([
          slot(WeekDay.lun, '09:00', '12:00'),
          slot(WeekDay.lun, '12:00', '14:00'),
        ]),
        isNull,
        reason: 'tocarse en el borde no es solaparse',
      );
    });

    test('vie 22:00–02:00 choca con sab 01:00–03:00 (cruce de medianoche)', () {
      expect(
        WeeklyAvailabilityValidator.validate([
          slot(WeekDay.vie, '22:00', '02:00'),
          slot(WeekDay.sab, '01:00', '03:00'),
        ]),
        WeeklyAvailabilityIssue.overlap,
      );
    });

    test('vie 22:00–02:00 convive con sab 10:00–14:00', () {
      expect(
        WeeklyAvailabilityValidator.validate([
          slot(WeekDay.vie, '22:00', '02:00'),
          slot(WeekDay.sab, '10:00', '14:00'),
        ]),
        isNull,
      );
    });

    test('dom 23:00–01:00 envuelve el fin de semana y choca con el lunes', () {
      expect(
        WeeklyAvailabilityValidator.validate([
          slot(WeekDay.dom, '23:00', '01:00'),
          slot(WeekDay.lun, '00:30', '02:00'),
        ]),
        WeeklyAvailabilityIssue.overlap,
      );
    });

    test('el resultado no depende del orden de la lista', () {
      final chocan = [
        slot(WeekDay.vie, '22:00', '02:00'),
        slot(WeekDay.sab, '01:00', '03:00'),
      ];
      expect(
        WeeklyAvailabilityValidator.validate(chocan.reversed.toList()),
        WeeklyAvailabilityValidator.validate(chocan),
      );

      final conviven = [
        slot(WeekDay.vie, '22:00', '02:00'),
        slot(WeekDay.sab, '10:00', '14:00'),
        slot(WeekDay.lun, '09:00', '12:00'),
      ];
      expect(
        WeeklyAvailabilityValidator.validate(conviven.reversed.toList()),
        WeeklyAvailabilityValidator.validate(conviven),
      );
      expect(WeeklyAvailabilityValidator.validate(conviven), isNull);
    });
  });
}
