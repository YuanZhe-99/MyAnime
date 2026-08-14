# lib/shared/utils/calendar_preferences.dart

Small shared utility module for calendar preferences and home-calendar geometry: the
`HomeCalendarLayout` and `HomeCalendarTimeBasis` enums, the `defaultWeekStartDay` and
`homeCalendarMaxWidth` constants, and four pure helper functions used by
`AppSettings`/`AppSettingsNotifier` (see
[../providers/app_settings.md](../providers/app_settings.md)), `AnimeStorage`, `home_page.dart`,
and `settings_page.dart` to normalize and enumerate weekday ordering and to size the home calendar
for the current viewport and text scale.

The module deliberately depends on nothing but `dart:core` — it holds no Flutter or
`table_calendar` imports — so every helper is directly unit-testable
(`test/calendar_preferences_test.dart`).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`normalizeWeekStartDay`](#normalizeweekstartday) | top-level function | A | Return a valid weekday to use as the app calendar week start. |
| [`homeCalendarDaysOfWeekHeight`](#homecalendardaysofweekheight) | top-level function | A | Return a home calendar weekday header height that fits its label text. |
| [`homeCalendarRowHeight`](#homecalendarrowheight) | top-level function | A | Return the home calendar day-cell row height for the current viewport. |
| [`weekdaySequence`](#weekdaysequence) | top-level function | A | Return weekdays ordered from the configured week start. |

The `HomeCalendarLayout` enum, `HomeCalendarTimeBasis` enum, and the `defaultWeekStartDay` and
`homeCalendarMaxWidth` constants are plain type/constant declarations without `/// Purpose:`
comments and are not indexed as separate rows. `homeCalendarMaxWidth` (560.0) is the widest the
home calendar grid is allowed to become, so square, landscape, tablet, and desktop windows centre
the grid instead of stretching the day cells across the whole window.

## Documentation

### `int normalizeWeekStartDay(int? weekday)` <a id="normalizeweekstartday"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/calendar_preferences.dart` (approx. line 14)
- **Purpose:** Clamp a possibly-invalid or missing weekday value to a valid app calendar week start
  day.
- **Inputs:** `weekday` — a candidate weekday using Dart's Monday=1…Sunday=7 numbering, or `null`.
- **Returns:** `int` — `weekday` unchanged if it's within `[DateTime.monday, DateTime.sunday]`,
  otherwise `defaultWeekStartDay` (Sunday).
- **Side effects:** None.
- **Algorithm:** A single guard: if `weekday` is `null` or outside the valid Dart weekday range,
  return `defaultWeekStartDay`; otherwise return `weekday` as-is.
- **Usage:**
  ```dart
  final normalized = normalizeWeekStartDay(weekday);
  ```
  (from `AppSettingsNotifier.setWeekStartDay`, `lib/shared/providers/app_settings.dart`; also used
  by `AnimeStorage` in `lib/features/anime/services/anime_storage.dart` and by
  `lib/features/anime/views/home_page.dart` when mapping to `table_calendar`'s
  `StartingDayOfWeek`)
- **Notes:** This is the single source of truth for "what counts as a valid week start day"; every
  other place in the codebase that stores or reads a week-start preference routes through it rather
  than validating independently.

### `double homeCalendarDaysOfWeekHeight(double labelLineHeight)` <a id="homecalendardaysofweekheight"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/calendar_preferences.dart` (approx. line 29)
- **Purpose:** Give the home calendar's weekday header row enough height that its labels are never
  vertically clipped.
- **Inputs:** `labelLineHeight` — the font-scaled line height of one weekday label, i.e.
  `MediaQuery.textScalerOf(context).scale(style.fontSize) * style.height`.
- **Returns:** `double` — `labelLineHeight + 8`, clamped to `[24.0, 64.0]`.
- **Side effects:** None.
- **Algorithm:** Add 8 logical pixels of breathing room to the measured line height, then clamp so
  the row can neither collapse below a legible minimum nor run away at extreme text scales.
- **Usage:**
  ```dart
  final daysOfWeekHeight = homeCalendarDaysOfWeekHeight(labelLineHeight);
  ```
  (from `lib/features/anime/views/home_page.dart`, `_buildCalendarSection`, fed straight into
  `TableCalendar.daysOfWeekHeight`)
- **Notes:** This exists because `table_calendar` defaults `daysOfWeekHeight` to `16.0` and wraps
  every weekday cell in a `SizedBox` of exactly that height (`calendar_core.dart`). A Material
  `bodySmall` label lays out around 16 px at normal scale and over 20 px at a large system font
  setting, and `RenderParagraph` clips the excess — which cut the top and bottom strokes off the
  日月火水木金土 labels. The 24.0 floor keeps the row above that default at every text scale.

### `double homeCalendarRowHeight(double viewportHeight, double daysOfWeekHeight)` <a id="homecalendarrowheight"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/calendar_preferences.dart` (approx. line 39)
- **Purpose:** Pick a day-cell row height that keeps a six-week month grid usable on short
  viewports without shrinking the calendar on ordinary portrait screens.
- **Inputs:** `viewportHeight` — the window height in logical pixels
  (`MediaQuery.sizeOf(context).height`); `daysOfWeekHeight` — the header height already reserved.
- **Returns:** `double` — `((viewportHeight * 0.55) - daysOfWeekHeight) / 6`, clamped to
  `[34.0, 52.0]`.
- **Side effects:** None.
- **Algorithm:** Budget roughly 55% of the window for the calendar block, subtract the weekday
  header, divide by the six rows of the tallest possible month, then clamp. The upper clamp is
  `table_calendar`'s own 52.0 default, so anything from a ~640 dp portrait phone upward is
  unchanged; short landscape and square windows slide down toward 34.0.
- **Usage:**
  ```dart
  final rowHeight = homeCalendarRowHeight(
    MediaQuery.sizeOf(context).height,
    daysOfWeekHeight,
  );
  ```
  (from `lib/features/anime/views/home_page.dart`, `_buildCalendarSection`)
- **Notes:** `home_page.dart` treats a result below 48.0 as "compact" and tightens the cell margin
  and marker dot to match, so the airing-episode dots do not collide with the day numbers.

### `List<int> weekdaySequence(int weekStartDay)` <a id="weekdaysequence"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/calendar_preferences.dart` (approx. line 49)
- **Purpose:** Produce the 7 weekdays in display order, starting from the configured week start
  day.
- **Inputs:** `weekStartDay` — Monday=1…Sunday=7; need not already be normalized.
- **Returns:** `List<int>` of length 7, each a Dart weekday number, starting with the normalized
  `weekStartDay` and wrapping around.
- **Side effects:** None.
- **Algorithm:**
  1. Normalize `weekStartDay` via `normalizeWeekStartDay`.
  2. For `offset` from 0 to 6, compute `((start - 1 + offset) % 7) + 1` — this rotates the
     1..7 weekday numbering so the sequence begins at `start` and wraps from 7 back to 1.
- **Usage:**
  ```dart
  for (final weekday in weekdaySequence(defaultWeekStartDay))
    DropdownMenuItem(
      value: weekday,
      child: Text(_weekdayLabel(weekday, l10n)),
    ),
  ```
  (from `lib/features/settings/views/settings_page.dart`, week-start-day dropdown options)
- **Notes:** The caller passes `defaultWeekStartDay` here specifically to always enumerate options
  in a fixed Sunday-first order for the dropdown list, independent of the currently selected
  preference — the *selected value* comes from `settings.effectiveWeekStartDay` separately.
