import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/core/repositories/repositories.dart';
import 'package:driverapp/core/theme/app_theme.dart';
import 'package:driverapp/features/notices/domain/notices_flow.dart';
import 'package:driverapp/features/notices/ui/notices_screen.dart';
import 'package:driverapp/features/shift_start/domain/shift_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../repositories/fake_repositories.dart';

/// D3 Notices inbox widget tests — spec seam 1: every Firebase touch is a
/// fake behind the repository providers
/// (`test/repositories/fake_repositories.dart`).
///
/// Acceptance (ticket 09):
/// - the watch goes out with exactly the running shift's van + route wardIds,
/// - only the three matching target shapes surface (`all`, this van, this
///   route's wards); out-of-scope notices never appear, even when newest,
/// - newest first (contract sort; ruling 10 lives in the repository),
/// - unread markers per notice; opening (tapping) a notice marks it read and
///   the D2 badge count clears accordingly; a fresh notice arrives unread,
/// - the contract carries NO read field, so mark-read writes nothing —
///   every seed doc stays byte-identical after taps (no invented storage),
/// - loading / empty ("no notices") / error / offline states localized,
/// - rows are ≥ 56 dp tap targets (contract section 6).

const String enNoticesTitle = 'Notices';
const String enNoNotices = 'No notices';
const String enLoading = 'Loading…';
const String enError = 'Something went wrong';
const String enOffline = "You're offline";
const String enRetry = 'Retry';

/// One running shift's identity (D3 reads it for van + route context). The
/// started instant is pinned: 2026-10-24 06:30 UTC = 12:00 IST so the
/// harness is deterministic on any test-runner zone (the ticket-10 pattern).
final DateTime shiftStartedAt = DateTime.utc(2026, 10, 24, 6, 30);

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
      date: shiftStartedAt,
    );

// -- seed helpers -------------------------------------------------------------

/// A 0.2 `notices` doc map (shape mirrors 0.7 sendNotice fan-out fields).
Map<String, Object?> noticeDocMap({
  required String id,
  required String targetType,
  String? targetId,
  required String message,
  required Object? createdAt,
}) =>
    <String, Object?>{
      'id': id,
      'targetType': targetType,
      'targetId': targetId,
      'message': message,
      'createdAt': createdAt,
      'createdBy': 'inspector-1',
    };

Notice seedNotice({
  required String id,
  required NoticeTargetType targetType,
  String? targetId,
  required String message,
  required DateTime createdAt,
}) =>
    Notice.fromMap(noticeDocMap(
      id: id,
      targetType: targetType.value,
      targetId: targetId,
      message: message,
      createdAt: Timestamp.fromDate(createdAt),
    ));

final DateTime noonIST = DateTime(2026, 10, 24, 12, 0);

/// In-scope: the three target shapes.
final Notice vanNotice = seedNotice(
  id: 'n-1',
  targetType: NoticeTargetType.van,
  targetId: 'van-1',
  message: 'Van notice: new timing tomorrow',
  createdAt: noonIST,
);

final Notice allNotice = seedNotice(
  id: 'n-2',
  targetType: NoticeTargetType.all,
  message: 'All vans: training next week',
  createdAt: DateTime(2026, 10, 24, 11, 0),
);

final Notice ward1Notice = seedNotice(
  id: 'n-3',
  targetType: NoticeTargetType.ward,
  targetId: 'ward-1',
  message: 'Ward 1: road blocked near gate',
  createdAt: DateTime(2026, 10, 24, 10, 0),
);

final Notice ward2Notice = seedNotice(
  id: 'n-4',
  targetType: NoticeTargetType.ward,
  targetId: 'ward-2',
  message: 'Ward 2: visit after lunch',
  createdAt: DateTime(2026, 10, 24, 9, 30),
);

/// Out of scope — targeted at a different van and a ward off this route.
/// The van-9 one is NEWER than every in-scope notice: filtering must beat
/// sorting (a leak sorted to the top would be visible).
final Notice wrongVanNotice = seedNotice(
  id: 'n-5',
  targetType: NoticeTargetType.van,
  targetId: 'van-9',
  message: 'Other van must not see this',
  createdAt: DateTime(2026, 10, 24, 12, 30),
);

final Notice wrongWardNotice = seedNotice(
  id: 'n-6',
  targetType: NoticeTargetType.ward,
  targetId: 'ward-9',
  message: 'Other ward must not see this',
  createdAt: DateTime(2026, 10, 24, 12, 10),
);

