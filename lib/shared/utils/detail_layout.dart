import 'adaptive_layout.dart';

/// Width-to-height ratio of the detail page cover image.
const detailCoverAspectRatio = 180 / 260;

/// Logical pixels the left pane reserves for the title, chips, progress bar and
/// its label before the cover is given whatever height is left.
const detailLeftPaneHeaderBudget = 220.0;

/// Width-to-height ratio of the edit page's cover picker.
const editCoverAspectRatio = 120 / 170;

/// Logical pixels the edit page's left pane reserves below its cover.
///
/// Two `OutlineInputBorder` text fields at 56 each, the 12 between them, the 16
/// under the cover, 16 of bottom padding, and 44 of slack so a validation error
/// appearing under the title field cannot push the column past the pane.
const editLeftPaneFieldBudget = 200.0;

/// Purpose: Report whether the anime detail page should use its two-pane layout.
/// Inputs: `width`, `height` — the viewport size in logical pixels.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Delegates to [canSplitLayout], which is the app-wide "when to split"
/// rule shared with the multi-column lists in the home, management and
/// statistics modules. The thresholds and the reasoning behind each of them
/// live in `lib/shared/utils/adaptive_layout.dart` and, in prose, in
/// `doc/en-us/adaptive-layout.md`. This wrapper exists so the detail page keeps
/// naming the decision in its own vocabulary.
bool useDetailTwoPane(double width, double height) =>
    canSplitLayout(width, height);

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

/// Purpose: Return the cover picker size for the edit page's left pane.
/// Inputs: `paneWidth`, `paneHeight` — the left pane's size in logical pixels.
/// Returns: A record of the cover `width` and `height`.
/// Side effects: None.
/// Notes: This is what makes the left pane non-scrolling: the cover takes the
/// height left after [editLeftPaneFieldBudget], so the column fits by
/// construction rather than by hoping. The 320 ceiling stops a desktop window
/// turning the picker into a poster, and the 140 floor keeps it a usable tap
/// target; between them the column runs 296 to 476 logical pixels, against the
/// 424 a pane has at the 480 minimum split height with an app bar above it.
/// Like [detailCoverSize] the height is re-derived from the width whenever the
/// aspect-correct width would overflow a narrow pane.
({double width, double height}) editCoverSize(
  double paneWidth,
  double paneHeight,
) {
  var height = paneHeight - editLeftPaneFieldBudget;
  if (height > 320) height = 320;
  if (height < 140) height = 140;
  final maxWidth = (paneWidth - 32).clamp(80.0, double.infinity);
  var width = height * editCoverAspectRatio;
  if (width > maxWidth) {
    width = maxWidth;
    height = width / editCoverAspectRatio;
  }
  return (width: width, height: height);
}
