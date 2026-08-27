import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record_draft.dart';

void main() {
  group('toJson', () {
    test('assembles the request and converts money to integer cents', () {
      const draft = MaintenanceRecordDraft(
        id: _recordId,
        occurredOn: CivilDate(2026, 8, 26),
        mileageKm: 100000,
        kind: MaintenanceRecordKind.performed,
        workshopName: 'Auto Center Silva',
        totalCostCents: Money.fromCents(42000),
        notes: 'Óleo sintético',
        items: [
          MaintenanceRecordLineDraft(
            item: _oil,
            description: '5W30',
            partBrand: 'Lubrax',
            costCents: Money.fromCents(18000),
            warrantyMonths: 6,
            warrantyKm: 10000,
          ),
          MaintenanceRecordLineDraft(
            item: _filter,
            costCents: Money.fromCents(4500),
          ),
        ],
      );
      final body = draft.toJson();

      expect(body['id'], _recordId);
      expect(body['occurred_on'], '2026-08-26');
      expect(body['mileage_km'], 100000);
      expect(body['kind'], 'performed');
      expect(body['workshop_name'], 'Auto Center Silva');
      expect(body['total_cost_cents'], 42000);
      expect(body['notes'], 'Óleo sintético');
      expect(body['items'], hasLength(2));

      final first = body['items'][0] as Map<String, dynamic>;
      expect(first['maintenance_item_id'], _oil.id);
      expect(first['description'], '5W30');
      expect(first['part_brand'], 'Lubrax');
      expect(first['cost_cents'], 18000);
      expect(first['warranty_months'], 6);
      expect(first['warranty_km'], 10000);

      final second = body['items'][1] as Map<String, dynamic>;
      expect(second['maintenance_item_id'], _filter.id);
      expect(second.containsKey('description'), isFalse);
      expect(second.containsKey('part_brand'), isFalse);
      expect(second['cost_cents'], 4500);
      expect(second.containsKey('warranty_months'), isFalse);
    });

    test('omits empty optionals rather than sending blanks', () {
      const draft = MaintenanceRecordDraft(
        id: _recordId,
        occurredOn: CivilDate(2026, 8, 26),
        mileageKm: 48000,
        kind: MaintenanceRecordKind.declared,
        items: [MaintenanceRecordLineDraft(item: _oil)],
      );
      final body = draft.toJson();

      expect(body['kind'], 'declared');
      expect(body.containsKey('workshop_name'), isFalse);
      expect(body.containsKey('total_cost_cents'), isFalse);
      expect(body.containsKey('notes'), isFalse);
      expect(body['items'], hasLength(1));
      expect((body['items'] as List).single, {'maintenance_item_id': _oil.id});
    });

    test('a care tap omits mileage_km rather than sending null', () {
      final draft = const MaintenanceRecordDraft(
        id: _recordId,
        occurredOn: CivilDate(2026, 8, 27),
        kind: MaintenanceRecordKind.performed,
        items: [MaintenanceRecordLineDraft(item: _tyre)],
      );
      final body = draft.toJson();

      expect(body.containsKey('mileage_km'), isFalse);
      expect(body['occurred_on'], '2026-08-27');
      expect(body['items'], [
        {'maintenance_item_id': _tyre.id},
      ]);
    });
  });

  group('items', () {
    test('cannot save with no items', () {
      const draft = MaintenanceRecordDraft(
        id: _recordId,
        occurredOn: CivilDate(2026, 8, 26),
        mileageKm: 48000,
        kind: MaintenanceRecordKind.performed,
        items: [],
      );

      expect(draft.canSave, isFalse);
      expect(draft.saveBlockedReason, isNotNull);
    });

    test('can save with one item', () {
      const draft = MaintenanceRecordDraft(
        id: _recordId,
        occurredOn: CivilDate(2026, 8, 26),
        mileageKm: 48000,
        kind: MaintenanceRecordKind.performed,
        items: [MaintenanceRecordLineDraft(item: _oil)],
      );

      expect(draft.canSave, isTrue);
      expect(draft.saveBlockedReason, isNull);
    });

    test('rejects a repeated item', () {
      const empty = MaintenanceRecordDraft(
        id: _recordId,
        occurredOn: CivilDate(2026, 8, 26),
        mileageKm: 48000,
        kind: MaintenanceRecordKind.performed,
        items: [],
      );

      final withOil = empty.add(_oil);
      expect(withOil.canAdd(_oil.id), isFalse);
      expect(withOil.add(_oil).items, hasLength(1));
      expect(withOil.canAdd(_filter.id), isTrue);
    });

    test('rejects a twenty-first item', () {
      var draft = const MaintenanceRecordDraft(
        id: _recordId,
        occurredOn: CivilDate(2026, 8, 26),
        mileageKm: 48000,
        kind: MaintenanceRecordKind.performed,
        items: [],
      );
      for (var i = 0; i < MaintenanceRecordDraft.maxItems; i++) {
        draft = draft.add(_item('$i'));
      }

      expect(draft.items, hasLength(20));
      expect(draft.canAdd(_oil.id), isFalse);
      expect(draft.add(_oil).items, hasLength(20));
    });
  });

  group('field errors', () {
    test('maps an indexed item error onto that line', () {
      const fields = {
        'items.1.warranty_months': 'Garantia em meses inválida.',
        'mileage_km': 'Quilometragem inválida.',
      };

      expect(
        itemFieldError(fields, 1, 'warranty_months'),
        'Garantia em meses inválida.',
      );
      expect(itemFieldError(fields, 0, 'warranty_months'), isNull);
      expect(fields['mileage_km'], 'Quilometragem inválida.');
    });

    test('accepts the bracketed form as well', () {
      const fields = {'items[0].cost_cents': 'Valor de item inválido.'};
      expect(
        itemFieldError(fields, 0, 'cost_cents'),
        'Valor de item inválido.',
      );
    });
  });
}

const _recordId = '11111111-1111-7111-8111-111111111111';

const _oil = MaintenanceItem(
  id: 'aaaaaaaa-aaaa-7aaa-8aaa-aaaaaaaaaaaa',
  slug: 'troca_oleo',
  name: 'Troca de óleo do motor',
  kind: MaintenanceItemKind.maintenance,
  vehicleType: 'car',
  isCustom: false,
  defaultStrategy: MaintenanceStrategy.periodic,
);

const _filter = MaintenanceItem(
  id: 'bbbbbbbb-bbbb-7bbb-8bbb-bbbbbbbbbbbb',
  slug: 'filtro_oleo',
  name: 'Filtro de óleo',
  kind: MaintenanceItemKind.maintenance,
  vehicleType: 'car',
  isCustom: false,
  defaultStrategy: MaintenanceStrategy.periodic,
);

const _tyre = MaintenanceItem(
  id: 'cccccccc-cccc-7ccc-8ccc-cccccccccccc',
  slug: 'calibrar_pneus',
  name: 'Calibrar os pneus',
  kind: MaintenanceItemKind.care,
  vehicleType: 'car',
  isCustom: false,
  defaultStrategy: MaintenanceStrategy.periodic,
  defaultIntervalDays: 15,
);

MaintenanceItem _item(String suffix) {
  return MaintenanceItem(
    id: '00000000-0000-7000-8000-${suffix.padLeft(12, '0')}',
    slug: 'item_$suffix',
    name: 'Item $suffix',
    kind: MaintenanceItemKind.maintenance,
    vehicleType: 'car',
    isCustom: false,
    defaultStrategy: MaintenanceStrategy.periodic,
  );
}
