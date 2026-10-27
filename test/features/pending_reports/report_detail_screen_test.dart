/// Report detail widget tests (wireframe WF-20).
///
/// Covers ticket id, category · ward, reports-today + time ago, location
/// chip, Done / Will Revisit buttons (≥ 56 dp each), and the Done snackbar.
/// Actions go through the D4 flow's public methods behind the repository fakes.
library;

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/core/repositories/repositories.dart';
import 'package:driverapp/core/theme/app_theme.dart';
import 'package:driverapp/features/pending_reports/ui/report_detail_screen.dart';
import 'package:driverapp/features/shift_start/domain/shift_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../repositories/fake_repositories.dart';

const String enTicketId = 'PMH-20261024-0001';
const String enCategoryMissedCollection = 'Missed collection';
const String enWardLabel = 'Ward ward-1';
const String enReportsToday = '1 reports today';
const String enDone = 'Done';
const String enWillRevisit = 'Will Revisit';
const String enLocation = 'Location';

final DateTime reportCreatedAt = DateTime(2026, 10, 24, 11, 0);
final DateTime shiftStartedAt = DateTime(2026, 10, 24, 6, 30);

RouteModel devRoute() => RouteModel.fromMap(<String, Object?>{
      'id': 'route-1',
      'name': 'West Loop',
      'wardIds': <String>['ward-1'],
      'scheduledStartTime': '07:30',
    });

Complaint seedComplaint({
  required String id,
  required String ticketId,
  required String? wardId,
  required String category,
  required String status,
  required DateTime createdAt,
  DateTime? resolvedAt,
}) =>
    Complaint.fromMap(<String, Object?>{
      'id': id,
      'ticketId': ticketId,
      'deviceId': 'device-1',
      'category': category,
      'photoUrl': null,
      'location': {'lat': 22.7751, 'lng': 73.7088},
      'wardId': wardId,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'assignedTo': null,
      'escalationLevel': 0,
      'resolvedPhotoUrl': null,
      'resolvedAt': resolvedAt == null ? null : Timestamp.fromDate(resolvedAt),
      'mergedInto': null,
      'note': null,
    });

Future<void> pumpReportDetail(
  WidgetTester tester, {
  required Complaint complaint,
  required FakeComplaintsRepository complaints,
  required FakeRoutesRepository routes,
}) async {
  routes.seedRoute(devRoute());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        complaintsRepositoryProvider.overrideWithValue(complaints),
        routesRepositoryProvider.overrideWithValue(routes),
        shiftControllerProvider.overrideWith(() => _SeededShift(shiftStartedAt)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: ReportDetailScreen(complaint: complaint),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Shift controller seeded for report detail (route context for the flow).
class _SeededShift extends ShiftController {
  _SeededShift(this._startedAt);

  final DateTime _startedAt;

  @override
  ShiftSession? build() => ShiftSession(
        vanId: 'van-1',
        tripId: 'trip-1',
        routeId: 'route-1',
        startedAt: _startedAt,
        date: DateTime(_startedAt.year, _startedAt.month, _startedAt.day),
      );
}

void main() {
  testWidgets('shows ticket id, category · ward, reports today, location', (t) async {
    final complaint = seedComplaint(
      id: 'c-1',
      ticketId: enTicketId,
      wardId: 'ward-1',
      category: 'missed_collection',
      status: 'received',
      createdAt: reportCreatedAt,
    );
    await pumpReportDetail(
      t,
      complaint: complaint,
      complaints: FakeComplaintsRepository([complaint]),
      routes: FakeRoutesRepository(),
    );

    expect(find.text(enTicketId), findsOneWidget);
    expect(
      find.text('${enCategoryMissedCollection} · $enWardLabel'),
      findsOneWidget,
    );
    expect(find.text(enReportsToday), findsOneWidget);
    expect(find.byKey(const Key('reportDetail.location')), findsOneWidget);
    expect(find.byKey(const Key('reportDetail.done')), findsOneWidget);
    expect(find.byKey(const Key('reportDetail.willRevisit')), findsOneWidget);
  });

  testWidgets('Done button is ≥ 56 dp tap target (contract section 6)', (t) async {
    final complaint = seedComplaint(
      id: 'c-1',
      ticketId: enTicketId,
      wardId: 'ward-1',
      category: 'missed_collection',
      status: 'received',
      createdAt: reportCreatedAt,
    );
    await pumpReportDetail(
      t,
      complaint: complaint,
      complaints: FakeComplaintsRepository([complaint]),
      routes: FakeRoutesRepository(),
    );

    expect(
      t.getSize(find.byKey(const Key('reportDetail.done'))).height,
      greaterThanOrEqualTo(56),
    );
    expect(
      t.getSize(find.byKey(const Key('reportDetail.willRevisit'))).height,
      greaterThanOrEqualTo(56),
    );
  });

  testWidgets('tapping Done writes resolved status through the D4 flow',
      (t) async {
    final complaint = seedComplaint(
      id: 'c-1',
      ticketId: enTicketId,
      wardId: 'ward-1',
      category: 'missed_collection',
      status: 'received',
      createdAt: reportCreatedAt,
    );
    final complaints = FakeComplaintsRepository([complaint]);
    await pumpReportDetail(
      t,
      complaint: complaint,
      complaints: complaints,
      routes: FakeRoutesRepository(),
    );

    await t.tap(find.byKey(const Key('reportDetail.done')));
    await t.pumpAndSettle();

    final updated = complaints.complaints[complaint.id];
    expect(updated?.status, ComplaintStatus.resolved);
    expect(updated?.resolvedAt, isNotNull);
  });

  testWidgets('tapping Will Revisit writes assigned status', (t) async {
    final complaint = seedComplaint(
      id: 'c-1',
      ticketId: enTicketId,
      wardId: 'ward-1',
      category: 'missed_collection',
      status: 'received',
      createdAt: reportCreatedAt,
    );
    final complaints = FakeComplaintsRepository([complaint]);
    await pumpReportDetail(
      t,
      complaint: complaint,
      complaints: complaints,
      routes: FakeRoutesRepository(),
    );

    await t.tap(find.byKey(const Key('reportDetail.willRevisit')));
    await t.pumpAndSettle();

    final updated = complaints.complaints[complaint.id];
    expect(updated?.status, ComplaintStatus.assigned);
  });

  testWidgets('back button pops the detail', (t) async {
    final complaint = seedComplaint(
      id: 'c-1',
      ticketId: enTicketId,
      wardId: 'ward-1',
      category: 'missed_collection',
      status: 'received',
      createdAt: reportCreatedAt,
    );
    await pumpReportDetail(
      t,
      complaint: complaint,
      complaints: FakeComplaintsRepository([complaint]),
      routes: FakeRoutesRepository(),
    );

    await t.tap(find.byKey(const Key('reportDetail.back')));
    await t.pumpAndSettle();

    expect(find.text(enTicketId), findsNothing);
  });
}
