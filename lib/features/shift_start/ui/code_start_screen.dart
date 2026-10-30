/// D1 (new) — Start-shift screen for the driver identity (ticket 4,
/// PRD-2 §0.16), M3 flow shell per DESIGN-driver-app.md §9.6, with the
/// ticket-5 welcome-back mode per §9.27.
///
/// One `XX-0000` code field (accepts any case and a missing dash; a bad
/// shape shows the inline error BEFORE any lookup) → confirm card (name,
/// allotted van, ward COUNT, masked phone) → the one black Start Shift
/// pill pinned bottom. Distinct not-found and lookup-failed states, both
/// with retry on the pinned CTA. Every string is localized (CL-D21);
/// colors/spacing/text only through tokens (CL-D02..D04).
///
/// Returning device (§9.27, ticket 5): when the identity controller
/// reports a remembered driver, the screen auto-lookups that code through
/// the same flow (no user tap) and shows the Welcome-back card instead of
/// the entry form — title, body, name, code, live ward count, "Start my
/// Shift" CTA, and a change-code text link below the card. The link drops
/// into the regular entry form (one-way; the remembered code stays until
/// a new confirm overwrites it). A stale remembered code lands in the
/// flow's not-found phase, where the entry form is available again.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/identity/driver_identity_controller.dart';
import '../../../core/models/driver.dart' show maskDriverPhone;import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../features/tracking/tracking_providers.dart'
    show
        trackingEngineProvider,
        trackingPermissionGatewayProvider,
        PermissionApproval;
import '../../../features/tracking/ui/ui_permission_flow.dart'
    show UIPermissionFlowController;
import '../data/shift_tracking_auto_start.dart'
    show
        ShiftTrackingAutoStart,
        ShiftTrackingAutoStartKind,
        shiftTrackingAutoStartStatusProvider;
import '../domain/identity_flow.dart';
import '../domain/shift_session.dart';
import 'language_toggle.dart';

// ignore: implementation_imports
import '../../live_route/live_route_screen.dart';

/// D1-new entry widget. `onShiftStarted` is the navigation seam for tests;
/// the default runs the tracking auto-start (permission flow → engine →
/// outcome surface) and pushes the live route, exactly like the old D1.
class CodeStartScreen extends ConsumerWidget {
  const CodeStartScreen({super.key, this.onShiftStarted});

  final void Function(BuildContext context)? onShiftStarted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(identityFlowProvider);
    if (flow.phase == IdentityFlowPhase.onShift && flow.session != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final live = ref.read(identityFlowProvider);
        if (live.phase != IdentityFlowPhase.onShift || live.session == null) {
          return;
        }
        _runPermissionFlowAndNavigate(
          context,
          ref,
          live.session!,
          onShiftStarted,
        );
      });
    }
    return _CodeStartHost(flow: flow);
  }

  /// The old D1 screen's post-activation pattern, reused verbatim for the
  /// identity flow: run the four-stage permission flow with rationale
  /// screens, start the tracking engine, surface the outcome for D2's
  /// banner, then navigate to the live route.
  static Future<void> _runPermissionFlowAndNavigate(
    BuildContext context,
    WidgetRef ref,
    ShiftSession session,
    void Function(BuildContext context)? onShiftStarted,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final gateway = ref.read(trackingPermissionGatewayProvider);

    final report = await UIPermissionFlowController(gateway, context)
        .requestAll();

    final started = report.allGranted
        ? await ref
            .read(trackingEngineProvider)
            .start(
              tripId: session.tripId,
              vanId: session.vanId,
              notificationTitle: l10n.trackingNotificationTitle,
              notificationBody: l10n.trackingNotificationBody,
            )
            .then((result) => result.isStarted)
        : false;

    final gpsOff = report.results.values
        .any((approval) => approval == PermissionApproval.gpsOff);

    final outcome = ShiftTrackingAutoStart(
      started
          ? ShiftTrackingAutoStartKind.started
          : gpsOff
              ? ShiftTrackingAutoStartKind.gpsOff
              : ShiftTrackingAutoStartKind.denied,
    );
    ref
        .read(shiftTrackingAutoStartStatusProvider.notifier)
        .set(outcome);

    if (context.mounted) {
      if (onShiftStarted != null) {
        onShiftStarted(context);
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => LiveRouteScreen(vanId: session.vanId),
          ),
        );
      }
    }

    // A pop back to D1-new lands on a fresh code entry; the shift itself
    // keeps running in [shiftControllerProvider].
    ref.read(identityFlowProvider.notifier).clearNavigated();
  }
}

