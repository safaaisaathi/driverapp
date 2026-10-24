import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/firebase_bootstrap.dart';
import 'core/l10n/app_localizations.dart';
import 'core/l10n/locale_controller.dart';
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

class DriverApp extends ConsumerWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: AppTheme.light(),
      // F-D10 (ticket 13): the D1 toggle drives the language app-wide and
      // instantly (this watch rebuilds MaterialApp), restored across
      // launches by LocaleController.
      locale: ref.watch(localeControllerProvider) ??
          // English fallback for "no stored choice" is a DEVELOPMENT-PHASE
          // decision (grill round 1, Q7): without it, null would follow the
          // device locale. Gujarati becomes the default before the demo —
          // revisit this line then.
          const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // D1 Shift Start is the app's home (F-D1); successful starts navigate
      // to the BasicRoute placeholder (tracking engine = ticket 05).
      home: const ShiftStartScreen(),
    );
  }
}
