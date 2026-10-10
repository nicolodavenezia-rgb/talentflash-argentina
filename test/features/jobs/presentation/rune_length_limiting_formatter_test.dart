import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/jobs/presentation/widgets/rune_length_limiting_formatter.dart';

/// El tope de los textos de la oferta cuenta code points (`runes`), como
/// `JobOfferValidation` y `length()` de Postgres, y nunca parte un grafema.
/// Lo que no entra se recorta de lo que se escribe o se pega, nunca del texto
/// que ya estaba. Con el teclado componiendo (IME) sigue la misma política
/// por plataforma que `maxLength` ([LengthLimitingTextInputFormatter]).
void main() {
  // 👨‍🍳: un solo grafema, tres code points (hombre, ZWJ, olla).
  const chef = '\u{1F468}‍\u{1F373}';
  // 👍🏽: un grafema, dos code points (pulgar y tono de piel).
  const pulgar = '\u{1F44D}\u{1F3FD}';
  // 🇦🇷: un grafema, dos code points (dos indicadores regionales).
  const bandera = '\u{1F1E6}\u{1F1F7}';
  const formatter = RuneLengthLimitingFormatter(10);
  const conTope = RuneLengthLimitingFormatter(
    10,
    maxLengthEnforcement: MaxLengthEnforcement.enforced,
  );
  const alTerminar = RuneLengthLimitingFormatter(
    10,
    maxLengthEnforcement: MaxLengthEnforcement.truncateAfterCompositionEnds,
  );

  TextEditingValue valor(String text) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );

  /// El teclado recompone "hola" (el cursor quedó en esa palabra) en un
  /// campo lleno: 10 de 10.
  const llenoComponiendo = TextEditingValue(
    text: 'hola mundo',
    selection: TextSelection.collapsed(offset: 4),
    composing: TextRange(start: 0, end: 4),
  );

  /// Lo que manda el teclado al sumar una letra a esa palabra: el texto nuevo
  /// mide 11 y la composición sigue abierta.
  const sumaEnElMedio = TextEditingValue(
    text: 'holas mundo',
    selection: TextSelection.collapsed(offset: 5),
    composing: TextRange(start: 0, end: 5),
  );

  test('lo que entra pasa tal cual', () {
    final nuevo = valor('a' * 7 + chef);
    expect(formatter.formatEditUpdate(valor(''), nuevo), nuevo);
  });

  test('cuenta code points y no grafemas: cuatro chefs son 12, no 4', () {
    final resultado = formatter.formatEditUpdate(valor(''), valor(chef * 4));
    expect(resultado.text, chef * 3);
    expect(resultado.text.runes.length, 9);
  });

  test('recorta sin partir un grafema y deja el cursor dentro del texto', () {
    final resultado = formatter.formatEditUpdate(
      valor(''),
      valor('a' * 8 + chef),
    );
    expect(resultado.text, 'a' * 8);
    expect(resultado.selection, const TextSelection.collapsed(offset: 8));
  });

  test('en el tope, escribir de más no cambia nada', () {
    final lleno = valor('a' * 10);
    expect(formatter.formatEditUpdate(lleno, valor('${'a' * 10}b')), lleno);
  });

  group('enforced (Android y Windows)', () {
    test('en el tope, una composición en el medio no borra el final', () {
      final resultado = conTope.formatEditUpdate(
        llenoComponiendo,
        sumaEnElMedio,
      );

      expect(resultado, llenoComponiendo);
      expect(resultado.text, endsWith('mundo'));
    });

    test('lejos del tope, se recorta aunque el teclado esté componiendo y la '
        'composición queda dentro del texto', () {
      const componiendo = TextEditingValue(
        text: 'aaaaaaaaxyz',
        selection: TextSelection.collapsed(offset: 11),
        composing: TextRange(start: 8, end: 11),
      );

      final resultado = conTope.formatEditUpdate(valor('a' * 8), componiendo);

      expect(resultado.text, 'aaaaaaaaxy');
      expect(resultado.selection, const TextSelection.collapsed(offset: 10));
      expect(resultado.composing, const TextRange(start: 8, end: 10));
    });

    test('una composición que queda entera fuera del recorte se descarta', () {
      final resultado = conTope.formatEditUpdate(
        valor('a' * 9),
        const TextEditingValue(
          text: 'aaaaaaaaa$chef',
          selection: TextSelection.collapsed(offset: 14),
          composing: TextRange(start: 9, end: 14),
        ),
      );

      expect(resultado.text, 'a' * 9);
      expect(resultado.composing, TextRange.empty);
    });
  });

  group('truncateAfterCompositionEnds (iOS, macOS, Linux y Web)', () {
    test('mientras el teclado compone no se corta (se recorta después)', () {
      const componiendo = TextEditingValue(
        text: 'aaaaaaaaaaab',
        selection: TextSelection.collapsed(offset: 12),
        composing: TextRange(start: 10, end: 12),
      );
      expect(alTerminar.formatEditUpdate(valor(''), componiendo), componiendo);
    });

    test('al cerrar la composición se recorta a lo que entra', () {
      const componiendo = TextEditingValue(
        text: 'aaaaaaaaaaab',
        selection: TextSelection.collapsed(offset: 12),
        composing: TextRange(start: 10, end: 12),
      );

      final resultado = alTerminar.formatEditUpdate(
        componiendo,
        valor('aaaaaaaaaaab'),
      );

      expect(resultado.text, 'a' * 10);
      expect(resultado.composing, TextRange.empty);
    });

    test('en el tope y sin composición en curso, una nueva no entra', () {
      final lleno = valor('hola mundo');
      expect(alTerminar.formatEditUpdate(lleno, sumaEnElMedio), lleno);
    });
  });

  group('nunca borra lo que ya estaba', () {
    /// "abcdefghi": 9 de 10, con el cursor entre la "d" y la "e".
    const casiLleno = TextEditingValue(
      text: 'abcdefghi',
      selection: TextSelection.collapsed(offset: 4),
    );

    /// Lo que manda el teclado al insertar [texto] en el cursor de [antes].
    TextEditingValue insertar(TextEditingValue antes, String texto) {
      final cursor = antes.selection.baseOffset;
      return TextEditingValue(
        text:
            antes.text.substring(0, cursor) +
            texto +
            antes.text.substring(cursor),
        selection: TextSelection.collapsed(offset: cursor + texto.length),
      );
    }

    for (final (nombre, emoji) in [
      ('un emoji con tono de piel', pulgar),
      ('una bandera', bandera),
    ]) {
      test('$nombre en el medio, con un code point libre, no entra y el '
          'final queda entero', () {
        for (final politica in [conTope, alTerminar, formatter]) {
          final resultado = politica.formatEditUpdate(
            casiLleno,
            insertar(casiLleno, emoji),
          );

          expect(resultado.text, 'abcdefghi');
          expect(resultado.selection, const TextSelection.collapsed(offset: 4));
        }
      });
    }

    test('pegar en el medio recorta lo pegado por grafemas enteros y deja el '
        'final', () {
      const antes = TextEditingValue(
        text: 'abcdef',
        selection: TextSelection.collapsed(offset: 3),
      );
      // 6 code points pegados con 4 libres: entran "X" e "Y"; el chef (3)
      // ya no, y tampoco la "Z" que viene después (no se salta un grafema).
      final resultado = formatter.formatEditUpdate(
        antes,
        insertar(antes, 'XY${chef}Z'),
      );

      expect(resultado.text, 'abcXYdef');
      expect(resultado.text.runes.length, 8);
      expect(resultado.selection, const TextSelection.collapsed(offset: 5));
    });

    test('con texto repetido, lo que se recorta es lo pegado, donde quedó el '
        'cursor', () {
      const tope6 = RuneLengthLimitingFormatter(6);
      const antes = TextEditingValue(
        text: 'abcab',
        selection: TextSelection.collapsed(offset: 2),
      );

      final resultado = tope6.formatEditUpdate(antes, insertar(antes, 'cab'));

      expect(resultado.text, 'abccab');
      expect(resultado.selection, const TextSelection.collapsed(offset: 3));
    });

    test('agregar de más al final se recorta igual que siempre', () {
      final resultado = formatter.formatEditUpdate(
        valor('a' * 8),
        valor('${'a' * 8}xyz'),
      );

      expect(resultado.text, 'aaaaaaaaxy');
      expect(resultado.selection, const TextSelection.collapsed(offset: 10));
    });

    test('truncateAfterCompositionEnds: al cerrar una composición que se pasó '
        'en el medio, se recorta lo compuesto y no el final', () {
      // El teclado dejó pasar "holas" mientras componía (ver el grupo de
      // arriba): al cerrar, sobra un code point.
      const componiendo = TextEditingValue(
        text: 'holas mundo',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 0, end: 5),
      );

      final resultado = alTerminar.formatEditUpdate(
        componiendo,
        const TextEditingValue(
          text: 'holas mundo',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );

      expect(resultado.text, 'hola mundo');
      expect(resultado.selection, const TextSelection.collapsed(offset: 4));
      expect(resultado.composing, TextRange.empty);
    });

    group('con el cursor en el medio de la palabra que compone el teclado', () {
      /// "hola casa": 9 de 10. El teclado compone "casa" (5..9) y el cursor
      /// está entre "ca" y "sa": Gboard deja compuesta la palabra donde se
      /// apoya el cursor aunque el cursor no esté al final.
      const enLaPalabra = TextEditingValue(
        text: 'hola casa',
        selection: TextSelection.collapsed(offset: 7),
        composing: TextRange(start: 5, end: 9),
      );

      for (final (nombre, composicion) in [
        ('y el teclado cierra la composición', TextRange.empty),
        // 5..12: "caXYZsa" o "ca👍🏽sa".
        ('y el teclado sigue componiendo la palabra', null),
      ]) {
        test('enforced: pegar en el cursor recorta lo pegado y no las letras '
            'de la palabra que siguen al cursor, $nombre', () {
          final resultado = conTope.formatEditUpdate(
            enLaPalabra,
            TextEditingValue(
              text: 'hola caXYZsa',
              selection: const TextSelection.collapsed(offset: 10),
              composing: composicion ?? const TextRange(start: 5, end: 12),
            ),
          );

          expect(resultado.text, 'hola caXsa');
          expect(resultado.selection, const TextSelection.collapsed(offset: 8));
          expect(
            resultado.composing,
            composicion ?? const TextRange(start: 5, end: 10),
          );
        });

        test('enforced: un emoji en el cursor que no entra no se lleva las '
            'letras de la palabra que siguen al cursor, $nombre', () {
          final resultado = conTope.formatEditUpdate(
            enLaPalabra,
            TextEditingValue(
              text: 'hola ca${pulgar}sa',
              selection: const TextSelection.collapsed(offset: 11),
              composing: composicion ?? const TextRange(start: 5, end: 13),
            ),
          );

          expect(resultado.text, 'hola casa');
          expect(resultado.selection, const TextSelection.collapsed(offset: 7));
        });
      }

      test('truncateAfterCompositionEnds: pegar o un emoji en el cursor al '
          'cerrar la composición recorta lo pegado y no las letras que '
          'siguen al cursor', () {
        final pegado = alTerminar.formatEditUpdate(
          enLaPalabra,
          const TextEditingValue(
            text: 'hola caXYZsa',
            selection: TextSelection.collapsed(offset: 10),
          ),
        );
        expect(pegado.text, 'hola caXsa');
        expect(pegado.selection, const TextSelection.collapsed(offset: 8));

        final emoji = alTerminar.formatEditUpdate(
          enLaPalabra,
          const TextEditingValue(
            text: 'hola ca${pulgar}sa',
            selection: TextSelection.collapsed(offset: 11),
          ),
        );
        expect(emoji.text, 'hola casa');
        expect(emoji.selection, const TextSelection.collapsed(offset: 7));
      });

      // Se escribió la "s" de "hosla" en el medio de la palabra (el cursor
      // quedó en 3) y el teclado la dejó pasar mientras componía: al cerrar,
      // sobra un code point. La "la" que sigue al cursor ya estaba.
      for (final (nombre, cursorAlCerrar) in [
        ('el cursor queda donde estaba', 3),
        ('el cursor pasa al final de la palabra', 5),
      ]) {
        test('truncateAfterCompositionEnds: al cerrar una composición que se '
            'pasó, se recorta lo último escrito antes del cursor y no lo '
            'compuesto que sigue al cursor ($nombre)', () {
          final resultado = alTerminar.formatEditUpdate(
            const TextEditingValue(
              text: 'hosla mundo',
              selection: TextSelection.collapsed(offset: 3),
              composing: TextRange(start: 0, end: 5),
            ),
            TextEditingValue(
              text: 'hosla mundo',
              selection: TextSelection.collapsed(offset: cursorAlCerrar),
            ),
          );

          expect(resultado.text, 'hola mundo');
          expect(
            resultado.selection,
            TextSelection.collapsed(offset: cursorAlCerrar - 1),
          );
          expect(resultado.composing, TextRange.empty);
        });
      }
    });

    // Al cerrar se recorta solo de lo compuesto y de lo que cambió al
    // cerrar; lo de afuera ya estaba. Primero lo que el cierre agrega
    // después del cursor, después lo compuesto justo antes del cursor (lo
    // último que se escribió) y, si todavía se pasa, el resto desde el final.
    group('truncateAfterCompositionEnds: al cerrar una composición que se '
        'pasó', () {
      // El teclado dejó pasar "hola abcdefg" (12 de 10) mientras componía
      // "abcdefg" y el cursor quedó cerca del principio de esa palabra:
      // sobran 2 code points, más que lo escrito antes del cursor.
      for (final (cursor, esperado) in [
        // Nada antes del cursor: desde el final de la palabra.
        (5, 'hola abcde'),
        // La "a" no alcanza: después, la "g" del final.
        (6, 'hola bcdef'),
        // Lo escrito antes del cursor alcanza.
        (7, 'hola cdefg'),
      ]) {
        test('con el cursor en $cursor el resultado queda dentro del tope y '
            'lo que está fuera de la palabra no se toca', () {
          final resultado = alTerminar.formatEditUpdate(
            TextEditingValue(
              text: 'hola abcdefg',
              selection: TextSelection.collapsed(offset: cursor),
              composing: const TextRange(start: 5, end: 12),
            ),
            TextEditingValue(
              text: 'hola abcdefg',
              selection: TextSelection.collapsed(offset: cursor),
            ),
          );

          expect(resultado.text.runes.length, lessThanOrEqualTo(10));
          expect(resultado.text, esperado);
          expect(resultado.text, startsWith('hola '));
          expect(resultado.selection, const TextSelection.collapsed(offset: 5));
          expect(resultado.composing, TextRange.empty);
        });
      }

      test('si el cierre también agrega algo después del cursor, se recorta '
          'primero eso y después lo escrito antes del cursor: lo que ya '
          'estaba entre el cursor y lo agregado queda', () {
        // El teclado compone "caXsa" (en el tope) con el cursor después de
        // la "X" y, al cerrar, agrega una "s" al final de la palabra: sobra
        // 1 y alcanza con lo agregado.
        final sobraUno = alTerminar.formatEditUpdate(
          const TextEditingValue(
            text: 'hola caXsa',
            selection: TextSelection.collapsed(offset: 8),
            composing: TextRange(start: 5, end: 10),
          ),
          const TextEditingValue(
            text: 'hola caXsas',
            selection: TextSelection.collapsed(offset: 11),
          ),
        );
        expect(sobraUno.text, 'hola caXsa');
        expect(sobraUno.selection, const TextSelection.collapsed(offset: 10));

        // Ahora el teclado dejó pasar "XY" (11 de 10) y el cierre agrega la
        // "s": sobran 2, lo agregado y la "Y", lo último escrito antes del
        // cursor. La "sa" que sigue al cursor ya estaba y queda.
        final resultado = alTerminar.formatEditUpdate(
          const TextEditingValue(
            text: 'hola caXYsa',
            selection: TextSelection.collapsed(offset: 9),
            composing: TextRange(start: 5, end: 11),
          ),
          const TextEditingValue(
            text: 'hola caXYsas',
            selection: TextSelection.collapsed(offset: 12),
          ),
        );

        expect(resultado.text, 'hola caXsa');
        expect(resultado.selection, const TextSelection.collapsed(offset: 10));
        expect(resultado.composing, TextRange.empty);
      });

      test('si el cierre inserta algo separado de lo compuesto, lo que hay '
          'entre los dos ya estaba y no se toca', () {
        // Sobran 3: la palabra compuesta ("ca") no alcanza y sigue lo
        // insertado desde su final; "hola " queda entero.
        final resultado = alTerminar.formatEditUpdate(
          const TextEditingValue(
            text: 'hola ca',
            selection: TextSelection.collapsed(offset: 7),
            composing: TextRange(start: 5, end: 7),
          ),
          const TextEditingValue(
            text: 'XYZWVUhola ca',
            selection: TextSelection.collapsed(offset: 6),
          ),
        );

        expect(resultado.text, 'XYZWVhola ');
        expect(resultado.selection, const TextSelection.collapsed(offset: 5));
      });
    });
  });

  test('sin política explícita usa la de la plataforma, igual que maxLength: '
      'mismo resultado que LengthLimitingTextInputFormatter al agregar al '
      'final, al borrar y en el tope', () {
    // Texto ASCII: ahí grafemas y code points coinciden, así que los dos
    // formatters tienen que devolver exactamente lo mismo. Salvo cuando
    // Flutter recorta lo que ya estaba: esos casos son diferencias a
    // propósito y están en los tests siguientes.
    final flutter = LengthLimitingTextInputFormatter(10);
    final casos = <(String, TextEditingValue, TextEditingValue)>[
      ('agregar de más al final', valor('a' * 8), valor('${'a' * 8}xyz')),
      ('borrar', valor('hola mundo'), valor('hola mund')),
      (
        'en el tope, escribir al final',
        valor('hola mundo'),
        valor('hola mundo!'),
      ),
      (
        'en el tope, escribir en el medio',
        const TextEditingValue(
          text: 'hola mundo',
          selection: TextSelection.collapsed(offset: 4),
        ),
        const TextEditingValue(
          text: 'holas mundo',
          selection: TextSelection.collapsed(offset: 5),
        ),
      ),
      ('composición en el medio, en el tope', llenoComponiendo, sumaEnElMedio),
      (
        'composición en el medio, en el tope y sin componer antes',
        valor('hola mundo'),
        sumaEnElMedio,
      ),
      (
        'composición que se pasa, lejos del tope',
        valor('a' * 8),
        const TextEditingValue(
          text: 'aaaaaaaaxyz',
          selection: TextSelection.collapsed(offset: 11),
          composing: TextRange(start: 8, end: 11),
        ),
      ),
      (
        'reemplazo de una selección por algo más largo, en el tope',
        const TextEditingValue(
          text: 'hola mundo',
          selection: TextSelection(baseOffset: 0, extentOffset: 4),
        ),
        const TextEditingValue(
          text: 'chau mundo!',
          selection: TextSelection.collapsed(offset: 4),
        ),
      ),
    ];
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    for (final plataforma in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = plataforma;
      for (final (nombre, antes, despues) in casos) {
        expect(
          formatter.formatEditUpdate(antes, despues),
          flutter.formatEditUpdate(antes, despues),
          reason: '$nombre en ${plataforma.name}',
        );
      }
    }
  });

  // Este caso estaba en la lista del test anterior para todas las
  // plataformas. Con enforced (Android y Windows) ya no coincide con Flutter,
  // a propósito: ahí el formatter nunca deja que lo compuesto pase el tope,
  // así que un valor de antes que ya se pasa solo pudo venir de afuera (p. ej.
  // `controller.text`), y lo que vino de afuera no se borra. Recortarlo
  // tomando la composición entera como "lo insertado" era justamente lo que
  // se llevaba letras de la palabra que siguen al cursor.
  test('cierre de una composición que se pasa: con '
      'truncateAfterCompositionEnds recorta igual que '
      'LengthLimitingTextInputFormatter; con enforced no borra lo que ya '
      'estaba', () {
    final flutter = LengthLimitingTextInputFormatter(10);
    const antes = TextEditingValue(
      text: 'aaaaaaaaaaab',
      selection: TextSelection.collapsed(offset: 12),
      composing: TextRange(start: 10, end: 12),
    );
    final despues = valor('aaaaaaaaaaab');
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    for (final plataforma in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = plataforma;
      final resultado = formatter.formatEditUpdate(antes, despues);
      switch (LengthLimitingTextInputFormatter.getDefaultMaxLengthEnforcement()) {
        case MaxLengthEnforcement.truncateAfterCompositionEnds:
          expect(
            resultado,
            flutter.formatEditUpdate(antes, despues),
            reason: plataforma.name,
          );
          expect(resultado.text, 'a' * 10, reason: plataforma.name);
        case MaxLengthEnforcement.enforced:
          expect(resultado, despues, reason: plataforma.name);
        case MaxLengthEnforcement.none:
          fail('ninguna plataforma usa none por defecto');
      }
    }
  });

  test('diferencia a propósito con LengthLimitingTextInputFormatter: donde '
      'Flutter recorta el final de lo que ya estaba, acá se recorta lo '
      'insertado', () {
    final flutter = LengthLimitingTextInputFormatter(10);
    // Pegar "XYZ" en el medio con el campo en 9 de 10.
    const antes = TextEditingValue(
      text: 'abcdefghi',
      selection: TextSelection.collapsed(offset: 4),
    );
    const despues = TextEditingValue(
      text: 'abcdXYZefghi',
      selection: TextSelection.collapsed(offset: 7),
    );
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    for (final plataforma in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = plataforma;

      expect(
        formatter.formatEditUpdate(antes, despues),
        const TextEditingValue(
          text: 'abcdXefghi',
          selection: TextSelection.collapsed(offset: 5),
        ),
        reason: plataforma.name,
      );
      // Flutter se queda con los primeros 10 de lo nuevo y pierde, sin
      // avisar, el final de lo que ya estaba ("hi").
      expect(
        flutter.formatEditUpdate(antes, despues).text,
        'abcdXYZefg',
        reason: plataforma.name,
      );
    }
  });
}
