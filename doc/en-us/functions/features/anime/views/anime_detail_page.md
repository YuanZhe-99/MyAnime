# lib/features/anime/views/anime_detail_page.dart

`AnimeDetailPage` is the read/act page for one tracked anime: cover, metadata chips, rating
summary, prev/next-season navigation, and the per-episode watch-status list with schedule-shift
controls. It reads and writes through `AnimeStorage` ([`../services/anime_storage.md`](../services/anime_storage.md))
and operates on the `Anime`/`AnimeRating` model ([`../models/anime.md`](../models/anime.md)). See
[`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md) for the episode
air-date/rollover and schedule-shift semantics this page exposes controls for.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `AnimeDetailPage.new` | constructor (`AnimeDetailPage`) | B | Create an `AnimeDetailPage` instance for a given anime ID. |
| `AnimeDetailPage.createState` | method (`AnimeDetailPage`) | B | Create the mutable state object for this widget. |
| `_AnimeDetailPageState.initState` | method (`_AnimeDetailPageState`) | B | Trigger the first data load. |
| [`_load`](#_load) | method (`_AnimeDetailPageState`) | A | Load this anime from storage and locate its prev/next season. |
| [`_toggleEpisode`](#_toggleepisode) | method (`_AnimeDetailPageState`) | A | Cycle one episode's watch status and persist it. |
| [`_shiftFromEpisode`](#_shiftfromepisode) | method (`_AnimeDetailPageState`) | A | Shift an episode's broadcast week by a delta and persist it. |
| [`_resetSchedule`](#_resetschedule) | method (`_AnimeDetailPageState`) | A | Clear all per-episode week offsets back to the original schedule. |
| [`_delete`](#_delete) | method (`_AnimeDetailPageState`) | A | Confirm and delete this anime record. |
| `_AnimeDetailPageState.build` | method (`_AnimeDetailPageState`, widget build) | B | Build the detail page scaffold (cover, info, episode list). |
| [`_toggleAllWatched`](#_toggleallwatched) | method (`_AnimeDetailPageState`) | A | Mark every tracked episode watched, or all unwatched if already complete. |
| `_buildAbandonOrResume` | method (widget helper) | B | Render the "Abandon"/"Resume" action button for the episode list header. |
| `_buildRatingCard` | method (widget helper) | B | Render the rating summary card. |
| `_formatScore` | method (`_AnimeDetailPageState`) | B | Format a score as an integer when whole, else one decimal place. |
| [`_abandonAnime`](#_abandonanime) | method (`_AnimeDetailPageState`) | A | Mark every remaining unwatched episode as skipped. |
| [`_resumeAnime`](#_resumeanime) | method (`_AnimeDetailPageState`) | A | Revert every skipped episode back to unwatched. |
| `_typeLabel` | method (`_AnimeDetailPageState`) | B | Localize an `AnimeType` value for display. |
| `_dayName` | method (`_AnimeDetailPageState`) | B | Localize a day-of-week number for display. |
| `_statusIcon` | method (`_AnimeDetailPageState`) | B | Pick the leading icon for an episode's watch status. |
| `_statusLabel` | method (`_AnimeDetailPageState`) | B | Localize an episode watch status for display. |
| `_statusColor` | method (`_AnimeDetailPageState`) | B | Pick the display color for an episode's watch status. |

## Documentation

### `Future<void> _load()` <a id="_load"></a>
- **Kind:** method of `_AnimeDetailPageState`
- **Source:** `lib/features/anime/views/anime_detail_page.dart` (approx. line 55)
- **Purpose:** Load the anime identified by `widget.animeId` from storage and, if found, locate the
  closest previous and next "season" records (same `displayTitle`, different `season` string) for
  the prev/next-season navigation buttons.
- **Inputs:** None (`widget.animeId` is read from the enclosing widget).
- **Returns:** `Future<void>`.
- **Side effects:** Calls `AnimeStorage.load()`; `setState`s `_anime`, `_prevSeasonId`, `_nextSeasonId`.
- **Algorithm:**
  1. Await `AnimeStorage.load()` and find the record whose `id == widget.animeId`.
  2. If found, collect every other record sharing the same `displayTitle`, sort that subset by
     `season` string comparison.
  3. Walk the sorted subset once to find the closest `season` less than the current one (`prev`,
     kept updating so the *last* qualifying entry — the closest below — wins) and once to find the
     closest `season` greater (`next`, `break`s on the *first* qualifying entry — the closest above).
  4. `setState` with the found anime and the two neighbor IDs (or just the anime if not found).
- **Usage:**
  ```dart
  @override
  void initState() {
    super.initState();
    _load();
  }
  ```
  (`_AnimeDetailPageState.initState`, same file; also called after edit/delete/episode actions to
  refresh the page)
- **Notes:** `season` comparison is a plain `String.compareTo`, so season labels need to sort
  correctly as strings (e.g. `"Season 2"` > `"Season 10"` lexicographically) — this page does not
  do numeric-aware season sorting.

### `Future<void> _toggleEpisode(int ep)` <a id="_toggleepisode"></a>
- **Kind:** method of `_AnimeDetailPageState`
- **Source:** `lib/features/anime/views/anime_detail_page.dart` (approx. line 95)
- **Purpose:** Advance one episode's watch status to the next state in the cycle and persist it.
- **Inputs:** `ep` — the episode number to toggle.
- **Returns:** `Future<void>`.
- **Side effects:** Calls `AnimeStorage.addOrUpdate`; reloads via `_load()`.
- **Algorithm:**
  1. Read the episode's current status (`unwatched` if absent).
  2. Cycle it: `unwatched` → `watched` → `skippedThisWeek` → `unwatched`.
  3. `copyWith` the anime with the updated `episodeStatuses` map and a fresh `modifiedAt`, save via
     `AnimeStorage.addOrUpdate`, then `_load()`.
- **Usage:**
  ```dart
  onTap: () => _toggleEpisode(ep),
  ```
  (`_AnimeDetailPageState.build`, episode list tile)
- **Notes:** The three-state cycle (rather than a plain watched/unwatched toggle) is what lets a
  single tap mark an episode as intentionally skipped, distinct from simply not-yet-watched — see
  [`viewingStatus`](../models/anime.md#viewingstatus) for how that distinction affects the derived
  status shown elsewhere.

### `Future<void> _shiftFromEpisode(int ep, int delta)` <a id="_shiftfromepisode"></a>
- **Kind:** method of `_AnimeDetailPageState`
- **Source:** `lib/features/anime/views/anime_detail_page.dart` (approx. line 123)
- **Purpose:** Shift episode `ep` (and, cumulatively, every subsequent episode) forward or backward
  by `delta` weeks.
- **Inputs:** `ep` — the episode number whose offset entry is adjusted; `delta` — weeks to add
  (positive delays, negative advances).
- **Returns:** `Future<void>`.
- **Side effects:** Calls `AnimeStorage.addOrUpdate`; reloads via `_load()`.
- **Algorithm:**
  1. Copy `episodeWeekOffsets`, add `delta` to the existing entry for `ep` (or start from `0`).
  2. Remove the entry entirely if the result is `0` (keeps the map minimal).
  3. Persist via `copyWith(episodeWeekOffsets: ..., modifiedAt: DateTime.now().toUtc())` and
     `AnimeStorage.addOrUpdate`, then `_load()`.
- **Usage:**
  ```dart
  icon: const Icon(Icons.keyboard_double_arrow_left),
  onPressed: () => _shiftFromEpisode(ep, -1),
  ```
  (`_AnimeDetailPageState.build`, per-episode shift buttons)
- **Notes:** Because [`weekOffsetFor`](../models/anime.md#weekoffsetfor) sums every offset entry
  whose key is `<= episodeNumber`, an offset stored against episode `ep` shifts every later episode
  too, not just `ep` itself — see
  [`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md).

