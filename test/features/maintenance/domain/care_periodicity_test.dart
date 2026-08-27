import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/features/maintenance/domain/care_periodicity.dart';
import 'package:meu_auto/features/maintenance/domain/plan_update.dart';

void main() {
  test('recommended uses the catalogue default, not a hardcoded 15', () {
    final body = carePeriodicityUpdate(
      choice: CarePeriodicityChoice.recommended,
      recommendedDays: 21,
    ).toJson();

    expect(body['interval_days'], 21);
    expect(body.containsKey('alert_km'), isFalse);
    expect(body.containsKey('alert_days'), isFalse);
  });

  test('the named presets map to days and omit alerts', () {
    expect(
      carePeriodicityUpdate(choice: CarePeriodicityChoice.weekly).toJson(),
      {'interval_days': 7},
    );
    expect(
      carePeriodicityUpdate(
        choice: CarePeriodicityChoice.everyFifteenDays,
      ).toJson(),
      {'interval_days': 15},
    );
    expect(
      carePeriodicityUpdate(choice: CarePeriodicityChoice.monthly).toJson(),
      {'interval_days': 30},
    );
  });

  test('custom sends the typed number as interval_days', () {
    expect(
      carePeriodicityUpdate(
        choice: CarePeriodicityChoice.custom,
        customDays: 10,
      ).toJson(),
      {'interval_days': 10},
    );
  });

  test('not reminding clears the three intervals and does not deactivate', () {
    final body = carePeriodicityUpdate(
      choice: CarePeriodicityChoice.dontRemind,
    ).toJson();

    expect(body, const PlanUpdate.clearIntervals().toJson());
    expect(body['clear_intervals'], isTrue);
    expect(body['interval_km'], isNull);
    expect(body['interval_months'], isNull);
    expect(body['interval_days'], isNull);
    expect(body.containsKey('is_active'), isFalse);
  });
}
