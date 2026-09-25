# lib/features/recommendations/views/reason_labels.dart

The one place that words a recommendation reason chip (1.6.2). It moved here from
`RecommendationsPage._reasonLabel` when the detail page's related card started showing chips too.
See [`recommendations_page.md`](recommendations_page.md) and [`related_card.md`](related_card.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`reasonLabel`](#reasonlabel) | top-level function | A | Word one recommendation reason chip. |

## Documentation

### `String reasonLabel(RecommendationReason reason, AppLocalizations l10n)` <a id="reasonlabel"></a>
- **Kind:** top-level function
- **Source:** `lib/features/recommendations/views/reason_labels.dart` (approx. line 13)
- **Purpose:** Word one reason chip.
- **Inputs:** `reason`, `l10n`.
- **Returns:** `String`.
- **Side effects:** None.
- **Algorithm:**

| Reason | Label |
|---|---|
| `NextAfterReason` | `reasonNextAfter(title)` |
| `CategoryMatchReason` | `reasonLikeCategories` with the ids through `categoryLabel`, comma-joined |
| `SameStudioReason` | `reasonSameStudio(title)` |
| `ExternalScoreReason` | `<source> <score to one decimal>`, unlocalized |
| `CatchUpReason` | `reasonCatchUp` |
| `SharedCategoriesReason` | `reasonSharedCategories` ("Also romance, school") |
| `SharedStudioReason` | `reasonSharedStudio(studio)` ("Also by Madhouse") |
| `RelatedByDatabaseReason` | `seriesSuggestionSpinOff` for a spin-off, `seriesSuggestionAlternative` for an alternative version, else `reasonRelatedByDatabase` |
| `SharedTitleReason` | `reasonSharedTitle` ("Similar title") |

- **Usage:** `RecommendationsPage._card`, `RelatedRecommendationsCard._row`.
- **Notes:** The `switch` is exhaustive over the sealed class, so a new reason type cannot ship
  without a label.
