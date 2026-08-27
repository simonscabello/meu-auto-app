import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/shared/widgets/app_number_field.dart';

/// Types [keystrokes] one character at a time through [formatter], the way a
/// keyboard does, and returns what the field ends up showing.
String _type(TextInputFormatter formatter, String keystrokes) {
  var value = const TextEditingValue();
  for (final char in keystrokes.split('')) {
    final typed = TextEditingValue(
      text: value.text + char,
      selection: TextSelection.collapsed(offset: value.text.length + 1),
    );
    value = formatter.formatEditUpdate(value, typed);
  }
  return value.text;
}

/// One backspace at the end of [current].
TextEditingValue _backspace(TextInputFormatter formatter, String current) {
  final shorter = current.isEmpty
      ? current
      : current.substring(0, current.length - 1);
  return formatter.formatEditUpdate(
    TextEditingValue(
      text: current,
      selection: TextSelection.collapsed(offset: current.length),
    ),
    TextEditingValue(
      text: shorter,
      selection: TextSelection.collapsed(offset: shorter.length),
    ),
  );
}

void main() {
  setUpAll(ensurePtBrFormatting);

  group('MoneyInputFormatter', () {
    const formatter = MoneyInputFormatter();

    test('fills from the cents up, the way a card machine does', () {
      expect(_type(formatter, '4'), 'R\$ 0,04');
      expect(_type(formatter, '42'), 'R\$ 0,42');
      expect(_type(formatter, '420'), 'R\$ 4,20');
      expect(_type(formatter, '42000'), 'R\$ 420,00');
      expect(_type(formatter, '420000'), 'R\$ 4.200,00');
    });

    test('what the person sees is what the write sends', () {
      expect(centsFromMoneyField(_type(formatter, '42000')), 42000);
    });

    test('non-digits typed by a stray keyboard are ignored', () {
      // Four digits reach the field: 4, 2, 0, 0.
      expect(_type(formatter, '4a2,0.0'), 'R\$ 42,00');
    });

    test('stops at nine digits, the ceiling the write already had', () {
      // The tenth keystroke onwards changes nothing.
      expect(_type(formatter, '123456789'), 'R\$ 1.234.567,89');
      expect(_type(formatter, '1234567890123'), 'R\$ 1.234.567,89');
    });

    test('backspacing through zero clears the field', () {
      expect(_backspace(formatter, 'R\$ 0,04').text, isEmpty);
    });

    test('backspacing a real amount drops one digit', () {
      expect(_backspace(formatter, 'R\$ 4,20').text, 'R\$ 0,42');
    });

    test('the caret stays at the end so the next digit lands there', () {
      final value = formatter.formatEditUpdate(
        const TextEditingValue(),
        const TextEditingValue(text: '42000'),
      );
      expect(value.selection.baseOffset, value.text.length);
      expect(value.selection.isCollapsed, isTrue);
    });
  });

  group('KmInputFormatter', () {
    const formatter = KmInputFormatter();

    test('groups thousands as the reading is typed', () {
      expect(_type(formatter, '9'), '9');
      expect(_type(formatter, '984'), '984');
      expect(_type(formatter, '98450'), '98.450');
      expect(_type(formatter, '1234567'), '1.234.567');
    });

    test('what the person sees is what the write sends', () {
      expect(kmFromField(_type(formatter, '98450')), 98450);
    });

    test('zero is a real mileage and is not cleared', () {
      expect(_backspace(formatter, '10').text, '1');
      expect(_type(formatter, '0'), '0');
    });

    test('emptying the field leaves it empty', () {
      expect(_backspace(formatter, '9').text, isEmpty);
    });

    test('stops at seven digits', () {
      expect(_type(formatter, '123456789'), '1.234.567');
    });
  });

  group('kmController', () {
    test('prefills masked and fully selected so typing replaces it', () {
      final controller = kmController(98450);
      addTearDown(controller.dispose);
      expect(controller.text, '98.450');
      expect(controller.selection.baseOffset, 0);
      expect(controller.selection.extentOffset, '98.450'.length);
    });

    test('setKmText resets to the same shape', () {
      final controller = kmController(0);
      addTearDown(controller.dispose);
      setKmText(controller, 120000);
      expect(controller.text, '120.000');
      expect(controller.selection.extentOffset, '120.000'.length);
    });
  });
}
