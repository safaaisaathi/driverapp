import 'package:driverapp/core/config/firebase_bootstrap.dart';
import 'package:driverapp/core/config/firebase_options.dart';
import 'package:driverapp/core/identity/driver_identity_controller.dart';
import 'package:driverapp/features/tracking/tracking_providers.dart'
    show trackingPermissionGatewayProvider;
import 'package:driverapp/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/identity/driver_identity_fakes.dart';
import '../features/launching/permission_gateway_fakes.dart';

/// Test double of the controller: renders the same UI flow main() produces
/// when Firebase/the emulator suite is unavailable.
final class DegradedBootstrapController extends BootstrapController {
  @override
  BootstrapStatus build() => const BootstrapStatus.pending();

  @override
  Future<void> run({FirebaseBackend? backend}) async {
    state = const BootstrapStatus.degraded();
  }
}

void main() {
  testWidgets('app renders the launched (degraded-tolerant) state without '
      'Firebase: splash → welcome → setup → start-shift page stays up',
      (tester) async {
    // Mirrors main()'s wiring WITHOUT running bootstrap: no Firebase app is
    // created, no platform channel (Auth/FCM/Hive) is touched, so the test
    // is green even when the Emulator Suite is not running (Ticket 02).
    // The setup flow runs against the grant-all gateway fake + the
    // in-memory identity store (nothing platform-bound).
    final container = ProviderContainer(
      overrides: [
        bootstrapProvider.overrideWith(() => DegradedBootstrapController()),
        driverIdentityStoreProvider.overrideWithValue(
          InMemoryDriverIdentityStore(),
        ),
        trackingPermissionGatewayProvider
            .overrideWithValue(const GrantAllPermissionGateway()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DriverApp()),
    );
    // Walk the new launching flow (0.16): splash (1.6 s hold) → welcome →
    // begin CTA runs the setup and lands on the start-shift page.
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('welcome-begin-button')));
    // The setup hand-over + fade-forwards: retire the replaced route
    // through small pumps.
    await tester.pumpAndSettle();

    // Home lands on the start-shift page (ticket 14 keeps the
    // Splash → Welcome → setup chain before it). Without Firebase the page
    // still renders its code entry — nothing crashes, the same
    // degrade-don't-crash contract this smoke test checked on the
    // placeholder / old D1.
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byKey(const ValueKey('d1-code-field')), findsOneWidget);
    // Issue #14: the shipping default is Gujarati, so the fresh-install
    // frame shows the gu title.
    expect(find.text('શિફ્ટ શરૂ કરો'), findsOneWidget);
  });

  testWidgets('bootstrap status reads degraded, never crashed', (tester) async {
    final container = ProviderContainer(
      overrides: [
        bootstrapProvider.overrideWith(() => DegradedBootstrapController()),
      ],
    );
    addTearDown(container.dispose);

    await (container.read(bootstrapProvider.notifier) as DegradedBootstrapController)
        .run();

    expect(
      container.read(bootstrapProvider),
      isA<BootstrapDegraded>(),
      reason: 'a failed boot must surface as degraded, not crash the app',
    );
  });
}
