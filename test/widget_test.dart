import 'package:driverapp/core/config/firebase_bootstrap.dart';
import 'package:driverapp/core/identity/driver_identity_controller.dart';
import 'package:driverapp/core/repositories/repositories.dart';
import 'package:driverapp/features/shift_start/data/fcm_topics.dart'
    show driverMessagingGatewayProvider;
import 'package:driverapp/features/tracking/tracking_providers.dart'
    show trackingPermissionGatewayProvider;
import 'package:driverapp/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'core/identity/driver_identity_fakes.dart';
import 'features/launching/permission_gateway_fakes.dart';
import 'repositories/fake_repositories.dart';

/// App smoke test: home boots the NEW driver-identity launching flow
/// (PRD-2 §0.16) against the fake seams — no platform channels.
void main() {
  testWidgets('DriverApp boots: Splash → Welcome → one-time setup → '
      'start-shift page against the fake seams (no platform channels)',
      (tester) async {
    final identityStore = InMemoryDriverIdentityStore();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        vansRepositoryProvider.overrideWithValue(FakeVansRepository()),
        tripsRepositoryProvider.overrideWithValue(FakeTripsRepository()),
        routesRepositoryProvider.overrideWithValue(FakeRoutesRepository()),
        driversRepositoryProvider.overrideWithValue(FakeDriversRepository()),
        driverIdentityStoreProvider.overrideWithValue(identityStore),
        driverMessagingGatewayProvider
            .overrideWithValue(const NoopMessagingGateway()),
        // The setup flow auto-grants every stage, so the CTA completes
        // without a rationale screen in the smoke walk.
        trackingPermissionGatewayProvider
            .overrideWithValue(const GrantAllPermissionGateway()),
      ],
      child: const DriverApp(),
    ));
    // Splash (1.6 s local hold) → Welcome replaces it; the begin CTA runs
    // the setup (grant-all fake) and lands on the start-shift page.
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('welcome-begin-button')));
    // The setup hand-over + fade-forwards: retire the replaced route
    // through small pumps.
    await tester.pumpAndSettle();
    // The start-shift page is up with its code field; the setup-done flag
    // is written through the identity seam.
    expect(find.byKey(const ValueKey('d1-code-field')), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(identityStore.storedSetupDone, isTrue);
  });
}
