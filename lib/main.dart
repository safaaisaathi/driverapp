import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/firebase_bootstrap.dart';
import 'core/l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/shift_start/ui/shift_start_screen.dart';

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
      // D1 Shift Start is the app's home (F-D1); successful starts navigate
      // to the BasicRoute placeholder (tracking engine = ticket 05).
      home: const ShiftStartScreen(),
    );
  }
}
