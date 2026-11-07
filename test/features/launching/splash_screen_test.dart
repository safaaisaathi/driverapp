/// Splash screen tests (ticket 8, PRD-2 §0.16) — container-based widget
/// tests (the welcome_screen_test.dart pattern): the splash is pumped in
/// a ProviderContainer with the seam fakes, so no test touches Firebase or
/// a platform channel.
///
/// The pinned contract:
/// - no mascot, no button, no tap-to-skip (the splash is a loading screen);
/// - it advances BY ITSELF once the bootstrap answered (ready or degraded);
/// - the destination follows the device-local `setupDone` flag: fresh →
///   Welcome, setup-done → the start-shift page.
library;

import 'package:driverapp/core/config/firebase_bootstrap.dart';
import 'package:driverapp/core/identity/driver_identity_controller.dart';
import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/l10n/locale_controller.dart';
import 'package:driverapp/core/repositories/repositories.dart';
import 'package:driverapp/core/theme/app_theme.dart';
import 'package:driverapp/features/launching/splash_screen.dart';
import 'package:driverapp/features/launching/welcome_screen.dart';
import 'package:driverapp/features/shift_start/ui/code_start_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/config/bootstrap_fakes.dart';
import '../../core/identity/driver_identity_fakes.dart';
import '../../core/l10n/locale_fakes.dart';
import '../../repositories/fake_repositories.dart';

// -- harness ----------------------------------------------------------------

/// Records the navigator's route events, so a test can tell "the splash
/// pushed a route" from "the splash is still up".
final class RouteRecorder extends NavigatorObserver {
  final List<String> events = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      events.add('push');

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      events.add('replace');
}

/// Pumps the splash in its own container with the seam fakes. The boot
/// starts PENDING, so a test decides when (and how) it answers.
/// Returns the container for state assertions.
Future<ProviderContainer> pumpSplash(
  WidgetTester tester, {
  required InMemoryDriverIdentityStore identityStore,
  RouteRecorder? recorder,
}) async {
  final container = ProviderContainer(
    overrides: [
      bootstrapProvider.overrideWith(() => FakeBootstrapController()),
      driverIdentityStoreProvider.overrideWithValue(identityStore),
      localeStoreProvider.overrideWithValue(InMemoryLocaleStore()),
      vansRepositoryProvider.overrideWithValue(FakeVansRepository()),
      tripsRepositoryProvider.overrideWithValue(FakeTripsRepository()),
      routesRepositoryProvider.overrideWithValue(FakeRoutesRepository()),
      driversRepositoryProvider.overrideWithValue(FakeDriversRepository()),
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
        navigatorObservers: [?recorder],
        home: const SplashScreen(),
      ),
    ),
  );
  await tester.pump();
  // The MaterialApp pushes its home route on its own — only the splash's
  // own navigation counts from here.
  recorder?.events.clear();
  // The flag must be known before the splash routes — main() awaits the
  // SAME restore before runApp, so the first frame already knows it.
  await container
      .read(driverIdentityControllerProvider.notifier)
      .ensureRestored();
  return container;
}

/// The boot answers now (the test drives the seam).
void resolveBoot(ProviderContainer container, BootstrapStatus status) {
  (container.read(bootstrapProvider.notifier) as FakeBootstrapController)
      .resolve(status);
}

