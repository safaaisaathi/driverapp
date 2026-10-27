/// D-Report detail (wireframe WF-20): the full pending report opened from
/// the D4 list. Shows the ticket id, category · ward, when it was reported,
/// the location, and the two actions ("Done" / "Will Revisit"). Actions go
/// through the D4 flow's public methods — exactly one status write per tap,
/// no backend surface beyond D4's existing `updateStatus`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/models/models.dart';
import '../domain/pending_reports_flow.dart';

/// One pending report's detail page. [complaint] is the row tapped in D4.
class ReportDetailScreen extends ConsumerWidget {
  const ReportDetailScreen({super.key, required this.complaint});

  final Complaint complaint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final flow = ref.watch(pendingReportsFlowProvider);
    // Kick the flow to load today's reports (route context comes from the
    // shift session, seeded by the caller).
    if (flow.phase == PendingReportsPhase.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.context.mounted) {
          ref.read(pendingReportsFlowProvider.notifier).ensureLoaded();
        }
      });
    }
    final todayCount = flow.reports.length;
    final mins = DateTime.now().difference(complaint.createdAt).inMinutes;
    final busy = flow.actionsInFlight.contains(complaint.id);
    final isDone = complaint.status == ComplaintStatus.resolved;
    final c = Theme.of(context).colorScheme;
    final location = complaint.location;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: AlignmentDirectional.topStart,
              child: AppIconButton(
                key: const Key('reportDetail.back'),
                onPressed: () => Navigator.of(context).pop(),
                icon: Icons.arrow_back,
                size: 48,
                semanticsLabel: MaterialLocalizations.of(context)
                    .backButtonTooltip,
              ),
            ),
            const SizedBox(height: AppTheme.spacingUnit),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ticket id.
                  Text(
                    complaint.ticketId,
                    key: const Key('reportDetail.ticketId'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: c.onSurface.withValues(alpha: 0.5),
                        ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  // "{category} · Ward {wardId}".
                  Text(
                    '${_categoryLabel(l10n)} · ${l10n.reportDetailWard(complaint.wardId ?? '')}',
                    key: const Key('reportDetail.title'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppTheme.spacingUnit),
                  // "{n} reports today · X min ago".
                  Row(
                    children: [
                      Text(
                        l10n.reportDetailReportsToday(todayCount),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: c.onSurface.withValues(alpha: 0.5),
                            ),
                      ),
                      const SizedBox(width: AppSpace.xs),
                      Text(
                        '· ${l10n.reportDetailTimeAgo(mins)}',
                        key: const Key('reportDetail.timeAgo'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: c.onSurface.withValues(alpha: 0.5),
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingUnit * 3),
                  // Location chip.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: c.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on, size: 16),
                        const SizedBox(width: AppSpace.xs),
                        Text(
                          location == null
                              ? l10n.reportDetailLocation
                              : '${location.lat.toStringAsFixed(4)}, ${location.lng.toStringAsFixed(4)}',
                          key: const Key('reportDetail.location'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (isDone) ...[
                    const SizedBox(height: AppTheme.spacingUnit),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.colorStatusResolved.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, size: 16),
                          const SizedBox(width: AppSpace.xs),
                          Text(
                            l10n.reportDetailStatusDone,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(),
            // Done / Will Revisit — side by side, ≥ 56 dp each.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          key: const Key('reportDetail.done'),
                          onPressed: busy || isDone
                              ? null
                              : () async {
                                    final ctx = context;
                                    await ref
                                        .read(
                                          pendingReportsFlowProvider
                                              .notifier,
                                        )
                                        .markDone(complaint.id);
                                    if (!ctx.mounted) return;
                                    ScaffoldMessenger.of(ctx)
                                        .showSnackBar(
                                      SnackBar(
                                        key: ValueKey<String>(
                                          'reportDetail.done-${complaint.id}',
                                        ),
                                        content: Text(
                                            l10n.reportDetailStatusDone),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                          child: Text(
                            isDone
                                ? l10n.reportDetailStatusDone
                                : l10n.reportDetailDone,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingUnit),
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('reportDetail.willRevisit'),
                          onPressed: busy || isDone
                              ? null
                              : () async {
                                    final ctx = context;
                                    await ref
                                        .read(
                                          pendingReportsFlowProvider
                                              .notifier,
                                        )
                                        .markWillRevisit(complaint.id);
                                    if (!ctx.mounted) return;
                                    ScaffoldMessenger.of(ctx)
                                        .showSnackBar(
                                      SnackBar(
                                        key: ValueKey<String>(
                                          'reportDetail.revisit-${complaint.id}',
                                        ),
                                        content: Text(
                                            l10n.reportDetailWillRevisit),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                          child: Text(l10n.reportDetailWillRevisit),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(AppLocalizations l10n) => switch (complaint.category) {
        ComplaintCategory.missedCollection =>
          l10n.complaintCategoryMissedCollection,
        ComplaintCategory.garbageDump => l10n.complaintCategoryGarbageDump,
        ComplaintCategory.openGutter => l10n.complaintCategoryOpenGutter,
        ComplaintCategory.other => l10n.complaintCategoryOther,
      };
}
