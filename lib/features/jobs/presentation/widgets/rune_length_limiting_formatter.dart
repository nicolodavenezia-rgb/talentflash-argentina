import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tope de un campo de texto contado como lo cuenta el servidor.
///
/// El `maxLength` de [TextField] cuenta grafemas (lo que la persona ve como
/// un carácter), pero `length()` de Postgres —y `JobOfferValidation`, que lo
/// imita— cuenta code points (en Dart, `runes`). Con un emoji compuesto
/// (👨‍🍳 son 3 code points) el contador decía "115/120" mientras el campo
/// marcaba "admite hasta 120 caracteres". Este formatter y [runeCounter]
/// cuentan lo mismo que el validador, así el tope, el contador y el error
/// nunca se contradicen.
///
/// Lo que no entra se recorta de lo que se está escribiendo o pegando, nunca
/// del texto que ya estaba: una edición no puede borrar texto que la persona
/// no seleccionó. Se queda con los grafemas enteros que entran (no aparece
/// medio emoji) y deja el cursor después de lo que entró. Acá se aparta a
/// propósito de [LengthLimitingTextInputFormatter], que recorta siempre el
/// FINAL del texto: con el campo casi lleno, un emoji o un pegado en el medio
/// entraba y se perdía, sin aviso, el final de lo ya escrito.
///
/// Con el teclado componiendo una palabra (IME) sigue la política por
/// plataforma de [LengthLimitingTextInputFormatter], el que usa `maxLength`,
/// según [maxLengthEnforcement]:
/// - [MaxLengthEnforcement.enforced]: la composición no tiene excepción. Con
///   el campo lleno no entra nada (queda como estaba) y, si no, se recorta
///   aunque el teclado esté componiendo. Se recorta solo lo que cambió en
///   esta edición: Gboard deja compuesta la palabra donde está el cursor
///   aunque el cursor quede en el medio, y lo que sigue al cursor ya estaba.
/// - [MaxLengthEnforcement.truncateAfterCompositionEnds]: mientras compone se
///   deja pasar y se recorta cuando termina, solo de lo compuesto y de lo que
///   cambió al cerrar: primero lo último que se escribió (lo que el cierre
///   agrega después del cursor y lo compuesto justo antes del cursor) y, si
///   todavía se pasa, el resto de eso desde el final. Lo de afuera nunca, así
///   que si el valor de antes entraba en el tope, el de después también; con
///   el campo lleno, una composición nueva no entra.
/// - [MaxLengthEnforcement.none]: no limita.
class RuneLengthLimitingFormatter extends TextInputFormatter {
  const RuneLengthLimitingFormatter(this.maxRunes, {this.maxLengthEnforcement});

  final int maxRunes;

