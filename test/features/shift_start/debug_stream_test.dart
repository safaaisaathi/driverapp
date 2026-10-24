import 'package:driverapp/core/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../repositories/fake_repositories.dart';
import 'shift_start_screen_test.dart' show sampleVan;

/// Probe: does `fakeRepos.watchVan().first` complete when the subscription
/// is created (a) from the test body — (b) triggered by a widget tap under
/// the tester's guarded pump machinery?
void main() {
  testWidgets('watch first from test body', (tester) async {
    final repo = FakeVansRepository([sampleVan()]);
    final van = await repo.watchVan('van-1').first;
    // ignore: avoid_print
    print('BODY got van: ${van?.id}');
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('watch first triggered by tap', (tester) async {
    final repo = FakeVansRepository([sampleVan()]);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            // ignore: avoid_print
            print('TAP started await');
            final van = await repo.watchVan('van-1').first;
            // ignore: avoid_print
            print('TAP got van: ${van?.id}');
          },
          child: const Text('go'),
        ),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('go'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
  });
}
