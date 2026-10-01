import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

/// Colors for the viewing statuses that carry a meaning of their own
/// (completed = success, dropped = failure) in charts, legends and share
/// images. Green and red are kept for recognisability but derived from the
/// active [ColorScheme], following Material 3's custom-color guidance, so they
/// sit in the same tonal family as the rest of the UI in light, dark and
/// dynamic color.
abstract final class StatusColors {
  /// Purpose: Return the color for completed anime.
  /// Inputs: `scheme` — the color scheme the color will be drawn on.
  /// Returns: `Color` — green harmonized toward `scheme.primary`.
  /// Side effects: None.
  /// Notes: Harmonization only shifts the hue slightly, so it still reads as
  /// green next to the dropped red.
  static Color completed(ColorScheme scheme) =>
      Colors.green.harmonizeWith(scheme.primary);

  /// Purpose: Return the color for dropped anime.
  /// Inputs: `scheme`.
  /// Returns: `Color` — `scheme.error`.
  /// Side effects: None.
  /// Notes: The scheme's error role is already a tuned red for its
  /// brightness.
  static Color dropped(ColorScheme scheme) => scheme.error;
}
