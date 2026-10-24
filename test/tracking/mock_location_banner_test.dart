/// F-D9 banner tests (ticket 11): the driver-facing side of the mock-location
/// latch. The provider reads the trips doc (ground truth), so the widget test
/// chips the banner into a ProviderScope with FakeTripsRepository overrides —
/// no platform channels, no router, no D2 dependency (self-contained widget).
library;

import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/core/repositories/repository_providers.dart';
import 'package:driverapp/features/tracking/mock_location_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../repositories/fake_repositories.dart';

Trip tripOf(DateTime today, bool detected) => Trip(
      id: 'trip-1',
      vanId: 'van-01',
      routeId: 'route-01',
      date: today,
      startedAt: DateTime(today.year, today.month, today.day, 8),
      endedAt: null,
      wardsDone: const <WardDone>[],
      alertedWardIds: const <String>[],
      gpsTrail: const <GpsPoint>[],
      mockLocationDetected: detected,
    );

Future<void> pumpBanner(WidgetTester tester, FakeTripsRepository trips) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tripsRepositoryProvider.overrideWithValue(trips),
      ],
      child: const MaterialApp(
        locale: Locale('en'), // locale pinned en (project decision)
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Column(
            children: <Widget>[MockLocationWarningBanner(vanId: 'van-01')],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  testWidgets('normal UX: real fixes → no warning banner', (tester) async {
    final trips = FakeTripsRepository([tripOf(today, false)]);

    await pumpBanner(tester, trips);

    expect(find.byKey(const Key('mock_location_banner')), findsNothing);
  });

  testWidgets('latched trip doc → localized warning banner shows',
      (tester) async {
    final trips = FakeTripsRepository([tripOf(today, true)]);

    await pumpBanner(tester, trips);

    expect(find.byKey(const Key('mock_location_banner')), findsOneWidget);
    expect(
      find.text(
        'Your phone is faking its location. Tracking continues, and the '
        'office will see this notice.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('latch flips LIVE while the banner is on screen', (tester) async {
    final trips = FakeTripsRepository([tripOf(today, false)]);
    await pumpBanner(tester, trips);
    expect(find.byKey(const Key('mock_location_banner')), findsNothing);

    // The app stays open when the engine latches mid-shift; the banner must
    // appear without any rebuild (the doc watch IS the state).
    await trips.setMockLocationDetected('trip-1', detected: true);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mock_location_banner')), findsOneWidget);
  });
}
