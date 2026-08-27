import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/money.dart';

void main() {
  test('formats reais from integer cents', () {
    expect(const Money.fromCents(0).format(), r'R$ 0,00');
    expect(const Money.fromCents(1).format(), r'R$ 0,01');
    expect(const Money.fromCents(5).format(), r'R$ 0,05');
    expect(const Money.fromCents(42000).format(), r'R$ 420,00');
    expect(const Money.fromCents(123456).format(), r'R$ 1.234,56');
    expect(const Money.fromCents(100000000).format(), r'R$ 1.000.000,00');
    expect(Money.zero.format(), r'R$ 0,00');
  });

  test('formatWhole rounds to the nearest real for tight spaces', () {
    expect(const Money.fromCents(123456).formatWhole(), r'R$ 1.235');
    expect(const Money.fromCents(42000).formatWhole(), r'R$ 420');
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
