# Adaptive layout

This is the app-wide rule for **when a layout may split** — into two panes on the anime detail page
and the settings page, or into multiple columns in the three data-browsing modules and on the kana
page — and, once it may, **how many columns** it gets. A second, narrower rule decides **where
navigation lives**. Both live in
[`lib/shared/utils/adaptive_layout.dart`](functions/shared/utils/adaptive_layout.md), a module that
deliberately imports nothing but `dart:core` so every decision is directly unit-testable without a
widget tree.

Before this file existed the rule lived only inside the detail page's own helper and read as a
detail-page rule. It is not: the same three thresholds now gate the multi-column lists, the kana
page and the settings panes as well, so one device answers the same way everywhere in the app.

## When to split

Split when **all three** of these hold:

| Constant | Value | What it is |
|---|---|---|
| `splitMinWidth` | `600.0` | Material's *medium* width class; Android's `sw600dp`. |
| `splitMinHeight` | `480.0` | The compact/medium height boundary. |
| `splitMinAspect` | `0.82` | Width divided by height. |

```dart
bool canSplitLayout(double width, double height) {
  if (width < splitMinWidth) return false;
  if (height < splitMinHeight) return false;
  if (height <= 0) return false;
  return width / height >= splitMinAspect;
}
```

Each condition earns its place, and none of them alone is enough.

### The aspect test is the load-bearing one

**It is why this is not a plain width breakpoint, and the Galaxy Z Fold 8 is why it has to exist.**
The Fold 8 unfolds to a 4:3 *landscape* panel (2448 × 1848 px), so held in portrait it is 3:4 —
**narrower relative to its height than the near-square Fold 7 it replaced**, despite being newer,
while the Fold 8 Ultra went the other way. One generation now spans roughly 672 to 954 logical
pixels unfolded, and one device needs two different answers at one width.

Pixel counts are authoritative; logical pixels depend on the density bucket and on Samsung's
user-adjustable **Display size** setting, so a plausible range is shown.

| Device | Inner panel, px | Portrait W:H | Portrait W, dp | Portrait | Landscape |
|---|---|---|---|---|---|
| Galaxy Z Fold 5 | 1812 × 2176 | 0.83 | 659–690 | split | split |
| Galaxy Z Fold 6 | 1856 × 2160 | 0.86 | 675–707 | split | split |
| Galaxy Z Fold 7 | 1968 × 2184 | 0.90 | 716–750 | split | split |
| **Galaxy Z Fold 8** | **2448 × 1848 (4:3 landscape)** | **0.755** | **672–704** | **single** | **split** |
| Galaxy Z Fold 8 Ultra | 2256 × 2504 | 0.90 | 820–859 | split | split |
| Pixel 9 / 10 Pro Fold | 2076 × 2152 | 0.96 | 755–791 | split | split |

`0.82` sits near the middle of the gap between the Fold 8's portrait `0.755` and the Fold 7 /
Fold 8 Ultra's portrait `0.90`, with roughly 9% margin on each side. A `720` threshold would have
failed the Fold 8, the Fold 5 and the Fold 6 outright; `840` would have left only the Ultra.

### The width floor

Every unfolded panel clears 600 dp by at least 59 dp even at the denser end of the range, and every
folded cover screen sits well below it: Z Fold 7 / 8 Ultra roughly 360 dp, Z Fold 8 roughly
356–416 dp, Pixel 10 Pro Fold roughly 411 dp.

### The height floor

The aspect test alone admits *wide and short* viewports. Without the floor, a folded Z Fold 8 cover
screen rotated to landscape (~657 × 416 dp) and an ordinary phone in landscape (~915 × 412 dp)
would both split into two cramped panes. Google gives the same advice independently: for a phone or
an open flippable in landscape the window width is typically medium but the height is compact, and
two-pane layouts are not practical there.

### The consequence worth knowing

The rule is about **shape, not device class**, so a 4:3 tablet in portrait (768 × 1024 → 0.75) and a
16:10 tablet in portrait (0.625) also stay single column, exactly like the Fold 8 in portrait. Both
split in landscape.

## How many columns

Once splitting is allowed, the count comes from the width the content actually gets and a minimum
width per column:

```dart
int columnCapacity(
  double contentWidth, {
  required double minItemWidth,
  double gap = listTileGap,
  int maxColumns = listMaxColumns,
}) => ((contentWidth + gap) / (minItemWidth + gap))
        .floor()
        .clamp(1, maxColumns);
```

This is the adaptive-minimum-width approach Google recommends for feed layouts — fit as many
columns of at least a minimum width as the space allows — rather than a hardcoded count per
breakpoint. Each caller brings the minimum its own content needs:

