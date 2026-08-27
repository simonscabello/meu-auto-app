import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/formatters.dart';

void main() {
  setUpAll(ensurePtBrFormatting);

  test("CivilDate.parse('2026-08-10') returns day 10 and round-trips", () {
    final date = CivilDate.parse('2026-08-10');
    expect(date.year, 2026);
    expect(date.month, 8);
    expect(date.day, 10);
    expect(date.toJson(), '2026-08-10');
  });

  test('civil date near midnight does not shift day when formatted', () {
    final date = CivilDate.parse('2026-08-10');
    expect(formatCivilDate(date), '10/08/2026');
    expect(formatCivilDateLong(date), '10 de agosto de 2026');
  });

  test('parse rejects anything other than YYYY-MM-DD', () {
    expect(() => CivilDate.parse('2026-8-10'), throwsFormatException);
    expect(
      () => CivilDate.parse('2026-08-10T00:00:00Z'),
      throwsFormatException,
    );
    expect(() => CivilDate.parse('10/08/2026'), throwsFormatException);
    expect(() => CivilDate.parse('2026-02-30'), throwsFormatException);
  });

  test('tryParse returns null for null, empty or invalid input', () {
    expect(CivilDate.tryParse(null), isNull);
    expect(CivilDate.tryParse(''), isNull);
    expect(CivilDate.tryParse('nope'), isNull);
    expect(CivilDate.tryParse('2026-08-10'), const CivilDate(2026, 8, 10));
  });

  test('todayLocal uses the device local calendar date', () {
    final now = DateTime.now();
    final today = CivilDate.todayLocal();
    expect(today.year, now.year);
    expect(today.month, now.month);
    expect(today.day, now.day);
  });

  test('compareTo, ==, hashCode and daysUntil follow the calendar', () {
    const a = CivilDate(2026, 8, 10);
    const b = CivilDate(2026, 8, 12);
    const same = CivilDate(2026, 8, 10);

    expect(a == same, isTrue);
    expect(a.hashCode, same.hashCode);
    expect(a.compareTo(b), lessThan(0));
    expect(b.compareTo(a), greaterThan(0));
    expect(a.compareTo(same), 0);
    expect(a < b, isTrue);
    expect(b > a, isTrue);
    expect(a.daysUntil(b), 2);
    expect(b.daysUntil(a), -2);
    expect(a.daysUntil(same), 0);
  });

  test('month rollover and leap day parse, and toJson round-trips', () {
    expect(CivilDate.parse('2026-01-31').toJson(), '2026-01-31');
    expect(CivilDate.parse('2026-03-01').toJson(), '2026-03-01');
    expect(CivilDate.parse('2024-02-29').toJson(), '2024-02-29');
    expect(() => CivilDate.parse('2025-02-29'), throwsFormatException);

    const jan31 = CivilDate(2026, 1, 31);
    const mar1 = CivilDate(2026, 3, 1);
    expect(jan31.daysUntil(mar1), 29);
  });
}
