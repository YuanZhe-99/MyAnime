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

/// Minimum viewport width, in logical pixels, before the shell shows its
/// navigation rail instead of a bottom navigation bar.
///
/// Material's *medium* width class, which is where Google's guidance moves
/// navigation to the side. This is a width-only threshold on purpose; see
/// [useNavigationRail].
const navRailMinWidth = 600.0;

/// Logical pixels the navigation rail takes from the content when it is shown.
///
/// An 80 dp `NavigationRail` plus the 1 dp `VerticalDivider` beside it.
const navRailWidth = 81.0;

/// Smallest width, in logical pixels, the settings detail pane may be given.
const settingsRightPaneMinWidth = 280.0;

/// Smallest width, in logical pixels, the statistics summary cards may occupy
/// when they sit beside the trend chart rather than above it.
///
/// The four cards become a 2x2 grid there, so this leaves each card about 124
/// logical pixels — enough for a two-digit count above a wrapped label.
const statsSummaryPaneMinWidth = 260.0;

/// Smallest width, in logical pixels, the trend chart may be given before the
/// statistics summary stops sitting beside it.
///
/// The chart reserves 32 for its sticky y-axis and draws one bar group every 50
/// logical pixels, so this shows roughly seven periods before scrolling.
const statsChartMinWidth = 380.0;

/// Minimum width, in logical pixels, one ranking filter dropdown may occupy.
///
/// Each is an `OutlineInputBorder` dropdown whose longest localized label is
/// Japanese; below this the label truncates before the arrow.
const rankingFilterMinWidth = 280.0;

/// Width, in logical pixels, the ranking score-source segmented button needs.
const rankingScoreSourceWidth = 200.0;

/// Width, in logical pixels, the ranking sort-direction segmented button needs.
const rankingDirectionWidth = 170.0;

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

/// Purpose: Report whether the shell should show a navigation rail.
/// Inputs: `screenWidth` — the whole screen width in logical pixels.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: **Width only, deliberately** — this is not [canSplitLayout] and must
/// not be routed through it. A rail is not a split; it trades width, which is
/// abundant whenever this returns true, for height, which is not. The case it
/// helps most is the one the split rule rejects on purpose: an ordinary phone
/// held in landscape at 915 x 412, where a bottom bar spends 19% of the height
/// on navigation while 915 logical pixels of width sit unused.
bool useNavigationRail(double screenWidth) => screenWidth >= navRailMinWidth;

/// Purpose: Return the width a shell page's content actually receives.
/// Inputs: `screenWidth` — the whole screen width in logical pixels.
/// Returns: `double`, never negative.
/// Side effects: None.
/// Notes: Subtracts the navigation rail when the shell is showing one. Pass the
/// result wherever a capacity is being computed; keep passing the untouched
/// screen size to [canSplitLayout], which asks about the window's shape rather
/// than about the room left over inside it.
double shellContentWidth(double screenWidth) {
  final width = useNavigationRail(screenWidth)
      ? screenWidth - navRailWidth
      : screenWidth;
  return width < 0 ? 0 : width;
}

/// Purpose: Return the bottom padding a shell page's scrolling list needs.
/// Inputs: `screenWidth` — the whole screen width in logical pixels.
/// Returns: `double`.
/// Side effects: None.
/// Notes: The shell's bottom navigation bar overlaps the last rows of a list,
/// so pages reserve room for it. A navigation rail takes width instead, and the
/// reservation becomes dead space at the very moment vertical room is scarcest
/// — a Fold 8 in landscape is only 704 logical pixels tall.
double shellListBottomInset(double screenWidth) =>
    useNavigationRail(screenWidth) ? 16.0 : 80.0;

