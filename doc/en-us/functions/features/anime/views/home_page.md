# lib/features/anime/views/home_page.dart

`HomePage` is the app's default tab: a JST-aware calendar (`table_calendar`) showing which episodes
air on a selected day, plus a rolling list of aired-but-unwatched episodes across every tracked
anime. It reads `AppSettings` (via `flutter_riverpod`,
[`../../../shared/providers/app_settings.md`](../../../shared/providers/app_settings.md)) to decide
calendar layout/time-basis, uses `JstTime`
([`../../../shared/utils/jst_time.md`](../../../shared/utils/jst_time.md)) and
`calendar_preferences.dart`
([`../../../shared/utils/calendar_preferences.md`](../../../shared/utils/calendar_preferences.md))
for date math, and persists episode-status changes through `AnimeStorage`
([`../services/anime_storage.md`](../services/anime_storage.md)). See
[`../../../../features/home-management-statistics.md`](../../../../features/home-management-statistics.md)
for the calendar/time-basis feature description and
[`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md) for the
underlying episode air-date logic this page consumes.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `HomePage.new` | constructor (`HomePage`) | B | Create a `HomePage` instance. |
| `HomePage.createState` | method (`HomePage`) | B | Create the mutable state object for this widget. |
| `_HomePageState.initState` | method (`_HomePageState`) | B | Register the sync-reload callback and trigger the first load. |
| `_HomePageState.dispose` | method (`_HomePageState`) | B | Unregister the sync-reload callback. |
| [`_load`](#_load) | method (`_HomePageState`) | A | Reload all anime from storage. |
| [`_getEventsForDay`](#_geteventsforday) | method (`_HomePageState`) | A | Collect every episode airing on a given calendar day. |
| [`_today`](#_today) | method (`_HomePageState`) | A | Return "today" under the selected home calendar time basis. |
| [`_getEpisodeCalendarDate`](#_getepisodecalendardate) | method (`_HomePageState`) | A | Resolve an episode's calendar date under the selected time basis. |
| [`_getEpisodeDisplayAirDate`](#_getepisodedisplayairdate) | method (`_HomePageState`) | A | Resolve an episode's display air date/time under the selected time basis. |
| [`_getUnwatchedEpisodes`](#_getunwatchedepisodes) | method (`_HomePageState`) | A | Build the sorted list of aired-but-unwatched episodes, one per anime. |
| [`_countUnwatchedAiredEpisodes`](#_countunwatchedairedepisodes) | method (`_HomePageState`) | A | Count all aired unwatched episodes across every anime. |
| [`_toggleWatched`](#_togglewatched) | method (`_HomePageState`) | A | Toggle one episode between watched and unwatched. |
| [`_showAddOptions`](#_showaddoptions) | method (`_HomePageState`) | A | Show the add/import choice dialog and open the resulting anime. |
| `_HomePageState.build` | method (`_HomePageState`, widget build) | B | Build the calendar, selected-day list, and unwatched list. |
| `_calendarDateLocale` | method (`_HomePageState`) | B | Pick the locale used for calendar month/date text. |
| `_formatCalendarMonth` | method (`_HomePageState`) | B | Format the calendar header's month label. |
| `_calendarWeekdayLabel` | method (`_HomePageState`) | B | Format one weekday-row label (Japanese single-character or localized). |
| `_startingDayOfWeek` | method (`_HomePageState`) | B | Convert a week-start weekday into `TableCalendar`'s enum. |
| `_calendarTimeNote` | method (`_HomePageState`) | B | Localize the explanatory note for the current time basis. |
| `_buildEpisodeTile` | method (widget helper) | B | Render one episode row (cover, title, air date, watch toggle). |
| `_AiringEpisode.new` | constructor (`_AiringEpisode`) | B | Pair an anime with one of its episode numbers. |

## Documentation

### `Future<void> _load()` <a id="_load"></a>
- **Kind:** method of `_HomePageState`
- **Source:** `lib/features/anime/views/home_page.dart` (approx. line 73)
- **Purpose:** Reload the full anime list from storage into `_allAnime`.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Calls `AnimeStorage.load()`; `setState`s `_allAnime`.
- **Algorithm:** Await `AnimeStorage.load()`; if still mounted, `setState(() => _allAnime =
  data.animeList)`.
- **Usage:**
  ```dart
  @override
  void initState() {
    super.initState();
    AutoSyncService.instance.addOnLocalDataChanged(_load);
    _load();
  }
  ```
  (`_HomePageState.initState`, same file; also wired as `RefreshIndicator.onRefresh` in `build`, and
  registered with `AutoSyncService` so background sync/restore triggers a reload)
- **Notes:** Registered with
  [`AutoSyncService.addOnLocalDataChanged`](../../../shared/services/auto_sync_service.md#addonlocaldatachanged)
  in `initState` and unregistered in `dispose`, so the calendar refreshes automatically after a
  background sync or backup restore replaces local data.

### `List<_AiringEpisode> _getEventsForDay(DateTime day, HomeCalendarTimeBasis timeBasis)` <a id="_geteventsforday"></a>
- **Kind:** method of `_HomePageState`
- **Source:** `lib/features/anime/views/home_page.dart` (approx. line 83)
- **Purpose:** Collect every episode, across every tracked anime, whose calendar date (under the
  given time basis) matches `day`.
- **Inputs:** `day`; `timeBasis` — `HomeCalendarTimeBasis.jst` or `.local`.
- **Returns:** `List<_AiringEpisode>`.
- **Side effects:** None.
- **Algorithm:**
  1. Normalize `day` to a date-only `DateTime`.
  2. For each anime, loop every episode from `startEpisode` to `endEpisode ?? startEpisode`.
  3. For each episode, compute its calendar date via [`_getEpisodeCalendarDate`](#_getepisodecalendardate);
     if it equals `dayOnly`, add an `_AiringEpisode(anime: anime, episode: ep)`.
- **Usage:**
  ```dart
  eventLoader: (day) =>
      _getEventsForDay(day, settings.homeCalendarTimeBasis),
  ```
  (`_HomePageState.build`, `TableCalendar.eventLoader` — also used directly for `selectedEvents`)
- **Notes:** For a long-running anime with no `endEpisode`, only `startEpisode` itself is scanned
  (the loop bound is `anime.endEpisode ?? anime.startEpisode`), so future episodes of an open-ended
  series never appear as calendar events here.

### `DateTime _today(HomeCalendarTimeBasis timeBasis)` <a id="_today"></a>
- **Kind:** method of `_HomePageState`
- **Source:** `lib/features/anime/views/home_page.dart` (approx. line 106)
- **Purpose:** Return the date-only "today" that the calendar should highlight and default its
  selection to, under the selected home calendar time basis.
- **Inputs:** `timeBasis`.
- **Returns:** `DateTime` (date-only).
- **Side effects:** None.
- **Algorithm:** `switch` on `timeBasis`: `jst` → `JstTime.today()`; `local` →
  `JstTime.localToday()`.
- **Usage:**
  ```dart
  final calendarToday = _today(settings.homeCalendarTimeBasis);
  final focusedDay = _focusedDay ?? calendarToday;
  final selectedDay = _selectedDay ?? calendarToday;
  ```
  (`_HomePageState.build`, same file)
- **Notes:** This is the concrete implementation of the "calendar date grid defaults to Japan time,
  but can be switched to the device's local timezone" behavior described in
  [`../../../../features/home-management-statistics.md`](../../../../features/home-management-statistics.md).

### `DateTime? _getEpisodeCalendarDate(Anime anime, int episode, HomeCalendarTimeBasis timeBasis)` <a id="_getepisodecalendardate"></a>
- **Kind:** method of `_HomePageState`
- **Source:** `lib/features/anime/views/home_page.dart` (approx. line 118)
- **Purpose:** Resolve which calendar day an episode belongs on for calendar-grid placement,
  respecting the local-time toggle while keeping all-at-once releases pinned to their JST release
  date.
- **Inputs:** `anime`; `episode`; `timeBasis`.
- **Returns:** `DateTime?` (date-only), or `null` if the anime's schedule data is incomplete.
- **Side effects:** None.
- **Algorithm:**
  1. If `timeBasis` is `jst`, or the anime's `effectiveType` is `allAtOnce`, return
     [`anime.getEpisodeCalendarDate(episode)`](../models/anime.md#getepisodecalendardate) directly
     (JST calendar date, no rollover).
  2. Otherwise (local basis, not all-at-once): get the JST air instant via
     [`anime.getEpisodeAirDate(episode)`](../models/anime.md#getepisodeairdate); if `null`, fall back
     to the JST calendar date; else convert it to local time via `JstTime.toLocal` and take its
     date-only part.
- **Usage:**
  ```dart
  final calDate = _getEpisodeCalendarDate(anime, ep, timeBasis);
  if (calDate != null && calDate == dayOnly) {
    events.add(_AiringEpisode(anime: anime, episode: ep));
  }
  ```
  (`_getEventsForDay`, same file)
- **Notes:** This is the mechanism behind "even when switched to local time, anime airing timestamps
  are still calculated in Japan time" — the underlying air *instant* always comes from the model's
  JST-based logic; only the final local/JST date conversion happens here. See
  [`../../../../features/home-management-statistics.md`](../../../../features/home-management-statistics.md).

### `DateTime? _getEpisodeDisplayAirDate(Anime anime, int episode, HomeCalendarTimeBasis timeBasis)` <a id="_getepisodedisplayairdate"></a>
- **Kind:** method of `_HomePageState`
- **Source:** `lib/features/anime/views/home_page.dart` (approx. line 142)
- **Purpose:** Resolve the air date/time shown as text on an episode tile, following the same
  local/JST and all-at-once rules as [`_getEpisodeCalendarDate`](#_getepisodecalendardate) but
  returning the full air instant (not date-only) when relevant.
- **Inputs:** `anime`; `episode`; `timeBasis`.
- **Returns:** `DateTime?`.
- **Side effects:** None.
- **Algorithm:**
  1. If `effectiveType == allAtOnce`, return the JST calendar date.
  2. Otherwise get the JST air instant via `getEpisodeAirDate`; return `null` if unavailable.
  3. Return it converted to local time (`JstTime.toLocal`) if `timeBasis == local`, else return the
     JST instant unchanged.
- **Usage:**
  ```dart
  final airDate = _getEpisodeDisplayAirDate(
    ep.anime,
    ep.episode,
    settings.homeCalendarTimeBasis,
  );
  ```
  (`_buildEpisodeTile`, same file, to format the displayed air-date string)
- **Notes:** Unlike [`_getEpisodeCalendarDate`](#_getepisodecalendardate), this keeps the full
  time-of-day (not just the date), since it feeds display text rather than calendar-grid placement.

### `List<_AiringEpisode> _getUnwatchedEpisodes()` <a id="_getunwatchedepisodes"></a>
- **Kind:** method of `_HomePageState`
- **Source:** `lib/features/anime/views/home_page.dart` (approx. line 163)
- **Purpose:** Build the "aired but not yet watched" list shown below the calendar — the single
  earliest unwatched, already-aired episode per anime, sorted by air date.
- **Inputs:** None.
- **Returns:** `List<_AiringEpisode>`.
- **Side effects:** None.
- **Algorithm:**
  1. For each anime, scan episodes from `startEpisode` upward; find the first episode whose status
     is (or defaults to) `unwatched`.
  2. If that episode has an air date (JST, via `getEpisodeAirDate`) that is not after `JstTime.now()`
     (i.e. it has already aired), add it to the result list.
  3. `break` after the first unwatched episode per anime regardless of whether it qualified — only
     one candidate per anime is ever considered.
  4. Sort the result by air date ascending, treating `null` air dates as sorting last.
- **Usage:**
  ```dart
  final unwatched = _getUnwatchedEpisodes();
  ```
  (`_HomePageState.build`, same file)
- **Notes:** Because the scan `break`s at the first unwatched episode per anime, an anime with
  episode 3 unwatched but episode 4 already aired only ever surfaces episode 3 here — later aired
  episodes stay hidden until the earlier one is resolved.

### `int _countUnwatchedAiredEpisodes()` <a id="_countunwatchedairedepisodes"></a>
- **Kind:** method of `_HomePageState`
- **Source:** `lib/features/anime/views/home_page.dart` (approx. line 194)
- **Purpose:** Count every aired episode across every anime that is still unwatched, for the summary
  text above the unwatched list.
- **Inputs:** None.
- **Returns:** `int`.
- **Side effects:** None.
- **Algorithm:** Unlike [`_getUnwatchedEpisodes`](#_getunwatchedepisodes), this does **not** stop at
  the first unwatched episode per anime — it scans every episode of every anime and increments the
  count for each one that is `unwatched` (or unset) and whose air date is not after now.
- **Usage:**
  ```dart
  l10n.homeUnwatched(unwatched.length, unwatchedEpisodeCount),
  ```
  (`_HomePageState.build`, unwatched-section header — `unwatched.length` is the anime count from
  `_getUnwatchedEpisodes`, `unwatchedEpisodeCount` is this method's total episode count)
- **Notes:** This is why the header can show a larger episode count than the number of visible rows
  — the visible list is capped at one row per anime, while this count reflects every backlogged
  episode.

### `Future<void> _toggleWatched(_AiringEpisode ep)` <a id="_togglewatched"></a>
- **Kind:** method of `_HomePageState`
- **Source:** `lib/features/anime/views/home_page.dart` (approx. line 217)
- **Purpose:** Toggle one episode between `watched` and `unwatched` from the home page's episode
  tiles.
- **Inputs:** `ep` — the `_AiringEpisode` (anime + episode number) being toggled.
- **Returns:** `Future<void>`.
- **Side effects:** Calls `AnimeStorage.addOrUpdate`; reloads via `_load()`.
- **Algorithm:** Flip the episode's status: anything other than `watched` becomes `watched`;
  `watched` becomes `unwatched`. Persist via `copyWith(episodeStatuses: ..., modifiedAt: ...)` and
  `_load()`.
- **Usage:**
  ```dart
  onPressed: () => _toggleWatched(ep),
  ```
  (`_buildEpisodeTile`, same file)
- **Notes:** Unlike [`_toggleEpisode`](anime_detail_page.md#_toggleepisode) on the detail page (which
  cycles through three states), this is a plain two-state toggle — it can never set
  `skippedThisWeek`.

### `Future<void> _showAddOptions()` <a id="_showaddoptions"></a>
- **Kind:** method of `_HomePageState`
- **Source:** `lib/features/anime/views/home_page.dart` (approx. line 237)
- **Purpose:** Show a "Create" vs. "Import" choice dialog, then navigate to whichever flow the user
  picked and open the resulting anime's detail page.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Shows a `SimpleDialog`; navigates via `context.push`; may run the import-bundle
  flow (file-system read); reloads via `_load()` at each step.
- **Algorithm:**
  1. Show a `SimpleDialog` offering "create" or "import"; return if dismissed without a choice.
  2. If `'create'`: push `/anime/edit`, reload, and if a new ID came back, push
     `/anime/detail/$newId` and reload again.
  3. If `'import'`: run `showImportBundleFlow(context)`, reload, and if any IDs were imported, push
     the detail page for the first imported ID and reload again.
- **Usage:**
  ```dart
  floatingActionButton: FloatingActionButton(
    onPressed: _showAddOptions,
    tooltip: l10n.animeAdd,
    child: const Icon(Icons.add),
  ),
  ```
  (`_HomePageState.build`, same file)
- **Notes:** Structurally identical to `ManagementPage._showAddOptions`
  ([`management_page.md`](management_page.md#_showaddoptions)), except this page does not jump the
  calendar to any particular date afterward (management's version jumps to the new anime's quarter).
