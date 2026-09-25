import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/money.dart';

void main() {
  test('formats reais from integer cents', () {
    expect(const Money.fromCents(0).format(), 'R\$\u00A00,00');
    expect(const Money.fromCents(1).format(), 'R\$\u00A00,01');
    expect(const Money.fromCents(5).format(), 'R\$\u00A00,05');
    expect(const Money.fromCents(42000).format(), 'R\$\u00A0420,00');
    expect(const Money.fromCents(123456).format(), 'R\$\u00A01.234,56');
    expect(const Money.fromCents(100000000).format(), 'R\$\u00A01.000.000,00');
    expect(Money.zero.format(), 'R\$\u00A00,00');
  });

  test('formatWhole rounds to the nearest real for tight spaces', () {
    expect(const Money.fromCents(123456).formatWhole(), 'R\$\u00A01.235');
    expect(const Money.fromCents(42000).formatWhole(), 'R\$\u00A0420');
  });

  test('adds and compares by cents', () {
    const a = Money.fromCents(100);
    const b = Money.fromCents(250);
    expect(a + b, const Money.fromCents(350));
    expect(a.compareTo(b), lessThan(0));
    expect(b > a, isTrue);
    expect(a == const Money.fromCents(100), isTrue);
    expect(Money.zero.cents, 0);
  });
}
