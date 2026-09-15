import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../domain/second_factor.dart';
import '../providers/second_factor_controller.dart';
import 'auth_copy.dart';
import 'widgets/auth_form_widgets.dart';

/// Alta y verificación del segundo factor TOTP (`/admin/segundo-factor`;
/// T-028, avance parcial de T-076).
///
/// Se llega desde la cola de verificaciones cuando la sesión no tiene
/// `aal2`. Al verificar, el estado de sesión cambia solo (mismo usuario, nivel
/// nuevo) y la pantalla vuelve a la cola por nombre de ruta.
///
/// Lo que se ve acá —QR, clave manual, código— vive únicamente en memoria
/// mientras dura el flujo; no se guarda, no se loguea y no viaja por URL. La
/// clave se muestra seleccionable para poder leerla con el teclado y cargarla
/// a mano; la app no la copia sola ni ofrece un botón de copiar. Sí queda el
/// menú de selección del sistema (copiar, compartir): es una acción deliberada
/// de la persona y esconder ese menú no la impediría —`Ctrl+C` sobre la
/// selección copia igual—, así que la clave se protege donde sí se puede, no
/// persistiéndola ni registrándola, no prometiendo un portapapeles cerrado.
///
/// Alcance deliberado: alta y verificación. No hay recuperación por pérdida
/// del autenticador, baja ni reemplazo de un factor verificado, ni códigos de
/// recuperación; la pantalla lo dice en vez de prometer un circuito que no
/// existe.
class SecondFactorScreen extends ConsumerStatefulWidget {
  const SecondFactorScreen({super.key});

  @override
  ConsumerState<SecondFactorScreen> createState() => _SecondFactorScreenState();
}

class _SecondFactorScreenState extends ConsumerState<SecondFactorScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _start();
      }
    });
  }

  /// Idempotente del lado del controller: si el flujo ya arrancó, esta
  /// llamada no crea otro factor. El nombre lleva segundos para que un
  /// reintento dentro del mismo minuto no choque con el alta anterior.
  void _start() {
    final l10n = AppLocalizations.of(context);
    final now = ref.read(clockProvider)();
    ref
        .read(secondFactorControllerProvider.notifier)
        .start(friendlyName: l10n.mfaFriendlyName(AuthCopy.shortDateTime(now)));
  }

  void _backToQueue() => context.goNamed(AppRoute.adminVerifications.name);

  void _cancel() {
    ref.read(secondFactorControllerProvider.notifier).cancel();
    _backToQueue();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final flow = ref.watch(secondFactorControllerProvider);

    ref.listen<SecondFactorFlow>(secondFactorControllerProvider, (_, next) {
      final message = switch (next) {
        SecondFactorVerified() => l10n.mfaVerified,
        SecondFactorAlreadyVerified() => l10n.mfaAlreadyVerified,
        _ => null,
      };
      if (message == null || !context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      _backToQueue();
    });

    return AuthScreenLayout(
      title: l10n.mfaTitle,
      children: [
        switch (flow) {
          SecondFactorIdle() ||
          SecondFactorPreparing() => _Preparing(onBack: _cancel),
          SecondFactorVerified() ||
          SecondFactorAlreadyVerified() => const _Preparing(),
          SecondFactorUnavailable(:final failure) => _Unavailable(
            message: AuthCopy.failure(l10n, failure),
            onRetry: _start,
            onBack: _backToQueue,
          ),
          SecondFactorChoosing(:final factors) => _ChooseFactor(
            factors: factors,
            onBack: _backToQueue,
          ),
          SecondFactorEnrolling() => _Enrollment(
            state: flow,
            onCancel: _cancel,
          ),
          SecondFactorChallenging() => _Challenge(
            state: flow,
            onCancel: _cancel,
          ),
        },
      ],
    );
  }
}

/// Espera anunciada al lector. Con [onBack] ofrece salir mientras el servidor
/// responde: una red lenta no puede dejar a la persona sin ninguna acción.
class _Preparing extends StatelessWidget {
  const _Preparing({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.mfaPreparing)),
            ],
          ),
        ),
        if (onBack != null) ...[
          const SizedBox(height: 24),
          TextButton(onPressed: onBack, child: Text(l10n.mfaCancel)),
        ],
      ],
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthMessageBanner.error(
          title: l10n.mfaUnavailableTitle,
          message: message,
        ),
        FilledButton(onPressed: onRetry, child: Text(l10n.retryLabel)),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onBack, child: Text(l10n.mfaBackToQueue)),
      ],
    );
  }
}

