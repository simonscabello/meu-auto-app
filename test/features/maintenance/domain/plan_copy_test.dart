import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record.dart';
import 'package:meu_auto/features/maintenance/domain/plan_copy.dart';

void main() {
  group('intervalPhrase', () {
    test('spells out only the dimensions that exist', () {
      expect(intervalPhrase(km: 10000), 'a cada 10.000 km');
      expect(intervalPhrase(months: 12), 'a cada 12 meses');
      expect(intervalPhrase(days: 15), 'a cada 15 dias');
      expect(
        intervalPhrase(km: 10000, months: 12),
        'a cada 10.000 km ou 12 meses',
      );
      expect(
        intervalPhrase(km: 10000, months: 12, days: 15),
        'a cada 10.000 km, 12 meses ou 15 dias',
      );
      expect(intervalPhrase(), isNull);
      expect(intervalPhrase(km: null, months: null, days: null), isNull);
    });

    test('singular units stay grammatical', () {
      expect(intervalPhrase(months: 1), 'a cada 1 mês');
      expect(intervalPhrase(days: 1), 'a cada 1 dia');
    });
  });

  group('dueNextPhrase', () {
    test('omits a null dimension rather than writing zero', () {
      expect(dueNextPhrase(dueAtKm: 108200), 'aos 108.200 km');
      expect(
        dueNextPhrase(dueOn: const CivilDate(2026, 9, 3)),
        'em 03/09/2026',
      );
      expect(
        dueNextPhrase(dueAtKm: 108200, dueOn: const CivilDate(2026, 9, 3)),
        'aos 108.200 km · em 03/09/2026',
      );
      expect(dueNextPhrase(), isNull);
      expect(dueNextPhrase(dueAtKm: null, dueOn: null), isNull);
    });
  });

  group('careNextCheckPhrase', () {
    test('spells remaining_days from the server, and stays quiet without it', () {
      expect(careNextCheckPhrase(15), 'Próxima verificação em 15 dias');
      expect(careNextCheckPhrase(1), 'Próxima verificação em 1 dia');
      expect(careNextCheckPhrase(null), isNull);
      expect(careNextCheckPhrase(0), isNull);
    });
  });

  group('lastDonePhrase', () {
    test('joins date and mileage when both exist', () {
      expect(
        lastDonePhrase(
          occurredOn: const CivilDate(2025, 8, 10),
          mileageKm: 98200,
        ),
        '10/08/2025 · 98.200 km',
      );
      expect(lastDonePhrase(), isNull);
    });
  });

  group('mileageSincePreviousPhrase', () {
    test('is subtraction of two numbers the API already returned', () {
      expect(
        mileageSincePreviousPhrase(108200, 98200),
        '10.000 km desde a anterior',
      );
      expect(
        mileageSincePreviousPhrase(90000, 98200),
        '8.200 km a menos que a anterior',
      );
      expect(mileageSincePreviousPhrase(98200, 98200), isNull);
    });
  });

  test('historyOfItem keeps server order and skips other items', () {
    final oil = _record(id: 'r1', itemId: 'oil', mileage: 108200);
    final mix = _record(
      id: 'r2',
      itemId: 'oil',
      mileage: 98200,
      extraItemId: 'filter',
    );
    final other = _record(id: 'r3', itemId: 'filter', mileage: 90000);

    final history = historyOfItem([oil, mix, other], 'oil');
    expect(history.map((record) => record.id), ['r1', 'r2']);
  });
}

MaintenanceRecord _record({
  required String id,
  required String itemId,
  required int mileage,
  String? extraItemId,
}) {
  return MaintenanceRecord(
    id: id,
    vehicleId: 'v1',
    occurredOn: const CivilDate(2026, 8, 10),
    mileageKm: mileage,
    kind: MaintenanceRecordKind.performed,
    totalCostCents: Money.zero,
    items: [
      MaintenanceRecordItem(
        id: 'line-$id',
        maintenanceItemId: itemId,
        itemSlug: itemId,
        itemName: itemId,
      ),
      if (extraItemId != null)
        MaintenanceRecordItem(
          id: 'line-$id-extra',
          maintenanceItemId: extraItemId,
          itemSlug: extraItemId,
          itemName: extraItemId,
        ),
    ],
    createdAt: DateTime(2026, 8, 10),
    updatedAt: DateTime(2026, 8, 10),
  );
}
