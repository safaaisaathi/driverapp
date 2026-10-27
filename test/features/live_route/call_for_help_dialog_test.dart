/// Call for help dialog widget tests (wireframe WF-26).
///
/// Covers: title, body, Call office button, and that tapping Call office
/// dismisses the dialog (demo-degraded: no real dialer).
library;

import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/features/live_route/ui/call_for_help_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const String enCallForHelpTitle = 'Call for help';
const String enCallForHelpBody = 'Call the office for help on today\'s route.';
const String enCallForHelpCall = 'Call office';

Future<void> pumpCallForHelpDialog(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const _DialogHost(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('dialogHost.openDialog')));
  await tester.pumpAndSettle();
}

class _DialogHost extends StatelessWidget {
  const _DialogHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const Key('dialogHost.openDialog'),
          onPressed: () => showCallForHelpDialog(context),
          child: const Text('open'),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('dialog shows title, body, and call button', (t) async {
    await pumpCallForHelpDialog(t);

    expect(find.text(enCallForHelpTitle), findsOneWidget);
    expect(find.text(enCallForHelpBody), findsOneWidget);
    expect(find.byKey(const Key('callForHelp.callOffice')), findsOneWidget);
  });

  testWidgets('tapping Call office dismisses the dialog', (t) async {
    await pumpCallForHelpDialog(t);

    await t.tap(find.byKey(const Key('callForHelp.callOffice')));
    await t.pumpAndSettle();

    expect(find.text(enCallForHelpTitle), findsNothing);
  });
}