### `Future<void> _resetSchedule()` <a id="_resetschedule"></a>
- **Kind:** method of `_AnimeDetailPageState`
- **Source:** `lib/features/anime/views/anime_detail_page.dart` (approx. line 141)
- **Purpose:** Clear every per-episode week offset, restoring the original `firstAirDate`-derived
  schedule, after user confirmation.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Shows a confirmation `AlertDialog`; calls `AnimeStorage.addOrUpdate`; reloads via
  `_load()`.
- **Algorithm:**
  1. Show a confirm dialog; return early unless the user confirms.
  2. `copyWith(episodeWeekOffsets: {}, modifiedAt: ...)`, save via `AnimeStorage.addOrUpdate`,
     `_load()`.
- **Usage:**
  ```dart
  onPressed: () => _resetSchedule(),
  ```
  (`_AnimeDetailPageState.build`, shown only when `anime.episodeWeekOffsets.isNotEmpty`)
- **Notes:** This clears every accumulated shift at once — there is no per-episode undo, only
  all-or-nothing reset.

### `Future<void> _delete()` <a id="_delete"></a>
- **Kind:** method of `_AnimeDetailPageState`
- **Source:** `lib/features/anime/views/anime_detail_page.dart` (approx. line 175)
- **Purpose:** Delete the currently displayed anime record after user confirmation, then leave the
  page.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Shows a confirm dialog (`confirmDelete`); calls
  `AnimeStorage.deleteAnime`; pops the current route.
