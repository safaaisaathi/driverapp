/// F-D10 language toggle on D1 (ticket 13) — widget tests at seam 1 /
/// MaterialApp locale wiring: the DriverApp tree runs against fakes, so
/// no test reaches a platform channel.
library;

import 'package:driverapp/core/config/firebase_bootstrap.dart';
import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/l10n/locale_controller.dart';
import 'package:driverapp/core/repositories/repositories.dart';
import 'package:driverapp/core/theme/app_theme.dart';
import 'package:driverapp/features/shift_start/data/verify_driver_pin.dart';
import 'package:driverapp/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/l10n/locale_fakes.dart';
import '../../repositories/fake_repositories.dart';
import 'shift_start_screen_test.dart' show pinVerifier;

const String enVansEmpty = 'No vans found';
const String guVansEmpty = 'કોઈ વેન મળી નથી';

/// The toggle shows the language it switches TO, written in that
/// language (native names, identical in every arb file by design).
const String guToggleName = 'ગુજરાતી';
const String enToggleName = 'English';

const Key toggleKey = ValueKey('d1-language-toggle');

class _NoopAuthGateway implements DriverAuthGateway {
  @override
  Future<String> signInWithCustomToken(String token) async => 'uid';
}

/// Pumps the real DriverApp wiring (main.dart's MaterialApp) against the
/// fake repository seam plus an in-memory locale store.
Future<void> pumpDriverApp(
  WidgetTester tester, {
  required InMemoryLocaleStore store,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      vansRepositoryProvider.overrideWithValue(FakeVansRepository()),
      tripsRepositoryProvider.overrideWithValue(FakeTripsRepository()),
      routesRepositoryProvider.overrideWithValue(FakeRoutesRepository()),
      pinVerifierProvider.overrideWithValue(pinVerifier()),
      driverAuthGatewayProvider.overrideWithValue(_NoopAuthGateway()),
      driverMessagingGatewayProvider
          .overrideWithValue(const NoopMessagingGateway()),
      localeStoreProvider.overrideWithValue(store),
    ],
    child: const DriverApp(),
  ));
}

/// Pumps in small steps until [finder] finds a widget, or fails.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  String? reason,
  int maxPumps = 60,
}) async {
  for (var i = 0; i < maxPumps && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 25));
  }
  expect(finder, findsOneWidget, reason: reason);
}

/// True when the string carries at least one Gujarati-block rune — the
/// label-shape gate for the device rendering check in ticket 14.
bool hasGujaratiGlyphs(String s) {
  for (final rune in s.runes) {
    if (rune >= 0x0A80 && rune <= 0x0AFF) return true;
  }
  return false;
}

void main() {
  testWidgets('fresh install: no stored choice launches in English '
      '(grilled dev-phase default holds)', (tester) async {
    await pumpDriverApp(tester, store: InMemoryLocaleStore());
    await pumpUntilFound(tester, find.text(enVansEmpty));
    // The toggle offers the other language, named in that language.
    expect(find.text(guToggleName), findsOneWidget);
    expect(find.text(enToggleName), findsNothing);
  });

  testWidgets('tapping the toggle flips every visible localized string to '
      'Gujarati immediately (no restart)', (tester) async {
    final store = InMemoryLocaleStore();
    await pumpDriverApp(tester, store: store);
    await pumpUntilFound(tester, find.text(enVansEmpty));

    await tester.tap(find.text(guToggleName));
    await pumpUntilFound(
      tester,
      find.text(guVansEmpty),
      reason: 'D1 strings must re-localize inside the running app',
    );

    expect(find.text(enVansEmpty), findsNothing);
    expect(
      find.text(enToggleName),
      findsOneWidget,
      reason: 'the toggle now points back at English (native name)',
    );
    expect(
      store.stored,
      'gu',
      reason: 'the choice persisted through the store seam',
    );
  });

  testWidgets('tapping again flips back to English', (tester) async {
    final store = InMemoryLocaleStore();
    await pumpDriverApp(tester, store: store);
    await pumpUntilFound(tester, find.text(enVansEmpty));

    await tester.tap(find.text(guToggleName));
    await pumpUntilFound(tester, find.text(guVansEmpty));
    await tester.tap(find.text(enToggleName));
    await pumpUntilFound(tester, find.text(enVansEmpty));

    expect(find.text(guVansEmpty), findsNothing);
    expect(store.stored, 'en');
  });

  testWidgets('chosen language persists across an app restart', (tester) async {
    final store = InMemoryLocaleStore();
    await pumpDriverApp(tester, store: store);
    await pumpUntilFound(tester, find.text(enVansEmpty));
    await tester.tap(find.text(guToggleName));
    await pumpUntilFound(tester, find.text(guVansEmpty));

    // Restart: throw the tree away, mount a fresh ProviderScope (fresh
    // container → fresh LocaleController → restore) over the SAME storage.
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpDriverApp(tester, store: store);
    await pumpUntilFound(
      tester,
      find.text(guVansEmpty),
      reason: 'the stored choice must restore on the next launch',
    );
    expect(find.text(enVansEmpty), findsNothing);
  });

  testWidgets('toggle renders on D1 with a ≥56 dp touch target', (tester) async {
    await pumpDriverApp(tester, store: InMemoryLocaleStore());
    await pumpUntilFound(tester, find.byKey(toggleKey));

    final size = tester.getSize(find.byKey(toggleKey));
    expect(size.height, greaterThanOrEqualTo(56));
    expect(size.width, greaterThanOrEqualTo(56));
  });

  testWidgets('toggle label is themed — AppTheme tokens, no hardcoded '
      'color (0.11.4)', (tester) async {
    await pumpDriverApp(tester, store: InMemoryLocaleStore());
    await pumpUntilFound(tester, find.byKey(toggleKey));

    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byKey(toggleKey),
        matching: find.byType(RichText),
      ),
    );
    expect(
      paragraph.text.style?.color,
      AppTheme.colorTextPrimary,
      reason: 'the outlined button resolves its foreground from AppTheme',
    );
  });

  testWidgets('a11y: the toggle exposes a localized change-language hint',
      (tester) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    await pumpDriverApp(tester, store: InMemoryLocaleStore());
    await pumpUntilFound(tester, find.bySemanticsLabel('Change language'));
  });

  test('gu labels keep the Gujarati script shape (rendering gate for the '
      'device check deferred to ticket 14)', () async {
    final gu = await AppLocalizations.delegate.load(const Locale('gu'));
    expect(gu.languageNameGu, guToggleName, reason: 'native name stays native');
    expect(gu.languageNameEn, enToggleName);
    for (final label in [
      gu.languageChangeHint,
      gu.languageNameGu,
      gu.vansEmpty,
      gu.pickVanPrompt,
    ]) {
      expect(hasGujaratiGlyphs(label), isTrue,
          reason: '"$label" must carry Gujarati script');
    }
  });
}
