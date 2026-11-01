/// Issue #14: Gujarati is the app's SHIPPING default. A driver with no
/// stored choice lands in `gu` on the first frame; a stored choice (either
/// direction) always wins over the default.
///
/// The const is pinned here; the end-to-end wiring (fresh-install frame in
/// gu, stored-`en` restore, live toggle) is covered by
/// `test/features/shift_start/language_toggle_test.dart` and
/// `test/features/tracking/permission_prompt_screen_test.dart`.
library;

import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/l10n/locale_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaultAppLocale is Gujarati (a shipping decision, issue #14)', () {
    expect(defaultAppLocale, const Locale('gu'));
    expect(defaultAppLocale.languageCode, 'gu');
  });

  test('the default is a language the app actually ships', () {
    expect(
      AppLocalizations.supportedLocales,
      contains(defaultAppLocale),
      reason: 'a default outside supportedLocales would fall to the '
          'device locale again',
    );
  });
}
