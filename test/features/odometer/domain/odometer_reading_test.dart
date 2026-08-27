import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/features/odometer/domain/odometer_reading.dart';

void main() {
  test('fromJson reads a manual reading', () {
    final reading = OdometerReading.fromJson({
      'id': '11111111-1111-7111-8111-111111111111',
      'vehicle_id': '22222222-2222-7222-8222-222222222222',
      'mileage_km': 48320,
      'occurred_on': '2026-08-10',
      'source': 'manual',
      'notes': null,
      'created_at': '2026-08-10T14:32:00Z',
    });

    expect(reading.mileageKm, 48320);
    expect(reading.occurredOn, const CivilDate(2026, 8, 10));
    expect(reading.source, OdometerSource.manual);
    expect(reading.notes, isNull);
  });

  test('occurred_on is a civil date and does not shift a day', () {
    // The classic bug: parsing a date as UTC midnight and converting to local
    // time turns it into the day before, everywhere west of Greenwich.
    final reading = OdometerReading.fromJson(_json(occurredOn: '2026-01-01'));
    expect(reading.occurredOn, const CivilDate(2026, 1, 1));
  });

  test('an unknown source falls back instead of throwing', () {
    final reading = OdometerReading.fromJson(_json(source: 'telemetria'));
    expect(reading.source, OdometerSource.desconhecido);
  });

  test('a missing source falls back too', () {
    final reading = OdometerReading.fromJson(_json(source: null));
    expect(reading.source, OdometerSource.desconhecido);
  });

  group('what the owner may delete', () {
    test('their own entries', () {
      expect(OdometerSource.manual.isOwnEntry, isTrue);
      expect(OdometerSource.correction.isOwnEntry, isTrue);
    });

    test('but not a reading another module wrote', () {
      expect(OdometerSource.maintenance.isOwnEntry, isFalse);
      expect(OdometerSource.abastecimento.isOwnEntry, isFalse);
    });

    test('nor one whose origin the app does not recognise', () {
      expect(OdometerSource.desconhecido.isOwnEntry, isFalse);
    });
  });

  group('origin label', () {
    test('a manual reading needs no explanation on screen', () {
      expect(OdometerSource.manual.originLabel, isNull);
      expect(OdometerSource.desconhecido.originLabel, isNull);
    });

    test('a reading from another event says where it came from', () {
      expect(
        OdometerSource.maintenance.originLabel,
        'Registrado junto com uma manutenção',
      );
      expect(
        OdometerSource.abastecimento.originLabel,
        'Registrado junto com um abastecimento',
      );
    });
  });
}

Map<String, dynamic> _json({
  String occurredOn = '2026-08-10',
  String? source = 'manual',
}) {
  return {
    'id': '11111111-1111-7111-8111-111111111111',
    'vehicle_id': '22222222-2222-7222-8222-222222222222',
    'mileage_km': 48320,
    'occurred_on': occurredOn,
    'source': source,
    'created_at': '2026-08-10T14:32:00Z',
  };
}
