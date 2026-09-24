import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/features/costs/domain/costs_copy.dart';

/// The two labels that used to live on Início and moved to Histórico with
/// the cost figure they describe.
void main() {
  test('the window is a rolling one, never "este mês"', () {
    expect(costPeriodLabel(12), 'Gastos registrados · últimos 12 meses');
    expect(costPeriodLabel(1), 'Gastos registrados · últimos 30 dias');
  });

  test('a single category is not joined with "e"', () {
    expect(includedCategoriesLine(['manutencao']), 'Inclui manutenção');
  });

  test('an unmapped category is shown rather than dropped', () {
    expect(
      includedCategoriesLine(['manutencao', 'pedagio']),
      'Inclui manutenção e pedagio',
    );
  });

  test('the four tracked categories read as one sentence', () {
    expect(
      includedCategoriesLine(['manutencao', 'ipva', 'licenciamento', 'seguro']),
      'Inclui manutenção, IPVA, licenciamento e seguro',
    );
    expect(includedCategoriesLine(const []), isNull);
  });
}
