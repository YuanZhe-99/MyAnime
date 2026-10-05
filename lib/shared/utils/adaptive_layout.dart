import 'package:flutter/widgets.dart';
import 'package:myapps_adaptive/myapps_adaptive.dart';

export 'package:myapps_adaptive/myapps_adaptive.dart';

/// Minimum width for a cover, title and trailing actions in an anime tile.
const listTileMinWidth = 320.0;

/// Minimum usable settings detail pane width.
const settingsRightPaneMinWidth = 280.0;

/// Minimum width for the statistics summary's two-column card grid.
const statsSummaryPaneMinWidth = 260.0;

/// Minimum width for the chart axis and approximately seven periods.
const statsChartMinWidth = 380.0;

/// Minimum width for localized ranking dropdown labels.
const rankingFilterMinWidth = 280.0;

/// Width reserved for ranking score-source controls.
const rankingScoreSourceWidth = 200.0;

/// Width reserved for ranking sort-direction controls.
const rankingDirectionWidth = 170.0;

/// Minimum proposal width for checkbox, field label and compared values.
const metaUpdateCardMinWidth = 360.0;

/// Minimum episode tile width for playback, editing and page address.
const episodeTileMinWidth = 360.0;

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
/// Notes: The page's floating action button overlaps the last rows of a list,
/// so pages reserve room for it. A navigation rail takes width instead, and the
/// reservation becomes dead space at the very moment vertical room is scarcest
/// — a Fold 8 in landscape is only 704 logical pixels tall. Since 1.7.2 the
/// Expressive bottom bar floats over the page; its height is added on top of
/// this value by [navBarAwarePadding], which every caller wraps around it.
double shellListBottomInset(double screenWidth) =>
    useNavigationRail(screenWidth) ? 16.0 : 80.0;

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
/// because this row carries a sort-field dropdown followed by two segmented
/// buttons rather than two equal halves. It is a sum, so it is independent of
/// the order the three sit in and did not move in 1.5.6 when the dropdown took
/// the lead. Below it the score source keeps its own line, which is the layout
/// every viewport had before 1.5.5.
bool useRankingSortRow(double contentWidth) =>
    contentWidth >=
    rankingScoreSourceWidth +
        rankingFilterMinWidth +
        rankingDirectionWidth +
        2 * listTileGap;

/// Purpose: Add the floating navigation bar's height to a page's padding.
/// Inputs: `context` — inside a shell page; `padding` — the page's own padding.
/// Returns: `EdgeInsets` — [padding] with the bottom inset reported by the
/// enclosing Scaffold added to its bottom.
/// Side effects: None.
/// Notes: With the Expressive bottom bar the shell uses `extendBody`, so pages
/// draw behind the bar and the Scaffold reports the bar's height as
/// `MediaQuery.padding.bottom`. Scroll views with an explicit padding do not
/// apply that inset themselves; passing their padding through here leaves room
/// to scroll the last content above the bar. This covers every page that lives
/// in the shell's navigator: the five tabs, anything pushed with a plain
/// `Navigator.push` from them, and the nested `Navigator` of Settings' two-pane
/// detail. `ScrollView`s that never add the inset themselves
/// (`SingleChildScrollView`, `CustomScrollView`) pass `EdgeInsets.zero`
/// through here too. Routes declared outside the `ShellRoute` and pushes with
/// `rootNavigator: true` sit above the bar, and with the classic bar or a rail
/// the inset is just the system's, so the call is harmless there. Modal bottom
/// sheets opened from shell pages must set `useRootNavigator: true` instead.
EdgeInsets navBarAwarePadding(BuildContext context, EdgeInsets padding) =>
    padding.copyWith(
      bottom: padding.bottom + MediaQuery.paddingOf(context).bottom,
    );
