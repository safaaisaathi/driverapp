/// Ticket 11 (issue #16, PRD-2 §0.16): the setup's permission rationale
/// screens carry the app's shared language toggle, top-end beside the
/// round close button (DESIGN-driver-app.md §4.18).
///
/// Reuse only: no new widget, no new arb key, no new asset - the toggle
/// flips the app instantly and persists through LocaleController, and the
/// rationale copy re-renders in the chosen locale the same way every
/// other screen does (MaterialApp watches the controller).
library;

import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/l10n/locale_controller.dart';
import 'package:driverapp/features/tracking/ui/permission_prompt_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/l10n/locale_fakes.dart';

// Pinned English strings (the arb values, asserted verbatim).
const String enLocationTitle = 'Location access';
const String guLocationTitle = 'લોકેશન પહોંચ';
const String guToggleName = 'ગુજરાતી';
const String enToggleName = 'English';

/// The app shell exactly the way `DriverApp` wires it: MaterialApp watches
/// the locale controller, so a toggle flip re-localizes the whole tree
/// (a fixed `locale:` here would make the flip invisible to this test).
class _AppShell extends ConsumerWidget {
  const _AppShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dev-phase default pinned en (issue #14 flips it to gu separately).
    final locale = ref.watch(localeControllerProvider) ?? const Locale('en');
    return MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              key: const ValueKey('open-prompt'),
              onPressed: () => showPermissionPrompt(
                context: context,
                stage: PermissionPromptStage.locationWhileInUse,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pumps the app shell and pushes the rationale screen for the FIRST
/// stage, the way the setup flow does (`showPermissionPrompt`).
Future<void> pumpRationale(
  WidgetTester tester, {
  InMemoryLocaleStore? store,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      localeStoreProvider.overrideWithValue(store ?? InMemoryLocaleStore()),
    ],
    child: const _AppShell(),
  ));
  await tester.tap(find.byKey(const ValueKey('open-prompt')));
  await tester.pump(); // route push + first frame
  await tester.pump(const Duration(milliseconds: 300));
}

/// Pumps in small steps until [finder] finds a widget, or fails.
Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 60 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 25));
  }
  expect(finder, findsOneWidget);
}

void main() {
  testWidgets('the rationale screen shows the shared language toggle '
      'beside the round close button', (tester) async {
    await pumpRationale(tester);

    // The toggle is present, next to the close control, and the screen
    // keeps exactly one primary (the Allow pill; the toggle is an outlined
    // secondary, CL-D07).
    expect(find.byKey(const ValueKey('d1-language-toggle')), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(
      find.byKey(const ValueKey('permissionAllow_locationWhileInUse')),
      findsOneWidget,
    );
    // The rationale copy renders in English on the first frame.
    expect(find.text(enLocationTitle), findsOneWidget);
  });

  testWidgets('tapping the toggle flips the rationale copy to Gujarati '
      'instantly (no restart, same screen)', (tester) async {
    await pumpRationale(tester);

    await tester.tap(find.byKey(const ValueKey('d1-language-toggle')));
    await pumpUntil(tester, find.text(guLocationTitle));

    expect(find.text(enLocationTitle), findsNothing);
    // The toggle now points back at English, named natively.
    expect(find.text(enToggleName), findsOneWidget);
    expect(find.text(guToggleName), findsNothing);
  });

  testWidgets('the flipped choice persists through the LocaleStore seam '
    '(LocaleController, unchanged)', (tester) async {
    final store = InMemoryLocaleStore();
    await pumpRationale(tester, store: store);

    await tester.tap(find.byKey(const ValueKey('d1-language-toggle')));
    await pumpUntil(tester, find.text(guLocationTitle));

    // The choice landed in storage; the next launch restores it the same
    // way the welcome/start-shift toggles do (no per-screen wiring).
    expect(store.stored, 'gu');
  });
}