class _ChooseFactor extends ConsumerWidget {
  const _ChooseFactor({required this.factors, required this.onBack});

  final List<SecondFactor> factors;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.mfaChooseTitle, style: theme.textTheme.titleLarge),
        ),
        const SizedBox(height: 8),
        Text(l10n.mfaChooseIntro),
        const SizedBox(height: 16),
        for (final factor in factors) ...[
          OutlinedButton.icon(
            onPressed: () => ref
                .read(secondFactorControllerProvider.notifier)
                .chooseFactor(factor.id),
            icon: const Icon(Icons.phonelink_lock_outlined),
            label: Text(_factorLabel(l10n, factor)),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        TextButton(onPressed: onBack, child: Text(l10n.mfaBackToQueue)),
      ],
    );
  }
}

/// Alta: QR, clave manual y primer código. El campo no toma foco solo: al
/// abrir, lo primero que hay que ver es el QR, no el teclado.
class _Enrollment extends ConsumerWidget {
  const _Enrollment({required this.state, required this.onCancel});

  final SecondFactorEnrolling state;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final enrollment = state.enrollment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.mfaEnrollTitle, style: theme.textTheme.titleLarge),
        ),
        const SizedBox(height: 8),
        Text(l10n.mfaEnrollIntro),
        // El alta anterior venció y esta la reemplaza: hay que decirlo ANTES
        // del QR, porque lo que la persona ya guardó en su autenticador dejó
        // de servir y el código de esa entrada nunca va a ser aceptado.
        if (state.restarted) ...[
          const SizedBox(height: 16),
          AuthMessageBanner.error(
            title: l10n.mfaEnrollRestartedTitle,
            message: l10n.mfaEnrollRestarted,
          ),
        ],
        const SizedBox(height: 16),
        _QrCode(uri: enrollment.uri),
        const SizedBox(height: 16),
        _ManualKey(enrollment: enrollment),
        const SizedBox(height: 16),
        AuthMessageBanner.info(message: l10n.mfaEnrollPendingNote),
        Text(l10n.mfaLimitsNote, style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        _CodeForm(
          state: state,
          submitLabel: l10n.mfaSubmitEnroll,
          autofocus: false,
          onCancel: onCancel,
        ),
      ],
    );
  }
}

/// Desafío sobre un factor que ya está verificado: solo hay que tipear, así
/// que el campo toma foco al abrir.
class _Challenge extends ConsumerWidget {
  const _Challenge({required this.state, required this.onCancel});

  final SecondFactorChallenging state;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.mfaChallengeTitle,
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 8),
        Text(l10n.mfaChallengeIntro(_factorLabel(l10n, state.factor))),
        const SizedBox(height: 16),
        _CodeForm(
          state: state,
          submitLabel: l10n.mfaSubmitVerify,
          autofocus: true,
          onCancel: onCancel,
          extraAction: state.canChooseAnother
              ? TextButton(
                  onPressed: state.isSubmitting
                      ? null
                      : () => ref
                            .read(secondFactorControllerProvider.notifier)
                            .chooseAnother(),
                  child: Text(l10n.mfaChooseAnother),
                )
              : null,
        ),
      ],
    );
  }
}

/// QR dibujado en el cliente a partir de la URI `otpauth://`. Fondo blanco y
/// módulos negros siempre, también en tema oscuro: los lectores de QR
/// necesitan ese contraste y el tema no debe alterarlo.
class _QrCode extends StatelessWidget {
  const _QrCode({required this.uri});

  final String uri;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(240.0, constraints.maxWidth);
        return Center(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: QrImageView(
              data: uri,
              size: size,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              semanticsLabel: l10n.mfaQrSemantics,
            ),
          ),
        );
      },
    );
  }
}

