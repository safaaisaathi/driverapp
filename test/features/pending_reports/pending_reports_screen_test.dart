import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:driverapp/core/domain/ist_clock.dart';
import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/core/repositories/repositories.dart';
import 'package:driverapp/core/theme/app_theme.dart';
import 'package:driverapp/features/pending_reports/ui/pending_reports_screen.dart';
import 'package:driverapp/features/shift_start/domain/shift_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../repositories/fake_repositories.dart';

/// D4 Pending Reports widget tests — spec seam 1: every Firebase touch is a
/// fake behind the repository providers (`test/repositories/fake_repositories.dart`).
///
/// Acceptance (ticket 10):
/// - the list is exactly today's `missed_collection` complaints for the
///   route's wards, statuses received/assigned (Today IST deterministic),
/// - "Will Revisit" → `status = assigned`; "Done" → `status = resolved` +
///   `resolvedAt` (contract shape; `resolvedPhotoUrl` stays unset), other
///   fields untouched, no other complaint ever touched, no batch writes,
/// - out-of-scope complaints (other ward/category/status/day) never appear,
/// - loading / empty ("nothing pending") / error / offline states localized,
/// - rows use big tap targets (≥ 56 dp, contract section 6).

const String enNothingPending = 'Nothing pending';
const String enPendingReportsTitle = 'Pending reports';
const String enWillRevisit = 'Will Revisit';
const String enDone = 'Done';
const String enLoading = 'Loading…';
const String enError = 'Something went wrong';
const String enOffline = "You're offline";
const String enRetry = 'Retry';

/// One running shift's identity (D4 reads it for the route context). The
/// started instant is pinned: 2026-10-24 06:30 UTC = 12:00 IST, so "Today"
/// resolves deterministically to the 2026-10-24 IST collection day and
/// [utcStartOfIstDay] stays IST-correct on any test-runner zone.
final DateTime shiftStartedAt = DateTime.utc(2026, 10, 24, 6, 30);
final DateTime expectedDay = utcStartOfIstDay(shiftStartedAt);

const String devRouteId = 'route-1';
const List<String> devWardIds = <String>['ward-1', 'ward-2'];

RouteModel devRoute() => RouteModel.fromMap(<String, Object?>{
      'id': devRouteId,
      'name': 'Vasna–Bavka',
      'wardIds': devWardIds,
      'scheduledStartTime': '07:30',
    });

ShiftSession runningShiftSession() => ShiftSession(
      vanId: 'van-1',
      tripId: 'trip-1',
      routeId: devRouteId,
      startedAt: shiftStartedAt,
      date: expectedDay,
    );

// -- seed helpers ------------------------------------------------------------

/// A 0.2 `complaints` doc map. Timestamp-shaped values follow
/// the same encodings the model layer normalizes (`firestore_time.dart`).
Map<String, Object?> complaintDocMap({
  required String id,
  required String ticketId,
  required String? wardId,
  required String category,
  required String status,
  required Object? createdAt,
  Object? resolvedAt,
  String? assignedTo,
  int escalationLevel = 0,
  String? note = '',
}) =>
    <String, Object?>{
      'id': id,
      'ticketId': ticketId,
      'deviceId': 'device-1',
      'category': category,
      'photoUrl': 'complaints/$id/photo.jpg',
      'location': {'lat': 22.7751, 'lng': 73.7088},
      'wardId': wardId,
      'createdAt': createdAt,
      'status': status,
      'assignedTo': assignedTo,
      'escalationLevel': escalationLevel,
      'resolvedPhotoUrl': null,
      'resolvedAt': resolvedAt,
      'mergedInto': null,
      'note': note,
    };

Complaint seedComplaint({
  required String id,
  required String ticketId,
  required String? wardId,
  required String category,
  required String status,
  required DateTime createdAt,
  DateTime? resolvedAt,
  String? assignedTo,
  int escalationLevel = 0,
}) =>
    Complaint.fromMap(complaintDocMap(
      id: id,
      ticketId: ticketId,
      wardId: wardId,
      category: category,
      status: status,
      createdAt: Timestamp.fromDate(createdAt),
      resolvedAt: resolvedAt == null ? null : Timestamp.fromDate(resolvedAt),
      assignedTo: assignedTo,
      escalationLevel: escalationLevel,
    ));

