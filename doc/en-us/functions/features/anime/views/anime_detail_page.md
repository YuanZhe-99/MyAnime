# lib/features/anime/views/anime_detail_page.dart

`AnimeDetailPage` is the read/act page for one tracked anime: cover, metadata chips, rating
summary, local-archive summary, the series card with prev/next-season navigation, and the per-episode watch-status list
with schedule-shift controls. It reads and writes through `AnimeStorage` ([`../services/anime_storage.md`](../services/anime_storage.md))
and operates on the `Anime`/`AnimeRating`/`AnimeLocalArchive` model
([`../models/anime.md`](../models/anime.md)), rendering the archive enums through
[`archive_labels.md`](archive_labels.md). The archive card is display-only and deliberately absent
from the shared image card this page's Share action produces — see
[`../../../../features/share-and-import.md`](../../../../features/share-and-import.md). See
[`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md) for the episode
air-date/rollover and schedule-shift semantics this page exposes controls for.


## Layout

The page renders in one of two layouts, chosen per frame from the viewport size by
`useDetailTwoPane` in [`../../../shared/utils/detail_layout.md`](../../../shared/utils/detail_layout.md):

- **Single column** — one `ListView`: cover, then the info block (Japanese title, chips, progress
  bar, `watched / total`, the rating / database / archive cards, notes, the series card and
  prev/next season), then the episode list. This is the original layout, unchanged.
- **Two panes** — a `Row`. The left pane is fixed-width and full-height, holding the cover through
  the watch-progress label, with the cover sized by `detailCoverSize` from whatever height is left
  over. The right pane is an independently scrolling `ListView` holding everything from the cards
  down, including the series card and the episode list.

The series card (1.6.0, `SeriesCard` in [`series_widgets.md`](series_widgets.md)) replaced the old
prev/next row in the same place in `_buildDetailChildren`, so in the two-pane layout it lands in the
right pane. It appears only when the record's series has at least two members; the prev/next buttons
below it, now driven by the series order, sit in a `Wrap` so they stack rather than overflow on a
narrow phone. Since 1.6.1 a member row and the prev/next buttons `context.push` the other record's
detail page rather than `context.go` to it, so back returns to the record the user came from. When the record belongs to no series — including a standalone one — the card is
absent and an app-bar link menu (*Link to series…*, *Add next season*, and *Let the app decide* when
the record carries a `seriesLink`) reaches the same actions. Directly above the series card sits the
missing-sequel hint (1.6.0 M2): a card reading "Next: <title> (<source>)" when a database lists a
sequel of the series' last member that is not in the library. Unlike the series card it also appears
for a record in no series. See
[`../../../../features/series-linking.md`](../../../../features/series-linking.md).

While recommendations are on (1.6.2), `_buildDetailChildren` places the **Related** card
(`RelatedRecommendationsCard`, [`../../recommendations/views/related_card.md`](../../recommendations/views/related_card.md))
after the notes and before the missing-sequel hint, so in the two-pane layout it lands in the right
pane. It is keyed by the record id, receives the library `_load` read, and owns its own loading,
persistence, refresh and trash; the page only decides whether it appears. See
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md#related-recommendations-on-the-detail-page).

While automatic categories are on (1.6.0 M4), `_buildHeaderChildren` adds a row of category chips
(`CategoryChips` in [`category_widgets.md`](category_widgets.md)) between the chips and the progress
bar, so in the two-pane layout they stay in the left pane. Its edit chip opens the category editor.
See [`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md).

