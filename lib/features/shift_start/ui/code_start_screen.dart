/// D1 (new) — Start-shift screen for the driver identity (ticket 4,
/// PRD-2 §0.16), M3 flow shell per DESIGN-driver-app.md §9.6, with the
/// ticket-5 welcome-back mode per §9.27 and the ticket-10 smart keyboard
/// on the code field (pure decisions in code_keyboard.dart).
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
import 'code_keyboard.dart';
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
    // Tapping the boxes re-focuses the hidden field (the row's tap seam).
    // On a result phase that means "I want to fix the code": flip back to
    // editing so the search button returns (demo feedback 10/2026).
    _codeFocus.addListener(() {
      if (mounted && _codeFocus.hasFocus && !_editing) {
        setState(() => _editing = true);
      }
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

  /// True while the driver is editing the code (fresh entry, or re-entry
  /// after tapping the boxes on a result). False once a search lands on a
  /// result phase: the boxes sit unfocused and the CTA carries the result
  /// action (Start / Retry) per the demo feedback 10/2026.
  bool _editing = true;

  @override
  void didUpdateWidget(_CodeStartHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newPhase = widget.flow.phase;
    // Compare state INSTANCES, not phases: a re-search coalesces
    // confirmReady → lookingUp → confirmReady between frames, and a
    // phase-only check would miss the fresh landing (the card would stay
    // hidden while editing).
    if (identical(oldWidget.flow, widget.flow)) return;
    switch (newPhase) {
      case IdentityFlowPhase.initial:
        // A fresh entry (change-code reset, post-shift return): editing
        // from the start.
        _setEditing(true);
      case IdentityFlowPhase.confirmReady:
      case IdentityFlowPhase.starting:
      case IdentityFlowPhase.startFailed:
      case IdentityFlowPhase.notFound:
      case IdentityFlowPhase.lookupFailed:
        // A search landed: drop focus (the demo asked for the boxes out of
        // focus after the search) and hand the CTA to the result action.
        _setEditing(false);
        _codeFocus.unfocus();
        _maybePrefillRememberedCode(newPhase);
      default:
        break; // lookingUp / invalidCode / onShift keep the current mode.
    }
  }

  void _setEditing(bool editing) {
    if (_editing == editing) return;
    setState(() => _editing = editing);
  }

  /// An auto-lookup (welcome back) failed or hit an unknown code: the
  /// driver saw an error about a code they never typed. Fill the boxes
  /// with the remembered code so they SEE what was checked and can edit it
  /// (the launch-time "Couldn't check the code" demo report 10/2026).
  void _maybePrefillRememberedCode(IdentityFlowPhase phase) {
    if (phase != IdentityFlowPhase.notFound &&
        phase != IdentityFlowPhase.lookupFailed) {
      return;
    }
    if (_changeMode || _codeController.text.isNotEmpty) return;
    final identity = ref.read(driverIdentityControllerProvider);
    final code = identity.rememberedCode;
    if (code == null || code.isEmpty) return;
    _codeController.text = code;
  }

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

  /// The change-code back seam (demo feedback 10/2026): the new-user form
  /// is reachable BACK to the welcome card, by the top-left button or the
  /// system back gesture. The flow drops to a resting entry and the
  /// welcome auto-lookup is allowed to run again for the remembered code,
  /// so the card re-lands exactly like on launch.
  void _exitChangeMode() {
    if (_busy) return; // Never mid-lookup or mid-start.
    setState(() => _changeMode = false);
    ref.read(identityFlowProvider.notifier).resetToEntry();
    _attemptedRememberedCode = null;
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
    final colors = context.colors;
    final scaffold = Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Spec story 15: the language toggle stays reachable on the
            // new screens, same top-end slot as the old D1. In change-code
            // mode a back button sits at the top-start (page margin, level
            // with the toggle and the headline) so the new-user detour is
            // reversible (demo feedback 10/2026).
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppSpace.page,
                end: AppSpace.page,
                top: AppSpace.xs,
              ),
              child: Row(
                children: [
                  if (_changeMode)
                    SizedBox(
                      width: AppSize.iconButtonDriver,
                      height: AppSize.iconButtonDriver,
                      child: IconButton(
                        key: const ValueKey('d1-change-back'),
                        onPressed: _busy ? null : _exitChangeMode,
                        icon: const Icon(Icons.arrow_back),
                        color: colors.textPrimary,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  const Spacer(),
                  const LanguageToggleButton(),
                ],
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
                          // Editing hides the card: the driver is changing
                          // the code and the search CTA takes over (demo
                          // feedback 10/2026).
                          _editing
                              ? const SizedBox.shrink()
                              : _ConfirmCard(flow: flow),
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
        editing: _editing,
        codeText: () => _codeController.text,
        onManualSubmit: _markManualEntry,
      ),
    );

    // System back inside the change-code form returns to the welcome card
    // instead of leaving the app (demo feedback 10/2026). Outside
    // change-code mode the default applies.
    return PopScope(
      canPop: !_changeMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitChangeMode();
      },
      child: scaffold,
    );
  }
}

