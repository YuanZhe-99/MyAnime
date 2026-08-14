import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/shared/utils/calendar_preferences.dart';
import 'package:my_anime/shared/utils/jst_time.dart';
import 'package:table_calendar/table_calendar.dart';

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

  test('weekday header height always clears the clipping default', () {
    // table_calendar's own 16.0 default clips CJK weekday labels.
    expect(homeCalendarDaysOfWeekHeight(16), greaterThan(16));
    expect(homeCalendarDaysOfWeekHeight(0), 24);
    expect(homeCalendarDaysOfWeekHeight(16), 24);
    expect(homeCalendarDaysOfWeekHeight(24), 32);
    expect(homeCalendarDaysOfWeekHeight(1000), 64);
  });

  test('row height keeps full rows on tall viewports and compacts on short', () {
    expect(homeCalendarRowHeight(900, 24), 52);
    expect(homeCalendarRowHeight(640, 24), 52);
    expect(homeCalendarRowHeight(400, 24), 34);
    expect(homeCalendarRowHeight(0, 24), 34);

    final medium = homeCalendarRowHeight(500, 24);
    expect(medium, greaterThan(34));
    expect(medium, lessThan(52));
    expect(homeCalendarRowHeight(520, 24), greaterThan(medium));
  });

  testWidgets('calendar weekday labels are never vertically clipped', (
    tester,
  ) async {
    // Mirrors what home_page.dart feeds TableCalendar: Material 3 `bodySmall`
    // metrics under a large system font setting.
    const dowStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.33,
    );
    const scaler = TextScaler.linear(1.3);
    final daysOfWeekHeight = homeCalendarDaysOfWeekHeight(
      scaler.scale(dowStyle.fontSize!) * dowStyle.height!,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: scaler),
          child: Material(
            child: ListView(
              children: [
                TableCalendar<void>(
                  firstDay: DateTime.utc(2020),
                  lastDay: DateTime.utc(2030),
                  focusedDay: DateTime.utc(2026, 8, 14),
                  daysOfWeekHeight: daysOfWeekHeight,
                  rowHeight: homeCalendarRowHeight(1200, daysOfWeekHeight),
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekdayStyle: dowStyle,
                    weekendStyle: dowStyle,
                  ),
                  calendarBuilders: CalendarBuilders(
                    dowBuilder: (context, day) =>
                        const Center(child: Text('日', style: dowStyle)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final painter = TextPainter(
      text: const TextSpan(text: '日', style: dowStyle),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();

    // table_calendar's own 16.0 default is shorter than the label, which is
    // what used to cut the top and bottom off 日月火水木金土.
    expect(painter.height, greaterThan(16.0));
    expect(
      tester.getSize(find.text('日').first).height,
      greaterThanOrEqualTo(painter.height),
    );
  });

  test('converts wall-clock JST timestamps to local instants', () {
    final local = JstTime.toLocal(DateTime(2026, 1, 2));

    expect(local.toUtc().toIso8601String(), '2026-01-01T15:00:00.000Z');
  });
}
