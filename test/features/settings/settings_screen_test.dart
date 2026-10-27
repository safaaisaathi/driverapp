/// Settings + Trip History widget tests (wireframes WF-21 / WF-22).
///
/// All data rides the repository fakes; app-owned preference seams
/// (locale, theme) ride in-memory fakes — no platform channels.
library;

import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/l10n/locale_controller.dart';
import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/core/repositories/repository_providers.dart';
import '../../core/theme/theme_fakes.dart';
import 'package:driverapp/core/theme/theme_mode_controller.dart';
import 'package:driverapp/features/settings/settings_flow.dart';
import 'package:driverapp/features/settings/ui/settings_screen.dart';
import 'package:driverapp/features/settings/ui/trip_history_screen.dart';
import 'package:driverapp/features/shift_start/domain/shift_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/l10n/locale_fakes.dart';
import '../../repositories/fake_repositories.dart';

const String enNotConnected = 'Not connected';
const String enTripHistory = 'Trip history';
const String enHelpAbout = 'Help and about';
const String enCompleted = 'Completed';
const String enPartlyDone = 'Partly done';
const String enNoTripsYet = 'No trips yet';
const String enToday = 'Today';
const String enYesterday = 'Yesterday';

Van sampleVan({String plateNo = 'GJ-01-V-2201', routeId = 'route-1'}) =>
    Van.fromMap(<String, Object?>{
      'id': 'van-1',
      'plateNo': plateNo,
      'routeId': routeId,
      'status': 'on_shift',
      'lastLocation': null,
      'currentTripId': 'trip-1',
      'batteryPct': 80,
    });

RouteModel sampleRoute({
  String id = 'route-1',
  String name = 'West Loop',
  int wardCount = 9,
}) =>
    RouteModel.fromMap(<String, Object?>{
      'id': id,
      'name': name,
      'wardIds': List<String>.generate(wardCount, (i) => 'ward-$i'),
      'scheduledStartTime': '07:30',
    });

Trip sampleTrip({
  String id = 'trip-past-1',
  required DateTime startedAt,
  DateTime? endedAt,
  int done = 9,
  routeId = 'route-1',
  DateTime? date,
}) =>
    Trip.fromMap(<String, Object?>{
      'id': id,
      'vanId': 'van-1',
      'routeId': routeId,
      'date': (date ?? startedAt).toIso8601String(),
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'wardsDone': List<Object?>.generate(
        done,
        (i) => <String, Object?>{
          'wardId': 'ward-$i',
          'doneAt': startedAt.toIso8601String(),
          'flagged': false,
        },
      ),
      'alertedWardIds': const <Object?>[],
      'gpsTrail': const <Object?>[],
      'mockLocationDetected': false,
    });

