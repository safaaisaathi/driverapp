/// Welcome screen tests (ticket 6, PRD-2 §0.16) — container-based widget
/// tests (pattern: code_start_screen_test.dart / mock_location_banner_test.dart):
/// the screen is pumped in a ProviderContainer with the seam fakes, so no
/// test reaches Firebase or a platform channel.
///
/// The fresh-device onboarding seam: the begin CTA runs the 4-stage
/// permission setup through a FAKE gateway, then the setup-done flag is
/// written through a FAKE DriverIdentityStore and the start-shift page
/// (CodeStartScreen) is pushed. Binny is gone from this screen (D-105).
///
/// Pinned English strings follow the code_start_screen_test.dart pattern;
/// keys are the stable widget seams.
library;

import 'package:driverapp/core/identity/driver_identity_controller.dart';
import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/theme/app_theme.dart';
import 'package:driverapp/core/widgets/binny.dart';
import 'package:driverapp/features/launching/welcome_screen.dart';
import 'package:driverapp/features/shift_start/ui/code_start_screen.dart';
import 'package:driverapp/features/tracking/tracking_providers.dart'
    show TrackingPermissionGateway, trackingPermissionGatewayProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/identity/driver_identity_fakes.dart';
import 'permission_gateway_fakes.dart';

// -- pinned English strings (arb contract) ----------------------------------

const String enWelcomeTitle = 'Welcome';
const String enWelcomeBody = "Safaai Saathi is ready for today's shift.";
const String enWelcomeCta = 'Get started';

// -- harness ----------------------------------------------------------------

/// Pumps the welcome screen in its own container with the gateway +
/// identity-store fakes. Returns the container for state assertions.
Future<ProviderContainer> pumpWelcome(
  WidgetTester tester, {
  TrackingPermissionGateway? gateway,
  InMemoryDriverIdentityStore? identityStore,
}) async {
  final store = identityStore ?? InMemoryDriverIdentityStore();
  final container = ProviderContainer(
    overrides: [
      trackingPermissionGatewayProvider
          .overrideWithValue(gateway ?? const GrantAllPermissionGateway()),
      driverIdentityStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        locale: const Locale('en'), // locale pinned en (project decision)
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const WelcomeScreen(),
      ),
    ),
  );
  await tester.pump();
  return container;
}

/// Pumps in small steps until [finder] finds a widget or gives up.
Future<void> pumpUntil(WidgetTester tester, Finder finder,
    {int maxPumps = 60}) async {
  for (var i = 0; i < maxPumps && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 25));
  }
  expect(finder, findsOneWidget);
}

// -- tests -------------------------------------------------------------------

void main() {
  testWidgets('welcome renders WITHOUT Binny: title, body and the begin '
      'CTA (D-105, removed-T8)', (tester) async {
    await pumpWelcome(tester);

    expect(
      find.byType(BinnyView),
      findsNothing,
      reason: 'the mascot is removed from this screen (the splash Binny is '
          'ticket 8, so the welcome tree must not host one either)',
    );
    expect(find.text(enWelcomeTitle), findsOneWidget);
    expect(find.text(enWelcomeBody), findsOneWidget);
    expect(find.text(enWelcomeCta), findsOneWidget);
    expect(
      find.byKey(const ValueKey('welcome-begin-button')),
      findsOneWidget,
    );
  });

  testWidgets('begin CTA runs the setup against a grant-all gateway: '
      'setup-done written and the start-shift page pushed', (tester) async {
    final store = InMemoryDriverIdentityStore();
    final container = await pumpWelcome(tester, identityStore: store);

    await tester.tap(find.byKey(const ValueKey('welcome-begin-button')));
    await pumpUntil(tester, find.byType(CodeStartScreen));

    // markSetupDone landed through the store seam AND in controller state.
    expect(
      store.storedSetupDone,
      isTrue,
      reason: 'the setup-done flag is persisted on completion',
    );
    expect(
      container.read(driverIdentityControllerProvider).isSetupDone,
      isTrue,
    );
    // The start-shift page replaced the welcome (0.16 fresh-device path).
    expect(find.byType(CodeStartScreen), findsOneWidget);
  });

  testWidgets('denied setup still lands on the start-shift page: "Not now" '
      'on the first rationale ends the flow, setup-done is written, no '
      'crash', (tester) async {
    final store = InMemoryDriverIdentityStore();
    await pumpWelcome(
      tester,
      gateway: const DenyAllPermissionGateway(),
      identityStore: store,
    );

    await tester.tap(find.byKey(const ValueKey('welcome-begin-button')));
    // The rationale screen of the FIRST stage shows (the check is denied).
    await pumpUntil(
      tester,
      find.byKey(const ValueKey('permissionNotNow_locationWhileInUse')),
    );
    await tester.tap(
      find.byKey(const ValueKey('permissionNotNow_locationWhileInUse')),
    );

    // The flow stops at the first non-grant, the setup completes anyway
    // and the app lands on the start-shift page (degraded-mode contract).
    await pumpUntil(tester, find.byType(CodeStartScreen));
    expect(store.storedSetupDone, isTrue);
  });
}
