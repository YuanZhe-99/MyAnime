# lib/features/anime/views/anime_edit_page.dart

`AnimeEditPage` is the create/edit form for a single `Anime` record: text fields for
title/season/episode range/URLs/notes, dropdowns for type override and air day, a date picker for
`firstAirDate`, rating sub-score fields, and (full-flavor builds only) online metadata search and
watch-URL search integrations. It persists through `AnimeStorage`
([`../services/anime_storage.md`](../services/anime_storage.md)) and builds/parses the `Anime`/
`AnimeRating` model ([`../models/anime.md`](../models/anime.md)). It also defines a private
`_WatchUrlSearchDialog` used only by its own watch-URL search action. See
[`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md) for how the
fields edited here (`manualType`, `airDayOfWeek`, `airTime`, `firstAirDate`) drive quarter placement
and episode air-date computation.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `AnimeEditPage.new` | constructor (`AnimeEditPage`) | B | Create an `AnimeEditPage`, optionally bound to an existing anime ID. |
| `AnimeEditPage.createState` | method (`AnimeEditPage`) | B | Create the mutable state object for this widget. |
| `_AnimeEditPageState.initState` | method (`_AnimeEditPageState`) | B | Set the default season text and trigger loading an existing record if editing. |
| [`_loadExisting`](#_loadexisting) | method (`_AnimeEditPageState`) | A | Load an existing anime and populate every form field/controller from it. |
| `_AnimeEditPageState.dispose` | method (`_AnimeEditPageState`) | B | Dispose all 15 owned `TextEditingController`s. |
| [`_pickCoverImage`](#_pickcoverimage) | method (`_AnimeEditPageState`) | A | Let the user pick a cover image file and stage its path. |
| [`_searchWatchUrl`](#_searchwatchurl) | method (`_AnimeEditPageState`) | A | Open the watch-URL search dialog and apply the chosen URL. |
| [`_showSearchDialog`](#_showsearchdialog) | method (`_AnimeEditPageState`) | A | Open the online metadata search dialog and merge its result into the form. |
| [`_pickFirstAirDate`](#_pickfirstairdate) | method (`_AnimeEditPageState`) | A | Show a date picker and stage the chosen `firstAirDate`. |
| [`_save`](#_save) | method (`_AnimeEditPageState`) | A | Validate the form and create or update the anime record. |
| [`_buildRating`](#_buildrating) | method (`_AnimeEditPageState`) | A | Assemble an `AnimeRating` from the rating text fields, or `null` if empty. |
| `_parseScore` | method (`_AnimeEditPageState`) | B | Parse a rating controller's text into a `double?`. |
| `_formatScore` | method (`_AnimeEditPageState`) | B | Format a score as an integer when whole, else one decimal place. |
| `_AnimeEditPageState.build` | method (`_AnimeEditPageState`, widget build) | B | Build the edit/create form scaffold. |
| `_buildRatingField` | method (widget helper) | B | Render one 0–10 rating `TextFormField` with validation. |
| `_dayName` | method (`_AnimeEditPageState`) | B | Localize a day-of-week number for the air-day dropdown. |
| `_typeLabel` | method (`_AnimeEditPageState`) | B | Localize an `AnimeType` value for the type-override dropdown. |
| `_WatchUrlSearchDialog.new` | constructor (`_WatchUrlSearchDialog`) | B | Create the watch-URL search dialog with a query and alternate queries. |
| `_WatchUrlSearchDialog.createState` | method (`_WatchUrlSearchDialog`) | B | Create the mutable state object for this widget. |
| `_WatchUrlSearchDialogState.initState` | method (`_WatchUrlSearchDialogState`) | B | Seed the query controller and run the first search. |
| `_WatchUrlSearchDialogState.dispose` | method (`_WatchUrlSearchDialogState`) | B | Dispose the query controller. |
| [`_search`](#_search-watchurl) | method (`_WatchUrlSearchDialogState`) | A | Search anime1.me for watch-page links matching the query. |
| `_WatchUrlSearchDialogState.build` | method (`_WatchUrlSearchDialogState`, widget build) | B | Build the watch-URL search dialog scaffold. |
| `_buildBody` | method (widget helper) | B | Render the loading/error/results body of the watch-URL dialog. |

## Documentation

### `Future<void> _loadExisting()` <a id="_loadexisting"></a>
- **Kind:** method of `_AnimeEditPageState`
- **Source:** `lib/features/anime/views/anime_edit_page.dart` (approx. line 79)
- **Purpose:** Load the anime identified by `widget.animeId` and populate every form controller and
  staged field from it, switching the page into edit mode.
- **Inputs:** None (`widget.animeId` from the enclosing widget).
- **Returns:** `Future<void>`.
- **Side effects:** Calls `AnimeStorage.load()`; `setState`s `_isEdit`, `_existing`, and every
  controller/staged field (`_titleController`, ..., `_coverImage`).
- **Algorithm:**
  1. Await `AnimeStorage.load()`; find the record whose `id == widget.animeId`.
  2. If found, set `_isEdit = true`, `_existing = found`, and copy every editable field into its
     matching controller (empty string for unset optional text fields) or staged variable
     (`_airDayOfWeek`, `_firstAirDate`, `_manualType`, `_coverImage`).
  3. Rating sub-scores are formatted through `_formatScore` (Tier B, same file) before being placed
     into their controllers.
- **Usage:**
  ```dart
  if (widget.animeId != null) {
    _loadExisting();
  }
  ```
  (`_AnimeEditPageState.initState`, same file)
- **Notes:** If no record matches `widget.animeId`, the page silently stays in create mode
  (`_isEdit` remains `false`) rather than showing an error.

### `Future<void> _pickCoverImage()` <a id="_pickcoverimage"></a>
- **Kind:** method of `_AnimeEditPageState`
- **Source:** `lib/features/anime/views/anime_edit_page.dart` (approx. line 141)
- **Purpose:** Let the user pick an image file from the device and stage it as the anime's cover.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Calls `ImageService.pickAndSaveImage()` (file-system read/copy); `setState`s
  `_coverImage`.
- **Algorithm:** Await `ImageService.pickAndSaveImage()`; if it returns a non-null path and the
  widget is still mounted, stage it into `_coverImage`.
- **Usage:**
  ```dart
  Center(
    child: GestureDetector(
      onTap: _pickCoverImage,
      child: Container(...),
  ```
  (`_AnimeEditPageState.build`, cover image tap target)
- **Notes:** The picked image is only staged in memory until [`_save`](#_save) persists the
  anime record — cancelling out of the edit page without saving discards the pick (though
  `ImageService.pickAndSaveImage` may already have copied the file into the app's image directory;
  see [`../../../shared/services/image_service.md`](../../../shared/services/image_service.md)).

### `Future<void> _searchWatchUrl()` <a id="_searchwatchurl"></a>
- **Kind:** method of `_AnimeEditPageState`
- **Source:** `lib/features/anime/views/anime_edit_page.dart` (approx. line 153)
- **Purpose:** Open `_WatchUrlSearchDialog` seeded with the current title (and alternate title) and
  apply whichever result URL the user selects.
- **Inputs:** None (reads `_titleController`/`_titleJaController` text).
- **Returns:** `Future<void>`.
- **Side effects:** Shows a dialog that performs network requests; `setState`s
  `_watchUrlController.text`; shows a `SnackBar` on success.
- **Algorithm:**
  1. Use the title if non-empty, else the Japanese title, as the primary query; return early if
     both are empty.
  2. Build `altQueries` — the *other* title, but only included when exactly one of the two is
     non-empty (so the dialog always has a fallback query when only one title exists).
  3. Await `showDialog<String>` with a `_WatchUrlSearchDialog`; if a URL was picked and the widget is
     still mounted, set `_watchUrlController.text` and show a confirmation `SnackBar`.
- **Usage:**
  ```dart
  suffixIcon: AppFlavor.isFull
      ? IconButton(
          icon: const Icon(Icons.search),
          tooltip: l10n.searchWatchUrl,
          onPressed: _searchWatchUrl,
        )
      : null,
  ```
  (`_AnimeEditPageState.build`, watch-URL field suffix — gated on `AppFlavor.isFull`)
- **Notes:** Only wired up in the full app flavor (`AppFlavor.isFull`); the lite flavor never shows
  the search icon that triggers this.

### `Future<void> _showSearchDialog()` <a id="_showsearchdialog"></a>
- **Kind:** method of `_AnimeEditPageState`
- **Source:** `lib/features/anime/views/anime_edit_page.dart` (approx. line 183)
- **Purpose:** Open the online-metadata search dialog
  ([`showAnimeSearchDialog`](anime_search_dialog.md#showanimesearchdialog)) pre-filled with the
  form's current values, then apply whichever fields the user chose to import back into the form.
- **Inputs:** None (reads the current controller/staged-field values to pass as `currentXxx`
  parameters).
- **Returns:** `Future<void>`.
- **Side effects:** Shows a dialog that performs network requests; `setState`s any of
  `_titleController`, `_titleJaController`, `_endEpController`, `_firstAirDate`, `_airDayOfWeek`,
  `_airTimeController`, `_notesController`, `_coverImage`, `_infoUrlController`.
- **Algorithm:**
  1. Use the title controller's text if non-empty, else the Japanese title, as the initial query.
  2. Await `showAnimeSearchDialog(...)`, passing every current form value as a `currentXxx`
     parameter (so the dialog can show "current vs. fetched" comparisons).
  3. If a non-null result map comes back, apply each key present in the map to its matching
     controller/field — each of the nine possible keys (`title`, `titleJa`, `endEpisode`,
     `firstAirDate`, `airDayOfWeek`, `airTime`, `notes`, `coverImage`, `infoUrl`) is checked and
     applied independently via `result.containsKey(...)`.
- **Usage:**
  ```dart
  if (AppFlavor.isFull)
    IconButton(
      icon: const Icon(Icons.travel_explore),
      tooltip: l10n.searchAnimeInfo,
      onPressed: _showSearchDialog,
    ),
  ```
  (`_AnimeEditPageState.build`, app bar action — full flavor only)
- **Notes:** The result map's keys are entirely defined by the callee — see
  [`showAnimeSearchDialog`](anime_search_dialog.md#showanimesearchdialog) and `_apply` in that file
  for exactly which keys can appear and under what conditions.

### `Future<void> _pickFirstAirDate()` <a id="_pickfirstairdate"></a>
- **Kind:** method of `_AnimeEditPageState`
- **Source:** `lib/features/anime/views/anime_edit_page.dart` (approx. line 245)
- **Purpose:** Show the platform date picker (bounded to years 2000–2040) and stage the chosen date
  as `firstAirDate`.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Shows a `showDatePicker` dialog; `setState`s `_firstAirDate`.
- **Algorithm:** Await `showDatePicker` with `initialDate: _firstAirDate ?? DateTime.now()`; if a
  date is chosen and the widget is still mounted, stage it.
- **Usage:**
  ```dart
  IconButton(
    icon: const Icon(Icons.calendar_today),
    onPressed: _pickFirstAirDate,
  ),
  ```
  (`_AnimeEditPageState.build`, first-air-date row)
- **Notes:** A separate "clear" icon (`onPressed: () => setState(() => _firstAirDate = null)`)
  bypasses this method entirely to unset the date directly.

### `Future<void> _save()` <a id="_save"></a>
- **Kind:** method of `_AnimeEditPageState`
- **Source:** `lib/features/anime/views/anime_edit_page.dart` (approx. line 262)
- **Purpose:** Validate the form, reconcile the episode range, and either update the existing anime
  or create a new one, then leave the page.
- **Inputs:** None (reads every controller/staged field).
- **Returns:** `Future<void>`.
- **Side effects:** May show a "missing fields" `AlertDialog`; calls `AnimeStorage.addOrUpdate`;
  pops the current route (with the new anime's ID, when creating).
- **Algorithm:**
  1. Run the `Form`'s field validators (`_formKey.currentState!.validate()`); abort if invalid.
  2. When creating (`!_isEdit`), require at least one of title/Japanese title to be non-empty;
     otherwise show a blocking dialog listing the missing field and return.
  3. Parse `startEp`/`endEp` from their controllers (defaulting to `1`/`12`) and build the rating via
     [`_buildRating`](#_buildrating).
  4. If `startEp > endEp`, shift `endEp` up so the episode count is preserved relative to the
     original `endEpisode` (when editing) or the raw parsed `endEp` (when creating) —
     `endEp = originalEnd - 1 + startEp`.
  5. When editing: `copyWith` the existing anime with every form field (empty optional strings
     become `null`), `rating`, `clearRating: rating == null`, and a fresh `modifiedAt`; save via
     `AnimeStorage.addOrUpdate`; pop with no result.
  6. When creating: auto-fill `title` from the Japanese title if the title field is empty, build a
     new `Anime` via [`Anime.create`](../models/anime.md#anime-create), save it, and pop the route
     with the new anime's `id` as the result.
- **Usage:**
  ```dart
  TextButton(onPressed: _save, child: Text(l10n.save)),
  ```
  (`_AnimeEditPageState.build`, app bar action)
- **Notes:** The episode-count-preserving adjustment in step 4 only fires when the user (or an
  imported search result) leaves `startEpisode` greater than `endEpisode` — it is a repair step, not
  something exercised on a normal save.

### `AnimeRating? _buildRating()` <a id="_buildrating"></a>
- **Kind:** method of `_AnimeEditPageState`
- **Source:** `lib/features/anime/views/anime_edit_page.dart` (approx. line 378)
- **Purpose:** Assemble an `AnimeRating` from the six rating text fields, collapsing to `null` when
  none of them (and no preserved `extraJson`) hold any data.
- **Inputs:** None (reads the six rating controllers and `_existing?.rating?.extraJson`).
- **Returns:** `AnimeRating?`.
- **Side effects:** None.
- **Algorithm:** Parse each of the six score controllers via `_parseScore`, build an `AnimeRating`
  carrying over `_existing`'s `extraJson` (if any), then return it only if
  [`hasAnyData`](../models/anime.md) is true, else `null`.
- **Usage:**
  ```dart
  final rating = _buildRating();
  ...
  rating: rating,
  clearRating: rating == null,
  ```
  (`_save`, same file)
- **Notes:** Named with a `_build` prefix but does **not** return a `Widget` — it is a data-assembly
  helper for [`_save`](#_save), not a UI builder.

### `Future<void> _search()` <a id="_search-watchurl"></a>
- **Kind:** method of `_WatchUrlSearchDialogState`
- **Source:** `lib/features/anime/views/anime_edit_page.dart` (approx. line 867)
- **Purpose:** Query `anime1.me` (via `AnimeSearchService.searchAnime1`) for watch-page links
  matching the dialog's query text, plus any alternate queries passed in.
- **Inputs:** None (reads `_controller.text`; uses `widget.altQueries`).
- **Returns:** `Future<void>`.
- **Side effects:** Performs a network request via `AnimeSearchService.searchAnime1`; `setState`s
  `_loading`, `_results`, `_error`.
- **Algorithm:**
  1. Trim the query text; return early if empty.
  2. `setState` into a loading state, clearing prior results/error.
  3. Await `AnimeSearchService.searchAnime1(q, altQueries: widget.altQueries)`; on success, store the
     results and set a "no results" error message if the list came back empty.
  4. On any thrown exception, store `e.toString()` as `_error` instead of results.
- **Usage:**
  ```dart
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
    _search();
  }
  ```
  (`_WatchUrlSearchDialogState.initState`, same file; also re-invoked from the search field's
  `onSubmitted` and the search `FilledButton`)
- **Notes:** Errors are surfaced as raw `e.toString()` text rather than a localized message.