/// The complaints the fake's day-window sees as "today". The repository
/// seam (fake and Firestore impl alike) brackets the day range from the
/// passed value's calendar fields — `DateTime(day.year, day.month,
/// day.day)` — so the seeds are constructed as local DateTimes of the
/// IST collection day (2026-10-24, the IST day of the pinned shift start).
/// In/out determination then holds on any test-runner zone.
final DateTime todayReportAt = DateTime(2026, 10, 24, 10, 0);
final DateTime yesterdayReportAt = DateTime(2026, 10, 23, 23, 59);
final DateTime nextDayReportAt = DateTime(2026, 10, 25, 0, 1);

/// In-scope: `missed_collection`, this route's wards, today, open statuses.
final Complaint inScopeReceived = seedComplaint(
  id: 'c-1',
  ticketId: 'PMH-20261024-0001',
  wardId: 'ward-1',
  category: 'missed_collection',
  status: 'received',
  createdAt: todayReportAt,
);

final Complaint inScopeAssigned = seedComplaint(
  id: 'c-2',
  ticketId: 'PMH-20261024-0002',
  wardId: 'ward-2',
  category: 'missed_collection',
  status: 'assigned',
  createdAt: DateTime(2026, 10, 24, 11, 0),
);

/// Out of scope: wrong ward / wrong category / closed statuses / other days.
final Complaint wrongWardReceived = seedComplaint(
  id: 'c-3',
  ticketId: 'PMH-20261024-0003',
  wardId: 'ward-9',
  category: 'missed_collection',
  status: 'received',
  createdAt: todayReportAt,
);

final Complaint wrongCategoryReceived = seedComplaint(
  id: 'c-4',
  ticketId: 'PMH-20261024-0004',
  wardId: 'ward-1',
  category: 'garbage_dump',
  status: 'received',
  createdAt: todayReportAt,
);

final Complaint resolvedStatusToday = seedComplaint(
  id: 'c-5',
  ticketId: 'PMH-20261024-0005',
  wardId: 'ward-1',
  category: 'missed_collection',
  status: 'resolved',
  createdAt: todayReportAt,
);

final Complaint escalatedStatusToday = seedComplaint(
  id: 'c-6',
  ticketId: 'PMH-20261024-0006',
  wardId: 'ward-1',
  category: 'missed_collection',
  status: 'escalated',
  createdAt: todayReportAt,
);

final Complaint yesterdayReceived = seedComplaint(
  id: 'c-7',
  ticketId: 'PMH-20261023-0007',
  wardId: 'ward-1',
  category: 'missed_collection',
  status: 'received',
  createdAt: yesterdayReportAt,
);

final Complaint nextDayReceived = seedComplaint(
  id: 'c-8',
  ticketId: 'PMH-20261025-0008',
  wardId: 'ward-1',
  category: 'missed_collection',
  status: 'received',
  createdAt: nextDayReportAt,
);

/// Every complaint that must NEVER surface on D4.
List<Complaint> allOutOfScope() => [
      wrongWardReceived,
      wrongCategoryReceived,
      resolvedStatusToday,
      escalatedStatusToday,
      yesterdayReceived,
      nextDayReceived,
    ];

// -- scripted fakes (test-local, layered on the shared fakes) -----------------

/// Records the exact repository calls so tests can assert the query shape
/// and the per-complaint write policy (no batch writes).
class RecordingComplaintsRepository extends FakeComplaintsRepository {
  RecordingComplaintsRepository([super.seed]);

  /// Last watch arguments, verbatim from the controller.
  ({
    List<String> wardIds,
    DateTime day,
    List<ComplaintStatus> statuses,
  })? lastQuery;

