import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/features/obligation/domain/obligation.dart';

void main() {
  group('Obligation.fromJson', () {
    test('parses a full unpaid IPVA', () {
      final obligation = Obligation.fromJson(_json());

      expect(obligation.id, _id);
      expect(obligation.vehicleId, _vehicleId);
      expect(obligation.kind, ObligationKind.ipva);
      expect(obligation.referenceYear, 2026);
      expect(obligation.dueOn, const CivilDate(2026, 3, 15));
      expect(obligation.amountCents, const Money.fromCents(184237));
      expect(obligation.paidOn, isNull);
      expect(obligation.paidAmountCents, isNull);
      expect(obligation.notes, isNull);
      expect(obligation.status, ObligationStatus.pendente);
      expect(obligation.remainingDays, 200);
      expect(obligation.isPaid, isFalse);
    });

    test(
      'keeps amount and payment null rather than turning them into zero',
      () {
        final obligation = Obligation.fromJson(
          _json(amountCents: null, paidAmountCents: null, status: 'vencido'),
        );

        expect(obligation.amountCents, isNull);
        expect(obligation.paidAmountCents, isNull);
        expect(obligation.status, ObligationStatus.vencido);
      },
    );

    test('reads a payment that differs from the predicted amount', () {
      final obligation = Obligation.fromJson(
        _json(
          status: 'pago',
          paidOn: '2026-03-18',
          paidAmountCents: 190000,
          remainingDays: -3,
        ),
      );

      expect(obligation.status, ObligationStatus.pago);
      expect(obligation.paidOn, const CivilDate(2026, 3, 18));
      expect(obligation.paidAmountCents, const Money.fromCents(190000));
      expect(obligation.remainingDays, -3);
      expect(obligation.isPaid, isTrue);
    });

    test('unknown kind and status fall back instead of throwing', () {
      final obligation = Obligation.fromJson(
        _json(kind: 'iptu', status: 'parcelado'),
      );

      expect(obligation.kind, ObligationKind.desconhecido);
      expect(obligation.status, ObligationStatus.desconhecido);
      expect(obligation.kind.wire, isEmpty);
      expect(obligation.status.wire, isEmpty);
    });
  });
}

const _id = 'aaaaaaaa-aaaa-7aaa-8aaa-aaaaaaaaaaaa';
const _vehicleId = '11111111-1111-7111-8111-111111111111';

Map<String, dynamic> _json({
  String kind = 'ipva',
  String status = 'pendente',
  int? amountCents = 184237,
  String? paidOn,
  int? paidAmountCents,
  int remainingDays = 200,
}) {
  return {
    'id': _id,
    'vehicle_id': _vehicleId,
    'kind': kind,
    'reference_year': 2026,
    'due_on': '2026-03-15',
    'amount_cents': amountCents,
    'paid_on': paidOn,
    'paid_amount_cents': paidAmountCents,
    'notes': null,
    'status': status,
    'remaining_days': remainingDays,
    'created_at': '2026-01-10T12:00:00Z',
    'updated_at': '2026-01-10T12:00:00Z',
  };
}
