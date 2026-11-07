/// F-D9 / CHG-0017: the in-memory latch behind the warning banner.
///
/// The durable latch is `trips.mockLocationDetected`, written by the
/// `flagMockLocation` callable. The banner must not wait for the network, so
/// it also reads this local latch: set the moment the OS reports a mocked fix,
/// cleared when a tracking run starts or ends.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

final mockLocationLatchProvider =
    NotifierProvider<MockLocationLatch, bool>(MockLocationLatch.new);

class MockLocationLatch extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    if (state == value) return;
    state = value;
  }
}
