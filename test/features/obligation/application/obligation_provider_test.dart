import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/features/obligation/application/obligation_provider.dart';
import 'package:meu_auto/features/obligation/domain/obligation.dart';
import 'package:meu_auto/core/domain/civil_date.dart';

void main() {
  const vehicleId = '11111111-1111-7111-8111-111111111111';

  test('obligationsProvider returns the list', () async {
    final container = ProviderContainer(
      overrides: [
        obligationsProvider(vehicleId).overrideWith((ref) async => [_sample]),
      ],
    );
    addTearDown(container.dispose);

    final list = await container.read(obligationsProvider(vehicleId).future);
    expect(list, hasLength(1));
    expect(list.single.kind, ObligationKind.ipva);
  });

  test('obligationsProvider surfaces an error', () async {
    final container = ProviderContainer(
      overrides: [
        obligationsProvider(
          vehicleId,
        ).overrideWith((ref) async => throw const ApiFailure.semConexao()),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(obligationsProvider(vehicleId).future),
      throwsA(isA<ApiFailure>()),
    );
  });

  test('invalidating the family refetches', () async {
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        obligationsProvider(vehicleId).overrideWith((ref) async {
          calls++;
          return const <Obligation>[];
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(obligationsProvider(vehicleId).future);
    container.invalidate(obligationsProvider(vehicleId));
    await container.read(obligationsProvider(vehicleId).future);

    expect(calls, 2);
  });
}

final _sample = Obligation(
  id: 'o1',
  vehicleId: '11111111-1111-7111-8111-111111111111',
  kind: ObligationKind.ipva,
  referenceYear: 2026,
  dueOn: const CivilDate(2026, 3, 15),
  status: ObligationStatus.pendente,
  remainingDays: 200,
  createdAt: DateTime.utc(2026, 1, 10),
  updatedAt: DateTime.utc(2026, 1, 10),
);
