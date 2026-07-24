# lib/shared/utils/jst_time.dart

A static-only `JstTime` utility providing Japan Standard Time (UTC+9, no DST) helpers used
throughout the anime scheduling/calendar/reminder/API code. JST has no daylight saving time, so the
whole class can use a fixed +9-hour offset rather than a real timezone database. See `AGENTS.md`'s
"Calendar and airing logic are JST-aware" note and
[../../../architecture.md](../../../architecture.md) for how this underpins the home calendar and
local API server.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `JstTime._` | constructor (`JstTime`) | B | Prevent direct instantiation and expose only static members. |
| [`JstTime.now`](#jsttime-now) | method (`JstTime`) | A | Return the current time converted to Japan Standard Time. |
| [`JstTime.today`](#jsttime-today) | method (`JstTime`) | A | Return today's JST calendar date with the time zeroed. |
| [`JstTime.localToday`](#jsttime-localtoday) | method (`JstTime`) | A | Return today's local calendar date with the time zeroed. |
| [`JstTime.toLocal`](#jsttime-tolocal) | method (`JstTime`) | A | Convert a Japan-time `DateTime` into the device local timezone. |

## Documentation

### `static DateTime now()` <a id="jsttime-now"></a>
- **Kind:** static method of `JstTime`
- **Source:** `lib/shared/utils/jst_time.dart` (approx. line 15)
- **Purpose:** Return the current wall-clock time in Japan Standard Time.
- **Inputs:** None.
- **Returns:** `DateTime` — a naive (non-UTC-flagged) `DateTime` representing the current JST
  moment.
- **Side effects:** None (reads the system clock but does not mutate anything).
- **Algorithm:** Take `DateTime.now().toUtc()`, then construct a new `DateTime` with the same
  year/month/day and `hour + 9` (JST is UTC+9, no DST), preserving minute/second/millisecond.
- **Usage:**
  ```dart
  final now = JstTime.now();
  ```
  (from `lib/features/anime/views/home_page.dart`, checking whether an episode has already aired;
  also used repeatedly in `lib/shared/services/local_api_server.dart` and
  `lib/shared/services/share_service.dart`)
- **Notes:** The returned `DateTime` is constructed via the local (non-UTC) `DateTime()`
  constructor, so its `.isUtc` is `false` even though the value represents JST, not the device's
  local time — callers must not pass this value to APIs that assume "not UTC" means "device local
  time". `hour + 9` can legitimately roll into a value ≥ 24; Dart's `DateTime` constructor
  normalizes overflowing field values automatically, so this does not need extra carry logic.

### `static DateTime today()` <a id="jsttime-today"></a>
- **Kind:** static method of `JstTime`
- **Source:** `lib/shared/utils/jst_time.dart` (approx. line 33)
- **Purpose:** Return today's calendar date in JST with the time-of-day zeroed out.
- **Inputs:** None.
- **Returns:** `DateTime` at midnight, using the JST calendar date.
- **Side effects:** None.
- **Algorithm:** Call `now()`, then construct a new `DateTime(year, month, day)` from its date
  components only, dropping the time.
- **Usage:**
  ```dart
  HomeCalendarTimeBasis.jst => JstTime.today(),
  ```
  (from `lib/features/anime/views/home_page.dart`, choosing the home calendar's "today" reference
  date depending on the configured time basis; also used in
  `lib/shared/services/share_service.dart`)
- **Notes:** This is the JST-basis counterpart to `localToday()` — which one is used depends on the
  user's `HomeCalendarTimeBasis` preference (see
  [../providers/app_settings.md](../providers/app_settings.md)).

### `static DateTime localToday()` <a id="jsttime-localtoday"></a>
- **Kind:** static method of `JstTime`
- **Source:** `lib/shared/utils/jst_time.dart` (approx. line 43)
- **Purpose:** Return today's calendar date in the device's local timezone with the time zeroed.
- **Inputs:** None.
- **Returns:** `DateTime` at local midnight for the device's current date.
- **Side effects:** None.
- **Algorithm:** Call `DateTime.now()` (device local time, not JST), then construct a new
  `DateTime(year, month, day)` from its date components only.
- **Usage:**
  ```dart
  HomeCalendarTimeBasis.local => JstTime.localToday(),
  ```
  (from `lib/features/anime/views/home_page.dart`, home calendar "today" reference date when the
  user has selected the local time basis)
- **Notes:** Despite living on `JstTime`, this method deliberately does *not* apply the JST offset —
  it exists so the home calendar can switch its date-grid basis between JST and device-local time
  while still routing through one class. Anime airing timestamps themselves are unaffected by this
  choice and remain JST-based per `AGENTS.md`.

### `static DateTime toLocal(DateTime jstTime)` <a id="jsttime-tolocal"></a>
- **Kind:** static method of `JstTime`
- **Source:** `lib/shared/utils/jst_time.dart` (approx. line 53)
- **Purpose:** Convert a `DateTime` that represents a Japan-time wall-clock moment into the
  equivalent moment in the device's local timezone.
- **Inputs:** `jstTime` — a `DateTime` whose fields are interpreted as JST wall-clock time,
  regardless of its own `isUtc` flag.
- **Returns:** `DateTime` in the device's local timezone (`.toLocal()`'d).
- **Side effects:** None.
- **Algorithm:**
  1. Reconstruct `jstTime`'s fields as a genuine UTC `DateTime` via `DateTime.utc(...)`, subtracting
     9 hours from the hour field (undoing the JST offset to recover the true UTC instant).
  2. Call `.toLocal()` on that UTC instant to convert to the device's local timezone.
- **Usage:**
  ```dart
  final local = JstTime.toLocal(airDate);
  ```
  (from `lib/features/anime/views/home_page.dart`, converting an anime's JST air date/time for
  display on a local-timezone calendar grid)
- **Notes:** The input's own `.isUtc` flag is ignored — the function always treats the field values
  as JST wall-clock time, so passing an already-UTC or already-local `DateTime` by mistake will
  silently produce a wrong result rather than throwing. `hour - 9` can go negative; like `now()`,
  this relies on `DateTime.utc`'s automatic field normalization (borrowing from the day) rather than
  manual carry logic.
