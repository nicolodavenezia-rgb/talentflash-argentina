import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/localization/gen/app_localizations.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

/// Raíz de la aplicación. Locale base: es-AR (SPEC §2); la arquitectura de
/// ARB soporta sumar es-UY/es-CL/es-CO/es-PE/pt-BR sin tocar código.
class TalentFlashApp extends ConsumerWidget {
  const TalentFlashApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      routerConfig: router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: const Locale('es', 'AR'),
      supportedLocales: const [Locale('es', 'AR'), Locale('es')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      debugShowCheckedModeBanner: false,
    );
  }
}
