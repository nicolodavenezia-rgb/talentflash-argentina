import '../domain/company_verification.dart';
import 'company_access_repository.dart';

/// Circuito de verificación de empresa (T-028).
///
/// Todo lo que hay acá es una llamada a una RPC o al bucket privado
/// `company-docs`: la autorización real vive en las policies y en las RPCs de
/// las migraciones 0028/0029, y esta interfaz solo describe qué puede pedir la
/// app. Cualquier comprobación que se haga del lado del cliente es UX.
abstract interface class CompanyVerificationRepository {
  /// Estado de verificación de la empresa del caller y su última solicitud.
  Future<CompanyVerification> fetchMyVerification();

  /// Sube la constancia de ARCA al bucket privado y devuelve el path que quedó
  /// guardado. El path lo decide el servidor: acá se pide y se respeta.
  Future<String> uploadConstancia(PickedConstancia document);

  /// Envía (o reenvía) la solicitud de verificación. Devuelve el id.
  ///
  /// [format] indica que hay una constancia adjunta con ese formato; el
  /// servidor arma el path con el `company_id` que resuelve de la sesión.
  Future<String> requestVerification({
    required String cuit,
    ConstanciaFormat? format,
  });

  /// URL firmada de vida corta para mirar una constancia ya subida.
  Future<String> createConstanciaSignedUrl(String path);

  // El nivel AAL de la sesión ya no se consulta acá: es un dato del estado de
  // sesión (`AuthStatus.assurance`, feature de autenticación) y así el panel
  // lo ve cambiar en cuanto se verifica el segundo factor.

  /// Cola administrativa filtrada por estado (avance parcial de T-077).
  Future<List<CompanyVerificationRequest>> fetchVerificationQueue(
    CompanyVerificationStatus status,
  );

  /// Resuelve una solicitud. [reason] es obligatorio al rechazar y tiene que
  /// quedar vacío al aprobar (la RPC rechaza lo contrario).
  Future<void> reviewVerification({
    required String requestId,
    required bool approve,
    VerificationRejectionReason? reason,
  });
}
