import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/features/vehicle/domain/vehicle.dart';

void main() {
  group('Vehicle.fromJson', () {
    test('reads required fields and keeps every optional as null', () {
      final vehicle = Vehicle.fromJson({
        'id': '11111111-1111-7111-8111-111111111111',
        'vehicle_type': 'car',
        'brand': 'Fiat',
        'model': 'Argo',
        'version': null,
        'manufacture_year': null,
        'model_year': null,
        'plate': null,
        'renavam': null,
        'chassis': null,
        'fuel_type': null,
        'color': null,
        'nickname': null,
        'fipe_code': null,
        'current_mileage_km': 0,
        'current_mileage_at': null,
        'created_at': '2026-08-26T16:15:00.000Z',
        'updated_at': '2026-08-26T16:15:00.000Z',
      });

      expect(vehicle.id, '11111111-1111-7111-8111-111111111111');
      expect(vehicle.vehicleType, VehicleType.car);
      expect(vehicle.brand, 'Fiat');
      expect(vehicle.model, 'Argo');
      expect(vehicle.version, isNull);
      expect(vehicle.manufactureYear, isNull);
      expect(vehicle.modelYear, isNull);
      expect(vehicle.plate, isNull);
      expect(vehicle.renavam, isNull);
      expect(vehicle.chassis, isNull);
      expect(vehicle.fuelType, isNull);
      expect(vehicle.color, isNull);
      expect(vehicle.nickname, isNull);
      expect(vehicle.fipeCode, isNull);
      expect(vehicle.catalogBrandId, isNull);
      expect(vehicle.catalogModelId, isNull);
      expect(vehicle.catalogModelYearId, isNull);
      expect(vehicle.isFromCatalog, isFalse);
      expect(vehicle.currentMileageKm, 0);
      expect(vehicle.currentMileageAt, isNull);
      expect(vehicle.refueling.supported, isTrue);
      expect(vehicle.refueling.fuelTypes, isEmpty);
      expect(
        vehicle.createdAt,
        DateTime.parse('2026-08-26T16:15:00.000Z').toLocal(),
      );
      expect(
        vehicle.updatedAt,
        DateTime.parse('2026-08-26T16:15:00.000Z').toLocal(),
      );
    });

    test('reads optionals and a civil currentMileageAt', () {
      final vehicle = Vehicle.fromJson({
        'id': '22222222-2222-7222-8222-222222222222',
        'vehicle_type': 'car',
        'brand': 'VW',
        'model': 'Gol',
        'version': '1.0',
        'manufacture_year': 2018,
        'model_year': 2019,
        'plate': 'ABC1D23',
        'renavam': '123456789',
        'chassis': '9BWZZZ377VT004251',
        'fuel_type': 'flex',
        'color': 'Prata',
        'nickname': 'Golzinho',
        'fipe_code': null,
        'current_mileage_km': 45200,
        'current_mileage_at': '2026-08-20',
        'created_at': '2026-08-26T16:15:00.000Z',
        'updated_at': '2026-08-26T16:15:00.000Z',
      });

      expect(vehicle.version, '1.0');
      expect(vehicle.manufactureYear, 2018);
      expect(vehicle.modelYear, 2019);
      expect(vehicle.plate, 'ABC1D23');
      expect(vehicle.fuelType, FuelType.flex);
      expect(vehicle.nickname, 'Golzinho');
      expect(vehicle.currentMileageAt, const CivilDate(2026, 8, 20));
    });

    test('unknown vehicle_type and fuel_type fall back to desconhecido', () {
      final vehicle = Vehicle.fromJson({
        'id': '33333333-3333-7333-8333-333333333333',
        'vehicle_type': 'hovercraft',
        'brand': 'X',
        'model': 'Y',
        'fuel_type': 'hidrogenio',
        'current_mileage_km': 1,
        'created_at': '2026-08-26T16:15:00.000Z',
        'updated_at': '2026-08-26T16:15:00.000Z',
      });

      expect(vehicle.vehicleType, VehicleType.desconhecido);
      expect(vehicle.fuelType, FuelType.desconhecido);
    });

    test('refueling comes from the server, never inferred from fuel_type', () {
      final electric = Vehicle.fromJson({
        'id': '44444444-4444-7444-8444-444444444444',
        'vehicle_type': 'car',
        'brand': 'BYD',
        'model': 'Dolphin',
        'fuel_type': 'eletrico',
        'current_mileage_km': 1200,
        'refueling': {'supported': false, 'fuel_types': <String>[]},
        'created_at': '2026-08-26T16:15:00.000Z',
        'updated_at': '2026-08-26T16:15:00.000Z',
      });

      expect(electric.fuelType, FuelType.eletrico);
      expect(electric.refueling.supported, isFalse);
      expect(electric.refueling.fuelTypes, isEmpty);
    });
  });

  group('normalizePlate', () {
    test('uppercases and strips hyphen from the old format', () {
      expect(normalizePlate('abc-1234'), 'ABC1234');
      expect(normalizePlate('ABC-1234'), 'ABC1234');
      expect(normalizePlate(' ABC 1234'), 'ABC1234');
    });

    test('uppercases and strips hyphen from the Mercosul format', () {
      expect(normalizePlate('abc-1d23'), 'ABC1D23');
      expect(normalizePlate('ABC1D23'), 'ABC1D23');
      expect(normalizePlate('abc1d23'), 'ABC1D23');
    });
  });

  group('displayName', () {
    test('uses nickname when present, otherwise brand and model', () {
      expect(_vehicle(nickname: 'Uno da firma').displayName, 'Uno da firma');
      expect(_vehicle(nickname: null).displayName, 'Fiat Argo');
      expect(_vehicle(nickname: '  ').displayName, 'Fiat Argo');
    });
  });
}

Vehicle _vehicle({String? nickname}) {
  return Vehicle(
    id: '11111111-1111-7111-8111-111111111111',
    vehicleType: VehicleType.car,
    brand: 'Fiat',
    model: 'Argo',
    nickname: nickname,
    fipeCode: null,
    currentMileageKm: 0,
    currentMileageAt: null,
    createdAt: DateTime.utc(2026, 8, 26),
    updatedAt: DateTime.utc(2026, 8, 26),
  );
}
