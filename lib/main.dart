import 'package:flutter/material.dart';

import 'core/l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';

void main() => runApp(const DriverApp());

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: AppTheme.light(),
      // English default is a DEVELOPMENT-PHASE decision (grill round 1, Q7).
      // Gujarati becomes the default before the demo — remove this line then.
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const _Phase0Placeholder(),
    );
  }
}

/// Temporary Phase-0 placeholder. Replaced by D1 Shift Start (F-D1).
class _Phase0Placeholder extends StatelessWidget {
  const _Phase0Placeholder();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(
        child: Text(
          l10n.loading,
          style: Theme.of(context)
              .textTheme
              .bodyMedium!
              .copyWith(color: AppTheme.colorTextMuted),
        ),
      ),
    );
  }
}
