# lib/features/recommendations/services/recommendation_store.dart

`RecommendationStore` (1.6.2) owns `recommendations.json` under `AnimeStorage.getAppDir()`. Unlike
`ai_insights.json` it is registered in [`../../../app/data_modules.md`](../../../app/data_modules.md),
so it syncs and is backed up, and every save calls `AutoSyncService.notifySaved`. Every write is a
read-modify-write through `update`, queued inside the process, so a related-list save racing a *Not
interested* tap cannot drop either change. See
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `RecommendationStore._` | constructor (`RecommendationStore`) | B | Prevent instantiation. |
| `_file` | static method | B | Resolve `recommendations.json` under the app directory. |
| [`load`](#load) | static method | A | Load the store; empty when absent or unreadable. |
| [`update`](#update) | static method | A | Apply one queued change and save it. |
| [`_apply`](#_apply) | static method | A | Run one queued update. |
| `hide` | static method | B | Put records into the global trash; an id already there keeps its `hiddenAt`. |
| `restore` | static method | B | Take records out of the global trash. |
| `hideSequels` | static method | B | Put missing-sequel cards into the global trash. |
| `restoreSequels` | static method | B | Take missing-sequel cards out of the global trash. |
| [`hideBatch`](#hidebatch) | static method | A | Trash the global page's current batch in one write. |
| [`hideRelated`](#hiderelated) | static method | A | Put records into one record's own related trash. |
| `restoreRelated` | static method | B | Take records out of one record's related trash. |
| [`putRelated`](#putrelated) | static method | A | Persist one record's generated related list. |
| [`migrateFromInsights`](#migratefrominsights) | static method | A | Move the pre-1.6.2 per-device hidden list into the synced trash, once. |

`fileName` (`recommendations.json`) and the private queue `_tail` carry no `/// Purpose:` comment.

## Documentation

### `static Future<RecommendationData> load()` <a id="load"></a>
- **Kind:** static method of `RecommendationStore`
- **Source:** `lib/features/recommendations/services/recommendation_store.dart` (approx. line 55)
- **Purpose:** Read the store.
- **Inputs:** None.
- **Returns:** `Future<RecommendationData>` — empty when the file is absent or unreadable.
- **Side effects:** Reads the file.
- **Algorithm:** Decode through `RecommendationData.fromJson`; any error reads as empty.
- **Usage:** The recommendations page, the trash page and the related card.
- **Notes:** **Entries for deleted records are not pruned.** The readers skip them. Pruning on disk
  would reach sync as a deliberate restore and could delete another device's entries for a record
  this device has not received yet. Anime ids are UUIDs and never reused, so a dangling entry is
  harmless.

### `static Future<RecommendationData> update(void Function(RecommendationData) mutate)` <a id="update"></a>
- **Kind:** static method of `RecommendationStore`
- **Source:** `lib/features/recommendations/services/recommendation_store.dart` (approx. line 72)
- **Purpose:** Apply one change and save it.
- **Inputs:** `mutate` — edits the loaded data in place.
- **Returns:** `Future<RecommendationData>` — the data after the change.
- **Side effects:** See `_apply`.
- **Algorithm:** Chain the change onto `_tail` and complete a `Completer` with its result or error.
- **Usage:** Every helper below.
- **Notes:** The queue is per process; another process writing the file (the sync engine is in the
  same process) is not expected.

### `static Future<RecommendationData> _apply(void Function(RecommendationData) mutate)` <a id="_apply"></a>
- **Kind:** static method of `RecommendationStore`
- **Source:** `lib/features/recommendations/services/recommendation_store.dart` (approx. line 91)
- **Purpose:** Run one queued read-modify-write.
- **Inputs:** `mutate`.
- **Returns:** `Future<RecommendationData>`.
- **Side effects:** Writes the file atomically (tmp then rename) and calls
  `AutoSyncService.notifySaved`, only when the bytes changed.
- **Algorithm:** Read the current bytes (an unreadable file starts empty), mutate, encode with
  `encodeRecommendationData`. Return without writing when the bytes are unchanged, or when there is
  no file and the result is the empty store.
- **Usage:** `update`.
- **Notes:** Not creating the file for an empty store keeps a library that never used the trash
  free of it, so sync uploads nothing new for it.

### `static Future<RecommendationData> hideBatch(Iterable<String> ids, Iterable<HiddenSequelEntry> sequels)` <a id="hidebatch"></a>
- **Kind:** static method of `RecommendationStore`
- **Source:** `lib/features/recommendations/services/recommendation_store.dart` (approx. line 179)
- **Purpose:** Trash the global page's current batch.
- **Inputs:** `ids` — the shown library cards; `sequels` — the shown missing-sequel cards.
- **Returns:** `Future<RecommendationData>`.
- **Side effects:** One write, one auto-sync notification.
- **Algorithm:** Add every id and every sequel key with one shared `hiddenAt`, keeping entries that
  were already there.
- **Usage:** The recommendations page's refresh action.
- **Notes:** None.

### `static Future<RecommendationData> hideRelated(String animeId, Iterable<String> ids)` <a id="hiderelated"></a>
- **Kind:** static method of `RecommendationStore`
- **Source:** `lib/features/recommendations/services/recommendation_store.dart` (approx. line 209)
- **Purpose:** Put records into one record's own related trash.
- **Inputs:** `animeId` — whose list; `ids` — the related records.
- **Returns:** `Future<RecommendationData>`.
- **Side effects:** Writes the file.
- **Algorithm:** Add each id to `related[animeId].hidden`, then remove those ids from its `items`.
- **Usage:** The related card's refresh and *Not interested*.
- **Notes:** The per-record bin is separate from the global one: trashing here never hides a record
  from "What to watch next".

### `static Future<RecommendationData> putRelated(String animeId, List<RelatedItem> items, {DateTime? generatedAt})` <a id="putrelated"></a>
- **Kind:** static method of `RecommendationStore`
- **Source:** `lib/features/recommendations/services/recommendation_store.dart` (approx. line 241)
- **Purpose:** Persist one record's generated related list.
- **Inputs:** `animeId`; `items`; `generatedAt` — defaults to now, UTC.
- **Returns:** `Future<RecommendationData>`.
- **Side effects:** Writes the file.
- **Algorithm:** Replace `related[animeId]` with a snapshot of `items` and `generatedAt`, keeping the
  existing trash and unknown keys.
- **Usage:** The related card, once for the list and once more when AI reasons arrive, with the same
  `generatedAt`.
- **Notes:** None.

### `static Future<bool> migrateFromInsights()` <a id="migratefrominsights"></a>
- **Kind:** static method of `RecommendationStore`
- **Source:** `lib/features/recommendations/services/recommendation_store.dart` (approx. line 266)
- **Purpose:** Move the 1.6.0–1.6.1 *Not interested* list into the synced global trash.
- **Inputs:** None.
- **Returns:** `Future<bool>` — whether anything moved.
- **Side effects:** May write `recommendations.json` and `ai_insights.json`.
- **Algorithm:** Load `AiInsightsCache`; if `hiddenRecommendations` is empty return false; `hide` the
  ids; clear the set; save the cache.
- **Usage:** `RecommendationsPage._load` and `RecommendationTrashPage._load`.
- **Notes:** The ids leave `ai_insights.json` only after the store saved them. `hiddenAt` is the
  migration time, since the old list kept no dates.