/// The M3 content host: headline + code field + phase content, with the
/// one CTA pinned at the bottom. It also owns the ticket-5 welcome-back
/// mode (watching the identity controller and firing the auto-lookup).
class _CodeStartHost extends ConsumerStatefulWidget {
  const _CodeStartHost({required this.flow});

  final IdentityFlowState flow;

  @override
  ConsumerState<_CodeStartHost> createState() => _CodeStartHostState();
}

class _CodeStartHostState extends ConsumerState<_CodeStartHost> {
  final _codeController = TextEditingController();
  final _codeFocus = FocusNode();

  /// The remembered code the welcome auto-lookup was attempted for. The
  /// guard: ONE attempt per remembered code value, so a stale code's
  /// not-found never re-triggers lookups on rebuilds.
  String? _attemptedRememberedCode;

  /// Latched once the driver opts out of the welcome view: taps the
  /// change-code link, or submits a code through the entry form (the
  /// stale-code recovery). One-way for this screen's lifetime — the
  /// welcome card and the auto-lookup never come back after it.
  bool _changeMode = false;

  @override
  void initState() {
    super.initState();
    // The Continue button's enabled state follows the field text (the old
    // D1's onPinChanged idiom: rebuild on every keystroke).
    _codeController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  bool get _busy =>
      widget.flow.phase == IdentityFlowPhase.lookingUp ||
      widget.flow.phase == IdentityFlowPhase.starting;

  /// The returning-device view (ticket 5): the identity controller
  /// reports a remembered driver and the driver has not opted into the
  /// entry form.
  bool _isWelcomeMode(DriverIdentityState identity) =>
      identity.isReturning && !_changeMode;

  /// The welcome-back card is up: the auto-lookup landed on the confirm
  /// phase for the remembered driver (starting keeps the card up while
  /// the start writes run, exactly like the confirm card).
  bool _showsWelcomeCard(DriverIdentityState identity) =>
      _isWelcomeMode(identity) &&
      (widget.flow.phase == IdentityFlowPhase.confirmReady ||
          widget.flow.phase == IdentityFlowPhase.starting);

  /// The pinned CTA carries the welcome action: from a resting welcome
  /// state through the confirm/start phases (startFailed falls back to
  /// the regular confirm-card CTA with its error line).
  bool _welcomeCta(DriverIdentityState identity) =>
      _isWelcomeMode(identity) &&
      switch (widget.flow.phase) {
        IdentityFlowPhase.initial ||
        IdentityFlowPhase.lookingUp ||
        IdentityFlowPhase.confirmReady ||
        IdentityFlowPhase.starting =>
          true,
        _ => false,
      };

  /// The entry form is back: the driver opted in, or the flow landed in a
  /// failure state while welcoming (a stale remembered code, an offline
  /// auto-lookup, a corrupt stored code) — the existing recovery UX
  /// applies and the driver can type a correct code.
  bool _showsEntryForm(DriverIdentityState identity) {
    if (!_isWelcomeMode(identity)) return true;
    return switch (widget.flow.phase) {
      IdentityFlowPhase.notFound ||
      IdentityFlowPhase.lookupFailed ||
      IdentityFlowPhase.invalidCode =>
        true,
      _ => false,
    };
  }

  /// Fires the welcome auto-lookup once per remembered code value, only
  /// from a resting entry phase, after the frame (the navigation
  /// post-frame idiom — no provider mutation during build).
  void _maybeAutoLookup() {
    if (_changeMode) return;
    final identity = ref.read(driverIdentityControllerProvider);
    if (!identity.isReturning) return;
    final code = identity.rememberedCode;
    if (code == null || code.isEmpty) return;
    if (_attemptedRememberedCode == code) return;
    if (ref.read(identityFlowProvider).phase !=
        IdentityFlowPhase.initial) {
      return; // Never over an in-flight or a confirmed flow.
    }
    _attemptedRememberedCode = code;
    ref.read(identityFlowProvider.notifier).submitCode(code);
  }

  /// The change-code link (ticket 5): reveals the regular entry form by
  /// dropping the current confirm context in the flow. One-way; the
  /// remembered code stays until a new confirm overwrites it.
  void _enterChangeMode() {
    if (_changeMode) return;
    setState(() => _changeMode = true);
    ref.read(identityFlowProvider.notifier).resetToEntry();
  }

  /// A manual code submit (the Continue CTA): the driver has taken over
  /// the entry path, so the welcome view never returns this session.
  void _markManualEntry() {
    if (_changeMode) return;
    setState(() => _changeMode = true);
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(driverIdentityControllerProvider);
    if (!_changeMode &&
        identity.isReturning &&
        _attemptedRememberedCode != identity.rememberedCode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeAutoLookup();
      });
    }
    final flow = widget.flow;
    final l10n = AppLocalizations.of(context)!;
    final text = context.text;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Spec story 15: the language toggle stays reachable on the
            // new screens, same top-end slot as the old D1.
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  end: AppSpace.page,
                  top: AppSpace.xs,
                ),
                child: const LanguageToggleButton(),
              ),
            ),
            Expanded(
              // One scroll view for all phases: a small viewport never
              // overflows and the CTA below stays pinned regardless.
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.page, AppSpace.md, AppSpace.page, AppSpace.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.identityStartTitle, style: text.headline),
                    const SizedBox(height: AppSpace.sectionGap),
                    if (_showsWelcomeCard(identity)) ...[
                      _WelcomeCard(
                        flow: flow,
                        code: identity.rememberedCode!,
                      ),
                      _ChangeCodeLink(onTap: _enterChangeMode),
                    ] else ...[
                      if (_showsEntryForm(identity))
                        _CodeField(
                          controller: _codeController,
                          focusNode: _codeFocus,
                          errored: flow.phase == IdentityFlowPhase.invalidCode,
                          enabled: !_busy,
                        ),
                      switch (flow.phase) {
                        IdentityFlowPhase.notFound => const _NotFoundState(),
                        IdentityFlowPhase.lookupFailed =>
                          const _LookupFailedState(),
                        IdentityFlowPhase.confirmReady ||
                        IdentityFlowPhase.starting ||
                        IdentityFlowPhase.startFailed =>
                          _ConfirmCard(flow: flow),
                        _ => const SizedBox.shrink(),
                      },
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _CtaBar(
        flow: flow,
        busy: _busy,
        welcomeCta: _welcomeCta(identity),
        entryRecovery: _isWelcomeMode(identity) &&
            (flow.phase == IdentityFlowPhase.notFound ||
                flow.phase == IdentityFlowPhase.lookupFailed),
        codeText: () => _codeController.text,
        onManualSubmit: _markManualEntry,
      ),
    );
  }
}

