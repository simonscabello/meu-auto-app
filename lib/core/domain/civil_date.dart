/// A calendar day without a time or a time zone.
///
/// Never build a [CivilDate] by `DateTime.parse(s)` followed by `.toLocal()`.
/// A civil date on the wire is `YYYY-MM-DD`, not an instant. Parsed as UTC
/// midnight and converted to local time it becomes the previous day in every
/// time zone west of Greenwich — which is all of Brazil. Split the string
/// into year, month and day integers instead.
///
/// Calendar arithmetic (adding months, computing due dates) lives on the
/// server. This type only stores and compares a day.
final class CivilDate implements Comparable<CivilDate> {
  const CivilDate(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  static final _pattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  factory CivilDate.parse(String value) {
    final match = _pattern.firstMatch(value);
    if (match == null) {
      throw FormatException(
        'Invalid civil date "$value"; expected exactly YYYY-MM-DD',
      );
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    // DateTime.utc is used only to reject impossible calendar days (Feb 30).
    // Both sides are UTC, so this is not a timezone conversion.
    final probe = DateTime.utc(year, month, day);
    if (probe.year != year || probe.month != month || probe.day != day) {
      throw FormatException('Invalid civil date "$value"');
    }
    return CivilDate(year, month, day);
  }

  static CivilDate? tryParse(String? value) {
    if (value == null) return null;
    try {
      return CivilDate.parse(value);
    } on FormatException {
      return null;
    }
  }

  /// Today's date on the device clock. [DateTime.now] is an instant; taking
  /// its local Y/M/D is the correct way to ask "what day is it here".
  factory CivilDate.todayLocal() {
    final now = DateTime.now();
    return CivilDate(now.year, now.month, now.day);
  }

  String toJson() {
    final mm = month.toString().padLeft(2, '0');
    final dd = day.toString().padLeft(2, '0');
    return '$year-$mm-$dd';
  }

  /// Whole calendar days from this date until [other]. Negative if [other]
  /// is earlier. Counted on the UTC civil timeline so a timezone never
  /// shifts the day.
  int daysUntil(CivilDate other) {
    final start = DateTime.utc(year, month, day);
    final end = DateTime.utc(other.year, other.month, other.day);
    return end.difference(start).inDays;
  }

  @override
  int compareTo(CivilDate other) {
    final byYear = year.compareTo(other.year);
    if (byYear != 0) return byYear;
    final byMonth = month.compareTo(other.month);
    if (byMonth != 0) return byMonth;
    return day.compareTo(other.day);
  }

  bool operator <(CivilDate other) => compareTo(other) < 0;
  bool operator <=(CivilDate other) => compareTo(other) <= 0;
  bool operator >(CivilDate other) => compareTo(other) > 0;
  bool operator >=(CivilDate other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is CivilDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toJson();
}
