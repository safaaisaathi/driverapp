/// Inbound FCM (B-21): the payload model, the platform seam and the
/// background handler.
///
/// The payload shape is the contract's (`topics.json`): a `data` map with
/// `type` = `notice`, the `noticeId` the app navigates with, plus the target
/// fields. A message without a notice id is ignored instead of opening an
/// arbitrary screen.
///
/// The app never invents notice state. The OS renders the `notification`
/// payload; the inbox stays the source of truth through its Firestore stream.
/// The background handler therefore only ensures a Firebase app exists in the
/// background isolate so later handling can read the platform safely.
library;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One push the app can act on (`topics.json` data payload).
final class PushMessage {
  const PushMessage({
    required this.noticeId,
    this.type,
    this.targetType,
    this.targetId,
  });

  /// `data.noticeId`: the doc the tap opens.
  final String noticeId;

  /// `data.type`, expected to be `notice`.
  final String? type;

  /// `data.targetType` (van | ward | all).
  final String? targetType;

  /// `data.targetId` (absent for `all`).
  final String? targetId;

  /// Parses the contract payload. Returns null when this is not a notice
  /// push or the id is missing, so a malformed push never navigates.
  static PushMessage? fromData(Map<String, dynamic> data) {
    if (data['type'] != 'notice') return null;
    final noticeId = data['noticeId'];
    if (noticeId is! String || noticeId.isEmpty) return null;
    final targetType = data['targetType'];
    final targetId = data['targetId'];
    return PushMessage(
      noticeId: noticeId,
      type: 'notice',
      targetType: targetType is String ? targetType : null,
      targetId: targetId is String ? targetId : null,
    );
  }
}

/// The inbound-message seam. Tests replace it; production uses FCM.
abstract interface class PushGateway {
  /// The user tapped a notification while the app was running.
  Stream<PushMessage> get onOpened;

  /// The user launched the app by tapping a notification while it was
  /// terminated. FCM hands this message over exactly once.
  Future<PushMessage?> initialMessage();
}

/// Real FCM gateway.
final class FirebasePushGateway implements PushGateway {
  const FirebasePushGateway();

  @override
  Stream<PushMessage> get onOpened =>
      FirebaseMessaging.onMessageOpenedApp
          .map((message) => PushMessage.fromData(message.data))
          .where((message) => message != null)
          .cast<PushMessage>();

  @override
  Future<PushMessage?> initialMessage() async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    return message == null ? null : PushMessage.fromData(message.data);
  }
}

/// Used by tests and by a host without platform channels.
final class NoopPushGateway implements PushGateway {
  const NoopPushGateway();

  @override
  Stream<PushMessage> get onOpened => const Stream<PushMessage>.empty();

  @override
  Future<PushMessage?> initialMessage() async => null;
}

final Provider<PushGateway> pushGatewayProvider =
    Provider<PushGateway>((ref) => const FirebasePushGateway());

/// Registers the background isolate handler. Must run before `runApp`.
void registerPushBackgroundHandler() {
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
}

/// Background isolate (app terminated).
///
/// The OS already renders the `notification` payload, and the inbox reads
/// Firestore when the app opens. The contract has no push-receipt field, so
/// writing anything here would invent notice state. The handler stays a
/// documented no-op: the push is shown, the inbox remains the source of truth.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('push: background message ${message.messageId} (no write by design)');
}
