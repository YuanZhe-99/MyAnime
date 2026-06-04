/// Japan Standard Time (UTC+9) utilities.
class JstTime {
  /// Purpose: Prevent direct instantiation and expose only static members.
  /// Inputs: None.
  /// Returns: A new `JstTime._` instance.
  /// Side effects: Implementation-dependent.
  /// Notes: Implementations should preserve this contract.
  JstTime._();

  /// Purpose: Return the current time converted to Japan Standard Time.
  /// Inputs: None.
  /// Returns: `DateTime`.
  /// Side effects: None.
  /// Notes: None.
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

  /// Purpose: Return today's JST calendar date with the time zeroed.
  /// Inputs: None.
  /// Returns: `DateTime`.
  /// Side effects: None.
  /// Notes: None.
  static DateTime today() {
    final n = now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Purpose: Return today's local calendar date with the time zeroed.
  /// Inputs: None.
  /// Returns: `DateTime`.
  /// Side effects: None.
  /// Notes: Use this only for UI date grids that explicitly follow the device timezone.
  static DateTime localToday() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Purpose: Convert a Japan-time `DateTime` into the device local timezone.
  /// Inputs: `jstTime`.
  /// Returns: `DateTime`.
  /// Side effects: None.
  /// Notes: The input is treated as a wall-clock Japan time even when its `isUtc` flag is false.
  static DateTime toLocal(DateTime jstTime) {
    final utc = DateTime.utc(
      jstTime.year,
      jstTime.month,
      jstTime.day,
      jstTime.hour - 9,
      jstTime.minute,
      jstTime.second,
      jstTime.millisecond,
      jstTime.microsecond,
    );
    return utc.toLocal();
  }
}
