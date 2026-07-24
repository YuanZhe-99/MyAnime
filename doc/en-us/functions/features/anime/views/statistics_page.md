# lib/features/anime/views/statistics_page.dart

`StatisticsPage` is the third of the app's three main data-browsing tabs (Home / Management /
Statistics — see [`../../../../features/home-management-statistics.md`](../../../../features/home-management-statistics.md)
and [`../../../../architecture.md`](../../../../architecture.md) for the `go_router` shell). It has
two sub-views selected by `_StatsView`: a **Summary** view (quarter/year/all scope, summary count
cards, a scrollable quarter/year trend bar chart, and expandable completed/watching/dropped/
not-started lists) and a **Ranking** view (rating-based ranking with time/type filters and
ascending/descending sort, with cover thumbnails). Both views can be shared/exported as an image,
a `.myanimeitem` data file, or a plain-text name list — the actual byte generation and platform
share mechanics live in `ShareService` (`shared/services/share_service.dart`, documented in
[`../../../../features/share-and-import.md`](../../../../features/share-and-import.md)); this file
owns the filtering, grouping, ranking, trend-computation, and row-limiting logic that feeds that
service. Quarter placement (`airsInQuarter`, `startQuarter`) comes from `Anime`
(`lib/features/anime/models/anime.dart`, [`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md));
this file additionally defines its own compact `year * 4 + quarter` index convention
(`_quarterIndex`/`_quarterFromIndex`) for iterating and comparing quarters. Data reloads come from
`AnimeStorage.load()` and are re-triggered automatically via `AutoSyncService`'s
"local data changed" callback.

The file also declares five private enums with no logic of their own (`_StatsView`, `_TimeScope`,
`_TrendGranularity`, `_RankingTimeFilter`, `_SummarySharePriority`) and one small private data class,
`_TrendEntry` (year/quarter/tracked/completed/dropped counts for one trend-chart bar) — these are
described here in prose rather than as `Declarations` rows, consistent with how plain enum/field
declarations are handled elsewhere in this doc set.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `StatisticsPage.new` | constructor (`StatisticsPage`) | B | Create a `StatisticsPage` instance. |
| `StatisticsPage.createState` | method (`StatisticsPage`) | B | Create the mutable state object for this widget. |
| `_StatisticsPageState.initState` | method (`_StatisticsPageState`) | B | Set quarter/year filter defaults to the current date, register the auto-sync reload callback, and trigger the first load. |
| `_StatisticsPageState.dispose` | method (`_StatisticsPageState`) | B | Unregister the auto-sync reload callback and dispose the trend scroll controller. |
| [`_StatisticsPageState._load`](#_load) | method (`_StatisticsPageState`) | A | Load the current anime list from storage and refresh the trend chart's scroll position. |
| `_StatisticsPageState._scrollTrendToEnd` | method (`_StatisticsPageState`) | B | Jump the trend chart's scroll position to its last entry after the next frame. |
| [`_StatisticsPageState._scrollTrendToFocused`](#_scrolltrendtofocused) | method (`_StatisticsPageState`) | A | Scroll the trend chart so the currently focused quarter/year entry is centered. |
| [`_StatisticsPageState._filteredAnime`](#_filteredanime) | getter (`_StatisticsPageState`) | A | Anime list for the summary view's current time scope (quarter/year/all). |
| [`_StatisticsPageState._rankingAnime`](#_rankinganime) | getter (`_StatisticsPageState`) | A | Filtered and sorted anime list for the current Ranking view. |
| [`_StatisticsPageState._rankingShareEntries`](#_rankingshareentries) | method (`_StatisticsPageState`) | A | Convert a sorted ranking list into share-image entries with 1-based ranks. |
| [`_StatisticsPageState._shareRanking`](#_shareranking) | method (`_StatisticsPageState`) | A | Generate and share a ranking image for the current filter/sort/order, optionally row-limited. |
| `_StatisticsPageState._summaryShareSubtitle` | method (`_StatisticsPageState`) | B | Build the summary share-image subtitle (scope label + count), with a truncation note when limited. |
| [`_StatisticsPageState._summaryShareEntries`](#_summaryshareentries) | method (`_StatisticsPageState`) | A | Flatten the grouped completed/watching/dropped/not-started map into ordered share entries. |
| `_StatisticsPageState._shareSubtitleWithTruncation` | method (`_StatisticsPageState`) | B | Append a "shown of total" truncation note to a subtitle when fewer rows are shown than exist. |
| [`_StatisticsPageState._shareCoverCount`](#_sharecovercount) | method (`_StatisticsPageState`) | A | Count distinct non-empty cover-image URLs, for the share progress dialog's counter. |
| [`_StatisticsPageState._renumberStatisticsEntries`](#_renumberstatisticsentries) | method (`_StatisticsPageState`) | A | Reassign sequential 1-based ranks after sorting/limiting summary share entries. |
| [`_StatisticsPageState._sortSummaryShareEntries`](#_sortsummaryshareentries) | method (`_StatisticsPageState`) | A | Reorder summary share entries by first-air-date so a row limit keeps the most/least recent anime. |
| [`_StatisticsPageState._summaryFromEntries`](#_summaryfromentries) | method (`_StatisticsPageState`) | A | Recompute tracked/completed/dropped counts from the final entries that will be rendered. |
| [`_StatisticsPageState._generateImageWithProgress`](#_generateimagewithprogress) | method (`_StatisticsPageState`) | A | Run an async image-generation callback behind a blocking progress dialog, with failure handling. |
| `_StatisticsPageState._showSummaryStatusSelectionDialog` | method (`_StatisticsPageState`) | B | Ask which derived viewing statuses to include in a summary share image. |
| `_StatisticsPageState._showSummaryShareLimitDialog` | method (`_StatisticsPageState`) | B | Ask for a summary share row limit and a recent/oldest first-air-date priority. |
| `_StatisticsPageState._showRankingShareLimitDialog` | method (`_StatisticsPageState`) | B | Ask for a ranking share row limit, keeping the current ranking order. |
| [`_StatisticsPageState._shareStatistics`](#_sharestatistics) | method (`_StatisticsPageState`) | A | Top-level share entry point: ask the export format, then produce it for the current view. |
| [`_StatisticsPageState._matchesRankingTimeFilter`](#_matchesrankingtimefilter) | method (`_StatisticsPageState`) | A | Decide whether one anime passes the ranking view's current time filter (all/quarter/year/custom). |
| [`_StatisticsPageState._groupedAnime`](#_groupedanime) | getter (`_StatisticsPageState`) | A | Partition the current scope's filtered anime into the four derived viewing-status buckets. |
| [`_StatisticsPageState._prevPeriod`](#_prevperiod) | method (`_StatisticsPageState`) | A | Step the active period (ranking or summary quarter/year) back by one, with rollover. |
| [`_StatisticsPageState._nextPeriod`](#_nextperiod) | method (`_StatisticsPageState`) | A | Step the active period (ranking or summary quarter/year) forward by one, with rollover. |
| [`_StatisticsPageState._availableYearRange`](#_availableyearrange) | getter (`_StatisticsPageState`) | A | Compute the selectable year range for the quarter/year picker dialogs. |
| `_StatisticsPageState._pickSummaryQuarter` | method (`_StatisticsPageState`) | B | Open the quarter picker dialog and apply the chosen quarter to the summary scope. |
| `_StatisticsPageState._pickSummaryYear` | method (`_StatisticsPageState`) | B | Open the year picker dialog and apply the chosen year to the summary scope. |
| `_StatisticsPageState._pickRankingQuarter` | method (`_StatisticsPageState`) | B | Open the quarter picker dialog and apply the chosen quarter to the ranking time filter. |
| `_StatisticsPageState._pickRankingYear` | method (`_StatisticsPageState`) | B | Open the year picker dialog and apply the chosen year to the ranking time filter. |
| `_StatisticsPageState._pickRankingRangeStart` | method (`_StatisticsPageState`) | B | Open the quarter picker for the custom ranking range's start quarter, then normalize the range. |
| `_StatisticsPageState._pickRankingRangeEnd` | method (`_StatisticsPageState`) | B | Open the quarter picker for the custom ranking range's end quarter, then normalize the range. |
| `_StatisticsPageState._showYearPickerDialog` | method (`_StatisticsPageState`) | B | Render a scrollable year-list dialog with a per-year anime count next to each entry. |
| `_StatisticsPageState._countAnimeInQuarter` | method (`_StatisticsPageState`) | B | Count anime airing in a given quarter, for the quarter picker's per-item badge. |
| `_StatisticsPageState._countAnimeInYear` | method (`_StatisticsPageState`) | B | Count anime airing in any quarter of a given year, for the year picker's per-item badge. |
| [`_StatisticsPageState._normalizeRankingCustomRange`](#_normalizerankingcustomrange) | method (`_StatisticsPageState`) | A | Swap the custom ranking range's start/end quarters if they're out of order. |
| [`_StatisticsPageState._quarterIndex`](#_quarterindex) | static method (`_StatisticsPageState`) | A | Encode a (year, quarter) pair as a single comparable/steppable integer. |
| [`_StatisticsPageState._quarterFromIndex`](#_quarterfromindex) | static method (`_StatisticsPageState`) | A | Decode a compact quarter index back into a (year, quarter) pair. |
| [`_StatisticsPageState._trendData`](#_trenddata) | getter (`_StatisticsPageState`) | A | Build the trend chart data for the active summary scope and (for "all") granularity. |
| [`_StatisticsPageState._quarterTrendData`](#_quartertrenddata) | method (`_StatisticsPageState`) | A | Build quarter-level trend entries spanning the full known anime timeline. |
| [`_StatisticsPageState._yearTrendData`](#_yeartrenddata) | method (`_StatisticsPageState`) | A | Build year-level trend entries spanning the full known anime timeline. |
| [`_StatisticsPageState._quarterTrendEntry`](#_quartertrendentry) | method (`_StatisticsPageState`) | A | Build one quarter's trend entry (tracked/completed/dropped counts). |
| [`_StatisticsPageState._yearTrendEntry`](#_yeartrendentry) | method (`_StatisticsPageState`) | A | Build one year's trend entry (tracked/completed/dropped counts). |
| [`_StatisticsPageState._focusedTrendIndex`](#_focusedtrendindex) | method (`_StatisticsPageState`) | A | Locate the trend-data index matching the currently selected summary period, if any. |
| `_StatisticsPageState.build` | method (`_StatisticsPageState`, widget build) | B | Build the page scaffold: scope/view switch, summary or ranking body, and the share action. |
| `_StatisticsPageState._buildSummaryCard` | method (widget helper) | B | Render one summary count card (label + count) in a given color. |
| `_StatisticsPageState._buildRankingView` | method (widget helper) | B | Render the ranking view: filter controls followed by the ranked anime list. |
| `_StatisticsPageState._buildRankingFilters` | method (widget helper) | B | Render the ranking view's time/type/sort-field/order filter controls. |
| `_StatisticsPageState._buildRankingRangeButton` | method (widget helper) | B | Render one quarter-range button (start or end) for the custom ranking time filter. |
| `_StatisticsPageState._buildRankingTile` | method (widget helper) | B | Render one ranked anime row with rank, cover thumbnail, title, and score. |
| `_StatisticsPageState._buildCoverThumbnail` | method (widget helper) | B | Render an anime's cover-image thumbnail, or a placeholder if it has none. |
| `_StatisticsPageState._coverPlaceholder` | method (widget helper) | B | Render the placeholder icon shown for a missing cover thumbnail. |
| `_StatisticsPageState._buildTrendChart` | method (widget helper) | B | Render the scrollable trend bar chart, sourcing its data from `_trendData`. |
| `_StatisticsPageState._buildYAxisStub` | method (widget helper) | B | Render the trend chart's fixed left-side Y-axis label column. |
| `_StatisticsPageState._buildBarChart` | method (widget helper) | B | Render the trend chart's scrollable `fl_chart` bar-chart body. |
| `_StatisticsPageState._legendDot` | method (widget helper) | B | Render one colored-dot-plus-label legend entry. |
| `_StatisticsPageState._buildGroupedLists` | method (widget helper) | B | Render the expandable per-status anime lists for the summary view. |
| `_StatisticsPageState._quarterLabel` | method (`_StatisticsPageState`) | B | Format a (year, quarter) pair as a localized season + year label. |
| `_StatisticsPageState._rankingTimeFilterLabel` | method (`_StatisticsPageState`) | B | Localized label for a ranking time-filter option (all/quarter/year/custom range). |
| `_StatisticsPageState._rankingShareSubtitle` | method (`_StatisticsPageState`) | B | Build the ranking share-image subtitle from the current time and type filters. |
| `_StatisticsPageState._ratingFieldLabel` | method (`_StatisticsPageState`) | B | Localized label for an `AnimeRatingField` (overall or one of the five sub-scores). |
| `_StatisticsPageState._typeLabel` | method (`_StatisticsPageState`) | B | Localized label for an `AnimeType`. |
| `_StatisticsPageState._formatScore` | method (`_StatisticsPageState`) | B | Format a rating score to one decimal place. |
| `_TrendEntry.new` | constructor (`_TrendEntry`) | B | Create a trend entry instance (year, quarter, tracked/completed/dropped counts). |

## Documentation

### `Future<void> _load()` <a id="_load"></a>
- **Kind:** method of `_StatisticsPageState`
- **Source:** `lib/features/anime/views/statistics_page.dart` (line 114)
- **Purpose:** Load the current anime list from storage into state and refresh the trend chart's
  scroll position.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Reads `AnimeStorage.load()`; `setState` replaces `_allAnime`; scrolls the trend
  chart.
- **Algorithm:**
  1. `await AnimeStorage.load()` to get the current `AnimeData`.
  2. If still `mounted`, `setState` to replace `_allAnime` with `data.animeList`.
  3. Call `_scrollTrendToEnd()` to jump the trend chart to its last entry after the next frame.
- **Usage:**
  ```dart
  AutoSyncService.instance.addOnLocalDataChanged(_load);
  _load();
  ```
  (from `initState`, same file, lines 93-94; also used directly as `onRefresh: _load` on the page's
  `RefreshIndicator` in `build`, line 1509)
- **Notes:** Registered as both the initial loader and the `AutoSyncService` "local data changed"
  callback (removed again in `dispose`), so external syncs/imports refresh this page automatically
  while it is mounted.

### `void _scrollTrendToFocused({bool fallbackToEnd = false})` <a id="_scrolltrendtofocused"></a>
- **Kind:** method of `_StatisticsPageState`
- **Source:** `lib/features/anime/views/statistics_page.dart` (line 142)
- **Purpose:** Scroll the trend chart so the currently focused quarter/year entry is centered in
  the viewport.
- **Inputs:** `fallbackToEnd` — if true and there is no focused entry, scroll to the chart's end
  instead of doing nothing.
- **Returns:** None.
- **Side effects:** Moves `_trendScrollController` after the next frame, when it has clients.
- **Algorithm:**
  1. Wait for the next frame (`addPostFrameCallback`); return early if the scroll controller has
     no attached clients.
  2. Compute `_trendData` and locate the focused index via `_focusedTrendIndex(data)`.
  3. If there is no focused index: return unless `fallbackToEnd`, in which case target the max
     scroll extent.
  4. Otherwise compute a pixel target that centers a fixed-width (50px) bar in the viewport:
     `focusedIndex * entryWidth + entryWidth / 2 - viewportDimension / 2`.
  5. Clamp the target between `minScrollExtent`/`maxScrollExtent` and jump to it.
- **Usage:**
  ```dart
  if (shouldScrollSummaryTrend) _scrollTrendToFocused();
  ```
  (from `_nextPeriod`/`_prevPeriod`, same file; also called — with the default `fallbackToEnd:
  false` — after `_pickSummaryQuarter`/`_pickSummaryYear`)
- **Notes:** The 50px entry width is a hardcoded constant that must match the bar width used by
  `_buildBarChart`/`_buildTrendChart` for the centering math to line up visually.

### `List<Anime> get _filteredAnime` <a id="_filteredanime"></a>
- **Kind:** getter of `_StatisticsPageState`
- **Source:** `lib/features/anime/views/statistics_page.dart` (line 176)
- **Purpose:** Anime list for the summary view's current time scope (quarter/year/all).
- **Inputs:** None.
- **Returns:** `List<Anime>`.
- **Side effects:** None.
- **Algorithm:** `switch` on `_scope`:
  1. `quarter` — filter `_allAnime` by `anime.airsInQuarter(_selectedYear, _selectedQuarter)`.
  2. `year` — filter `_allAnime` by whether it airs in any of the 4 quarters of
     `_selectedYearOnly` (loop `q = 1..4`, short-circuit on first match).
  3. `all` — return `_allAnime` unfiltered.
- **Usage:**
  ```dart
  final animes = isRanking ? _rankingAnime : _filteredAnime;
  ```
  (from `_shareStatistics`, same file, line 799)
- **Notes:** Backs both the summary grouped lists (`_groupedAnime`) and the summary share/export
  flow; does not itself apply any viewing-status filter. See
  [`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md) for what
  `airsInQuarter` considers (multi-cour spans, `manualType` overrides, etc.).

### `List<Anime> get _rankingAnime` <a id="_rankinganime"></a>
- **Kind:** getter of `_StatisticsPageState`
- **Source:** `lib/features/anime/views/statistics_page.dart` (line 199)
- **Purpose:** Compute the current filtered and sorted anime list for the Ranking view.
- **Inputs:** None.
- **Returns:** `List<Anime>`.
- **Side effects:** None.
- **Algorithm:**
  1. Filter `_allAnime`, keeping anime that pass `_matchesRankingTimeFilter`, match
     `_rankingTypeFilter` when set (via `anime.effectiveType`), and have a non-null
     `anime.rating?.scoreFor(_rankingSortField)`.
  2. Sort the filtered list by that score — descending if `_rankingDescending`, else ascending —
     with ties broken by `displayTitle` ascending.
- **Usage:**
  ```dart
  final rankedAnime = isRanking ? _rankingAnime : const <Anime>[];
  ```
  (from `build`, same file, line 1492; also used in `_shareRanking` and `_shareStatistics`)
- **Notes:** Anime without a score for the selected `AnimeRatingField` are excluded entirely, not
  shown with a blank score.

### `List<RankingShareEntry> _rankingShareEntries(List<Anime> rankedAnime)` <a id="_rankingshareentries"></a>
- **Kind:** method of `_StatisticsPageState`
- **Source:** `lib/features/anime/views/statistics_page.dart` (line 226)
- **Purpose:** Convert an already-sorted ranking list into share-image entries with 1-based ranks
  and the current sort field's score.
- **Inputs:** `rankedAnime` — expected pre-filtered/pre-sorted (i.e. `_rankingAnime`).
- **Returns:** `List<RankingShareEntry>`.
- **Side effects:** None.
- **Algorithm:** `List.generate` over `rankedAnime`, wrapping each as `RankingShareEntry(anime,
  rank: index + 1, score: anime.rating!.scoreFor(_rankingSortField)!)`.
- **Usage:**
  ```dart
  var entries = _rankingShareEntries(rankedAnime);
  ```
  (from `_shareRanking`, same file, line 249)
- **Notes:** Assumes every anime in `rankedAnime` already has a non-null score for
  `_rankingSortField` — guaranteed by `_rankingAnime`'s filter — and would throw otherwise.

### `Future<void> _shareRanking()` <a id="_shareranking"></a>
- **Kind:** method of `_StatisticsPageState`
- **Source:** `lib/features/anime/views/statistics_page.dart` (line 244)
- **Purpose:** Generate and share a ranking image for the current filter/sort/order, optionally
  limited to the first N rows.
- **Inputs:** None (reads `context`/state).
- **Returns:** `Future<void>`.
- **Side effects:** Shows optional limit/progress dialogs, generates a PNG image, invokes the
  platform share flow.
- **Algorithm:**
  1. Return early if `_rankingAnime` is empty.
  2. Build share entries via `_rankingShareEntries`; remember `totalCount`.
  3. If there are more than 50 entries, ask `_showRankingShareLimitDialog(l10n, entries.length)`;
     cancel returns. If the limit is enabled, `take` the first N entries (N clamped to
     `1..entries.length`), keeping their existing rank/order.
  4. Build the subtitle via `_rankingShareSubtitle` plus `_shareSubtitleWithTruncation`.
  5. Generate image bytes via `_generateImageWithProgress` calling
     `ShareService.generateRankingShareBytes` with the sort-field and order labels.
  6. Share the resulting pages via `ShareService.shareImageBytesMulti` with file name base
     `myanime_ranking`.
- **Usage:**
  ```dart
  if (isRanking) {
    await _shareRanking();
  } else {
    // summary image branch
  }
  ```
  (from `_shareStatistics`, same file, line 832)
- **Notes:** A limited ranking share keeps the ranking's *existing* order — it takes the first N of
  the already-sorted list, unlike the summary share path (see `_sortSummaryShareEntries`), which
  offers a separate recent/oldest priority. See
  [`../../../../features/share-and-import.md`](../../../../features/share-and-import.md) for the
  50-row threshold and multi-page PNG splitting behavior owned by `ShareService`.

### `List<StatisticsShareEntry> _summaryShareEntries(Map<AnimeViewingStatus, List<Anime>> grouped, AppLocalizations l10n)` <a id="_summaryshareentries"></a>
- **Kind:** method of `_StatisticsPageState`
- **Source:** `lib/features/anime/views/statistics_page.dart` (line 321)
- **Purpose:** Flatten the completed/watching/dropped/not-started grouped map into a single ranked
  list of share entries in a fixed display order.
- **Inputs:** `grouped` — a status-to-anime-list map (typically `_groupedAnime`, possibly filtered
  down to selected statuses); `l10n` — for status labels.
- **Returns:** `List<StatisticsShareEntry>`.
- **Side effects:** None.
- **Algorithm:**
  1. Fixed status order: completed, watching, dropped, not-started (each paired with its localized
     label).
  2. For each status in order, for each anime in `grouped[status]`: compute `watchedCount` (count of
     `episodeStatuses` values equal to `EpisodeStatus.watched`) and `totalEps`
     (`endEpisode ?? startEpisode) - startEpisode + 1`); append a `StatisticsShareEntry` with a
     running 1-based `rank`, the status label, a `"watched/total"` progress label, and
     `anime.rating?.effectiveOverall` as score.
- **Usage:**
  ```dart
  var entries = _summaryShareEntries(selectedGrouped, l10n);
  ```
  (from `_shareStatistics`, same file, line 855)
- **Notes:** Rank numbering is contiguous across all four groups (not restarted per group); the
  order matches the on-screen grouped lists built by `_buildGroupedLists`.

### `int _shareCoverCount(Iterable<Anime> animes)` <a id="_sharecovercount"></a>
- **Kind:** method of `_StatisticsPageState`
- **Source:** `lib/features/anime/views/statistics_page.dart` (line 374)
- **Purpose:** Count unique cover images that may be loaded for a share image, for the progress
  dialog's "N of M" counter.
- **Inputs:** `animes` — the anime whose covers will be rendered.
- **Returns:** `int` — count of distinct non-empty `coverImage` values.
- **Side effects:** None.
- **Algorithm:** Build a `Set<String>` of `coverImage` values, skipping `null`/empty; return its
  length.
- **Usage:**
  ```dart
  coverCount: _shareCoverCount(entries.map((e) => e.anime)),
  ```
  (from both `_shareRanking` and `_shareStatistics`'s image branch)
- **Notes:** Counts unique URLs, not entries — anime sharing the same cover URL count once, since
  the underlying loader would only fetch that URL once.

### `List<StatisticsShareEntry> _renumberStatisticsEntries(List<StatisticsShareEntry> entries)` <a id="_renumberstatisticsentries"></a>
- **Kind:** method of `_StatisticsPageState`
- **Source:** `lib/features/anime/views/statistics_page.dart` (line 388)
- **Purpose:** Reassign sequential 1-based ranks after sorting or limiting share entries.
- **Inputs:** `entries` — the entries to renumber, in their final order.
- **Returns:** New `List<StatisticsShareEntry>` with sequential ranks; all other fields preserved.
- **Side effects:** None.
- **Algorithm:** `List.generate` copying each entry with `rank: index + 1`, keeping every other
  field unchanged.
- **Usage:**
  ```dart
  entries = _renumberStatisticsEntries(entries);
  ```
  (from `_shareStatistics`, same file, line 866, immediately after sorting and limiting)
- **Notes:** Must run after `_sortSummaryShareEntries` + `take(limitCount)` so displayed ranks are
  contiguous from 1, not the original grouped-list ranks.

### `List<StatisticsShareEntry> _sortSummaryShareEntries(List<StatisticsShareEntry> entries, _SummarySharePriority priority)` <a id="_sortsummaryshareentries"></a>
- **Kind:** method of `_StatisticsPageState`
- **Source:** `lib/features/anime/views/statistics_page.dart` (line 409)
- **Purpose:** Sort summary share entries by first-air-date so a row limit keeps the most (or
  least) recent anime.
- **Inputs:** `entries`; `priority` — `recent` or `oldest`.
- **Returns:** A new sorted `List<StatisticsShareEntry>`.
- **Side effects:** None.
- **Algorithm:**
  1. Copy `entries`, then sort with a comparator on `anime.firstAirDate`.
  2. Both dates `null` → compare by `displayTitle`. Exactly one `null` → the undated entry always
     sorts last, regardless of `priority`.
  3. Both dates present → compare them; `recent` priority negates the natural (ascending)
     comparison so newer dates sort first, `oldest` keeps ascending order.
  4. Equal dates → break ties by `displayTitle`.
- **Usage:**
  ```dart
  entries = _sortSummaryShareEntries(entries, limit.priority);
  ```
  (from `_shareStatistics`, same file, line 861; only reached when `entries.length > 50`)
- **Notes:** Entries without `firstAirDate` always sort to the bottom regardless of priority, so a
  "recent" limit still drops undated anime first.

### `StatisticsShareSummary _summaryFromEntries(List<StatisticsShareEntry> entries)` <a id="_summaryfromentries"></a>
- **Kind:** method of `_StatisticsPageState`
- **Source:** `lib/features/anime/views/statistics_page.dart` (line 436)
- **Purpose:** Build a tracked/completed/dropped summary count from the entries that will actually
  be rendered in a share image.
- **Inputs:** `entries` — the final (possibly limited/renumbered) entry list.
- **Returns:** `StatisticsShareSummary` reflecting exactly those entries.
- **Side effects:** None.
- **Algorithm:** Loop `entries`, `switch` on `entry.anime.viewingStatus` incrementing `completed`
  or `dropped` counters (`watching`/`notStarted` are no-ops); return
  `StatisticsShareSummary(tracked: entries.length, completed, dropped)`.
- **Usage:**
  ```dart
  final summary = _summaryFromEntries(entries);
  ```
  (from `_shareStatistics`, same file, line 868, after any limiting/renumbering)
- **Notes:** Recomputed after limiting so the share image's header bar chart reflects the possibly
  row-limited set, not the full unfiltered summary from `_groupedAnime`.

### `Future<List<Uint8List>?> _generateImageWithProgress({required AppLocalizations l10n, required int coverCount, required Future<List<Uint8List>> Function(ValueNotifier<double> progress) generate})` <a id="_generateimagewithprogress"></a>
- **Kind:** method of `_StatisticsPageState`
- **Source:** `lib/features/anime/views/statistics_page.dart` (line 465)
- **Purpose:** Generate image pages while showing a blocking progress dialog, surfacing a failure
  snackbar if generation throws.
- **Inputs:** `l10n`; `coverCount` — for the "done/total" progress text; `generate` — the actual
  byte-generation callback, given a `ValueNotifier<double>` to report progress into.
- **Returns:** A list of PNG page byte lists, or `null` when generation fails.
- **Side effects:** Shows/dismisses a non-dismissible `AlertDialog`; may show a failure `SnackBar`.
- **Algorithm:**
  1. Create a `ValueNotifier<double> progress` and show a `PopScope(canPop: false)` `AlertDialog`
     with a `LinearProgressIndicator` bound to it (plus a "done/coverCount" counter when
     `coverCount > 0`).
  2. `await Future.delayed(Duration.zero)` so the dialog actually paints before work starts.
  3. `try`/`catch`/`finally`: `await generate(progress)`; on error, capture it; `finally`, if still
     `mounted`, pop the dialog's navigator and await the dialog's future, then dispose `progress`.
  4. If an error occurred and still `mounted`, show a `SnackBar` with `l10n.shareFailed`.
  5. Return the generated pages, or `null` if generation failed.
- **Usage:**
  ```dart
  final pages = await _generateImageWithProgress(
    l10n: l10n,
    coverCount: _shareCoverCount(entries.map((e) => e.anime)),
    generate: (progress) => ShareService.generateRankingShareBytes(
      entries: entries,
      title: l10n.statsRanking,
      subtitle: subtitle,
      sortLabel: _ratingFieldLabel(_rankingSortField, l10n),
      orderLabel: _rankingDescending ? l10n.statsRankingDescending : l10n.statsRankingAscending,
      l10n: l10n,
      progress: progress,
    ),
  );
  ```
  (from `_shareRanking`, same file; called analogously from `_shareStatistics`'s summary-image
  branch with `ShareService.generateStatisticsShareBytes`)
- **Notes:** The platform share sheet is only shown after this dialog closes, so — per its own
  source comment — desktop preview behavior isn't exercised while this method runs.

### `Future<void> _shareStatistics()` <a id="_sharestatistics"></a>
- **Kind:** method of `_StatisticsPageState`
- **Source:** `lib/features/anime/views/statistics_page.dart` (line 764)
- **Purpose:** Top-level entry point for the AppBar share action: ask the user whether to share as
  an image, data file, or TXT name list, then produce the appropriate output for the current
  statistics view (summary or ranking).
- **Inputs:** None (reads `context`/state).
- **Returns:** `Future<void>`.
- **Side effects:** Shows dialogs, generates images, shares files.
- **Algorithm:**
  1. Ask `shareType` via a `SimpleDialog`: `'image'`, `'data'`, or `'txt'`; cancel returns.
  2. Compute `animes` (`_rankingAnime` or `_filteredAnime`) and a `displayName` (`myanime_ranking`,
     or `myanime_<year>_Q<quarter>` / `myanime_<year>` / `myanime_all` depending on `_scope`), used
     by the `txt`/`data` branches.
  3. `'txt'` → `ShareService.shareStatisticsTxt` and return.
  4. `'data'` → return early if `animes` is empty, else `ShareService.shareStatisticsData` and
     return.
  5. Image share, ranking view → delegate entirely to `_shareRanking()`.
  6. Image share, summary view → ask `_showSummaryStatusSelectionDialog`, filter `_groupedAnime`
     down to the selected statuses (unselected statuses become empty lists), build entries via
     `_summaryShareEntries`. If more than 50 entries: ask `_showSummaryShareLimitDialog`, sort via
     `_sortSummaryShareEntries(priority)`, optionally `take(limitCount)`, then
     `_renumberStatisticsEntries`. Compute `summary` via `_summaryFromEntries` and the subtitle via
     `_summaryShareSubtitle`. Generate pages via `_generateImageWithProgress` calling
     `ShareService.generateStatisticsShareBytes`, then share via
     `ShareService.shareImageBytesMulti` with file name base `myanime_stats`.
- **Usage:**
  ```dart
  IconButton(
    icon: const Icon(Icons.ios_share),
    tooltip: l10n.statsShare,
    onPressed: (isRanking ? rankedAnime.isNotEmpty : _filteredAnime.isNotEmpty)
        ? _shareStatistics
        : null,
  ),
  ```
  (from `build`, same file, lines 1498-1505)
- **Notes:** This is the only method that ever calls `_showSummaryStatusSelectionDialog`,
  `_sortSummaryShareEntries`, `_renumberStatisticsEntries`, or `_summaryFromEntries` — those helpers
  exist purely to support this method's summary-image branch.

### `bool _matchesRankingTimeFilter(Anime anime)` <a id="_matchesrankingtimefilter"></a>
- **Kind:** method of `_StatisticsPageState`
- **Source:** `lib/features/anime/views/statistics_page.dart` (line 901)
- **Purpose:** Decide whether one anime is included under the ranking view's current time filter.
- **Inputs:** `anime`.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** `switch` on `_rankingTimeFilter`:
  1. `all` → always `true`.
  2. `quarter` → `anime.airsInQuarter(_rankingSelectedYear, _rankingSelectedQuarter)`.
  3. `year` → `true` if `anime.airsInQuarter(_rankingSelectedYearOnly, q)` for any `q` in `1..4`.
  4. `custom` → convert the start/end `(year, quarter)` pairs to compact indices via
     `_quarterIndex`, swap them locally if `end < start`, then loop every index in
     `[start, end]`, converting back via `_quarterFromIndex` and returning `true` on the first
     quarter the anime airs in.
- **Usage:**
  ```dart
  final filtered = _allAnime.where((anime) {
    if (!_matchesRankingTimeFilter(anime)) return false;
    ...
  }).toList();
  ```
  (from `_rankingAnime`, same file, lines 200-201)
- **Notes:** The `custom` branch re-derives a normalized `[start, end]` locally on every call rather
  than relying on `_normalizeRankingCustomRange` having already run, so results stay correct even if
  the stored start/end were left swapped.

### `Map<AnimeViewingStatus, List<Anime>> get _groupedAnime` <a id="_groupedanime"></a>
- **Kind:** getter of `_StatisticsPageState`
- **Source:** `lib/features/anime/views/statistics_page.dart` (line 936)
- **Purpose:** Partition the current scope's filtered anime into the four derived viewing-status
  buckets shown in the summary view's expandable lists.
- **Inputs:** None.
- **Returns:** `Map<AnimeViewingStatus, List<Anime>>`.
- **Side effects:** None.
- **Algorithm:** Pre-seed a map with empty lists for `watching`/`completed`/`dropped`/`notStarted`
  (in that insertion order); iterate `_filteredAnime` and append each anime to
  `map[anime.viewingStatus]`.
- **Usage:**
  ```dart
  final grouped = _groupedAnime;
  ```
  (from `build`, same file, line 1490; also used in `_shareStatistics` before filtering to the
  user-selected statuses, line 836)
- **Notes:** Relies entirely on `Anime.viewingStatus` for the completed/watching/dropped/notStarted
  classification — this getter does no status inference of its own. See
  [`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md) /
  [`../../../../data-formats.md`](../../../../data-formats.md).

### `void _prevPeriod()` <a id="_prevperiod"></a>
- **Kind:** method of `_StatisticsPageState`
- **Source:** `lib/features/anime/views/statistics_page.dart` (line 956)
- **Purpose:** Step the active period (ranking quarter/year filter, or summary quarter/year scope)
  back by one, with quarter/year rollover.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** `setState` mutates the relevant selected-year/quarter field(s); may re-scroll
  the trend chart.
- **Algorithm (inside one `setState`):**
  1. Ranking view + `quarter` time filter → decrement `_rankingSelectedQuarter`; if it drops below
     1, wrap to 4 and decrement `_rankingSelectedYear`.
  2. Else ranking view + `year` time filter → decrement `_rankingSelectedYearOnly`.
  3. Else summary scope `quarter` → decrement `_selectedQuarter` with the same wraparound onto
     `_selectedYear`; mark `shouldScrollSummaryTrend`.
  4. Else summary scope `year` → decrement `_selectedYearOnly`; mark `shouldScrollSummaryTrend`.
  5. After `setState`, if `shouldScrollSummaryTrend`, call `_scrollTrendToFocused()`.
- **Usage:**
  ```dart
  IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevPeriod),
  ```
  (from `build`, same file, line 1581, and from `_buildRankingFilters`, line 1782)
- **Notes:** Ranking's `all`/`custom` time filters have no single period to step, so in those cases
  (and whenever `_view`/`_scope` don't match one of the four branches above) this method is a no-op
  aside from the empty `setState` call.

### `void _nextPeriod()` <a id="_nextperiod"></a>
- **Kind:** method of `_StatisticsPageState`
- **Source:** `lib/features/anime/views/statistics_page.dart` (line 989)
- **Purpose:** Step the active period (ranking quarter/year filter, or summary quarter/year scope)
  forward by one, with quarter/year rollover.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** `setState` mutates the relevant selected-year/quarter field(s); may re-scroll
  the trend chart.
- **Algorithm:** Mirrors `_prevPeriod` with increment instead of decrement: quarter counters wrap
  from 4 back to 1 while incrementing the paired year; year-only counters simply increment.
- **Usage:**
  ```dart
  IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextPeriod),
  ```
  (from `build`, same file, line 1600, and from `_buildRankingFilters`, line 1804)
- **Notes:** Same scope/view applicability caveat as `_prevPeriod`.

### `(int, int) get _availableYearRange` <a id="_availableyearrange"></a>
- **Kind:** getter of `_StatisticsPageState`
- **Source:** `lib/features/anime/views/statistics_page.dart` (line 1022)
- **Purpose:** Build the selectable year range for the summary and ranking year/quarter picker
  dialogs.
- **Inputs:** None.
- **Returns:** `(int, int)` — `(minYear, maxYear)`.
- **Side effects:** None.
- **Algorithm:**
  1. Collect every distinct `startQuarter.$1` (start year) across `_allAnime` into a `Set<int>`.
  2. Add `now.year`, `now.year + 1`, and every currently-selected year field (`_selectedYear`,
     `_selectedYearOnly`, `_rankingSelectedYear`, `_rankingSelectedYearOnly`, `_rankingStartYear`,
     `_rankingEndYear`) so pickers always include whatever is presently selected.
  3. Return `(min, max)` of the resulting set via `reduce`.
- **Usage:**
  ```dart
  final range = _availableYearRange;
  ```
  (from `_pickSummaryQuarter`, `_pickSummaryYear`, `_pickRankingQuarter`, `_pickRankingYear`,
  `_pickRankingRangeStart`, and `_pickRankingRangeEnd`, same file)
- **Notes:** Includes anime data years, "current context" (this year and next), and every current
  selection, so the range never accidentally excludes a year already chosen somewhere in the UI.

### `void _normalizeRankingCustomRange()` <a id="_normalizerankingcustomrange"></a>
- **Kind:** method of `_StatisticsPageState`
- **Source:** `lib/features/anime/views/statistics_page.dart` (line 1296)
- **Purpose:** Swap the custom ranking range's start/end quarters if they were left in reverse
  order.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Mutates `_rankingStartYear`/`_rankingStartQuarter`/`_rankingEndYear`/
  `_rankingEndQuarter` in place when out of order.
- **Algorithm:**
  1. Compute `startIdx`/`endIdx` via `_quarterIndex` for the current start/end.
  2. If `endIdx >= startIdx`, return (already in order).
  3. Otherwise swap the year/quarter pairs so start always precedes end.
- **Usage:**
  ```dart
  setState(() {
    _rankingStartYear = selected.year;
    _rankingStartQuarter = selected.quarter;
    _normalizeRankingCustomRange();
  });
  ```
  (from `_pickRankingRangeStart`, same file, lines 1143-1147; called analogously from
  `_pickRankingRangeEnd`)
- **Notes:** Runs inside the same `setState` as the picker's assignment, so the UI never briefly
  shows a reversed range. `_matchesRankingTimeFilter`'s `custom` branch additionally re-normalizes
  locally, so this method is a UX/state-consistency convenience rather than a correctness
  requirement for filtering itself.

### `static int _quarterIndex(int year, int quarter)` <a id="_quarterindex"></a>
- **Kind:** static method of `_StatisticsPageState`
- **Source:** `lib/features/anime/views/statistics_page.dart` (line 1314)
- **Purpose:** Encode a `(year, quarter)` pair as a single comparable/steppable integer.
- **Inputs:** `year`; `quarter` (1-4).
- **Returns:** `int` — `year * 4 + quarter`.
- **Side effects:** None.
- **Algorithm:** `year * 4 + quarter`.
- **Usage:**
  ```dart
  var startIdx = _quarterIndex(_rankingStartYear, _rankingStartQuarter);
  ```
  (from `_matchesRankingTimeFilter`'s `custom` branch, `_normalizeRankingCustomRange`, and
  `_quarterTrendData`)
- **Notes:** Used throughout the file as the compact "timeline position" for quarters — comparing,
  min/max-ing, and iterating a quarter range all reduce to integer arithmetic on this index.

### `static (int, int) _quarterFromIndex(int index)` <a id="_quarterfromindex"></a>
- **Kind:** static method of `_StatisticsPageState`
- **Source:** `lib/features/anime/views/statistics_page.dart` (line 1321)
- **Purpose:** Decode a compact quarter index back into a `(year, quarter)` pair.
- **Inputs:** `index` — produced by `_quarterIndex`.
- **Returns:** `(int, int)` — `(year, quarter)`.
- **Side effects:** None.
- **Algorithm:** `year = (index - 1) ~/ 4`; `quarter = ((index - 1) % 4) + 1`.
- **Usage:**
  ```dart
  final (year, quarter) = _quarterFromIndex(idx);
  ```
  (from `_matchesRankingTimeFilter`'s `custom` branch, same file, line 924; also used in
  `_quarterTrendData` to expand an index range back into entries)
- **Notes:** Must stay the exact inverse of `_quarterIndex`'s `year * 4 + quarter` convention — the
  two are only ever used together.

### `List<_TrendEntry> get _trendData` <a id="_trenddata"></a>
- **Kind:** getter of `_StatisticsPageState`
- **Source:** `lib/features/anime/views/statistics_page.dart` (line 1334)
- **Purpose:** Build the trend chart data for the active summary scope, and — for the "all" scope —
  the currently selected trend granularity.
- **Inputs:** None.
- **Returns:** `List<_TrendEntry>`.
- **Side effects:** None.
- **Algorithm:** `switch` on `_scope`:
  1. `quarter` → `_quarterTrendData(includeFocused: true)`.
  2. `year` → `_yearTrendData(includeFocused: true)`.
  3. `all` → `switch` on `_allTrendGranularity`: `quarter` → `_quarterTrendData(includeFocused:
     false)`; `year` → `_yearTrendData(includeFocused: false)`.
- **Usage:**
  ```dart
  final data = _trendData;
  if (data.isEmpty) return const SizedBox.shrink();
  ```
  (from `_buildTrendChart`, same file, lines 2090-2091; also used in `_scrollTrendToFocused`)
- **Notes:** Quarter/year scopes always include the focused (currently selected) period even if it
  has no anime; the "all" scope shows only periods that actually have data.

### `List<_TrendEntry> _quarterTrendData({required bool includeFocused})` <a id="_quartertrenddata"></a>
- **Kind:** method of `_StatisticsPageState`
- **Source:** `lib/features/anime/views/statistics_page.dart` (line 1353)
- **Purpose:** Build quarter-level trend entries spanning the full known anime timeline.
- **Inputs:** `includeFocused` — whether to also widen the range to include the currently selected
  quarter.
- **Returns:** `List<_TrendEntry>`.
- **Side effects:** None.
- **Algorithm:**
  1. Start `startIndex = endIndex = _quarterIndex(currentYear, currentQuarter)` (today's quarter);
     `hasData = false`.
  2. For every anime with a non-null `startQuarter`, widen `[startIndex, endIndex]` to include its
     quarter index and set `hasData = true`.
  3. If `includeFocused`, further widen the range to include `_quarterIndex(_selectedYear,
     _selectedQuarter)`. Otherwise, if no anime had data at all, return `[]`.
  4. Build one `_quarterTrendEntry` per index from `startIndex` to `endIndex` inclusive (via
     `_quarterFromIndex`).
- **Usage:**
  ```dart
  List<_TrendEntry> get _trendData {
    switch (_scope) {
      case _TimeScope.quarter:
        return _quarterTrendData(includeFocused: true);
      ...
  ```
  (from `_trendData`, same file, lines 1336-1337)
- **Notes:** The full timeline always spans at least "today's quarter" even with no data, so a
  brand-new library still shows one bar.

### `List<_TrendEntry> _yearTrendData({required bool includeFocused})` <a id="_yeartrenddata"></a>
- **Kind:** method of `_StatisticsPageState`
- **Source:** `lib/features/anime/views/statistics_page.dart` (line 1388)
- **Purpose:** Build year-level trend entries spanning the full known anime timeline.
- **Inputs:** `includeFocused` — whether to also widen the range to include the currently selected
  year.
- **Returns:** `List<_TrendEntry>`.
- **Side effects:** None.
- **Algorithm:** Same shape as `_quarterTrendData` but at year granularity: start from
  `[now.year, now.year]`, widen over every anime's `startQuarter.$1`, optionally widen further to
  include `_selectedYearOnly`, then build one `_yearTrendEntry` per year in range (or `[]` if
  `!includeFocused && !hasData`).
- **Usage:**
  ```dart
  case _TimeScope.year:
    return _yearTrendData(includeFocused: true);
  ```
  (from `_trendData`, same file, lines 1338-1339)
- **Notes:** See `_quarterTrendData`'s notes — the same "always at least the current period" and
  "empty when unfocused and dataless" behavior applies.

### `_TrendEntry _quarterTrendEntry((int, int) yearQuarter)` <a id="_quartertrendentry"></a>
- **Kind:** method of `_StatisticsPageState`
- **Source:** `lib/features/anime/views/statistics_page.dart` (line 1419)
- **Purpose:** Build one quarter-level trend entry (tracked/completed/dropped counts).
- **Inputs:** `yearQuarter` — a `(year, quarter)` pair.
- **Returns:** `_TrendEntry`.
- **Side effects:** None.
- **Algorithm:**
  1. Filter `_allAnime` to those where `airsInQuarter(yearQuarter.$1, yearQuarter.$2)`.
  2. `tracked` = that list's length; `completed`/`dropped` = counts within it matching the
     corresponding `AnimeViewingStatus`.
- **Usage:**
  ```dart
  return [
    for (var index = startIndex; index <= endIndex; index++)
      _quarterTrendEntry(_quarterFromIndex(index)),
  ];
  ```
  (from `_quarterTrendData`, same file, lines 1377-1380)
- **Notes:** Counts anime via `airsInQuarter`, which accounts for multi-cour spans — a
  multi-quarter anime is counted in every quarter it airs in, not only its start quarter. See
  [`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md).

### `_TrendEntry _yearTrendEntry(int year)` <a id="_yeartrendentry"></a>
- **Kind:** method of `_StatisticsPageState`
- **Source:** `lib/features/anime/views/statistics_page.dart` (line 1441)
- **Purpose:** Build one year-level trend entry (tracked/completed/dropped counts).
- **Inputs:** `year`.
- **Returns:** `_TrendEntry` (with `quarter: 0`, used as the year-scope sentinel).
- **Side effects:** None.
- **Algorithm:**
  1. Filter `_allAnime` to those airing in any of the year's four quarters (loop `q = 1..4`,
     short-circuit on first match) — so a multi-quarter anime counts once per year, not once per
     quarter.
  2. `tracked` = that list's length; `completed`/`dropped` = counts within it matching the
     corresponding `AnimeViewingStatus`.
- **Usage:**
  ```dart
  return [
    for (var year = startYear; year <= endYear; year++) _yearTrendEntry(year),
  ];
  ```
  (from `_yearTrendData`, same file, line 1410)
- **Notes:** The `quarter: 0` field is how `_focusedTrendIndex` and `_TrendEntry` distinguish
  year-level entries from quarter-level ones sharing the same `year`.

### `int? _focusedTrendIndex(List<_TrendEntry> data)` <a id="_focusedtrendindex"></a>
- **Kind:** method of `_StatisticsPageState`
- **Source:** `lib/features/anime/views/statistics_page.dart` (line 1466)
- **Purpose:** Locate the trend entry matching the currently selected summary period, if any.
- **Inputs:** `data` — the trend entries to search (typically the result of `_trendData`).
- **Returns:** `int?` — the matching index, or `null` if none (or in the `all` scope).
- **Side effects:** None.
- **Algorithm:** `switch` on `_scope`: `quarter` → `data.indexWhere` matching both `_selectedYear`
  and `_selectedQuarter`; `year` → `data.indexWhere` matching `_selectedYearOnly` with `quarter ==
  0`; `all` → `-1` (no focus). Converts any `-1` result to `null`.
- **Usage:**
  ```dart
  final focusedIndex = _focusedTrendIndex(data);
  ```
  (from `_scrollTrendToFocused` and `_buildTrendChart`, same file)
- **Notes:** The `all` scope has no single focused period by design (it shows the whole timeline
  at the user-chosen granularity), so it always returns `null` regardless of `data`'s contents.

