# lib/features/recommendations/views/related_card.dart

`RelatedRecommendationsCard` (1.6.2) is the detail page's "Related" card: up to five library records
like this one, ranked by
[`RecommendationService.related`](../services/recommendation_service.md#recommendationservice-related)
and **persisted** in `recommendations.json`, so the list is the same on every visit and every device
until the user refreshes it. Refresh puts the shown batch into this record's own trash and generates
the next one; each row's ✕ trashes one item; the menu opens this record's trash. The detail page
shows the card only while recommendations are on. See
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md#related-recommendations-on-the-detail-page).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `RelatedRecommendationsCard.new` | constructor | B | Create the card for `anime` over `library`. |
| `RelatedRecommendationsCard.createState` | method | B | Create the state object. |
| `_RelatedRecommendationsCardState.initState` | method | B | Register with auto-sync and load. |
| `_RelatedRecommendationsCardState.didUpdateWidget` | method | B | Reload for another record; a new library alone regenerates nothing. |
| `_RelatedRecommendationsCardState.dispose` | method | B | Unregister from auto-sync. |
| [`_load`](#_load) | method | A | Read the persisted list, generating it the first time. |
| [`_generate`](#_generate) | method | A | Rank a new list, save it, then ask the model for reasons. |
| [`_aiReasons`](#_aireasons) | method | A | Ask the on-device model for reasons, if it can answer. |
| [`_refresh`](#_refresh) | method | A | Trash the shown batch and generate the next one. |
| `_hide` | method | B | Trash one related record; the list shrinks until the next refresh. |
| `_openTrash` | method | B | Push `/recommendations/trash?anime=<id>`, then reload. |
| [`_resolved`](#_resolved) | getter | A | Pair each stored item with its record. |
| [`build`](#build) | method | A | Build the card. |
| `_row` | method | B | Build one row: cover, title, reason chips, labelled AI reason, ✕. |

`_RelatedAction` (`refresh`, `trash`) is the menu's private enum and carries no comment.

## Documentation

### `Future<void> _load()` <a id="_load"></a>
- **Kind:** method of `_RelatedRecommendationsCardState`
- **Source:** `lib/features/recommendations/views/related_card.dart` (approx. line 104)
- **Purpose:** Show the stored list, or make one.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Reads `recommendations.json`; writes it when no list was generated for this
  record yet.
- **Algorithm:** Load the store. When `related[id]` is missing or not `isGenerated`, `_generate`
  with its trash; otherwise show it.
- **Usage:** `initState`, auto-sync's local-data callback, after the trash page returns.
- **Notes:** A list synced from another device is shown as it is; nothing regenerates it except a
  refresh.

### `Future<void> _generate(Set<String> exclude)` <a id="_generate"></a>
- **Kind:** method of `_RelatedRecommendationsCardState`
- **Source:** `lib/features/recommendations/views/related_card.dart` (approx. line 122)
- **Purpose:** Make and persist a new list.
- **Inputs:** `exclude` — this record's trash.
- **Returns:** None.
- **Side effects:** Writes `recommendations.json` once for the list and once more if the model wrote
  reasons; may run the model once.
- **Algorithm:** 1) `AiInsightsCache.load()` for AI categories. 2)
  `RecommendationService.related(anime, library, insights:, exclude:)`. 3) Encode each reason with
  `encodeRelatedReason` and `putRelated` with one `generatedAt`; show it. 4) `_aiReasons`; when any
  arrive, `putRelated` again with `aiReason` filled and the same `generatedAt`.
- **Usage:** `_load`, `_refresh`.
- **Notes:** Guarded by `_busy`, so a sync reload during a generation does not start another.

### `Future<Map<String, String>> _aiReasons(List<Recommendation> ranked, AiInsights insights)` <a id="_aireasons"></a>
- **Kind:** method of `_RelatedRecommendationsCardState`
- **Source:** `lib/features/recommendations/views/related_card.dart` (approx. line 167)
- **Purpose:** Get up to three generated reasons.
- **Inputs:** `ranked`, `insights`.
- **Returns:** Anime id to reason; empty when skipped.
- **Side effects:** A 2 px progress bar under the header while waiting; one model run.
- **Algorithm:** The same gate as the global page: `canGenerate`; on iOS and macOS, ask Apple about
  the UI locale once when unknown; `ReasonLanguage.forLocale`; then
  [`writeRelatedAiReasons`](../services/ai_reason_service.md#writerelatedaireasons).
- **Usage:** `_generate`.
- **Notes:** Unlike the global page's reasons, these are persisted with the list.

### `Future<void> _refresh()` <a id="_refresh"></a>
- **Kind:** method of `_RelatedRecommendationsCardState`
- **Source:** `lib/features/recommendations/views/related_card.dart` (approx. line 209)
- **Purpose:** Pass over the shown batch.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Writes `recommendations.json` (synced).
- **Algorithm:** `hideRelated(id, shownIds)`, then `_generate` with the updated trash.
- **Usage:** The header's refresh button and the menu's *Show others*.
- **Notes:** With nothing shown it trashes nothing and simply regenerates, which is how records added
  since the last list can appear.

### `List<(Anime, RelatedItem)> get _resolved` <a id="_resolved"></a>
- **Kind:** getter of `_RelatedRecommendationsCardState`
- **Source:** `lib/features/recommendations/views/related_card.dart` (approx. line 246)
- **Purpose:** Turn stored ids into rows.
- **Inputs:** None.
- **Returns:** Items whose record exists and that are not trashed, in stored order.
- **Side effects:** None.
- **Algorithm:** Map the library by id; filter the snapshot's items.
- **Usage:** `build`, `_refresh`.
- **Notes:** A deleted record simply drops out; nothing is rewritten.

### `Widget build(BuildContext context)` <a id="build"></a>
- **Kind:** method of `_RelatedRecommendationsCardState`
- **Source:** `lib/features/recommendations/views/related_card.dart` (approx. line 263)
- **Purpose:** Build the card.
- **Inputs:** `context`.
- **Returns:** Nothing until the first load, then a `Card`.
- **Side effects:** None.
- **Algorithm:** A header `ListTile` titled `relatedTitle` with a refresh `IconButton` (disabled while
  busy) and a menu (*Show others*, *Trash*); the progress bar while AI reasons are pending;
  `relatedEmpty` when no row resolves; then one `_row` per item. Reason chips are decoded with
  `decodeRelatedReason` and worded by [`reasonLabel`](reason_labels.md); unknown codes are skipped.
- **Usage:** `AnimeDetailPage._buildDetailChildren`.
- **Notes:** `margin: EdgeInsets.zero`, like the detail page's other cards.
