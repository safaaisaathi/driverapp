/// D1-new Start-shift screen tests (ticket 4, PRD-2 §0.16) —
/// container-based widget tests (pattern: mock_location_banner_test.dart):
/// the screen is pumped in a ProviderContainer with repository/seam fakes,
/// so no test reaches Firebase or a platform channel.
///
/// Pinned English strings follow the shift_start_screen_test.dart pattern;
/// keys are the stable d1-* widget seams.
library;

import 'package:driverapp/core/identity/driver_identity_controller.dart';
import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/core/repositories/repositories.dart';
import 'package:driverapp/core/config/firebase_bootstrap.dart';
import 'package:driverapp/core/theme/app_theme.dart';
import 'package:driverapp/features/shift_start/data/fcm_topics.dart'
    show driverMessagingGatewayProvider;
import 'package:driverapp/features/shift_start/domain/shift_session.dart';
import 'package:driverapp/features/shift_start/ui/code_start_screen.dart';
import 'package:driverapp/features/tracking/domain/tracking_engine.dart'
    show
        TrackingEngineState,
        TrackingStartResult,
        TrackingStartOutcome,
        TrackingResumeResult,
        TrackingResumeOutcome,
        TrackingRunStatus;
import 'package:driverapp/features/tracking/tracking_providers.dart'
    show
        trackingEngineProvider,
        trackingPermissionGatewayProvider,
        PermissionApproval,
        TrackingEngine,
        TrackingPermissionGateway;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/identity/driver_identity_fakes.dart';
import '../../models/sample_maps.dart';
import '../../repositories/fake_repositories.dart';

// -- pinned English strings (arb contract) ----------------------------------

const String enIdentityTitle = 'Start shift';
const String enCodeLabel = 'Code';
const String enCodeHint = 'XX-0000';
const String enCodeError = 'Wrong code. Try again.';
const String enContinue = 'Continue';
const String enStartShift = 'Start Shift';
const String enRetry = 'Retry';
const String enDriverName = 'Ramesh Patel';
const String enVanPlate = 'GJ-05-AB-1234';
const String enTwoWardsAllotted = '2 wards allotted';
const String enMaskedPhone = '98XXXXXX10';
const String enNotFoundTitle = 'Driver not found';
const String enNotFoundBody = 'Check the code with the office and try again.';
const String enLookupFailedTitle = "Couldn't check the code";
const String enLookupFailedBody = 'Check your connection and try again.';
const String enStartFailed =
    "Couldn't start the shift. Check the connection and try again.";
const String enWelcomeBackTitle = 'Welcome back';
const String enWelcomeBackBody = 'This phone remembers you.';
const String enStartMyShift = 'Start my Shift';
const String enChangeCode = 'Different driver?';
const String enOtherDriverName = 'Suresh Shah';

// -- fixtures ----------------------------------------------------------------

Van sampleVan({
  String id = 'van-01',
  String plateNo = 'GJ-05-AB-1234',
  String routeId = 'route-van',
}) =>
    Van.fromMap(<String, Object?>{
      'id': id,
      'plateNo': plateNo,
      'routeId': routeId,
      'status': 'idle',
      'lastLocation': null,
      'currentTripId': null,
      'batteryPct': 80,
    });

Driver sampleDriver({bool active = true}) => Driver.fromMap(<String, Object?>{
      ...driverDocMap(),
      'routeId': 'route-driver',
      'active': active,
    });

/// A second driver for the change-code path (a colleague sharing the
/// device enters a different code, spec story 14).
Driver otherDriver() => Driver.fromMap(<String, Object?>{
      ...driverDocMap(id: 'CD-5678'),
      'name': enOtherDriverName,
    });

/// A store pre-seeded as a returning device (ticket 3): setup done and
/// [code] remembered. The writes land synchronously into the map.
InMemoryDriverIdentityStore returningStore(String code) {
  final store = InMemoryDriverIdentityStore();
  store
    ..writeSetupDone(true)
    ..writeDriverCode(code);
  return store;
}

class RecordingMessagingGateway implements MessagingGateway {
  final List<String> topics = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> subscribeToTopic(String topic) async {
    topics.add(topic);
  }
}

/// Permission gateway that reports every check as already granted, so the
/// post-activation flow runs without ever showing a rationale screen.
class GrantAllPermissionGateway implements TrackingPermissionGateway {
  const GrantAllPermissionGateway();

  @override
  Future<PermissionApproval> ensureLocationWhileInUse() async =>
      PermissionApproval.granted;

  @override
  Future<PermissionApproval> ensureLocationBackground() async =>
      PermissionApproval.granted;

  @override
  Future<PermissionApproval> ensureNotifications() async =>
      PermissionApproval.granted;

  @override
  Future<PermissionApproval> ensureBatteryOptimizationExemption() async =>
      PermissionApproval.granted;

  @override
  Future<PermissionApproval> checkLocationWhileInUse() async =>
      PermissionApproval.granted;

  @override
  Future<PermissionApproval> checkLocationBackground() async =>
      PermissionApproval.granted;

