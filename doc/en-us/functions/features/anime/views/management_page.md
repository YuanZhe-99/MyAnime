# lib/features/anime/views/management_page.dart

`ManagementPage` is the seasonal quarter browser: a swipeable `PageView` of quarters (2000–2040)
plus a final "Other" page for anime with no `firstAirDate`, a jump-to-quarter picker
([`quarter_picker_dialog.md`](quarter_picker_dialog.md)), and a global title search. It reads and
writes through `AnimeStorage` ([`../services/anime_storage.md`](../services/anime_storage.md)) and
places anime into quarters using [`Anime.airsInQuarter`](../models/anime.md#airsinquarter). See
[`../../../../features/home-management-statistics.md`](../../../../features/home-management-statistics.md)
for the feature overview and
[`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md#quarter-placement)
for the quarter-placement rules this page's grouping relies on.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `ManagementPage.new` | constructor (`ManagementPage`) | B | Create a `ManagementPage` instance. |
| `ManagementPage.createState` | method (`ManagementPage`) | B | Create the mutable state object for this widget. |
| `_isOtherPage` | getter (`_ManagementPageState`) | B | Whether the currently displayed page is the "Other" (no-date) page. |
| [`_ManagementPageState.initState`](#initstate-mgmt) | method (`_ManagementPageState`) | A | Load data and position the `PageView` on the current quarter. |
| `_ManagementPageState.dispose` | method (`_ManagementPageState`) | B | Unregister the sync-reload callback and dispose the page controller. |
| [`_load`](#_load) | method (`_ManagementPageState`) | A | Reload all anime from storage. |
| [`_animeForQuarter`](#_animeforquarter) | method (`_ManagementPageState`) | A | Filter and sort the anime airing in a given quarter. |
| [`_otherAnime`](#_otheranime) | getter (`_ManagementPageState`) | A | Anime with no `firstAirDate`, sorted by title. |
| [`_searchResults`](#_searchresults) | method (`_ManagementPageState`) | A | Filter and sort anime by a case-insensitive title substring match. |
| `_quarterLabel` | method (`_ManagementPageState`) | B | Format a quarter as "`year` `season name`". |
| `_dayLabel` | method (`_ManagementPageState`) | B | Localize a day-of-week number for the anime tile subtitle. |
| [`_deleteAnime`](#_deleteanime) | method (`_ManagementPageState`) | A | Confirm and delete an anime record. |
| [`_showAddOptions`](#_showaddoptions) | method (`_ManagementPageState`) | A | Show the add/import choice dialog and open + jump to the resulting anime. |
| [`_jumpToAnimeQuarter`](#_jumptoanimequarter) | method (`_ManagementPageState`) | A | Page the view to the quarter (or "Other" page) containing a given anime. |
| [`_showQuarterPicker`](#_showquarterpicker) | method (`_ManagementPageState`) | A | Open the quarter picker dialog and page the view to the chosen quarter. |
| `_ManagementPageState.build` | method (`_ManagementPageState`, widget build) | B | Build the page scaffold (search field, quarter view, FAB). |
| `_buildSearchResults` | method (widget helper) | B | Render the global search results list. |
| `_buildQuarterView` | method (widget helper) | B | Render the quarter navigation row and swipeable `PageView`. |
| `_buildAnimeTile` | method (widget helper) | B | Render one anime row with swipe-to-edit/delete actions. |
| `_Quarter.new` | constructor (`_Quarter`) | B | Pair a year and quarter number. |

## Documentation

### `void initState()` <a id="initstate-mgmt"></a>
- **Kind:** method of `_ManagementPageState`
- **Source:** `lib/features/anime/views/management_page.dart` (approx. line 58)
- **Purpose:** Register the sync-reload callback, trigger the first data load, and position the
  `PageView` on the quarter containing today's date.
- **Inputs:** None.
- **Returns:** `None`.
- **Side effects:** Registers with `AutoSyncService`; calls `_load()`; creates `_pageController`.
- **Algorithm:**
  1. Register `_load` with
     [`AutoSyncService.addOnLocalDataChanged`](../../../shared/services/auto_sync_service.md#addonlocaldatachanged)
     and call `_load()`.
  2. Compute the current quarter from `DateTime.now()`: `((now.month - 1) ~/ 3) + 1`.
  3. Find that quarter's index in the static `_quarters` list via `indexWhere`; fall back to index
     `0` if not found (should not happen given `_quarters` spans 2000–2040).
  4. Construct `_pageController` with `initialPage: _currentQuarterIndex`.
- **Usage:**
  ```dart
  @override
  void initState() {
    super.initState();
    AutoSyncService.instance.addOnLocalDataChanged(_load);
    _load();
    ...
  }
  ```
  (same file — this override itself)
- **Notes:** Unlike the other views in this batch, this `initState` does real inline computation
  (locating the current-quarter index) rather than only delegating to a helper, which is why it is
  documented as Tier A here.

### `Future<void> _load()` <a id="_load"></a>
- **Kind:** method of `_ManagementPageState`
- **Source:** `lib/features/anime/views/management_page.dart` (approx. line 88)
- **Purpose:** Reload the full anime list from storage into `_allAnime`.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Calls `AnimeStorage.load()`; `setState`s `_allAnime`.
- **Algorithm:** Await `AnimeStorage.load()`; if mounted, `setState(() => _allAnime =
  data.animeList)`.
- **Usage:**
  ```dart
  AutoSyncService.instance.addOnLocalDataChanged(_load);
  _load();
  ```
  (`_ManagementPageState.initState`, same file; also called after every mutating action to refresh
  the view)
- **Notes:** None.

### `List<Anime> _animeForQuarter(_Quarter quarter)` <a id="_animeforquarter"></a>
- **Kind:** method of `_ManagementPageState`
- **Source:** `lib/features/anime/views/management_page.dart` (approx. line 98)
- **Purpose:** Compute the anime list shown on one quarter's page, filtered by
  [`airsInQuarter`](../models/anime.md#airsinquarter) and sorted for display.
- **Inputs:** `quarter`.
- **Returns:** `List<Anime>`.
- **Side effects:** None.
- **Algorithm:**
  1. Filter `_allAnime` to those where `a.airsInQuarter(quarter.year, quarter.q)` is `true`.
  2. Sort by `airDayOfWeek` (missing values sort last, using `8` as a sentinel), then by
     `displayTitle` for anime sharing the same air day.
- **Usage:**
  ```dart
  final quarter = _quarters[index];
  final animeList = _animeForQuarter(quarter);
  ```
  (`_buildQuarterView`, same file)
- **Notes:** None.

### `List<Anime> get _otherAnime` <a id="_otheranime"></a>
- **Kind:** getter of `_ManagementPageState`
- **Source:** `lib/features/anime/views/management_page.dart` (approx. line 115)
- **Purpose:** Compute the anime list shown on the trailing "Other" page — records with no
  `firstAirDate`, which [`airsInQuarter`](../models/anime.md#airsinquarter) can never place into a
  quarter.
- **Inputs:** None.
- **Returns:** `List<Anime>`.
- **Side effects:** None.
- **Algorithm:** Filter `_allAnime` to `firstAirDate == null`, sort by `displayTitle`.
- **Usage:**
  ```dart
  otherCount: _otherAnime.length,
  ```
  (`_showQuarterPicker`, same file; also read directly in `_buildQuarterView` for the "Other" page)
- **Notes:** None.

### `List<Anime> _searchResults()` <a id="_searchresults"></a>
- **Kind:** method of `_ManagementPageState`
- **Source:** `lib/features/anime/views/management_page.dart` (approx. line 125)
- **Purpose:** Compute the global search result list from the search field's current text.
- **Inputs:** None (reads `_searchQuery`).
- **Returns:** `List<Anime>`.
- **Side effects:** None.
- **Algorithm:** Lowercase `_searchQuery`; filter `_allAnime` to those whose `title` or `titleJa`
  (lowercased) contains it; sort the matches by `displayTitle`.
- **Usage:**
  ```dart
  Widget _buildSearchResults(ThemeData theme, AppLocalizations l10n) {
    final results = _searchResults();
    ...
  ```
  (`_buildSearchResults`, same file)
- **Notes:** Matches against both the primary and Japanese title independently — an anime matches if
  *either* field contains the query, not just the one currently displayed.

### `Future<void> _deleteAnime(Anime anime)` <a id="_deleteanime"></a>
- **Kind:** method of `_ManagementPageState`
- **Source:** `lib/features/anime/views/management_page.dart` (approx. line 176)
- **Purpose:** Confirm with the user, then delete an anime record.
- **Inputs:** `anime`.
- **Returns:** `Future<void>`.
- **Side effects:** Shows a confirm dialog (`confirmDelete`); calls `AnimeStorage.deleteAnime`;
  reloads via `_load()`.
- **Algorithm:** Await `confirmDelete(context, anime.displayTitle)`; return if declined; else
  `AnimeStorage.deleteAnime(anime.id)` followed by `_load()`.
- **Usage:**
  ```dart
  confirmDismiss: (direction) async {
    if (direction == DismissDirection.startToEnd) {
      ...
    } else {
      await _deleteAnime(anime);
      return false;
    }
  },
  ```
  (`_buildAnimeTile`, swipe-to-delete on a `Dismissible`)
- **Notes:** The `Dismissible`'s `confirmDismiss` always returns `false` regardless of outcome — the
  tile is never actually dismissed by the framework; the list simply refreshes (via `_load()`) once
  the record is gone.

### `Future<void> _showAddOptions(BuildContext context)` <a id="_showaddoptions"></a>
- **Kind:** method of `_ManagementPageState`
- **Source:** `lib/features/anime/views/management_page.dart` (approx. line 188)
- **Purpose:** Show a "Create" vs. "Import" choice dialog, then navigate to whichever flow was
  chosen, open the resulting anime's detail page, and jump the quarter view to it.
- **Inputs:** `context`.
- **Returns:** `Future<void>`.
- **Side effects:** Shows a `SimpleDialog`; navigates via `context.push`; may run the import-bundle
  flow (file-system read); reloads via `_load()`; pages `_pageController` to the new anime's quarter.
- **Algorithm:**
  1. Show a `SimpleDialog` offering `'create'`/`'import'`; return if dismissed without a choice.
  2. If `'create'`: push `/anime/edit`, reload; if an ID came back, push its detail page, reload
     again, then call [`_jumpToAnimeQuarter`](#_jumptoanimequarter) with the new ID.
  3. If `'import'`: run `showImportBundleFlow(context)`, reload; if any IDs were imported, push the
     detail page for the first imported ID, reload again, then jump to its quarter.
- **Usage:**
  ```dart
  floatingActionButton: FloatingActionButton(
    onPressed: () => _showAddOptions(context),
    tooltip: l10n.animeAdd,
    child: const Icon(Icons.add),
  ),
  ```
  (`_ManagementPageState.build`, same file)
- **Notes:** Structurally identical to `HomePage._showAddOptions`
  ([`home_page.md`](home_page.md#_showaddoptions)), but this version additionally jumps the
  `PageView` to the new anime's quarter afterward, which is why Management (unlike Home) needs the
  extra `_jumpToAnimeQuarter` step.

### `void _jumpToAnimeQuarter(String animeId)` <a id="_jumptoanimequarter"></a>
- **Kind:** method of `_ManagementPageState`
- **Source:** `lib/features/anime/views/management_page.dart` (approx. line 240)
- **Purpose:** Page the quarter `PageView` to whichever quarter (or the "Other" page) contains the
  given anime.
- **Inputs:** `animeId`.
- **Returns:** `None`.
- **Side effects:** May call `_pageController.jumpToPage`.
- **Algorithm:**
  1. Find the anime in `_allAnime` by `id`; return if not found.
  2. If its [`startQuarter`](../models/anime.md#startquarter) is `null` (no `firstAirDate`), jump to
     the "Other" page index (`_quarters.length`) unless already there.
  3. Otherwise find the matching `(year, quarter)` entry in `_quarters` and jump to it unless already
     on that page.
- **Usage:**
  ```dart
  await context.push('/anime/detail/$newId');
  await _load();
  _jumpToAnimeQuarter(newId);
  ```
  (`_showAddOptions`, same file)
- **Notes:** Uses `startQuarter` (the anime's *starting* cour), not the fuller
  [`airsInQuarter`](../models/anime.md#airsinquarter) span logic — an anime that spans multiple
  quarters (e.g. a `fullYear` type) is always jumped to its first quarter, not any later one it also
  airs in.

### `Future<void> _showQuarterPicker()` <a id="_showquarterpicker"></a>
- **Kind:** method of `_ManagementPageState`
- **Source:** `lib/features/anime/views/management_page.dart` (approx. line 264)
- **Purpose:** Open the year/quarter picker dialog
  ([`showQuarterPickerDialog`](quarter_picker_dialog.md#showquarterpickerdialog)), scoped to the
  range of years actually present in the data (plus the current and next year), and page the view
  to whatever the user picks.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Shows a dialog; may call `_pageController.jumpToPage`.
- **Algorithm:**
  1. Collect every distinct year from every anime's `startQuarter` into a set, plus the current year
     and the next year, then take the min/max of that set as the picker's year bounds.
  2. Call `showQuarterPickerDialog` with a `countBuilder` that reports, per `(year, quarter)`, how
     many anime satisfy `airsInQuarter` — and an "Other" option whose count is `_otherAnime.length`.
  3. If the result is the "Other" selection, jump to the "Other" page index; otherwise find the
     matching quarter in `_quarters` and jump to it (in both cases, only if not already on that
     page).
- **Usage:**
  ```dart
  GestureDetector(
    onTap: _showQuarterPicker,
    child: Center(
      child: Row(
  ```
  (`_buildQuarterView`, tapping the quarter label in the navigation row)
- **Notes:** The per-cell counts shown in the picker come from `airsInQuarter` (a quarter's full
  potential membership), while `_animeForQuarter` used elsewhere applies the same filter — so the
  counts always match what the corresponding page actually shows.
