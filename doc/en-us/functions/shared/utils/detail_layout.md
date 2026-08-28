# lib/shared/utils/detail_layout.dart

Small shared utility module for the anime detail page's adaptive layout: the
`detailCoverAspectRatio` and `detailLeftPaneHeaderBudget` constants, plus three pure helpers used
by `anime_detail_page.dart` (see
[../../features/anime/views/anime_detail_page.md](../../features/anime/views/anime_detail_page.md))
to decide whether to split the page into two panes and to size that split.

**The split decision itself no longer lives here.** The three thresholds that used to be
`detailTwoPaneMinWidth`, `detailTwoPaneMinHeight` and `detailTwoPaneMinAspect` moved to
[adaptive_layout.md](adaptive_layout.md) in 1.5.3, when the multi-column lists in the home,
management and statistics modules started sharing the same rule; `useDetailTwoPane` is now a
one-line delegate to `canSplitLayout`. What stays here is the sizing that is genuinely specific to
this page — how wide the left pane is and how large the cover inside it can be.

The module deliberately depends on nothing but `dart:core` and its sibling `adaptive_layout.dart` —
it holds no Flutter imports, and `useDetailTwoPane` takes two doubles rather than a `Size` for
exactly that reason — so every helper is directly unit-testable
(`test/detail_layout_test.dart`), and the rendered result is covered separately at real device
geometries by `test/detail_layout_ui_test.dart`.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`useDetailTwoPane`](#usedetailtwopane) | top-level function | A | Report whether the anime detail page should use its two-pane layout. |
| [`detailLeftPaneWidth`](#detailleftpanewidth) | top-level function | A | Return the width of the detail page's fixed left pane. |
| [`detailCoverSize`](#detailcoversize) | top-level function | A | Return the cover image size for the detail page's left pane. |

The two constants are plain declarations without `/// Purpose:` comments and are not indexed as
separate rows. `detailCoverAspectRatio` (180/260) preserves the cover proportions the
single-column layout has always used, and `detailLeftPaneHeaderBudget` (220.0) is the vertical
space reserved below the cover for the Japanese title, the chip row, the progress bar and its
label.

## Documentation

### `bool useDetailTwoPane(double width, double height)` <a id="usedetailtwopane"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/detail_layout.dart` (approx. line 21)
- **Purpose:** Decide whether the viewport is the right shape and size for the detail page's
  two-pane layout.
- **Inputs:** `width`, `height` — the viewport size in logical pixels, read from
  `MediaQuery.sizeOf(context)`.
- **Returns:** `bool` — whatever `canSplitLayout` returns.
- **Side effects:** None.
- **Algorithm:** `=> canSplitLayout(width, height)`. The three thresholds and the reasoning behind
  each of them are documented on [adaptive_layout.md](adaptive_layout.md) and, in prose, in
  [../../../adaptive-layout.md](../../../adaptive-layout.md).
- **Usage:**
  ```dart
  final screen = MediaQuery.sizeOf(context);
  if (!useDetailTwoPane(screen.width, screen.height)) {
    return ListView(children: [...]);
  }
  ```
  (from `_AnimeDetailPageState.build`, `lib/features/anime/views/anime_detail_page.dart`)
- **Notes:** The wrapper is kept rather than replaced at the call site so the detail page keeps
  naming the decision in its own vocabulary, and so the existing tests and this page keep their
  names. `test/adaptive_layout_test.dart` asserts the two functions agree across every pinned
  device geometry, so the delegation cannot silently drift.

  Briefly, for orientation: split when width >= 600, height >= 480, and width / height >= 0.82.
  The aspect test is the load-bearing one — a Galaxy Z Fold 8 unfolds to a 4:3 *landscape* panel,
  so it splits in landscape and keeps the single column in portrait, while the near-square Fold 7
  and Fold 8 Ultra split in both.

  The decision reads `MediaQuery.sizeOf(context)` rather than the `LayoutBuilder` constraints the
  panes are sized from: measuring the `Scaffold` body would subtract the app bar from the height
  and inflate the ratio, which would read the Z Fold 8 in portrait as 0.80 and leave almost no
  margin under the threshold.

### `double detailLeftPaneWidth(double totalWidth)` <a id="detailleftpanewidth"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/detail_layout.dart` (approx. line 30)
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
- **Source:** `lib/shared/utils/detail_layout.dart` (approx. line 48)
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
