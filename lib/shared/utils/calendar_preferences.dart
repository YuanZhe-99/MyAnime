enum HomeCalendarLayout { local, japanese }

enum HomeCalendarTimeBasis { jst, local }

const defaultWeekStartDay = DateTime.sunday;

const homeCalendarMaxWidth = 560.0;

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

/// Purpose: Return a home calendar weekday header height that fits its label text.
/// Inputs: `labelLineHeight`.
/// Returns: `double`.
/// Side effects: None.
/// Notes: `labelLineHeight` is the font-scaled line height of one weekday label; the result stays
/// well above `table_calendar`'s 16.0 default, which clips CJK labels.
double homeCalendarDaysOfWeekHeight(double labelLineHeight) {
  return (labelLineHeight + 8).clamp(24.0, 64.0);
}

/// Purpose: Return the home calendar day-cell row height for the current viewport.
/// Inputs: `viewportHeight`, `daysOfWeekHeight`.
/// Returns: `double`.
/// Side effects: None.
/// Notes: Keeps the roomy 52.0 rows on ordinary portrait viewports and shrinks toward 34.0 on
/// short landscape or square viewports so a six-week month grid still fits above the episode list.
double homeCalendarRowHeight(double viewportHeight, double daysOfWeekHeight) {
  final gridBudget = (viewportHeight * 0.55) - daysOfWeekHeight;
  return (gridBudget / 6).clamp(34.0, 52.0);
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
