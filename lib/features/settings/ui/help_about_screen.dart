/// Help and about (wireframe WF-21's "Help and about" row): one static,
/// fully offline page — the app's name, tagline and nothing else.
/// Deliberately minimal: inventing contact numbers or support channels
/// would put unverified data in front of a driver; those arrive in the
/// "Call for help" flow with the office's real numbers (WF-26).
library;

import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/widgets/app_icon_button.dart';

class HelpAboutScreen extends StatelessWidget {
  const HelpAboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          children: [
            Align(
              alignment: AlignmentDirectional.topStart,
              child: AppIconButton(
                key: const Key('helpAbout.back'),
                onPressed: () => Navigator.of(context).pop(),
                icon: Icons.arrow_back,
                size: 48,
                semanticsLabel:
                    MaterialLocalizations.of(context).backButtonTooltip,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.helpAboutTitle,
              key: const Key('helpAbout.title'),
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 24),
            Text(
              l10n.helpAboutTagline,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.appTitle,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}
