import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/firebase_bootstrap.dart';
import 'core/l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  // Boot wiring (Firebase init, emulator setup, anonymous session, FCM
  // topic `all`) runs in the background and must NEVER hard-crash the app
  // if Firebase/the emulator suite is unavailable (Ticket 02): failures
  // degrade the app to silent retries, observable/awaitable through
  // bootstrapProvider.
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  unawaited(runBootstrap(container));
  runApp(UncontrolledProviderScope(container: container, child: const DriverApp()));
}

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
/// Kept as-is per Ticket 02 (AAV rule: no UI work in this ticket).
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
