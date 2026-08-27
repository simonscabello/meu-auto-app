import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/features/vehicle/domain/selected_vehicle.dart';

void main() {
  group('resolveSelectedVehicleId', () {
    test('returns null when the list is empty', () {
      expect(
        resolveSelectedVehicleId(vehicleIds: const [], storedId: 'gone'),
        isNull,
      );
      expect(
        resolveSelectedVehicleId(vehicleIds: const [], storedId: null),
        isNull,
      );
    });

    test(
      'falls back to the first id when the stored id is no longer in the list',
      () {
        expect(
          resolveSelectedVehicleId(
            vehicleIds: const ['a', 'b'],
            storedId: 'gone',
          ),
          'a',
        );
      },
    );

    test('keeps the stored id when it is still in the list', () {
      expect(
        resolveSelectedVehicleId(
          vehicleIds: const ['a', 'b', 'c'],
          storedId: 'b',
        ),
        'b',
      );
    });

    test('uses the first id when nothing is stored', () {
      expect(
        resolveSelectedVehicleId(vehicleIds: const ['a', 'b'], storedId: null),
        'a',
      );
    });
  });
}
