import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/features/costs/domain/costs_copy.dart';

void main() {
  group('costWindowLabel', () {
    test('one month is the last 30 days, never "este mês"', () {
      expect(costWindowLabel(1), 'últimos 30 dias');
      expect(costWindowLabel(1), isNot(contains('este mês')));
    });

    test('three months', () {
      expect(costWindowLabel(3), 'últimos 3 meses');
    });

    test('twelve months', () {
      expect(costWindowLabel(12), 'últimos 12 meses');
    });

    test('twenty-four months', () {
      expect(costWindowLabel(24), 'últimos 24 meses');
    });
  });

  group('emptyPeriodPhrase', () {
    test('names the window and what to do next', () {
      expect(
        emptyPeriodPhrase(6),
        'Nenhum custo nos últimos 6 meses. '
        'Troque o intervalo ou registre um serviço.',
      );
    });
  });

  group('excludedCategoriesNote', () {
    test('the MVP categories name fuel and day-to-day expenses as missing', () {
      expect(
        excludedCategoriesNote([
          'manutencao',
          'ipva',
          'licenciamento',
          'seguro',
        ]),
        'Combustível e despesas do dia a dia ainda não entram nesta conta.',
      );
    });

    test('drops fuel from the note once abastecimento is tracked', () {
      expect(
        excludedCategoriesNote([
          'manutencao',
          'ipva',
          'licenciamento',
          'seguro',
          'abastecimento',
        ]),
        'despesas do dia a dia ainda não entram nesta conta.',
      );
    });

    test('drops the note when nothing is missing', () {
      expect(
        excludedCategoriesNote(['manutencao', 'abastecimento', 'expenses']),
        isNull,
      );
    });
  });
}
