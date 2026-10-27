/// D-More options sheet (wireframe WF-23): operations available during a
/// shift — skip ward, on break, call for help, settings. Presented as a
/// modal bottom sheet over D2 Live Route.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../settings/ui/settings_screen.dart';
import '../ui/call_for_help_dialog.dart';
import '../ui/on_break_screen.dart';
import '../ui/skip_ward_dialog.dart';

/// Shows the more-options bottom sheet over [context]. [wardId] is the ward
/// offered for skipping (typically the next ward in route order).
Future<void> showMoreOptionsSheet(BuildContext context, {required String wardId}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MoreOptionsSheet(wardId: wardId),
  );
  // Nothing to do after dismiss: each option navigates or dialogs in place.
}

class _MoreOptionsSheet extends ConsumerWidget {
  const _MoreOptionsSheet({required this.wardId});

  final String wardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final c = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // Drag handle.
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header.
          ListTile(
            key: const Key('moreOptions.header'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            title: Text(
              l10n.moreOptionsTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            trailing: AppIconButton(
              key: const Key('moreOptions.close'),
              onPressed: () => Navigator.of(context).pop(),
              icon: Icons.close,
              size: 40,
              semanticsLabel: 'Close',
            ),
          ),
          const Divider(height: 1),
          // Options.
          _OptionTile(
            key: const Key('moreOptions.skipWard'),
            icon: Icons.skip_next,
            label: l10n.moreOptionsSkipWard,
            onTap: () {
              Navigator.of(context).pop();
              unawaited(showSkipWardDialog(context, wardId));
            },
          ),
          _OptionTile(
            key: const Key('moreOptions.onBreak'),
            icon: Icons.pause,
            label: l10n.moreOptionsOnBreak,
            onTap: () {
              final navigator = Navigator.of(context);
              navigator.pop();
              unawaited(
                navigator.push(
                  MaterialPageRoute<void>(builder: (_) => const OnBreakScreen()),
                ),
              );
            },
          ),
          _OptionTile(
            key: const Key('moreOptions.callForHelp'),
            icon: Icons.help,
            label: l10n.moreOptionsCallForHelp,
            onTap: () {
              Navigator.of(context).pop();
              unawaited(showCallForHelpDialog(context));
            },
          ),
          _OptionTile(
            key: const Key('moreOptions.settings'),
            icon: Icons.settings,
            label: l10n.moreOptionsSettings,
            onTap: () {
              final navigator = Navigator.of(context);
              navigator.pop();
              unawaited(
                navigator.push(
                  MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
      ),
    );
  }
}

class _OptionTile extends ConsumerWidget {
  const _OptionTile({
    required super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      key: key,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      leading: Icon(icon, color: context.colors.textPrimary),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
