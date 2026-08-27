import 'business_role.dart';

/// Usuario autenticado, ya desacoplado del SDK de Supabase.
///
/// Solo contiene lo que la app necesita para navegar y mostrar identidad. Los
/// datos de perfil viven en `profiles` y llegan con el Bloque D.
class AuthenticatedUser {
  const AuthenticatedUser({
    required this.id,
    required this.email,
    required this.role,
  });

  final String id;

  /// Puede venir vacío en cuentas creadas por teléfono (fuera del MVP).
  final String email;

  /// Rol confiable derivado de `app_metadata.role`.
  final BusinessRole role;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthenticatedUser &&
          other.id == id &&
          other.email == email &&
          other.role == role;

  @override
  int get hashCode => Object.hash(id, email, role);

  @override
  String toString() => 'AuthenticatedUser(id: $id, role: ${role.claim})';
}
