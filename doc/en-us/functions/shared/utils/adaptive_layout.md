# lib/shared/utils/adaptive_layout.dart

The app-wide adaptive-layout policy: the `splitMinWidth`, `splitMinHeight` and `splitMinAspect`
thresholds that decide whether a layout may split at all, and the `listTileMinWidth`,
`listTileGap`, `listMaxColumns` and `listColumnsAuto` constants that decide how many columns a list
gets once it may, plus `navRailMinWidth`, `navRailWidth` and `settingsRightPaneMinWidth`
for the shell's navigation rail and the settings detail pane, and `statsSummaryPaneMinWidth`,
`statsChartMinWidth`, `rankingFilterMinWidth`, `rankingScoreSourceWidth` and
`rankingDirectionWidth` for the statistics page, and `metaUpdateCardMinWidth` for the metadata
review page. Twelve pure helpers sit on top of them.

The module deliberately depends on nothing but `dart:core` — it holds no Flutter imports, and
`canSplitLayout` takes two doubles rather than a `Size` for exactly that reason — so every helper
is directly unit-testable (`test/adaptive_layout_test.dart`), and the rendered result is covered
separately at real device geometries by `test/list_columns_ui_test.dart`,
`test/detail_layout_ui_test.dart`, `test/kana_layout_ui_test.dart`,
`test/settings_two_pane_ui_test.dart`, `test/shell_nav_ui_test.dart`,
`test/statistics_layout_ui_test.dart`, `test/anime_edit_two_pane_ui_test.dart` and
`test/metadata_updates_layout_ui_test.dart`.

The prose derivation of these numbers, the foldable device tables and the reconciliation with
Google's guidance live in [../../../adaptive-layout.md](../../../adaptive-layout.md). This page
documents the declarations.