List<Notice> allOutOfScope() => [wrongVanNotice, wrongWardNotice];

/// A notice pushed mid-test (0.7 sendNotice lands via the van topic; the
/// inbox sees it through the live stream).
final Notice pushedNotice = seedNotice(
  id: 'n-7',
  targetType: NoticeTargetType.van,
  targetId: 'van-1',
  message: 'Pushed during test',
  createdAt: DateTime(2026, 10, 24, 13, 0),
);

// -- scripted fakes (test-local, layered on the shared fakes) -----------------

/// Records the exact repository watch arguments so tests can assert the
/// query shape the controller asks for. Self-contained controller streams
/// (not layered on the shared fake's private broadcast) so [addNotice] can
/// push re-emissions to live listeners — the topic-push path's observable
/// behaviour without touching the shared fakes.
class RecordingNoticesRepository implements NoticesRepository {
  RecordingNoticesRepository([Iterable<Notice>? seed])
      : notices = {
          for (final notice in seed ?? const <Notice>[]) notice.id: notice,
        };

  final Map<String, Notice> notices;

  /// Last watch arguments, verbatim from the controller.
  ({String vanId, List<String> wardIds})? lastQuery;

  final _controllers =
      <({StreamController<List<Notice>> controller, String vanId,
          List<String> wardIds})>{};

  @override
  Stream<List<Notice>> watchNotices({
    required String vanId,
    required List<String> wardIds,
  }) {
    lastQuery = (vanId: vanId, wardIds: wardIds);
    late StreamController<List<Notice>> controller;
    controller = StreamController<List<Notice>>(
      // Microtask, not synchronous: controller events may never be added
      // from inside onListen (FakeAsync-safe flush semantics).
      onListen: () {
        scheduleMicrotask(
          () => controller.add(_filtered(vanId, wardIds)),
        );
      },
      onCancel: () => _controllers.remove(
        (
          controller: controller,
          vanId: vanId,
          wardIds: wardIds,
        ),
      ),
    );
    _controllers.add(
      (
        controller: controller,
        vanId: vanId,
        wardIds: wardIds,
      ),
    );
    return controller.stream;
  }

  /// Simulates a notice landing after the initial snapshot (0.7 sendNotice
  /// reaches the device via the van topic; the inbox observes it as a
  /// stream re-emission).
  void addNotice(Notice notice) {
    notices[notice.id] = notice;
    for (final live in _controllers) {
      scheduleMicrotask(
        () => live.controller.add(_filtered(live.vanId, live.wardIds)),
      );
    }
  }

  List<Notice> _filtered(String vanId, List<String> wardIds) {
    final result = notices.values
        .where(
          (notice) => switch (notice.targetType) {
            NoticeTargetType.all => true,
            NoticeTargetType.van => notice.targetId == vanId,
            NoticeTargetType.ward => wardIds.contains(notice.targetId),
          },
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }
}

/// Watch stream fails [failures] times before delegating to the shared fake.
class FlakyWatchNoticesRepository extends FakeNoticesRepository {
  FlakyWatchNoticesRepository(this.failures, [super.seed]);

  final int failures;
  int _watched = 0;

  @override
  Stream<List<Notice>> watchNotices({
    required String vanId,
    required List<String> wardIds,
  }) {
    if (_watched++ < failures) {
      return Stream<List<Notice>>.error(const _WatchFailed());
    }
    return super.watchNotices(vanId: vanId, wardIds: wardIds);
  }
}

final class _WatchFailed implements Exception {
  const _WatchFailed();
}

/// A transport-shaped failure: carries a `code` getter — the same shape
/// Firestore surfaces when the connection is unavailable (the duck-typed
/// `code` check lives in the flow, like ticket 10).
final class _UnavailableShaped implements Exception {
  final String code;

  const _UnavailableShaped(this.code);
}

class OfflineWatchNoticesRepository extends FakeNoticesRepository {
  OfflineWatchNoticesRepository([super.seed]);

  @override
  Stream<List<Notice>> watchNotices({
    required String vanId,
    required List<String> wardIds,
  }) =>
      Stream<List<Notice>>.error(const _UnavailableShaped('unavailable'));
}

/// Never emits a snapshot: the loading state must hold while the first
/// snapshot is pending.
class NeverEmittingNoticesRepository extends FakeNoticesRepository {
  NeverEmittingNoticesRepository([super.seed]);

