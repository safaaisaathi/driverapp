/// D1 — Shift Start screen (F-D1, ticket 04).
///
/// Driver picks a van (public `vans` doc with the assigned route name),
/// enters the 4-digit PIN, and taps Start. Loading, empty, error and
/// offline/degraded states everywhere (0.11). Buttons ≥ 56 dp come from
/// `AppTheme` (0.5 / contract section 6). Every string is localized.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
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
    return Scaffold(
      // F-D10 (ticket 13): a slim always-on row at the top end holds the
      // language toggle — visible on every D1 phase, one hand's reach,
      // never fighting the picker for attention.
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Align(
              alignment: AlignmentDirectional.topEnd,
              heightFactor: 1,
              child: const Padding(
                padding: EdgeInsetsDirectional.only(
                  end: AppTheme.spacingUnit * 2,
                ),
                child: LanguageToggleButton(),
              ),
            ),
          ),
          Expanded(
            child: switch (flow.phase) {
              ShiftFlowPhase.loadingVans => const _VanListLoading(),
              ShiftFlowPhase.vanListFailed => const _VanListError(),
              ShiftFlowPhase.onShift => const _VanListLoading(),
              ShiftFlowPhase.pickVan ||
              ShiftFlowPhase.verifyingPin ||
              ShiftFlowPhase.readyToStart ||
              ShiftFlowPhase.startingShift =>
                const _VanPicker(),
            },
          ),
        ],
      ),
    );
  }
}

class _VanListLoading extends StatelessWidget {
  const _VanListLoading();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppTheme.spacingUnit * 2),
          Text(l10n.loading),
        ],
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 48),
          const SizedBox(height: AppTheme.spacingUnit * 2),
          Text(l10n.vanListError, textAlign: TextAlign.center),
          const SizedBox(height: AppTheme.spacingUnit * 2),
          OutlinedButton(
            onPressed: () => ref.read(shiftStartFlowProvider.notifier).retry(),
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}

/// Empty vs filled van list, with the PIN entry under the picked van.
class _VanPicker extends ConsumerWidget {
  const _VanPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(shiftStartFlowProvider);
    final l10n = AppLocalizations.of(context)!;
    if (flow.vans.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.spacingUnit * 2),
        child: Center(
          child: Text(l10n.vansEmpty, textAlign: TextAlign.center),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingUnit * 2),
      children: [
        Text(
          l10n.pickVanPrompt,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppTheme.spacingUnit),
        for (final entry in flow.vans)
          _VanTile(
            entry: entry,
            selected: entry.van.id == flow.selectedVanId,
            showPinEntry: flow.selectedVanId == entry.van.id,
            flow: flow,
          ),
      ],
    );
  }
}

class _VanTile extends StatelessWidget {
  const _VanTile({
    required this.entry,
    required this.selected,
    required this.showPinEntry,
    required this.flow,
  });

  final VanPickerEntry entry;
  final bool selected;
  final bool showPinEntry;
  final ShiftFlowState flow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Card(
      color: selected ? theme.colorScheme.secondaryContainer : null,
      child: Column(
        children: [
          ListTile(
            key: ValueKey<String>('van-tile-${entry.van.id}'),
            leading: const Icon(Icons.local_shipping),
            title: Text(entry.van.plateNo, style: theme.textTheme.titleMedium),
            subtitle: Text(
              entry.routeName == null
                  ? l10n.routeUnknown
                  : '${l10n.routeLabel}: ${entry.routeName}',
            ),
            // ListTile renders ≥ 56 dp tall: the big hit-target rule.
            onTap: () => _select(context),
          ),
          if (showPinEntry) _PinEntry(flow: flow),
        ],
      ),
    );
  }

  void _select(BuildContext context) =>
      ProviderScope.containerOf(context)
          .read(shiftStartFlowProvider.notifier)
          .selectVan(entry.van.id);
}

/// PIN entry + the verify / start-shift button for the selected van.
class _PinEntry extends StatefulWidget {
  const _PinEntry({required this.flow});

  final ShiftFlowState flow;

  @override
  State<_PinEntry> createState() => _PinEntryState();
}

class _PinEntryState extends State<_PinEntry> {
  final _pinController = TextEditingController();

  ShiftStartFlowController _flowOf(BuildContext context) =>
      ProviderScope.containerOf(context).read(shiftStartFlowProvider.notifier);

  bool get _busy =>
      widget.flow.phase == ShiftFlowPhase.verifyingPin ||
      widget.flow.phase == ShiftFlowPhase.startingShift;

  bool get _pinVerified =>
      widget.flow.phase == ShiftFlowPhase.readyToStart ||
      widget.flow.phase == ShiftFlowPhase.startingShift;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final flow = widget.flow;
    final pinOk = _pinController.text.length == 4;

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingUnit * 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_pinVerified) ...[
            TextField(
              key: const ValueKey('d1-pin-field'),
              controller: _pinController,
              decoration: InputDecoration(
                labelText: l10n.enterPinPrompt,
                counterText: '',
                errorText: _errorText(l10n),
              ),
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              enabled: !_busy,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppTheme.spacingUnit * 2),
            FilledButton(
              key: const ValueKey('d1-verify-button'),
              onPressed: (_busy || !pinOk)
                  ? null
                  : () => _flowOf(context).submitPin(_pinController.text),
              child: Text(l10n.verifyPin),
            ),
          ] else ...[
            Text(
              l10n.readyToStartInfo,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppTheme.spacingUnit * 2),
            FilledButton(
              key: const ValueKey('d1-start-button'),
              onPressed: _busy ? null : () => _flowOf(context).startShift(),
              child: _busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(flow.resumable ? l10n.resumeShift : l10n.startShift),
            ),
            if (flow.failure != null) ...[
              const SizedBox(height: AppTheme.spacingUnit),
              Text(
                l10n.shiftStartFailed,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall!
                    .copyWith(color: AppTheme.colorStatusEscalated),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// The localized message under the PIN field; wrong PIN / lockout /
  /// unreachable server map 1:1 from [ShiftFlowFailure].
  String? _errorText(AppLocalizations l10n) => switch (widget.flow.failure) {
        ShiftFlowFailure.wrongPin => l10n.wrongPin,
        ShiftFlowFailure.lockedOut => l10n.pinLockedOut,
        ShiftFlowFailure.verifyUnavailable => l10n.verificationUnavailable,
        null || ShiftFlowFailure.startFailed => null,
      };
}
