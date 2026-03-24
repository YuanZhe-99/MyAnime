/// Japan Standard Time (UTC+9) utilities.
class JstTime {
  JstTime._();

  /// Current time in JST.
  static DateTime now() {
    final utc = DateTime.now().toUtc();
    return DateTime(
      utc.year,
      utc.month,
      utc.day,
      utc.hour + 9,
      utc.minute,
      utc.second,
      utc.millisecond,
    );
  }

  /// Today's date in JST (time-of-day zeroed).
  static DateTime today() {
    final n = now();
    return DateTime(n.year, n.month, n.day);
  }
}