Consumers: `detail_layout.dart` (see [detail_layout.md](detail_layout.md)), whose
`useDetailTwoPane` is a one-line delegate to `canSplitLayout`; `home_page.dart`,
`management_page.dart` and `statistics_page.dart` for their list column counts; and
`anime_storage.dart` and `app_settings.dart` for `listColumnsAuto` and `listMaxColumns` when
validating the stored preference; `shell_scaffold.dart` for `useNavigationRail`;
`kana_page.dart` for `columnCapacity` at its own minimums; `settings_page.dart` for
`settingsLeftPaneWidth`; `metadata_updates_page.dart` for `canSplitLayout`, `columnCapacity` at
`metaUpdateCardMinWidth` and `listRowCount`; and `statistics_page.dart` again for
`useStatsSideBySide`, `statsSummaryPaneWidth` and `useRankingSortRow`.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`canSplitLayout`](#cansplitlayout) | top-level function | A | Report whether a layout may split into panes or columns. |
| [`useNavigationRail`](#usenavigationrail) | top-level function | A | Report whether the shell should show a navigation rail. |
| [`shellContentWidth`](#shellcontentwidth) | top-level function | A | Return the width a shell page's content actually receives. |
| [`shellListBottomInset`](#shelllistbottominset) | top-level function | A | Return the bottom padding a shell page's scrolling list needs. |
| [`columnCapacity`](#columncapacity) | top-level function | A | Return how many columns of a given minimum width fit a content box. |
| [`listColumnCapacity`](#listcolumncapacity) | top-level function | A | Return how many list columns a given content width can carry. |
| [`listColumnCount`](#listcolumncount) | top-level function | A | Return the number of columns a list should actually render. |
| [`listRowCount`](#listrowcount) | top-level function | A | Return how many rows a list of items needs at a column count. |
| [`settingsLeftPaneWidth`](#settingsleftpanewidth) | top-level function | A | Return the width of the settings page's fixed left pane. |
| [`useStatsSideBySide`](#usestatssidebyside) | top-level function | A | Report whether the statistics summary fits beside the trend chart. |
| [`statsSummaryPaneWidth`](#statssummarypanewidth) | top-level function | A | Return the width of the statistics summary's 2x2 card pane. |
| [`useRankingSortRow`](#userankingsortrow) | top-level function | A | Report whether the ranking sort controls fit on a single row. |

The sixteen constants are plain declarations without `/// Purpose:` comments and are not indexed as
separate rows.

## Documentation

### `bool canSplitLayout(double width, double height)` <a id="cansplitlayout"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/adaptive_layout.dart` (approx. line 44)
- **Purpose:** Decide whether the viewport is the right shape and size to split at all.
- **Inputs:** `width`, `height` — the viewport size in logical pixels, read from
  `MediaQuery.sizeOf(context)`.
- **Returns:** `bool` — `true` when all three conditions hold.
- **Side effects:** None.
- **Algorithm:** Three independent tests, all of which must pass:
  1. `width >= splitMinWidth` (600.0)
  2. `height >= splitMinHeight` (480.0)
  3. `width / height >= splitMinAspect` (0.82)

  A non-positive height is rejected before the division.
- **Usage:**
  ```dart
  final capacity = canSplitLayout(screen.width, screen.height)
      ? listColumnCapacity(screen.width)
      : 1;
  ```
  (from `_HomePageState.build`, `lib/features/anime/views/home_page.dart`)
- **Notes:** **The aspect test is the load-bearing one, and it is why this is not a plain width
  breakpoint.** The Galaxy Z Fold 8 unfolds to a 4:3 *landscape* panel, so in portrait it is 3:4 —
  narrower relative to its height than the near-square Fold 7 it replaced, despite being newer.
  One device therefore needs two different answers at one width. The width floor is the usual
  Material 3 *medium* / Android `sw600dp` threshold. The height floor exists because the aspect
  test alone admits wide, short viewports — a folded cover screen or an ordinary phone held in
  landscape would otherwise split. Full derivation, device tables and the deliberate divergence
  from Google's "use width, not aspect ratio" guidance are in
  [../../../adaptive-layout.md](../../../adaptive-layout.md).

### `bool useNavigationRail(double screenWidth)` <a id="usenavigationrail"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/adaptive_layout.dart` (approx. line 87)
- **Purpose:** Decide whether the shell puts navigation at the side or along the bottom.
- **Inputs:** `screenWidth` â the whole screen width in logical pixels.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** `screenWidth >= navRailMinWidth` (600.0).
- **Usage:**
  ```dart
  if (!useNavigationRail(MediaQuery.sizeOf(context).width)) {
    return Scaffold(body: child, bottomNavigationBar: NavigationBar(...));
  }
  ```
  (from `ShellScaffold.build`)
- **Notes:** **Width only, deliberately â this is not [`canSplitLayout`](#cansplitlayout) and must
  not be routed through it.** A rail is not a split: it trades width, which is abundant whenever
  this returns true, for height, which is not. The case it helps most is the one the split rule
  rejects on purpose â an ordinary phone in landscape at 915 Ã 412, where a bottom bar spends 19%
  of the height on navigation while 915 logical pixels of width sit unused.

### `double shellContentWidth(double screenWidth)` <a id="shellcontentwidth"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/adaptive_layout.dart` (approx. line 96)
- **Purpose:** Report how much width is left for a shell page after the navigation rail.
- **Inputs:** `screenWidth` â the whole screen width in logical pixels.
- **Returns:** `double`, never negative.
- **Side effects:** None.
- **Algorithm:** Subtracts `navRailWidth` (81 â an 80 dp rail plus its 1 dp divider) when
  [`useNavigationRail`](#usenavigationrail) is true, and floors the result at zero.
- **Usage:**
  ```dart
  final contentWidth = shellContentWidth(screen.width);
  final capacity = canSplitLayout(screen.width, screen.height)
      ? listColumnCapacity(contentWidth)
      : 1;
  ```
  (from `_ManagementPageState.build`)
- **Notes:** Pass the result wherever a capacity or a pane width is being computed; keep passing
  the untouched screen size to `canSplitLayout`, which asks about the window's shape rather than
  about the room left inside it. Introduced in 1.5.4 with the rail: before it, the three list pages
  passed the raw screen width and were correct only because nothing had been subtracted yet.

### `double shellListBottomInset(double screenWidth)` <a id="shelllistbottominset"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/adaptive_layout.dart` (approx. line 110)
- **Purpose:** Give a scrolling page the bottom padding its shell chrome calls for.
- **Inputs:** `screenWidth` â the whole screen width in logical pixels.
- **Returns:** `double` â 16 with a rail, 80 with a bottom bar.
- **Side effects:** None.
- **Algorithm:** `useNavigationRail(screenWidth) ? 16.0 : 80.0`.
- **Usage:**
  ```dart
  padding: EdgeInsets.only(
    bottom: shellListBottomInset(MediaQuery.sizeOf(context).width),
  ),
  ```
  (from `_ManagementPageState._buildQuarterView`)
- **Notes:** The bottom navigation bar overlaps the last rows of a list, so pages reserve room for
  it. A rail takes width instead, and the reservation becomes dead space at the exact moment
  vertical room is scarcest â a Z Fold 8 in landscape is only 704 logical pixels tall.

### `int columnCapacity(double contentWidth, {required double minItemWidth, double gap = listTileGap, int maxColumns = listMaxColumns})` <a id="columncapacity"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/adaptive_layout.dart` (approx. line 122)
- **Purpose:** Report how many columns of a given minimum width fit a content box.
- **Inputs:** `contentWidth` â the width available, in logical pixels; `minItemWidth` â the
  narrowest one column may be; `gap` â spacing between columns; `maxColumns` â a ceiling however
  wide the box is.
- **Returns:** `int`, at least 1 and at most `maxColumns`.
- **Side effects:** None.
- **Algorithm:** `((contentWidth + gap) / (minItemWidth + gap)).floor()`, clamped to
  `[1, maxColumns]`. Adding one gap to the numerator is what makes the arithmetic count gaps
  *between* columns rather than after every column. A non-positive `contentWidth` returns 1; a
  non-positive `minItemWidth` returns the ceiling rather than dividing by zero.
- **Usage:**
  ```dart
  final twoColumn = canSplitLayout(screen.width, screen.height) &&
      columnCapacity(contentWidth, minItemWidth: 330, maxColumns: 2) >= 2;
  ```
  (from `_KanaPageState.build`)
- **Notes:** The adaptive-minimum-width approach Google recommends for feeds and grids, rather than
  a hardcoded count per breakpoint. Generalized out of `listColumnCapacity` in 1.5.4 so the kana
  page could bring its own minimums â 330 for a five-column kana table, 320 for a rule card, both
  capped at two â instead of the hardcoded `720` breakpoint it had carried since before this module
  existed.

### `int listColumnCapacity(double contentWidth)` <a id="listcolumncapacity"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/adaptive_layout.dart` (approx. line 140)
- **Purpose:** Report how many columns of at least `listTileMinWidth` fit in the width a list gets.
- **Inputs:** `contentWidth` â the width available to the list, in logical pixels.
- **Returns:** `int`, at least 1 and at most `listMaxColumns` (4).
- **Side effects:** None.
- **Algorithm:** [`columnCapacity`](#columncapacity) at `minItemWidth: listTileMinWidth`.
- **Usage:**
  ```dart
  final contentWidth = shellContentWidth(screen.width) - 32;
  final capacity = canSplitLayout(screen.width, screen.height)
      ? listColumnCapacity(contentWidth)
      : 1;
  ```
  (from `_StatisticsPageState.build`, whose lists sit inside a 16 dp horizontal page padding)
- **Notes:** 320 dp is what a list tile needs before its 40 Ã 56 cover, two lines of text and up to
  two trailing icon buttons squeeze the title to nothing. Pass the width the list actually gets â
  [`shellContentWidth`](#shellcontentwidth) less any page padding â not the screen width, so both
  the rail and the padding are accounted for.

### `int listColumnCount({required double screenWidth, required double screenHeight, required double contentWidth, required int preference})` <a id="listcolumncount"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/adaptive_layout.dart` (approx. line 87)
- **Purpose:** Combine the split gate, the width capacity and the user's stored preference into the
  number of columns a list renders.
- **Inputs:** `screenWidth`, `screenHeight` — the whole screen, which decides whether splitting is
  allowed at all; `contentWidth` — the width the list itself gets; `preference` —
  `listColumnsAuto` (0) or a pinned column count.
- **Returns:** `int`, at least 1.
- **Side effects:** None.
- **Algorithm:**
  1. Return 1 when `canSplitLayout(screenWidth, screenHeight)` is false.
  2. Compute `listColumnCapacity(contentWidth)`.
  3. Return the capacity when `preference == listColumnsAuto`, otherwise the preference clamped to
     `[1, capacity]`.
- **Usage:**
  ```dart
  final columns = listColumnCount(
    screenWidth: screen.width,
    screenHeight: screen.height,
    contentWidth: screen.width,
    preference: settings.manageListColumns,
  );
  ```
  (from `_ManagementPageState.build`)
- **Notes:** The gate reads the screen while the capacity reads the list's own width, deliberately;
  see the note on `canSplitLayout` and the section "Measure the screen for the gate, the content
  for the capacity" in [../../../adaptive-layout.md](../../../adaptive-layout.md). A pinned
  preference is **clamped, not rejected**, so a count set on a desktop survives being carried onto
  a folded phone and comes back on unfolding — the stored value is never rewritten by the layout.

### `int listRowCount(int itemCount, int columns)` <a id="listrowcount"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/adaptive_layout.dart` (approx. line 99)
- **Purpose:** Give a `ListView.builder` its `itemCount` when each item is a row of tiles.
- **Inputs:** `itemCount` — tiles in the flat list; `columns`.
- **Returns:** `int` — 0 for an empty list, otherwise the ceiling of `itemCount / columns`.
- **Side effects:** None.
- **Algorithm:** `(itemCount + perRow - 1) ~/ perRow`, where `perRow` is `columns` floored at 1.
- **Usage:**
  ```dart
  return ListView.builder(
    itemCount: listRowCount(results.length, columns),
    itemBuilder: (context, row) => adaptiveTileRow(
      rowIndex: row,
      columns: columns,
      itemCount: results.length,
      itemBuilder: (i) => _buildAnimeTile(results[i], theme, l10n, columns),
    ),
  );
  ```
  (from `_ManagementPageState._buildSearchResults`)
- **Notes:** The last row may be short; `adaptiveTileRow` pads it so the remaining tiles keep their
  width instead of stretching across the row. Guarding `columns < 1` keeps the arithmetic total
  rather than dividing by zero at a call site that has not clamped yet.

### `double settingsLeftPaneWidth(double contentWidth)` <a id="settingsleftpanewidth"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/adaptive_layout.dart` (approx. line 189)
- **Purpose:** Return the width of the settings page's fixed left pane.
- **Inputs:** `contentWidth` â the width both panes share, which is
  [`shellContentWidth`](#shellcontentwidth) rather than the screen width.
- **Returns:** `double`.
- **Side effects:** None.
- **Algorithm:** `(contentWidth * 0.44).clamp(300, 440)`, then capped at
  `contentWidth - settingsRightPaneMinWidth` (280) and floored at 240 if that cap binds.
- **Usage:**
  ```dart
  SizedBox(
    width: settingsLeftPaneWidth(constraints.maxWidth),
    child: list,
  ),
  ```
  (from `_SettingsPageState.build`, inside a `LayoutBuilder` so the width is measured after the
  navigation rail)
- **Notes:** Wider than the detail page's `detailLeftPaneWidth`, because this pane carries full
  `ListTile`s with trailing dropdowns rather than a cover and a column of text. The cap only binds
  on a hand-resized desktop window and on the narrowest unfolded foldables â a Z Fold 5 leaves 578
  after the rail, where the pane gives up width rather than let the detail pane become unusable.
  Those rows are cramped there, with the title wrapping beside its dropdown; that was accepted in
  exchange for the settings gate staying the one shared `canSplitLayout` rather than growing a
  threshold of its own.

### `bool useStatsSideBySide(double contentWidth)` <a id="usestatssidebyside"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/adaptive_layout.dart` (approx. line 219)
- **Purpose:** Report whether the statistics summary fits beside the trend chart.
- **Inputs:** `contentWidth` — the width the statistics body gets, which is
  [`shellContentWidth`](#shellcontentwidth) less the page's own 32 of padding.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** `contentWidth >= statsSummaryPaneMinWidth + statsChartMinWidth + listTileGap`
  — 260 + 380 + 12 = 652.
- **Usage:**
  ```dart
  final summaryBesideChart =
      canSplitLayout(screen.width, screen.height) &&
      useStatsSideBySide(contentWidth) &&
      _trendData.isNotEmpty;
  ```
  (from `_StatisticsPageState.build`)
- **Notes:** A width floor **on top of** `canSplitLayout`, never instead of it — callers must test
  both, the same double gate the kana tables use. The split rule alone admits a Z Fold 5, a Z Fold
  6 and a Z Fold 7 in portrait, all of which would leave the chart between 215 and 245 logical
  pixels. Those three keep the stacked layout without needing a breakpoint of their own.

### `double statsSummaryPaneWidth(double contentWidth)` <a id="statssummarypanewidth"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/adaptive_layout.dart` (approx. line 231)
- **Purpose:** Return the width of the statistics summary's 2x2 card pane.
- **Inputs:** `contentWidth` — the width both blocks share.
- **Returns:** `double`.
- **Side effects:** None.
- **Algorithm:** `(contentWidth * 0.34).clamp(statsSummaryPaneMinWidth, 360)`.
- **Usage:**
  ```dart
  SizedBox(
    width: statsSummaryPaneWidth(contentWidth),
    child: _buildSummaryCards(theme, l10n, grouped, 2),
  ),
  ```
  (from `_StatisticsPageState.build`)
- **Notes:** No right-hand cap, unlike [`settingsLeftPaneWidth`](#settingsleftpanewidth), because
  none can bind: above [`useStatsSideBySide`](#usestatssidebyside) the pane grows at 0.34 of the
  width while the chart grows at 0.66, so `statsChartMinWidth` is met exactly at the gate and only
  more comfortably above it. `test/adaptive_layout_test.dart` asserts that across the whole range
  rather than defending it with a second clamp.

### `bool useRankingSortRow(double contentWidth)` <a id="userankingsortrow"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/adaptive_layout.dart` (approx. line 243)
- **Purpose:** Report whether the ranking sort controls fit on a single row.
- **Inputs:** `contentWidth` — the width the ranking filter panel gets, which is its
  `LayoutBuilder`'s `constraints.maxWidth`.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:**
  `rankingScoreSourceWidth + rankingFilterMinWidth + rankingDirectionWidth + 2 * listTileGap`
  — 200 + 280 + 170 + 24 = 674.
- **Usage:**
  ```dart
  final oneSortRow = useRankingSortRow(constraints.maxWidth);
  ```
  (from `_StatisticsPageState._buildRankingFilters`)
- **Notes:** A separate and larger threshold than the filter dropdowns' own pairing, which is a
  plain `columnCapacity` call at `rankingFilterMinWidth` (572). This row carries a sort-field
  dropdown and two segmented buttons rather than two equal halves, so the same number would not
  describe it. It is a sum and therefore independent of the order the three are placed in: 1.5.6
  moved the dropdown to the front of the row without moving the threshold. Below it the score
  source keeps the line it has always had. **Width only, deliberately** —
  packing controls onto a line asks whether they fit, not whether the window has the shape for two
  panes, and reading it as a split would exclude a phone in landscape, where the panel costs 244 of
  412 logical pixels.
