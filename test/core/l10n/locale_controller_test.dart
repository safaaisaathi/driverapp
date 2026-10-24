/// F-D10 LocaleController behaviour (ticket 13) — pure Dart tests over the
/// [LocaleStore] seam: no widgets, no Firebase, no platform channels.
library;

import 'package:driverapp/core/l10n/locale_controller.dart';
import 'package:driverapp/core/l10n/locale_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'locale_fakes.dart';

const Locale en = Locale('en');
const Locale gu = Locale('gu');

/// Lets the controller's fire-and-forget restore land deterministically.
Future<void> flushRestore() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('locale codec (stored code ↔ Locale)', () {
    test('the two shipped codes decode to their locale; anything else is '
        '"no choice"', () {
      expect(decodeStoredLocale('en'), const Locale('en'));
      expect(decodeStoredLocale('gu'), const Locale('gu'));
      expect(
        decodeStoredLocale('hi'),
        isNull,
        reason: 'an unshipped language must not masquerade as a choice',
      );
      expect(decodeStoredLocale('garbage'), isNull);
      expect(decodeStoredLocale(''), isNull);
      expect(decodeStoredLocale(null), isNull);
    });

    test('shipped locales encode to their stored code; others persist none',
        () {
      expect(encodeStoredLocale(en), 'en');
      expect(encodeStoredLocale(gu), 'gu');
      expect(encodeStoredLocale(const Locale('hi')), isNull);
      expect(encodeStoredLocale(null), isNull);
    });
  });

  group('LocaleController on the in-memory store seam', () {
    late InMemoryLocaleStore store;
    late ProviderContainer container;

    setUp(() {
      store = InMemoryLocaleStore();
      container = ProviderContainer(
        overrides: [localeStoreProvider.overrideWithValue(store)],
      );
    });
    tearDown(() {
      container.dispose();
    });

    test('fresh install: no stored pref → no stored choice (null state; '
        'the dev-phase fallback keeps the app on en)', () async {
      // First read = the app mounting its watch (DriverApp); kicks restore.
      container.read(localeControllerProvider);
      await flushRestore();
      expect(container.read(localeControllerProvider), isNull);
    });

    test('restore: a stored choice re-applies on first read (no tap needed)',
        () async {
      store.values[localePrefKey] = 'gu';
      container.read(localeControllerProvider);
      await flushRestore();
      expect(container.read(localeControllerProvider), const Locale('gu'));
    });

    test('corrupt stored value → degrades to no choice (en fallback)',
        () async {
      store.values[localePrefKey] = 'hi';
      container.read(localeControllerProvider);
      await flushRestore();
      expect(container.read(localeControllerProvider), isNull);
    });

    test('setLocale applies immediately and persists through the store seam',
        () async {
      final notifier = container.read(localeControllerProvider.notifier);

      await notifier.setLocale(gu);
      expect(container.read(localeControllerProvider), gu);
      expect(store.stored, 'gu');

      await notifier.setLocale(en);
      expect(store.stored, 'en');
    });

    test('persistence round-trip: set → restart (fresh container over the '
        'same storage) → restored', () async {
      await container
          .read(localeControllerProvider.notifier)
          .setLocale(const Locale('gu'));

      // "Restart": main() wiring is not involved — DriverApp builds a
      // fresh controller on a fresh container, which restores from the
      // same backing storage.
      final restarted = ProviderContainer(
        overrides: [localeStoreProvider.overrideWithValue(store)],
      );
      addTearDown(restarted.dispose);
      // First read = the fresh app mounting its watch; then let restore land.
      restarted.read(localeControllerProvider);
      await flushRestore();

      expect(restarted.read(localeControllerProvider), const Locale('gu'));
    });

    test('a choice made while the restore is still in flight wins',
        () async {
      final slow = DelayedLocaleStore(
        InMemoryLocaleStore(),
        const Duration(milliseconds: 200),
      );
      final racing = ProviderContainer(
        overrides: [localeStoreProvider.overrideWithValue(slow)],
      );
      addTearDown(racing.dispose);

      // First read kicks the (slow) restore; the driver taps meanwhile.
      await racing
          .read(localeControllerProvider.notifier)
          .setLocale(const Locale('gu'));
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(
        racing.read(localeControllerProvider),
        const Locale('gu'),
        reason: 'the late restore must not clobber the explicit choice',
      );
    });
  });
}
