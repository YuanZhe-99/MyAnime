# lib/features/recommendations/views/recommendations_page.dart

`RecommendationsPage` (1.6.0, M5) is "What to watch next", at `/recommendations`, pushed from the
Home app-bar action that is shown only while recommendations are on. It lists the ranked candidates
from [`RecommendationService.rank`](../services/recommendation_service.md#recommendationservice-rank)
as cards with reason chips, appends sequels the anime databases list but the library lacks, and —
with on-device AI on and a model ready — fills in up to three short generated reasons.

Since 1.6.2 the page shows a **batch of ten**, every card (missing sequels included) has *Not
interested*, which moves it to the **synced** trash in `recommendations.json`
([`../services/recommendation_store.md`](../services/recommendation_store.md)), and the app bar has
**Refresh** — trash the whole shown batch, show the next, with Undo — and **Trash**, which opens
[`recommendation_trash_page.md`](recommendation_trash_page.md). See
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md)
and [`../../../../adaptive-layout.md`](../../../../adaptive-layout.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `RecommendationsPage.new` | constructor (`RecommendationsPage`) | B | Create the recommendations page. |
| `RecommendationsPage.createState` | method (`RecommendationsPage`) | B | Create the state object. |
| `_RecommendationsPageState.initState` | method (`_RecommendationsPageState`) | B | Register `_load` with auto-sync and start it. |
| `_RecommendationsPageState.dispose` | method (`_RecommendationsPageState`) | B | Unregister from auto-sync (1.6.2). |
| [`_RecommendationsPageState._load`](#_recommendationspagestate-_load) | method (`_RecommendationsPageState`) | A | Rank the library, then ask the model for reasons. |
| [`_RecommendationsPageState._requestAiReasons`](#_recommendationspagestate-_requestaireasons) | method (`_RecommendationsPageState`) | A | Ask the on-device model for reasons, if it can answer. |
| [`_RecommendationsPageState._hide`](#_recommendationspagestate-_hide) | method (`_RecommendationsPageState`) | A | Put one library card into the trash. |
| [`_RecommendationsPageState._hideSequel`](#_recommendationspagestate-_hidesequel) | method (`_RecommendationsPageState`) | A | Put one missing-sequel card into the trash (1.6.2). |
| `_RecommendationsPageState._sequelEntry` | method (`_RecommendationsPageState`) | B | Describe a missing-sequel card as a `HiddenSequelEntry` (1.6.2). |
| [`_RecommendationsPageState._refreshBatch`](#_recommendationspagestate-_refreshbatch) | method (`_RecommendationsPageState`) | A | Trash the whole current batch and show the next one (1.6.2). |
| `_RecommendationsPageState._openTrash` | method (`_RecommendationsPageState`) | B | Push `/recommendations/trash`, then reload (1.6.2). |
| [`_RecommendationsPageState.build`](#_recommendationspagestate-build) | method (`_RecommendationsPageState`) | A | Build the page. |
| [`_RecommendationsPageState._card`](#_recommendationspagestate-_card) | method (`_RecommendationsPageState`) | A | Build one recommendation card. |
| [`_RecommendationsPageState._missingCard`](#_recommendationspagestate-_missingcard) | method (`_RecommendationsPageState`) | A | Build a card for a sequel the library does not have. |
| `_RecommendationsPageState._cover` | method (`_RecommendationsPageState`) | B | Delegate to `recommendationCover`. |
| `recommendationCover` | top-level function | B | Build a cover through `ImageService.resolve` (56×80 by default), or a placeholder; shared with the trash page and the related card (1.6.2). |

Through 1.6.1 this page also held `_reasonLabel`; since 1.6.2 chips are worded by the shared
[`reasonLabel`](reason_labels.md).

## Documentation

### `Future<void> _load()` <a id="_recommendationspagestate-_load"></a>
- **Kind:** method of `_RecommendationsPageState`
- **Source:** `lib/features/recommendations/views/recommendations_page.dart` (approx. line 92)
- **Purpose:** Rank the library, then ask the model for reasons.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Reads `anime_data.json`, `recommendations.json` and `ai_insights.json` (pruned to
  live ids); moves a 1.6.0–1.6.1 *Not interested* list into the synced trash once; sets state; may
  run the model once.
- **Algorithm:** 1) `RecommendationStore.migrateFromInsights()`. 2) Load the library, the store and
  `AiInsightsCache.load(liveIds: …)`. 3) `rank` with `hidden:` the store's global trash and
  `JstTime.now()`. 4) Missing sequels: for each completed record that is the last member of its
  series (or has no series of two or more), take
  [`SeriesIndex.missingSequelFor`](../../anime/services/series_service.md#missingsequelfor), keyed by
  [`sequelTrashKey`](../services/recommendation_service.md#sequeltrashkey), skipping keys in
  `hiddenSequels` and duplicates. 5) Show the list, clearing the AI reasons when the batch changed.
  6) Ask for reasons when the batch changed or none are shown.
- **Usage:** `initState`, auto-sync's local-data callback, after the trash page and a
  missing-sequel card's create page return, and after a refresh.
- **Notes:** The deterministic list renders at once; nothing waits on the model. A sync that changes
  nothing on this page keeps its reasons.

### `Future<void> _requestAiReasons()` <a id="_recommendationspagestate-_requestaireasons"></a>
- **Kind:** method of `_RecommendationsPageState`
- **Source:** `lib/features/recommendations/views/recommendations_page.dart` (approx. line 145)
- **Purpose:** Ask the on-device model for reasons, if it can answer.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Shows a 2 px progress bar under the app bar while waiting; runs the model once;
  stores the reasons in state.
- **Algorithm:** Return when `canGenerate` is false, nothing is ranked, or a request is already
  pending. On iOS and macOS, when `ai.coreInfo?.localeSupported` is still unknown, first call
  `ai.refreshStatus` with the UI locale tag so Apple's `supportsLocale` answer is known, and return
  if the model stopped being able to generate. Pick the language with
  [`ReasonLanguage.forLocale`](../services/ai_reason_service.md#reasonlanguage-forlocale), passing
  `ai.coreInfo?.localeSupported`; return when it gives no language. Otherwise call
  [`writeAiReasons`](../services/ai_reason_service.md#writeaireasons) with `insights: _insights`.
- **Usage:** `_load`.
- **Notes:** Reasons are kept for this page only; leaving and returning asks again.

### `Future<void> _hide(Anime anime)` <a id="_recommendationspagestate-_hide"></a>
- **Kind:** method of `_RecommendationsPageState`
- **Source:** `lib/features/recommendations/views/recommendations_page.dart` (approx. line 187)
- **Purpose:** Put one library card into the trash.
- **Inputs:** `anime`.
- **Returns:** None.
- **Side effects:** `RecommendationStore.hide([id])` — writes `recommendations.json`, which syncs;
  removes the card.
- **Algorithm:** Hide, then filter the ranked list.
- **Usage:** The *Not interested* button on each card.
- **Notes:** Through 1.6.1 this wrote the per-device `ai_insights.json` and could not be undone.
  Since 1.6.2 it syncs and the trash page restores it.

### `Future<void> _hideSequel(Anime source, AnimeExternalRelation sequel)` <a id="_recommendationspagestate-_hidesequel"></a>
- **Kind:** method of `_RecommendationsPageState`
- **Source:** `lib/features/recommendations/views/recommendations_page.dart` (approx. line 203)
- **Purpose:** Put one missing-sequel card into the trash.
- **Inputs:** `source` — the record it follows; `sequel`.
- **Returns:** None.
- **Side effects:** `RecommendationStore.hideSequels` — writes `recommendations.json`; removes the
  card.
- **Algorithm:** Store `_sequelEntry(source, sequel)` (key, source id, title, database), then filter
  the missing list by key.
- **Usage:** The *Not interested* button on each missing-sequel card.
- **Notes:** The title and database are kept so the trash can label the entry after the relation
  is gone.

### `Future<void> _refreshBatch()` <a id="_recommendationspagestate-_refreshbatch"></a>
- **Kind:** method of `_RecommendationsPageState`
- **Source:** `lib/features/recommendations/views/recommendations_page.dart` (approx. line 236)
- **Purpose:** Pass over the batch on screen and show the next one.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** One write of `recommendations.json` (synced); reloads; shows a snack bar
  "Moved N to the trash" with **Undo**.
- **Algorithm:** Collect the shown ranked ids and missing-sequel entries;
  `RecommendationStore.hideBatch`; `_load`; the snack bar's Undo calls `restore(ids)` and
  `restoreSequels(keys)` for exactly that batch, then reloads.
- **Usage:** The app bar's refresh button, disabled while loading or when nothing is shown.
- **Notes:** This is what refresh means: the batch the user looked at and passed over is "not
  interested". Everything stays restorable from the trash.

### `Widget build(BuildContext context)` <a id="_recommendationspagestate-build"></a>
- **Kind:** method of `_RecommendationsPageState`
- **Source:** `lib/features/recommendations/views/recommendations_page.dart` (approx. line 281)
- **Purpose:** Build the page.
- **Inputs:** `context`.
- **Returns:** A `Scaffold`.
- **Side effects:** None.
- **Algorithm:** App bar: title, **Refresh** (`Icons.refresh`) and **Trash** (`Icons.delete_outline`),
  with the 2 px progress bar while AI reasons are pending. Columns come from
  [`listColumnCount`](../../../shared/utils/adaptive_layout.md#listcolumncount) with the screen
  width as content width and `settings.homeListColumns` as the preference. Items are the ranked
  cards, then the missing-sequel cards, laid out by
  [`adaptiveTileRows`](../../../shared/widgets/adaptive_tile_grid.md#adaptivetilerows) in a
  `ListView`. A spinner while loading; `recommendationsEmpty` when there is nothing.
- **Usage:** Flutter.
- **Notes:** The page has no column button of its own; it follows the Home list's preference.

### `Widget _card(Recommendation r, AppLocalizations l10n)` <a id="_recommendationspagestate-_card"></a>
- **Kind:** method of `_RecommendationsPageState`
- **Source:** `lib/features/recommendations/views/recommendations_page.dart` (approx. line 348)
- **Purpose:** Build one recommendation card.
- **Inputs:** `r`, `l10n`.
- **Returns:** `Widget`.
- **Side effects:** None; a tap pushes `/anime/detail/<id>`.
- **Algorithm:** Cover, title (two lines), a `Wrap` of chips worded by
  [`reasonLabel`](reason_labels.md), then — when there is an AI reason — the sparkle icon with
  `aiGeneratedLabel` and the reason, and a *Not interested* button.
- **Usage:** `build`.
- **Notes:** The AI reason is always labelled as generated on this device.

### `Widget _missingCard(Anime source, AnimeExternalRelation sequel, AppLocalizations l10n)` <a id="_recommendationspagestate-_missingcard"></a>
- **Kind:** method of `_RecommendationsPageState`
- **Source:** `lib/features/recommendations/views/recommendations_page.dart` (approx. line 424)
- **Purpose:** Build a card for a sequel the library does not have.
- **Inputs:** `source` — the member it follows; `sequel`; `l10n`.
- **Returns:** `Widget`.
- **Side effects:** A tap pushes `/anime/edit` with
  [`NextSeasonPrefill.fromRelation`](../../anime/services/series_service.md#nextseasonprefill-fromrelation),
  then reloads.
- **Algorithm:** A `ListTile` titled `seriesMissingSequel(title, source)` with the subtitle
  `recommendationsNotInLibrary` ("Not in your library yet"), and under it a *Not interested* button
  (1.6.2) calling `_hideSequel`.
- **Usage:** `build`.
- **Notes:** The prefilled search starts only in full builds.
