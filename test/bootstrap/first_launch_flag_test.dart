import 'package:driverapp/core/config/firebase_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory stand-in for the Hive `_bootstrap` box (no real box: tests must
/// not touch platform channels or the file system).
final class FakeFlagBox implements FlagBox {
  final _store = <String, bool>{};
  var putCount = 0;

  @override
  bool? getBool(String key) => _store[key];

  @override
  Future<void> putBool(String key, bool value) async {
    putCount++;
    _store[key] = value;
  }
}

/// Records subscriptions; can be told to fail (e.g. emulator down).
final class RecordingMessagingGateway implements MessagingGateway {
  RecordingMessagingGateway({this.failSubscribeWith});

  final Object? failSubscribeWith;
  final subscribedTopics = <String>[];
  var initCalls = 0;

  @override
  Future<void> init() async => initCalls++;

  @override
  Future<void> subscribeToTopic(String topic) async {
    if (failSubscribeWith != null) throw failSubscribeWith!;
    subscribedTopics.add(topic);
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    subscribedTopics.remove(topic);
  }
}

void main() {
  group('ensureSubscribedToAllTopic (PRD-2 0.6.6)', () {
    test('subscribes to topic `all` exactly once on first launch', () async {
      final flags = FakeFlagBox();
      final messaging = RecordingMessagingGateway();

      final subscribedNow = await ensureSubscribedToAllTopic(
        flags: flags,
        messaging: messaging,
      );

      expect(subscribedNow, isTrue);
      expect(messaging.subscribedTopics, ['all']);
      expect(flags.getBool(subscribedAllFlagKey), isTrue);
    });

    test('is idempotent across restarts — no second subscription', () async {
      final flags = FakeFlagBox();
      final messaging = RecordingMessagingGateway();

      await ensureSubscribedToAllTopic(flags: flags, messaging: messaging);
      final secondBoot = await ensureSubscribedToAllTopic(
        flags: flags,
        messaging: messaging,
      );

      expect(secondBoot, isFalse);
      expect(messaging.subscribedTopics, hasLength(1),
          reason: 'a restarted app must not re-subscribe');
    });

    test('does not persist the flag when subscribing fails', () async {
      final flags = FakeFlagBox();
      final messaging =
          RecordingMessagingGateway(failSubscribeWith: StateError('no FCM'));

      await expectLater(
        ensureSubscribedToAllTopic(flags: flags, messaging: messaging),
        throwsStateError,
      );

      expect(flags.getBool(subscribedAllFlagKey), isNull,
          reason: 'a later launch must retry the subscription');
      // And the retry on the next launch succeeds.
      final messagingRetry = RecordingMessagingGateway();
      await ensureSubscribedToAllTopic(flags: flags, messaging: messagingRetry);
      expect(messagingRetry.subscribedTopics, ['all']);
    });
  });
}
