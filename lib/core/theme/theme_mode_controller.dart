/// Driver theme choice (wireframes WF-14/21): Light / Dark / System.
///
/// `MaterialApp` watches this controller (like [LocaleController] for
/// language) and the choice persists through a SharedPreferences seam
/// mirroring the F-D10 store pattern — the key is app-owned, NOT a
/// contract constant. Dark is a full second theme built from the same
/// tokens (DESIGN.md D-07), so no widget ever branches on brightness.
library;

import 'dart:async';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-owned SharedPreferences key for the theme choice. Stored values
/// are `'light'` / `'dark'` / `'system'`; a missing value means
/// "no choice made" (System).
const String themeModePrefKey = 'driverapp.themeMode';

/// Storage seam for the theme choice; tests inject an in-memory fake so
/// nothing touches the SharedPreferences channel.
abstract interface class ThemeStore {
  /// The stored choice code, or null when no valid choice was made yet.
  Future<String?> read();

  /// Persists the choice (null clears it).
  Future<void> write(String? value);
}

/// SharedPreferences-backed store (the real code path).
final class SharedPreferencesThemeStore implements ThemeStore {
  const SharedPreferencesThemeStore();

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(themeModePrefKey);

  @override
  Future<void> write(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(themeModePrefKey);
    } else {
      await prefs.setString(themeModePrefKey, value);
    }
  }
}

/// Stored code → [ThemeMode]: only the three shipped values count;
/// corrupt/foreign values read as System.
ThemeMode decodeStoredThemeMode(String? code) => switch (code) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.system,
    };

/// [ThemeMode] → stored code.
String? encodeStoredThemeMode(ThemeMode mode) => switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };

/// The driver's chosen theme. `build()` starts at System and restores
/// the stored choice in the background — the same degrade-don't-crash
/// idiom as the locale restore: a failed storage read or write keeps
/// the in-session choice and never crashes the app.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    unawaited(_restore());
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    try {
      final stored = await ref.read(themeStoreProvider).read();
      if (ref.mounted && stored != null) {
        state = decodeStoredThemeMode(stored);
      }
    } on Exception {
      // Storage unavailable: degrade to System, never crash.
    }
  }

  /// Driver picked a Light/Dark/System segment: applies instantly
  /// (MaterialApp watches this state) and persists.
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      await ref.read(themeStoreProvider).write(encodeStoredThemeMode(mode));
    } on Exception {
      // Keep the in-session choice; the next launch falls back to System.
    }
  }
}

final themeStoreProvider = Provider<ThemeStore>(
  (ref) => const SharedPreferencesThemeStore(),
);

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
