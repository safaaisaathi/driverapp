/// On break screen widget tests (wireframe WF-25).
///
/// Covers: title, body, elapsed timer, Resume button, and that Resume ends
/// the break through BreakController (no van.status write — local only).
library;

import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/features/live_route/domain/break_flow.dart';
import 'package:driverapp/features/live_route/ui/on_break_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const String enOnBreakTitle = 'On break';
const String enOnBreakBody =
    'Your shift is paused locally — the office can still see your last location. Tap Resume shift when you\'re back.';
const String enOnBreakResume = 'Resume shift';

Future<void> pumpOnBreakScreen(WidgetTester tester,
    {required ProviderContainer container}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const OnBreakScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows title, body, timer, and resume button', (t) async {
    final container = ProviderContainer();
    await pumpOnBreakScreen(t, container: container);

    expect(find.text(enOnBreakTitle), findsOneWidget);
    expect(find.text(enOnBreakBody), findsOneWidget);
    expect(find.byKey(const Key('onBreak.timer')), findsOneWidget);
    expect(find.byKey(const Key('onBreak.resume')), findsOneWidget);
    container.dispose();
  });

  testWidgets('resume ends the break through BreakController', (t) async {
    final container = ProviderContainer();
    // Start a break first.
    container.read(breakControllerProvider.notifier).start();
    await pumpOnBreakScreen(t, container: container);

    expect(find.byKey(const Key('onBreak.timer')), findsOneWidget);

    await t.tap(find.byKey(const Key('onBreak.resume')));
    await t.pumpAndSettle();

    final state = container.read(breakControllerProvider);
    expect(state.phase, BreakPhase.notOnBreak);
    container.dispose();
  });
}
