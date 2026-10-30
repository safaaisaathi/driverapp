/// F-D10 language toggle (ticket 13) — the D1 control that flips the
/// whole app between English and Gujarati, instantly and persistently
/// (LocaleController is watched by MaterialApp).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/locale_controller.dart';

/// Compact toggle pinned to D1's top end: a small [OutlinedButton] whose
/// label names the language it switches TO, written in that language —
/// the standard switcher affordance (a native language name reads the
/// same way no matter which locale is active; the en/gu arb files carry
/// both native names verbatim, so 0.11.4 "all text through l10n" holds).
///
/// The ≥56 dp hit target and the colors come from `AppTheme`
/// (`outlinedButtonTheme`, contract section 6 / token rule 0.11.4).
class LanguageToggleButton extends ConsumerWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(localeControllerProvider);
    final l10n = AppLocalizations.of(context)!;
    // No stored choice (null) sits on the Gujarati default (issue #14), so
    // the toggle offers the other language, English.
    final toGujarati = (chosen?.languageCode ?? 'gu') == 'en';
    final next = Locale(toGujarati ? 'gu' : 'en');
    return Semantics(
      label: l10n.languageChangeHint,
      button: true,
      child: OutlinedButton(
        key: const ValueKey('d1-language-toggle'),
        onPressed: () =>
            ref.read(localeControllerProvider.notifier).setLocale(next),
        child: Text(toGujarati ? l10n.languageNameGu : l10n.languageNameEn),
      ),
    );
  }
}
