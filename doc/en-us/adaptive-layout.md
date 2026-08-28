# Adaptive layout

This is the app-wide rule for **when a layout may split** — into two panes on the anime detail
page, or into multiple columns in the three data-browsing modules — and, once it may, **how many
columns** it gets. Both live in
[`lib/shared/utils/adaptive_layout.dart`](functions/shared/utils/adaptive_layout.md), a module that
deliberately imports nothing but `dart:core` so every decision is directly unit-testable without a
widget tree.

Before this file existed the rule lived only inside the detail page's own helper and read as a
detail-page rule. It is not: the same three thresholds now gate the multi-column lists as well, so
one device answers the same way everywhere in the app.

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
Fold 8 Ultra's portrait `0.90`, with roughly 9% margin on each side. A `720` threshold — the value
`kana_page.dart` uses for its own unrelated rule — would have failed the Fold 8, the Fold 5 and the
Fold 6 outright; `840` would have left only the Ultra.

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

Once splitting is allowed, the column count comes from the width the list actually gets:

```dart
int listColumnCapacity(double contentWidth) =>
    ((contentWidth + listTileGap) / (listTileMinWidth + listTileGap))
        .floor()
        .clamp(1, listMaxColumns);
```

with `listTileMinWidth = 320.0`, `listTileGap = 12.0` and `listMaxColumns = 4`. This is the
adaptive-minimum-width approach Google recommends for feed layouts — fit as many columns of at
least a minimum width as the space allows — rather than a hardcoded count per breakpoint. 320 dp is
what a list tile needs before its 40 × 56 cover, two lines of text and up to two trailing icon
buttons squeeze the title to nothing.

`listColumnCount` combines the two: one column when `canSplitLayout` is false, otherwise the
capacity when the user's preference is `listColumnsAuto`, otherwise the preference clamped to the
capacity. Clamping rather than rejecting is what lets a preference set on a desktop survive being
carried onto a folded phone and come back on unfolding.

| Viewport | Splits | Capacity | Columns at auto |
|---|---|---|---|
| Z Fold 8 landscape 933 × 704 | yes | 2 | 2 |
| Z Fold 8 portrait 704 × 933 | no | — | 1 |
| Z Fold 7 750 × 832 / 832 × 750 | yes | 2 | 2 either way |
| Z Fold 8 Ultra 859 × 954 / 954 × 859 | yes | 2 | 2 either way |
| Tablet 1024 × 768 | yes | 3 | 3 |
| Tablet 768 × 1024 | no | — | 1 |
| Phone landscape 915 × 412 | no | — | 1 |
| Desktop 1600 × 900 | yes | 4 | 4 |

Tiles are laid out **left to right, then top to bottom**. See
[`functions/shared/widgets/adaptive_tile_grid.md`](functions/shared/widgets/adaptive_tile_grid.md)
for why that is a builder over rows rather than a `GridView`.

## Measure the screen for the gate, the content for the capacity

`canSplitLayout` reads `MediaQuery.sizeOf(context)` — the whole screen. `listColumnCapacity` and
the detail page's pane sizing read the width the content actually gets. The asymmetry is
deliberate: measuring the split decision against the `Scaffold` body would subtract the app bar
from the height and inflate the ratio, reading a Z Fold 8 in portrait as `0.80` instead of `0.755`
and leaving almost no margin under the threshold.

## Folding and unfolding

`android/app/src/main/AndroidManifest.xml` declares
`screenLayout|screenSize|smallestScreenSize|density` among the activity's `configChanges`, so
folding or unfolding resizes the window **without restarting the activity**. Everything that reads
`MediaQuery.sizeOf` therefore re-evaluates on the next frame, which is all "switch automatically
when the device unfolds" needs — no lifecycle work, and no state to save and restore.

## Where this rule is and is not used

| Call site | Uses the rule |
|---|---|
| `anime_detail_page.dart` | Yes, through `useDetailTwoPane`, a one-line delegate to `canSplitLayout`. |
| `home_page.dart`, `management_page.dart`, `statistics_page.dart` | Yes, through `listColumnCount`. |
| `kana_page.dart` | **No.** |

`kana_page.dart` has its own inline `constraints.maxWidth >= 720` for its two-column card `Wrap`,
predating this module, and is deliberately left alone. Routing it through `canSplitLayout` would
change its behaviour on a tablet in portrait — 720 × 1280 currently gives two columns and the
aspect rule would give one — which is a user-visible change nobody asked for. It is recorded here
so the inconsistency is a known exception rather than a discovery.

## Divergence from Google's guidance

Google's adaptive-layout guidance says window size classes are "explicitly not determined by the
size of the device screen" and "not intended for *isTablet*-type logic", and directs apps to decide
from available width rather than aspect ratio. This app **deliberately diverges** on one point: the
aspect test. It is not an oversight. Width alone cannot give the Fold 8 two different answers in
its two orientations, and that behaviour — split in landscape, original single column in portrait —
is the requirement the rule exists to satisfy. The width and height floors follow Google's
breakpoints exactly, and the column capacity follows its feed guidance exactly.

## Tests

- `test/adaptive_layout_test.dart` — the gate, the capacity, the preference clamping and the row
  math, pinned at the real logical-pixel geometry of every device in the tables above, with the
  device named in a comment so a regression names the device it would break. It also asserts that
  `useDetailTwoPane` and `canSplitLayout` still agree, so the delegation cannot silently drift.
- `test/detail_layout_test.dart` — the detail page's pane and cover sizing.
- `test/list_columns_ui_test.dart` and `test/detail_layout_ui_test.dart` — the rendered result,
  driven through the real pages at the same geometries.