  /// One entry per `updateStatus` call: `"complaintId:status"`.
  final List<String> statusCalls = [];

  /// The [resolvedAt] paired with each `updateStatus` call.
  final List<DateTime?> resolvedAtCalls = [];

  @override
  Stream<List<Complaint>> watchMissedCollectionComplaints({
    required List<String> wardIds,
    required DateTime day,
    required List<ComplaintStatus> statuses,
  }) {
    lastQuery = (wardIds: wardIds, day: day, statuses: statuses);
    return super.watchMissedCollectionComplaints(
      wardIds: wardIds,
      day: day,
      statuses: statuses,
    );
  }

  @override
  Future<void> updateStatus(
    String complaintId,
    ComplaintStatus status, {
    DateTime? resolvedAt,
  }) async {
    statusCalls.add('$complaintId:${status.value}');
    resolvedAtCalls.add(resolvedAt);
    await super.updateStatus(complaintId, status, resolvedAt: resolvedAt);
  }
}

/// Watch stream fails [failures] times before delegating to the shared fake.
class FlakyWatchComplaintsRepository extends FakeComplaintsRepository {
  FlakyWatchComplaintsRepository(this.failures, [super.seed]);

  final int failures;
  int _watched = 0;

  @override
  Stream<List<Complaint>> watchMissedCollectionComplaints({
    required List<String> wardIds,
    required DateTime day,
    required List<ComplaintStatus> statuses,
  }) {
    if (_watched++ < failures) {
      return Stream<List<Complaint>>.error(_WatchFailed());
    }
    return super.watchMissedCollectionComplaints(
      wardIds: wardIds,
      day: day,
      statuses: statuses,
    );
  }
}

final class _WatchFailed implements Exception {
  const _WatchFailed();
}

/// A transport-shaped failure: carries a `code` getter, i.e. the same shape
/// Firestore surfaces when the connection is unavailable (no Firebase import
/// needed at the seam — the duck-typed `code` check lives in the flow).
final class _UnavailableShaped implements Exception {
  final String code;

  const _UnavailableShaped(this.code);
}

class OfflineWatchComplaintsRepository extends FakeComplaintsRepository {
  OfflineWatchComplaintsRepository([super.seed]);

  @override
  Stream<List<Complaint>> watchMissedCollectionComplaints({
    required List<String> wardIds,
    required DateTime day,
    required List<ComplaintStatus> statuses,
  }) => Stream<List<Complaint>>.error(const _UnavailableShaped('unavailable'));
}

/// Never emits a snapshot: the loading state must hold while the first
/// snapshot is pending.
class NeverEmittingComplaintsRepository extends FakeComplaintsRepository {
  NeverEmittingComplaintsRepository([super.seed]);

  @override
  Stream<List<Complaint>> watchMissedCollectionComplaints({
    required List<String> wardIds,
    required DateTime day,
    required List<ComplaintStatus> statuses,
  }) => const Stream<List<Complaint>>.empty();
}

/// `updateStatus` fails for the first [failures] writes; later ones land in
/// the inner fake (the complaint stays untouched on the failure).
class FlakyWriteComplaintsRepository extends FakeComplaintsRepository {
  FlakyWriteComplaintsRepository(this.failures, [super.seed]);

  final int failures;
  int _attempts = 0;

  @override
  Future<void> updateStatus(
    String complaintId,
    ComplaintStatus status, {
    DateTime? resolvedAt,
  }) async {
    if (_attempts++ < failures) {
      throw const _WriteFailed();
    }
    await super.updateStatus(complaintId, status, resolvedAt: resolvedAt);
  }
}

final class _WriteFailed implements Exception {
  const _WriteFailed();
}

// -- harness -----------------------------------------------------------------

