import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';

void main() {
  test('a catalogue item with every field', () {
    final item = MaintenanceItem.fromJson({
      'id': _id,
      'slug': 'troca_oleo',
      'name': 'Troca de óleo do motor',
      'kind': 'maintenance',
      'vehicle_type': 'car',
      'is_custom': false,
      'default_interval_km': 10000,
      'default_interval_months': 12,
      'default_interval_days': null,
    });

    expect(item.id, _id);
    expect(item.slug, 'troca_oleo');
    expect(item.name, 'Troca de óleo do motor');
    expect(item.kind, MaintenanceItemKind.maintenance);
    expect(item.vehicleType, 'car');
    expect(item.isCustom, isFalse);
    expect(item.defaultIntervalKm, 10000);
    expect(item.defaultIntervalMonths, 12);
    expect(item.defaultIntervalDays, isNull);
  });

  test('every optional interval may be absent', () {
    final item = MaintenanceItem.fromJson({
      'id': _id,
      'slug': 'personalizada',
      'name': 'Manutenção personalizada',
      'kind': 'maintenance',
      'vehicle_type': 'car',
      'is_custom': false,
    });

    expect(item.defaultIntervalKm, isNull);
    expect(item.defaultIntervalMonths, isNull);
    expect(item.defaultIntervalDays, isNull);
  });

  test('a care item is distinct from maintenance', () {
    final item = MaintenanceItem.fromJson({
      'id': _id,
      'slug': 'calibrar_pneus',
      'name': 'Calibrar os pneus',
      'kind': 'care',
      'vehicle_type': 'all',
      'is_custom': false,
      'default_interval_days': 15,
    });

    expect(item.kind, MaintenanceItemKind.care);
    expect(item.vehicleType, 'all');
  });

  test('an unknown kind falls back instead of throwing', () {
    final item = MaintenanceItem.fromJson({
      'id': _id,
      'slug': 'algo_novo',
      'name': 'Algo novo',
      'kind': 'inspection',
      'vehicle_type': 'car',
      'is_custom': false,
    });

    expect(item.kind, MaintenanceItemKind.desconhecido);
  });

  test('a custom item is flagged', () {
    final item = MaintenanceItem.fromJson({
      'id': _id,
      'slug': 'troca_kit_embreagem',
      'name': 'Kit de embreagem',
      'kind': 'maintenance',
      'vehicle_type': 'all',
      'is_custom': true,
    });

    expect(item.isCustom, isTrue);
  });
}

const _id = '55555555-5555-7555-8555-555555555555';
