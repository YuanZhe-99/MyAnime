# lib/features/anime/views/anime_search_dialog.dart

The online metadata search dialog. `showAnimeSearchDialog` opens a two-phase modal: a **search
phase** listing hits from every source in
[`../services/anime_search_service.md`](../services/anime_search_service.md), and a **preview phase**
where the user checks which fields of one chosen result to apply. It returns a `Map<String, dynamic>`
of field names → values, which `anime_edit_page.dart` writes into its form controllers.

The dialog is only reachable from `anime_edit_page.dart`, which gates it behind `AppFlavor.isFull` —
see the flavor-gating rule in
[`../../../../features/multi-source-search.md`](../../../../features/multi-source-search.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`showAnimeSearchDialog`](#showanimesearchdialog) | top-level function | A | Open the search dialog and return the fields to apply. |
| `_SearchDialog(...)` | constructor (`_SearchDialog`) | B | Hold the current field values shown as "Current" in the preview. |
| `createState` | method (`_SearchDialog`) | B | Flutter lifecycle override. |
| `initState` | method (`_SearchDialogState`) | B | Seed the query controller from `initialQuery`. |
| `dispose` | method (`_SearchDialogState`) | B | Dispose the query controller. |
| [`_search`](#search) | method (`_SearchDialogState`) | A | Run the search, showing results as each source answers, and reset the result-list controls. |
| [`_visibleResults`](#visibleresults) | getter (`_SearchDialogState`) | A | Apply the active filters and sort order to the raw result list. |
| [`_availableSources`](#availablesources) | getter (`_SearchDialogState`) | A | List the source names present in the current raw results. |
| [`_selectResult`](#selectresult) | method (`_SearchDialogState`) | A | Enter the preview phase with per-field checkboxes pre-set. |
| [`_externalMetaFieldCount`](#externalmetafieldcount) | method (`_SearchDialogState`) | A | Count how many external-metadata fields a result actually carries. |
| `_fetchCover` | method (`_SearchDialogState`) | B | Download the cover image and show a before/after preview. |
| [`_apply`](#apply) | method (`_SearchDialogState`) | A | Close the dialog with the checked field values. |
| `build` | method (`_SearchDialogState`) | B | Render the search or preview phase. |
| `_buildSearchView` | method (`_SearchDialogState`) | B | Query field, search button, the compact progress strip while partial results are shown (1.6.1), toolbar, and result list. |
| [`_buildResultToolbar`](#buildresulttoolbar) | method (`_SearchDialogState`) | A | Build the sort/filter/group toolbar shown above the result list. |
| `_sortLabel` | method (`_SearchDialogState`) | B | Localized label for one `_SearchSort` value. |
| [`_showFilterSheet`](#showfiltersheet) | method (`_SearchDialogState`) | A | Show the source and field filters in a bottom sheet. |
| `_buildSearchResults` | method (`_SearchDialogState`) | B | Choose between the full progress panel (only until the first results arrive), error, empty, grouped, or flat list. |
| [`_buildSearchProgress`](#_buildsearchprogress) | method | A | Show which sources have answered while a search runs, as a full panel or a compact strip. |
| `_sourceChip` | method | B | Render one source's pending/found/failed state. |
| [`_buildGroupedResults`](#buildgroupedresults) | method (`_SearchDialogState`) | A | Render the result list as one collapsible section per source. |
| [`_resultTile`](#resulttile) | method (`_SearchDialogState`) | A | Build one row of the search result list. |
| [`_secondaryLine`](#secondaryline) | method (`_SearchDialogState`) | A | Compose the secondary metadata line shown under a result. |
| [`_showResultDetails`](#showresultdetails) | method (`_SearchDialogState`) | A | Show every title and field a result carries, untruncated. |
| [`_detailRows`](#detailrows) | method (`_SearchDialogState`) | A | Build the labelled metadata rows for the result detail sheet. |
| `_copyToClipboard` | method (`_SearchDialogState`) | B | Copy one value and confirm with a snack bar. |
| `_buildPreviewView` | method (`_SearchDialogState`) | B | Source badge, field list, and Cancel/Apply buttons. |
| [`_buildFieldList`](#buildfieldlist) | method (`_SearchDialogState`) | A | Build the per-field checkbox list for the preview phase. |
| [`_buildExternalMetaSummary`](#buildexternalmetasummary) | method (`_SearchDialogState`) | A | Show the metadata that the external-metadata checkbox would apply. |
| `_coverColumn` | method (`_SearchDialogState`) | B | Label-over-thumbnail column. |
| `_fieldTile` | method (`_SearchDialogState`) | B | One "Current → Fetched" checkbox row. |
| `_buildHeader` | method (`_SearchDialogState`) | B | Title bar with optional back button and close button. |
| `_dayName` | method (`_SearchDialogState`) | B | Localized weekday name for `1..7`. |
| `_truncate` | method (`_SearchDialogState`) | B | Ellipsize a string at a maximum length. |

The file also declares two private enums with no doc comments: `_Phase` (`search`, `preview`) and
`_SearchSort` (`relevance`, `firstAirDate`, `episodes`, `source`). Their members carry `///`
comments; the enums themselves are counted as types rather than declarations here.

## Documentation

### `Future<Map<String, dynamic>?> showAnimeSearchDialog(BuildContext context, {initialQuery, currentTitle, currentTitleJa, currentEndEp, currentFirstAirDate, currentAirDay, currentAirTime, currentCoverImage, currentNotes, currentExternalMeta})` <a id="showanimesearchdialog"></a>
- **Kind:** top-level function
- **Source:** `lib/features/anime/views/anime_search_dialog.dart` (line 17)
- **Purpose:** Open the anime search dialog and return the fields the user chose to apply.
- **Inputs:** `initialQuery` seeds the query field; every `current*` argument is the edit form's present value, shown as "Current" beside each fetched value so the user can see what a checkbox would overwrite.
- **Returns:** `Future<Map<String, dynamic>?>` — field name → value, or `null` if cancelled.
- **Side effects:** Shows a modal dialog; the dialog itself performs network I/O.
- **Notes:** `currentExternalMeta` is not just for display — [`_apply`](#apply) folds the newly fetched metadata *into* it, so applying a second result from another source keeps what the first one contributed instead of replacing it.

### `Future<void> _search()` <a id="search"></a>
- **Kind:** method of `_SearchDialogState`
- **Source:** `lib/features/anime/views/anime_search_dialog.dart` (approx. line 164)
- **Purpose:** Run the search and reset the result-list controls.
- **Returns:** None.
- **Side effects:** Network I/O via `AnimeSearchService.searchAll`; rebuilds state as each source answers; bumps `_searchGeneration`.
- **Algorithm:**
  1. Return for a blank query or while a search is already running.
  2. Read `Localizations.localeOf(context).toLanguageTag()` as `preferredLanguage`, bump `_searchGeneration`, and define `current()` as "still mounted and still the newest search".
  3. Clear results, error and all filters, and store `AnimeSearchService.queryVariants(query)` and the language **before** the first result arrives, so partial results already sort by relevance.
  4. Await `searchAll` with `onProgress` storing `_progress` and `onResults` (1.6.1) storing `_results`, each only while `current()`.
  5. When it returns and `current()` still holds, store the final results and clear `_searching`; set `_error` to the "no results" message when the list is empty.
  6. On an exception (and `current()`), clear `_searching`; set `_error` to the exception text only when no results have arrived.
- **Notes:** The variants are cached in state deliberately — every relevance-sorted rebuild scores against them, and re-deriving them per frame would be wasteful and could drift from what the service actually searched with. Filters are reset on each new search because a source chip from the previous query may not exist in the new results. Since 1.6.1 the list is usable long before the slowest source finishes and re-sorts as more results arrive; an error after partial results keeps them. The generation guard drops callbacks from an older search that is still finishing in the background. The `int _searchGeneration` field it maintains has no `/// Purpose:` block and no row.

### `List<AnimeSearchResult> get _visibleResults` <a id="visibleresults"></a>
- **Kind:** getter of `_SearchDialogState`
- **Source:** `lib/features/anime/views/anime_search_dialog.dart` (line 200)
- **Purpose:** Apply the active filters and sort order to the raw result list.
- **Returns:** `List<AnimeSearchResult>`.
- **Side effects:** None.
- **Algorithm:** Filters out hidden sources, and (when the switches are on) results with no cover or no first air date. Then sorts by the active `_SearchSort`: `relevance` by descending `AnimeSearchService.relevance`; `firstAirDate` newest first; `episodes` highest first; `source` alphabetically with relevance as the tiebreak.
- **Notes:** For `firstAirDate` and `episodes`, results **missing** the value always sink to the bottom regardless of direction, rather than sorting as zero — an unknown episode count must never outrank a known one.

### `List<String> get _availableSources` <a id="availablesources"></a>
- **Kind:** getter of `_SearchDialogState`
- **Source:** `lib/features/anime/views/anime_search_dialog.dart` (line 249)
- **Purpose:** List the source names present in the current raw results.
- **Returns:** `List<String>` in `AnimeSearchSource.all` order.
- **Side effects:** None.
- **Notes:** Drives the filter chips, so a source that returned nothing is never offered as a filter. Ordering by the canonical list rather than by first appearance keeps the chip row stable across searches.

### `void _selectResult(AnimeSearchResult result)` <a id="selectresult"></a>
- **Kind:** method of `_SearchDialogState`
- **Source:** `lib/features/anime/views/anime_search_dialog.dart` (line 259)
- **Purpose:** Enter the preview phase with per-field checkboxes pre-set.
- **Side effects:** Rebuilds state; clears any previously fetched cover.
- **Algorithm:** Switches `_phase` to `preview` and pre-checks every field the result actually supplies — title, Japanese title, episodes, first air date, air day, air time, notes, and (when [`_externalMetaFieldCount`](#externalmetafieldcount) is non-zero) external metadata.
- **Notes:** The cover checkbox is deliberately left **off**: it requires an explicit fetch, because applying it downloads and writes an image file.

### `int _externalMetaFieldCount(AnimeSearchResult r)` <a id="externalmetafieldcount"></a>
- **Kind:** method of `_SearchDialogState`
- **Source:** `lib/features/anime/views/anime_search_dialog.dart` (line 285)
- **Purpose:** Count how many external-metadata fields a result actually carries.
- **Returns:** `int`.
- **Side effects:** None.
- **Algorithm:** Adds one for each non-empty `synonyms`, `titleRomaji`, `titleEn`, `format`, `status`, `durationMinutes`, `genres`, `studios`, `endDate`, and for the score block as a whole.
- **Notes:** Zero means the source supplied nothing beyond the basic fields, so no external-metadata checkbox is offered at all. The count is also shown in the checkbox label, so "Database info: 6 field(s) from AniList" tells the user what they are accepting without expanding anything.

### `void _apply()` <a id="apply"></a>
- **Kind:** method of `_SearchDialogState`
- **Source:** `lib/features/anime/views/anime_search_dialog.dart` (line 342)
- **Purpose:** Close the dialog with the checked field values.
- **Side effects:** Pops the dialog with the result map.
- **Algorithm:** Copies each checked field into the map. When `firstAirDate` is checked but the source reported no `airDayOfWeek`, derives the weekday from the date. When the external-metadata box is checked, builds `AnimeSearchService.toExternalMeta(r)` and folds it into `widget.currentExternalMeta` via `mergedWith`. `infoUrl` is set from `sourceUrl` unconditionally whenever one exists.
- **Notes:** `infoUrl` is not a checkbox because it records *where this metadata came from*, and the refresh flow later needs it — see [`../services/anime_search_service.md`](../services/anime_search_service.md).

### `Widget _buildResultToolbar(AppLocalizations l10n)` <a id="buildresulttoolbar"></a>
- **Kind:** method of `_SearchDialogState`
- **Source:** `lib/features/anime/views/anime_search_dialog.dart` (line 462)
- **Purpose:** Build the sort/filter/group toolbar shown above the result list.
- **Returns:** `Widget`.
- **Side effects:** None.
- **Algorithm:** A row with the "N of M results" count, a group-by-source toggle, a `PopupMenuButton<_SearchSort>`, and a filter button whose icon switches between `filter_alt_outlined` and `filter_alt` when any filter is active.
- **Notes:** Only rendered once a search has produced results, so an empty dialog stays uncluttered. The popup-menu-plus-state-dependent-icon pattern mirrors the archive filter in `management_page.dart`.

### `Future<void> _showFilterSheet(AppLocalizations l10n)` <a id="showfiltersheet"></a>
- **Kind:** method of `_SearchDialogState`
- **Source:** `lib/features/anime/views/anime_search_dialog.dart` (line 537)
- **Purpose:** Show the source and field filters in a bottom sheet.
- **Side effects:** Opens a modal sheet and mutates filter state as the user toggles.
- **Algorithm:** A `StatefulBuilder` sheet holding a `FilterChip` per entry of [`_availableSources`](#availablesources), two `SwitchListTile`s, and a reset button. A local `toggle()` helper calls **both** the parent's `setState` and the sheet's own, so the list behind the sheet updates live.
- **Notes:** Filters are stored as `_hiddenSources` (an exclusion set) rather than an inclusion set, so a source appearing in a later search is visible by default and "reset" is simply clearing the set.

### `Widget _buildGroupedResults(AppLocalizations l10n, List<AnimeSearchResult> visible)` <a id="buildgroupedresults"></a>
- **Kind:** method of `_SearchDialogState`
- **Source:** `lib/features/anime/views/anime_search_dialog.dart` (line 671)
- **Purpose:** Render the result list as one collapsible section per source.
- **Returns:** `Widget`.
- **Side effects:** None.
- **Algorithm:** Buckets `visible` by `source`, then renders an initially-expanded `ExpansionTile` per source with a per-group count in the trailing slot.
- **Notes:** Sections keep the canonical `AnimeSearchSource.all` order rather than the current sort order, so switching the sort reorders rows *within* sections without reshuffling the sections themselves.

### `Widget _resultTile(AppLocalizations l10n, AnimeSearchResult r)` <a id="resulttile"></a>
- **Kind:** method of `_SearchDialogState`
- **Source:** `lib/features/anime/views/anime_search_dialog.dart` (line 713)
- **Purpose:** Build one row of the search result list.
- **Returns:** `Widget`.
- **Side effects:** None.
- **Algorithm:** A `ListTile` with the network cover thumbnail, `r.displayTitle` wrapped in a `Tooltip` listing every known title, a first subtitle line of source · Japanese title · episode count, and [`_secondaryLine`](#secondaryline) beneath it. `onTap` selects the result; `onLongPress` opens [`_showResultDetails`](#showresultdetails).
- **Notes:** The title is deliberately clipped to one line — anime titles routinely exceed the dialog width. Long-press (touch) and hover tooltip (desktop) are the two escape hatches to the full name, which is what the detail sheet exists for.

### `String? _secondaryLine(AppLocalizations l10n, AnimeSearchResult r)` <a id="secondaryline"></a>
- **Kind:** method of `_SearchDialogState`
- **Source:** `lib/features/anime/views/anime_search_dialog.dart` (line 773)
- **Purpose:** Compose the secondary metadata line shown under a result.
- **Returns:** `String?` — `null` when the source supplied none of these fields.
- **Side effects:** None.
- **Algorithm:** Joins, with ` · `, whichever of these exist: the score as `★ 9.2/10`, the format, the air day plus time, the first air date (only when there is no air day), and the first studio.
- **Notes:** Returning `null` rather than an empty string lets the caller drop `isThreeLine`, so rows from a thin source like filmarks.com stay compact instead of reserving a blank line.

### `Future<void> _showResultDetails(AppLocalizations l10n, AnimeSearchResult r)` <a id="showresultdetails"></a>
- **Kind:** method of `_SearchDialogState`
- **Source:** `lib/features/anime/views/anime_search_dialog.dart` (line 794)
- **Purpose:** Show every title and field a result carries, untruncated.
- **Side effects:** Opens a modal sheet; copying writes to the system clipboard.
- **Algorithm:** A `DraggableScrollableSheet` listing the source chip, every entry of `r.allTitles` as a `SelectableText` with a copy button, the rows from [`_detailRows`](#detailrows), and the full summary.
- **Notes:** Titles are `SelectableText` so a name can be copied out even when it is far too long for the list row that triggered this sheet. This is the answer to "the list truncates the name and I can't read it" — nothing here is ellipsized.

### `List<Widget> _detailRows(AppLocalizations l10n, AnimeSearchResult r, ThemeData theme)` <a id="detailrows"></a>
- **Kind:** method of `_SearchDialogState`
- **Source:** `lib/features/anime/views/anime_search_dialog.dart` (line 870)
- **Purpose:** Build the labelled metadata rows for the result detail sheet.
- **Returns:** `List<Widget>`.
- **Side effects:** None.
- **Algorithm:** Builds a `(label, value)` list from every field the result supplies — episodes, first/last air date, air day and time, format, status, duration, studios, genres, the score with votes and rank, and the source URL — then renders each as a fixed-width label beside a `SelectableText` value.
- **Notes:** Fields the source did not supply are omitted entirely rather than shown blank, so the sheet's length is an honest signal of how much that source knows.

### `Widget _buildFieldList(AppLocalizations l10n, AnimeSearchResult r)` <a id="buildfieldlist"></a>
- **Kind:** method of `_SearchDialogState`
- **Source:** `lib/features/anime/views/anime_search_dialog.dart` (line 1007)
- **Purpose:** Build the per-field checkbox list for the preview phase.
- **Returns:** `Widget`.
- **Side effects:** None.
- **Algorithm:** One `_fieldTile` per supplied field (title, Japanese title, episodes, first air date, air day, air time, notes), then the external-metadata checkbox plus its read-only chip summary, then the cover-image section with its explicit fetch button and before/after preview.
- **Notes:** External metadata is a *single* checkbox covering all of studios/genres/format/status/duration/alternate titles/score. Splitting it per field would make the list unusable, and the fields always arrive together from one source anyway.

### `Widget _buildExternalMetaSummary(AppLocalizations l10n, AnimeSearchResult r)` <a id="buildexternalmetasummary"></a>
- **Kind:** method of `_SearchDialogState`
- **Source:** `lib/features/anime/views/anime_search_dialog.dart` (line 1161)
- **Purpose:** Show the metadata that the external-metadata checkbox would apply.
- **Returns:** `Widget` — `SizedBox.shrink()` when there is nothing to show.
- **Side effects:** None.
- **Algorithm:** A compact `Wrap` of chips: format, status, duration, each studio, each genre, and the score.
- **Notes:** Read-only by design — the single checkbox above governs whether any of it is written. It exists so the user can see what "6 fields from AniList" actually means before accepting it.

### `Widget _buildSearchProgress(AppLocalizations, {bool compact = false})` <a id="_buildsearchprogress"></a>
- **Kind:** method
- **Source:** `lib/features/anime/views/anime_search_dialog.dart` (approx. line 708)
- **Purpose:** Show which sources have answered while a search is still running.
- **Inputs:** `l10n`; `compact` (1.6.1) — the slim strip shown above partial results instead of the
  full panel.
- **Returns:** `Widget`.
- **Side effects:** None.
- **Algorithm:** Render a determinate bar from `AnimeSearchProgress.fraction`, a caption naming the
  round and the count, and one chip per source — spinner while pending, a tick and a result count
  once it lands, an error icon when it threw. `compact` shrinks the padding and spacing and uses
  `bodySmall` for the caption.
- **Usage:**
  ```dart
  if (_searching && _results.isNotEmpty)
    _buildSearchProgress(l10n, compact: true),
  ```
  (`_buildSearchView`, above the result toolbar; `_buildSearchResults` shows the full panel while
  `_searching && _results.isEmpty`)
- **Notes:** Replaces the bare `CircularProgressIndicator` this screen used through 1.5.0. A search
  can legitimately take about half a minute — each source has its own 10–15 second timeout, and
  sources that come back empty are queried a second time with titles harvested from the first round
  — and over that stretch a lone spinner is indistinguishable from a hang.

  The chips are the part that actually answers the question: when one source is slow, the other four
  are already ticked, which says "working" rather than "stuck", and names the one holding things up.

  Falls back to the plain spinner (a bare `LinearProgressIndicator` when `compact`) before the first
  progress snapshot arrives, so there is never a frame with an empty bar and no chips.

  Since 1.6.1 the full panel fills the dialog only until the first results arrive; after that it
  shrinks to the compact strip above the already usable result list while the remaining sources
  finish.
