# lib/features/anime/views/series_widgets.dart

The series UI (1.6.0): the detail page's *Series* card and the manage sheet it opens. Both sit on
top of the pure engine in [`../services/series_service.md`](../services/series_service.md); the
detail page wires them up in `_buildDetailChildren` and `_runSeriesAction`
([`anime_detail_page.md`](anime_detail_page.md)). The manage sheet picks a bottom sheet or a dialog
through `canSplitLayout` ([`../../../shared/utils/adaptive_layout.md`](../../../shared/utils/adaptive_layout.md)),
so it follows the app-wide split rule. Behavior is described in
[`../../../../features/series-linking.md`](../../../../features/series-linking.md). Widget test:
`test/series_card_ui_test.dart`.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `SeriesCard.new` | constructor (`SeriesCard`) | B | Create a series card for a series of at least two members, the current record, and two callbacks. |
| [`SeriesCard.build`](#seriescard-build) | method (`SeriesCard`, widget build) | A | Build the card: header, action menu, and one row per member. |
| `_memberTile` | method (`SeriesCard`, widget helper) | B | One member row: position, title, season label with watched/total, status icon; the current record is highlighted and not tappable. |
| `viewingStatusIcon` | top-level function | B | Pick an icon for an `AnimeViewingStatus`; shared by the card and the sheet. |
| [`showSeriesManageSheet`](#showseriesmanagesheet) | top-level function | A | Open the manage sheet as a bottom sheet or a dialog. |
| `SeriesManageSheet.new` | constructor (`SeriesManageSheet`) | B | Create the sheet for one record and the index its edits are computed against. |
| `SeriesManageSheet.createState` | method (`SeriesManageSheet`) | B | Create the state object. |
| `_SeriesManageSheetState.initState` | method (`_SeriesManageSheetState`) | B | Initialise the editable member order from the index. |
| `_SeriesManageSheetState.dispose` | method (`_SeriesManageSheetState`) | B | Dispose the search controller. |
| [`_apply`](#_apply) | method (`_SeriesManageSheetState`) | A | Write the records an edit produced and close the sheet. |
| [`_search`](#_search) | method (`_SeriesManageSheetState`) | A | Return library records whose folded titles contain the search text. |
| [`_SeriesManageSheetState.build`](#seriesmanagesheet) | method (`_SeriesManageSheetState`, widget build) | A | Build the search field, suggestions, and reorderable member list. |
| `_header` | method (`_SeriesManageSheetState`, widget helper) | B | Build a section header. |

The `SeriesAction` enum (`manage`, `addNextSeason`, `remove`, `letAppDecide`) carries no
`/// Purpose:` comment and is not indexed as a row; it is what both the card's menu and the detail
page's app-bar link menu hand to `_runSeriesAction`.

## Documentation

### `Widget build(BuildContext context)` (`SeriesCard`) <a id="seriescard-build"></a>
- **Kind:** method of `SeriesCard` (widget build)
- **Source:** `lib/features/anime/views/series_widgets.dart` (line 61)
- **Purpose:** Build the detail page's *Series* card.
- **Inputs:** `context`. Fields: `series` (at least two members), `current`, `onOpen`, `onAction`.
- **Returns:** `Widget` — a `Card`.
- **Side effects:** None; taps call `onOpen`, menu picks call `onAction`.
- **Algorithm:**
  1. Header row: an icon, *Series*, and a subtitle — *Linked by you* for a curated series,
     *Grouped automatically* for a derived one.
  2. A `PopupMenuButton<SeriesAction>`: *Manage series…*, *Add next season*, *Remove from series*,
     and *Let the app decide* only when `current` has a `seriesLink` of its own to remove.
  3. One `_memberTile` per member in series order.
- **Usage:**
  ```dart
  SeriesCard(
    series: series,
    current: anime,
    onOpen: (a) => context.go('/anime/detail/${a.id}'),
    onAction: _runSeriesAction,
  ),
  ```
  (`anime_detail_page.dart`, `_buildDetailChildren`)
- **Notes:** The card sits in `_buildDetailChildren`, so in the two-pane detail layout it renders in
  the right pane.

### `Future<bool> showSeriesManageSheet(BuildContext context, {required Anime anime, required SeriesIndex index})` <a id="showseriesmanagesheet"></a>
- **Kind:** top-level function
- **Source:** `lib/features/anime/views/series_widgets.dart` (line 180)
- **Purpose:** Open the series manage sheet for `anime`.
- **Inputs:** `context`; `anime`; `index` — built from the current library.
- **Returns:** `Future<bool>` — whether anything was written.
- **Side effects:** Shows a modal; the sheet may write records through `AnimeStorage.addOrUpdateAll`.
- **Algorithm:** When `canSplitLayout(width, height)` holds, a `Dialog` constrained to 560 × 640;
  otherwise a scroll-controlled, safe-area modal bottom sheet at 85 % height.
- **Usage:** `_runSeriesAction`'s `manage` branch, reached from the card's *Manage series…* and the
  app bar's *Link to series…*.
- **Notes:** No new breakpoint: it reuses the app-wide split rule, so a window that splits into panes
  gets a dialog. See [`../../../../adaptive-layout.md`](../../../../adaptive-layout.md).

### `Future<void> _apply(List<Anime> writes)` <a id="_apply"></a>
- **Kind:** method of `_SeriesManageSheetState`
- **Source:** `lib/features/anime/views/series_widgets.dart` (line 270)
- **Purpose:** Write the records an edit produced and close the sheet.
- **Inputs:** `writes` — from `SeriesEditor.link` or `reorder`.
- **Returns:** `Future<void>`.
- **Side effects:** Sets `_busy`; one `AnimeStorage.addOrUpdateAll`; pops the sheet with `true`.
- **Notes:** Ignored while a write is already in flight, and every tile and the save button are
  disabled meanwhile, so a double tap cannot write twice.

### `List<Anime> _search(String query)` <a id="_search"></a>
- **Kind:** method of `_SeriesManageSheetState`
- **Source:** `lib/features/anime/views/series_widgets.dart` (line 283)
- **Purpose:** Return library records matching the search text.
- **Inputs:** `query`.
- **Returns:** `List<Anime>` — at most 30, excluding the current record; empty for a blank query.
- **Side effects:** None.
- **Algorithm:** Fold the query with `AnimeSearchService.foldTitle`, then keep records (from
  `SeriesIndex.all`, in `id` order) any of whose `seriesTitlesOf` titles folds to a string that
  contains it.
- **Notes:** Folding makes script and width differences irrelevant, so `进击` finds `進撃`.

### `Widget build(BuildContext context)` (`_SeriesManageSheetState`) <a id="seriesmanagesheet"></a>
- **Kind:** method of `_SeriesManageSheetState` (widget build)
- **Source:** `lib/features/anime/views/series_widgets.dart` (line 306)
- **Purpose:** Build the manage sheet: search, suggestions, and member order.
- **Returns:** `Widget`.
- **Side effects:** None directly; taps call `_apply`.
- **Algorithm:**
  1. A search field (*Search your library*).
  2. With text: the `_search` results, or *No matching anime*.
  3. Without text: *Suggestions* from `SeriesIndex.suggestionsFor`, then — when the record's series
     has at least two members — *In this series* as a `SliverReorderableList` with drag handles, and
     a *Save order* button enabled once the order changed.
  4. Tapping any suggestion or search result applies `SeriesEditor.link(current, tapped)`; *Save
     order* applies `SeriesEditor.reorder`.
- **Notes:** Linking moves the current record into the tapped record's series (materialising it
  first). Nothing is written until a tap or *Save order*; closing the sheet writes nothing.