Both layouts are assembled from the same four builders — `_buildCover`, `_buildHeaderChildren`,
`_buildDetailChildren`, `_buildEpisodeChildren` — so there is exactly one copy of each section's
widget code. The split between `_buildHeaderChildren` and `_buildDetailChildren` *is* the pane
boundary: move a section across that seam and it changes column. Each entry in
`_buildDetailChildren` carries its own leading `SizedBox(height: 12)`, which is what lets the same
list read correctly whether it follows the progress bar or opens the right pane.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `AnimeDetailPage.new` | constructor (`AnimeDetailPage`) | B | Create an `AnimeDetailPage` instance for a given anime ID. |
| `AnimeDetailPage.createState` | method (`AnimeDetailPage`) | B | Create the mutable state object for this widget. |
| `_AnimeDetailPageState.initState` | method (`_AnimeDetailPageState`) | B | Trigger the first data load. |
| [`_load`](#_load) | method (`_AnimeDetailPageState`) | A | Load this anime and build the series index to find the series it belongs to. |
| [`didUpdateWidget`](#didupdatewidget) | method (`_AnimeDetailPageState`) | A | Reload when the page is rebuilt for a different record. |
| [`_editCategories`](#_editcategories) | method (`_AnimeDetailPageState`) | A | Let the user set this record's categories. |
| [`_addMissingSequel`](#_addmissingsequel) | method (`_AnimeDetailPageState`) | A | Open the create page for a sequel the databases list but the library lacks. |
| [`_runSeriesAction`](#_runseriesaction) | method (`_AnimeDetailPageState`) | A | Run one of the series card's (or the app-bar link menu's) actions. |
| [`_toggleEpisode`](#_toggleepisode) | method (`_AnimeDetailPageState`) | A | Cycle one episode's watch status and persist it. |
| [`_shiftFromEpisode`](#_shiftfromepisode) | method (`_AnimeDetailPageState`) | A | Shift an episode's broadcast week by a delta and persist it. |
| [`_resetSchedule`](#_resetschedule) | method (`_AnimeDetailPageState`) | A | Clear all per-episode week offsets back to the original schedule. |
| [`_delete`](#_delete) | method (`_AnimeDetailPageState`) | A | Confirm and delete this anime record. |
| `_AnimeDetailPageState.build` | method (`_AnimeDetailPageState`, widget build) | B | Build the detail page scaffold, choosing the single-column or two-pane layout. |
| `_buildCover` | method (widget helper) | B | Build the cover image block at an explicit size. |
| `_buildHeaderChildren` | method (widget helper) | B | Build the header block: Japanese title, chips (including the anime1.me progress chip), the category chips while automatic categories are on, and the watched-episode bar. |
| `_buildDetailChildren` | method (widget helper) | B | Build the cards below the progress bar, plus the related card (1.6.2, while recommendations are on), the missing-sequel hint, the series card and prev/next buttons. |
| `_buildEpisodeChildren` | method (widget helper) | B | Build the episode list header and one row per tracked episode. |
| [`_toggleAllWatched`](#_toggleallwatched) | method (`_AnimeDetailPageState`) | A | Mark every tracked episode watched, or all unwatched if already complete. |
| `_buildAbandonOrResume` | method (widget helper) | B | Render the "Abandon"/"Resume" action button for the episode list header. |
| [`_refreshableUrls`](#_refreshableurls) | method (`_AnimeDetailPageState`) | A | List the source pages this anime can be refreshed from. |
| [`_refreshExternalMeta`](#_refreshexternalmeta) | method (`_AnimeDetailPageState`) | A | Re-fetch external metadata from every remembered source page. |
| `_watchProgressChipLabel` | method (`_AnimeDetailPageState`) | B | Label the anime1.me chip from the stored watch progress, or the "check" prompt. |
| [`_checkWatchProgress`](#_checkwatchprogress) | method (`_AnimeDetailPageState`) | A | Re-read what anime1.me lists for this record's URL and store it. |
| [`_buildExternalMetaCard`](#_buildexternalmetacard) | method (widget helper) | A | Render the public metadata pulled from external databases. |
| `_buildRatingCard` | method (widget helper) | B | Render the user's own rating summary card. |
| `_buildLocalArchiveCard` | method (widget helper) | B | Render the read-only local-archive summary card. |
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
- **Source:** `lib/features/anime/views/anime_detail_page.dart` (approx. line 89)
- **Purpose:** Load the anime identified by `widget.animeId` and the series it belongs to.
- **Inputs:** None (`widget.animeId` is read from the enclosing widget).
- **Returns:** `Future<void>`.
- **Side effects:** Calls `AnimeStorage.loadFixingSeasonLabels(seasonLabelFixups)` (1.6.1), which may
  rewrite default season labels without touching `modifiedAt`, `AnimeStorage.getAutoCategoriesEnabled()` and, only
  while that and on-device AI (`AnimeStorage.getOnDeviceAiEnabled()`) are both on,
  `AiInsightsCache.load()`, and `AnimeStorage.getRecommendationsEnabled()` (1.6.2); `setState`s
  `_anime`, `_seriesIndex`, `_series`, `_missingSequel`, `_categoriesOn`, `_categories`,
  `_recommendationsOn` and `_library`. Writes nothing else; the related card writes
  `recommendations.json` itself.
- **Algorithm:**
  1. Await [`AnimeStorage.loadFixingSeasonLabels`](../services/anime_storage.md#loadfixingseasonlabels)`(seasonLabelFixups)`
     and find the record whose `id == widget.animeId`.
  2. Build a [`SeriesIndex`](../services/series_service.md#seriesindex-build) over the whole
     library and ask it for the record's series.
  3. `setState` with the record, the index, and the series — but only when that series has at
     least two members; otherwise `_series` is `null` and the series card is not shown. Also store
     [`missingSequelFor`](../services/series_service.md#missingsequelfor) as `_missingSequel`,
     which drives the missing-sequel hint.
  4. Store the automatic-categories switch as `_categoriesOn` and
     [`resolveCategories`](../../categories/services/category_service.md#resolvecategories) of the
     record (with the AI cache when it was read) as `_categories`.
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
- **Notes:** Until 1.6.0 this matched records with an identical `displayTitle` and compared their
  `season` labels with a plain `String.compareTo`, which put `"Season 10"` before `"Season 2"` and
  never found a sequel whose title differed at all. It no longer compares strings: order comes from
  the series index (explicit `order`, then `firstAirDate`, season ordinal, `createdAt`, `id`), and
  the old identical-title rule survives only as one of the index's grouping edges. See
  [`../../../../features/series-linking.md`](../../../../features/series-linking.md). Since 1.6.1
  it loads through `loadFixingSeasonLabels`, so a record whose titles name a later season shows
  `Season N` instead of the default `Season 1`.

### `void didUpdateWidget(covariant AnimeDetailPage oldWidget)` <a id="didupdatewidget"></a>
- **Kind:** method of `_AnimeDetailPageState` (Flutter lifecycle override)
- **Source:** `lib/features/anime/views/anime_detail_page.dart` (approx. line 76)
- **Purpose:** Reload when the page is rebuilt for a different record.
- **Inputs:** `oldWidget`.
- **Returns:** None.
- **Side effects:** Calls [`_load`](#_load) when `animeId` changed.
- **Notes:** Added in 1.6.1. The `/anime/detail/:id` route keys the page by `ValueKey(id)`
  ([`../../../app/router.md`](../../../app/router.md)), so this is a safety net: before 1.6.1,
  `context.go` between seasons reused one State and left the first-opened record on screen.

### `Future<void> _editCategories()` <a id="_editcategories"></a>
- **Kind:** method of `_AnimeDetailPageState`
- **Source:** `lib/features/anime/views/anime_detail_page.dart` (approx. line 108)
- **Purpose:** Let the user set this record's categories.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** May call `AnimeStorage.addOrUpdate` (a user edit, `modifiedAt` stamped in UTC);
  reloads via `_load()`.
- **Algorithm:**
  1. Open [`showCategoryEditor`](category_widgets.md#showcategoryeditor) with the effective ids and
     `hasOverride: anime.categories != null`. Dismissed → return.
  2. `CategoriesChosen(ids)` → `copyWith(categories: [...ids, ...unknown])`, where `unknown` is every
     id in the record's own list that this build does not know, so a newer build's ids survive.
     An empty choice writes `[]`.
  3. `CategoriesReset` → `copyWith(clearCategories: true)`, returning the record to automatic.
  4. Save with `AnimeStorage.addOrUpdate`, then `_load()`.
- **Usage:** `CategoryChips(categories: _categories, onEdit: _editCategories)` in
  `_buildHeaderChildren`.
- **Notes:** The editor starts from the *effective* ids, so saving without a change turns mapped or
  AI categories into the user's own. The write is an ordinary user edit and syncs like one.

### `Future<void> _addMissingSequel(AnimeExternalRelation relation)` <a id="_addmissingsequel"></a>
- **Kind:** method of `_AnimeDetailPageState`
- **Source:** `lib/features/anime/views/anime_detail_page.dart` (approx. line 93)
- **Purpose:** Open the create page for a sequel the databases list but the library lacks.
- **Inputs:** `relation` — the `sequel` from `_missingSequel`.
- **Returns:** `Future<void>`.
- **Side effects:** Pushes `/anime/edit`; reloads via `_load()` when it returns.
- **Algorithm:** Returns early without `_anime`; otherwise pushes
  `context.push('/anime/edit', extra: NextSeasonPrefill.fromRelation(last, relation))`, where
  `last` is the series' last member (or this record when there is no series).
- **Usage:** The missing-sequel hint card's `onTap` in `_buildDetailChildren`, same file.
- **Notes:** Full builds also start the online search on the create page; store builds get the title
  pre-filled only — see
  [`NextSeasonPrefill.fromRelation`](../services/series_service.md#nextseasonprefill-fromrelation).
  The new record is linked to `last` only when the user saves it.

### `Future<void> _runSeriesAction(SeriesAction action)` <a id="_runseriesaction"></a>
- **Kind:** method of `_AnimeDetailPageState`
- **Source:** `lib/features/anime/views/anime_detail_page.dart` (approx. line 111)
- **Purpose:** Run one of the series card's menu actions, or the app-bar link menu's when the
  record is in no series.
- **Inputs:** `action` — a `SeriesAction` ([`series_widgets.md`](series_widgets.md)).
- **Returns:** `Future<void>`.
- **Side effects:** May write records through `AnimeStorage.addOrUpdateAll`, open the manage sheet or
  the create page, and reload via `_load()`.
- **Algorithm:** Returns early until `_anime` and `_seriesIndex` are loaded; then, with a
  `SeriesEditor` over the current index:
  - `manage` → `showSeriesManageSheet`; reload only when it reports a write.
  - `addNextSeason` → `context.push('/anime/edit', extra: NextSeasonPrefill.after(last))`, where
    `last` is the series' last member (or this record when there is no series); reload on return.
  - `remove` → `addOrUpdateAll(editor.removeFromSeries(anime))`, then reload.
  - `letAppDecide` → `addOrUpdateAll(editor.letAppDecide(anime))`, then reload.
- **Usage:**
  ```dart
  SeriesCard(
    series: series,
    current: anime,
    onOpen: (a) => context.push('/anime/detail/${a.id}'),
    onAction: _runSeriesAction,
  ),
  ```
  (`_buildDetailChildren`, same file; the app bar's `PopupMenuButton<SeriesAction>` also calls it)
- **Notes:** Every write is a user edit stamped by `SeriesEditor` — see
  [`../services/series_service.md`](../services/series_service.md#serieseditor).

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

### `List<String> _refreshableUrls(Anime anime)` <a id="_refreshableurls"></a>
- **Kind:** method of `_AnimeDetailPageState`
- **Source:** `lib/features/anime/views/anime_detail_page.dart` (line 616)
- **Purpose:** List the source pages this anime can be refreshed from.
- **Inputs:** `anime`.
- **Returns:** `List<String>` — deduplicated, blanks dropped.
- **Side effects:** None.
- **Algorithm:** Delegates to `MetadataUpdateService.refreshableUrls`, which unions `infoUrl` with the `sourceUrl` of every entry in `externalMeta.ratings`.
- **Notes:** Combining both is what makes a record built from several sources refresh all of them. It also doubles as the visibility test for the refresh chip: an empty list means there is nothing to re-query, so the chip is not rendered at all. As of 1.5.0 the logic lives in the background updater and is shared, so the manual chip and the background refresh queue cannot disagree about what "refreshable" means.

### `Future<void> _refreshExternalMeta(Anime anime)` <a id="_refreshexternalmeta"></a>
- **Kind:** method of `_AnimeDetailPageState`
- **Source:** `lib/features/anime/views/anime_detail_page.dart` (approx. line 851)
- **Purpose:** Re-fetch external metadata from every remembered source page.
- **Inputs:** `anime`.
- **Returns:** None.
- **Side effects:** Issues HTTP requests via `AnimeSearchService.refreshAll`, writes the updated anime through `AnimeStorage.patchExternalMeta`, reloads the page, and shows a snack bar with the outcome.
- **Algorithm:**
  1. Bail out with a "no refreshable source" message when [`_refreshableUrls`](#_refreshableurls) is empty.
  2. `await AnimeSearchService.refreshAll(urls)`; a fully empty result is reported the same way rather than treated as success.
  3. Fold each fetched result into the existing `externalMeta` with `AnimeExternalMeta.mergedWith`, stamping one shared UTC `now` as both `fetchedAt` and `refreshedAt`.
  4. Save via `AnimeStorage.patchExternalMeta({anime.id: merged})`, reload, and confirm.

  Since 1.6.0 the fetched results carry each source's `relations`, which `mergedWith` replaces per
  source; the reload then recomputes the series index, so a new relation can link a series or show
  the missing-sequel hint straight away.
- **Notes:** **Only external metadata is touched.** The user's own `rating`, episode progress, and manual edits are left exactly as they are — that separation is the whole reason external scores live in `externalMeta.ratings` rather than in `AnimeRating`. Callers must gate on `AppFlavor.isFull`, since store builds do not ship online lookups; see [`../../../../features/multi-source-search.md`](../../../../features/multi-source-search.md).

  Until 1.5.0 step 4 was `copyWith(externalMeta: merged, modifiedAt: now)`, which bumped
  `modifiedAt`. That carried the same hazard as a background refresh would: because `mergeRecords`
  reads "changed" only from `modifiedAt` versus the sync base, a refreshed record could survive a
  deletion made on another device. `patchExternalMeta` leaves the timestamp alone. See
  [`../../../../sync.md`](../../../../sync.md).

### `Widget _buildExternalMetaCard(AnimeExternalMeta meta, ThemeData theme, AppLocalizations l10n)` <a id="_buildexternalmetacard"></a>
- **Kind:** method of `_AnimeDetailPageState` (widget helper)
- **Source:** `lib/features/anime/views/anime_detail_page.dart` (line 691)
- **Purpose:** Render the public metadata pulled from external databases.
- **Returns:** `Widget`.
- **Side effects:** None.
- **Algorithm:** A card headed by the source icon, the section title, and the localized `refreshedAt` date; then a label/value row for each supplied field (format, status, duration, last air date, studios, genres, alternate titles); then, when any rating has a score, a divider, the "external ratings" heading, an explanatory line, and one chip per source showing `source score/max · votes`.
- **Notes:** Sits directly below the personal rating card and is styled to read as a separate block on purpose — the explanatory line under the ratings heading exists so nobody mistakes an external score for their own. The card itself is **not** flavor-gated: displaying already-synced data is not a network feature, and a store build can legitimately receive this data through WebDAV sync or an imported share file.

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

### `Future<void> _checkWatchProgress(Anime anime)` <a id="_checkwatchprogress"></a>
- **Kind:** method of `_AnimeDetailPageState`
- **Source:** `lib/features/anime/views/anime_detail_page.dart` (approx. line 816)
- **Purpose:** Re-read what anime1.me currently lists for this record's watch URL and store it.
- **Inputs:** `anime`.
- **Returns:** `Future<void>`.
- **Side effects:** Up to three HTTP requests via `Anime1Service.fetchProgress`; a write through
  `AnimeStorage.patchExternalMeta`; `setState`s `_checkingProgress`; a snack bar on failure.
- **Algorithm:**
  1. Return when there is no watch URL; set the chip's spinner.
  2. Await `Anime1Service.fetchProgress(url)`; `null` → snack bar `anime1ProgressUnknown`.
  3. Otherwise merge the record into `externalMeta` via `mergedWith(AnimeExternalMeta(watchProgress: …))`, write it with `patchExternalMeta`, and `_load()`.
  4. Any exception → snack bar `anime1ProgressFailed`; the spinner is always cleared when mounted.
- **Usage:**
  ```dart
  onPressed: AppFlavor.isFull && !_checkingProgress
      ? () => _checkWatchProgress(anime)
      : null,
  ```
  (`_buildHeaderChildren`, the anime1.me chip — the chip itself renders in every flavor)
- **Notes:** Like `_refreshExternalMeta`, this never bumps `modifiedAt`: the progress is a cache of
  public site data, not a user edit. The chip's label comes from `_watchProgressChipLabel`, which
  reads `Anime.validWatchProgress`, so a URL edited after the last check shows the "check" prompt
  rather than a stale count.
