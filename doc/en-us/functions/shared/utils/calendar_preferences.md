# lib/shared/utils/calendar_preferences.dart

Small shared utility module for calendar week-start-day handling: the `HomeCalendarLayout` and
`HomeCalendarTimeBasis` enums, the `defaultWeekStartDay` constant, and two pure helper functions
used by `AppSettings`/`AppSettingsNotifier` (see
[../providers/app_settings.md](../providers/app_settings.md)), `AnimeStorage`, `home_page.dart`,
and `settings_page.dart` to normalize and enumerate weekday ordering.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`normalizeWeekStartDay`](#normalizeweekstartday) | top-level function | A | Return a valid weekday to use as the app calendar week start. |
| [`weekdaySequence`](#weekdaysequence) | top-level function | A | Return weekdays ordered from the configured week start. |

The `HomeCalendarLayout` enum, `HomeCalendarTimeBasis` enum, and `defaultWeekStartDay` constant are
plain type/constant declarations without `/// Purpose:` comments and are not indexed as separate
rows.

## Documentation

### `int normalizeWeekStartDay(int? weekday)` <a id="normalizeweekstartday"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/calendar_preferences.dart` (approx. line 12)
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

### `List<int> weekdaySequence(int weekStartDay)` <a id="weekdaysequence"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/calendar_preferences.dart` (approx. line 26)
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
