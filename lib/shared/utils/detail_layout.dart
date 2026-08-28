/// Minimum viewport width, in logical pixels, before the anime detail page may
/// use its two-pane layout.
const detailTwoPaneMinWidth = 600.0;

/// Minimum viewport height, in logical pixels, before the anime detail page may
/// use its two-pane layout.
const detailTwoPaneMinHeight = 480.0;

/// Minimum viewport width-to-height ratio before the anime detail page may use
/// its two-pane layout.
const detailTwoPaneMinAspect = 0.82;

/// Width-to-height ratio of the detail page cover image.
const detailCoverAspectRatio = 180 / 260;

/// Logical pixels the left pane reserves for the title, chips, progress bar and
/// its label before the cover is given whatever height is left.
const detailLeftPaneHeaderBudget = 220.0;

/// Purpose: Report whether the anime detail page should use its two-pane layout.
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
/// cramped panes.
bool useDetailTwoPane(double width, double height) {
  if (width < detailTwoPaneMinWidth) return false;
  if (height < detailTwoPaneMinHeight) return false;
  if (height <= 0) return false;
  return width / height >= detailTwoPaneMinAspect;
}

/// Purpose: Return the width of the detail page's fixed left pane.
/// Inputs: `totalWidth` — the full viewport width in logical pixels.
/// Returns: `double`.
/// Side effects: None.
/// Notes: Proportional rather than fixed because one foldable generation now
/// spans roughly 672 to 954 logical pixels unfolded; the clamps keep the pane
/// usable at the narrow end and stop it sprawling on a desktop window.
double detailLeftPaneWidth(double totalWidth) {
  return (totalWidth * 0.36).clamp(260.0, 420.0);
}

/// Purpose: Return the cover image size for the detail page's left pane.
/// Inputs: `paneWidth`, `paneHeight` — the left pane's size in logical pixels.
/// Returns: A record of the cover `width` and `height`.
/// Side effects: None.
/// Notes: The cover takes the height left after
/// [detailLeftPaneHeaderBudget], then is capped at half the pane and at 420,
/// floored at 140, and finally re-derived from the pane width whenever the
/// aspect-correct width would overflow. Every limit earns its place: the
/// half-pane cap keeps the content below the cover on screen when a wrapped
/// title and three rows of chips outgrow the flat budget, and the width check
/// stops a 3:4 portrait panel — which has far more vertical room relative to
/// its width than a near-square one — producing a tall, thin cover.
({double width, double height}) detailCoverSize(
  double paneWidth,
  double paneHeight,
) {
  var height = paneHeight - detailLeftPaneHeaderBudget;
  // Never more than half the pane, whatever the budget arithmetic says: the
  // header below the cover is content-sized, so a long title wrapping onto two
  // lines and chips wrapping onto three rows can outgrow a flat reservation.
  final halfPane = paneHeight / 2;
  if (height > halfPane) height = halfPane;
  if (height > 420) height = 420;
  if (height < 140) height = 140;
  final maxWidth = (paneWidth - 32).clamp(80.0, double.infinity);
  var width = height * detailCoverAspectRatio;
  if (width > maxWidth) {
    width = maxWidth;
    height = width / detailCoverAspectRatio;
  }
  return (width: width, height: height);
}
