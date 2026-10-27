/// D-Skip ward dialog (wireframe WF-24): drops a ward from today's route
/// locally. Never writes `trips.wardsDone` — the skipped ward is tracked
/// in session-only state ([skipWardControllerProvider]) so the shift's trip
/// record is never corrupted.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../domain/break_flow.dart';

/// Shows the skip-ward dialog for [wardId] over the current screen.
Future<void> showSkipWardDialog(BuildContext context, String wardId) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _SkipWardDialog(wardId: wardId),
  );
}

class _SkipWardDialog extends ConsumerWidget {
  const _SkipWardDialog({required this.wardId});

  final String wardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      key: const Key('skipWard.dialog'),
      title: Text(
        l10n.skipWardTitle,
        key: const Key('skipWard.title'),
      ),
      content: Text(
        l10n.skipWardWarning,
        key: const Key('skipWard.warning'),
      ),
      actions: [
        TextButton(
          key: const Key('skipWard.cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.skipWardCancel),
        ),
        FilledButton(
          key: const Key('skipWard.confirm'),
          onPressed: () {
            ref.read(skipWardControllerProvider.notifier).skip(wardId);
            Navigator.of(context).pop();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  key: const ValueKey('skipWard.skipped'),
                  content: Text('${l10n.skipWardConfirm}: $wardId'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          child: Text(l10n.skipWardConfirm),
        ),
      ],
    );
  }
}
