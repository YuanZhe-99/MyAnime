# lib/features/anime/views/anime_edit_page.dart

`AnimeEditPage` is the create/edit form for a single `Anime` record: text fields for
title/season/episode range/URLs/notes, dropdowns for type override and air day, a date picker for
`firstAirDate`, rating sub-score fields, a Local Archive section recording a downloaded local copy,
and (full-flavor builds only) online metadata search and watch-URL search integrations. It persists
through `AnimeStorage`
([`../services/anime_storage.md`](../services/anime_storage.md)) and builds/parses the `Anime`/
`AnimeRating`/`AnimeLocalArchive` model ([`../models/anime.md`](../models/anime.md)); the archive
enum labels come from [`archive_labels.md`](archive_labels.md). It also defines a private
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
| `_AnimeEditPageState.dispose` | method (`_AnimeEditPageState`) | B | Dispose all 17 owned `TextEditingController`s. |
| [`_pickCoverImage`](#_pickcoverimage) | method (`_AnimeEditPageState`) | A | Let the user pick a cover image file and stage its path. |
| [`_searchWatchUrl`](#_searchwatchurl) | method (`_AnimeEditPageState`) | A | Open the watch-URL search dialog and apply the chosen URL. |
| [`_showSearchDialog`](#_showsearchdialog) | method (`_AnimeEditPageState`) | A | Open the online metadata search dialog and merge its result into the form. |
| [`_pickFirstAirDate`](#_pickfirstairdate) | method (`_AnimeEditPageState`) | A | Show a date picker and stage the chosen `firstAirDate`. |
| [`_save`](#_save) | method (`_AnimeEditPageState`) | A | Validate the form and create or update the anime record. |
| [`_buildRating`](#_buildrating) | method (`_AnimeEditPageState`) | A | Assemble an `AnimeRating` from the rating text fields, or `null` if empty. |
| [`_buildLocalArchive`](#_buildlocalarchive) | method (`_AnimeEditPageState`) | A | Assemble an `AnimeLocalArchive` from the archive controls, or `null` if untouched. |
| `_parseScore` | method (`_AnimeEditPageState`) | B | Parse a rating controller's text into a `double?`. |
| `_formatScore` | method (`_AnimeEditPageState`) | B | Format a score as an integer when whole, else one decimal place. |
| [`_AnimeEditPageState.build`](#_animeeditpagestate_build) | method (`_AnimeEditPageState`, widget build) | A | Build the edit/create form as one column or two panes. |
| [`_buildCoverPicker`](#_buildcoverpicker) | method (`_AnimeEditPageState`) | A | Build the cover picker at an explicit size. |
| [`_buildTitleFields`](#_buildtitlefields) | method (`_AnimeEditPageState`) | A | Build the two title fields that share the left pane with the cover. |
| [`_buildDetailFields`](#_builddetailfields) | method (`_AnimeEditPageState`) | A | Build every form field below the two titles. |
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
     (`_airDayOfWeek`, `_firstAirDate`, `_manualType`, `_coverImage`, `_archived`, `_archiveSource`, `_archiveResolution`).
  3. Rating sub-scores are formatted through `_formatScore` (Tier B, same file) before being placed
     into their controllers.
  4. The Local Archive controls are seeded from `found.localArchive` with null-safe defaults, so an
     anime that has no archive record opens with the switch off and every field blank.
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
  `_airTimeController`, `_notesController`, `_coverImage`, `_infoUrlController`, `_externalMeta`.
- **Algorithm:**
  1. Use the title controller's text if non-empty, else the Japanese title, as the initial query.
  2. Await `showAnimeSearchDialog(...)`, passing every current form value as a `currentXxx`
     parameter (so the dialog can show "current vs. fetched" comparisons).
  3. If a non-null result map comes back, apply each key present in the map to its matching
     controller/field — each of the ten possible keys (`title`, `titleJa`, `endEpisode`,
     `firstAirDate`, `airDayOfWeek`, `airTime`, `notes`, `coverImage`, `infoUrl`, `externalMeta`)
     is checked and applied independently via `result.containsKey(...)`. `externalMeta` is held in
     `_externalMeta` rather than a form controller — it is never typed by hand — and is written
     out with the record in `_save()`.
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
     [`_buildRating`](#_buildrating), plus the local-archive record via
     [`_buildLocalArchive`](#_buildlocalarchive).
  4. If `startEp > endEp`, shift `endEp` up so the episode count is preserved relative to the
     original `endEpisode` (when editing) or the raw parsed `endEp` (when creating) —
     `endEp = originalEnd - 1 + startEp`.
  5. When editing: `copyWith` the existing anime with every form field (empty optional strings
     become `null`), `rating`, `clearRating: rating == null`, `localArchive`,
     `clearLocalArchive: localArchive == null`, and a fresh `modifiedAt`; save via
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

### `AnimeLocalArchive? _buildLocalArchive()` <a id="_buildlocalarchive"></a>
- **Kind:** method of `_AnimeEditPageState`
- **Source:** `lib/features/anime/views/anime_edit_page.dart` (approx. line 416)
- **Purpose:** Assemble an `AnimeLocalArchive` from the Local Archive section's controls, collapsing
  to `null` when the section was left untouched.
- **Inputs:** None (reads `_archived`, `_archiveSource`, `_archiveResolution`, the two archive
  controllers, and `_existing?.localArchive?.extraJson`).
- **Returns:** `AnimeLocalArchive?`.
- **Side effects:** None.
- **Algorithm:** Trim the location text (empty → `null`), `int.tryParse` the copies text, build an
  `AnimeLocalArchive` carrying over `_existing`'s archive `extraJson` (if any), then return it only
  if [`hasAnyData`](../models/anime.md#animelocalarchive-hasanydata) is true, else `null`.
- **Usage:**
  ```dart
  final localArchive = _buildLocalArchive();
  ...
  localArchive: localArchive,
  clearLocalArchive: localArchive == null,
  ```
  (`_save`, same file)
- **Notes:** Exactly parallel to [`_buildRating`](#_buildrating), including the `_build` prefix that
  does not return a `Widget`. The `null` collapse is what keeps `anime_data.json` free of empty
  `localArchive` objects for anime that never used the feature. The sub-fields stay editable even
  when the `archived` switch is off — there is no cross-field gating, so "not downloaded yet, but
  earmarked for NAS-01" is expressible.
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

### `Widget build(BuildContext context)` <a id="_animeeditpagestate_build"></a>
- **Kind:** method of `_AnimeEditPageState` (widget build)
- **Source:** `lib/features/anime/views/anime_edit_page.dart` (approx. line 487)
- **Purpose:** Build the edit/create form as one column or two panes.
- **Inputs:** `context`.
- **Returns:** The page's widget tree.
- **Side effects:** Creates UI widgets from the current state.
- **Algorithm:**
  1. Build `_buildTitleFields` and `_buildDetailFields` once, so both layouts get the same widgets.
  2. When `useDetailTwoPane(screen.width, screen.height)` is false, return the original single
     `ListView`: cover at 120 × 170, the titles, then the detail fields.
  3. Otherwise return a `Row` of a `SizedBox(width: detailLeftPaneWidth(constraints.maxWidth))`
     holding the cover at `editCoverSize` and the two titles, a `VerticalDivider(width: 1)`, and an
     `Expanded` `ListView` of the detail fields.
- **Usage:**
  ```dart
  GoRoute(
    path: '/anime/edit/:id',
    builder: (context, state) =>
        AnimeEditPage(animeId: state.pathParameters['id']),
  ),
  ```
  (from `appRouter` in `lib/app/router.dart`)
- **Notes:** Added in 1.5.5, on the shape the detail page has had since 1.5.2 and through the same
  `useDetailTwoPane` delegate. This route sits **outside** the `ShellRoute`, so there is no
  navigation rail to subtract and `constraints.maxWidth` is the whole width — which is why this is
  the one adaptive page that does not go through `shellContentWidth`.

  Both panes stay inside the single `Form`, so `_save`'s `validate()` still reaches the title field
  on the left and the season field on the right. Nothing here is stateful beyond the controllers
  the state object already owned, so folding the device swaps the layouts on the next frame with a
  half-typed title intact.

### `Widget _buildCoverPicker({required double width, required double height})` <a id="_buildcoverpicker"></a>
- **Kind:** method of `_AnimeEditPageState`
- **Source:** `lib/features/anime/views/anime_edit_page.dart` (approx. line 552)
- **Purpose:** Build the cover picker at an explicit size.
- **Inputs:** `width`, `height` — the picker box in logical pixels.
- **Returns:** `Widget`.
- **Side effects:** Reads the cover file through `ImageService.resolve`; tapping opens the picker.
- **Algorithm:** A `Center` around a `GestureDetector` around a `Container` at the given size,
  showing the resolved cover file or an `add_photo_alternate` icon.
- **Usage:**
  ```dart
  _buildCoverPicker(width: cover.width, height: cover.height),
  ```
  (from `build`, same file, two-pane branch)
- **Notes:** Extracted from `build` in 1.5.5 and given a size because the two-pane layout derives
  it from the height its left pane has left over, while the single-column layout keeps the original
  fixed 120 × 170 box. Mirrors `anime_detail_page._buildCover`.

### `List<Widget> _buildTitleFields(AppLocalizations l10n)` <a id="_buildtitlefields"></a>
- **Kind:** method of `_AnimeEditPageState`
- **Source:** `lib/features/anime/views/anime_edit_page.dart` (approx. line 596)
- **Purpose:** Build the two title fields that share the left pane with the cover.
- **Inputs:** `l10n`.
- **Returns:** `List<Widget>` — the title field, a 12 dp gap, the Japanese title field.
- **Side effects:** None.
- **Algorithm:** Returns the two `TextFormField`s unchanged from their single-column form.
- **Usage:**
  ```dart
  final titleFields = _buildTitleFields(l10n);
  ```
  (from `build`, same file)
- **Notes:** Separate from [`_buildDetailFields`](#_builddetailfields) because these are exactly
  what the user asked to keep beside the cover. They have to stay together wherever they render:
  the title's validator accepts an empty value when the Japanese title is filled in, so splitting
  them would put a field's validity in another pane.

### `List<Widget> _buildDetailFields(AppLocalizations l10n)` <a id="_builddetailfields"></a>
- **Kind:** method of `_AnimeEditPageState`
- **Source:** `lib/features/anime/views/anime_edit_page.dart` (approx. line 630)
- **Purpose:** Build every form field below the two titles.
- **Inputs:** `l10n`.
- **Returns:** `List<Widget>` — season, episode range, type, air day, air time, first air date,
  info URL, watch URL, the rating card, the local-archive card and notes.
- **Side effects:** None.
- **Algorithm:** Returns the fields verbatim from what used to be the tail of `build`'s `ListView`.
- **Usage:**
  ```dart
  Expanded(
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: detailFields,
    ),
  ),
  ```
  (from `build`, same file, two-pane branch)
- **Notes:** These are the scrolling pane's children in the two-pane layout and the tail of the
  single `ListView` otherwise — one list, two hosts, so the field order cannot drift between the
  layouts. This is the `ListView` `test/local_archive_ui_test.dart` scrolls; since 1.5.5 it must
  address it through `find.byType(ListView)` rather than as the first `Scrollable` on the page,
  because the left pane's scroll view now comes first.
