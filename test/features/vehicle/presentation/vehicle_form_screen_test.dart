import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/features/vehicle/presentation/vehicle_form_screen.dart';

String _type(TextInputFormatter formatter, String keystrokes) {
  var value = const TextEditingValue();
  for (final char in keystrokes.split('')) {
    value = formatter.formatEditUpdate(
      value,
      TextEditingValue(
        text: value.text + char,
        selection: TextSelection.collapsed(offset: value.text.length + 1),
      ),
    );
  }
  return value.text;
}

void main() {
  group('PlateInputFormatter', () {
    const formatter = PlateInputFormatter();

    test('uppercases what is typed in lower case', () {
      expect(_type(formatter, 'abc1d23'), 'ABC1D23');
    });

    test('drops the hyphen people type out of habit', () {
      expect(_type(formatter, 'ABC-1234'), 'ABC1234');
    });

    test('drops spaces and punctuation anywhere in the plate', () {
      expect(_type(formatter, ' abc 1d.23 '), 'ABC1D23');
    });

    test('stops at seven, the length both formats share', () {
      expect(_type(formatter, 'ABC1D23456'), 'ABC1D23');
    });

    test(
      'matches what the server normalizes to, so no 422 for punctuation',
      () {
        // The server strips non-alphanumerics and uppercases before validating
        // against ^[A-Z]{3}[0-9]{4}$ or ^[A-Z]{3}[0-9][A-Z][0-9]{2}$.
        expect(_type(formatter, 'abc-1234'), 'ABC1234');
        expect(RegExp(r'^[A-Z]{3}[0-9]{4}$').hasMatch('ABC1234'), isTrue);
      },
    );

    test('an empty field stays empty', () {
      expect(_type(formatter, ''), isEmpty);
      expect(_type(formatter, '---'), isEmpty);
    });
  });
}
