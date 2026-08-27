import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/features/obligation/domain/obligation.dart';
import 'package:meu_auto/features/obligation/domain/obligation_copy.dart';
import 'package:meu_auto/features/obligation/domain/seguro.dart';

void main() {
  setUpAll(ensurePtBrFormatting);

  group('obligationStatusPhrase', () {
    test('paid on time reads as em dia', () {
      expect(obligationStatusPhrase(_obligation()), 'Em dia');
    });

    test('paid late uses remaining_days from the server', () {
      expect(
        obligationStatusPhrase(_obligation(remainingDays: -3)),
        'pago com 3 dias de atraso',
      );
      expect(
        obligationStatusPhrase(_obligation(remainingDays: -1)),
        'pago com 1 dia de atraso',
      );
    });

    test('unpaid statuses reuse remainingDaysPhrase', () {
      expect(
        obligationStatusPhrase(
          _obligation(status: ObligationStatus.venceEmBreve, remainingDays: 0),
        ),
        'vence hoje',
      );
      expect(
        obligationStatusPhrase(
          _obligation(status: ObligationStatus.vencido, remainingDays: -10),
        ),
        'venceu há 10 dias',
      );
      expect(
        obligationStatusPhrase(
          _obligation(status: ObligationStatus.pendente, remainingDays: 80),
        ),
        'faltam cerca de 3 meses',
      );
    });

    test('unknown status produces no phrase', () {
      expect(
        obligationStatusPhrase(
          _obligation(status: ObligationStatus.desconhecido),
        ),
        isEmpty,
      );
    });
  });

  test('obligationTitle and conflict copy name the kind and year', () {
    expect(obligationTitle(_obligation()), 'IPVA 2026');
    expect(
      obligationTitle(_obligation(kind: ObligationKind.licenciamento)),
      'Licenciamento 2026',
    );
    expect(
      obligationConflictMessage(kind: ObligationKind.ipva, year: 2026),
      'Já existe um IPVA de 2026 para este carro.',
    );
    expect(
      obligationConflictMessage(kind: ObligationKind.licenciamento, year: 2026),
      'Já existe um licenciamento de 2026 para este carro.',
    );
  });

  group('seguroStatusPhrase', () {
    test('futuro counts days until the start, not the end', () {
      expect(
        seguroStatusPhrase(
          _seguro(status: SeguroStatus.futuro, remainingDays: 12),
        ),
        'Começa em 12 dias',
      );
      expect(
        seguroStatusPhrase(
          _seguro(status: SeguroStatus.futuro, remainingDays: 1),
        ),
        'Começa amanhã',
      );
      expect(
        seguroStatusPhrase(
          _seguro(status: SeguroStatus.futuro, remainingDays: 0),
        ),
        'Começa hoje',
      );
    });

    test('vigente has no extra phrase', () {
      expect(seguroStatusPhrase(_seguro()), isEmpty);
    });

    test('due soon talks about the end of cover', () {
      expect(
        seguroStatusPhrase(
          _seguro(status: SeguroStatus.venceEmBreve, remainingDays: 8),
        ),
        'faltam 8 dias',
      );
    });

    test('expired says the car is uncovered, without alarm', () {
      expect(
        seguroStatusPhrase(
          _seguro(status: SeguroStatus.vencido, remainingDays: -4),
        ),
        'O carro está sem cobertura.',
      );
    });
  });
}

Obligation _obligation({
  ObligationKind kind = ObligationKind.ipva,
  ObligationStatus status = ObligationStatus.pago,
  int remainingDays = 20,
}) {
  return Obligation(
    id: 'o1',
    vehicleId: 'v1',
    kind: kind,
    referenceYear: 2026,
    dueOn: const CivilDate(2026, 3, 15),
    amountCents: const Money.fromCents(184237),
    status: status,
    remainingDays: remainingDays,
    createdAt: DateTime.utc(2026, 1, 10),
    updatedAt: DateTime.utc(2026, 1, 10),
  );
}

Seguro _seguro({
  SeguroStatus status = SeguroStatus.vigente,
  int remainingDays = 136,
}) {
  return Seguro(
    id: 's1',
    vehicleId: 'v1',
    insurerName: 'Porto Seguro',
    startsOn: const CivilDate(2026, 1, 10),
    endsOn: const CivilDate(2027, 1, 10),
    status: status,
    remainingDays: remainingDays,
    createdAt: DateTime.utc(2026, 1, 10),
    updatedAt: DateTime.utc(2026, 1, 10),
  );
}
