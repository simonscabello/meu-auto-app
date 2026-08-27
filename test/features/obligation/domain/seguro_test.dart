import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/features/obligation/domain/seguro.dart';

void main() {
  group('Seguro.fromJson', () {
    test('parses a full policy', () {
      final seguro = Seguro.fromJson(_json());

      expect(seguro.id, _id);
      expect(seguro.vehicleId, _vehicleId);
      expect(seguro.insurerName, 'Porto Seguro');
      expect(seguro.policyNumber, '12345');
      expect(seguro.startsOn, const CivilDate(2026, 1, 10));
      expect(seguro.endsOn, const CivilDate(2027, 1, 10));
      expect(seguro.premiumCents, const Money.fromCents(250000));
      expect(seguro.emergencyPhone, '0800 727 0800');
      expect(seguro.brokerName, 'Ana');
      expect(seguro.brokerPhone, '11999999999');
      expect(seguro.status, SeguroStatus.vigente);
      expect(seguro.remainingDays, 136);
    });

    test('keeps optional fields null', () {
      final seguro = Seguro.fromJson(
        _json(
          policyNumber: null,
          premiumCents: null,
          emergencyPhone: null,
          brokerName: null,
          brokerPhone: null,
          notes: null,
        ),
      );

      expect(seguro.policyNumber, isNull);
      expect(seguro.premiumCents, isNull);
      expect(seguro.emergencyPhone, isNull);
      expect(seguro.brokerName, isNull);
      expect(seguro.brokerPhone, isNull);
      expect(seguro.notes, isNull);
    });

    test('unknown status falls back instead of throwing', () {
      final seguro = Seguro.fromJson(_json(status: 'suspenso'));

      expect(seguro.status, SeguroStatus.desconhecido);
      expect(seguro.status.wire, isEmpty);
    });
  });
}

const _id = 'bbbbbbbb-bbbb-7bbb-8bbb-bbbbbbbbbbbb';
const _vehicleId = '11111111-1111-7111-8111-111111111111';

Map<String, dynamic> _json({
  String status = 'vigente',
  String? policyNumber = '12345',
  int? premiumCents = 250000,
  String? emergencyPhone = '0800 727 0800',
  String? brokerName = 'Ana',
  String? brokerPhone = '11999999999',
  String? notes,
}) {
  return {
    'id': _id,
    'vehicle_id': _vehicleId,
    'insurer_name': 'Porto Seguro',
    'policy_number': policyNumber,
    'starts_on': '2026-01-10',
    'ends_on': '2027-01-10',
    'premium_cents': premiumCents,
    'emergency_phone': emergencyPhone,
    'broker_name': brokerName,
    'broker_phone': brokerPhone,
    'notes': notes,
    'status': status,
    'remaining_days': 136,
    'created_at': '2026-01-10T12:00:00Z',
    'updated_at': '2026-01-10T12:00:00Z',
  };
}
