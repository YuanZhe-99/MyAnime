# lib/features/anime/views/anime_search_dialog.dart

`showAnimeSearchDialog` and its backing `_SearchDialog` implement the "search online for anime
metadata" flow used from the edit page: search several sources via `AnimeSearchService`
([`../services/anime_search_service.md`](../services/anime_search_service.md)), preview one result
with per-field checkboxes deciding what to import, optionally fetch its cover image (via
`ImageService`, [`../../../shared/services/image_service.md`](../../../shared/services/image_service.md)),
and return a sparse `Map<String, dynamic>` of the fields the user chose to apply. The caller
(`AnimeEditPage._showSearchDialog`, [`anime_edit_page.md`](anime_edit_page.md#_showsearchdialog))
merges that map into its own form fields — this file has no direct dependency on `AnimeStorage` or
the `Anime` model itself.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`showAnimeSearchDialog`](#showanimesearchdialog) | top-level function | A | Show the anime metadata search dialog and return the chosen field values. |
| `_SearchDialog.new` | constructor (`_SearchDialog`) | B | Create the search dialog with the current form's values for comparison. |
| `_SearchDialog.createState` | method (`_SearchDialog`) | B | Create the mutable state object for this widget. |
| `_SearchDialogState.initState` | method (`_SearchDialogState`) | B | Seed the query controller from `initialQuery`. |
| `_SearchDialogState.dispose` | method (`_SearchDialogState`) | B | Dispose the query controller. |
| [`_search`](#_search) | method (`_SearchDialogState`) | A | Search all configured sources for the current query text. |
| [`_selectResult`](#_selectresult) | method (`_SearchDialogState`) | A | Enter preview phase for a chosen result, pre-selecting which fields to apply. |
| [`_fetchCover`](#_fetchcover) | method (`_SearchDialogState`) | A | Download and stage the selected result's cover image. |
| [`_apply`](#_apply) | method (`_SearchDialogState`) | A | Build the result map from the toggled fields and close the dialog. |
| `_SearchDialogState.build` | method (`_SearchDialogState`, widget build) | B | Build the dialog, switching between the search and preview views. |
| `_buildSearchView` | method (widget helper) | B | Render the search phase: header, query field, and results list. |
| `_buildSearchResults` | method (widget helper) | B | Render the search results list (loading/error/empty/list states). |
| `_buildPreviewView` | method (widget helper) | B | Render the preview phase: source badge, field list, and apply/cancel buttons. |
| `_buildFieldList` | method (widget helper) | B | Render the per-field comparison checkboxes and cover-image section. |
| `_coverColumn` | method (widget helper) | B | Render one labeled cover-image thumbnail column. |
| `_fieldTile` | method (widget helper) | B | Render one checkbox field tile comparing current vs. fetched values. |
| `_buildHeader` | method (widget helper) | B | Render the dialog header (icon, title, optional back/close buttons). |
| `_dayName` | method (`_SearchDialogState`) | B | Localize a day-of-week number for display. |
| `_truncate` | method (`_SearchDialogState`) | B | Shorten a string to a maximum length, appending `...`. |

## Documentation

### `Future<Map<String, dynamic>?> showAnimeSearchDialog(BuildContext context, {String? initialQuery, String? currentTitle, String? currentTitleJa, int? currentEndEp, DateTime? currentFirstAirDate, int? currentAirDay, String? currentAirTime, String? currentCoverImage, String? currentNotes})` <a id="showanimesearchdialog"></a>
- **Kind:** top-level function
- **Source:** `lib/features/anime/views/anime_search_dialog.dart` (approx. line 15)
- **Purpose:** Public entry point for the online metadata search flow: show `_SearchDialog` seeded
  with the caller's current field values, and return whatever field map the user chose to apply.
- **Inputs:** `context`; `initialQuery` — pre-filled search text; the `currentXxx` parameters are
  passed straight through to `_SearchDialog` purely so it can display "current vs. fetched"
  comparisons — they do not affect what is searched.
- **Returns:** `Future<Map<String, dynamic>?>` — a sparse map of only the fields the user chose to
  apply (possible keys: `title`, `titleJa`, `endEpisode`, `firstAirDate`, `airDayOfWeek`, `airTime`,
  `notes`, `coverImage`, `infoUrl`), or `null` if the dialog was cancelled.
- **Side effects:** Shows a modal dialog that performs network requests.
- **Algorithm:** Thin forwarding wrapper: calls `showDialog<Map<String, dynamic>>` with a
  `_SearchDialog` built from the given parameters.
- **Usage:**
  ```dart
  final result = await showAnimeSearchDialog(
    context,
    initialQuery: query,
    currentTitle: _titleController.text.isEmpty ? null : _titleController.text,
    ...
  );
  if (result != null && mounted) {
    setState(() {
      if (result.containsKey('title')) {
        _titleController.text = result['title'] as String;
      }
      ...
  ```
  (`AnimeEditPage._showSearchDialog`, [`anime_edit_page.md`](anime_edit_page.md#_showsearchdialog))
- **Notes:** The exact set of keys that can appear in the returned map, and the conditions under
  which each appears, is entirely determined by [`_apply`](#_apply) below — callers should treat any
  key as optional.

### `Future<void> _search()` <a id="_search"></a>
- **Kind:** method of `_SearchDialogState`
- **Source:** `lib/features/anime/views/anime_search_dialog.dart` (approx. line 126)
- **Purpose:** Query every configured metadata source (via
  [`AnimeSearchService.searchAll`](../services/anime_search_service.md#searchall)) for the current
  query text.
- **Inputs:** None (reads `_queryController.text`).
- **Returns:** `Future<void>`.
- **Side effects:** Performs network requests; `setState`s `_searching`, `_results`, `_error`.
- **Algorithm:**
  1. Trim the query; return early if empty.
  2. `setState` into a loading state, clearing prior results/error.
  3. Await `AnimeSearchService.searchAll(query)`; on success, store the results and set a
     "no results" error message when the list is empty.
  4. On any thrown exception, store `e.toString()` as `_error`.
- **Usage:**
  ```dart
  FilledButton(
    onPressed: _searching ? null : _search,
    child: Text(l10n.searchButton),
  ),
  ```
  (`_buildSearchView`, same file; also triggered by the query field's `onSubmitted`)
- **Notes:** Distinct from `_WatchUrlSearchDialogState._search` in `anime_edit_page.dart`
  ([`anime_edit_page.md`](anime_edit_page.md#_search-watchurl)), which searches only `anime1.me` for
  watch-page links rather than metadata across `AnimeSearchService.searchAll`'s sources.

### `void _selectResult(AnimeSearchResult result)` <a id="_selectresult"></a>
- **Kind:** method of `_SearchDialogState`
- **Source:** `lib/features/anime/views/anime_search_dialog.dart` (approx. line 160)
- **Purpose:** Switch from the search phase to the preview phase for a chosen result, and
  pre-select which fields default to "apply" based on which data the result actually provides.
- **Inputs:** `result` — the tapped `AnimeSearchResult`.
- **Returns:** `None`.
- **Side effects:** `setState`s `_selected`, `_phase`, `_toggles`, and clears any previously fetched
  cover.
- **Algorithm:**
  1. Set `_selected = result`, `_phase = _Phase.preview`, clear `_fetchedCoverPath`/`_coverPreview`,
     and clear `_toggles`.
  2. For each of `title`/`titleJa`/`episodes`(→`endEpisode` toggle key)/`firstAirDate`/
     `airDayOfWeek`/`airTime`/`notes`(from `summary`): set that toggle to `true` only if the result
     actually provides a non-empty value for it.
  3. If the result has a `coverImageUrl`, set the `'cover'` toggle to `false` (off by default —
     applying a cover requires an explicit [`_fetchCover`](#_fetchcover) first).
- **Usage:**
  ```dart
  onTap: () => _selectResult(r),
  ```
  (`_buildSearchResults`, same file, on each result `ListTile`)
- **Notes:** A field with no data in the result (e.g. no `airTime`) simply has no toggle entry at
  all — [`_apply`](#_apply)'s `_toggles['airTime'] == true` check treats a missing key the same as
  `false`.

### `Future<void> _fetchCover()` <a id="_fetchcover"></a>
- **Kind:** method of `_SearchDialogState`
- **Source:** `lib/features/anime/views/anime_search_dialog.dart` (approx. line 184)
- **Purpose:** Download the selected result's cover image and stage it locally so it can be
  previewed and, if the user leaves the toggle on, applied.
- **Inputs:** None (reads `_selected?.coverImageUrl`).
- **Returns:** `Future<void>`.
- **Side effects:** Performs a network request via `ImageService.saveImageFromUrl`; reads the saved
  file via `ImageService.resolve`; `setState`s `_fetchingCover`, `_fetchedCoverPath`,
  `_coverPreview`, `_toggles['cover']`; shows a `SnackBar` on failure.
- **Algorithm:**
  1. Return early if there's no `coverImageUrl`.
  2. `setState(() => _fetchingCover = true)`.
  3. Await `ImageService.saveImageFromUrl(url)`; if it returns a path and the widget is still
     mounted, resolve it to a `File` via `ImageService.resolve`, then `setState` the staged path,
     a `FileImage` preview, `_toggles['cover'] = true`, and `_fetchingCover = false`.
  4. If the save returned `null`, just clear the loading flag.
  5. On any thrown exception, clear the loading flag and show a `SnackBar` with the error message.
- **Usage:**
  ```dart
  TextButton.icon(
    onPressed: _fetchCover,
    icon: const Icon(Icons.download, size: 16),
    label: Text(l10n.searchFetchCover),
  ),
  ```
  (`_buildFieldList`, shown only while no cover has been fetched yet)
- **Notes:** Successfully fetching the cover also force-enables the `'cover'` toggle — there is no
  way to fetch a preview without also defaulting it to "apply"; the user must manually uncheck it
  afterward to discard it.

### `void _apply()` <a id="_apply"></a>
- **Kind:** method of `_SearchDialogState`
- **Source:** `lib/features/anime/views/anime_search_dialog.dart` (approx. line 221)
- **Purpose:** Build the sparse result map from whichever fields are currently toggled on, and close
  the dialog with it.
- **Inputs:** None (reads `_selected` and `_toggles`).
- **Returns:** `None`.
- **Side effects:** `Navigator.of(context).pop(result)`.
- **Algorithm:**
  1. Return early if nothing is selected.
  2. For each of `title`/`titleJa`/`episodes`→`endEpisode`/`firstAirDate`/`airDayOfWeek`/`airTime`:
     include it in the result map only when its toggle is `true` **and** the result actually has a
     non-null value for it.
  3. Special case: if `firstAirDate` is toggled on but the source didn't supply `airDayOfWeek`
     directly, derive it from `firstAirDate.weekday` (`1=Mon..7=Sun`) and add it to the result even
     though its own toggle wasn't necessarily set.
  4. Include `notes` (from `summary`) similarly, and `coverImage` (from `_fetchedCoverPath`) when the
     `'cover'` toggle is on.
  5. Always include `infoUrl` (from `sourceUrl`) when non-empty, regardless of any toggle.
  6. `Navigator.of(context).pop(result)`.
- **Usage:**
  ```dart
  FilledButton(
    onPressed: _toggles.values.any((v) => v) ? _apply : null,
    child: Text(l10n.searchApply),
  ),
  ```
  (`_buildPreviewView`, same file — disabled unless at least one toggle is on)
- **Notes:** `infoUrl` is applied unconditionally whenever the source provides one — there is no
  checkbox for it, unlike every other field; the returned map can therefore contain `infoUrl` even
  when every other toggle is off, so the "Apply" button being enabled (which only requires *some*
  toggle to be on) does not mean the final map is limited to toggled fields alone.
