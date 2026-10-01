# lib/shared/utils/status_colors.dart

`StatusColors` (1.7.0) is an `abstract final class` of static color helpers for the two viewing
statuses that carry a meaning of their own: completed (success) and dropped (failure). Green and red
are kept for recognisability, but they are derived from the active `ColorScheme`, following Material
3's custom-color guidance, so they sit in the same tonal family as the rest of the UI in light, dark
and dynamic color. The statistics page uses them for its summary cards, trend legend and bars
([`../../features/anime/views/statistics_page.md`](../../features/anime/views/statistics_page.md)),
and `ShareService` evaluates them on its fixed light palette
([`../services/share_service.md`](../services/share_service.md)). See
[`../../app/theme.md`](../../app/theme.md) for the scheme itself.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `StatusColors` | abstract final class | B | Namespace for the status colors; never instantiated. |
| [`StatusColors.completed`](#completed) | static method | A | The color for completed anime. |
| [`StatusColors.dropped`](#dropped) | static method | A | The color for dropped anime. |

## completed

- **Inputs:** `scheme` — the color scheme the color will be drawn on.
- **Returns:** `Color` — `Colors.green.harmonizeWith(scheme.primary)` (the `dynamic_color` extension).
- **Notes:** Harmonization only shifts the hue slightly toward the primary color, so it still reads
  as green next to the dropped red.

## dropped

- **Inputs:** `scheme`.
- **Returns:** `Color` — `scheme.error`.
- **Notes:** The scheme's error role is already a tuned red for its brightness.
