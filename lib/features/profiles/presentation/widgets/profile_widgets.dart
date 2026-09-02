import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/profile_providers.dart';

/// Sección del perfil con encabezado semántico.
class ProfileSection extends StatelessWidget {
  const ProfileSection({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

/// Valor simple de una sección; muestra un texto neutro cuando falta.
class ProfileValue extends StatelessWidget {
  const ProfileValue({
    required this.value,
    required this.emptyLabel,
    super.key,
  });

  final String? value;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = value != null && value!.trim().isNotEmpty;
    return Text(
      hasValue ? value! : emptyLabel,
      style: hasValue
          ? theme.textTheme.bodyLarge
          : theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
    );
  }
}

/// Lista de valores como chips de solo lectura.
class ProfileChips extends StatelessWidget {
  const ProfileChips({
    required this.values,
    required this.emptyLabel,
    super.key,
  });

  final List<String> values;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return ProfileValue(value: null, emptyLabel: emptyLabel);
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final value in values) Chip(label: Text(value))],
    );
  }
}

/// Avatar circular con URL firmada de corta vida (T-022). Si no hay foto o la
/// URL falla, muestra el ícono neutro: la foto es opcional y jamás penaliza.
class ProfileAvatar extends ConsumerWidget {
  const ProfileAvatar({
    required this.avatarPath,
    required this.semanticLabel,
    this.radius = 40,
    super.key,
  });

  final String? avatarPath;
  final String semanticLabel;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeholder = CircleAvatar(
      radius: radius,
      child: Icon(Icons.person_outline, size: radius),
    );
    final path = avatarPath;
    if (path == null) {
      return Semantics(image: true, label: semanticLabel, child: placeholder);
    }
    final signedUrl = ref.watch(avatarSignedUrlProvider(path));
    return Semantics(
      image: true,
      label: semanticLabel,
      child: signedUrl.when(
        data: (url) => CircleAvatar(
          radius: radius,
          foregroundImage: NetworkImage(url),
          onForegroundImageError: (_, _) {},
          child: Icon(Icons.person_outline, size: radius),
        ),
        loading: () => placeholder,
        error: (_, _) => placeholder,
      ),
    );
  }
}

/// Distintivo de estado (publicado / listo para postularse) con ícono además
/// de color, para no depender solo del color (UX_FLOWS §20).
class ProfileBadge extends StatelessWidget {
  const ProfileBadge({required this.label, required this.positive, super.key});

  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(
        positive ? Icons.check_circle_outline : Icons.info_outline,
        size: 18,
        color: positive ? scheme.primary : scheme.onSurfaceVariant,
      ),
      label: Text(label),
    );
  }
}