/// Alternativa manual al QR (WCAG: nunca una sola vía). La clave se muestra
/// en bloques de cuatro, se deletrea para el lector de pantalla y es
/// seleccionable (teclado incluido) para cargarla a mano; no se guarda en
/// ningún otro lado.
class _ManualKey extends StatelessWidget {
  const _ManualKey({required this.enrollment});

  final TotpEnrollment enrollment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.mfaManualKeyLabel, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(l10n.mfaManualKeyHelp, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            enrollment.secretGrouped,
            semanticsLabel: l10n.mfaManualKeySemantics(
              enrollment.secretSpelled,
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: 'monospace',
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

/// Campo de código con envío, bloqueo de doble toque y foco de vuelta al
/// campo cuando el servidor rechaza.
class _CodeForm extends ConsumerStatefulWidget {
  const _CodeForm({
    required this.state,
    required this.submitLabel,
    required this.autofocus,
    required this.onCancel,
    this.extraAction,
  });

  final SecondFactorCodeEntry state;
  final String submitLabel;
  final bool autofocus;
  final VoidCallback onCancel;
  final Widget? extraAction;

  @override
  ConsumerState<_CodeForm> createState() => _CodeFormState();
}

class _CodeFormState extends ConsumerState<_CodeForm> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void didUpdateWidget(covariant _CodeForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.factorId != oldWidget.state.factorId) {
      // Cambió el factor: lo que la persona había tipeado era para el
      // anterior y contra este no va a servir nunca. Se borra, así no lo
      // manda sin darse cuenta contra el QR nuevo y se come un rechazo que
      // no explica nada.
      _controller.clear();
    }
    final failure = widget.state.failure;
    if (failure != null && !identical(failure, oldWidget.state.failure)) {
      // El error se anuncia por el cartel (live region) y el foco vuelve al
      // campo con el texto seleccionado para corregir de una (UX_FLOWS §19.2).
      // Después del frame: en este instante el campo todavía está
      // deshabilitado por el envío anterior y no aceptaría el foco.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _focus.requestFocus();
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _focus.requestFocus();
      return;
    }
    ref
        .read(secondFactorControllerProvider.notifier)
        .submitCode(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = widget.state.failure;
    final busy = widget.state.isSubmitting;
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failure != null)
            AuthMessageBanner.error(
              title: l10n.mfaErrorTitle,
              message: AuthCopy.failure(l10n, failure),
            ),
          TextFormField(
            controller: _controller,
            focusNode: _focus,
            enabled: !busy,
            autofocus: widget.autofocus,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              labelText: l10n.mfaCodeLabel,
              helperText: l10n.mfaCodeHelp,
              // Tres líneas: al 200 % en un teléfono angosto la ayuda no
              // entra en dos y se perdería justo la pista de los 30 s.
              helperMaxLines: 3,
              // Lo mismo para el error, que sin esto es UNA línea con elipsis
              // (`errorMaxLines` por defecto es null) y al 200 % se cortaría
              // justo el mensaje que dice cómo corregir.
              errorMaxLines: 3,
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              final text = (value ?? '').trim();
              if (text.isEmpty) {
                return l10n.mfaCodeRequired;
              }
              if (text.length != 6) {
                return l10n.mfaCodeFormat;
              }
              return null;
            },
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          AuthSubmitButton(
            label: widget.submitLabel,
            isLoading: busy,
            onPressed: _submit,
          ),
          if (widget.extraAction != null) ...[
            const SizedBox(height: 8),
            widget.extraAction!,
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: busy ? null : widget.onCancel,
            child: Text(l10n.mfaCancel),
          ),
        ],
      ),
    );
  }
}

/// Rótulo de un factor: su etiqueta si la tiene; si no, un texto del ARB con
/// la fecha de alta para poder distinguirlo. Los factores que crea esta app
/// ya llevan la fecha en la etiqueta, así que no se repite.
String _factorLabel(AppLocalizations l10n, SecondFactor factor) {
  final name = factor.friendlyName;
  if (name != null) {
    return name;
  }
  final created = factor.createdAt;
  if (created == null) {
    return l10n.mfaFactorUnnamed;
  }
  return l10n.mfaFactorUnnamedCreated(AuthCopy.shortDate(created));
}