- **Algorithm:**
  1. Return early if `_anime` is `null`.
  2. Await `confirmDelete(context, _anime!.displayTitle)`; return if declined.
  3. `AnimeStorage.deleteAnime(_anime!.id)`, then `context.pop()` if still mounted.
- **Usage:**
  ```dart
  IconButton(
    icon: const Icon(Icons.delete_outline),
    onPressed: _delete,
  ),
  ```
  (`_AnimeDetailPageState.build`, app bar action)
- **Notes:** Unlike the episode/schedule mutators, this does not call `_load()` afterward — the page
  is popped instead since its subject no longer exists.

### `Future<void> _toggleAllWatched()` <a id="_toggleallwatched"></a>
- **Kind:** method of `_AnimeDetailPageState`
- **Source:** `lib/features/anime/views/anime_detail_page.dart` (approx. line 457)
- **Purpose:** Mark every tracked episode watched in one action, or mark all unwatched if the anime
  is already fully complete (acts as a toggle at the whole-series level).
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Calls `AnimeStorage.addOrUpdate`; reloads via `_load()`.
- **Algorithm:**
  1. Return early if `_anime` is `null` or has no `endEpisode` (open-ended series can't be "all
     watched").
  2. Read `isCompleted` (see [`../models/anime.md#iscompleted`](../models/anime.md#iscompleted)) to
     decide direction.
  3. Loop `startEpisode..endEpisode`, setting every episode's status to `unwatched` (if already
     complete) or `watched` (otherwise).
  4. Persist via `copyWith(episodeStatuses: ..., modifiedAt: ...)` and `_load()`.
- **Usage:**
  ```dart
  TextButton(
    onPressed: () => _toggleAllWatched(),
    child: Text(
      anime.isCompleted
          ? l10n.animeMarkAllUnwatched
          : l10n.animeMarkAllWatched,
    ),
  ),
  ```
  (`_AnimeDetailPageState.build`, episode list header)
- **Notes:** Overwrites every episode's status unconditionally in one direction — any individually
  `skippedThisWeek` episodes are also swept into `watched`/`unwatched` by this action.

### `Future<void> _abandonAnime()` <a id="_abandonanime"></a>
- **Kind:** method of `_AnimeDetailPageState`
- **Source:** `lib/features/anime/views/anime_detail_page.dart` (approx. line 595)
- **Purpose:** Mark every currently-unwatched tracked episode as `skippedThisWeek`, effectively
  giving up on catching up with the remaining backlog.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Calls `AnimeStorage.addOrUpdate`; reloads via `_load()`.
- **Algorithm:**
  1. Return early if `_anime` is `null` or has no `endEpisode`.
  2. Loop `startEpisode..endEpisode`; any episode whose status is (or defaults to) `unwatched`
     becomes `skippedThisWeek`. Episodes already `watched` are left untouched.
  3. Persist and reload.
- **Usage:**
  ```dart
  return TextButton(
    onPressed: () => _abandonAnime(),
    child: Text(l10n.animeAbandon),
  );
  ```
  (`_buildAbandonOrResume`, shown when at least one episode is still unwatched)
- **Notes:** Per [`viewingStatus`](../models/anime.md#viewingstatus), turning every unwatched episode
  into `skippedThisWeek` (with zero remaining `unwatched`) is exactly what makes the anime read as
  `dropped` elsewhere in the app.

### `Future<void> _resumeAnime()` <a id="_resumeanime"></a>
- **Kind:** method of `_AnimeDetailPageState`
- **Source:** `lib/features/anime/views/anime_detail_page.dart` (approx. line 617)
- **Purpose:** Reverse `_abandonAnime` — revert every `skippedThisWeek` episode back to `unwatched`
  so the series can be picked back up.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Calls `AnimeStorage.addOrUpdate`; reloads via `_load()`.
- **Algorithm:**
  1. Return early if `_anime` is `null` or has no `endEpisode`.
  2. Loop `startEpisode..endEpisode`; any episode whose status is exactly `skippedThisWeek` becomes
     `unwatched`. `watched` episodes are left untouched.
  3. Persist and reload.
- **Usage:**
  ```dart
  return TextButton(
    onPressed: () => _resumeAnime(),
    child: Text(l10n.animeResume),
  );
  ```
  (`_buildAbandonOrResume`, shown when there are no unwatched episodes left but at least one skipped
  one)
- **Notes:** `_buildAbandonOrResume` shows at most one of the abandon/resume buttons at a time —
  abandon takes priority when both unwatched and skipped episodes exist.