/// The `XX-0000` entry (4.5, amended by the driver demo feedback 10/2026:
/// OTP-style boxes instead of one input pill). Label + a row of six focused
/// cells — one box per character: 2 letter boxes, the pre-rendered `-`
/// (NOT a box itself — the driver never types it), then 4 digit boxes —
/// with the inline error below on a bad shape.
///
/// The editing model is unchanged on purpose: the real TextField keeps the
/// `d1-code-field` seam (formatter, paste, backspace-safe dash per ticket
/// 10) but is painted transparent behind the boxes and ignore-pointer'd —
/// the row tap just focuses it, so typing stays append-at-the-caret-end
/// exactly as the formatter enforces. The keyboard type is the pure
/// content decision [codeFieldKeyboardType] (ticket 10); the host
/// rebuilds on every keystroke, which repaints the boxes.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.identityCodeLabel, style: context.text.label),
        const SizedBox(height: AppSpace.sm),
        _CodeBoxes(
          controller: controller,
          focusNode: focusNode,
          errored: errored,
          enabled: enabled,
          hint: l10n.identityCodeHint,
        ),
        if (errored) ...[
          const SizedBox(height: AppSpace.sm),
          // InlineError (4.15): error icon + bodySmall error text, never
          // color alone.
          Row(
            key: const ValueKey('d1-code-error'),
            children: [
              Icon(Icons.error_outline, size: AppSize.iconSmall, color: context.colors.error),
              const SizedBox(width: AppSpace.xs),
              Flexible(
                child: Text(
                  l10n.identityCodeError,
                  style: context.text.bodySmall.copyWith(color: context.colors.error),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The visible box row behind the [TextField]: one cell per character of
/// the 6-char alphanumeric entry, the `-` rendered as plain text (no box —
/// it is never typed, it pre-reads `XX-0000`).
class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({
    required this.controller,
    required this.focusNode,
    required this.errored,
    required this.enabled,
    required this.hint,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool errored;
  final bool enabled;
  final String hint;

  /// Box structure: 2 letter cells + the pre-rendered dash + 4 digit
  /// cells (D-104's 7 visible slots carry over; the driver's demo feedback
  /// 2026-10-30 splits the flat field into OTP boxes and keeps the dash
  /// as plain text — never a typed box).
  ///
  /// Dimensions from the DESIGN-driver-app.md rules, no invented values:
  /// cell size = [AppSize.codeBox] (§2.3 driver sizes, the dedicated code
  /// box token), cell radius = [AppRadius.control] (inputs 20 dp rule,
  /// the same radius §4.5 pinned on the flat field), outline 1.5
  /// `borderStrong` (escalated `error` on a bad shape, brand 2.5 on the
  /// active cell), fill `surface`, per-box text `text.headline`.
  static const _letterCells = 2;
  static const _cellCount = 6;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    // Painted content: the alphanumeric characters in order — the dash
    // never consumes a cell. A bad shape ('A1') still shows its characters
    // in the natural order (identical to the old flat field), and the
    // inline error explains the shape on submit.
    final chars = alnumEntryOf(controller.text).split('');

    // The ACTIVE cell (the next keystroke's landing spot; the formatter
    // keeps the caret at the end, so this is derived from the content,
    // not the caret position).
    final int? activeIndex =
        focusNode.hasFocus && !errored && chars.length < 6 ? chars.length : null;
    final Color borderColor = errored ? colors.error : colors.borderStrong;

    Widget cell(int index) {
      final filled = index < chars.length;
      return Container(
        // The first cell doubles as the tap-test seam for the edit cycle.
        key: index == 0 ? const ValueKey('d1-code-cell-0') : null,
        width: AppSize.codeBox,
        height: AppSize.codeBox,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(
            color: index == activeIndex ? colors.brand : borderColor,
            width: index == activeIndex ? 2.5 : 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          filled ? chars[index] : '',
          style: text.headline.copyWith(color: colors.textPrimary),
        ),
      );
    }

    return Semantics(
      hint: hint,
      child: GestureDetector(
        onTap: enabled ? focusNode.requestFocus : null,
        child: ExcludeSemantics(
          child: Stack(
            key: const ValueKey('d1-code-boxes'),
            alignment: Alignment.center,
            children: [
              // The visible row: 2 letter cells + pre-rendered dash (plain
              // text) + 4 digit cells. Fixed 56 dp cells per
              // DESIGN-driver-app.md §2.3 codeBox token. The natural row
              // (~380 dp) exceeds a 360 dp screen, so FittedBox scales the
              // whole row down proportionally instead of overflowing
              // (the 73 px overflow band seen on the device).
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    cell(0),
                    for (var i = 1; i < _cellCount; i++) ...[
                      if (i == _letterCells)
                        // The dash is pre-rendered text, NOT a box (driver
                        // demo feedback: "dash pe box mat rakhna, vo pehle
                        // se wahi hoga").
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.sm,
                          ),
                          child: Text(
                            '-',
                            style: text.headline.copyWith(
                              color: colors.textMuted,
                              height: 1,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: AppSpace.sm),
                      cell(i),
                    ],
                  ],
                ),
              ),
              // The real entry (seam `d1-code-field`, ticket 10
              // keyboard-flip + dash brain): painted transparent and
              // ignore-pointer'd (the row tap above handles focus), so the
              // IME behaviour — paste, backspace walk, per-keystroke flip —
              // is EXACTLY the tested one.
              Positioned.fill(
                child: IgnorePointer(
                  child: TextField(
                    key: const ValueKey('d1-code-field'),
                    controller: controller,
                    focusNode: focusNode,
                    enabled: enabled,
                    inputFormatters: [const DriverCodeInputFormatter()],
                    keyboardType: codeFieldKeyboardType(controller.text),
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    enableSuggestions: false,
                    maxLength: 7,
                    cursorColor: Colors.transparent,
                    style: const TextStyle(color: Colors.transparent),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: false,
                      hintText: hint,
                      // None ALL border states: the app decorationTheme
                      // paints an OutlineInputBorder on any unspecified
                      // state, and an unspecified border on the invisible
                      // field painted the stray full-width pill outline
                      // over the boxes (the driver's "big border" report).
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      hintStyle: const TextStyle(
                        color: Colors.transparent,
                        height: 0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

/// Not-found state (DM-D03 blocking error, §4.16): neutral icon in a
/// `brandSoft` circle + title + body. Retry sits on the pinned CTA.
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
    required this.editing,
    required this.codeText,
    required this.onManualSubmit,
  });

  final IdentityFlowState flow;
  final bool busy;
  final bool welcomeCta;

  /// Welcome mode sitting in a failure phase (not-found / offline): the
  /// entry form is back and a typed code submits through Continue.
  final bool entryRecovery;

  /// The driver is editing the code (fresh entry, or re-entry by tapping
  /// the boxes on a result): the search (Continue) CTA rules apply instead
  /// of the result action, per the demo feedback 10/2026.
  final bool editing;
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
        if (!welcomeCta && editing) {
          // The driver tapped the boxes on a result card: the search
          // button returns with the code in view (demo feedback 10/2026).
          final hasText = codeText().trim().isNotEmpty;
          onPressed = busy || !hasText
              ? null
              : () {
                  onManualSubmit();
                  _flowOf(context).submitCode(codeText());
                };
          label = l10n.identityCodeContinue;
          ctaKey = 'd1-code-continue';
        } else {
          // The welcome start IS the confirm-card start (same flow start()).
          onPressed = busy ? null : () => _flowOf(context).start();
          label = welcomeCta ? l10n.identityStartMyShift : l10n.startShift;
          ctaKey = welcomeCta ? 'd1-welcome-start' : 'd1-confirm-start';
        }
      case IdentityFlowPhase.notFound:
      case IdentityFlowPhase.lookupFailed:
        // Welcome-mode recovery (ticket 5) or a box-tap edit on a manual
        // failure: a typed code submits through Continue; an empty field
        // keeps the retry of the remembered / failed code (the existing
        // not-found and offline seams).
        if ((entryRecovery || editing) && codeText().trim().isNotEmpty) {
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
