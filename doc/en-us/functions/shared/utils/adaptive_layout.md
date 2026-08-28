# lib/shared/utils/adaptive_layout.dart

The app-wide adaptive-layout policy: the `splitMinWidth`, `splitMinHeight` and `splitMinAspect`
thresholds that decide whether a layout may split at all, and the `listTileMinWidth`,
`listTileGap`, `listMaxColumns` and `listColumnsAuto` constants that decide how many columns a list
gets once it may. Four pure helpers sit on top of them.

The module deliberately depends on nothing but `dart:core` — it holds no Flutter imports, and
`canSplitLayout` takes two doubles rather than a `Size` for exactly that reason — so every helper
is directly unit-testable (`test/adaptive_layout_test.dart`), and the rendered result is covered
separately at real device geometries by `test/list_columns_ui_test.dart` and
`test/detail_layout_ui_test.dart`.

The prose derivation of these numbers, the foldable device tables and the reconciliation with
Google's guidance live in [../../../adaptive-layout.md](../../../adaptive-layout.md). This page
documents the declarations.

Consumers: `detail_layout.dart` (see [detail_layout.md](detail_layout.md)), whose
`useDetailTwoPane` is a one-line delegate to `canSplitLayout`; `home_page.dart`,
`management_page.dart` and `statistics_page.dart` for their list column counts; and
`anime_storage.dart` and `app_settings.dart` for `listColumnsAuto` and `listMaxColumns` when
validating the stored preference.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`canSplitLayout`](#cansplitlayout) | top-level function | A | Report whether a layout may split into panes or columns. |
| [`listColumnCapacity`](#listcolumncapacity) | top-level function | A | Return how many list columns a given content width can carry. |
| [`listColumnCount`](#listcolumncount) | top-level function | A | Return the number of columns a list should actually render. |
| [`listRowCount`](#listrowcount) | top-level function | A | Return how many rows a list of items needs at a column count. |

The seven constants are plain declarations without `/// Purpose:` comments and are not indexed as
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

### `int listColumnCapacity(double contentWidth)` <a id="listcolumncapacity"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/adaptive_layout.dart` (approx. line 68)
- **Purpose:** Report how many columns of at least `listTileMinWidth` fit in the width a list gets.
- **Inputs:** `contentWidth` — the width available to the list, in logical pixels.
- **Returns:** `int`, at least 1 and at most `listMaxColumns` (4).
- **Side effects:** None.
- **Algorithm:** `((contentWidth + listTileGap) / (listTileMinWidth + listTileGap)).floor()`,
  clamped to `[1, listMaxColumns]`. Adding one gap to the numerator is what makes the arithmetic
  count gaps *between* columns rather than after every column. A non-positive width returns 1.
- **Usage:**
  ```dart
  final contentWidth = screen.width - 32;
  final capacity = canSplitLayout(screen.width, screen.height)
      ? listColumnCapacity(contentWidth)
      : 1;
  ```
  (from `_StatisticsPageState.build`, whose lists sit inside a 16 dp horizontal page padding)
- **Notes:** This is the adaptive-minimum-width approach Google recommends for feed layouts, rather
  than a hardcoded column count per breakpoint. 320 dp is what a list tile needs before its
  40 × 56 cover, two lines of text and up to two trailing icon buttons squeeze the title to
  nothing. Pass the width the list actually gets, not the screen width, so page padding is already
  accounted for.

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
