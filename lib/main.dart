import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/firebase_bootstrap.dart';
import 'core/l10n/app_localizations.dart';
import 'core/l10n/locale_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'features/launching/splash_screen.dart';

Future<void> main() async {
  // Boot wiring (Firebase init, emulator setup, anonymous session, FCM
  // topic `all`) runs in the background and must NEVER hard-crash the app
  // if Firebase/the emulator suite is unavailable (Ticket 02): failures
  // degrade the app to silent retries, observable/awaitable through
  // bootstrapProvider.
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  unawaited(runBootstrap(container));
  // Bug Bag fix (2026-10-29): the locale restore used to race the first
  // frame (fire-and-forget), so a stored gu could flash en for a frame or
  // two. The read is ~ms, so main() simply awaits it before runApp: the
  // first frame carries the stored language, deterministically.
  await container.read(localeControllerProvider.notifier).ensureRestored();
  runApp(UncontrolledProviderScope(container: container, child: const DriverApp()));
}

class DriverApp extends ConsumerWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      // The DEBUG ribbon is a debug-build-only cosmetic (no contract
      // impact); drawing it over the driver's top-right corner hurts
      // taste and covers content (DESIGN.md line 365 rules the corners).
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      // Wireframes WF-14/21: Light / Dark / System from the SAME token
      // set (DESIGN.md D-07). Widgets must not branch on brightness —
      // they read context.tokens, and the extension swaps per theme.
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ref.watch(themeModeControllerProvider),
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
      // Launching flow (static, no API): Splash → Welcome → Start Duty,
      // then the D1 van-picker / route screen where data (skeletons +
      // error states) takes over.
      home: const SplashScreen(),
    );
  }
}
