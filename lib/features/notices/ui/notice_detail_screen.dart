/// D-Notice detail (wireframe WF-19): the full message opened from the D3
/// inbox. Read-only: opening marks the notice read this session (handled by
/// the inbox row that navigates here). Shows the message, the relative time
/// it was sent, and the target it applies to — no contract fields invented.
library;

import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/models/models.dart';

/// One notice's detail page. [notice] is the doc opened from the inbox.
class NoticeDetailScreen extends StatelessWidget {
  const NoticeDetailScreen({super.key, required this.notice});

  final Notice notice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = Theme.of(context).colorScheme;
    final mins = DateTime.now().difference(notice.createdAt).inMinutes;
    final timeAgo = l10n.noticeDetailTimeAgo(mins);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back arrow — mirrors the wireframe's top-left dismiss.
            Align(
              alignment: AlignmentDirectional.topStart,
              child: AppIconButton(
                key: const Key('noticeDetail.back'),
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
                  Text(
                    notice.message,
                    key: const Key('noticeDetail.message'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppTheme.spacingUnit),
                  // Meta: who sent it and when (relative, e.g. "10 min ago").
                  Row(
                    children: [
                      Text(
                        notice.createdBy,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: c.onSurface.withValues(alpha: 0.5),
                            ),
                      ),
                      const SizedBox(width: AppTheme.spacingUnit),
                      Text(
                        '· $timeAgo',
                        key: const Key('noticeDetail.timeAgo'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: c.onSurface.withValues(alpha: 0.5),
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingUnit * 3),
                  // The target this notice applies to (targetType/targetId).
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
                        const Icon(Icons.public, size: 16),
                        const SizedBox(width: AppSpace.xs),
                        Text(
                          _targetLabel(l10n),
                          key: const Key('noticeDetail.target'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // "Got it" dismisses the detail and returns to the inbox.
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: FilledButton(
                  key: const Key('noticeDetail.gotIt'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.noticeDetailGotIt),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Human-readable target from the notice's contract targetType/targetId.
  String _targetLabel(AppLocalizations l10n) => switch (notice.targetType) {
        NoticeTargetType.all => l10n.noticeDetailAppliesToAll,
        NoticeTargetType.van => l10n.noticeDetailAppliesToVan,
        NoticeTargetType.ward =>
          l10n.noticeDetailAppliesToWard(notice.targetId ?? ''),
      };
}
