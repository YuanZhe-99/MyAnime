enum HomeCalendarLayout { local, japanese }

enum HomeCalendarTimeBasis { jst, local }

const defaultWeekStartDay = DateTime.sunday;

/// Purpose: Return a valid weekday to use as the app calendar week start.
/// Inputs: `weekday`.
/// Returns: `int`.
/// Side effects: None.
/// Notes: Weekday values use Dart's Monday=1 through Sunday=7 numbering; invalid values default to Sunday.
int normalizeWeekStartDay(int? weekday) {
  if (weekday == null ||
      weekday < DateTime.monday ||
      weekday > DateTime.sunday) {
    return defaultWeekStartDay;
  }
  return weekday;
}

/// Purpose: Return weekdays ordered from the configured week start.
/// Inputs: `weekStartDay`.
/// Returns: `List<int>`.
/// Side effects: None.
/// Notes: Weekday values use Dart's Monday=1 through Sunday=7 numbering.
List<int> weekdaySequence(int weekStartDay) {
  final start = normalizeWeekStartDay(weekStartDay);
  return [
    for (var offset = 0; offset < 7; offset++) ((start - 1 + offset) % 7) + 1,
  ];
}