/// Purpose: Return how many columns of a given minimum width fit a content box.
/// Inputs: `contentWidth` — the width available, in logical pixels;
/// `minItemWidth` — the narrowest one column may be; `gap` — spacing between
/// columns; `maxColumns` — a ceiling however wide the box is.
/// Returns: `int`, at least 1 and at most `maxColumns`.
/// Side effects: None.
/// Notes: The adaptive-minimum-width approach Google recommends for feeds and
/// grids, rather than a hardcoded count per breakpoint. One gap is added to the
/// numerator so the arithmetic pays for the gaps *between* columns rather than
/// one after every column. Non-positive widths return 1.
int columnCapacity(
  double contentWidth, {
  required double minItemWidth,
  double gap = listTileGap,
  int maxColumns = listMaxColumns,
}) {
  final ceiling = maxColumns < 1 ? 1 : maxColumns;
  if (contentWidth <= 0) return 1;
  if (minItemWidth <= 0) return ceiling;
  final fit = ((contentWidth + gap) / (minItemWidth + gap)).floor();
  return fit.clamp(1, ceiling);
}

/// Purpose: Return how many list columns a given content width can carry.
/// Inputs: `contentWidth` — the width available to the list, in logical pixels.
/// Returns: `int`, at least 1 and at most [listMaxColumns].
/// Side effects: None.
/// Notes: [columnCapacity] at the anime-list tile's own minimum. Pass the width
/// the list actually gets — [shellContentWidth] less any page padding — not the
/// screen width, so the navigation rail and the padding are both accounted for.
int listColumnCapacity(double contentWidth) =>
    columnCapacity(contentWidth, minItemWidth: listTileMinWidth);

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

/// Purpose: Return the width of the settings page's fixed left pane.
/// Inputs: `contentWidth` — the width both panes share, in logical pixels,
/// which is [shellContentWidth] rather than the screen width.
/// Returns: `double`.
/// Side effects: None.
/// Notes: Proportional, then clamped, then capped so the detail pane can never
/// be squeezed below [settingsRightPaneMinWidth]. The left pane needs more room
/// than the anime detail page's does, because it carries full `ListTile`s with
/// trailing dropdowns rather than a cover and a column of text. The cap only
/// binds on a hand-resized desktop window and on the narrowest foldables, where
/// it gives up left-pane width rather than let the right pane become unusable.
double settingsLeftPaneWidth(double contentWidth) {
  final preferred = (contentWidth * 0.44).clamp(300.0, 440.0);
  final capped = contentWidth - settingsRightPaneMinWidth;
  if (preferred <= capped) return preferred;
  return capped.clamp(240.0, 440.0);
}

/// Purpose: Report whether the statistics summary fits beside the trend chart.
/// Inputs: `contentWidth` — the width the statistics body gets, in logical
/// pixels, which is [shellContentWidth] less the page's own padding.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: A width floor **on top of** [canSplitLayout], not instead of it — the
/// same double gate the kana tables use. The split rule alone admits viewports
/// the size of a Z Fold 5, where the chart would be left about 215 logical
/// pixels and show four bar groups. Callers must test both.
bool useStatsSideBySide(double contentWidth) =>
    contentWidth >= statsSummaryPaneMinWidth + statsChartMinWidth + listTileGap;

/// Purpose: Return the width of the statistics summary's 2x2 card pane.
/// Inputs: `contentWidth` — the width both blocks share, in logical pixels.
/// Returns: `double`.
/// Side effects: None.
/// Notes: No right-hand cap, unlike [settingsLeftPaneWidth], because none can
/// bind: under [useStatsSideBySide] the pane grows at 0.34 of the width while
/// the chart grows at 0.66, so [statsChartMinWidth] is met exactly at the gate
/// and only more comfortably above it.
double statsSummaryPaneWidth(double contentWidth) =>
    (contentWidth * 0.34).clamp(statsSummaryPaneMinWidth, 360.0);

/// Purpose: Report whether the ranking sort controls fit on a single row.
/// Inputs: `contentWidth` — the width the filter panel gets, in logical pixels.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: A separate, larger threshold than the filter dropdowns' own pairing,
/// because this row carries a segmented button on each side of the dropdown
/// rather than two equal halves. Below it the score source keeps its own line,
/// which is the layout every viewport had before 1.5.5.
bool useRankingSortRow(double contentWidth) =>
    contentWidth >=
    rankingScoreSourceWidth +
        rankingFilterMinWidth +
        rankingDirectionWidth +
        2 * listTileGap;
