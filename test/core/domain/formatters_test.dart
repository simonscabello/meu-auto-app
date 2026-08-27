import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/formatters.dart';

void main() {
  setUpAll(ensurePtBrFormatting);

  test('formatKm(98450) uses a thousands separator and the unit', () {
    expect(formatKm(0), '0 km');
    expect(formatKm(1), '1 km');
    expect(formatKm(98450), '98.450 km');
    expect(formatKm(1000000), '1.000.000 km');
    expect(formatKmNumber(98450), '98.450');
  });

  test('formatCivilDate variants stay on the civil day', () {
    const date = CivilDate(2026, 8, 10);
    expect(formatCivilDate(date), '10/08/2026');
    expect(formatCivilDateLong(date), '10 de agosto de 2026');
    expect(formatCivilDayMonth(date), '10 de agosto');
    expect(formatCivilDayMonthShort(date), '10 AGO');
    expect(formatCivilMonthHeader(date), 'Agosto de 2026');
  });

  test('formatInstant converts the timestamp to the device local zone', () {
    final instant = DateTime.utc(2026, 8, 10, 3, 0, 0);
    final local = instant.toLocal();
    final formatted = formatInstant(instant);
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    expect(formatted, contains('$day/$month/${local.year}'));
  });

  group('masked fields read back as integers', () {
    test('money reads the digits, masked or not', () {
      expect(centsFromMoneyField('R\$ 420,00'), 42000);
      expect(centsFromMoneyField('R\$ 4.200,00'), 420000);
      expect(centsFromMoneyField('42000'), 42000);
      expect(centsFromMoneyField('R\$ 0,00'), 0);
      expect(centsFromMoneyField(''), isNull);
      expect(centsFromMoneyField('   '), isNull);
    });

    test('mileage reads the digits, masked or not', () {
      expect(kmFromField('98.450'), 98450);
      expect(kmFromField('98450'), 98450);
      expect(kmFromField('0'), 0);
      expect(kmFromField(''), isNull);
    });

    test('digitsOnly keeps order and drops everything else', () {
      expect(digitsOnly('R\$ 1.234,56'), '123456');
      expect(digitsOnly('abc'), '');
    });
  });
}
