# lib/features/recommendations/views/recommendations_page.dart

`RecommendationsPage` (1.6.0, M5) is "What to watch next", at `/recommendations`, pushed from the
Home app-bar action that is shown only while recommendations are on. It lists the ranked candidates
from [`RecommendationService.rank`](../services/recommendation_service.md#recommendationservice-rank)
as cards with reason chips, appends sequels the anime databases list but the library lacks, and —
with on-device AI on and a model ready — fills in up to three short generated reasons. See
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md)
and [`../../../../adaptive-layout.md`](../../../../adaptive-layout.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `RecommendationsPage.new` | constructor (`RecommendationsPage`) | B | Create the recommendations page. |
| `RecommendationsPage.createState` | method (`RecommendationsPage`) | B | Create the state object. |
| `_RecommendationsPageState.initState` | method (`_RecommendationsPageState`) | B | Start `_load` on first build. |
| [`_RecommendationsPageState._load`](#_recommendationspagestate-_load) | method (`_RecommendationsPageState`) | A | Rank the library, then ask the model for reasons. |
| [`_RecommendationsPageState._requestAiReasons`](#_recommendationspagestate-_requestaireasons) | method (`_RecommendationsPageState`) | A | Ask the on-device model for reasons, if it can answer. |
| [`_RecommendationsPageState._hide`](#_recommendationspagestate-_hide) | method (`_RecommendationsPageState`) | A | Hide a candidate on this device. |
| [`_RecommendationsPageState._reasonLabel`](#_recommendationspagestate-_reasonlabel) | method (`_RecommendationsPageState`) | A | Word one reason chip. |
| [`_RecommendationsPageState.build`](#_recommendationspagestate-build) | method (`_RecommendationsPageState`) | A | Build the page. |
| [`_RecommendationsPageState._card`](#_recommendationspagestate-_card) | method (`_RecommendationsPageState`) | A | Build one recommendation card. |
| [`_RecommendationsPageState._missingCard`](#_recommendationspagestate-_missingcard) | method (`_RecommendationsPageState`) | A | Build a card for a sequel the library does not have. |
| `_RecommendationsPageState._cover` | method (`_RecommendationsPageState`) | B | Build a 56×80 cover through `ImageService.resolve`, or a placeholder. |

## Documentation

### `Future<void> _load()` <a id="_recommendationspagestate-_load"></a>
- **Kind:** method of `_RecommendationsPageState`
- **Source:** `lib/features/recommendations/views/recommendations_page.dart` (approx. line 72)
- **Purpose:** Rank the library, then ask the model for reasons.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Reads `anime_data.json` and `ai_insights.json` (pruned to live ids); sets state;
  may run the model once.
- **Algorithm:** 1) Load the library and `AiInsightsCache.load(liveIds: …)`. 2) `rank` with
  `JstTime.now()`. 3) Missing sequels: for each completed record that is the last member of its
  series (or has no series of two or more), take
  [`SeriesIndex.missingSequelFor`](../../anime/services/series_service.md#missingsequelfor),
  deduplicated by target URL or title. 4) Show the list. 5) Await `_requestAiReasons`.
- **Usage:** `initState`, and again after a missing-sequel card's create page returns.
- **Notes:** The deterministic list renders at once; nothing waits on the model.

### `Future<void> _requestAiReasons()` <a id="_recommendationspagestate-_requestaireasons"></a>
- **Kind:** method of `_RecommendationsPageState`
- **Source:** `lib/features/recommendations/views/recommendations_page.dart` (approx. line 115)
- **Purpose:** Ask the on-device model for reasons, if it can answer.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Shows a 2 px progress bar under the app bar while waiting; runs the model once;
  stores the reasons in state.
- **Algorithm:** Return when `canGenerate` is false or nothing is ranked. On iOS and macOS, when
  `ai.coreInfo?.localeSupported` is still unknown, first call `ai.refreshStatus` with the UI locale
  tag so Apple's `supportsLocale` answer is known, and return if the model stopped being able to
  generate. Pick the language with
  [`ReasonLanguage.forLocale`](../services/ai_reason_service.md#reasonlanguage-forlocale), passing
  `ai.coreInfo?.localeSupported`; return when it gives no language. Otherwise call
  [`writeAiReasons`](../services/ai_reason_service.md#writeaireasons) with `insights: _insights`.
- **Usage:** `_load`.
- **Notes:** Reasons are kept for this page only; leaving and returning asks again.

### `Future<void> _hide(Anime anime)` <a id="_recommendationspagestate-_hide"></a>
- **Kind:** method of `_RecommendationsPageState`
- **Source:** `lib/features/recommendations/views/recommendations_page.dart` (approx. line 143)
- **Purpose:** Hide a candidate on this device.
- **Inputs:** `anime`.
- **Returns:** None.
- **Side effects:** Adds the id to `hiddenRecommendations` and writes `ai_insights.json`; removes the
  card.
- **Algorithm:** Add, `AiInsightsCache.save`, then filter the ranked list.
- **Usage:** The *Not interested* button on each card.
- **Notes:** Per device: `ai_insights.json` is neither synced nor backed up. There is no UI to undo
  it; the id is dropped only when the record is deleted.

### `String _reasonLabel(RecommendationReason reason, AppLocalizations l10n)` <a id="_recommendationspagestate-_reasonlabel"></a>
- **Kind:** method of `_RecommendationsPageState`
- **Source:** `lib/features/recommendations/views/recommendations_page.dart` (approx. line 160)
- **Purpose:** Word one reason chip.
- **Inputs:** `reason`, `l10n`.
- **Returns:** `String`.
- **Side effects:** None.
- **Algorithm:** `NextAfterReason` → `reasonNextAfter(title)`; `CategoryMatchReason` →
  `reasonLikeCategories` with the ids through
  [`categoryLabel`](../../anime/views/category_widgets.md#categorylabel), comma-joined;
  `SameStudioReason` → `reasonSameStudio(title)`; `ExternalScoreReason` → `<source> <score to one
  decimal>`, unlocalized; `CatchUpReason` → `reasonCatchUp`.
- **Usage:** `_card`.
- **Notes:** The `switch` is exhaustive over the sealed class.

### `Widget build(BuildContext context)` <a id="_recommendationspagestate-build"></a>
- **Kind:** method of `_RecommendationsPageState`
- **Source:** `lib/features/recommendations/views/recommendations_page.dart` (approx. line 182)
- **Purpose:** Build the page.
- **Inputs:** `context`.
- **Returns:** A `Scaffold`.
- **Side effects:** None.
- **Algorithm:** Columns come from
  [`listColumnCount`](../../../shared/utils/adaptive_layout.md#listcolumncount) with the screen
  width as content width and `settings.homeListColumns` as the preference. Items are the ranked
  cards, then the missing-sequel cards, laid out by
  [`adaptiveTileRows`](../../../shared/widgets/adaptive_tile_grid.md#adaptivetilerows) in a
  `ListView`. A spinner while loading; `recommendationsEmpty` when there is nothing.
- **Usage:** Flutter.
- **Notes:** The page has no column button of its own; it follows the Home list's preference.

### `Widget _card(Recommendation r, AppLocalizations l10n)` <a id="_recommendationspagestate-_card"></a>
- **Kind:** method of `_RecommendationsPageState`
- **Source:** `lib/features/recommendations/views/recommendations_page.dart` (approx. line 237)
- **Purpose:** Build one recommendation card.
- **Inputs:** `r`, `l10n`.
- **Returns:** `Widget`.
- **Side effects:** None; a tap pushes `/anime/detail/<id>`.
- **Algorithm:** Cover, title (two lines), a `Wrap` of reason chips, then — when there is an AI
  reason — the sparkle icon with `aiGeneratedLabel` and the reason, and a *Not interested* button.
- **Usage:** `build`.
- **Notes:** The AI reason is always labelled as generated on this device.

### `Widget _missingCard(Anime source, AnimeExternalRelation sequel, AppLocalizations l10n)` <a id="_recommendationspagestate-_missingcard"></a>
- **Kind:** method of `_RecommendationsPageState`
- **Source:** `lib/features/recommendations/views/recommendations_page.dart` (approx. line 312)
- **Purpose:** Build a card for a sequel the library does not have.
- **Inputs:** `source` — the member it follows; `sequel`; `l10n`.
- **Returns:** `Widget`.
- **Side effects:** A tap pushes `/anime/edit` with
  [`NextSeasonPrefill.fromRelation`](../../anime/services/series_service.md#nextseasonprefill-fromrelation),
  then reloads.
- **Algorithm:** A `ListTile` titled `seriesMissingSequel(title, source)` with the subtitle
  `recommendationsNotInLibrary` ("Not in your library yet").
- **Usage:** `build`.
- **Notes:** The prefilled search starts only in full builds. These cards carry no *Not interested*
  button.