| Caller | Minimum | Max | Why that number |
|---|---|---|---|
| Anime lists (`listColumnCapacity`) | `320` | 4 | What a tile needs before its 40 × 56 cover, two lines of text and up to two trailing icon buttons squeeze the title to nothing. |
| Kana tables | `330` | 2 | A five-column table spends 44 on its row label, so 330 leaves ≈ 57 per cell — level with what the same table gets on a phone in one column. |
| Kana rule cards | `320` | 2 | Paragraph cards; a third column would fall below a comfortable reading measure. |
| Ranking filter dropdowns | `280` | 2 | An `OutlineInputBorder` dropdown whose longest localized label is Japanese; narrower and the label truncates before the arrow. Also governs the custom-range buttons below them. |

`listColumnCount` combines the gate with the capacity: one column when `canSplitLayout` is false,
otherwise the capacity when the user's preference is `listColumnsAuto`, otherwise the preference
clamped to the capacity. Clamping rather than rejecting is what lets a preference set on a desktop
survive being carried onto a folded phone and come back on unfolding.

Content width is `shellContentWidth(screenWidth)` less whatever padding the page adds — see
[the section below](#measure-the-screen-for-the-gate-the-content-for-the-capacity).

| Viewport | Splits | List content | Anime list columns | Kana table columns |
|---|---|---|---|---|
| Z Fold 8 landscape 933 × 704 | yes | 852 | 2 | 2 |
| Z Fold 8 portrait 704 × 933 | no | — | 1 | 1 |
| Z Fold 8 Ultra 954 × 859 / 859 × 954 | yes | 873 / 778 | 2 / 2 | 2 / 2 |
| Pixel 10 Pro Fold 791 × 820 | yes | 710 | 2 | 2 |
| Z Fold 7 832 × 750 / 750 × 832 | yes | 751 / 669 | 2 / 2 | 2 / 1 |
| Z Fold 6 675 × 786 · Z Fold 5 659 × 791 | yes | 594 / 578 | 1 / 1 | 1 / 1 |
| Tablet 1024 × 768 | yes | 943 | 2 | 2 |
| Tablet 768 × 1024 | no | — | 1 | 1 |
| Phone landscape 915 × 412 | no | — | 1 | 1 |
| Desktop 1600 × 900 | yes | 1519 | 4 | 2 |

**A tablet in landscape now gets two anime-list columns where 1.5.3 gave three.** The navigation
rail takes 81 of its 1024, and a third column of the remaining 943 would be 306 wide — under the
320 minimum. The count changed because the room did; the rule did not.

Tiles are laid out **left to right, then top to bottom**. See
[`functions/shared/widgets/adaptive_tile_grid.md`](functions/shared/widgets/adaptive_tile_grid.md)
for why that is a builder over rows rather than a `GridView`.

## Two blocks side by side: a width floor on top of the split rule

Some layouts need both questions answered. The statistics summary is the clearest case: four
status counts above a 200 dp trend chart cost roughly 340 of a Z Fold 8's ~640 dp body before a
single anime row appears. Putting the counts in a 2 × 2 grid beside the chart reclaims about 150 —
but only where the chart still has room to plot in.

```dart
canSplitLayout(screenWidth, screenHeight)   // does the window have the shape?
  && useStatsSideBySide(contentWidth)       // is there room for both blocks?
  && _trendData.isNotEmpty                  // is there a chart at all?
```

`useStatsSideBySide` is `contentWidth >= 260 + 380 + 12`. The two minimums are the summary pane
(four cards in a 2 × 2 grid, ≈ 124 each) and the chart (a 32 dp sticky y-axis plus roughly seven
bar groups at 50 dp). The split rule alone is not enough: a Z Fold 5, a Z Fold 6 and a Z Fold 7 in
portrait all pass it and would leave the chart between 215 and 245 dp. They keep the stacked
layout, and need no breakpoint of their own to do so — the same double gate the kana tables use.

`statsSummaryPaneWidth` is `(contentWidth * 0.34).clamp(260, 360)` with **no right-hand cap**,
unlike `settingsLeftPaneWidth`. None can bind: above the gate the pane grows at 0.34 of the width
while the chart grows at 0.66, so the chart's floor is met exactly at the boundary and only more
comfortably above it. That invariant is asserted across the whole range in
`test/adaptive_layout_test.dart` rather than defended by a second clamp.

The third condition is not defensive padding. An empty chart renders `SizedBox.shrink()`, so
without it the cards would sit in a 260 dp pane beside a blank half rather than falling back to
their full-width row.

| Viewport | Splits | Content | Numbers beside chart | Pane | Chart |
|---|---|---|---|---|---|
| Z Fold 8 landscape 933 × 704 | yes | 820 | **yes** | 279 | 529 |
| Z Fold 8 portrait 704 × 933 | no | — | no | — | — |
| Z Fold 8 Ultra 954 / 859 | yes | 841 / 746 | **yes** / **yes** | 286 / 260 | 543 / 474 |
| Pixel 10 Pro Fold 791 × 820 | yes | 678 | **yes** | 260 | 406 |
| Z Fold 7 832 / 750 | yes | 719 / 637 | **yes** / no | 260 / — | 447 / — |
| Z Fold 6 675 · Z Fold 5 659 | yes | 562 / 546 | no / no | — | — |
| Tablet 1024 / 768 | yes / no | 911 / — | **yes** / no | 310 / — | 589 / — |
| Phone landscape 915 × 412 | no | — | no | — | — |
| Desktop 1600 × 900 | yes | 1487 | **yes** | 360 | 1115 |

**The cost of gating this on `canSplitLayout`:** a phone in landscape at 915 × 412 keeps the
stacked layout, although it is the viewport with the least height of any. A width-only rule — the
one `useNavigationRail` uses, and the one the ranking filter panel below uses — would have helped
it. The app-wide split rule was chosen instead, deliberately, for consistency with the detail,
settings and kana pages.

## Where navigation lives

A **second rule, and deliberately a narrower one**:

```dart
bool useNavigationRail(double screenWidth) => screenWidth >= navRailMinWidth; // 600.0
```

Above it the shell renders a `NavigationRail` down the side; below it, the bottom `NavigationBar`
it always had. Both are built from one list of destinations in
[`shell_scaffold.dart`](functions/shared/widgets/shell_scaffold.md), so they cannot drift apart. The rail
centres its destinations (`groupAlignment: 0`) rather than taking the default top alignment: a rail
top-aligns to sit under a leading menu button or FAB, and this one has neither, so five
destinations pinned to the top of a 704 dp rail would leave its whole lower half empty.

**This is width-only on purpose, and must not be routed through `canSplitLayout`.** A rail is not a
split. It trades width — abundant whenever the test passes — for height, which is not. The case it
helps most is precisely the one the split rule rejects: an ordinary phone in landscape at
915 × 412, where a bottom bar spends 19% of the height on navigation while 915 logical pixels of
width sit unused. On a Z Fold 8 in landscape the window is only 704 tall, and the same trade
applies.

Two consequences follow through the rest of the app:

- `shellContentWidth(screenWidth)` subtracts `navRailWidth` (81 = an 80 dp rail plus its 1 dp
  divider) whenever the rail is showing. Every capacity is measured from that, never from the raw
  screen width.
- `shellListBottomInset(screenWidth)` drops the 80 dp that scrolling pages reserved for the bottom
  bar down to 16 when there is no bottom bar — otherwise the reservation becomes dead space at the
  exact moment vertical room is scarcest.

Not done, deliberately: a `NavigationDrawer` above 1240 dp. The rail is correct through
extra-large here, and a third navigation mode is not worth its cost.

## Measure the screen for the gate, the content for the capacity

`canSplitLayout` and `useNavigationRail` read `MediaQuery.sizeOf(context)` — the whole screen.
Capacities and pane widths read what the content actually gets. The asymmetry is deliberate, for
two separate reasons:

- Measuring the split decision against the `Scaffold` body would subtract the app bar from the
  height and inflate the ratio, reading a Z Fold 8 in portrait as `0.80` instead of `0.755` and
  leaving almost no margin under the threshold.
- The gate asks about the window's *shape*, which the rail does not change. The capacity asks how
  much room is left, which the rail very much does.

## Folding and unfolding

`android/app/src/main/AndroidManifest.xml` declares
`screenLayout|screenSize|smallestScreenSize|density` among the activity's `configChanges`, so
folding or unfolding resizes the window **without restarting the activity**. Everything that reads
`MediaQuery.sizeOf` therefore re-evaluates on the next frame, which is all "switch automatically
when the device unfolds" needs — no lifecycle work, and no state to save and restore.

## Where these rules are used

| Call site | Split rule | Notes |
|---|---|---|
| `anime_detail_page.dart` | Yes | Through `useDetailTwoPane`, a one-line delegate to `canSplitLayout`. |
| `home_page.dart`, `management_page.dart`, `statistics_page.dart` | Yes | Through `listColumnCount`. |
| `settings_page.dart` | Yes | Two panes: the first-level list on the left, the second-level page it leads to on the right. |
| `kana_page.dart` | Yes | Gated by `canSplitLayout`, then by whether two 330 dp tables fit. |
| `anime_edit_page.dart` | Yes | Through `useDetailTwoPane`, like the detail page. The cover and the two title fields are fixed on the left; everything below them scrolls on the right. |
| `statistics_page.dart` (summary) | Yes | Gated by `canSplitLayout`, then by `useStatsSideBySide`; see above. |
| `statistics_page.dart` (ranking filters) | No — width only | Pairing controls onto a row is a packing question, not a two-pane one. |
| `shell_scaffold.dart` | No — `useNavigationRail` | Width only; see above. |

**The `kana_page.dart` exception recorded here in 1.5.3 is resolved.** It used to carry its own
inline `constraints.maxWidth >= 720` for the rule cards' two-column `Wrap`, and was left alone
because changing it would have altered tablet-portrait behaviour nobody had asked about. Routing it
through `columnCapacity` in 1.5.4 turns out to *preserve* that behaviour rather than change it: the
rail leaves a tablet in portrait 655 dp of rule width, which the `720` literal would have failed
and the shared arithmetic passes.

**Correction, made in 1.5.5.** This section claimed after 1.5.4 that no second layout rule remained
anywhere in `lib/`. That was wrong: `statistics_page.dart` still carried an inline
`constraints.maxWidth < 560` deciding whether the ranking view's two custom-range buttons shared a
row. It was overlooked because the search that produced the claim covered the pages 1.5.4 touched
rather than the whole tree. It now asks the same question the filter dropdowns above it ask, in the
same way — `columnCapacity` at `rankingFilterMinWidth` — which moves the threshold from 560 to 572
and changes nothing else. With that folded in, the claim holds: **every width decision in `lib/`
now goes through `adaptive_layout.dart`.**

### Where the ranking filter panel diverges

The ranking panel's two pairings are **width-only**, and deliberately not `canSplitLayout`:

- the time and type dropdowns share a row from 572 dp of panel width up (`columnCapacity` at 280);
- the score source, sort field and direction share one from 674 dp up (`useRankingSortRow`, which
  is `200 + 280 + 170` plus two gaps — a segmented button on each side of a dropdown, rather than
  two equal halves, which is why it is a separate and larger threshold).

Packing controls onto a line asks whether they fit, not whether the window has the shape for two
panes. Reading it as a split would have excluded a phone in landscape, where the panel costs 244 of
412 dp — proportionally the worst case in the app, and the one the pairing helps most. Below 572
nothing changes, so the phone-in-portrait layout is exactly what it was.

| Viewport | Panel width | Filter row | Sort row | Panel height |
|---|---|---|---|---|
| Z Fold 8 landscape 933 | 820 | yes | yes | 244 → **124** |
| Z Fold 8 portrait 704 | 591 | yes | no | 244 → **176** |
| Pixel 10 Pro Fold 791 | 678 | yes | yes | 244 → **124** |
| Z Fold 7 832 / 750 | 719 / 637 | yes / yes | yes / no | **124** / **176** |
| Z Fold 6 675 · Z Fold 5 659 | 562 / 546 | no | no | 244 (unchanged) |
| Tablet 1024 / 768 | 911 / 655 | yes | yes / no | **124** / **176** |
| Phone landscape 915 × 412 | 802 | yes | yes | 244 → **124** |
| Phone portrait 412 | 380 | no | no | 244 (unchanged) |

## Divergence from Google's guidance

Google's adaptive-layout guidance says window size classes are "explicitly not determined by the
size of the device screen" and "not intended for *isTablet*-type logic", and directs apps to decide
from available width rather than aspect ratio. This app **deliberately diverges** on one point: the
aspect test. It is not an oversight. Width alone cannot give the Fold 8 two different answers in
its two orientations, and that behaviour — split in landscape, original single column in portrait —
is the requirement the rule exists to satisfy.

Everything else follows Google exactly: the width and height floors are its breakpoints, the column
capacity is its feed guidance, and the navigation rail at medium width and up is its recommendation
verbatim.

## Tests

- `test/adaptive_layout_test.dart` — the gate, the rail rule, the content width, the capacity, the
  preference clamping, the settings pane width and the row math, pinned at the real logical-pixel
  geometry of every device in the tables above, with the device named in a comment so a regression
  names the device it would break. It also asserts that `useDetailTwoPane` and `canSplitLayout`
  still agree, so the delegation cannot silently drift.
- `test/detail_layout_test.dart` — the detail page's pane and cover sizing.
- `test/list_columns_ui_test.dart`, `test/detail_layout_ui_test.dart`,
  `test/kana_layout_ui_test.dart`, `test/settings_two_pane_ui_test.dart` and
  `test/shell_nav_ui_test.dart` — the rendered result, driven through the real pages at the same
  geometries.

`flutter_test` renders every glyph of its default font as a full em square, which inflates a label
to roughly two and a half times its real width. That is why `settings_two_pane_ui_test.dart` runs
in Simplified Chinese: the English option labels would overflow their rows in the test environment
and nowhere else, and short Chinese labels let the test measure the real layout rather than filter
errors around a fake one.
