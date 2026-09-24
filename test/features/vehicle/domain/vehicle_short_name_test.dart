import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/features/vehicle/domain/vehicle.dart';

void main() {
  test('the FIPE specification is left out of the short model name', () {
    expect(shortModelName('PRIUS 1.8 16V 5p Aut. (Híbrido)'), 'Prius');
    expect(shortModelName('ONIX HATCH LT 1.0 12V Flex 5p Mec.'), 'Onix Hatch');
    expect(shortModelName('HB20 Comfort 1.0 Flex 12V Mec.'), 'HB20 Comfort');
    expect(
      shortModelName('T-CROSS Highline 250 TSI 1.4 Flex Aut.'),
      'T-Cross Highline',
    );
    expect(shortModelName('Gol'), 'Gol');
    expect(shortModelName('Onix Plus'), 'Onix Plus');
    expect(shortModelName('UP!'), 'Up!');
    expect(shortModelName('  '), '');
  });
}
