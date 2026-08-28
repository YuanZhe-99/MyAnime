/// Minimum viewport width, in logical pixels, before a layout may split.
///
/// Material's *medium* width class and Android's `sw600dp` tablet threshold.
const splitMinWidth = 600.0;

/// Minimum viewport height, in logical pixels, before a layout may split.
///
/// Matches the boundary between Android's compact and medium height classes.
/// Google's own guidance is that a window whose height is compact — a phone or
/// an open flippable held in landscape — cannot practically carry two panes.
const splitMinHeight = 480.0;

/// Minimum viewport width-to-height ratio before a layout may split.
const splitMinAspect = 0.82;

/// Minimum width, in logical pixels, one list column may occupy.
///
/// The list tiles carry a 40x56 cover, two lines of text and up to two trailing
/// icon buttons, so a column narrower than this truncates the title to nothing.
const listTileMinWidth = 320.0;

/// Horizontal gap, in logical pixels, between columns of a multi-column list.
const listTileGap = 12.0;

/// Largest number of columns a list will use, however wide the window is.
const listMaxColumns = 4;

/// Column preference meaning "use whatever the width can fit".
const listColumnsAuto = 0;

/// Purpose: Report whether a layout may split into panes or columns.
/// Inputs: `width`, `height` — the viewport size in logical pixels.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Three independent conditions, because none of them alone is enough.
/// The aspect test is the load-bearing one: it keeps a viewport that is
/// meaningfully taller than it is wide on the original single-column layout, so
/// a Galaxy Z Fold 8 splits in landscape (4:3) but not in portrait (3:4), while
/// the near-square Fold 7 and Fold 8 Ultra split in both orientations. The width
/// floor is the usual `sw600dp` tablet threshold. The height floor exists
/// because the aspect test alone admits wide, short viewports — a folded cover
/// screen or an ordinary phone held in landscape would otherwise split into two
/// cramped panes. See `doc/en-us/adaptive-layout.md` for the full derivation.
bool canSplitLayout(double width, double height) {
  if (width < splitMinWidth) return false;
  if (height < splitMinHeight) return false;
  if (height <= 0) return false;
  return width / height >= splitMinAspect;
}

/// Purpose: Return how many list columns a given content width can carry.
/// Inputs: `contentWidth` — the width available to the list, in logical pixels.
/// Returns: `int`, at least 1 and at most [listMaxColumns].
/// Side effects: None.
/// Notes: Counts how many [listTileMinWidth] columns fit once the
/// [listTileGap] between them is paid for, which is the adaptive-minimum-width
/// approach Google recommends for feeds rather than a hardcoded count per
/// breakpoint. Pass the width the list actually gets, not the screen width, so
/// page padding is already accounted for.
int listColumnCapacity(double contentWidth) {
  if (contentWidth <= 0) return 1;
  final fit = ((contentWidth + listTileGap) / (listTileMinWidth + listTileGap))
      .floor();
  return fit.clamp(1, listMaxColumns);
}

/// Purpose: Return the number of columns a list should actually render.
/// Inputs: `screenWidth`, `screenHeight` — the whole screen, which decides
/// whether splitting is allowed at all; `contentWidth` — the width the list
/// itself gets; `preference` — [listColumnsAuto] or a pinned column count.
/// Returns: `int`, at least 1.
/// Side effects: None.
/// Notes: The gate reads the screen while the capacity reads the list's own
/// width, deliberately. Measuring the split decision against the body would
/// subtract the app bar and read a Fold 8 in portrait as 0.80 rather than
/// 0.755, leaving almost no margin under [splitMinAspect]. A pinned preference
/// is clamped to what fits, so a window that shrinks — or a foldable that
/// closes — falls back to a single column without losing the stored choice.
int listColumnCount({
  required double screenWidth,
  required double screenHeight,
  required double contentWidth,
  required int preference,
}) {
  if (!canSplitLayout(screenWidth, screenHeight)) return 1;
  final capacity = listColumnCapacity(contentWidth);
  if (preference == listColumnsAuto) return capacity;
  return preference.clamp(1, capacity);
}

/// Purpose: Return how many rows a list of items needs at a column count.
/// Inputs: `itemCount`, `columns`.
/// Returns: `int`.
/// Side effects: None.
/// Notes: The last row may be short; callers pad it so the remaining tiles keep
/// their width instead of stretching across the row.
int listRowCount(int itemCount, int columns) {
  if (itemCount <= 0) return 0;
  final perRow = columns < 1 ? 1 : columns;
  return (itemCount + perRow - 1) ~/ perRow;
}
