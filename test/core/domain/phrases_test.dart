import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/phrases.dart';

void main() {
  group('remainingKmPhrase', () {
    test('covers null, overdue, due now and remaining km', () {
      expect(remainingKmPhrase(null), isNull);
      expect(remainingKmPhrase(-320), 'passou 320 km');
      expect(remainingKmPhrase(-1), 'passou 1 km');
      expect(remainingKmPhrase(0), 'vence agora');
      expect(remainingKmPhrase(1), 'faltam 1 km');
      expect(remainingKmPhrase(1550), 'faltam 1.550 km');
    });
  });

  group('remainingDaysPhrase', () {
    test('covers the calendar-copy limits', () {
      expect(remainingDaysPhrase(null), isNull);
      expect(remainingDaysPhrase(-30), 'venceu há 30 dias');
      expect(remainingDaysPhrase(-1), 'venceu ontem');
      expect(remainingDaysPhrase(0), 'vence hoje');
      expect(remainingDaysPhrase(1), 'vence amanhã');
      expect(remainingDaysPhrase(45), 'faltam 45 dias');
      expect(remainingDaysPhrase(-45), 'venceu há 45 dias');
      expect(remainingDaysPhrase(46), 'faltam cerca de 2 meses');
      expect(remainingDaysPhrase(400), 'faltam cerca de 13 meses');
    });

    test('uses months on the overdue side past 45 days', () {
      expect(remainingDaysPhrase(-46), 'venceu há cerca de 2 meses');
    });

    test('singular month and day stay grammatical', () {
      expect(remainingDaysPhrase(2), 'faltam 2 dias');
      expect(remainingDaysPhrase(-2), 'venceu há 2 dias');
    });
  });

  group('dueSummary', () {
    test('uses only km, only days, both, or neither', () {
      expect(dueSummary(remainingKm: 1550), 'faltam 1.550 km');
      expect(dueSummary(remainingDays: 12), 'faltam 12 dias');
      expect(
        dueSummary(remainingKm: 1550, remainingDays: 12),
        'faltam 12 dias · faltam 1.550 km',
      );
      expect(dueSummary(), isNull);
      expect(dueSummary(remainingKm: null, remainingDays: null), isNull);
    });

    test('leads with the closer remaining dimension', () {
      expect(
        dueSummary(remainingKm: -320, remainingDays: 12),
        'passou 320 km · faltam 12 dias',
      );
      expect(
        dueSummary(remainingKm: 10, remainingDays: 100),
        'faltam 10 km · faltam cerca de 3 meses',
      );
    });
  });

  group('maintenanceStatusPhrase', () {
    test('maps each known status and never throws on unknown', () {
      expect(maintenanceStatusPhrase('vencido'), 'Está vencida');
      expect(
        maintenanceStatusPhrase(
          'vence_em_breve',
          remainingKm: 1550,
          remainingDays: 12,
        ),
        'faltam 12 dias · faltam 1.550 km',
      );
      expect(maintenanceStatusPhrase('vence_em_breve'), '');
      expect(maintenanceStatusPhrase('em_dia'), 'Em dia');
      expect(
        maintenanceStatusPhrase('sem_baseline'),
        'Informe a última vez para começarmos a contar',
      );
      expect(
        maintenanceStatusPhrase('sem_periodicidade'),
        'Só histórico, não vence',
      );
      expect(maintenanceStatusPhrase('algo_novo_do_servidor'), '');
    });
  });

  group('paidLatePhrase', () {
    test('describes delay only when remaining days are negative', () {
      expect(paidLatePhrase(-3), 'pago com 3 dias de atraso');
      expect(paidLatePhrase(-1), 'pago com 1 dia de atraso');
      expect(paidLatePhrase(0), isNull);
      expect(paidLatePhrase(5), isNull);
      expect(paidLatePhrase(-45), 'pago com 45 dias de atraso');
    });
  });
}