/// The single `XX-0000` field (4.5): height 64, radius 20, `surface` fill,
/// 1.5 `borderStrong` outline; error outline + InlineError below on a bad
/// shape. Auto-uppercases and auto-inserts the dash after 2 characters.
class _CodeField extends StatelessWidget {
  const _CodeField({
    required this.controller,
    required this.focusNode,
    required this.errored,
    required this.enabled,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool errored;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final text = context.text;
    final outline = BorderSide(
      color: errored ? colors.error : colors.borderStrong,
      width: 1.5,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.identityCodeLabel, style: text.label),
        const SizedBox(height: AppSpace.sm),
        SizedBox(
          // 3.3: the code field is driver-height 64 (AppSize.buttonDriver).
          height: AppSize.buttonDriver,
          child: TextField(
            key: const ValueKey('d1-code-field'),
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            inputFormatters: [_DriverCodeFormatter()],
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: 7,
            decoration: InputDecoration(
              counterText: '',
              hintText: l10n.identityCodeHint,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.control),
                borderSide: outline,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.control),
                borderSide: errored
                    ? BorderSide(color: colors.error, width: 1.5)
                    : BorderSide(color: colors.brand, width: 2.5),
              ),
            ),
          ),
        ),
        if (errored) ...[
          const SizedBox(height: AppSpace.sm),
          // InlineError (4.15): error icon + bodySmall error text, never
          // color alone.
          Row(
            key: const ValueKey('d1-code-error'),
            children: [
              Icon(Icons.error_outline, size: AppSize.iconSmall, color: colors.error),
              const SizedBox(width: AppSpace.xs),
              Flexible(
                child: Text(
                  l10n.identityCodeError,
                  style: text.bodySmall.copyWith(color: colors.error),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Keeps the entry shaped like `XX-0000`: uppercase, one dash after the
/// two letters, nothing beyond 6 alphanumerics. The flow still normalizes
/// (and rejects) on submit — this is only the typing nicety.
class _DriverCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final compact = newValue.text.toUpperCase().replaceAll('-', '');
    final clamped =
        compact.length > 6 ? compact.substring(0, 6) : compact;
    final formatted = clamped.length <= 2
        ? clamped
        : '${clamped.substring(0, 2)}-${clamped.substring(2)}';
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// The confirm card (4.20 / 9.6): white card radius 28, padding 20, four
/// info rows (name, van, ward count, masked phone), each a leading icon 20
/// + label `titleSmall` + value `body`.
class _ConfirmCard extends StatelessWidget {
  const _ConfirmCard({required this.flow});

  final IdentityFlowState flow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final text = context.text;
    final driver = flow.driver!;
    return Container(
      key: const ValueKey('d1-confirm-card'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpace.lg),
      padding: const EdgeInsets.all(AppSpace.cardPad),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ConfirmRow(
            icon: Icons.person_outline,
            label: l10n.identityFieldName,
            value: driver.name,
          ),
          _ConfirmRow(
            icon: Icons.local_shipping_outlined,
            label: l10n.vanLabel,
            value: flow.vanPlate ?? driver.vanId,
          ),
          _ConfirmRow(
            icon: Icons.map_outlined,
            label: l10n.identityFieldWards,
            value: l10n.identityWardsAllotted(driver.wardIds.length),
          ),
          _ConfirmRow(
            icon: Icons.call_outlined,
            label: l10n.identityFieldPhone,
            value: maskDriverPhone(driver.phone),
          ),
          if (flow.phase == IdentityFlowPhase.startFailed) ...[
            const SizedBox(height: AppSpace.md),
            Row(
              key: const ValueKey('d1-start-error'),
              children: [
                Icon(Icons.error_outline,
                    size: AppSize.iconSmall, color: colors.error),
                const SizedBox(width: AppSpace.xs),
                Flexible(
                  child: Text(
                    l10n.shiftStartFailed,
                    style: text.bodySmall.copyWith(color: colors.error),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One confirm-card row: leading icon 20 + label above value (label-over-
/// value survives the 150%-longer Gujarati strings, CL-D21).
class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppSize.iconSmall, color: colors.textPrimary),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: text.titleSmall.copyWith(color: colors.textMuted),
                ),
                Text(
                  value,
                  style: text.body.copyWith(color: colors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The welcome-back card (4.19 / 9.27, ticket 5): white card radius 28,
/// padding 20 — greeting, body, then the live-fetched record as the same
/// label-over-value rows the confirm card uses (name, code, ward count).
class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.flow, required this.code});

  final IdentityFlowState flow;
  final String code;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final text = context.text;
    final driver = flow.driver!;
    return Container(
      key: const ValueKey('d1-welcome-card'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpace.lg),
      padding: const EdgeInsets.all(AppSpace.cardPad),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.identityWelcomeBackTitle,
            style: text.title.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            l10n.identityWelcomeBackBody,
            style: text.bodySmall.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: AppSpace.sm),
          _ConfirmRow(
            icon: Icons.person_outline,
            label: l10n.identityFieldName,
            value: driver.name,
          ),
          _ConfirmRow(
            icon: Icons.badge_outlined,
            label: l10n.identityCodeLabel,
            value: code,
          ),
          _ConfirmRow(
            icon: Icons.map_outlined,
            label: l10n.identityFieldWards,
            value: l10n.identityWardsAllotted(driver.wardIds.length),
          ),
        ],
      ),
    );
  }
}

/// The change-code option below the welcome card (9.27 "text link" tier of
/// the CTA hierarchy): a full-width, driver-height ink-colored text link,
/// so the one primary pill stays "Start my Shift" (CL-D06/D07).
class _ChangeCodeLink extends StatelessWidget {
  const _ChangeCodeLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final text = context.text;
    return SizedBox(
      key: const ValueKey('d1-change-code'),
      width: double.infinity,
      height: AppSize.buttonDriver,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.identityChangeCode,
              style: text.label.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(width: AppSpace.xs),
            Icon(Icons.chevron_right,
                size: AppSize.iconSmall, color: colors.textPrimary),
          ],
        ),
      ),
    );
  }
}

/// Not-found state (DM-D03 blocking error, Binny-free 4.16): neutral icon
/// in a `brandSoft` circle + title + body. Retry sits on the pinned CTA.
class _NotFoundState extends StatelessWidget {
  const _NotFoundState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _IdentityErrorState(
      stateKey: 'd1-not-found',
      icon: Icons.person_off_outlined,
      title: l10n.identityNotFoundTitle,
      body: l10n.identityNotFoundBody,
    );
  }
}

/// Lookup-failed state (offline/outage): same treatment, connection copy.
class _LookupFailedState extends StatelessWidget {
  const _LookupFailedState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _IdentityErrorState(
      stateKey: 'd1-lookup-failed',
      icon: Icons.cloud_off,
      title: l10n.identityLookupFailedTitle,
      body: l10n.identityLookupFailedBody,
    );
  }
}

