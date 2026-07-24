# lib/shared/widgets/duplicate_check_page.dart

`DuplicateCheckPage` is the settings-accessible page that scans the full anime library for
duplicate records (via `DuplicateService.detect`) and lets the user resolve each group by keeping
one record and either merging or discarding the others. See `AGENTS.md`'s "Duplicate Detection and
Merge" section and [../../../architecture.md](../../../architecture.md) for how this fits the
settings/router surface; the actual detection/merge algorithm lives in
`lib/shared/services/duplicate_service.dart` (not part of this batch).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`DuplicateCheckPage`](#duplicatecheckpage) | class (`StatefulWidget`) | A | Display and resolve duplicate anime groups. |
| `DuplicateCheckPage.new` | constructor (`DuplicateCheckPage`) | B | Create a `DuplicateCheckPage` instance. |
| `DuplicateCheckPage.createState` | method (`DuplicateCheckPage`) | B | Create the mutable state object for this widget. |
| `_DuplicateCheckPageState.initState` | method (`_DuplicateCheckPageState`) | B | Initialize state by triggering the first data load. |
| [`_DuplicateCheckPageState._load`](#_duplicatecheckpagestate_load) | method (`_DuplicateCheckPageState`) | A | Load anime data and run duplicate detection. |
| [`_DuplicateCheckPageState._resolveGroup`](#_duplicatecheckpagestate_resolvegroup) | method (`_DuplicateCheckPageState`) | A | Apply the user's keep/merge/delete choice for one duplicate group. |
| `_DuplicateCheckPageState.build` | method (`_DuplicateCheckPageState`, widget build) | B | Build the page scaffold (loading/empty/list states). |
| `_DuplicateCheckPageState._buildGroupCard` | method (widget helper) | B | Render one duplicate group as a `Card`. |
| `_DuplicateCheckPageState._buildAnimeTile` | method (widget helper) | B | Render one anime row within a group, with keep/merge actions. |
| `_DuplicateCheckPageState._buildCover` | method (widget helper) | B | Render a cover thumbnail or placeholder icon for one anime. |

## Documentation

### `class DuplicateCheckPage extends StatefulWidget` <a id="duplicatecheckpage"></a>
- **Kind:** class (top-level widget)
- **Source:** `lib/shared/widgets/duplicate_check_page.dart` (approx. line 19)
- **Purpose:** Entry-point widget for the "Check Duplicates" settings flow: scans the full anime
  library for duplicates and lets the user keep, merge, or delete redundant records group by group.
- **Inputs:** None (no constructor parameters beyond `key`).
- **Returns:** N/A (widget class).
- **Side effects:** Its state (`_DuplicateCheckPageState`) reads and mutates anime storage once
  mounted.
- **Algorithm:** See `_load` and `_resolveGroup` below for the actual detection/resolution flow;
  this class itself only declares the widget and its state factory.
- **Usage:**
  ```dart
  GoRoute(
    path: '/duplicate-check',
    builder: (context, state) => const DuplicateCheckPage(),
  ),
  ```
  (from `lib/app/router.dart`; also pushed directly via `MaterialPageRoute` from
  `lib/features/settings/views/settings_page.dart`'s "Check Duplicates" entry)
- **Notes:** Routed both through `go_router` (`/duplicate-check`) and via a direct
  `Navigator.push(MaterialPageRoute(...))` from the settings page — two different navigation
  mechanisms reach the same widget.

### `Future<void> _load()` <a id="_duplicatecheckpagestate_load"></a>
- **Kind:** method of `_DuplicateCheckPageState`
- **Source:** `lib/shared/widgets/duplicate_check_page.dart` (approx. line 57)
- **Purpose:** Load the full anime list from storage and recompute duplicate groups.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Reads `AnimeStorage.load()`; calls `setState` to update `_allAnime`, `_result`,
  and `_loading`.
- **Algorithm:**
  1. Await `AnimeStorage.load()` to get the current `AnimeData` (all records).
  2. Guard on `mounted` (widget may have been disposed while awaiting).
  3. `setState`: store `data.animes` in `_allAnime`, run `DuplicateService.detect(_allAnime)` and
     store the result in `_result`, and set `_loading = false`.
- **Usage:**
  ```dart
  @override
  void initState() {
    super.initState();
    _load();
  }
  ```
  (from `_DuplicateCheckPageState.initState`, same file; also called again at the end of
  `_resolveGroup` to refresh the list after a resolution)
- **Notes:** Not awaited from `initState` (fire-and-forget), so the page shows a loading spinner
  (`_loading` starts `true`) until this completes.

### `Future<void> _resolveGroup(DuplicateGroup group, int keepIndex, {required bool merge})` <a id="_duplicatecheckpagestate_resolvegroup"></a>
- **Kind:** method of `_DuplicateCheckPageState`
- **Source:** `lib/shared/widgets/duplicate_check_page.dart` (approx. line 74)
- **Purpose:** Apply the user's chosen resolution for one duplicate group — keep one record and
  discard the rest, optionally merging fields from the discarded records into the kept one first.
- **Inputs:** `group` — the `DuplicateGroup` being resolved; `keepIndex` — index within
  `group.animes` of the record to keep; `merge` — whether to merge the other records' fields into
  the kept one before deleting them.
- **Returns:** `Future<void>`.
- **Side effects:** May call `DuplicateService.merge` and `AnimeStorage.addOrUpdate`; calls
  `FileOpenService.deleteAnimeByIds` on the non-kept records; reloads the page via `_load()`; shows
  a `SnackBar` confirming the resolution.
- **Algorithm:**
  1. Extract `kept = group.animes[keepIndex]` and `others` (every other record in the group, via
     index filtering).
  2. If `merge` is true, compute `DuplicateService.merge(kept, others)` and save it via
     `AnimeStorage.addOrUpdate` — this absorbs fields from `others` into `kept` under the kept
     record's ID before the others are deleted.
  3. Delete every record in `others` via `FileOpenService.deleteAnimeByIds(others.map((a) => a.id))`.
  4. Call `_load()` to refresh `_allAnime`/`_result` from storage.
  5. If still mounted, show a `SnackBar` with the localized `duplicateResolved` message.
- **Usage:**
  ```dart
  TextButton(
    onPressed: () => _resolveGroup(group, index, merge: false),
    child: Text(l10n.duplicateKeepFirst),
  ),
  TextButton(
    onPressed: () => _resolveGroup(group, index, merge: true),
    child: Text(l10n.duplicateMergeAll),
  ),
  ```
  (from `_buildAnimeTile`, same file)
- **Notes:** When `merge` is `false` ("keep first"), the non-kept records are deleted outright with
  no field absorption — any data unique to them (notes, ratings, etc.) is lost. The merge algorithm
  itself (field-fallback rules, episode-status precedence) is documented on
  `DuplicateService.merge` (see `lib/shared/services/duplicate_service.dart`, not part of this
  batch).
