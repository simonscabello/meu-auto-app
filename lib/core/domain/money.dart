import 'package:intl/intl.dart';

/// An amount in integer cents. Never a [double].
final class Money implements Comparable<Money> {
  const Money.fromCents(this.cents);

  static const Money zero = Money.fromCents(0);

  final int cents;

  static final _integer = NumberFormat('#,##0', 'pt_BR');

  String format() {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final whole = abs ~/ 100;
    final fraction = abs % 100;
    return '$sign${_withSymbol(_integer.format(whole))},${fraction.toString().padLeft(2, '0')}';
  }

  /// Rounded to the nearest real, for tight layouts. Still integer math.
  String formatWhole() {
    final sign = cents < 0 ? '-' : '';
    final roundedReais = (cents.abs() + 50) ~/ 100;
    return '$sign${_withSymbol(_integer.format(roundedReais))}';
  }

  Money operator +(Money other) => Money.fromCents(cents + other.cents);

  @override
  int compareTo(Money other) => cents.compareTo(other.cents);

  bool operator <(Money other) => cents < other.cents;
  bool operator <=(Money other) => cents <= other.cents;
  bool operator >(Money other) => cents > other.cents;
  bool operator >=(Money other) => cents >= other.cents;

  @override
  bool operator ==(Object other) => other is Money && other.cents == cents;

  @override
  int get hashCode => cents.hashCode;

  @override
  String toString() => format();

  static String _withSymbol(String amount) => 'R\$ $amount';
}
