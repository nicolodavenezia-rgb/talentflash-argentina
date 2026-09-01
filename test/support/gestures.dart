import 'package:flutter_test/flutter_test.dart';

/// Scrollea hasta el widget y lo toca: los formularios largos del onboarding
/// no entran en la ventana de test de 800×600.
Future<void> ensureAndTap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Selecciona una opción de un Dropdown de Material identificado por el texto
/// visible del campo y el de la opción.
Future<void> selectDropdownOption(
  WidgetTester tester,
  Finder field,
  String optionText,
) async {
  await ensureAndTap(tester, field);
  await tester.tap(find.text(optionText).last);
  await tester.pumpAndSettle();
}
