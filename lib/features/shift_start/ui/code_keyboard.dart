/// Ticket 10 (issue #11, PRD-2 §0.16): the `XX-0000` code field's
/// keyboard-flip brain, extracted as pure functions so the widget only
/// applies the decision (D-104, DESIGN-driver-app.md §4.5).
///
/// Flip rule: text keyboard while fewer than 2 letters are typed; numeric
/// keypad once the letter half is complete — the numeric keypad has no
/// dash key, so the dash is auto-inserted the moment the 2nd letter lands
/// (`XX-` then the digits follow). Deleting back below the dash re-flips
/// to the text keyboard and never re-inserts the dash, so backspace can
/// always get past it. The keyboard state is derived from the field
/// content, so after any paste it is correct by construction.
///
/// The two entry transforms are split by WHAT the edit did, not by how
/// long the text got: an edit that only removes characters is a deletion
/// (the dash is kept where it is, never re-inserted), anything that brings
/// characters along - typing, a paste, an overwritten selection - is an
/// insertion (the canonical `XX-` shape is rebuilt).
library;

import 'package:flutter/services.dart';

/// The letters-plus-digits entry cap: 6 alphanumerics = `XX-0000` (7
/// chars with the auto-dash).
const int maxDriverCodeAlnum = 6;

final RegExp _junk = RegExp('[^A-Z0-9]');

/// The raw alphanumeric entry content of [fieldText] — the paint-side view
/// used by the OTP-box renderer (one visible box per character, the dash
/// never occupying a cell).
String alnumEntryOf(String fieldText) => _alnumOf(fieldText);

/// Uppercases, drops everything but letters and digits, and caps at
/// [maxDriverCodeAlnum] — the raw alphabet of the entry.
String _alnumOf(String raw) {
  final filtered = raw.toUpperCase().replaceAll(_junk, '');
  return filtered.length <= maxDriverCodeAlnum
      ? filtered
      : filtered.substring(0, maxDriverCodeAlnum);
}

/// The keyboard decision (pure): [fieldText] is the field's current text.
/// Fewer than 2 letters typed → text keyboard; the letter half complete →
/// numeric keypad. Backspacing below the dash shortens the letters again
/// and re-flips to text.
TextInputType codeFieldKeyboardType(String fieldText) {
  final letters = _alnumOf(fieldText).replaceAll(RegExp('[0-9]'), '').length;
  return letters >= 2 ? TextInputType.number : TextInputType.text;
}

/// The auto-dash transform for a typing/paste edit (pure): raw entry →
/// display form. The dash inserts the moment the 2nd letter lands, so the
/// field reads `XX-` before the digits; an entry that does not start with
/// 2 letters is capped but left bare (a bad shape shows the inline error
/// on submit, never a misleading dash).
String formatDriverCodeInsertion(String raw) {
  final clamped = _alnumOf(raw);
  if (clamped.length < 2 ||
      !_isLetter(clamped[0]) ||
      !_isLetter(clamped[1])) {
    return clamped;
  }
  return '${clamped.substring(0, 2)}-${clamped.substring(2)}';
}

/// The deletion-safe transform (pure): a backspace keeps an existing dash
/// but never re-inserts one — otherwise deleting the dash would bounce
/// straight back and the driver could never remove a letter. Junk is
/// dropped and the full 7-char cap holds.
String formatDriverCodeDeletion(String raw) {
  final kept = raw
      .toUpperCase()
      .replaceAll(RegExp('[^A-Z0-9-]'), '');
  return kept.length <= maxDriverCodeAlnum + 1
      ? kept
      : kept.substring(0, maxDriverCodeAlnum + 1);
}

bool _isLetter(String char) => char.compareTo('A') >= 0 && char.compareTo('Z') <= 0;

/// True when the edit only REMOVED text (a backspace, a cut, a deleted
/// selection) and brought nothing new along. Typing, a paste, an
/// overwritten selection - anything that inserts characters - is an
/// insertion, even when the result is shorter than the text it replaces
/// (pasting a shorter code over the old one).
bool _isDeletion(String oldText, String newText) {
  if (newText.length >= oldText.length) return false;
  var prefix = 0;
  while (prefix < newText.length && oldText[prefix] == newText[prefix]) {
    prefix++;
  }
  var suffix = 0;
  while (suffix < newText.length - prefix &&
      oldText[oldText.length - 1 - suffix] ==
          newText[newText.length - 1 - suffix]) {
    suffix++;
  }
  return newText.substring(prefix, newText.length - suffix).isEmpty;
}

/// The field's input formatter: routes each edit through the right pure
/// transform. An edit that only removes text is a backspace (the
/// deletion-safe path); everything else — typing, paste, replace — takes
/// the auto-dash path. The cursor lands at the end, the old formatter's
/// idiom.
class DriverCodeInputFormatter extends TextInputFormatter {
  const DriverCodeInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Nothing changed (the IME re-sent the same text, e.g. a composing
    // region commit): nothing to format. Re-formatting here would put a
    // just-deleted dash back - the letter below it could never be removed.
    if (newValue.text == oldValue.text) return newValue;
    final deleting = _isDeletion(oldValue.text, newValue.text);
    final text = deleting
        ? formatDriverCodeDeletion(newValue.text)
        : formatDriverCodeInsertion(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
