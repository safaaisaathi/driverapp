import 'package:driverapp/core/config/firebase_bootstrap.dart';
import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/repositories/repositories.dart';
import 'package:driverapp/features/shift_start/data/verify_driver_pin.dart';
import 'package:driverapp/features/shift_start/domain/shift_flow.dart';
import 'package:driverapp/features/shift_start/ui/shift_start_screen.dart';
import 'package:driverapp/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shift_start_screen_test.dart' show pinVerifier, sampleRoute, sampleVan;
import '../../repositories/fake_repositories.dart';

void main() {
  testWidgets('DEBUG widget flow instrumented', (tester) async {
    final vansRepo = FakeVansRepository([sampleVan()]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        vansRepositoryProvider.overrideWithValue(vansRepo),
        tripsRepositoryProvider.overrideWithValue(FakeTripsRepository()),
        routesRepositoryProvider
            .overrideWithValue(FakeRoutesRepository([sampleRoute()])),
        pinVerifierProvider.overrideWithValue(pinVerifier()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const ShiftStartScreen(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('GJ-05-AB-1234'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.enterText(find.byKey(const ValueKey('d1-pin-field')), '1234');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const ValueKey('d1-verify-button')));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      final state = ProviderScope.containerOf(
              tester.element(find.byType(ShiftStartScreen)))
          .read(shiftStartFlowProvider);
      // ignore: avoid_print
      print('pump$i :: phase=${state.phase} failure=${state.failure}');
    }
  });
}
