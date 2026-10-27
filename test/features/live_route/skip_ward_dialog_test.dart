/// Skip ward dialog widget tests (wireframe WF-24).
///
/// Covers: title, warning body, confirm / cancel buttons, and that confirm
/// records the skip through the session-only SkipWardController (never
/// touching trips.wardsDone).
library;

import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/features/live_route/domain/break_flow.dart';
import 'package:driverapp/features/live_route/ui/skip_ward_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const String enSkipWardTitle = 'Skip ward';
const String enSkipWardConfirm = 'Skip this ward';
const String enSkipWardCancel = 'Cancel';
const String enSkipWardWarning = "This ward will be dropped from today's route. It cannot be restored this shift.";

class _DialogHost extends StatelessWidget {
  final String wardId;
  const _DialogHost({required this.wardId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const Key('dialogHost.openDialog'),
          onPressed: () => showSkipWardDialog(context, wardId),
          child: const Text('open'),
        ),
      ),
    );
  }
}

Future<void> pumpSkipWardDialog(WidgetTester tester, {required String wardId}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: _DialogHost(wardId: wardId),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('dialogHost.openDialog')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('dialog shows title, warning, confirm and cancel', (t) async {
    await pumpSkipWardDialog(t, wardId: 'ward-1');

    expect(find.text(enSkipWardTitle), findsOneWidget);
    expect(find.text(enSkipWardWarning), findsOneWidget);
    expect(find.byKey(const Key('skipWard.confirm')), findsOneWidget);
    expect(find.byKey(const Key('skipWard.cancel')), findsOneWidget);
  });

  testWidgets('confirm records the skip in the session controller', (t) async {
    final container = ProviderContainer();
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: _DialogHost(wardId: 'ward-1'),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('dialogHost.openDialog')));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const Key('skipWard.confirm')));
    await t.pumpAndSettle();

    final controller = container.read(skipWardControllerProvider.notifier);
    expect(controller.isSkipped('ward-1'), isTrue);
    container.dispose();
  });

  testWidgets('cancel dismisses without recording a skip', (t) async {
    final container = ProviderContainer();
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: _DialogHost(wardId: 'ward-1'),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('dialogHost.openDialog')));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const Key('skipWard.cancel')));
    await t.pumpAndSettle();

    final controller = container.read(skipWardControllerProvider.notifier);
    expect(controller.isSkipped('ward-1'), isFalse);
    container.dispose();
  });
}
