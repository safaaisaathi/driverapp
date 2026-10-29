/// D4 — Pending Reports screen (F-D6, ticket 10).
///
/// Today's `missed_collection` complaints for the running shift's route
/// wards (Glossary: Pending Report), each row offering exactly two
/// buttons: "Will Revisit" and "Done" — minimal text, one-handed, with
/// loading / empty / error / offline states everywhere (0.11). Buttons
/// ≥ 56 dp come from `AppTheme` (0.5 / contract section 6). Every string
/// is localized.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/pending_reports_flow.dart';
import 'report_detail_screen.dart';

/// D4 entry widget. Reads the running shift's route context from
/// [pendingReportsFlowProvider]; open the screen while a shift runs
/// (D1's flow navigates here after Start Shift).
class PendingReportsScreen extends ConsumerWidget {
  const PendingReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(pendingReportsFlowProvider);
    if (flow.phase == PendingReportsPhase.loading) {
      // Idempotent first-load kick; retries go through the Retry button
      // (the D1 pattern).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.context.mounted) {
          ref.read(pendingReportsFlowProvider.notifier).ensureLoaded();
        }
      });
    }
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pendingReportsTitle)),
      body: switch (flow.phase) {
        PendingReportsPhase.loading => const _PendingListLoading(),
        PendingReportsPhase.empty => const _PendingListEmpty(),
        PendingReportsPhase.error => _PendingListDegraded(
          message: l10n.error,
          icon: Icons.error_outline,
        ),
        PendingReportsPhase.offline => _PendingListDegraded(
          message: l10n.offline,
          icon: Icons.cloud_off,
        ),
        PendingReportsPhase.ready => _ReportList(flow: flow),
      },
    );
  }
}

class _PendingListLoading extends StatelessWidget {
  const _PendingListLoading();

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

class _PendingListEmpty extends StatelessWidget {
  const _PendingListEmpty();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingUnit * 2),
      child: Center(
        child: Text(l10n.pendingReportsEmpty, textAlign: TextAlign.center),
      ),
    );
  }
}

/// Error / offline: one localized line + one retry button (minimal text,
/// boring and predictable, spec story 24).
class _PendingListDegraded extends ConsumerWidget {
  const _PendingListDegraded({required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: AppTheme.spacingUnit * 2),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppTheme.spacingUnit * 2),
          OutlinedButton(
            key: const ValueKey('d4-retry-button'),
            onPressed: () =>
                ref.read(pendingReportsFlowProvider.notifier).retry(),
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}

/// Empty vs the report rows, one card per pending report.
class _ReportList extends StatelessWidget {
  const _ReportList({required this.flow});

  final PendingReportsState flow;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingUnit * 2),
      children: [
        for (final complaint in flow.reports)
          _ReportRow(
            complaint: complaint,
            busy: flow.actionsInFlight.contains(complaint.id),
          ),
      ],
    );
  }
}

/// One pending report: the ticket id header opens the WF-20 detail page
/// (≥ 56 dp target), below it the exactly-two action buttons ("Will
/// Revisit" / "Done"), each a ≥ 56 dp target reached with one hand.
class _ReportRow extends ConsumerWidget {
  const _ReportRow({required this.complaint, required this.busy});

  final Complaint complaint;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final complaintId = complaint.id;
    return Card(
      key: ValueKey<String>('d4-row-$complaintId'),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingUnit * 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The header tap opens the detail page — actions stay inline
            // here, the detail adds context (location, time, today count).
            InkWell(
              key: ValueKey<String>('d4-open-$complaintId'),
              borderRadius: const BorderRadius.all(
                Radius.circular(AppTheme.radiusMd),
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ReportDetailScreen(complaint: complaint),
                ),
              ),
              child: SizedBox(
                height: 56,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        complaint.ticketId,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color:
                          Theme.of(context).textTheme.bodySmall?.color
                              ?.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingUnit),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    key: ValueKey<String>('d4-revisit-$complaintId'),
                    onPressed: busy
                        ? null
                        : () => ref
                              .read(pendingReportsFlowProvider.notifier)
                              .markWillRevisit(complaintId),
                    child: Text(l10n.willRevisit),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingUnit),
                Expanded(
                  child: FilledButton(
                    key: ValueKey<String>('d4-done-$complaintId'),
                    onPressed: busy
                        ? null
                        : () => ref
                              .read(pendingReportsFlowProvider.notifier)
                              .markDone(complaintId),
                    child: Text(l10n.markDone),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
