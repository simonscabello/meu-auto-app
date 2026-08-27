import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/network/api_envelope.dart';
import 'package:meu_auto/features/odometer/domain/odometer_reading.dart';
import 'package:meu_auto/features/vehicle/domain/vehicle.dart';

import '../support/fixtures.dart';
import '../support/parse.dart';

void main() {
  final created = loadFixture('odometer_create.json');
  final complete = asMap(created['reading']);
  final nulls = loadFixture('odometer_reading_nulls.json');

  group('OdometerReading.fromJson', () {
    test('parses a complete reading from the create response', () {
      final reading = OdometerReading.fromJson(complete);

      expect(reading.id, '11111111-1111-7111-8111-111111111111');
      expect(reading.vehicleId, '22222222-2222-7222-8222-222222222222');
      expect(reading.mileageKm, 48320);
      expect(reading.occurredOn, const CivilDate(2026, 8, 10));
      expect(reading.source, OdometerSource.manual);
      expect(reading.notes, 'Painel conferido');
    });

    test('parses when notes is null', () {
      final reading = OdometerReading.fromJson(nulls);
      expect(reading.notes, isNull);
      expect(reading.source, OdometerSource.manual);
    });

    test('unknown source falls back without throwing', () {
      final reading = OdometerReading.fromJson({
        ...complete,
        'source': 'telemetria',
      });
      expect(reading.source, OdometerSource.desconhecido);
    });

    test('fails clearly when a required field is missing', () {
      expect(
        () => OdometerReading.fromJson(withoutKey(complete, 'id')),
        throwsMissingRequired,
      );
      expect(
        () => OdometerReading.fromJson(withoutKey(complete, 'occurred_on')),
        throwsMissingRequired,
      );
      expect(
        () => OdometerReading.fromJson(withoutKey(complete, 'mileage_km')),
        throwsMissingRequired,
      );
    });
  });

  test('odometer create response carries the updated vehicle', () {
    final reading = OdometerReading.fromJson(complete);
    final vehicle = Vehicle.fromJson(asMap(created['vehicle']));

    expect(reading.mileageKm, 48320);
    expect(vehicle.currentMileageKm, 48320);
    expect(vehicle.currentMileageAt, const CivilDate(2026, 8, 10));
  });

  test('odometer list envelope keeps a null cursor as last page', () {
    final page = pageOf(
      loadFixture('odometer_list.json'),
      OdometerReading.fromJson,
    );
    expect(page.items, hasLength(1));
    expect(page.nextCursor, isNull);
  });
}
