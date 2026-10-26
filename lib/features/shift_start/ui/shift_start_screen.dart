/// D1 — Shift Start screen (F-D1, ticket 04), M3 flow shell per DESIGN.md
/// §9.8 and the Safai Sathi wireframes (WF-2/WF-3).
///
/// Driver picks a van (public `vans` doc), sees the route as a read-only
/// chip, enters the 4-digit PIN into four boxes, and taps the one dark CTA
/// pinned at the bottom. Loading state shows skeleton van rows (0.11);
/// error states surface inline under the fields. Every string is
/// localized (CL-21); buttons ≥ 56/64 dp come from `AppTheme` (0.5).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/skeleton.dart';
import '../domain/shift_flow.dart';
import 'basic_route_placeholder.dart';
import 'language_toggle.dart';

/// D1 entry widget. `onShiftStarted` defaults to pushing the route
/// placeholder (ticket 05 will replace the destination).
class ShiftStartScreen extends ConsumerWidget {
  const ShiftStartScreen({super.key, this.onShiftStarted});

  /// Navigation seam for tests; default: `pushReplacement` to the
  /// BasicRoute placeholder.
  final void Function(BuildContext context)? onShiftStarted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(shiftStartFlowProvider);
    if (flow.phase == ShiftFlowPhase.loadingVans) {
      // Idempotent first-load kick; retries go through the Retry button.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.context.mounted) {
          ref.read(shiftStartFlowProvider.notifier).ensureVansLoaded();
        }
      });
    }
    if (flow.phase == ShiftFlowPhase.onShift && flow.session != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        if (onShiftStarted != null) {
          onShiftStarted!(context);
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => const BasicRoutePlaceholder(),
            ),
          );
        }
        // Drop the sticky `onShift` phase so a pop back to D1 re-enters
        // the picker instead of firing the navigation again.
        ref.read(shiftStartFlowProvider.notifier).clearNavigated();
      });
    }
    return _OneCtaFlowHost(flow: flow, onShiftStarted: onShiftStarted);
  }
}

/// The M3 content host: headline + fields + the CTA pinned at the
/// bottom, with one PIN controller shared by the boxes and the CTA.
class _OneCtaFlowHost extends StatefulWidget {
  const _OneCtaFlowHost({required this.flow, this.onShiftStarted});

  final ShiftFlowState flow;
  final void Function(BuildContext context)? onShiftStarted;

  @override
  State<_OneCtaFlowHost> createState() => _OneCtaFlowHostState();
}

class _OneCtaFlowHostState extends State<_OneCtaFlowHost> {
  final _pinController = TextEditingController();
  final _pinFocus = FocusNode();

  bool get _busy =>
      widget.flow.phase == ShiftFlowPhase.verifyingPin ||
      widget.flow.phase == ShiftFlowPhase.startingShift;

  bool get _pickerPhase =>
      widget.flow.phase == ShiftFlowPhase.pickVan ||
      widget.flow.phase == ShiftFlowPhase.verifyingPin ||
      widget.flow.phase == ShiftFlowPhase.readyToStart ||
      widget.flow.phase == ShiftFlowPhase.startingShift;

  @override
  void initState() {
    super.initState();
    // A fresh van selection resets the digits.
    var lastVanId = widget.flow.selectedVanId;
    _pinController.addListener(() {
      if (widget.flow.selectedVanId != lastVanId) {
        lastVanId = widget.flow.selectedVanId;
        _pinController.clear();
      }
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flow = widget.flow;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // F-D10 (ticket 13): the language toggle lives at the top end.
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
                    Text(
                      l10n.shiftStartTitle,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpace.md),
                    switch (flow.phase) {
                      ShiftFlowPhase.loadingVans ||
                      ShiftFlowPhase.onShift =>
                        const SkeletonVanCard(height: 72),
                      ShiftFlowPhase.vanListFailed => const _VanListError(),
                      ShiftFlowPhase.pickVan ||
                      ShiftFlowPhase.verifyingPin ||
                      ShiftFlowPhase.readyToStart ||
                      ShiftFlowPhase.startingShift =>
                        flow.vans.isEmpty
                            ? _EmptyVans()
                            : _VanPicker(
                                flow: flow,
                                pinController: _pinController,
                                pinFocus: _pinFocus,
                                onPinChanged: () => setState(() {}),
                              ),
                    },
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // The M3 CTA bar: one dark pill pinned bottom (§9.8 / CTA-bar rule).
      bottomNavigationBar: _CtaBar(
        flow: flow,
        busy: _busy,
        pickerPhase: _pickerPhase,
        pinController: _pinController,
      ),
    );
  }
}

/// Van rows (optional), the route chip for the picked van, and the PIN
/// boxes. `vans` is never empty here (empty handled in the host).
class _VanPicker extends StatelessWidget {
  const _VanPicker({
    required this.flow,
    required this.pinController,
    required this.pinFocus,
    required this.onPinChanged,
  });