  @override
  Stream<List<Notice>> watchNotices({
    required String vanId,
    required List<String> wardIds,
  }) =>
      const Stream<List<Notice>>.empty();
}

// -- harness ------------------------------------------------------------------

Future<ProviderContainer> pumpNotices(
  WidgetTester tester, {
  required NoticesRepository notices,
  bool activateShift = true,
  RoutesRepository? routes,
}) async {
  final container = ProviderContainer(overrides: [
    noticesRepositoryProvider.overrideWithValue(notices),
    routesRepositoryProvider
        .overrideWithValue(routes ?? FakeRoutesRepository([devRoute()])),
  ]);
  if (activateShift) {
    // D3 runs inside a started shift: activate the session up front so the
    // first build already has the van + route context (no D1 in the harness).
    container
        .read(shiftControllerProvider.notifier)
        .activate(runningShiftSession());
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const NoticesScreen(),
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

Key rowKey(String id) => ValueKey<String>('d3-row-$id');
Key tapKey(String id) => ValueKey<String>('d3-tap-$id');
Key unreadDotKey(String id) => ValueKey<String>('d3-unread-$id');

// -- tests --------------------------------------------------------------------

void main() {
  testWidgets(
      'watches with exactly the running shift context: vanId + the route '
      'wardIds in order', (tester) async {
    final notices = RecordingNoticesRepository([vanNotice]);
    await pumpNotices(tester, notices: notices);
    await pumpUntil(tester, find.text(vanNotice.message));

    final query = notices.lastQuery;
    expect(query, isNotNull);
    expect(query!.vanId, 'van-1');
    expect(query.wardIds, devWardIds);
  });

  testWidgets(
      'shows only the three matching target shapes — out-of-scope notices '
      'never leak, even when newer than every in-scope one', (tester) async {
    final notices = RecordingNoticesRepository([
      vanNotice,
      allNotice,
      ward1Notice,
      ward2Notice,
      ...allOutOfScope(),
    ]);
    await pumpNotices(tester, notices: notices);
    await pumpUntil(tester, find.text(vanNotice.message));

    expect(find.text(allNotice.message), findsOneWidget);
    expect(find.text(ward1Notice.message), findsOneWidget);
    expect(find.text(ward2Notice.message), findsOneWidget);

    expect(find.text(wrongVanNotice.message), findsNothing);
    expect(find.text(wrongWardNotice.message), findsNothing);
  });

  testWidgets('newest first: contract sort, newer in-scope notice on top',
      (tester) async {
    final notices = RecordingNoticesRepository([
      ward2Notice, // oldest, seeded first
      allNotice,
      ward1Notice,
      vanNotice, // newest, seeded last
    ]);
    final container = await pumpNotices(tester, notices: notices);
    await pumpUntil(tester, find.text(vanNotice.message));

    final flow = container.read(noticesFlowProvider);
    expect(
      flow.notices.map((notice) => notice.id).toList(),
      [vanNotice.id, allNotice.id, ward1Notice.id, ward2Notice.id],
      reason: 'contract sort: descending createdAt — the first row the '
          'driver reads is the freshest notice',
    );
  });

  testWidgets('every seeded notice starts unread with the badge count '
      'matching; opening one clears its dot and decrements the badge',
      (tester) async {
    final notices = RecordingNoticesRepository([
      vanNotice,
      allNotice,
      ward1Notice,
      ward2Notice,
    ]);
    final container = await pumpNotices(tester, notices: notices);
    await pumpUntil(tester, find.text(vanNotice.message));

    expect(container.read(unreadNoticesCountProvider), 4);
    expect(find.byKey(unreadDotKey(vanNotice.id)), findsOneWidget);
    expect(find.byKey(unreadDotKey(allNotice.id)), findsOneWidget);
    expect(find.byKey(unreadDotKey(ward1Notice.id)), findsOneWidget);
    expect(find.byKey(unreadDotKey(ward2Notice.id)), findsOneWidget);

    // Opening a notice (tap-through) marks exactly that one read.
    await tester.tap(find.byKey(tapKey(vanNotice.id)));
    await pumpFrames(tester);

    expect(container.read(unreadNoticesCountProvider), 3);
    expect(find.byKey(unreadDotKey(vanNotice.id)), findsNothing);
    expect(find.byKey(unreadDotKey(allNotice.id)), findsOneWidget);
  });

  testWidgets('mark-read writes NOTHING to the repository — the contract '
      'carries no read field and none may be invented', (tester) async {
    final notices = RecordingNoticesRepository([vanNotice]);
    await pumpNotices(tester, notices: notices);
    await pumpUntil(tester, find.text(vanNotice.message));

    final before = Map<String, Notice>.from(notices.notices);
    await tester.tap(find.byKey(tapKey(vanNotice.id)));
    await pumpFrames(tester);

    expect(
      notices.notices,
      before,
      reason: 'mark-read must not touch a single stored field — the '
          '`notices` shape belongs to the contract (0.2), not the app',
    );
  });

  testWidgets('a re-emission after a push keeps read notices read and '
      'marks the pushed one unread on top', (tester) async {
    final notices = RecordingNoticesRepository([vanNotice, allNotice]);
    final container = await pumpNotices(tester, notices: notices);
    await pumpUntil(tester, find.text(vanNotice.message));

    // Driver opens the van notice.
    await tester.tap(find.byKey(tapKey(vanNotice.id)));
    await pumpFrames(tester);
    expect(container.read(unreadNoticesCountProvider), 1);

    // Push arrives (van topic -> live stream re-emission).
    notices.addNotice(pushedNotice);
    await pumpUntil(tester, find.text(pushedNotice.message));

    expect(container.read(unreadNoticesCountProvider), 2);
    expect(find.byKey(unreadDotKey(pushedNotice.id)), findsOneWidget);
    expect(find.byKey(unreadDotKey(vanNotice.id)), findsNothing,
        reason: 'opening a notice must survive re-emissions');
  });

  testWidgets('empty state shows the localized no-notices line and the '
      'badge stays at zero', (tester) async {
    final notices = RecordingNoticesRepository(allOutOfScope());
    final container = await pumpNotices(tester, notices: notices);
    await pumpUntil(tester, find.text(enNoNotices));

    expect(container.read(unreadNoticesCountProvider), 0);
    expect(find.text(enNoticesTitle), findsOneWidget);
    expect(find.byKey(rowKey(vanNotice.id)), findsNothing);
  });

  testWidgets('loading state holds while the first snapshot is pending',
      (tester) async {
    await pumpNotices(
      tester,
      notices: NeverEmittingNoticesRepository([vanNotice]),
    );
    await pumpFrames(tester);
    expect(find.text(enLoading), findsOneWidget);
    expect(find.byKey(rowKey(vanNotice.id)), findsNothing);
  });

  testWidgets('stream failure surfaces the localized error state; Retry '
      'reloads the list', (tester) async {
    final notices = FlakyWatchNoticesRepository(1, [vanNotice]);
    await pumpNotices(tester, notices: notices);
    await pumpUntil(tester, find.text(enError));
    expect(find.text(enRetry), findsOneWidget);

    await tester.tap(find.text(enRetry));
    await pumpUntil(tester, find.text(vanNotice.message));
  });

  testWidgets('unavailable-shaped failure surfaces the localized offline '
      'state, not the error state', (tester) async {
    await pumpNotices(
      tester,
      notices: OfflineWatchNoticesRepository([vanNotice]),
    );
    await pumpUntil(tester, find.text(enOffline));
    expect(find.text(enError), findsNothing);
    expect(find.text(enRetry), findsOneWidget);
  });

  testWidgets('each row is a ≥ 56 dp tap target covering the full card',
      (tester) async {
    await pumpNotices(
      tester,
      notices: RecordingNoticesRepository([vanNotice, allNotice]),
    );
    await pumpUntil(tester, find.text(vanNotice.message));

    expect(
      tester.getSize(find.byKey(tapKey(vanNotice.id))).height,
      greaterThanOrEqualTo(56),
    );
    expect(
      tester.getSize(find.byKey(tapKey(allNotice.id))).height,
      greaterThanOrEqualTo(56),
    );
  });

  testWidgets('no shift context (dev/demo misuse) degrades to the error '
      'state, not a crash', (tester) async {
    await pumpNotices(
      tester,
      notices: RecordingNoticesRepository([vanNotice]),
      activateShift: false,
    );
    await pumpUntil(tester, find.text(enError));
    expect(find.text(enRetry), findsOneWidget);
  });
}
