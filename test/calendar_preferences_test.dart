import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/shared/utils/calendar_preferences.dart';
import 'package:my_anime/shared/utils/jst_time.dart';

/// Purpose: Run calendar preference and time conversion unit tests.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: Tests are timezone-safe by comparing converted instants in UTC.
void main() {
  test('week start defaults to Sunday and orders weekdays from start', () {
    expect(normalizeWeekStartDay(null), DateTime.sunday);
    expect(normalizeWeekStartDay(0), DateTime.sunday);
    expect(weekdaySequence(DateTime.sunday), [7, 1, 2, 3, 4, 5, 6]);
  });

  test('converts wall-clock JST timestamps to local instants', () {
    final local = JstTime.toLocal(DateTime(2026, 1, 2));

    expect(local.toUtc().toIso8601String(), '2026-01-01T15:00:00.000Z');
  });
}
