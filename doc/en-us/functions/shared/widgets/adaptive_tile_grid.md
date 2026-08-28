# lib/shared/widgets/adaptive_tile_grid.dart

The widget half of the multi-column list layout: two builders that turn a flat list of tiles into
rows, and the app-bar control that lets the user pick the column count. The arithmetic lives
separately in [`../utils/adaptive_layout.md`](../utils/adaptive_layout.md); this file only builds
widgets from it.

Used by all three data-browsing modules — `home_page.dart`, `management_page.dart` and
`statistics_page.dart` (see
[../../features/anime/views/home_page.md](../../features/anime/views/home_page.md) and its
siblings). The concept-level description of the behaviour is in
[../../../adaptive-layout.md](../../../adaptive-layout.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`adaptiveTileRow`](#adaptivetilerow) | top-level function | A | Build one row of a multi-column list, filled left to right. |
| [`adaptiveTileRows`](#adaptivetilerows) | top-level function | A | Build a list's children as rows, single column or multi-column. |
| [`listColumnsButton`](#listcolumnsbutton) | top-level function | A | Build the app-bar control that picks a list's column count. |

## Documentation

### `Widget adaptiveTileRow({required int rowIndex, required int columns, required int itemCount, required Widget Function(int index) itemBuilder, double gap = listTileGap})` <a id="adaptivetilerow"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/widgets/adaptive_tile_grid.dart` (approx. line 19)
- **Purpose:** Build the tiles that belong to one row of a multi-column list.
- **Inputs:** `rowIndex` — the zero-based row; `columns` — tiles per row; `itemCount` — total tiles
  in the flat list; `itemBuilder` — builds one tile by its index in that flat list; `gap` —
  spacing between columns.
- **Returns:** A `Row` of equally wide tiles, top-aligned.
- **Side effects:** None beyond building widgets.
- **Algorithm:** For each column `c` in `0..columns-1`, insert a `SizedBox(width: gap)` before every
  column but the first, then an `Expanded` holding `itemBuilder(rowIndex * columns + c)` when that
  index is in range and a `SizedBox.shrink()` when it is not. Index order across successive rows is
  therefore left to right, then top to bottom.
- **Usage:**
  ```dart
  return ListView.builder(
    itemCount: listRowCount(animeList.length, columns),
    itemBuilder: (context, row) => adaptiveTileRow(
      rowIndex: row,
      columns: columns,
      itemCount: animeList.length,
      itemBuilder: (i) => _buildAnimeTile(animeList[i], theme, l10n, columns),
    ),
  );
  ```
  (from `_ManagementPageState._buildQuarterView`)
- **Notes:** **Deliberately a `Row` of `Expanded` children rather than a `GridView`.** Two of the
  three list modules build their tiles as children of an outer scroll view — the statistics page's
  outer `ListView`, and the home page's heterogeneous one that also carries the calendar — where a
  nested scrollable would need `shrinkWrap: true` and `NeverScrollableScrollPhysics`. The third,
  the management page, relies on `ListView.builder` virtualization that a pre-built grid would
  throw away for a large library. Feeding this from a builder over `listRowCount` rows keeps both
  properties. A `GridView` would also force a fixed `childAspectRatio` per cell, which is brittle
  under large text scales; `Expanded` children keep their natural height.

  Short final rows are padded with empty cells rather than left to stretch, so the last row's tiles
  line up with the columns above them.

### `List<Widget> adaptiveTileRows({required int columns, required int itemCount, required Widget Function(int index) itemBuilder, double gap = listTileGap})` <a id="adaptivetilerows"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/widgets/adaptive_tile_grid.dart` (approx. line 47)
- **Purpose:** Produce a list's children ready to spread into a `ListView` or `Column`.
- **Inputs:** `columns`, `itemCount`, `itemBuilder`, `gap` — as above.
- **Returns:** `List<Widget>`.
- **Side effects:** None beyond building widgets.
- **Algorithm:** At `columns <= 1`, `List.generate(itemCount, itemBuilder)` — the tiles untouched.
  Otherwise `List.generate(listRowCount(itemCount, columns), ...)` over `adaptiveTileRow`.
- **Usage:**
  ```dart
  ...adaptiveTileRows(
    columns: columns,
    itemCount: unwatched.length,
    itemBuilder: (i) => _buildEpisodeTile(unwatched[i], theme, l10n, settings),
  ),
  ```
  (from `_HomePageState.build`)
- **Notes:** Returning the tiles untouched at one column is what lets a caller wrap its
  single-column tile in something the grid cannot carry. The management page relies on this: its
  swipe-to-edit / swipe-to-delete `Dismissible` stays in place at one column and is dropped above
  it, because a horizontal drag inside one narrow cell is ambiguous. Use this for lists built as
  children of an outer scroll view; use `adaptiveTileRow` directly where a `ListView.builder` must
  keep its virtualization.

### `Widget listColumnsButton(BuildContext context, {required int preference, required int capacity, required ValueChanged<int> onChanged})` <a id="listcolumnsbutton"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/widgets/adaptive_tile_grid.dart` (approx. line 79)
- **Purpose:** Offer the column-count choice from the page's app bar.
- **Inputs:** `context`; `preference` — the stored choice, `listColumnsAuto` or a pinned count;
  `capacity` — the most columns the current width can carry; `onChanged` — receives the new
  preference.
- **Returns:** A `PopupMenuButton<int>`, or `SizedBox.shrink()` when `capacity <= 1`.
- **Side effects:** None beyond invoking `onChanged` when the user picks.
- **Algorithm:** Returns an empty widget when the window cannot carry more than one column.
  Otherwise a `PopupMenuButton<int>` with `Icons.view_column_outlined`, `initialValue: preference`,
  and items `listColumnsAuto` followed by `1..listMaxColumns`.
- **Usage:**
  ```dart
  listColumnsButton(
    context,
    preference: settings.statsListColumns,
    capacity: capacity,
    onChanged: (value) =>
        ref.read(appSettingsProvider.notifier).setStatsListColumns(value),
  ),
  ```
  (from `_StatisticsPageState.build`, in the app bar's `actions`)
- **Notes:** **Hidden rather than disabled** when only one column fits, so a phone and a folded
  cover screen never show a control that could not do anything. The menu still offers every count
  up to `listMaxColumns` even when the current width cannot use them all, so a preference can be
  set while folded and take effect on unfolding; the check mark tracks the stored preference, while
  what renders is that preference clamped by `listColumnCount`. Each of the three modules stores
  its own preference, so the same control appears three times with three different values.