  final ShiftFlowState flow;
  final TextEditingController pinController;
  final FocusNode pinFocus;
  final VoidCallback onPinChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final selected = flow.vans
        .where((entry) => entry.van.id == flow.selectedVanId)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Van label + rows (WF-2) ---
        Text(l10n.vanLabel, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpace.sm),
        for (final entry in flow.vans)
          _VanRow(
            entry: entry,
            selected:
                selected.isNotEmpty && entry.van.id == flow.selectedVanId,
          ),
        if (selected.isEmpty) ...[
          const SizedBox(height: AppSpace.md),
          Text(
            AppLocalizations.of(context)!.pickVanPrompt,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
        // --- Route chip + PIN section only once a van is picked ---
        if (selected.isNotEmpty) ...[
          const SizedBox(height: AppSpace.md),
          Text(l10n.routeLabel, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpace.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.md, vertical: AppSpace.sm + 2,
            ),
            decoration: BoxDecoration(
              color: colors.brandSoft,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              selected.first.routeName == null
                  ? l10n.routeUnknown
                  : '${selected.first.routeName} '
                      '${l10n.routeSetByAdmin}',
              style: Theme.of(context).textTheme.labelLarge!.copyWith(
                    color: colors.brand,
                  ),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Text(l10n.pinLabel, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpace.sm),
          _PinField(
            pinController: pinController,
            pinFocus: pinFocus,
            onChanged: onPinChanged,
          ),
          if (flow.failure != null) ...[
            const SizedBox(height: AppSpace.sm),
            _PinError(flow: flow),
          ],
          if (flow.phase == ShiftFlowPhase.readyToStart ||
              flow.phase == ShiftFlowPhase.startingShift) ...[
            const SizedBox(height: AppSpace.sm),
            Text(
              l10n.readyToStartInfo,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ],
      ],
    );
  }
}

/// One van row: outlined field row (truck icon + plate), selected row
/// fills `brandSoft`. ≥56 dp tall (big hit-target rule).
class _VanRow extends StatelessWidget {
  const _VanRow({required this.entry, required this.selected});

  final VanPickerEntry entry;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      child: Material(
        color: selected ? colors.brandSoft : theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: BorderSide(
            color: selected
                ? Colors.transparent
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.control),
          onTap: () => ProviderScope.containerOf(context)
              .read(shiftStartFlowProvider.notifier)
              .selectVan(entry.van.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.md, vertical: AppSpace.sm + 4,
            ),
            child: Row(
              children: [
                const Icon(Icons.local_shipping, size: 20),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Text(
                    key: ValueKey<String>('van-tile-${entry.van.id}'),
                    entry.van.plateNo,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                // Unselected rows keep the route line as their subtitle;
                // the route chip appears only for the selected van.
                if (!selected)
                  Text(
                    entry.routeName == null
                        ? l10n.routeUnknown
                        : '${l10n.routeLabel}: ${entry.routeName}',
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The four PIN boxes (WF-2): an invisible TextField captures the
/// digits so the real input stays a platform TextField (a11y, autofill
/// and the existing `d1-pin-field` test key), painted as dots below.
class _PinField extends ConsumerWidget {
  const _PinField({
    required this.pinController,
    required this.pinFocus,
    required this.onChanged,
  });

  final TextEditingController pinController;
  final FocusNode pinFocus;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final flow = ref.watch(shiftStartFlowProvider);
    final errored = flow.failure == ShiftFlowFailure.wrongPin ||
        flow.failure == ShiftFlowFailure.lockedOut;
    final busy =
        flow.phase == ShiftFlowPhase.verifyingPin ||
            flow.phase == ShiftFlowPhase.startingShift;
    final text = pinController.text;

    Widget box(int i, {required bool caret}) {
      return Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: errored
                ? AppTheme.colorStatusEscalated
                : caret
                    ? colors.brandMid
                    : theme.colorScheme.outlineVariant,
            width: caret || errored ? 1.6 : 1,
          ),
        ),
        child: i < text.length
            // A dot, never the digit — the PIN renders nowhere.
            ? Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface,
                  shape: BoxShape.circle,
                ),
              )
            : caret && !busy
                ? Container(width: 3, height: 22, color: colors.brandMid)
                : null,
      );
    }

    return GestureDetector(
      onTap: () => pinFocus.requestFocus(),
      child: Stack(
        children: [
          Row(
            children: [
              for (var i = 0; i < 4; i++)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                      end: AppSpace.unit * 2),
                  child: box(i, caret: text.length == i),
                ),
            ],
          ),
          // The real editable field, invisible but focusable — the same
          // `d1-pin-field` key tests (and any autofill) already target.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                key: const ValueKey('d1-pin-field'),
                controller: pinController,
                focusNode: pinFocus,
                decoration: const InputDecoration(counterText: ''),
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                enabled: !busy,
                onChanged: (_) => onChanged(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wrong PIN / lockout / unreachable-server line under the boxes (WF-3).
class _PinError extends StatelessWidget {
  const _PinError({required this.flow});

  final ShiftFlowState flow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final message = switch (flow.failure) {
      ShiftFlowFailure.wrongPin => l10n.wrongPin,
      ShiftFlowFailure.lockedOut => l10n.pinLockedOut,
      ShiftFlowFailure.verifyUnavailable => l10n.verificationUnavailable,
      ShiftFlowFailure.startFailed => l10n.shiftStartFailed,
      null => null,
    };
    if (message == null) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(
          Icons.error_outline,
          size: 16,
          color: AppTheme.colorStatusEscalated,
        ),
        const SizedBox(width: AppSpace.xs),
        Flexible(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: AppTheme.colorStatusEscalated,
                ),
          ),
        ),
      ],
    );
  }
}

/// The one dark CTA of the M3 shell, pinned bottom (§9.8 / CTA-bar
/// rule). Label and action follow the flow phase; hidden entirely on
/// loading/error/empty phases.
class _CtaBar extends StatelessWidget {
  const _CtaBar({
    required this.flow,
    required this.busy,
    required this.pickerPhase,
    required this.pinController,
  });

