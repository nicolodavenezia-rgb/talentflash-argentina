import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentflash_argentina/features/authentication/domain/auth_status.dart';
import 'package:talentflash_argentina/features/authentication/domain/business_role.dart';
import 'package:talentflash_argentina/features/companies/data/company_access_repository.dart';
import 'package:talentflash_argentina/features/companies/domain/company_verification.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer.dart';
import 'package:talentflash_argentina/features/jobs/domain/job_offer_enums.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_company_verification_repository.dart';
import '../../../support/fake_job_offers_repository.dart';
import '../../../support/fake_onboarding_repositories.dart';
import '../../../support/pump_app.dart';

/// Monta la app con sesión del [role] y navega a [ruta]. Con [settle] en
/// false solo dibuja un frame tras navegar: sirve para ver el estado de
/// carga (un indicador girando nunca "se asienta"). [riverpodRetry]: el
/// reintento de producción (ver `pumpTalentFlashApp`).
Future<TalentFlashHarness> entrarA(
  WidgetTester tester,
  String ruta, {
  BusinessRole role = BusinessRole.company,
  FakeJobOffersRepository? jobs,
  FakeCompanyVerificationRepository? verification,
  FakeCatalogRepository? catalog,
  bool settle = true,
  Size surface = const Size(1000, 3000),
  bool riverpodRetry = false,
}) async {
  // Ventana alta: la lista de ofertas y el formulario son largos y un
  // ListView no construye lo que queda fuera de pantalla.
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = FakeAuthRepository(initialStatus: const AuthStatusSignedOut());
  final harness = await pumpTalentFlashApp(
    tester,
    authRepository: auth,
    jobOffersRepository: jobs,
    companyVerificationRepository: verification,
    catalogRepository: catalog,
    riverpodRetry: riverpodRetry,
  );
  await tester.pumpAndSettle();
  auth.emitSignedIn(role);
  await tester.pumpAndSettle();
  harness.router.go(ruta);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
  return harness;
}

/// Verificación de la empresa de los fakes con el [status] pedido.
FakeCompanyVerificationRepository verificacion(
  CompanyVerificationStatus? status,
) {
  return FakeCompanyVerificationRepository(
    verification: CompanyVerification(
      companyId: testJobCompanyId,
      companyStatus: status,
    ),
  );
}

/// Variante de una oferta de prueba: `JobOffer` es inmutable y no tiene
/// `copyWith` (lo editable vive en `JobOfferInput`).
JobOffer variante(
  JobOffer base, {
  String? id,
  String? companyId,
  String? title,
  num? salaryMin,
  JobStatus? status,
  String? provinciaId,
  String? localidadId,
  String? Function()? barrioId,
  List<String>? benefits,
  DateTime? expiresAt,
  JobOfferCompany? Function()? company,
}) {
  return JobOffer(
    id: id ?? base.id,
    companyId: companyId ?? base.companyId,
    title: title ?? base.title,
    description: base.description,
    sectorId: base.sectorId,
    salaryMin: salaryMin ?? base.salaryMin,
    salaryMax: base.salaryMax,
    salaryPeriod: base.salaryPeriod,
    contractType: base.contractType,
    jornada: base.jornada,
    scheduleDays: base.scheduleDays,
    scheduleDetail: base.scheduleDetail,
    workMode: base.workMode,
    provinciaId: provinciaId ?? base.provinciaId,
    localidadId: localidadId ?? base.localidadId,
    barrioId: barrioId == null ? base.barrioId : barrioId(),
    experience: base.experience,
    availability: base.availability,
    benefits: benefits ?? base.benefits,
    expiresAt: expiresAt ?? base.expiresAt,
    vacancies: base.vacancies,
    status: status ?? base.status,
    publishedAt: base.publishedAt,
    closedAt: base.closedAt,
    createdAt: base.createdAt,
    updatedAt: base.updatedAt,
    company: company == null ? base.company : company(),
  );
}

/// El botón (de cualquier estilo) cuyo texto visible es [label], dentro de
/// la tarjeta de la oferta [titulo] si se indica.
Finder boton(String label, {String? titulo}) {
  final texto = titulo == null
      ? find.text(label)
      : find.descendant(of: tarjeta(titulo), matching: find.text(label));
  return find.ancestor(
    of: texto,
    matching: find.bySubtype<ButtonStyleButton>(),
  );
}

/// La tarjeta de la lista de la empresa que muestra la oferta [titulo].
Finder tarjeta(String titulo) =>
    find.ancestor(of: find.text(titulo), matching: find.byType(Card)).first;

bool habilitado(WidgetTester tester, Finder finder) =>
    tester.widget<ButtonStyleButton>(finder).enabled;

/// Un TextField enfocado vuelve a desplazar el formulario hacia sí mismo en
/// cada frame: se suelta el foco antes de ir a otro control.
Future<void> soltarFoco(WidgetTester tester) async {
  tester.binding.focusManager.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}
