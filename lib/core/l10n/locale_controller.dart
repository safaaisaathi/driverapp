/// F-D10 LocaleController (ticket 13): the driver's language choice as
/// Riverpod state.
///
/// `MaterialApp` watches [localeControllerProvider], so a flip on D1
/// re-localizes the whole app immediately (no restart); the choice
/// persists through [LocaleStore] and is restored on the next launch.
library;

import 'dart:async';

import 'package:flutter/material.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'locale_preferences.dart';

/// Storage seam for the language choice; overridden with an in-memory
/// fake in tests so nothing touches the SharedPreferences channel.
final localeStoreProvider = Provider<LocaleStore>(
  (ref) => const SharedPreferencesLocaleStore(),
);

/// The driver's chosen language. `null` = no stored choice (system
/// default — English during development per the grilled decision).
class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() {
    // Fire-and-forget restore: the app renders its fallback (en) while
    // storage answers — the same degrade-don't-crash idiom as bootstrap
    // (ticket 02).
    unawaited(_restore());
    return null;
  }

  Future<void> _restore() async {
    try {
      final restored =
          decodeStoredLocale(await ref.read(localeStoreProvider).read());
      // The controller may have been rebuilt meanwhile; a choice made
      // while restoring wins over the stored value.
      if (ref.mounted && state == null && restored != null) {
        state = restored;
      }
    } on Exception {
      // Storage unavailable (tests without an override, or a broken
      // disk): degrade to the system default, never crash.
    }
  }

  /// Driver tapped the D1 toggle: applies instantly (MaterialApp watches
  /// this state) and persists through [LocaleStore].
  Future<void> setLocale(Locale locale) async {
    state = locale;
    try {
      await ref.read(localeStoreProvider).write(encodeStoredLocale(locale));
    } on Exception {
      // Keep the in-session choice on a failed write; the next launch
      // simply falls back to the system default.
    }
  }
}

final localeControllerProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);
