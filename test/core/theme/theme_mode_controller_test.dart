/// Driver theme choice behaviour (wireframes WF-14/21) — pure Dart tests
/// over the [ThemeStore] seam: no widgets, no platform channels.
library;

import 'theme_fakes.dart';
import 'package:driverapp/core/theme/theme_mode_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lets the controller's fire-and-forget restore land deterministically.
Future<void> flushRestore() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('theme codec (stored code ↔ ThemeMode)', () {
    test('the three shipped codes decode; anything else is System', () {
      expect(decodeStoredThemeMode('light'), ThemeMode.light);
      expect(decodeStoredThemeMode('dark'), ThemeMode.dark);
      expect(decodeStoredThemeMode('system'), ThemeMode.system);
      expect(decodeStoredThemeMode('sepia'), ThemeMode.system);
      expect(decodeStoredThemeMode(''), ThemeMode.system);
      expect(decodeStoredThemeMode(null), ThemeMode.system);
    });

    test('every ThemeMode encodes to its stored code', () {
      expect(encodeStoredThemeMode(ThemeMode.light), 'light');
      expect(encodeStoredThemeMode(ThemeMode.dark), 'dark');
      expect(encodeStoredThemeMode(ThemeMode.system), 'system');
    });
  });

  group('ThemeModeController on the in-memory store seam', () {
    late InMemoryThemeStore store;
    late ProviderContainer container;

    setUp(() {
      store = InMemoryThemeStore();
      container = ProviderContainer(
        overrides: [themeStoreProvider.overrideWithValue(store)],
      );
    });
    tearDown(() {
      container.dispose();
    });

    test('starts at System with no stored choice', () async {
      expect(
        container.read(themeModeControllerProvider),
        ThemeMode.system,
      );
      await flushRestore();
      expect(
        container.read(themeModeControllerProvider),
        ThemeMode.system,
        reason: 'a restore of nothing must not tamper with the default',
      );
    });

    test('restore picks up a stored choice from a previous launch',
        () async {
      store.values[themeModePrefKey] = 'dark';
      // The read starts the controller (and its fire-and-forget
      // restore); the flush then lets it land.
      container.read(themeModeControllerProvider);
      await flushRestore();
      expect(container.read(themeModeControllerProvider), ThemeMode.dark);
    });

    test('a corrupt stored code degrades to System, never crashes', () async {
      store.values[themeModePrefKey] = 'high-contrast';
      container.read(themeModeControllerProvider);
      await flushRestore();
      expect(container.read(themeModeControllerProvider), ThemeMode.system);
    });

    test('setThemeMode applies instantly and persists the code', () async {
      await container
          .read(themeModeControllerProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      expect(container.read(themeModeControllerProvider), ThemeMode.dark);
      expect(store.stored, 'dark');

      await container
          .read(themeModeControllerProvider.notifier)
          .setThemeMode(ThemeMode.light);
      expect(store.stored, 'light');
    });
  });
}
