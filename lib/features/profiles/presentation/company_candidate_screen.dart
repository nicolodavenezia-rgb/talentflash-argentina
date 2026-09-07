import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/models/data_failure.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../companies/data/company_access_repository.dart';
import '../../onboarding/presentation/onboarding_copy.dart';
import '../domain/candidate_public_profile.dart';
import '../providers/profile_providers.dart';
import 'profile_copy.dart';
import 'widgets/profile_widgets.dart';

/// Vista limitada de un candidato para la empresa (T-024).
///
/// Renderiza EXCLUSIVAMENTE la proyección con whitelist de campos que decide
/// el servidor (fail-closed). Nunca contacto, nacimiento, salario ni score.
/// Si el candidato no está disponible, la respuesta es idéntica exista o no.
class CompanyCandidateScreen extends ConsumerWidget {
  const CompanyCandidateScreen({required this.candidateProfileId, super.key});

  final String candidateProfileId;

  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    Widget body;
    if (!_uuidPattern.hasMatch(candidateProfileId)) {
      // Un id malformado ni siquiera viaja al servidor.
      body = const _NotAvailableView();
    } else {
      final projection = ref.watch(
        candidatePublicProfileProvider(candidateProfileId),
      );
      body = projection.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          if (error is DataFailure && error.code == DataFailureCode.network) {
            return _CenteredMessage(
              title: l10n.companyCandidateLoadError,
              body: null,
              child: FilledButton(
                onPressed: () => ref.invalidate(
                  candidatePublicProfileProvider(candidateProfileId),
                ),
                child: Text(l10n.retryLabel),
              ),
            );
          }
          return const _NotAvailableView();
        },
        data: (profile) => profile == null
            ? const _UnavailableOrPendingView()
            : _ProjectionView(profile: profile),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.goNamed(AppRoute.companyHome.name),
        ),
        title: Text(l10n.companyCandidateTitle),
      ),
      body: SafeArea(child: body),
    );
  }
}

/// La proyección vino null: antes de mostrar el mensaje genérico se revisa el
/// estado de verificación de la PROPIA empresa (dato propio, nunca del
/// candidato) para explicar el caso "todavía no podés ver candidatos".
class _UnavailableOrPendingView extends ConsumerWidget {
  const _UnavailableOrPendingView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final verification = ref.watch(ownCompanyVerificationProvider);
    return verification.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      // La cuenta figura en más de una empresa (`TFMUL`, 0031). Es un estado
      // sin salida por la app —el servidor se niega a elegir una, y hace
      // bien— así que se dice cuál es el problema en vez de esconderlo detrás
      // del "no disponible" genérico, que invitaría a reintentar para siempre.
      error: (error, _) =>
          error is DataFailure && error.code == DataFailureCode.ambiguousCompany
          ? _CenteredMessage(
              title: l10n.companyCandidateNotAvailableTitle,
              body: l10n.dataFailureAmbiguousCompany,
            )
          : const _NotAvailableView(),
      data: (status) => switch (status) {
        CompanyVerificationStatus.pending ||
        CompanyVerificationStatus.inReview => _CenteredMessage(
          title: l10n.companyCandidatePendingTitle,
          body: l10n.companyCandidatePendingBody,
        ),
        CompanyVerificationStatus.rejected => _CenteredMessage(
          title: l10n.companyCandidateRejectedTitle,
          body: l10n.companyCandidateRejectedBody,
        ),
        _ => const _NotAvailableView(),
      },
    );
  }
}

