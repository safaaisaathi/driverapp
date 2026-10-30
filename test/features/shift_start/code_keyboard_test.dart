/// Ticket 10 (issue #11, PRD-2 §0.16): the code-field keyboard flip and the
/// auto-dash entry transform as PURE functions — pure unit tests, no
/// widgets, no pumps.
///
/// Flip rule: text keyboard while fewer than 2 letters are typed; numeric
/// keypad once the letter half is complete (from the 2nd letter on). The
/// dash is auto-inserted when the 2nd letter lands (the numeric keypad has
/// no dash key) and a deletion below the dash never re-inserts it, so
/// backspace can always get past it.
library;

import 'package:driverapp/features/shift_start/ui/code_keyboard.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// -- keyboard decision -------------------------------------------------------

void main() {
  group('codeFieldKeyboardType (content -> TextInputType)', () {
    test('empty field: text keyboard', () {
      expect(codeFieldKeyboardType(''), TextInputType.text);
    });

    test('first letter typing: text keyboard', () {
      expect(codeFieldKeyboardType('A'), TextInputType.text);
      expect(codeFieldKeyboardType('a'), TextInputType.text);
    });

    test('2nd letter landed (letter half complete): numeric', () {
      expect(codeFieldKeyboardType('AB'), TextInputType.number);
      expect(codeFieldKeyboardType('ab'), TextInputType.number);
    });

    test('the flip counts LETTERS, not characters', () {
      // One letter plus a digit is still the letter half: the driver has
      // more letters to type, so the text keyboard must stay. A rule that
      // counted characters would flip to numeric here and trap the driver.
      expect(codeFieldKeyboardType('A1'), TextInputType.text);
      expect(codeFieldKeyboardType('12'), TextInputType.text);
      expect(codeFieldKeyboardType('1'), TextInputType.text);
    });

    test('digit half (dash or digits after the letters): numeric', () {
      expect(codeFieldKeyboardType('AB-'), TextInputType.number);
      expect(codeFieldKeyboardType('AB-1'), TextInputType.number);
      expect(codeFieldKeyboardType('AB-1234'), TextInputType.number);
    });

    test('backspace below the dash re-flips to text', () {
      expect(codeFieldKeyboardType('AB'), TextInputType.number,
          reason: 'the dash was deleted, letter half still complete');
      expect(codeFieldKeyboardType('A'), TextInputType.text);
    });
  });

  // -- auto-dash transform (insertion) ---------------------------------------

  group('formatDriverCodeInsertion (typing and paste)', () {
    test('less than 2 letters: no dash yet', () {
      expect(formatDriverCodeInsertion(''), isEmpty);
      expect(formatDriverCodeInsertion('a'), 'A');
      expect(formatDriverCodeInsertion('A'), 'A');
    });

    test('the 2nd letter lands: dash inserted, field shows XX-', () {
      expect(formatDriverCodeInsertion('ab'), 'AB-');
      expect(formatDriverCodeInsertion('AB'), 'AB-');
    });

    test('digits follow the dash', () {
      expect(formatDriverCodeInsertion('ab1'), 'AB-1');
      expect(formatDriverCodeInsertion('ab1234'), 'AB-1234');
    });

    test('pasted shapes normalize: ab1234 / AB-1234 / ab-1234', () {
      expect(formatDriverCodeInsertion('ab1234'), 'AB-1234');
      expect(formatDriverCodeInsertion('AB-1234'), 'AB-1234');
      expect(formatDriverCodeInsertion('ab-1234'), 'AB-1234');
    });

    test('junk characters are dropped, only letters and digits kept', () {
      expect(formatDriverCodeInsertion('a@#b'), 'AB-');
      expect(formatDriverCodeInsertion('ab 12,34'), 'AB-1234');
    });

    test('cap: 6 alphanumerics max (7 chars with the dash)', () {
      expect(formatDriverCodeInsertion('abcdefgh'), 'AB-CDEF');
      expect(formatDriverCodeInsertion('ab-1234xyz'), 'AB-1234');
    });

    test('entry that does not start with 2 letters gets no dash', () {
      expect(formatDriverCodeInsertion('a1234'), 'A1234');
      expect(formatDriverCodeInsertion('1234'), '1234');
    });
  });

  // -- deletion-safe transform (backspace) -----------------------------------

  group('formatDriverCodeDeletion (backspace)', () {
    test('an existing dash stays while digits are deleted', () {
      expect(formatDriverCodeDeletion('AB-123'), 'AB-123');
      expect(formatDriverCodeDeletion('AB-1'), 'AB-1');
    });

    test('deleting the dash itself does NOT re-insert it', () {
      expect(formatDriverCodeDeletion('AB'), 'AB');
    });

    test('deleting below the dash removes letters normally', () {
      expect(formatDriverCodeDeletion('A'), 'A');
    });

    test('junk dropped, cap holds', () {
      expect(formatDriverCodeDeletion('ab@-12,3456789'), 'AB-1234');
    });
  });

  // -- the widget-side formatter routes the two transforms --------------------

  group('DriverCodeInputFormatter', () {
    const formatter = DriverCodeInputFormatter();

    TextEditingValue edit(String oldText, String newText) =>
        formatter.formatEditUpdate(
          TextEditingValue(
            text: oldText,
            selection: TextSelection.collapsed(offset: oldText.length),
          ),
          TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length),
          ),
        );

    TextEditingValue editWithSelection(
      String oldText,
      TextSelection oldSelection,
      String newText,
    ) =>
        formatter.formatEditUpdate(
          TextEditingValue(text: oldText, selection: oldSelection),
          TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length),
          ),
        );

    test('insertion: the 2nd letter lands, dash auto-inserted', () {
      expect(edit('A', 'AB').text, 'AB-');
      // Cursor sits at the end so the digits follow the dash.
      expect(edit('A', 'AB').selection.baseOffset, 3);
    });

    test('insertion: a pasted full code lands in the canonical shape', () {
      expect(edit('AB-', 'ab1234').text, 'AB-1234');
      expect(edit('', 'AB-1234').text, 'AB-1234');
      expect(edit('', 'ab-1234').text, 'AB-1234');
    });

    test('insertion: a paste over a selection wins, even when it is '
        'shorter than the text it replaces', () {
      // The driver selects the old code and pastes a shorter one. The paste
      // brings characters, so it is an INSERTION - the canonical dash comes
      // back. A deletion would drop the dash and leave a bare "AB12".
      expect(edit('AB-1234', 'ab12').text, 'AB-12');
      expect(edit('AB-1234', 'ab1234').text, 'AB-1234');
    });

    test('a selection-shaped edit: the selected digits are replaced, the '
        'canonical dash rebuilds', () {
      // The driver selects "1234" and types "9" over it. The edit arrives
      // with a real (non-collapsed) old selection, so the routing must not
      // depend on the caret sitting at the end.
      expect(
        editWithSelection(
          'AB-1234',
          const TextSelection(baseOffset: 3, extentOffset: 7),
          'AB-9',
        ).text,
        'AB-9',
      );
    });

    test('a selection-shaped deletion: the selected digits are gone, the '
        'dash stays and does not bounce back', () {
      expect(
        editWithSelection(
          'AB-1234',
          const TextSelection(baseOffset: 3, extentOffset: 7),
          'AB-',
        ).text,
        'AB-',
      );
    });

    test('deletion: the dash never re-inserts, backspace gets past it', () {
      expect(edit('AB-', 'AB').text, 'AB');
      expect(edit('AB', 'A').text, 'A');
      expect(edit('AB-12', 'AB-1').text, 'AB-1');
    });

    test('an edit that changed nothing changes nothing (no dash bounce '
        'back)', () {
      // The IME re-sends the same text (a composing-region commit). The
      // dash the driver just deleted must stay deleted, or the letter
      // below it could never be removed.
      expect(edit('AB', 'AB').text, 'AB');
      expect(edit('AB-', 'AB-').text, 'AB-');
    });

    test('a full backspace walk clears the field letter by letter', () {
      // The real IME sends the whole text on every keystroke. The typed
      // text is A, AB, AB, A, '' and the field walks A -> AB- -> AB -> A
      // -> empty: the dash is auto-inserted, then backspace removes it
      // without it bouncing back.
      var text = '';
      for (final typed in ['A', 'AB', 'AB', 'A', '']) {
        text = edit(text, typed).text;
      }
      expect(text, isEmpty);
    });
  });
}
