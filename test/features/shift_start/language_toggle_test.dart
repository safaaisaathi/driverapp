/// F-D10 language toggle (ticket 13) on the start-shift page — widget tests
/// at seam 1 / MaterialApp locale wiring: the DriverApp tree runs against
/// fakes, so no test reaches a platform channel.
library;

import 'package:driverapp/core/config/firebase_bootstrap.dart';
import 'package:driverapp/core/identity/driver_identity_controller.dart';
import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/l10n/locale_controller.dart';
import 'package:driverapp/core/repositories/repositories.dart';
import 'package:driverapp/core/theme/app_theme.dart';
import 'package:driverapp/features/shift_start/data/fcm_topics.dart'
    show driverMessagingGatewayProvider;
import 'package:driverapp/features/tracking/tracking_providers.dart'
    show trackingPermissionGatewayProvider;
import 'package:driverapp/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/identity/driver_identity_fakes.dart';
import '../../core/l10n/locale_fakes.dart';
import '../../features/launching/permission_gateway_fakes.dart';
import '../../repositories/fake_repositories.dart';

const String enTitle = 'Start shift';
const String guTitle = 'શિફ્ટ શરૂ કરો';

/// The toggle shows the language it switches TO, written in that
/// language (native names, identical in every arb file by design).
const String guToggleName = 'ગુજરાતી';
const String enToggleName = 'English';

const Key toggleKey = ValueKey('d1-language-toggle');

/// Pumps the real DriverApp wiring (main.dart's MaterialApp) against the
/// fake seams plus an in-memory locale store, then walks the launching
/// flow (splash → welcome → one-time setup) onto the start-shift page.
Future<void> pumpDriverApp(
  WidgetTester tester, {
  required InMemoryLocaleStore store,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      vansRepositoryProvider.overrideWithValue(FakeVansRepository()),
      tripsRepositoryProvider.overrideWithValue(FakeTripsRepository()),
      routesRepositoryProvider.overrideWithValue(FakeRoutesRepository()),
      driversRepositoryProvider.overrideWithValue(FakeDriversRepository()),
      driverIdentityStoreProvider.overrideWithValue(
        InMemoryDriverIdentityStore(),
      ),
      driverMessagingGatewayProvider
          .overrideWithValue(const NoopMessagingGateway()),
      // The setup flow auto-grants every stage, so the begin CTA completes
      // without a rationale screen in the walk.
      trackingPermissionGatewayProvider
          .overrideWithValue(const GrantAllPermissionGateway()),
      localeStoreProvider.overrideWithValue(store),
    ],
    child: const DriverApp(),
  ));
  // Splash holds 1.6 s (local timer), then Welcome replaces it; the begin
  // CTA runs the setup (grant-all fake) and lands on the start-shift page.
  await tester.pump(const Duration(milliseconds: 1700));
  await tester.pump(const Duration(milliseconds: 400)); // welcome push settles
  await tester.tap(find.byKey(const ValueKey('welcome-begin-button')));
  // The setup hand-over + fade-forwards exit need continuous small-step
  // pumping to retire the replaced route; one long pump leaves it
  // mid-bookkeeping.
  await tester.pumpAndSettle();
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
    await pumpUntilFound(tester, find.text(enTitle));
    // The toggle offers the other language, named in that language.
    expect(find.text(guToggleName), findsOneWidget);
    expect(find.text(enToggleName), findsNothing);
  });

  testWidgets('tapping the toggle flips every visible localized string to '
      'Gujarati immediately (no restart)', (tester) async {
    final store = InMemoryLocaleStore();
    await pumpDriverApp(tester, store: store);
    await pumpUntilFound(tester, find.text(enTitle));

    await tester.tap(find.text(guToggleName));
    await pumpUntilFound(
      tester,
      find.text(guTitle),
      reason: 'start-shift strings must re-localize inside the running app',
    );

    expect(find.text(enTitle), findsNothing);
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
    await pumpUntilFound(tester, find.text(enTitle));

    await tester.tap(find.text(guToggleName));
    await pumpUntilFound(tester, find.text(guTitle));
    await tester.tap(find.text(enToggleName));
    await pumpUntilFound(tester, find.text(enTitle));

    expect(find.text(guTitle), findsNothing);
    expect(store.stored, 'en');
  });

  testWidgets('chosen language persists across an app restart', (tester) async {
    final store = InMemoryLocaleStore();
    await pumpDriverApp(tester, store: store);
    await pumpUntilFound(tester, find.text(enTitle));
    await tester.tap(find.text(guToggleName));
    await pumpUntilFound(tester, find.text(guTitle));

    // Restart: throw the tree away, mount a fresh ProviderScope (fresh
    // container → fresh LocaleController → restore) over the SAME storage.
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpDriverApp(tester, store: store);
    await pumpUntilFound(
      tester,
      find.text(guTitle),
      reason: 'the stored choice must restore on the next launch',
    );
    expect(find.text(enTitle), findsNothing);
  });

  testWidgets('toggle renders on the start-shift page with a ≥56 dp touch '
      'target', (tester) async {
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

  testWidgets(
      'a11y: the toggle exposes a localized change-language hint',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpDriverApp(tester, store: InMemoryLocaleStore());
    await pumpUntilFound(tester, find.bySemanticsLabel('Change language'));
    // End-of-test verification requires every handle gone; dispose here
    // (before the framework's checks) not in addTearDown.
    semantics.dispose();
  });

  test('gu labels keep the Gujarati script shape (rendering gate for the '
      'device check deferred to ticket 14)', () async {
    final gu = await AppLocalizations.delegate.load(const Locale('gu'));
    expect(gu.languageNameGu, guToggleName, reason: 'native name stays native');
    expect(gu.languageNameEn, enToggleName);
    for (final label in [
      gu.languageChangeHint,
      gu.languageNameGu,
      gu.identityStartTitle,
      gu.identityCodeContinue,
    ]) {
      expect(hasGujaratiGlyphs(label), isTrue,
          reason: '"$label" must carry Gujarati script');
    }
  });
}
