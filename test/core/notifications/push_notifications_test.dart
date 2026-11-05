/// B-21: inbound FCM payload parsing and tap routing.
///
/// The tap is the only inbound behaviour the app can own without inventing
/// notice state: the OS shows the notification, the inbox stays the source of
/// truth, and a tap opens that notice.
library;

import 'dart:async';

import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/core/navigation/app_navigator.dart';
import 'package:driverapp/core/notifications/push_notifications.dart';
import 'package:driverapp/core/notifications/push_tap_router.dart';
import 'package:driverapp/core/repositories/repository_providers.dart';
import 'package:driverapp/features/notices/ui/notice_detail_screen.dart';
import 'package:driverapp/features/notices/ui/notices_screen.dart';
import 'package:driverapp/features/shift_start/domain/shift_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../repositories/fake_repositories.dart';

void main() {
  Notice sampleNotice() => Notice(
        id: 'notice-1',
        targetType: NoticeTargetType.van,
        targetId: 'van-01',
        message: 'Maintenance: your van is due for the evening check-up.',
        createdAt: DateTime.utc(2026, 11, 5, 2),
        createdBy: 'staff-9',
      );

  RouteModel sampleRoute() => const RouteModel(
        id: 'route-01',
        name: 'West Loop',
        wardIds: ['ward-1'],
        scheduledStartTime: '07:30',
      );

  ShiftSession sampleSession() => ShiftSession(
        vanId: 'van-01',
        tripId: 'trip-1',
        routeId: 'route-01',
        startedAt: DateTime.utc(2026, 11, 5, 8),
        date: DateTime.utc(2026, 11, 5),
      );

  Widget host(ProviderContainer container) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: appNavigatorKey,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(body: Text('home')),
        ),
      );

  ProviderContainer containerWith(_FakePushGateway gateway) {
    final container = ProviderContainer(
      overrides: [
        pushGatewayProvider.overrideWithValue(gateway),
        noticesRepositoryProvider
            .overrideWithValue(FakeNoticesRepository([sampleNotice()])),
        routesRepositoryProvider
            .overrideWithValue(FakeRoutesRepository([sampleRoute()])),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a contract notice payload parses', () {
    final message = PushMessage.fromData(const <String, dynamic>{
      'type': 'notice',
      'noticeId': 'notice-1',
      'targetType': 'van',
      'targetId': 'van-01',
    });

    expect(message, isNotNull);
    expect(message!.noticeId, 'notice-1');
    expect(message.targetType, 'van');
    expect(message.targetId, 'van-01');
  });

  test('a push without a notice id is ignored', () {
    expect(
      PushMessage.fromData(const <String, dynamic>{'type': 'notice'}),
      isNull,
    );
    expect(
      PushMessage.fromData(const <String, dynamic>{
        'type': 'notice',
        'noticeId': '',
      }),
      isNull,
    );
    expect(
      PushMessage.fromData(const <String, dynamic>{
        'type': 'other',
        'noticeId': 'notice-1',
      }),
      isNull,
    );
  });

  testWidgets('a notice tap opens the inbox at the pushed notice',
      (tester) async {
    final gateway = _FakePushGateway();
    addTearDown(gateway.dispose);
    final container = containerWith(gateway)
      ..read(shiftControllerProvider.notifier).activate(sampleSession())
      ..read(pushTapRouterProvider).start();

    await tester.pumpWidget(host(container));

    gateway.taps.add(const PushMessage(noticeId: 'notice-1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    // The pushed inbox kicks its own Firestore load; the flow reaches ready
    // and then the post-frame auto-open pushes the detail. Bounded pumps (no
    // pumpAndSettle) keep this deterministic.
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(NoticesScreen), findsOneWidget);
    expect(find.byType(NoticeDetailScreen), findsOneWidget);
  });

  testWidgets('a tap on a cold launch waits for the shift session',
      (tester) async {
    final gateway = _FakePushGateway();
    addTearDown(gateway.dispose);
    final container = containerWith(gateway)
      ..read(pushTapRouterProvider).start();

    await tester.pumpWidget(host(container));

    gateway.taps.add(const PushMessage(noticeId: 'notice-1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.byType(NoticesScreen),
      findsNothing,
      reason: 'no shift context yet; the tap is held, not dropped',
    );

    container.read(shiftControllerProvider.notifier).activate(sampleSession());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(NoticesScreen), findsOneWidget);
  });

  testWidgets('a terminated-launch tap uses the initial message',
      (tester) async {
    final gateway = _FakePushGateway()
      ..initial = const PushMessage(noticeId: 'notice-1');
    addTearDown(gateway.dispose);
    final container = containerWith(gateway)
      ..read(shiftControllerProvider.notifier).activate(sampleSession());

    await tester.pumpWidget(host(container));
    container.read(pushTapRouterProvider).start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(NoticesScreen), findsOneWidget);
  });
}

final class _FakePushGateway implements PushGateway {
  final StreamController<PushMessage> taps =
      StreamController<PushMessage>.broadcast();
  PushMessage? initial;

  @override
  Stream<PushMessage> get onOpened => taps.stream;

  @override
  Future<PushMessage?> initialMessage() async => initial;

  void dispose() => taps.close();
}
