/// D-Call for help dialog (wireframe WF-26): shows the office number for
/// today's route. No phone integration in the demo slice — "Call office"
/// surfaces an honest local-only message rather than dialing a real number.
library;

import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';

/// Shows the call-for-help dialog over the current screen.
Future<void> showCallForHelpDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  await showDialog<void>(
    context: context,
    builder: (_) => const _CallForHelpDialog(),
  );
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const ValueKey('callForHelp.dialing'),
        content: Text('${l10n.callForHelpCall} — not available in demo'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _CallForHelpDialog extends StatelessWidget {
  const _CallForHelpDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      key: const Key('callForHelp.dialog'),
      title: Text(
        l10n.callForHelpTitle,
        key: const Key('callForHelp.title'),
      ),
      content: Text(
        l10n.callForHelpBody,
        key: const Key('callForHelp.body'),
      ),
      actions: [
        TextButton(
          key: const Key('callForHelp.cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.skipWardCancel),
        ),
        FilledButton(
          key: const Key('callForHelp.callOffice'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.callForHelpCall),
        ),
      ],
    );
  }
}