  @override
  Future<PermissionApproval> checkNotifications() async =>
      PermissionApproval.granted;

  @override
  Future<PermissionApproval> checkBatteryOptimization() async =>
      PermissionApproval.granted;
}

/// Tracking engine fake that starts immediately and records the hand-over.
class RecordingTrackingEngine implements TrackingEngine {
  final List<({String tripId, String vanId})> startedWith = [];

  @override
  Stream<TrackingEngineState> get changes =>
      const Stream<TrackingEngineState>.empty();

  @override
  TrackingEngineState get state => const TrackingEngineState(
        status: TrackingRunStatus.idle,
      );

  @override
  Future<TrackingStartResult> start({
    required String tripId,
    required String vanId,
    required String notificationTitle,
    required String notificationBody,
  }) async {
    startedWith.add((tripId: tripId, vanId: vanId));
    return TrackingStartResult(TrackingStartOutcome.started);
  }

  @override
  Future<TrackingResumeResult> startForActiveShift({
    required String vanId,
    required String notificationTitle,
    required String notificationBody,
  }) async =>
      const TrackingResumeResult(outcome: TrackingResumeOutcome.resumed);

  @override
  Future<void> stop() async {}
}

class FlakyDriversRepository implements DriversRepository {
  FlakyDriversRepository(this.inner, this.failsRemaining);

  final DriversRepository inner;
  int failsRemaining;

  @override
  Future<Driver?> fetchDriver(String rawCode) {
    if (failsRemaining > 0) {
      failsRemaining--;
      throw const _LookupFailed();
    }
    return inner.fetchDriver(rawCode);
  }
}

final class _LookupFailed implements Exception {
  const _LookupFailed();
}

class FailingCreateTripsRepository extends FakeTripsRepository {
  bool fail = true;

  @override
  Future<Trip> createTrip(Trip trip) async {
    if (fail) throw const _CreateTripFailed();
    return super.createTrip(trip);
  }
}

final class _CreateTripFailed implements Exception {
  const _CreateTripFailed();
}

// -- harness -----------------------------------------------------------------

