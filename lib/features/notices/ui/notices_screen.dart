/// D3 — Notices inbox screen (F-D4, ticket 09).
///
/// The one-way messages the office sent to this van, this route's wards,
/// or everyone (Glossary: Notice), newest first, each row showing the
/// message with an unread dot until the driver opens it this session —
/// marking read writes nothing to the backend (the 0.2 shape carries no
/// read field). Minimal text, one-handed, with loading / empty ("no
/// notices") / error / offline states everywhere (0.11). Rows are ≥ 56 dp
/// tap targets (0.5 / contract section 6). Every string is localized.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/notices_flow.dart';
import 'notice_detail_screen.dart';

/// D3 entry widget. Reachable from D2's app-bar notices badge (the keyed
/// slot); the flow needs the running shift's van + route context.
class NoticesScreen extends ConsumerWidget {
  const NoticesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(noticesFlowProvider);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.noticesTitle)),
      body: switch (flow.phase) {
        NoticesPhase.loading => const _NoticesListLoading(),
        NoticesPhase.empty => const _NoticesListEmpty(),
        NoticesPhase.error => _NoticesListDegraded(
          message: l10n.error,
          icon: Icons.error_outline,
        ),
        NoticesPhase.offline => _NoticesListDegraded(
          message: l10n.offline,
          icon: Icons.cloud_off,
        ),
        NoticesPhase.ready => _NoticeList(flow: flow),
      },
    );
  }
}

class _NoticesListLoading extends StatelessWidget {
  const _NoticesListLoading();

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

class _NoticesListEmpty extends StatelessWidget {
  const _NoticesListEmpty();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingUnit * 2),
      child: Center(
        child: Text(l10n.noticesEmpty, textAlign: TextAlign.center),
      ),
    );
  }
}

/// Error / offline: one localized line + one retry button (minimal text,
/// boring and predictable, spec story 24).
class _NoticesListDegraded extends ConsumerWidget {
  const _NoticesListDegraded({required this.message, required this.icon});

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
            key: const ValueKey('d3-retry-button'),
            onPressed: () => ref.read(noticesFlowProvider.notifier).retry(),
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}

/// The notice rows, newest first (the flow guarantees the order).
class _NoticeList extends StatelessWidget {
  const _NoticeList({required this.flow});

  final NoticesState flow;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingUnit * 2),
      children: [
        for (final notice in flow.notices)
          _NoticeRow(notice: notice, isUnread: flow.unread.contains(notice.id)),
      ],
    );
  }
}

/// One notice: a full-card tap target (≥ 56 dp, one hand, campaign-glove
/// friendly) with the unread dot and the message — minimal text. Tapping
/// marks it read this session AND opens the WF-19 detail page (the detail
/// is read-only; the inbox owns the mark-read side effect).
class _NoticeRow extends ConsumerWidget {
  const _NoticeRow({required this.notice, required this.isUnread});

  final Notice notice;
  final bool isUnread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      key: ValueKey<String>('d3-row-${notice.id}'),
      child: InkWell(
        key: ValueKey<String>('d3-tap-${notice.id}'),
        borderRadius: const BorderRadius.all(
          Radius.circular(AppTheme.radiusMd),
        ),
        onTap: () {
          ref.read(noticesFlowProvider.notifier).markRead(notice.id);
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => NoticeDetailScreen(notice: notice),
            ),
          );
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingUnit * 2,
              vertical: AppTheme.spacingUnit * 2,
            ),
            child: Row(
              children: [
                // Unread dot: gone once this notice is opened this session.
                if (isUnread) ...[
                  Container(
                    key: ValueKey<String>('d3-unread-${notice.id}'),
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.colorStatusEscalated,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingUnit * 2),
                ],
                Expanded(
                  child: Text(
                    notice.message,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      color: isUnread
                          ? AppTheme.colorTextPrimary
                          : AppTheme.colorTextMuted,
                    ),
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
