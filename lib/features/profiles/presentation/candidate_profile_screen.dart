import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../onboarding/presentation/onboarding_copy.dart';
import '../domain/candidate_profile.dart';
import '../domain/profile_completeness.dart';
import '../providers/profile_providers.dart';
import 'profile_copy.dart';
import 'widgets/profile_widgets.dart';

/// Perfil propio del candidato (T-021): consulta, completitud (T-025) y
/// estado de presentación honesto (T-023). El score es solo para el dueño.
class CandidateProfileScreen extends ConsumerWidget {
  const CandidateProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.goNamed(AppRoute.candidateHome.name),
        ),
        title: Text(l10n.profileTitle),
        actions: [
          if (profileAsync.hasValue)
            TextButton(
              onPressed: () =>
                  context.goNamed(AppRoute.candidateProfileEdit.name),
              child: Text(l10n.profileEditAction),
            ),
        ],
      ),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MessageBanner.info(message: l10n.profileLoadError),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => ref.invalidate(myProfileProvider),
                      child: Text(l10n.retryLabel),
                    ),
                  ],
                ),
              ),
            ),
          ),
          data: (profile) => _ProfileView(profile: profile),
        ),
      ),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView({required this.profile});

  final CandidateProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final completeness = ProfileCompleteness.of(profile);
    final salaryFormat = NumberFormat.decimalPattern('es_AR');

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
                    avatarPath: profile.avatarPath,
                    semanticLabel: l10n.profileAvatarLabel,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.fullName ?? l10n.profileEmptyValue,
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ProfileBadge(
                    label: profile.isPublished
                        ? l10n.profilePublishedBadge
                        : l10n.profileNotPublishedBadge,
                    positive: profile.isPublished,
                  ),
                  ProfileBadge(
                    label: profile.applicationReady
                        ? l10n.profileReadyBadge
                        : l10n.profileNotReadyBadge,
                    positive: profile.applicationReady,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _CompletenessCard(completeness: completeness),
              const SizedBox(height: 24),
              _PresentationCard(status: profile.presentationStatus),
              const SizedBox(height: 24),
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
                      profile.province?.name,
                      profile.locality?.name,
                      profile.neighborhood?.name,
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
                      profile.sector?.name,
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
              ProfileSection(
                title: l10n.profileSectionSchedule,
                children: [
                  if (profile.weeklyAvailability.isEmpty)
                    ProfileValue(
                      value: null,
                      emptyLabel: l10n.profileOptionalEmptyValue,
                    )
                  else
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
              ProfileSection(
                title: l10n.profileSectionSalary,
                children: [
                  ProfileValue(
                    value:
                        profile.expectedSalaryMin != null &&
                            profile.expectedSalaryMax != null
                        ? l10n.profileSalaryRange(
                            salaryFormat.format(profile.expectedSalaryMin),
                            salaryFormat.format(profile.expectedSalaryMax),
                          )
                        : null,
                    emptyLabel: l10n.profileOptionalEmptyValue,
                  ),
                ],
              ),
              ProfileSection(
                title: l10n.profileSectionSkills,
                children: [
                  ProfileChips(
                    values: profile.skills,
                    emptyLabel: l10n.profileEmptyValue,
                  ),
                ],
              ),
              ProfileSection(
                title: l10n.profileSectionLanguages,
                children: [
                  ProfileChips(
                    values: profile.languages,
                    emptyLabel: l10n.profileEmptyValue,
                  ),
                ],
              ),
              ProfileSection(
                title: l10n.profileSectionExperience,
                children: [
                  if (profile.workHistory.isEmpty)
                    ProfileValue(
                      value: null,
                      emptyLabel: l10n.profileEmptyValue,
                    )
                  else
                    for (final entry in profile.workHistory)
                      _ExperienceTile(entry: entry),
                ],
              ),
              ProfileSection(
                title: l10n.profileSectionEducation,
                children: [
                  if (profile.education.isEmpty)
                    ProfileValue(
                      value: null,
                      emptyLabel: l10n.profileOptionalEmptyValue,
                    )
                  else
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

class _ExperienceTile extends StatelessWidget {
  const _ExperienceTile({required this.entry});

  final WorkExperience entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final period = entry.isCurrent
        ? l10n.profileExperienceCurrent(entry.fromMonth)
        : l10n.profileExperiencePeriod(entry.fromMonth, entry.toMonth!);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${entry.position} · ${entry.company}',
            style: theme.textTheme.titleSmall,
          ),
          Text(period, style: theme.textTheme.bodyMedium),
          if (entry.description != null)
            Text(entry.description!, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _CompletenessCard extends StatelessWidget {
  const _CompletenessCard({required this.completeness});

  final ProfileCompleteness completeness;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final score = completeness.score;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.profileCompletenessTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              label: l10n.profileCompletenessValue(score),
              child: ExcludeSemantics(
                child: LinearProgressIndicator(value: score / 100),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.profileCompletenessValue(score),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.profileCompletenessHint,
              style: theme.textTheme.bodySmall,
            ),
            if (completeness.pending.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l10n.profileCompletenessPendingTitle,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              for (final item in completeness.pending)
                Text(
                  '• ${ProfileCopy.completenessItem(l10n, item)}',
                  style: theme.textTheme.bodyMedium,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PresentationCard extends StatelessWidget {
  const _PresentationCard({required this.status});

  final PresentationStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ProfileCopy.presentationStatus(l10n, status),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            // Banner informativo SIN CTA (T-023): el flujo real de video,
            // audio y texto pertenece al Bloque K/T-084 y no se simula.
            Text(
              l10n.profilePresentationOptionalNote,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
