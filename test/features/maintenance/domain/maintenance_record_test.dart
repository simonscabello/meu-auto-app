import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record.dart';

void main() {
  test('a record with a single item', () {
    final record = MaintenanceRecord.fromJson(
      _record(items: [_item(name: 'Troca de óleo do motor')]),
    );

    expect(record.occurredOn, const CivilDate(2026, 8, 10));
    expect(record.mileageKm, 98200);
    expect(record.kind, MaintenanceRecordKind.performed);
    expect(record.totalCostCents.format(), r'R$ 420,00');
    expect(record.items, hasLength(1));
    expect(record.itemsSummary, 'Troca de óleo do motor');
  });

  test('a service with several items reads as one event', () {
    final record = MaintenanceRecord.fromJson(
      _record(
        items: [
          _item(name: 'Troca de óleo do motor'),
          _item(name: 'Filtro de óleo'),
          _item(name: 'Filtro de ar do motor'),
        ],
      ),
    );

    expect(record.items, hasLength(3));
    expect(
      record.itemsSummary,
      'Troca de óleo do motor, Filtro de óleo, Filtro de ar do motor',
    );
  });

  test('every optional field may be absent', () {
    final record = MaintenanceRecord.fromJson({
      'id': _recordId,
      'vehicle_id': _vehicleId,
      'occurred_on': '2026-08-10',
      'mileage_km': 98200,
      'kind': 'declared',
      'workshop_name': null,
      'total_cost_cents': 0,
      'notes': null,
      'items': [
        {
          'id': _itemId,
          'maintenance_item_id': _catalogueId,
          'item_slug': 'troca_oleo',
          'item_name': 'Troca de óleo do motor',
        },
      ],
      'created_at': '2026-08-10T14:00:00Z',
      'updated_at': '2026-08-10T14:00:00Z',
    });

    expect(record.workshopName, isNull);
    expect(record.notes, isNull);
    expect(record.totalCostCents.cents, 0);
    final item = record.items.single;
    expect(item.costCents, isNull);
    expect(item.description, isNull);
    expect(item.partBrand, isNull);
    expect(item.hasWarranty, isFalse);
  });

  test('a care-only record may arrive without mileage', () {
    final record = MaintenanceRecord.fromJson(
      _record()
        ..['mileage_km'] = null
        ..['items'] = [_item(name: 'Calibrar os pneus')],
    );

    expect(record.mileageKm, isNull);
  });

  test('an unknown kind falls back instead of throwing', () {
    final record = MaintenanceRecord.fromJson(_record(kind: 'estimated'));
    expect(record.kind, MaintenanceRecordKind.desconhecido);
  });

  test('items arriving as something other than a list yields none', () {
    final json = _record(items: [])..['items'] = 'nada disso';
    expect(MaintenanceRecord.fromJson(json).items, isEmpty);
  });

  group('warranty', () {
    test('both dimensions come derived from the server', () {
      final item = MaintenanceRecordItem.fromJson(
        _item(
          name: 'Bateria',
          warrantyMonths: 24,
          warrantyKm: 40000,
          warrantyUntil: '2028-08-10',
          warrantyUntilKm: 138200,
        ),
      );

      expect(item.warrantyMonths, 24);
      expect(item.warrantyUntil, const CivilDate(2028, 8, 10));
      expect(item.warrantyUntilKm, 138200);
      expect(item.hasWarranty, isTrue);
    });

    test('a time-only warranty leaves the distance null', () {
      final item = MaintenanceRecordItem.fromJson(
        _item(name: 'Bateria', warrantyMonths: 24, warrantyUntil: '2028-08-10'),
      );

      expect(item.warrantyUntil, isNotNull);
      expect(item.warrantyUntilKm, isNull);
      expect(item.hasWarranty, isTrue);
    });

    test('no warranty at all is not "zero warranty"', () {
      final item = MaintenanceRecordItem.fromJson(_item(name: 'Alinhamento'));

      expect(item.warrantyUntil, isNull);
      expect(item.warrantyUntilKm, isNull);
      expect(item.hasWarranty, isFalse);
    });
  });
}

const _recordId = '11111111-1111-7111-8111-111111111111';
const _vehicleId = '22222222-2222-7222-8222-222222222222';
const _itemId = '33333333-3333-7333-8333-333333333333';
const _catalogueId = '44444444-4444-7444-8444-444444444444';

Map<String, dynamic> _record({
  String kind = 'performed',
  List<Map<String, dynamic>>? items,
}) {
  return {
    'id': _recordId,
    'vehicle_id': _vehicleId,
    'occurred_on': '2026-08-10',
    'mileage_km': 98200,
    'kind': kind,
    'workshop_name': 'Auto Center Silva',
    'total_cost_cents': 42000,
    'notes': 'Óleo sintético',
    'items': items ?? [_item(name: 'Troca de óleo do motor')],
    'created_at': '2026-08-10T14:00:00Z',
    'updated_at': '2026-08-10T14:00:00Z',
  };
}

Map<String, dynamic> _item({
  required String name,
  int? warrantyMonths,
  int? warrantyKm,
  String? warrantyUntil,
  int? warrantyUntilKm,
}) {
  return {
    'id': _itemId,
    'maintenance_item_id': _catalogueId,
    'item_slug': 'troca_oleo',
    'item_name': name,
    'description': null,
    'part_brand': null,
    'cost_cents': null,
    'warranty_months': warrantyMonths,
    'warranty_km': warrantyKm,
    'warranty_until': warrantyUntil,
    'warranty_until_km': warrantyUntilKm,
  };
}