Future<ProviderContainer> pumpScreen(
  WidgetTester tester, {
  required DriversRepository driversRepo,
  required FakeVansRepository vans,
  required TripsRepository trips,
  InMemoryDriverIdentityStore? identityStore,
  void Function(BuildContext context)? onShiftStarted,
}) async {
  final container = ProviderContainer(
    overrides: [
      driversRepositoryProvider.overrideWithValue(driversRepo),
      vansRepositoryProvider.overrideWithValue(vans),
      tripsRepositoryProvider.overrideWithValue(trips),
      driverIdentityStoreProvider
          .overrideWithValue(identityStore ?? InMemoryDriverIdentityStore()),
      driverMessagingGatewayProvider
          .overrideWithValue(RecordingMessagingGateway()),
      // Post-activation seams: the permission flow auto-grants and the
      // engine records, so tests never touch platform channels.
      trackingPermissionGatewayProvider
          .overrideWithValue(const GrantAllPermissionGateway()),
      trackingEngineProvider.overrideWithValue(RecordingTrackingEngine()),
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
        home: CodeStartScreen(onShiftStarted: onShiftStarted),
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

/// Pumps until [condition] holds (async navigation hand-over).
Future<void> pumpUntilCondition(
  WidgetTester tester,
  bool Function() condition, {
  int maxPumps = 500,
}) async {
  for (var i = 0; i < maxPumps && !condition(); i++) {
    await tester.pump(const Duration(milliseconds: 25));
  }
  expect(condition(), isTrue, reason: 'Condition not met within pump limit');
}

RecordingTrackingEngine _engineOf(WidgetTester tester) =>
    ProviderScope.containerOf(
      tester.element(find.byType(CodeStartScreen)),
    ).read(trackingEngineProvider) as RecordingTrackingEngine;

RecordingMessagingGateway _messagingOf(WidgetTester tester) =>
    ProviderScope.containerOf(
      tester.element(find.byType(CodeStartScreen)),
    ).read(driverMessagingGatewayProvider) as RecordingMessagingGateway;

Future<void> submitCode(WidgetTester tester, String raw) async {
  await tester.enterText(find.byKey(const ValueKey('d1-code-field')), raw);
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('d1-code-continue')));
  await tester.pump();
}

/// The code field under test (the d1-* seam), read back as a widget.
TextField _codeFieldOf(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(const ValueKey('d1-code-field')));

/// Types [keystrokes] one keystroke at a time into the code field
/// (ticket 10: the flip is per-keystroke, so every keystroke must reach
/// the formatter the way the real IME sends it - appended to the field's
/// CURRENT content, the auto-dash included).
Future<void> typeCode(WidgetTester tester, String keystrokes) async {
  final field = find.byKey(const ValueKey('d1-code-field'));
  for (final char in keystrokes.split('')) {
    final current = tester.widget<TextField>(field).controller!.text;
    await tester.enterText(field, '$current$char');
    await tester.pump();
  }
}

// -- tests -------------------------------------------------------------------

void main() {
  testWidgets('invalid format: inline error, NO lookup call (a bad shape '
      'never reaches Firestore)', (tester) async {
    final drivers = FakeDriversRepository();
    await pumpScreen(
      tester,
      driversRepo: drivers,
      vans: FakeVansRepository([sampleVan()]),
      trips: FakeTripsRepository(),
    );

    await submitCode(tester, 'abc1234');

    expect(find.byKey(const ValueKey('d1-code-error')), findsOneWidget);
    expect(find.text(enCodeError), findsOneWidget);
    expect(drivers.lookups, isEmpty, reason: 'no Firestore call on a bad shape');
  });

  testWidgets('valid code: confirm card shows name, van plate, ward count '
      'and the masked phone', (tester) async {
    await pumpScreen(
      tester,
      driversRepo: FakeDriversRepository([sampleDriver()]),
      vans: FakeVansRepository([sampleVan()]),
      trips: FakeTripsRepository(),
    );

    await submitCode(tester, 'ab-1234');
    await pumpUntil(tester, find.byKey(const ValueKey('d1-confirm-card')));

    expect(find.text(enDriverName), findsOneWidget);
    expect(find.text(enVanPlate), findsOneWidget);
    expect(find.text(enTwoWardsAllotted), findsOneWidget);
    expect(find.text(enMaskedPhone), findsOneWidget);
    // The title and the code field stay on screen per the 9.6 template.
    expect(find.text(enIdentityTitle), findsOneWidget);
    expect(find.text(enCodeLabel), findsOneWidget);
  });

  testWidgets('Start Shift: activates the session, creates the trip from '
      'the driver\'s van, remembers the code and navigates', (tester) async {
    final vans = FakeVansRepository([sampleVan()]);
    final trips = FakeTripsRepository();
    final identityStore = InMemoryDriverIdentityStore();
    var navigated = false;
    await pumpScreen(
      tester,
      driversRepo: FakeDriversRepository([sampleDriver()]),
      vans: vans,
      trips: trips,
      identityStore: identityStore,
      onShiftStarted: (_) => navigated = true,
    );

    await submitCode(tester, 'AB-1234');
    await pumpUntil(tester, find.byKey(const ValueKey('d1-confirm-card')));
    await tester.tap(find.byKey(const ValueKey('d1-confirm-start')));
    await pumpUntilCondition(tester, () => navigated);

    // Session activated on the D2 seam, built from the driver's van.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CodeStartScreen)),
    );
    final session = container.read(shiftControllerProvider);
    expect(session, isNotNull);
    expect(session!.vanId, 'van-01');
    final trip = trips.trips.values.single;
    expect(trip.vanId, 'van-01');
    expect(trip.routeId, 'route-van', reason: 'routeId comes from the van');
    expect(session.tripId, trip.id);

    // Van marker writes + topic subscription (0.13 / 0.6.6).
    expect(vans.vans['van-01']!.status, VanStatus.onShift);
    expect(vans.vans['van-01']!.currentTripId, trip.id);
    expect(_messagingOf(tester).topics, ['van_van-01']);

    // The confirmed code is remembered on-device (0.16).
    expect(identityStore.storedDriverCode, 'AB-1234');

    // The tracking engine received the hand-over (old D1's post-activation
    // pattern).
    final engine = _engineOf(tester);
    expect(engine.startedWith.single.tripId, trip.id);
    expect(engine.startedWith.single.vanId, 'van-01');
  });

  testWidgets('not-found state with retry: seeding the driver afterwards '
      'recovers through the same code', (tester) async {
    final drivers = FakeDriversRepository();
    await pumpScreen(
      tester,
      driversRepo: drivers,
      vans: FakeVansRepository([sampleVan()]),
      trips: FakeTripsRepository(),
    );

    await submitCode(tester, 'ZZ-9999');
    await pumpUntil(tester, find.byKey(const ValueKey('d1-not-found')));
    expect(find.text(enNotFoundTitle), findsOneWidget);
    expect(find.text(enNotFoundBody), findsOneWidget);
    expect(drivers.lookups, ['ZZ-9999']);

    // The office seeds the driver; Retry re-looks-up the SAME code.
    drivers.drivers['ZZ-9999'] = sampleDriver();
    await tester.tap(find.byKey(const ValueKey('d1-not-found-retry')));
    await pumpUntil(tester, find.byKey(const ValueKey('d1-confirm-card')));
    expect(find.text(enDriverName), findsOneWidget);
  });

  testWidgets('lookup-failed (offline) state with retry recovers',
      (tester) async {
    final inner = FakeDriversRepository([sampleDriver()]);
    await pumpScreen(
      tester,
      driversRepo: FlakyDriversRepository(inner, 1),
      vans: FakeVansRepository([sampleVan()]),
      trips: FakeTripsRepository(),
    );

    await submitCode(tester, 'AB-1234');
    await pumpUntil(tester, find.byKey(const ValueKey('d1-lookup-failed')));
    expect(find.text(enLookupFailedTitle), findsOneWidget);
    expect(find.text(enLookupFailedBody), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('d1-lookup-failed-retry')));
    await pumpUntil(tester, find.byKey(const ValueKey('d1-confirm-card')));
    expect(find.text(enDriverName), findsOneWidget);
  });

  testWidgets('start write failure: localized error, the CTA stays '
      'available and retry starts once the write succeeds', (tester) async {
    final trips = FailingCreateTripsRepository();
    var navigated = false;
    await pumpScreen(
      tester,
      driversRepo: FakeDriversRepository([sampleDriver()]),
      vans: FakeVansRepository([sampleVan()]),
      trips: trips,
      onShiftStarted: (_) => navigated = true,
    );

    await submitCode(tester, 'AB-1234');
    await pumpUntil(tester, find.byKey(const ValueKey('d1-confirm-card')));
    await tester.tap(find.byKey(const ValueKey('d1-confirm-start')));
    await pumpUntil(tester, find.text(enStartFailed));
    expect(trips.trips, isEmpty, reason: 'the failed write created no doc');

    trips.fail = false;
    await tester.tap(
      find.byKey(const ValueKey('d1-confirm-start')).hitTestable(),
    );
    await pumpUntilCondition(tester, () => navigated);
    expect(trips.trips, hasLength(1));
  });

  // -- demo feedback 10/2026: the edit cycle after a search --------------------

  testWidgets('after a search the boxes sit unfocused; tapping them brings '
      'the search button back and hides the card, and the cycle repeats',
      (tester) async {
    final drivers = FakeDriversRepository([sampleDriver()]);
    await pumpScreen(
      tester,
      driversRepo: drivers,
      vans: FakeVansRepository([sampleVan()]),
      trips: FakeTripsRepository(),
    );

    await submitCode(tester, 'AB-1234');
    await pumpUntil(tester, find.byKey(const ValueKey('d1-confirm-card')));
    // Search done: the boxes dropped focus and the CTA is Start.
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('d1-code-field')))
          .focusNode!
          .hasFocus,
      isFalse,
    );
    expect(find.byKey(const ValueKey('d1-confirm-start')), findsOneWidget);

    // Tapping the boxes re-enters editing: the search button returns and
    // the confirm card hides.
    await tester.tap(find.byKey(const ValueKey('d1-code-cell-0')));
    await tester.pump();
    expect(find.byKey(const ValueKey('d1-code-continue')), findsOneWidget);
    expect(find.byKey(const ValueKey('d1-confirm-card')), findsNothing);

    // Re-searching lands on the card again, unfocused (the cycle).
    await submitCode(tester, 'AB-1234');
    await pumpUntil(tester, find.byKey(const ValueKey('d1-confirm-card')));
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('d1-code-field')))
          .focusNode!
          .hasFocus,
      isFalse,
    );
    expect(drivers.lookups, ['AB-1234', 'AB-1234']);
  });

  testWidgets('a searched wrong code is correctable: tapping the boxes swaps '
      'Retry for Continue with the code in view', (tester) async {
    final drivers = FakeDriversRepository();
    await pumpScreen(
      tester,
      driversRepo: drivers,
      vans: FakeVansRepository([sampleVan()]),
      trips: FakeTripsRepository(),
    );

    await submitCode(tester, 'ZZ-9999');
    await pumpUntil(tester, find.byKey(const ValueKey('d1-not-found')));
    expect(find.byKey(const ValueKey('d1-not-found-retry')), findsOneWidget);

    // Tapping the boxes re-enters editing: Continue returns for the code
    // in view — the correction path the demo asked for.
    await tester.tap(find.byKey(const ValueKey('d1-code-cell-0')));
    await tester.pump();
    expect(find.byKey(const ValueKey('d1-code-continue')), findsOneWidget);

    // The corrected code recovers through the same search.
    drivers.drivers['AB-1234'] = sampleDriver();
    await submitCode(tester, 'AB-1234');
    await pumpUntil(tester, find.byKey(const ValueKey('d1-confirm-card')));
    expect(find.text(enDriverName), findsOneWidget);
  });

  testWidgets('code hint and label render on the fresh screen', (tester) async {
    await pumpScreen(
      tester,
      driversRepo: FakeDriversRepository(),
      vans: FakeVansRepository([sampleVan()]),
      trips: FakeTripsRepository(),
    );

    expect(find.text(enIdentityTitle), findsOneWidget);
    expect(find.text(enCodeLabel), findsOneWidget);
    expect(find.text(enCodeHint), findsOneWidget);
    expect(find.text(enContinue), findsOneWidget);
    expect(find.byKey(const ValueKey('d1-code-error')), findsNothing);
  });

  // -- smart keyboard on the code field (ticket 10, issue #11) ---------------

  testWidgets('fresh code field: text keyboard, characters capitalized, '
      'autocorrect and suggestions off', (tester) async {
    await pumpScreen(
      tester,
      driversRepo: FakeDriversRepository(),
      vans: FakeVansRepository([sampleVan()]),
      trips: FakeTripsRepository(),
    );

    final field = _codeFieldOf(tester);
    expect(field.keyboardType, TextInputType.text);
    expect(field.textCapitalization, TextCapitalization.characters);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
  });

  testWidgets('typing: the 2nd letter lands, dash auto-inserted, keyboard '
      'flips to numeric; backspacing below re-flips to text', (tester) async {
    await pumpScreen(
      tester,
      driversRepo: FakeDriversRepository(),
      vans: FakeVansRepository([sampleVan()]),
      trips: FakeTripsRepository(),
    );

    await typeCode(tester, 'A');
    expect(_codeFieldOf(tester).controller!.text, 'A');
    expect(_codeFieldOf(tester).keyboardType, TextInputType.text);

    // The 2nd letter lands: the dash follows it and the keyboard flips to
    // the numeric keypad - the field keeps its focus and its content.
    await typeCode(tester, 'B');
    expect(_codeFieldOf(tester).controller!.text, 'AB-');
    expect(_codeFieldOf(tester).keyboardType, TextInputType.number);
    expect(_codeFieldOf(tester).focusNode!.hasFocus, isTrue);

    // The digits follow the dash on the numeric keypad.
    await typeCode(tester, '1234');
    expect(_codeFieldOf(tester).controller!.text, 'AB-1234');
    expect(_codeFieldOf(tester).keyboardType, TextInputType.number);

    // Backspace the dash: the letter half is still complete, so the
    // keyboard stays numeric, and the dash must not bounce back.
    await tester.enterText(find.byKey(const ValueKey('d1-code-field')), 'AB');
    await tester.pump();
    expect(_codeFieldOf(tester).controller!.text, 'AB');
    expect(_codeFieldOf(tester).keyboardType, TextInputType.number);

    // Backspace again, below the letter half: flip back to text.
    await tester.enterText(find.byKey(const ValueKey('d1-code-field')), 'A');
    await tester.pump();
    expect(_codeFieldOf(tester).controller!.text, 'A');
    expect(_codeFieldOf(tester).keyboardType, TextInputType.text);
  });

  testWidgets('paste: any accepted shape lands as a sane XX-0000 value '
      '(<= 7 chars) and the flip state matches the content', (tester) async {
    await pumpScreen(
      tester,
      driversRepo: FakeDriversRepository(),
      vans: FakeVansRepository([sampleVan()]),
      trips: FakeTripsRepository(),
    );

    for (final pasted in ['ab1234', 'AB-1234', 'ab-1234']) {
      await tester.enterText(find.byKey(const ValueKey('d1-code-field')), '');
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('d1-code-field')), pasted);
      await tester.pump();

      final field = _codeFieldOf(tester);
      expect(field.controller!.text, 'AB-1234', reason: 'pasting "$pasted"');
      expect(field.controller!.text.length, lessThanOrEqualTo(7),
          reason: 'pasting "$pasted"');
      expect(field.keyboardType, TextInputType.number,
          reason: 'pasting "$pasted"');
    }
  });

  testWidgets('paste: one letter plus a digit keeps the text keyboard (the '
      'flip counts letters, not characters)', (tester) async {
    await pumpScreen(
      tester,
      driversRepo: FakeDriversRepository(),
      vans: FakeVansRepository([sampleVan()]),
      trips: FakeTripsRepository(),
    );

    // The driver pasted a letter and a digit. The letter half is not done,
    // so the text keyboard must stay, otherwise the driver cannot type the
    // 2nd letter at all.
    await tester.enterText(find.byKey(const ValueKey('d1-code-field')), 'A1');
    await tester.pump();

    final field = _codeFieldOf(tester);
    expect(field.controller!.text, 'A1');
    expect(field.keyboardType, TextInputType.text);
  });

  testWidgets('paste over the code already typed: the pasted shape wins '
      'and the dash is (re)inserted', (tester) async {
    await pumpScreen(
      tester,
      driversRepo: FakeDriversRepository(),
      vans: FakeVansRepository([sampleVan()]),
      trips: FakeTripsRepository(),
    );

    await typeCode(tester, 'AB');
    expect(_codeFieldOf(tester).controller!.text, 'AB-');

    // The driver selects the old code and pastes a shorter one: the paste
    // brings characters, so the canonical shape is rebuilt.
    await tester.enterText(find.byKey(const ValueKey('d1-code-field')), 'ab12');
    await tester.pump();
    expect(_codeFieldOf(tester).controller!.text, 'AB-12');
    expect(_codeFieldOf(tester).keyboardType, TextInputType.number);
  });

  testWidgets('only letters, digits and the auto-dash are accepted; the '
      'field caps at 7 display chars', (tester) async {
    await pumpScreen(
      tester,
      driversRepo: FakeDriversRepository(),
      vans: FakeVansRepository([sampleVan()]),
      trips: FakeTripsRepository(),
    );

    await tester.enterText(
        find.byKey(const ValueKey('d1-code-field')), 'ab@#123456789');
    await tester.pump();
    expect(_codeFieldOf(tester).controller!.text, 'AB-1234');
    expect(_codeFieldOf(tester).controller!.text.length, 7);

    // Junk before the letters is dropped as well.
    await tester.enterText(find.byKey(const ValueKey('d1-code-field')), '@#ab');
    await tester.pump();
    expect(_codeFieldOf(tester).controller!.text, 'AB-');
    expect(_codeFieldOf(tester).keyboardType, TextInputType.number);
  });

  testWidgets('change-code mode: the same entry form flips the keyboard '
      'identically (no welcome-mode behavior change)', (tester) async {
    final drivers = FakeDriversRepository([sampleDriver()]);
    await pumpScreen(
      tester,
      driversRepo: drivers,
      vans: FakeVansRepository([sampleVan()]),
      trips: FakeTripsRepository(),
      identityStore: returningStore('AB-1234'),
    );
    await pumpUntil(tester, find.byKey(const ValueKey('d1-welcome-card')));

    await tester.tap(find.byKey(const ValueKey('d1-change-code')));
    await tester.pump();
    expect(find.byKey(const ValueKey('d1-code-field')), findsOneWidget);

    await typeCode(tester, 'AB');
    expect(_codeFieldOf(tester).controller!.text, 'AB-');
    expect(_codeFieldOf(tester).keyboardType, TextInputType.number);
  });

  // -- welcome-back card + change-code (ticket 5, PRD-2 §0.16) ----------------

  testWidgets('returning device: welcome-back card from a live fetch, the '
      'code field never shows first', (tester) async {
    final drivers = FakeDriversRepository([sampleDriver()]);
    await pumpScreen(
      tester,
      driversRepo: drivers,
      vans: FakeVansRepository([sampleVan()]),
      trips: FakeTripsRepository(),
      identityStore: returningStore('AB-1234'),
    );

    // The lookup runs on its own; no tap anywhere.
    await pumpUntil(tester, find.byKey(const ValueKey('d1-welcome-card')));

    // Card content is the LIVE-fetched record — the store only held the
    // code (story 13: name + code + ward count).
    expect(find.text(enWelcomeBackTitle), findsOneWidget);
    expect(find.text(enWelcomeBackBody), findsOneWidget);
    expect(find.text(enDriverName), findsOneWidget);
    expect(find.text('AB-1234'), findsOneWidget);
    expect(find.text(enTwoWardsAllotted), findsOneWidget);
    // No code entry first; the change-code option is visible below.
    expect(find.byKey(const ValueKey('d1-code-field')), findsNothing);
    expect(find.byKey(const ValueKey('d1-change-code')), findsOneWidget);
    expect(find.text(enChangeCode), findsOneWidget);
    // The primary CTA is Start my Shift on the pinned bar.
    expect(find.byKey(const ValueKey('d1-welcome-start')), findsOneWidget);
    expect(find.text(enStartMyShift), findsOneWidget);
    // Exactly one lookup, fired by the mount itself.
    expect(drivers.lookups, ['AB-1234']);
  });

  testWidgets('change-code reveals the entry form; a new confirm overwrites '
      'the remembered code and never re-fires the auto-lookup', (tester) async {
    final drivers = FakeDriversRepository([sampleDriver(), otherDriver()]);
    final identityStore = returningStore('AB-1234');
    await pumpScreen(
      tester,
      driversRepo: drivers,
      vans: FakeVansRepository([sampleVan()]),
      trips: FakeTripsRepository(),
      identityStore: identityStore,
    );
    await pumpUntil(tester, find.byKey(const ValueKey('d1-welcome-card')));

    await tester.tap(find.byKey(const ValueKey('d1-change-code')));
    await tester.pump();

    // The regular entry form; the remembered code is NOT cleared (only a
    // new confirm overwrites it).
    expect(find.byKey(const ValueKey('d1-code-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('d1-welcome-card')), findsNothing);
    expect(identityStore.storedDriverCode, 'AB-1234');

    // A colleague confirms with their own code (story 14; any case works).
    await submitCode(tester, 'cd-5678');
    await pumpUntil(tester, find.byKey(const ValueKey('d1-confirm-card')));
    expect(find.text(enOtherDriverName), findsOneWidget);
    // The welcome card stays gone; the remembered code was replaced.
    expect(find.byKey(const ValueKey('d1-welcome-card')), findsNothing);
    expect(identityStore.storedDriverCode, 'CD-5678');
    // One auto-lookup (the old code) + the manual entry. The new remembered
    // code never re-looked-up itself on rebuild.
    expect(drivers.lookups, ['AB-1234', 'CD-5678']);
  });

  testWidgets('stale remembered code: not-found with the entry form back, '
      'no re-trigger loop, and a fresh entry recovers', (tester) async {
    final drivers = FakeDriversRepository();
    final identityStore = returningStore('ZZ-9999');
    await pumpScreen(
      tester,
      driversRepo: drivers,
      vans: FakeVansRepository([sampleVan()]),
      trips: FakeTripsRepository(),
      identityStore: identityStore,
    );

    // The auto-lookup lands in the flow's not-found phase.
    await pumpUntil(tester, find.byKey(const ValueKey('d1-not-found')));
    expect(find.text(enNotFoundTitle), findsOneWidget);
    expect(find.text(enNotFoundBody), findsOneWidget);
    expect(drivers.lookups, ['ZZ-9999']);
    // The entry form is available again with the stale code PRE-FILLED in
    // the boxes (the driver sees what was checked, demo feedback
    // 10/2026); the CTA carries the Continue of the visible code.
    expect(find.byKey(const ValueKey('d1-code-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('d1-code-continue')), findsOneWidget);

    // The stale code must not re-trigger lookups on rebuilds.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(drivers.lookups, ['ZZ-9999'],
        reason: 'the stale code is attempted once');

    // A fresh entry recovers; the stale code is overwritten.
    drivers.drivers['AB-1234'] = sampleDriver();
    await submitCode(tester, 'AB-1234');
    await pumpUntil(tester, find.byKey(const ValueKey('d1-confirm-card')));
    expect(find.text(enDriverName), findsOneWidget);
    expect(identityStore.storedDriverCode, 'AB-1234');
  });

  testWidgets('change-code is reversible: the top-left back button returns '
      'to the welcome card and the auto-lookup re-lands', (tester) async {
    final drivers = FakeDriversRepository([sampleDriver()]);
    final identityStore = returningStore('AB-1234');
    await pumpScreen(
      tester,
      driversRepo: drivers,
      vans: FakeVansRepository([sampleVan()]),
      trips: FakeTripsRepository(),
      identityStore: identityStore,
    );
    await pumpUntil(tester, find.byKey(const ValueKey('d1-welcome-card')));

    await tester.tap(find.byKey(const ValueKey('d1-change-code')));
    await tester.pump();
    // The new-user form carries the top-left back button.
    expect(find.byKey(const ValueKey('d1-change-back')), findsOneWidget);

    // Back returns to the welcome card; the remembered code re-looks-up
    // so the card re-lands exactly like on launch.
    await tester.tap(find.byKey(const ValueKey('d1-change-back')));
    await pumpUntil(tester, find.byKey(const ValueKey('d1-welcome-card')));
    expect(find.byKey(const ValueKey('d1-change-back')), findsNothing);
    expect(drivers.lookups, ['AB-1234', 'AB-1234']);
  });

  testWidgets('system back inside the change-code form returns to the '
      'welcome card instead of leaving the app', (tester) async {
    final drivers = FakeDriversRepository([sampleDriver()]);
    await pumpScreen(
      tester,
      driversRepo: drivers,
      vans: FakeVansRepository([sampleVan()]),
      trips: FakeTripsRepository(),
      identityStore: returningStore('AB-1234'),
    );
    await pumpUntil(tester, find.byKey(const ValueKey('d1-welcome-card')));

    await tester.tap(find.byKey(const ValueKey('d1-change-code')));
    await tester.pump();
    expect(find.byKey(const ValueKey('d1-change-back')), findsOneWidget);

    // The Android back gesture: maybePop honours the PopScope and lands
    // back on the welcome card.
    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await pumpUntil(tester, find.byKey(const ValueKey('d1-welcome-card')));
    expect(find.byKey(const ValueKey('d1-change-back')), findsNothing);
  });

  testWidgets('offline auto-lookup: lookup-failed state with the entry form '
      'back; a fresh entry recovers through it', (tester) async {
    final inner = FakeDriversRepository([sampleDriver()]);
    await pumpScreen(
      tester,
      driversRepo: FlakyDriversRepository(inner, 1),
      vans: FakeVansRepository([sampleVan()]),
      trips: FakeTripsRepository(),
      identityStore: returningStore('AB-1234'),
    );

    // The auto-lookup fails offline; the connection copy shows.
    await pumpUntil(tester, find.byKey(const ValueKey('d1-lookup-failed')));
    expect(find.text(enLookupFailedTitle), findsOneWidget);
    expect(find.text(enLookupFailedBody), findsOneWidget);
    expect(find.byKey(const ValueKey('d1-code-field')), findsOneWidget);

    // The failed remembered code is pre-filled in the boxes (demo
    // feedback 10/2026): the driver sees what was checked, and the CTA
    // carries the Continue of the code in view.
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('d1-code-field')))
          .controller!
          .text,
      'AB-1234',
    );
    expect(find.byKey(const ValueKey('d1-code-continue')), findsOneWidget);

    // The driver types their code and recovers through the same form.
    await submitCode(tester, 'AB-1234');
    await pumpUntil(tester, find.byKey(const ValueKey('d1-confirm-card')));
    expect(find.text(enDriverName), findsOneWidget);
  });

  testWidgets('Start from the welcome-back card activates the session like '
      'the confirm card start', (tester) async {
    final vans = FakeVansRepository([sampleVan()]);
    final trips = FakeTripsRepository();
    final identityStore = returningStore('AB-1234');
    var navigated = false;
    await pumpScreen(
      tester,
      driversRepo: FakeDriversRepository([sampleDriver()]),
      vans: vans,
      trips: trips,
      identityStore: identityStore,
      onShiftStarted: (_) => navigated = true,
    );
    await pumpUntil(tester, find.byKey(const ValueKey('d1-welcome-card')));

    await tester.tap(find.byKey(const ValueKey('d1-welcome-start')));
    await pumpUntilCondition(tester, () => navigated);

    // The same activation as the confirm-card start (ticket 4): session
    // built from the driver's van, trip recorded, van marked, topic
    // subscribed, tracking hand-over.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CodeStartScreen)),
    );
    final session = container.read(shiftControllerProvider);
    expect(session, isNotNull);
    expect(session!.vanId, 'van-01');
    final trip = trips.trips.values.single;
    expect(trip.vanId, 'van-01');
    expect(trip.routeId, 'route-van', reason: 'routeId comes from the van');
    expect(session.tripId, trip.id);
    expect(vans.vans['van-01']!.status, VanStatus.onShift);
    expect(vans.vans['van-01']!.currentTripId, trip.id);
    expect(_messagingOf(tester).topics, ['van_van-01']);
    expect(identityStore.storedDriverCode, 'AB-1234');
    final engine = _engineOf(tester);
    expect(engine.startedWith.single.tripId, trip.id);
    expect(engine.startedWith.single.vanId, 'van-01');
  });

  // OTP-box rendering (driver demo feedback 2026-10-30): the code entry
  // paints one box per character — 2 letter cells, the pre-rendered dash
  // (never a box), 4 digit cells — while the d1-code-field TextField
  // keeps the invisible edit seam.
  group('the code entry box row', () {
    Finder charBox(char) => find.descendant(
          of: find.byKey(const ValueKey('d1-code-boxes')),
          matching: find.text(char),
        );

    testWidgets('renders empty: 6 border cells + the pre-rendered dash, '
        'no characters', (tester) async {
      await pumpScreen(
        tester,
        driversRepo: FakeDriversRepository(),
        vans: FakeVansRepository([sampleVan()]),
        trips: FakeTripsRepository(),
      );
      await pumpUntil(tester, find.byKey(const ValueKey('d1-code-boxes')));

      expect(charBox('-'), findsOneWidget,
          reason: 'the dash is pre-rendered text, not a cell');
      for (final char in ['A', 'B', '1', '2', '3', '4']) {
        expect(charBox(char), findsNothing, reason: 'char "$char" absent');
      }
      expect(
        tester.widgetList<TextField>(
          find.descendant(
            of: find.byKey(const ValueKey('d1-code-boxes')),
            matching: find.byKey(const ValueKey('d1-code-field')),
          ),
        ),
        isNotEmpty,
        reason: 'the editing seam keeps the d1-code-field TextField',
      );
    });

    testWidgets('typed characters each land in their own cell ' 
        '(letters then digits), no dash cell', (tester) async {
      await pumpScreen(
        tester,
        driversRepo: FakeDriversRepository(),
        vans: FakeVansRepository([sampleVan()]),
        trips: FakeTripsRepository(),
      );
      await pumpUntil(tester, find.byKey(const ValueKey('d1-code-boxes')));

      await typeCode(tester, 'AB');
      expect(charBox('A'), findsOneWidget);
      expect(charBox('B'), findsOneWidget);
      expect(charBox('-'), findsOneWidget);
      for (final char in ['1', '2', '3', '4']) {
        expect(charBox(char), findsNothing);
      }

      await typeCode(tester, '12');
      expect(charBox('1'), findsOneWidget);
      expect(charBox('2'), findsOneWidget);
      for (final char in ['3', '4']) {
        expect(charBox(char), findsNothing);
      }
    });

    testWidgets('junk and a whole pasted code render through the same '
        'cells (the box row mirrors the hidden field value)', (tester) async {
      await pumpScreen(
        tester,
        driversRepo: FakeDriversRepository(),
        vans: FakeVansRepository([sampleVan()]),
        trips: FakeTripsRepository(),
      );
      await pumpUntil(tester, find.byKey(const ValueKey('d1-code-boxes')));

      // A full paste shows six chars: A B dash 1 2 3 4 — the dash is text,
      // the digits land per cell.
      await tester.enterText(
          find.byKey(const ValueKey('d1-code-field')), 'AB-1234');
      await tester.pump();
      expect(charBox('A'), findsOneWidget);
      expect(charBox('B'), findsOneWidget);
      expect(charBox('1'), findsOneWidget);
      expect(charBox('2'), findsOneWidget);
      expect(charBox('3'), findsOneWidget);
      expect(charBox('4'), findsOneWidget);

      // A bad shape ('A1'): the same per-cell order, no invented dash.
      await tester.enterText(find.byKey(const ValueKey('d1-code-field')), '');
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('d1-code-field')), 'A1');
      await tester.pump();
      expect(charBox('A'), findsOneWidget);
      expect(charBox('1'), findsOneWidget);
      for (final char in ['B', '2', '3', '4']) {
        expect(charBox(char), findsNothing);
      }
    });
  });
}