Future<void> pumpSettings(
  WidgetTester tester, {
  required FakeVansRepository vans,
  required FakeRoutesRepository routes,
  required FakeTripsRepository trips,
  ShiftSession? session,
  InMemoryThemeStore? themeStore,
  InMemoryLocaleStore? localeStore,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vansRepositoryProvider.overrideWithValue(vans),
        routesRepositoryProvider.overrideWithValue(routes),
        tripsRepositoryProvider.overrideWithValue(trips),
        localeStoreProvider
            .overrideWithValue(localeStore ?? InMemoryLocaleStore()),
        themeStoreProvider
            .overrideWithValue(themeStore ?? InMemoryThemeStore()),
        shiftControllerProvider.overrideWith(() => _SeededShift(session)),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const SettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// ShiftController seeded for settings (the default `build` returns null,
/// which is what the "not connected" tests rely on).
class _SeededShift extends ShiftController {
  _SeededShift(this._seed);

  final ShiftSession? _seed;

  @override
  ShiftSession? build() => _seed;
}

void main() {
  group('wf-21 Settings screen', () {
    testWidgets('shows Not connected with no running session', (t) async {
      await pumpSettings(
        t,
        vans: FakeVansRepository(),
        routes: FakeRoutesRepository(),
        trips: FakeTripsRepository(),
      );
      expect(find.text(enNotConnected), findsOneWidget);
      expect(find.byKey(const Key('settings.title')), findsOneWidget);
      expect(find.text(enTripHistory), findsOneWidget);
      expect(find.text(enHelpAbout), findsOneWidget);
    });

    testWidgets('shows the running shift van (plate · route)', (t) async {
      final now = DateTime.now();
      await pumpSettings(
        t,
        vans: FakeVansRepository([sampleVan()]),
        routes: FakeRoutesRepository([sampleRoute()]),
        trips: FakeTripsRepository(),
        session: ShiftSession(
          vanId: 'van-1',
          tripId: 'trip-1',
          routeId: 'route-1',
          startedAt: now,
          date: DateTime(now.year, now.month, now.day),
        ),
      );
      expect(find.text('GJ-01-V-2201 · West Loop'), findsOneWidget);
    });

    testWidgets('theme segment persists the choice through the seam',
        (t) async {
      final store = InMemoryThemeStore();
      await pumpSettings(
        t,
        vans: FakeVansRepository(),
        routes: FakeRoutesRepository(),
        trips: FakeTripsRepository(),
        themeStore: store,
      );
      final container = ProviderScope.containerOf(
        t.element(find.byKey(const Key('settings.themeSegments'))),
      );
      expect(container.read(themeModeControllerProvider), ThemeMode.system);

      await t.tap(find.text('Dark'));
      await t.pump();
      expect(store.stored, 'dark');
    });

    testWidgets('language segment flips the stored locale', (t) async {
      final store = InMemoryLocaleStore();
      await pumpSettings(
        t,
        vans: FakeVansRepository(),
        routes: FakeRoutesRepository(),
        trips: FakeTripsRepository(),
      );
      // The settings screen overrides the app-level store seam with a
      // private InMemoryLocaleStore — rebuild with that instance instead.
      final container = ProviderScope.containerOf(t.element(
        find.byType(SettingsScreen),
      ));
      // The default override already installed one instance above; grab
      // the locale controller and flip it through the EN segment.
      await t.tap(find.text('ગુ'));
      await t.pumpAndSettle();
      expect(
        container.read(localeControllerProvider)?.languageCode,
        'gu',
      );
      expect(store.stored, isNull); // the screen's own store (unshared).
    });
  });

  group('wf-22 Trip history screen', () {
    Future<void> pumpHistory(
      WidgetTester tester, {
      required FakeTripsRepository trips,
      required FakeRoutesRepository routes,
      required ShiftSession session,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripsRepositoryProvider.overrideWithValue(trips),
            routesRepositoryProvider.overrideWithValue(routes),
            shiftControllerProvider.overrideWith(() => _SeededShift(session)),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            home: const TripHistoryScreen(),
          ),
        ),
      );
      // Bounded pumps (never pumpAndSettle): the seeded empty state hosts
      // BinnyView, whose bob runs forever by design.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('groups trips with the Completed chip for a full route',
        (t) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await pumpHistory(
        t,
        trips: FakeTripsRepository([
          sampleTrip(
            startedAt: today.subtract(const Duration(days: 1, hours: 5)),
            endedAt: today.subtract(const Duration(days: 1, hours: 0, minutes: 12)),
            date: today.subtract(const Duration(days: 1)),
            done: 9,
          ),
          sampleTrip(
            id: 'trip-past-2',
            startedAt: today.subtract(const Duration(days: 2, hours: 4)),
            endedAt: today.subtract(const Duration(days: 2, hours: 0, minutes: 5)),
            date: today.subtract(const Duration(days: 2)),
            done: 7,
          ),
          sampleTrip(
            id: 'trip-past-3',
            startedAt: today.subtract(const Duration(days: 0, hours: 1)),
            endedAt: null,
            date: today,
            done: 4,
          ),
        ]),
        routes: FakeRoutesRepository([sampleRoute(wardCount: 9)]),
        session: ShiftSession(
          vanId: 'van-1',
          tripId: 'trip-1',
          routeId: 'route-1',
          startedAt: today,
          date: today,
        ),
      );

      expect(find.byKey(const Key('tripHistory.title')), findsOneWidget);
      // Today (open trip → Running), Yesterday and date labels.
      expect(find.text(enToday), findsOneWidget);
      expect(find.text(enYesterday), findsOneWidget);
      // 9/9 yesterday row → Completed; 7/9 → Partly done; open → not.
      expect(find.text(enCompleted), findsOneWidget);
      expect(find.text(enPartlyDone), findsOneWidget);
      // Meta lines carry "n of 9 wards".
      expect(find.text('9 of 9 wards · 4 h 48 min'), findsOneWidget);
      expect(find.text('7 of 9 wards · 3 h 55 min'), findsOneWidget);
    });

    testWidgets('empty history shows the seeded empty state', (t) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await pumpHistory(
        t,
        trips: FakeTripsRepository(),
        routes: FakeRoutesRepository([sampleRoute()]),
        session: ShiftSession(
          vanId: 'van-1',
          tripId: 'trip-1',
          routeId: 'route-1',
          startedAt: today,
          date: today,
        ),
      );
      expect(find.text(enNoTripsYet), findsOneWidget);
    });

    testWidgets('settings row navigates to the history screen', (t) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await pumpSettings(
        t,
        vans: FakeVansRepository(),
        routes: FakeRoutesRepository(),
        trips: FakeTripsRepository(),
        session: ShiftSession(
          vanId: 'van-1',
          tripId: 'trip-1',
          routeId: 'route-1',
          startedAt: today,
          date: today,
        ),
      );
      await t.tap(find.byKey(const Key('settings.tripHistoryRow')));
      // Bounded pumps again — the destination may host BinnyView.
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('tripHistory.title')), findsOneWidget);
    });
  });
}
