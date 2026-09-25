import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/domain/plan_copy.dart';

/// The words for a state the server already decided.
///
/// Nothing here recomputes anything: every input is a field that arrived on the
/// wire. What is being tested is that two states which are genuinely different
/// do not read the same — which is the whole reason `strategy` and
/// `history_status` exist.
void main() {
  group('condition-based items are not deadlines', () {
    test('an overdue tyre is worth checking, not late', () {
      final phrase = planStatusPhrase(
        _plan(
          status: MaintenanceStatus.vencido,
          strategy: MaintenanceStrategy.conditionBased,
          remainingKm: -2000,
        ),
      );

      expect(phrase, 'Já rodou bastante — vale checar');
      expect(phrase, isNot(contains('vencida')));
    });

    test('a periodic item still says it is overdue', () {
      expect(
        planStatusPhrase(
          _plan(
            status: MaintenanceStatus.vencido,
            strategy: MaintenanceStrategy.periodic,
            remainingKm: -2000,
          ),
        ),
        'Passou 2.000\u00A0km',
      );
    });

    test('an inspection with no interval says where to look at it', () {
      expect(
        planStatusPhrase(
          _plan(
            status: MaintenanceStatus.semPeriodicidade,
            strategy: MaintenanceStrategy.inspection,
          ),
        ),
        'Verificar na revisão',
      );
    });
  });

  group('"não sei" and "nunca foi feito" do not read the same', () {
    // The group already says the date is missing; the row says how often the
    // item is done instead of repeating the same request on every line.
    test('never asked says how often the item is done', () {
      expect(
        planStatusPhrase(
          _plan(
            status: MaintenanceStatus.semBaseline,
            intervalKm: 10000,
            intervalMonths: 12,
          ),
        ),
        'A cada 10.000\u00A0km ou 12 meses',
      );
      expect(
        planStatusPhrase(_plan(status: MaintenanceStatus.semBaseline)),
        'Informe quando foi feito',
      );
    });

    test('does not remember is reassured, not asked again', () {
      expect(
        planStatusPhrase(
          _plan(
            status: MaintenanceStatus.semBaseline,
            historyStatus: MaintenanceHistoryStatus.unknown,
          ),
        ),
        'Você não lembra quando foi',
      );
    });

    test('never done is a fact about the car', () {
      expect(
        planStatusPhrase(
          _plan(
            status: MaintenanceStatus.semBaseline,
            historyStatus: MaintenanceHistoryStatus.never,
          ),
        ),
        'Nunca foi feito',
      );
    });

    // With a server that counts "never" from the car being new, the item has a
    // real due point — and the row says where it counts from.
    test('never done, counted from new, says so next to the figures', () {
      expect(
        planStatusPhrase(
          _plan(
            status: MaintenanceStatus.vencido,
            historyStatus: MaintenanceHistoryStatus.never,
            baseline: MaintenanceBaseline.sinceNew,
            remainingKm: -80000,
          ),
        ),
        'Nunca feito\u00A0· Passou 80.000\u00A0km',
      );
    });
  });

  group('strategyExplanation', () {
    test('explains only what the interval cannot', () {
      expect(
        strategyExplanation(_plan(strategy: MaintenanceStrategy.periodic)),
        isNull,
      );
      expect(
        strategyExplanation(_plan(strategy: MaintenanceStrategy.noSchedule)),
        isNull,
      );
      expect(
        strategyExplanation(
          _plan(strategy: MaintenanceStrategy.conditionBased),
        ),
        contains('desgaste'),
      );
      expect(
        strategyExplanation(_plan(strategy: MaintenanceStrategy.inspection)),
        contains('verificar na revisão'),
      );
    });

    test('says it plainly for something the car does not have', () {
      expect(
        strategyExplanation(
          _plan(
            strategy: MaintenanceStrategy.notApplicable,
            status: MaintenanceStatus.naoSeAplica,
          ),
        ),
        'Seu carro não usa esse item.',
      );
    });
  });

  // A strategy this build has never heard of must not blank the sentence out.
  group('care items speak as habits, not as deadlines', () {
    // How late, in days, when the server said: the same words Início uses.
    test('an overdue care says how late, in days', () {
      expect(
        planStatusPhrase(
          _plan(
            status: MaintenanceStatus.vencido,
            itemKind: MaintenanceItemKind.care,
            remainingDays: -13,
          ),
        ),
        'Venceu há 13 dias',
      );
    });

    test('an overdue care with no figure is time to check', () {
      expect(
        planStatusPhrase(
          _plan(
            status: MaintenanceStatus.vencido,
            itemKind: MaintenanceItemKind.care,
          ),
        ),
        'Está na hora de verificar',
      );
    });

    test('a care due soon says in how many days', () {
      expect(
        planStatusPhrase(
          _plan(
            status: MaintenanceStatus.venceEmBreve,
            itemKind: MaintenanceItemKind.care,
            remainingDays: 3,
          ),
        ),
        'Vence em 3 dias',
      );
    });

    test('a care with no baseline is ready to mark done', () {
      expect(
        planStatusPhrase(
          _plan(
            status: MaintenanceStatus.semBaseline,
            itemKind: MaintenanceItemKind.care,
          ),
        ),
        'Está na hora de verificar',
      );
    });

    test('a care on track reads as all good', () {
      expect(
        planStatusPhrase(
          _plan(
            status: MaintenanceStatus.emDia,
            itemKind: MaintenanceItemKind.care,
          ),
        ),
        'Tudo certo',
      );
    });
  });

  test('an unknown strategy falls back to the plain status phrase', () {
    expect(
      planStatusPhrase(
        _plan(
          status: MaintenanceStatus.emDia,
          strategy: MaintenanceStrategy.desconhecido,
        ),
      ),
      'Em dia',
    );
  });
}

MaintenancePlan _plan({
  MaintenanceStatus status = MaintenanceStatus.emDia,
  MaintenanceStrategy strategy = MaintenanceStrategy.periodic,
  MaintenanceHistoryStatus historyStatus = MaintenanceHistoryStatus.notAsked,
  MaintenanceItemKind itemKind = MaintenanceItemKind.maintenance,
  int? remainingKm,
  int? remainingDays,
  int? intervalKm,
  int? intervalMonths,
  MaintenanceBaseline baseline = MaintenanceBaseline.none,
}) {
  return MaintenancePlan(
    id: 'plan-1',
    maintenanceItemId: 'item-1',
    itemSlug: 'pneus',
    itemName: 'Pneus',
    itemKind: itemKind,
    alertKm: 1000,
    alertDays: 15,
    origin: MaintenancePlanOrigin.suggested,
    strategy: strategy,
    historyStatus: historyStatus,
    status: status,
    remainingKm: remainingKm,
    remainingDays: remainingDays,
    intervalKm: intervalKm,
    intervalMonths: intervalMonths,
    baseline: baseline,
  );
}
