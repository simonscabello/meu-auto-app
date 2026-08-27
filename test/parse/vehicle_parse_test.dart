import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/network/api_envelope.dart';
import 'package:meu_auto/features/vehicle/domain/vehicle.dart';

import '../support/fixtures.dart';
import '../support/parse.dart';

void main() {
  final complete = loadFixture('vehicle_get.json');
  final nulls = loadFixture('vehicle_get_nulls.json');

  group('Vehicle.fromJson', () {
    test('parses a complete vehicle, including unused catalog keys', () {
      final vehicle = Vehicle.fromJson(complete);

      expect(vehicle.id, '22222222-2222-7222-8222-222222222222');
      expect(vehicle.vehicleType, VehicleType.car);
      expect(vehicle.brand, 'Fiat');
      expect(vehicle.model, 'Argo');
      expect(vehicle.version, '1.0 Drive');
      expect(vehicle.fuelType, FuelType.flex);
      expect(vehicle.currentMileageKm, 45200);
      expect(vehicle.currentMileageAt, const CivilDate(2026, 8, 20));
      expect(vehicle.nickname, 'Argolino');
    });

    test('parses when every optional is null', () {
      final vehicle = Vehicle.fromJson(nulls);

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
      expect(vehicle.currentMileageAt, isNull);
      expect(vehicle.currentMileageKm, 0);
    });

    test('unknown vehicle_type and fuel_type fall back without throwing', () {
      final vehicle = Vehicle.fromJson({
        ...complete,
        'vehicle_type': 'hovercraft',
        'fuel_type': 'hidrogenio',
      });

      expect(vehicle.vehicleType, VehicleType.desconhecido);
      expect(vehicle.fuelType, FuelType.desconhecido);
    });

    test('fails clearly when a required field is missing', () {
      expect(
        () => Vehicle.fromJson(withoutKey(complete, 'id')),
        throwsMissingRequired,
      );
      expect(
        () => Vehicle.fromJson(withoutKey(complete, 'brand')),
        throwsMissingRequired,
      );
      expect(
        () => Vehicle.fromJson(withoutKey(complete, 'current_mileage_km')),
        throwsMissingRequired,
      );
    });

    test('a list envelope parses each vehicle', () {
      final vehicles = listOf(
        loadFixture('vehicles_list.json'),
        Vehicle.fromJson,
      );
      expect(vehicles, hasLength(1));
      expect(vehicles.single.plate, 'ABC1D23');
    });
  });
}