  final ShiftFlowState flow;
  final bool busy;
  final bool pickerPhase;
  final TextEditingController pinController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    if (!pickerPhase) return const SizedBox.shrink();

    final verified = flow.phase == ShiftFlowPhase.readyToStart ||
        flow.phase == ShiftFlowPhase.startingShift;

    final VoidCallback? onPressed;
    final String label;
    if (busy) {
      onPressed = null;
      label = verified ? l10n.startShift : l10n.verifyPin;
    } else if (verified) {
      onPressed = () => ProviderScope.containerOf(context)
          .read(shiftStartFlowProvider.notifier)
          .startShift();
      label = flow.resumable ? l10n.resumeShift : l10n.startShift;
    } else {
      final pin = pinController.text;
      onPressed = pin.length == 4
          ? () => ProviderScope.containerOf(context)
              .read(shiftStartFlowProvider.notifier)
              .submitPin(pin)
          : null;
      label = l10n.verifyPin;
    }

    final child = busy
        ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: theme.textTheme.titleMedium!.copyWith(
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              const Icon(Icons.arrow_forward, size: 20),
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
          // The same pill carries the flow's two real actions; the
          // key that swaps keeps the existing two-step widget tests
          // and test harnesses working verbatim.
          key: ValueKey(verified ? 'd1-start-button' : 'd1-verify-button'),
          onPressed: onPressed,
          child: child,
        ),
      ),
    );
  }
}

/// Van-list read failed (emulator/instance down → degraded state, 0.11).
class _VanListError extends ConsumerWidget {
  const _VanListError();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.cloud_off, size: 48),
        const SizedBox(height: AppSpace.unit * 2),
        Text(l10n.vanListError, textAlign: TextAlign.center),
        const SizedBox(height: AppSpace.unit * 2),
        OutlinedButton(
          onPressed: () =>
              ref.read(shiftStartFlowProvider.notifier).retry(),
          child: Text(l10n.retry),
        ),
      ],
    );
  }
}

/// No van is assigned to this driver's account yet.
class _EmptyVans extends StatelessWidget {
  const _EmptyVans();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.unit * 2),
      child: Text(
        l10n.vansEmpty,
        textAlign: TextAlign.center,
      ),
    );
  }
}