Future<ProviderContainer> pumpPendingReports(
  WidgetTester tester, {
  required ComplaintsRepository complaints,
  required RoutesRepository routes,
}) async {
  final container = ProviderContainer(overrides: [
    complaintsRepositoryProvider.overrideWithValue(complaints),
    routesRepositoryProvider.overrideWithValue(routes),
  ]);
  // D4 runs inside a started shift: activate the session up front so the
  // first build already has the route context (no D1 in this harness).
  container
      .read(shiftControllerProvider.notifier)
      .activate(runningShiftSession());
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const PendingReportsScreen(),
      ),
    ),
  );
  return container;
}

/// Pumps in small steps until [finder] finds a widget or gives up.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 60,
}) async {
  for (var i = 0; i < maxPumps && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 25));
  }
  expect(finder, findsOneWidget);
}

/// Lets async controller work land without expecting a specific widget.
Future<void> pumpFrames(WidgetTester tester, [int pumps = 12]) async {
  for (var i = 0; i < pumps; i++) {
    await tester.pump(const Duration(milliseconds: 25));
  }
}

/// `actual` keeps every 0.2 field of [seed] except the keys in [changed].
void expectFieldsUntouched(
  Complaint actual,
  Complaint seed,
  Set<String> changed,
) {
  final actualMap = actual.toMap();
  final seedMap = seed.toMap();
  for (final key in seedMap.keys) {
    if (!changed.contains(key)) {
      expect(
        actualMap[key],
        seedMap[key],
        reason: 'field "$key" of complaint ${seed.id} must stay untouched',
      );
    }
  }
}

// -- tests -------------------------------------------------------------------

