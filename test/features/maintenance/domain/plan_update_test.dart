import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/features/maintenance/domain/plan_update.dart';

void main() {
  test('clear_intervals travels alone', () {
    expect(const PlanUpdate.clearIntervals().toJson(), {
      'clear_intervals': true,
    });
  });

  test('an interval patch never includes the clear flag', () {
    final body = const PlanUpdate.intervals(
      intervalKm: 8000,
      intervalMonths: 12,
      alertKm: 800,
      alertDays: 15,
    ).toJson();

    expect(body.containsKey('clear_intervals'), isFalse);
    expect(body['interval_km'], 8000);
    expect(body['interval_months'], 12);
    expect(body.containsKey('interval_days'), isFalse);
    expect(body['alert_km'], 800);
    expect(body['alert_days'], 15);
  });
}
