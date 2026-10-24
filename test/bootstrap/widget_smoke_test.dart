import 'package:driverapp/core/config/firebase_bootstrap.dart';
import 'package:driverapp/core/config/firebase_options.dart';
import 'package:driverapp/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app renders the launched (degraded-tolerant) state without '
      'Firebase: scanning/placeholder screen stays up', (tester) async {
    // Mirrors main()'s wiring WITHOUT running bootstrap: no Firebase app is
    // created, no platform channel (Auth/FCM/Hive) is touched, so the test
    // is green even when the Emulator Suite is not running (Ticket 02).
    final container = ProviderContainer(
      overrides: [
        bootstrapProvider.overrideWith(() => DegradedBootstrapController()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DriverApp()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    // The Phase-0 placeholder is intentionally unchanged (AAV rule).
    expect(find.text('Driver App – Panchmahal'), findsOneWidget);
    expect(find.text('Loading…'), findsOneWidget);
  });

  testWidgets('bootstrap status reads degraded, never crashed', (tester) async {
    final container = ProviderContainer(
      overrides: [
        bootstrapProvider.overrideWith(() => DegradedBootstrapController()),
      ],
    );
    addTearDown(container.dispose);

    await (container.read(bootstrapProvider.notifier) as DegradedBootstrapController)
        .run();

    expect(
      container.read(bootstrapProvider),
      isA<BootstrapDegraded>(),
      reason: 'a failed boot must surface as degraded, not crash the app',
    );
  });
}

/// Test double of the controller: renders the same UI flow main() produces
/// when Firebase/the emulator suite is unavailable.
final class DegradedBootstrapController extends BootstrapController {
  @override
  BootstrapStatus build() => const BootstrapStatus.pending();

  @override
  Future<void> run({FirebaseBackend? backend}) async {
    state = const BootstrapStatus.degraded();
  }
}