/// Pumps in small steps until [finder] finds a widget (or gives up).
Future<void> pumpUntilFound(WidgetTester tester, Finder finder,
    {int maxPumps = 20}) async {
  for (var i = 0; i < maxPumps && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

// -- tests -------------------------------------------------------------------

void main() {
  testWidgets('splash renders the brand face with NO mascot and NO tappable '
      'control', (tester) async {
    await pumpSplash(tester, identityStore: InMemoryDriverIdentityStore());

    expect(
      find.byType(GestureDetector),
      findsNothing,
      reason: 'the splash has no tap-to-skip gesture',
    );
    expect(
      find.byWidgetPredicate((w) => w is ButtonStyleButton),
      findsNothing,
      reason: 'the splash has no buttons',
    );
    // The brand face is still there.
    expect(find.text('Driver App – Panchmahal'), findsOneWidget);
    expect(find.text('Clean city, one route at a time.'), findsOneWidget);
  });

  testWidgets('fresh device (setup-done absent): the splash routes to the '
      'welcome screen', (tester) async {
    final recorder = RouteRecorder();
    final container = await pumpSplash(
      tester,
      identityStore: InMemoryDriverIdentityStore(),
      recorder: recorder,
    );
    resolveBoot(container, const BootstrapStatus.ready());

    await tester.pump(const Duration(milliseconds: 1700));
    await pumpUntilFound(tester, find.byType(WelcomeScreen));

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(CodeStartScreen), findsNothing);
  });

  testWidgets('setup-done device: the splash routes to the start-shift page',
      (tester) async {
    final store = InMemoryDriverIdentityStore();
    await store.writeSetupDone(true);
    final container = await pumpSplash(tester, identityStore: store);
    resolveBoot(container, const BootstrapStatus.ready());

    await tester.pump(const Duration(milliseconds: 1700));
    await pumpUntilFound(tester, find.byType(CodeStartScreen));

    expect(find.byType(CodeStartScreen), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsNothing);
  });

  testWidgets('the splash advances BY ITSELF once the bootstrap is ready',
      (tester) async {
    final recorder = RouteRecorder();
    final container = await pumpSplash(
      tester,
      identityStore: InMemoryDriverIdentityStore(),
      recorder: recorder,
    );

    // Before the brand moment the splash does not route.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(
      recorder.events,
      isEmpty,
      reason: 'the splash holds its brand moment before it routes',
    );
    expect(find.byType(SplashScreen), findsOneWidget);

    // The boot answers: the splash advances with no user input at all.
    resolveBoot(container, const BootstrapStatus.ready());
    await tester.pump();
    await pumpUntilFound(tester, find.byType(WelcomeScreen));

    expect(
      recorder.events,
      isNotEmpty,
      reason: 'the splash routed by itself, with no tap',
    );
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  testWidgets('a degraded bootstrap still advances the splash (never hangs)',
      (tester) async {
    final recorder = RouteRecorder();
    final container = await pumpSplash(
      tester,
      identityStore: InMemoryDriverIdentityStore(),
      recorder: recorder,
    );
    resolveBoot(container, const BootstrapStatus.degraded());

    await tester.pump(const Duration(milliseconds: 1700));
    await pumpUntilFound(tester, find.byType(WelcomeScreen));

    expect(recorder.events, isNotEmpty);
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  testWidgets('a bootstrap that never answers does not hang the splash',
      (tester) async {
    final recorder = RouteRecorder();
    await pumpSplash(
      tester,
      identityStore: InMemoryDriverIdentityStore(),
      recorder: recorder,
    );

    // The hard cap lets the driver in even when the boot stays silent.
    await tester.pump(const Duration(milliseconds: 1700));
    await pumpUntilFound(tester, find.byType(WelcomeScreen));

    expect(recorder.events, isNotEmpty);
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  testWidgets('the onSplashDone seam fires when the splash auto-advances',
      (tester) async {
    var fired = 0;
    final container = ProviderContainer(
      overrides: [
        bootstrapProvider.overrideWith(() => FakeBootstrapController()),
        driverIdentityStoreProvider
            .overrideWithValue(InMemoryDriverIdentityStore()),
        localeStoreProvider.overrideWithValue(InMemoryLocaleStore()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: SplashScreen(onSplashDone: (_) => fired++),
        ),
      ),
    );
    await tester.pump();
    resolveBoot(container, const BootstrapStatus.ready());

    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pump(const Duration(milliseconds: 300));

    expect(fired, 1, reason: 'the seam fires exactly once, on the advance');
    expect(find.byType(SplashScreen), findsOneWidget);
  });
}
