/// More options sheet widget tests (wireframe WF-23).
///
/// Covers: sheet header, skip ward / on break / call for help / settings
/// options, close button, and that tapping an option closes the sheet.
library;

import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/features/live_route/ui/more_options_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const String enMoreOptionsTitle = 'More options';
const String enSkipWard = 'Skip ward';
const String enOnBreak = 'On break';
const String enCallForHelp = 'Call for help';
const String enSettings = 'Settings';

class _SheetHost extends StatelessWidget {
  const _SheetHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const Key('sheetHost.openSheet'),
          onPressed: () => showMoreOptionsSheet(context, wardId: 'ward-1'),
          child: const Text('open'),
        ),
      ),
    );
  }
}

Future<void> pumpAndOpenSheet(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const _SheetHost(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('sheetHost.openSheet')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sheet shows header and all four options', (t) async {
    await pumpAndOpenSheet(t);

    expect(find.text(enMoreOptionsTitle), findsOneWidget);
    expect(find.text(enSkipWard), findsOneWidget);
    expect(find.text(enOnBreak), findsOneWidget);
    expect(find.text(enCallForHelp), findsOneWidget);
    expect(find.text(enSettings), findsOneWidget);
  });

  testWidgets('close button dismisses the sheet', (t) async {
    await pumpAndOpenSheet(t);

    await t.tap(find.byKey(const Key('moreOptions.close')));
    await t.pumpAndSettle();

    expect(find.text(enMoreOptionsTitle), findsNothing);
  });

  testWidgets('tapping skip ward opens the skip dialog', (t) async {
    await pumpAndOpenSheet(t);

    await t.tap(find.text(enSkipWard).last);
    await t.pumpAndSettle();

    // Sheet closed, dialog opened.
    expect(find.byKey(const Key('skipWard.dialog')), findsOneWidget);
    expect(find.byKey(const Key('skipWard.confirm')), findsOneWidget);
    expect(find.byKey(const Key('skipWard.cancel')), findsOneWidget);
  });

  testWidgets('tapping on break opens the on break screen', (t) async {
    await pumpAndOpenSheet(t);

    await t.tap(find.text(enOnBreak).last);
    await t.pumpAndSettle();

    expect(find.byKey(const Key('onBreak.title')), findsOneWidget);
  });

  testWidgets('tapping call for help opens the call dialog', (t) async {
    await pumpAndOpenSheet(t);

    await t.tap(find.text(enCallForHelp).last);
    await t.pumpAndSettle();

    expect(find.byKey(const Key('callForHelp.dialog')), findsOneWidget);
    expect(find.byKey(const Key('callForHelp.callOffice')), findsOneWidget);
  });

  testWidgets('tapping settings opens the settings screen', (t) async {
    await pumpAndOpenSheet(t);

    await t.tap(find.text(enSettings).last);
    await t.pumpAndSettle();

    expect(find.text(enSettings), findsOneWidget);
  });
}