void main() {
  testWidgets(
      'loads through the exact repository query: route wardIds, '
      'Today (IST) of the running shift, statuses received + assigned',
      (tester) async {
    final complaints = RecordingComplaintsRepository([inScopeReceived]);
    await pumpPendingReports(
      tester,
      complaints: complaints,
      routes: FakeRoutesRepository([devRoute()]),
    );
    await pumpFrames(tester);

    final query = complaints.lastQuery;
    expect(query, isNotNull);
    expect(query!.wardIds, devWardIds,
        reason: 'the route wardIds in visiting order');
    // Today (IST): the collection-day calendar date the repository seam
    // brackets — fields resolved by the domain clock (IST), never the
    // runner's zone.
    final istDay = todayIST(shiftStartedAt);
    expect(query.day.year, istDay.year);
    expect(query.day.month, istDay.month);
    expect(query.day.day, istDay.day);
    expect(
      query.statuses,
      [ComplaintStatus.received, ComplaintStatus.assigned],
    );
  });

  testWidgets(
      'lists exactly the in-scope reports (today, route wards, '
      'missed_collection, received/assigned); all out-of-scope ones never '
      'appear', (tester) async {
    final complaints = RecordingComplaintsRepository([
      inScopeReceived,
      inScopeAssigned,
      ...allOutOfScope(),
    ]);
    await pumpPendingReports(
      tester,
      complaints: complaints,
      routes: FakeRoutesRepository([devRoute()]),
    );
    await pumpUntil(tester, find.text('PMH-20261024-0001'));
    expect(find.text('PMH-20261024-0002'), findsOneWidget);
    expect(find.byKey(const ValueKey('d4-row-c-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('d4-row-c-2')), findsOneWidget);

    // Out of scope: wrong ward, wrong category, resolved/escalated,
    // other days — never appear.
    expect(find.text('PMH-20261024-0003'), findsNothing);
    expect(find.text('PMH-20261024-0004'), findsNothing);
    expect(find.text('PMH-20261024-0005'), findsNothing);
    expect(find.text('PMH-20261024-0006'), findsNothing);
    expect(find.text('PMH-20261023-0007'), findsNothing);
    expect(find.text('PMH-20261025-0008'), findsNothing);
    expect(find.byKey(const ValueKey('d4-row-c-3')), findsNothing);
    expect(find.byKey(const ValueKey('d4-row-c-4')), findsNothing);
    expect(find.byKey(const ValueKey('d4-row-c-5')), findsNothing);
    expect(find.byKey(const ValueKey('d4-row-c-6')), findsNothing);
    expect(find.byKey(const ValueKey('d4-row-c-7')), findsNothing);
    expect(find.byKey(const ValueKey('d4-row-c-8')), findsNothing);
  });

  testWidgets('empty state shows the localized nothing-pending line when '
      'every report is out of scope', (tester) async {
    final complaints = RecordingComplaintsRepository(allOutOfScope());
    await pumpPendingReports(
      tester,
      complaints: complaints,
      routes: FakeRoutesRepository([devRoute()]),
    );
    await pumpUntil(tester, find.text(enNothingPending));
    expect(find.byKey(const ValueKey('d4-row-c-3')), findsNothing);
    expect(find.text(enPendingReportsTitle), findsOneWidget);
  });

  testWidgets('loading state holds while the first snapshot is pending',
      (tester) async {
    await pumpPendingReports(
      tester,
      complaints: NeverEmittingComplaintsRepository([inScopeReceived]),
      routes: FakeRoutesRepository([devRoute()]),
    );
    await pumpFrames(tester);
    expect(find.text(enLoading), findsOneWidget);
  });

  testWidgets('stream failure surfaces the localized error state; '
      'Retry reloads the list', (tester) async {
    final complaints = FlakyWatchComplaintsRepository(1, [inScopeReceived]);
    await pumpPendingReports(
      tester,
      complaints: complaints,
      routes: FakeRoutesRepository([devRoute()]),
    );
    await pumpUntil(tester, find.text(enError));
    expect(find.text(enRetry), findsOneWidget);
    await tester.tap(find.text(enRetry));
    await pumpUntil(tester, find.text('PMH-20261024-0001'));
  });

  testWidgets('unavailable-shaped failure surfaces the localized offline '
      'state, not the error state', (tester) async {
    await pumpPendingReports(
      tester,
      complaints: OfflineWatchComplaintsRepository([inScopeReceived]),
      routes: FakeRoutesRepository([devRoute()]),
    );
    await pumpUntil(tester, find.text(enOffline));
    expect(find.text(enError), findsNothing);
    expect(find.text(enRetry), findsOneWidget);
  });

  testWidgets(
      'Will Revisit writes exactly `status = assigned` of the tapped '
      'complaint only — one single write, other complaint untouched',
      (tester) async {
    final complaints = RecordingComplaintsRepository([
      inScopeReceived,
      inScopeAssigned,
    ]);
    await pumpPendingReports(
      tester,
      complaints: complaints,
      routes: FakeRoutesRepository([devRoute()]),
    );
    await pumpUntil(tester, find.text('PMH-20261024-0001'));
    await tester.tap(find.byKey(const ValueKey('d4-revisit-c-1')));
    await pumpFrames(tester);

    // The write: `c-1` → assigned, resolvedAt unset; field-accurate.
    final updated = complaints.complaints['c-1']!;
    expect(updated.status, ComplaintStatus.assigned);
    expect(updated.resolvedAt, isNull,
        reason: 'Will Revisit never sets a resolution time');
    expectFieldsUntouched(updated, inScopeReceived, {'status'});

    // The other (untouched) complaint stays identical, not even by write.
    expect(complaints.complaints['c-2'], inScopeAssigned,
        reason: 'writes only ever touch the tapped complaint');

    // Per-complaint write policy: exactly one single-doc update call.
    expect(complaints.statusCalls, ['c-1:assigned']);
    expect(complaints.resolvedAtCalls.length, 1);
    expect(complaints.resolvedAtCalls.single, isNull);
  });

  testWidgets(
      'Done writes exactly `status = resolved` + resolvedAt (contract '
      'shape; resolvedPhotoUrl stays unset), row leaves the list, other '
      'complaint untouched', (tester) async {
    final complaints = RecordingComplaintsRepository([
      inScopeReceived,
      inScopeAssigned,
    ]);
    final beforeTap = DateTime.now();
    await pumpPendingReports(
      tester,
      complaints: complaints,
      routes: FakeRoutesRepository([devRoute()]),
    );
    await pumpUntil(tester, find.text('PMH-20261024-0001'));
    await tester.tap(find.byKey(const ValueKey('d4-done-c-1')));
    await pumpFrames(tester);

    // Resolved row leaves the list (re-emission drops it).
    await pumpFrames(tester);
    expect(find.byKey(const ValueKey('d4-row-c-1')), findsNothing);

    // `c-1`: resolved + resolvedAt around the tap; resolvedPhotoUrl unset.
    final updated = complaints.complaints['c-1']!;
    final afterTap = DateTime.now();
    expect(updated.status, ComplaintStatus.resolved);
    expect(updated.resolvedAt != null, isTrue);
    expect(
      !updated.resolvedAt!.isBefore(beforeTap) &&
          !updated.resolvedAt!.isAfter(afterTap),
      isTrue,
      reason: 'resolvedAt stamped around the Done tap',
    );
    expect(updated.resolvedPhotoUrl, isNull,
        reason: 'no contract field requires the driver to add one');
    expectFieldsUntouched(updated, inScopeReceived, {'status', 'resolvedAt'});

    // The other complaint untouched; writes stay per-complaint (no batch).
    expect(complaints.complaints['c-2'], inScopeAssigned);
    expect(complaints.statusCalls, ['c-1:resolved']);
    expect(complaints.resolvedAtCalls.length, 1);
    expect(complaints.resolvedAtCalls.single, isNotNull);
  });

  testWidgets(
      'failed write surfaces the error state; the complaint stays '
      'untouched; a second Done (after retry) resolves it',
      (tester) async {
    final complaints = FlakyWriteComplaintsRepository(1, [
      inScopeReceived,
      inScopeAssigned,
    ]);
    await pumpPendingReports(
      tester,
      complaints: complaints,
      routes: FakeRoutesRepository([devRoute()]),
    );
    await pumpUntil(tester, find.text('PMH-20261024-0001'));
    await tester.tap(find.byKey(const ValueKey('d4-done-c-1')));
    await pumpFrames(tester);
    await pumpUntil(tester, find.text(enError));

    // Nothing landed: status still received, resolvedAt still null.
    final untouched = complaints.complaints['c-1']!;
    expect(untouched.status, ComplaintStatus.received);
    expect(untouched.resolvedAt, isNull);
    expect(untouched, inScopeReceived);

    // The list reloads through Retry (fresh watch), then Done succeeds.
    await tester.tap(find.text(enRetry));
    await pumpUntil(tester, find.text('PMH-20261024-0001'));
    await tester.tap(find.byKey(const ValueKey('d4-done-c-1')));
    await pumpFrames(tester);
    expect(complaints.complaints['c-1']!.status, ComplaintStatus.resolved);
  });

  testWidgets('each row shows exactly two ≥ 56 dp action buttons '
      '(Will Revisit, Done)', (tester) async {
    await pumpPendingReports(
      tester,
      complaints: RecordingComplaintsRepository([
        inScopeReceived,
        inScopeAssigned,
      ]),
      routes: FakeRoutesRepository([devRoute()]),
    );
    await pumpUntil(tester, find.text('PMH-20261024-0001'));

    // Exactly two buttons per row.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('d4-row-c-1')),
        matching: find.byType(FilledButton),
      ),
      findsExactly(2),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('d4-row-c-2')),
        matching: find.byType(FilledButton),
      ),
      findsExactly(2),
    );
    expect(find.text(enWillRevisit), findsNWidgets(2));
    expect(find.text(enDone), findsNWidgets(2));

    // Big-target rule (contract section 6): both buttons ≥ 56 dp tall.
    expect(
      tester.getSize(find.byKey(const ValueKey('d4-revisit-c-1'))).height,
      greaterThanOrEqualTo(56),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('d4-done-c-1'))).height,
      greaterThanOrEqualTo(56),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('d4-revisit-c-2'))).height,
      greaterThanOrEqualTo(56),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('d4-done-c-2'))).height,
      greaterThanOrEqualTo(56),
    );
  });
}