  /// Null = la de la plataforma, igual que `maxLength` en un [TextField]
  /// ([LengthLimitingTextInputFormatter.getDefaultMaxLengthEnforcement]: hoy
  /// `enforced` en Android y Windows, `truncateAfterCompositionEnds` en iOS,
  /// macOS, Linux y Web).
  final MaxLengthEnforcement? maxLengthEnforcement;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.runes.length <= maxRunes) {
      return newValue;
    }
    final atLimit = oldValue.text.runes.length == maxRunes;
    switch (maxLengthEnforcement ??
        LengthLimitingTextInputFormatter.getDefaultMaxLengthEnforcement()) {
      case MaxLengthEnforcement.none:
        return newValue;
      case MaxLengthEnforcement.enforced:
        // Ya estaba en el tope y se quiso escribir más: queda como estaba.
        if (atLimit && oldValue.selection.isCollapsed) {
          return oldValue;
        }
        return _keepWhatFits(oldValue, newValue, maxRunes);
      case MaxLengthEnforcement.truncateAfterCompositionEnds:
        // En el tope y sin composición en curso: queda como estaba.
        if (atLimit && !oldValue.composing.isValid) {
          return oldValue;
        }
        // Mientras el teclado compone no se corta la palabra a la mitad: se
        // recorta en la edición que cierra la composición.
        if (newValue.composing.isValid) {
          return newValue;
        }
        return _keepWhatFits(
          oldValue,
          newValue,
          maxRunes,
          closesComposition: true,
        );
    }
  }

  /// [newValue] sin pasarse de [maxRunes] code points, recortando por
  /// grafemas enteros solo lo que se acaba de escribir o pegar.
  ///
  /// Lo insertado es el tramo de [newValue] que difiere de [oldValue] (lo que
  /// sobra del prefijo y el sufijo comunes): se queda con sus primeros
  /// grafemas, los que entran. Con [closesComposition]
  /// (truncateAfterCompositionEnds) también se puede recortar lo que el
  /// teclado venía componiendo, que se dejó pasar mientras componía: al
  /// cerrar una composición que se pasó, el texto puede no cambiar y lo que
  /// hay que recortar es eso. Ahí el orden es: si el cierre agrega algo
  /// después del cursor, primero eso (lo que hay entre el cursor y lo
  /// agregado ya estaba); después lo compuesto justo antes del cursor, lo
  /// último que se escribió; y solo si todavía se pasa, lo que queda de lo
  /// compuesto y de lo insertado, desde el final. Lo que está fuera de lo
  /// compuesto y de lo insertado no se toca nunca: es texto de antes, así
  /// que si el valor de antes entraba en el tope, el resultado también. La
  /// selección y la composición se corren con el texto.
  static TextEditingValue _keepWhatFits(
    TextEditingValue oldValue,
    TextEditingValue newValue,
    int maxRunes, {
    bool closesComposition = false,
  }) {
    final before = oldValue.text;
    final after = newValue.text;
    final shorter = math.min(before.length, after.length);

    // Sufijo común. Con el cursor colapsado, lo insertado termina en el
    // cursor: el sufijo no empieza antes. Sin esto, con texto repetido
    // ("abcab" + "cab" pegado después de "ab") el tramo sería ambiguo y lo
    // recortado podría quedar en otro lugar que el pegado.
    final selection = newValue.selection;
    final caretLimit =
        selection.isValid &&
            selection.isCollapsed &&
            selection.baseOffset <= after.length
        ? after.length - selection.baseOffset
        : shorter;
    var suffix = 0;
    while (suffix < math.min(shorter, caretLimit) &&
        before.codeUnitAt(before.length - 1 - suffix) ==
            after.codeUnitAt(after.length - 1 - suffix)) {
      suffix++;
    }
    var prefix = 0;
    while (prefix < shorter - suffix &&
        before.codeUnitAt(prefix) == after.codeUnitAt(prefix)) {
      prefix++;
    }

    // Sin partir un par sustituto (un emoji es un solo code point de dos
    // unidades UTF-16): un borde que cae en el medio de uno lo abarca entero.
    bool splitsPair(int offset) =>
        offset > 0 &&
        offset < after.length &&
        _isLowSurrogate(after.codeUnitAt(offset)) &&
        _isHighSurrogate(after.codeUnitAt(offset - 1));
    int startAt(int offset) => splitsPair(offset) ? offset - 1 : offset;
    int endAt(int offset) => splitsPair(offset) ? offset + 1 : offset;

    // Tramo que cambió en [after]: [changeStart, changeEnd).
    final changeStart = startAt(prefix);
    final changeEnd = endAt(after.length - suffix);
    final changed = changeStart < changeEnd;

    // Lo compuesto [composedStart, composedEnd) y el cursor de antes
    // ([caretAt]), llevados a [after]. Null si no hay composición que
    // cerrar.
    final composing = oldValue.composing;
    final ({int composedStart, int composedEnd, int caretAt})? closing;
    if (closesComposition &&
        composing.isValid &&
        composing.isNormalized &&
        composing.end <= before.length) {
      // El cursor en lo compuesto: se escribe ahí, y lo compuesto que sigue
      // al cursor ya estaba (el teclado recompone la palabra en la que se
      // apoya el cursor). Si el cursor no está en lo compuesto, cuenta como
      // si estuviera al final.
      final oldSelection = oldValue.selection;
      final caret =
          oldSelection.isValid &&
              oldSelection.end >= composing.start &&
              oldSelection.end <= composing.end
          ? oldSelection.end
          : composing.end;
      // Del texto de antes al de ahora: lo que estaba antes del tramo que
      // cambió no se movió, lo de después se corrió con él.
      int toAfter(int offset, {required bool isEnd}) {
        if (offset <= prefix) {
          return offset;
        }
        if (offset >= before.length - suffix) {
          return offset + after.length - before.length;
        }
        return isEnd ? after.length - suffix : prefix;
      }

      closing = (
        composedStart: startAt(toAfter(composing.start, isEnd: false)),
        composedEnd: endAt(toAfter(composing.end, isEnd: true)),
        caretAt: endAt(toAfter(caret, isEnd: true)),
      );
    } else {
      closing = null;
    }

    // Lo único que se puede recortar: lo insertado y lo compuesto, en uno o
    // dos tramos (si no se tocan, lo que hay entre los dos ya estaba).
    final spans = <(int, int)>[
      if (changed) (changeStart, changeEnd),
      if (closing != null && closing.composedStart < closing.composedEnd)
        (closing.composedStart, closing.composedEnd),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    if (spans.length == 2 && spans[1].$1 <= spans[0].$2) {
      spans
        ..[0] = (spans[0].$1, math.max(spans[0].$2, spans[1].$2))
        ..removeLast();
    }

    // Esos tramos en piezas: los grafemas, cortados también donde empieza o
    // termina lo insertado y en el cursor, así cada pieza es de una sola
    // cosa (lo insertado, lo escrito antes del cursor o lo demás).
    final cuts = <int>{changeStart, changeEnd, ?closing?.caretAt};
    final pieces = <(int, int)>[];
    var graphemeStart = 0;
    for (final grapheme in after.characters) {
      final graphemeEnd = graphemeStart + grapheme.length;
      for (final (spanStart, spanEnd) in spans) {
        final pieceStart = math.max(graphemeStart, spanStart);
        final pieceEnd = math.min(graphemeEnd, spanEnd);
        if (pieceStart >= pieceEnd) {
          continue;
        }
        var from = pieceStart;
        for (final cut in [
          ...cuts.where((cut) => cut > pieceStart && cut < pieceEnd).toList()
            ..sort(),
          pieceEnd,
        ]) {
          pieces.add((from, cut));
          from = cut;
        }
      }
      graphemeStart = graphemeEnd;
    }

    // Orden en que se recortan las piezas; cada grupo, desde su final.
    final order = <(int, int)>[];
    if (closing != null) {
      final caretAt = closing.caretAt;
      // Lo que el cierre agrega después del cursor: es lo último que llegó,
      // y lo que hay entre el cursor y eso ya estaba.
      if (changed && changeStart >= caretAt) {
        order.addAll(
          pieces.reversed.where(
            (piece) => piece.$1 >= changeStart && piece.$2 <= changeEnd,
          ),
        );
      }
      // Lo compuesto justo antes del cursor (hasta el principio de su
      // tramo): lo último que se escribió.
      for (final (spanStart, spanEnd) in spans) {
        if (spanStart < caretAt && caretAt <= spanEnd) {
          order.addAll(
            pieces.reversed.where(
              (piece) => piece.$1 >= spanStart && piece.$2 <= caretAt,
            ),
          );
        }
      }
    }
    // Y, si todavía se pasa, lo que quede, desde el final.
    order.addAll(pieces.reversed);

    // Lo justo para no pasarse. Si lo que no se puede tocar ya se pasa (p.
    // ej. vino así de afuera), se recorta todo lo que se puede, pero eso no
    // se borra.
    final excess = after.runes.length - maxRunes;
    final removed = <(int, int)>{};
    var dropped = 0;
    for (final piece in order) {
      if (dropped >= excess) {
        break;
      }
      if (removed.add(piece)) {
        dropped += after.substring(piece.$1, piece.$2).runes.length;
      }
    }
    final removedInOrder = removed.toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));

    final text = StringBuffer();
    var keptFrom = 0;
    for (final (start, end) in removedInOrder) {
      text.write(after.substring(keptFrom, start));
      keptFrom = end;
    }
    text.write(after.substring(keptFrom));

    // Una posición dentro de lo recortado queda donde empezaba; las de
    // después se corren lo que se recortó antes.
    int moved(int offset) {
      var shift = 0;
      for (final (start, end) in removedInOrder) {
        if (offset <= start) {
          break;
        }
        if (offset < end) {
          return start - shift;
        }
        shift += end - start;
      }
      return offset - shift;
    }

    final newComposing = newValue.composing;
    final composingStart = moved(newComposing.start);
    final composingEnd = moved(newComposing.end);
    return TextEditingValue(
      text: text.toString(),
      selection: selection.copyWith(
        baseOffset: moved(selection.baseOffset),
        extentOffset: moved(selection.extentOffset),
      ),
      composing: newComposing.isValid && composingStart < composingEnd
          ? TextRange(start: composingStart, end: composingEnd)
          : TextRange.empty,
    );
  }

  static bool _isHighSurrogate(int codeUnit) => (codeUnit & 0xFC00) == 0xD800;

  static bool _isLowSurrogate(int codeUnit) => (codeUnit & 0xFC00) == 0xDC00;
}

/// Contador visible "n/máximo" en code points (lo mismo que cuenta
/// [RuneLengthLimitingFormatter]) y lo que queda, dicho para el lector de
/// pantalla con el texto de Material ("Quedan N caracteres").
({String text, String semantics}) runeCounter(
  BuildContext context,
  String text,
  int maxRunes,
) {
  final used = text.runes.length;
  final remaining = math.max(0, maxRunes - used);
  return (
    text: '$used/$maxRunes',
    semantics: MaterialLocalizations.of(context)
        .remainingTextFieldCharacterCount(remaining),
  );
}
