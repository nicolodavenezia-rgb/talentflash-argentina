import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pantalla inicial del binario. No es una frontera de autorización: los
/// guards de sesión/rol llegan en Bloque B y la seguridad real permanece en RLS.
enum AppEntryPoint {
  chooser('/'),
  candidate('/candidato'),
  company('/empresa');

  const AppEntryPoint(this.initialLocation);

  final String initialLocation;
}

final appEntryPointProvider = Provider<AppEntryPoint>(
  (ref) => AppEntryPoint.chooser,
);
