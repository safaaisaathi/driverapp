import 'package:driverapp/core/config/firebase_bootstrap.dart';
import 'package:driverapp/core/repositories/repositories.dart';
import 'package:driverapp/features/shift_start/data/verify_driver_pin.dart';
import 'package:driverapp/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'features/shift_start/shift_start_screen_test.dart' show pinVerifier;
import 'repositories/fake_repositories.dart';

/// App smoke test: home now boots into D1 Shift Start (F-D1), rendered
/// against the fake repository seam — no platform channels.
void main() {
  testWidgets('DriverApp renders D1 Shift Start as home', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        vansRepositoryProvider.overrideWithValue(FakeVansRepository()),
        tripsRepositoryProvider.overrideWithValue(FakeTripsRepository()),
        routesRepositoryProvider.overrideWithValue(FakeRoutesRepository()),
        pinVerifierProvider.overrideWithValue(pinVerifier()),
        driverAuthGatewayProvider.overrideWithValue(_NoopAuthGateway()),
        driverMessagingGatewayProvider
            .overrideWithValue(const NoopMessagingGateway()),
      ],
      child: const DriverApp(),
    ));
    // The first van load resolves against the fake (empty) list.
    for (var i = 0;
        i < 30 &&
            find.text('Pick your van').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
    expect(find.text('Pick your van'), findsOneWidget);
    expect(find.text('No vans found'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

class _NoopAuthGateway implements DriverAuthGateway {
  @override
  Future<String> signInWithCustomToken(String token) async => 'uid';
}
