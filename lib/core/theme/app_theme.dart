import 'package:flutter/material.dart';

/// Tema base del Bloque A. Decisiones guiadas por WCAG AA (UX_FLOWS.md §20):
/// - contraste del seed verificado sobre blanco/negro;
/// - objetivos táctiles >= 48 dp (minimumSize en botones);
/// - foco visible para navegación por teclado en Web.
abstract final class AppTheme {
  static const _seed = Color(
    0xFF0F4C81,
  ); // azul profundo, contraste AA sobre blanco

  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // Nunca reducir el área táctil por densidad de la plataforma (WCAG 2.5.8).
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 56),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 56)),
      ),
      // Foco visible: anillo de 2 px para teclado en Web (WCAG 2.4.7).
      focusColor: scheme.primary.withValues(alpha: 0.25),
    );
  }
}
