/// Disponibilidad horaria estructurada (T-021): franjas por día con soporte
/// de turnos que terminan después de la medianoche. Espejo exacto de las
/// reglas server-side de `private.validate_candidate_content` (0023).
library;

/// Día de la semana con el mismo formato de cable que `jobs.schedule_days`.
enum WeekDay {
  lun('lun'),
  mar('mar'),
  mie('mie'),
  jue('jue'),
  vie('vie'),
  sab('sab'),
  dom('dom');

  const WeekDay(this.wireName);

  final String wireName;

  static WeekDay? fromWire(Object? raw) {
    for (final value in WeekDay.values) {
      if (value.wireName == raw) {
        return value;
      }
    }
    return null;
  }
}

/// Una franja horaria: `end < start` significa que el turno cruza la
/// medianoche y termina el día siguiente (p. ej. vie 22:00–02:00).
class AvailabilitySlot {
  const AvailabilitySlot({
    required this.day,
    required this.startMinutes,
    required this.endMinutes,
  });

  final WeekDay day;

  /// Minutos desde las 00:00 (0..1439).
  final int startMinutes;
  final int endMinutes;

  bool get crossesMidnight => endMinutes < startMinutes;

  int get durationMinutes => ((endMinutes - startMinutes) % 1440 + 1440) % 1440;

  String get startLabel => _formatTime(startMinutes);
  String get endLabel => _formatTime(endMinutes);

  static String _formatTime(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  static int? parseTime(Object? raw) {
    if (raw is! String ||
        !RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9]$').hasMatch(raw)) {
      return null;
    }
    return int.parse(raw.substring(0, 2)) * 60 + int.parse(raw.substring(3, 5));
  }

  static AvailabilitySlot? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final day = WeekDay.fromWire(raw['day']);
    final start = parseTime(raw['start']);
    final end = parseTime(raw['end']);
    if (day == null || start == null || end == null) {
      return null;
    }
    return AvailabilitySlot(day: day, startMinutes: start, endMinutes: end);
  }

  static List<AvailabilitySlot> listFromJson(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    final slots = <AvailabilitySlot>[];
    for (final entry in raw) {
      final slot = fromJson(entry);
      if (slot != null) {
        slots.add(slot);
      }
    }
    return slots;
  }

  Map<String, Object?> toJson() => {
    'day': day.wireName,
    'start': startLabel,
    'end': endLabel,
  };

  @override
  bool operator ==(Object other) =>
      other is AvailabilitySlot &&
      other.day == day &&
      other.startMinutes == startMinutes &&
      other.endMinutes == endMinutes;

  @override
  int get hashCode =>
      Object.hash(AvailabilitySlot, day, startMinutes, endMinutes);
}

enum WeeklyAvailabilityIssue {
  tooManySlots,
  tooManySlotsPerDay,
  zeroLength,
  overlap,
}

/// Validación pura, espejo del servidor: hasta 21 franjas, hasta 3 por día,
/// inicio ≠ fin y sin solapamientos sobre la línea de tiempo circular de la
/// semana (un turno vie 22:00–02:00 también choca con sab 01:00–03:00).
abstract final class WeeklyAvailabilityValidator {
  static const maxSlots = 21;
  static const maxSlotsPerDay = 3;

  static WeeklyAvailabilityIssue? validate(List<AvailabilitySlot> slots) {
    if (slots.length > maxSlots) {
      return WeeklyAvailabilityIssue.tooManySlots;
    }
    final perDay = <WeekDay, int>{};
    for (final slot in slots) {
      if (slot.startMinutes == slot.endMinutes) {
        return WeeklyAvailabilityIssue.zeroLength;
      }
      perDay[slot.day] = (perDay[slot.day] ?? 0) + 1;
      if (perDay[slot.day]! > maxSlotsPerDay) {
        return WeeklyAvailabilityIssue.tooManySlotsPerDay;
      }
    }

    // Cada franja se proyecta a minutos absolutos de la semana (0..10080) y
    // la que envuelve el fin de semana (dom→lun) se parte en dos tramos.
    final starts = <int>[];
    final ends = <int>[];
    for (final slot in slots) {
      final absStart = slot.day.index * 1440 + slot.startMinutes;
      final absEnd = absStart + slot.durationMinutes;
      if (absEnd <= 10080) {
        starts.add(absStart);
        ends.add(absEnd);
      } else {
        starts.add(absStart);
        ends.add(10080);
        starts.add(0);
        ends.add(absEnd - 10080);
      }
    }
    for (var i = 0; i < starts.length; i++) {
      for (var j = i + 1; j < starts.length; j++) {
        if (starts[i] < ends[j] && starts[j] < ends[i]) {
          return WeeklyAvailabilityIssue.overlap;
        }
      }
    }
    return null;
  }
}
