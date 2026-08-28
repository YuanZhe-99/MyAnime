# lib/shared/utils/detail_layout.dart

Small shared utility module for the anime detail page's adaptive layout: the
`detailTwoPaneMinWidth`, `detailTwoPaneMinHeight`, `detailTwoPaneMinAspect`,
`detailCoverAspectRatio` and `detailLeftPaneHeaderBudget` constants, plus three pure helpers used
by `anime_detail_page.dart` (see
[../../features/anime/views/anime_detail_page.md](../../features/anime/views/anime_detail_page.md))
to decide whether to split the page into two panes and to size that split.

The module deliberately depends on nothing but `dart:core` — it holds no Flutter imports, and
`useDetailTwoPane` takes two doubles rather than a `Size` for exactly that reason — so every helper
is directly unit-testable (`test/detail_layout_test.dart`), and the rendered result is covered
separately at real device geometries by `test/detail_layout_ui_test.dart`.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`useDetailTwoPane`](#usedetailtwopane) | top-level function | A | Report whether the anime detail page should use its two-pane layout. |
| [`detailLeftPaneWidth`](#detailleftpanewidth) | top-level function | A | Return the width of the detail page's fixed left pane. |
| [`detailCoverSize`](#detailcoversize) | top-level function | A | Return the cover image size for the detail page's left pane. |

The five constants are plain declarations without `/// Purpose:` comments and are not indexed as
separate rows. `detailCoverAspectRatio` (180/260) preserves the cover proportions the
single-column layout has always used, and `detailLeftPaneHeaderBudget` (220.0) is the vertical
space reserved below the cover for the Japanese title, the chip row, the progress bar and its
label.

## Documentation

### `bool useDetailTwoPane(double width, double height)` <a id="usedetailtwopane"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/detail_layout.dart` (approx. line 33)
- **Purpose:** Decide whether the viewport is the right shape and size for the detail page's
  two-pane layout.
- **Inputs:** `width`, `height` — the viewport size in logical pixels, read from
  `MediaQuery.sizeOf(context)`.
- **Returns:** `bool` — `true` when all three conditions hold.
- **Side effects:** None.
- **Algorithm:** Three independent tests, all of which must pass:
  1. `width >= detailTwoPaneMinWidth` (600.0)
  2. `height >= detailTwoPaneMinHeight` (480.0)
  3. `width / height >= detailTwoPaneMinAspect` (0.82)
- **Usage:**
  ```dart
  final screen = MediaQuery.sizeOf(context);
  if (!useDetailTwoPane(screen.width, screen.height)) {
    return ListView(children: [...]);
  }
  ```
  (from `_AnimeDetailPageState.build`, `lib/features/anime/views/anime_detail_page.dart`)
- **Notes:** **The aspect test is the load-bearing one, and it is why this is not a plain width
  breakpoint.** The Galaxy Z Fold 8 unfolds to a 4:3 *landscape* panel (2448 × 1848 px), so in
  portrait it is 3:4 — narrower relative to its height than the near-square Fold 7 it replaced,
  despite being newer. One device therefore needs two different answers at one width: split in
  landscape, keep the original single column in portrait. The threshold 0.82 sits near the middle
  of the gap between the Fold 8's portrait 0.755 and the Fold 7 / Fold 8 Ultra's portrait 0.90,
  with roughly 9% margin on each side.

  The width floor is the usual Material 3 *medium* / Android `sw600dp` threshold. Every unfolded
  foldable clears it by at least 59 dp even at the denser end of the plausible display-size range,
  and every folded cover screen (roughly 356–416 dp) sits well below it.

  The height floor exists because the aspect test alone admits *wide and short* viewports: without
  it, a folded Z Fold 8 cover screen rotated to landscape (~657 × 416 dp) and an ordinary phone in
  landscape (~915 × 412 dp) would both split into two cramped panes.

  Because the rule is about shape rather than device class, a 4:3 or 16:10 tablet in portrait also
  stays single-column and splits in landscape, exactly like the Fold 8.

  The decision reads `MediaQuery.sizeOf(context)` rather than the `LayoutBuilder` constraints the
  panes are sized from: measuring the `Scaffold` body would subtract the app bar from the height
  and inflate the ratio, which would read the Z Fold 8 in portrait as 0.80 and leave almost no
  margin under the threshold.

### `double detailLeftPaneWidth(double totalWidth)` <a id="detailleftpanewidth"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/detail_layout.dart` (approx. line 48)
- **Purpose:** Size the fixed left pane that holds the cover through the watch progress.
- **Inputs:** `totalWidth` — the full viewport width in logical pixels.
- **Returns:** `double` — `totalWidth * 0.36`, clamped to `[260.0, 420.0]`.
- **Side effects:** None.
- **Algorithm:** A fixed proportion of the viewport, clamped at both ends.
- **Usage:**
  ```dart
  final paneWidth = detailLeftPaneWidth(constraints.maxWidth);
  ```
  (from `_AnimeDetailPageState.build`, two-pane branch)
- **Notes:** Proportional rather than fixed because one foldable generation now spans roughly
  672 dp (Z Fold 8, portrait-density worst case) to 954 dp (Z Fold 8 Ultra, landscape) unfolded —
  a much wider range than before the Fold 8 split the lineup into a 4:3 model and a near-square
  Ultra. The lower clamp keeps the pane usable at 600 dp; the upper stops it sprawling in a
  desktop window. The 0.36 factor with those clamps always leaves the right pane the larger share.

### `({double width, double height}) detailCoverSize(double paneWidth, double paneHeight)` <a id="detailcoversize"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/detail_layout.dart` (approx. line 66)
- **Purpose:** Size the cover image so it fills the height the left pane has spare without pushing
  the header below it off screen.
- **Inputs:** `paneWidth`, `paneHeight` — the left pane's size in logical pixels.
- **Returns:** A record of the cover `width` and `height`.
- **Side effects:** None.
- **Algorithm:**
  1. Start from `paneHeight - detailLeftPaneHeaderBudget`.
  2. Cap at `paneHeight / 2`, then at `420`, then floor at `140`.
  3. Derive `width` from `height * detailCoverAspectRatio`.
  4. If that width exceeds `paneWidth - 32`, take the width as the binding constraint instead and
     recompute the height from it, so the aspect ratio is preserved either way.
- **Usage:**
  ```dart
  final cover = detailCoverSize(paneWidth, constraints.maxHeight);
  ```
  (from `_AnimeDetailPageState.build`, two-pane branch, passed to `_buildCover`)
- **Notes:** Every limit earns its place, and two of them were added after seeing the rendered
  result rather than derived up front. The **half-pane cap** exists because the header below the
  cover is content-sized: on a Z Fold 8 in landscape (704 dp tall) the flat budget alone handed the
  cover 420 dp, and a title wrapping onto two lines above three rows of chips then ran past the
  bottom of the pane. The **width check** exists because a 3:4 portrait panel has far more vertical
  room relative to its width than a near-square one, so height-only sizing produced a tall, thin
  cover. The left pane is still a `SingleChildScrollView`, so unusually long content or an extreme
  text scale scrolls rather than overflowing.
