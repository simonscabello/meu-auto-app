import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/features/notification/domain/push_tap.dart';

/// A reminder names a car, and — when it is about one item — which one, in
/// the alerts' own terms. Where that opens is the app's map, the same the
/// alerts list uses.
void main() {
  test('one item opens that item', () {
    for (final (type, route) in [
      ('obligation', AppRoutes.obligation('o1')),
      ('seguro', AppRoutes.seguro('o1')),
      ('maintenance_plan', AppRoutes.plan('o1')),
      ('maintenance_record', AppRoutes.maintenanceRecord('o1')),
    ]) {
      final tap = PushTap.fromData({
        'kind': 'reminder',
        'vehicle_id': 'v1',
        'reference_type': type,
        'reference_id': 'o1',
      });
      expect(tap?.vehicleId, 'v1', reason: type);
      expect(tap?.route, route, reason: type);
    }
  });

  test('several items open the list of the car’s alerts', () {
    final tap = PushTap.fromData({'kind': 'reminder', 'vehicle_id': 'v1'});

    expect(tap?.route, AppRoutes.alerts);
  });

  test('an item of a kind this build does not know opens the list', () {
    final tap = PushTap.fromData({
      'kind': 'reminder',
      'vehicle_id': 'v1',
      'reference_type': 'something_new',
      'reference_id': 'x',
    });

    expect(tap?.route, AppRoutes.alerts);
  });

  test('anything that is not a reminder opens nothing', () {
    expect(PushTap.fromData({'kind': 'other', 'vehicle_id': 'v1'}), isNull);
    expect(PushTap.fromData({'kind': 'reminder'}), isNull);
    expect(PushTap.fromData(const {}), isNull);
  });
}
