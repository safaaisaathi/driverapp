/// Notice detail widget tests (wireframe WF-19).
///
/// Every render path is covered: message + time ago + target chip + Got it
/// dismiss. No Firebase touches; the notice is passed in directly.
library;

import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/features/notices/ui/notice_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const String enNoticeTitle = 'Route change tomorrow';
const String enAppliesToVan = 'Applies to this van';
const String enAppliesToWard = 'Applies to Ward ward-1';
const String enAppliesToAll = 'Applies to all vans';
const String enGotIt = 'Got it';

Notice seedNotice({
  required String id,
  required NoticeTargetType targetType,
  String? targetId,
  required String message,
  required DateTime createdAt,
}) =>
    Notice.fromMap(<String, Object?>{
      'id': id,
      'targetType': targetType.value,
      'targetId': targetId,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': 'inspector-1',
    });

Future<void> pumpNoticeDetail(WidgetTester tester, {required Notice notice}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: NoticeDetailScreen(notice: notice),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the message, time ago, and applies-to chip', (t) async {
    final notice = seedNotice(
      id: 'n-1',
      targetType: NoticeTargetType.van,
      message: enNoticeTitle,
      createdAt: DateTime(2026, 10, 24, 11, 50),
    );
    await pumpNoticeDetail(t, notice: notice);

    expect(find.text(enNoticeTitle), findsOneWidget);
    // Time ago is relative to now — assert some relative-time text is shown.
    expect(find.byKey(const Key('noticeDetail.timeAgo')), findsOneWidget);
    expect(find.text(enAppliesToVan), findsOneWidget);
    expect(find.byKey(const Key('noticeDetail.gotIt')), findsOneWidget);
  });

  testWidgets('target chip shows ward when targetType is ward', (t) async {
    final notice = seedNotice(
      id: 'n-2',
      targetType: NoticeTargetType.ward,
      targetId: 'ward-1',
      message: 'Ward notice',
      createdAt: DateTime(2026, 10, 24, 12, 0),
    );
    await pumpNoticeDetail(t, notice: notice);

    expect(find.text(enAppliesToWard), findsOneWidget);
    expect(find.text(enAppliesToVan), findsNothing);
  });

  testWidgets('target chip shows all-vans when targetType is all', (t) async {
    final notice = seedNotice(
      id: 'n-3',
      targetType: NoticeTargetType.all,
      message: 'All notice',
      createdAt: DateTime(2026, 10, 24, 12, 0),
    );
    await pumpNoticeDetail(t, notice: notice);

    expect(find.text(enAppliesToAll), findsOneWidget);
  });

  testWidgets('Got it pops the detail and returns to the inbox', (t) async {
    final notice = seedNotice(
      id: 'n-1',
      targetType: NoticeTargetType.van,
      message: enNoticeTitle,
      createdAt: DateTime(2026, 10, 24, 11, 50),
    );
    await pumpNoticeDetail(t, notice: notice);

    await t.tap(find.byKey(const Key('noticeDetail.gotIt')));
    await t.pumpAndSettle();

    // The detail is gone — back to whatever pushed it.
    expect(find.text(enNoticeTitle), findsNothing);
  });
}