class _IdentityErrorState extends StatelessWidget {
  const _IdentityErrorState({
    required this.stateKey,
    required this.icon,
    required this.title,
    required this.body,
  });

  final String stateKey;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    return Container(
      key: ValueKey(stateKey),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sectionGap),
      child: Column(
        children: [
          Container(
            width: AppSize.permissionIconCircle,
            height: AppSize.permissionIconCircle,
            decoration: BoxDecoration(
              color: colors.brandSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: AppSize.icon * 2, color: colors.brand),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            title,
            style: text.title.copyWith(color: colors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            body,
            style: text.body.copyWith(color: colors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// The one primary pill of the M3 shell (CL-D07/D08), label and action
/// following the flow phase. The key swaps with the phase so tests keep
/// stable seams (the old D1's verify/start swap idiom). In the
/// welcome-back mode the pill becomes "Start my Shift" (d1-welcome-start):
/// enabled once the auto-lookup confirms, a waiting spinner while it
/// runs; [onManualSubmit] latches the entry path when the driver submits
/// a code through the Continue CTA.
class _CtaBar extends StatelessWidget {
  const _CtaBar({
    required this.flow,
    required this.busy,
    required this.welcomeCta,
    required this.entryRecovery,
    required this.codeText,
    required this.onManualSubmit,
  });

  final IdentityFlowState flow;
  final bool busy;
  final bool welcomeCta;

  /// Welcome mode sitting in a failure phase (not-found / offline): the
  /// entry form is back and a typed code submits through Continue.
  final bool entryRecovery;
  final String Function() codeText;
  final VoidCallback onManualSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (flow.phase == IdentityFlowPhase.onShift) return const SizedBox.shrink();

    final VoidCallback? onPressed;
    final String label;
    final String ctaKey;
    switch (flow.phase) {
      case IdentityFlowPhase.confirmReady:
      case IdentityFlowPhase.startFailed:
      case IdentityFlowPhase.starting:
        // The welcome start IS the confirm-card start (same flow start()).
        onPressed =
            busy ? null : () => _flowOf(context).start();
        label = welcomeCta ? l10n.identityStartMyShift : l10n.startShift;
        ctaKey = welcomeCta ? 'd1-welcome-start' : 'd1-confirm-start';
      case IdentityFlowPhase.notFound:
      case IdentityFlowPhase.lookupFailed:
        // Welcome-mode recovery (ticket 5): a typed code submits through
        // Continue; an empty field keeps the retry of the remembered /
        // failed code (the existing not-found and offline seams).
        if (entryRecovery && codeText().trim().isNotEmpty) {
          onPressed = () {
            onManualSubmit();
            _flowOf(context).submitCode(codeText());
          };
          label = l10n.identityCodeContinue;
          ctaKey = 'd1-code-continue';
        } else {
          onPressed = () => _flowOf(context).retry();
          label = l10n.retry;
          ctaKey = flow.phase == IdentityFlowPhase.notFound
              ? 'd1-not-found-retry'
              : 'd1-lookup-failed-retry';
        }
      case IdentityFlowPhase.initial:
      case IdentityFlowPhase.invalidCode:
      case IdentityFlowPhase.lookingUp:
        if (welcomeCta) {
          // The auto-lookup owns the flow; the pill waits as Start my
          // Shift (spinner while the lookup runs).
          onPressed = null;
          label = l10n.identityStartMyShift;
          ctaKey = 'd1-welcome-start';
        } else {
          final hasText = codeText().trim().isNotEmpty;
          onPressed = busy || !hasText
              ? null
              : () {
                  onManualSubmit();
                  _flowOf(context).submitCode(codeText());
                };
          label = l10n.identityCodeContinue;
          ctaKey = 'd1-code-continue';
        }
      case IdentityFlowPhase.onShift:
        onPressed = null;
        label = l10n.startShift;
        ctaKey = 'd1-confirm-start';
    }

    final child = busy
        ? const SizedBox(
            width: AppSize.iconSmall + AppSpace.xs,
            height: AppSize.iconSmall + AppSpace.xs,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label),
              const SizedBox(width: AppSpace.sm),
              const Icon(Icons.arrow_forward, size: AppSize.iconSmall),
            ],
          );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.page,
        AppSpace.sm,
        AppSpace.page,
        AppSpace.md,
      ),
      child: SizedBox(
        height: AppSize.buttonDriver,
        width: double.infinity,
        child: FilledButton(
          key: ValueKey(ctaKey),
          onPressed: onPressed,
          child: child,
        ),
      ),
    );
  }

  IdentityFlowController _flowOf(BuildContext context) =>
      ProviderScope.containerOf(context).read(identityFlowProvider.notifier);
}