class _NotAvailableView extends StatelessWidget {
  const _NotAvailableView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _CenteredMessage(
      title: l10n.companyCandidateNotAvailableTitle,
      body: l10n.companyCandidateNotAvailableBody,
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.title, required this.body, this.child});

  final String title;
  final String? body;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                liveRegion: true,
                child: Text(title, style: theme.textTheme.headlineSmall),
              ),
              if (body != null) ...[
                const SizedBox(height: 12),
                Text(body!, style: theme.textTheme.bodyLarge),
              ],
              if (child != null) ...[const SizedBox(height: 24), child!],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectionView extends StatelessWidget {
  const _ProjectionView({required this.profile});

  final CandidatePublicProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ProfileAvatar(
                    avatarPath: profile.avatarThumbPath ?? profile.avatarPath,
                    semanticLabel: l10n.profileAvatarLabel,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName,
                          style: theme.textTheme.titleLarge,
                        ),
                        if (profile.headline != null)
                          Text(
                            profile.headline!,
                            style: theme.textTheme.bodyLarge,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              MessageBanner.info(
                message: profile.presentationAvailable
                    ? l10n.companyCandidatePresentationReady
                    : l10n.companyCandidateNoPresentation,
              ),
              if (profile.bio != null)
                ProfileSection(
                  title: l10n.profileSectionIdentity,
                  children: [
                    ProfileValue(
                      value: profile.bio,
                      emptyLabel: l10n.profileEmptyValue,
                    ),
                  ],
                ),
              ProfileSection(
                title: l10n.profileSectionLocation,
                children: [
                  ProfileValue(
                    value: [
                      profile.provinceName,
                      profile.localityName,
                      profile.neighborhoodName,
                    ].whereType<String>().join(' · '),
                    emptyLabel: l10n.profileEmptyValue,
                  ),
                ],
              ),
              ProfileSection(
                title: l10n.profileSectionPreferences,
                children: [
                  ProfileValue(
                    value: [
                      profile.sectorName,
                      profile.availability == null
                          ? null
                          : OnboardingCopy.availability(
                              l10n,
                              profile.availability!,
                            ),
                      profile.workModes.isEmpty
                          ? null
                          : profile.workModes
                                .map(
                                  (mode) => OnboardingCopy.workMode(l10n, mode),
                                )
                                .join(', '),
                      profile.experienceLevel == null
                          ? null
                          : ProfileCopy.experienceLevel(
                              l10n,
                              profile.experienceLevel!,
                            ),
                    ].whereType<String>().join(' · '),
                    emptyLabel: l10n.profileEmptyValue,
                  ),
                ],
              ),
              if (profile.weeklyAvailability.isNotEmpty)
                ProfileSection(
                  title: l10n.profileSectionSchedule,
                  children: [
                    for (final slot in profile.weeklyAvailability)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          ProfileCopy.slot(l10n, slot),
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                  ],
                ),
              if (profile.skills.isNotEmpty)
                ProfileSection(
                  title: l10n.profileSectionSkills,
                  children: [
                    ProfileChips(
                      values: profile.skills,
                      emptyLabel: l10n.profileEmptyValue,
                    ),
                  ],
                ),
              if (profile.languages.isNotEmpty)
                ProfileSection(
                  title: l10n.profileSectionLanguages,
                  children: [
                    ProfileChips(
                      values: profile.languages,
                      emptyLabel: l10n.profileEmptyValue,
                    ),
                  ],
                ),
              if (profile.workHistory.isNotEmpty)
                ProfileSection(
                  title: l10n.profileSectionExperience,
                  children: [
                    for (final entry in profile.workHistory)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${entry.position} · ${entry.company}',
                              style: theme.textTheme.titleSmall,
                            ),
                            Text(
                              entry.isCurrent
                                  ? l10n.profileExperienceCurrent(
                                      entry.fromMonth,
                                    )
                                  : l10n.profileExperiencePeriod(
                                      entry.fromMonth,
                                      entry.toMonth!,
                                    ),
                              style: theme.textTheme.bodyMedium,
                            ),
                            if (entry.description != null)
                              Text(
                                entry.description!,
                                style: theme.textTheme.bodyMedium,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              if (profile.education.isNotEmpty)
                ProfileSection(
                  title: l10n.profileSectionEducation,
                  children: [
                    for (final entry in profile.education)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${ProfileCopy.educationLevel(l10n, entry.level)} · '
                          '${entry.institution}'
                          '${entry.degree == null ? '' : ' · ${entry.degree}'}',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
