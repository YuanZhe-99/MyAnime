# lib/features/categories/widgets/categorize_now_tile.dart

`CategorizeNowTile` (1.6.0, M4) is the Settings row that classifies every pending record now, with
an "N of M" count. Settings shows it in the *Categories & recommendations* section only while
automatic categories are on, and the tile itself renders nothing unless the platform may have an
on-device model and on-device AI is on. See
[`../services/category_service.md`](../services/category_service.md) and
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `CategorizeNowTile.new` | constructor (`CategorizeNowTile`) | B | Create the tile; `classifier` and `ai` are injectable for tests. |
| `CategorizeNowTile.createState` | method (`CategorizeNowTile`) | B | Create the state object. |
| `_CategorizeNowTileState.initState` | method (`_CategorizeNowTileState`) | B | Read the pending count when the tile appears (`refreshCounts`). |
| [`_CategorizeNowTileState.build`](#_categorizenowtilestate-build) | method (`_CategorizeNowTileState`) | A | Build the row. |

## Documentation

### `Widget build(BuildContext context)` <a id="_categorizenowtilestate-build"></a>
- **Kind:** method of `_CategorizeNowTileState`
- **Source:** `lib/features/categories/widgets/categorize_now_tile.dart` (approx. line 58)
- **Purpose:** Build the row.
- **Inputs:** `context`.
- **Returns:** A `ListTile`, or `SizedBox.shrink()` when `platformMayHaveOnDeviceModel` is false or
  AI is off.
- **Side effects:** None; the button calls `classifyAll` and then `refreshCounts`.
- **Algorithm:** Inside a `ListenableBuilder` on the classifier and the AI service: title
  `aiCategorizeNow`, subtitle `aiCategorizeProgress(pending, candidates)`, and a trailing spinner
  while a pass runs, else a tonal button.
- **Usage:** `settings_page.dart`, `if (settings.autoCategoriesEnabled) const CategorizeNowTile()`.
- **Notes:** The button is enabled only while the model can generate and something is pending.
