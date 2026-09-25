# lib/features/ai/services/ai_insights_cache.dart

`AiInsightsCache` owns `ai_insights.json`, the per-device cache of results the on-device model
generated (1.6.0, M4). The file holds `AiInsights`: cached category classifications
(`AiCategoryEntry`, with an `AiCategoryStatus`) keyed by anime id, and a `hiddenRecommendations` id
list that held the per-device *Not interested* list in 1.6.0–1.6.1; since 1.6.2 it is only read to
migrate those ids into the synced `recommendations.json` and is then left empty (see
[`../../recommendations/services/recommendation_store.md`](../../recommendations/services/recommendation_store.md#migratefrominsights)).
It is the only file that reads or writes the cache. See
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md)
for the schema and [`../../../../data-formats.md`](../../../../data-formats.md) for where it sits in
the persisted-data inventory.

## Why this file is not synced

It follows [`MetadataCache`](../../anime/services/metadata_cache.md): tolerant load, atomic
pretty-printed writes, no `AutoSyncService.notifySaved`, and no registration in
[`../../../app/data_modules.md`](../../../app/data_modules.md) — so neither sync nor backup ever
sees it. It still lives under `AnimeStorage.getAppDir()`, so a storage-path change carries it along.
Everything in it can be regenerated, and the model that produced it belongs to this device.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `AiCategoryEntry.new` | constructor (`AiCategoryEntry`) | B | Create a cache entry. |
| `AiCategoryEntry.toJson` | method (`AiCategoryEntry`) | B | Serialize the entry; `model` only when known, `generatedAt` in UTC. |
| [`AiCategoryEntry.fromJson`](#aicategoryentry-fromjson) | static method (`AiCategoryEntry`) | A | Read an entry tolerantly. |
| `AiInsights.new` | constructor (`AiInsights`) | B | Create the insights store, empty by default. |
| [`AiInsights.toJson`](#aiinsights-tojson) | method (`AiInsights`) | A | Serialize the store. |
| `AiInsights.fromJson` | factory (`AiInsights`) | B | Read the store tolerantly, dropping malformed parts. |
| `AiInsightsCache._` | constructor (`AiInsightsCache`) | B | Prevent instantiation. |
| `AiInsightsCache._file` | static method (`AiInsightsCache`) | B | Resolve the cache file under the app directory. |
| [`AiInsightsCache.load`](#aiinsightscache-load) | static method (`AiInsightsCache`) | A | Load the cache, pruning entries for deleted records. |
| [`AiInsightsCache.save`](#aiinsightscache-save) | static method (`AiInsightsCache`) | A | Save the cache. |

The `AiCategoryStatus` enum (`ok`, `none`, `skipped`), the entry and store fields, and
`AiInsightsCache.fileName` carry no `/// Purpose:` comment and are not rows.

## Documentation

### `static AiCategoryEntry? fromJson(Object? json)` <a id="aicategoryentry-fromjson"></a>
- **Kind:** static method of `AiCategoryEntry`
- **Source:** `lib/features/ai/services/ai_insights_cache.dart` (approx. line 70)
- **Purpose:** Read an entry tolerantly.
- **Inputs:** `json` — one value from the `categories` map.
- **Returns:** `AiCategoryEntry?` — `null` when unusable.
- **Side effects:** None.
- **Algorithm:** Require a map with a string `fingerprint`, a known `status` name and a parseable
  `generatedAt`; otherwise return `null`. Keep only the string items of `ids`; `model` is optional.
- **Usage:** `AiInsights.fromJson`, once per entry.
- **Notes:** Unlike `anime_data.json`, nothing malformed is preserved: a cache is rebuildable, so a
  dropped entry only means the record is classified again.

### `Map<String, dynamic> toJson()` (`AiInsights`) <a id="aiinsights-tojson"></a>
- **Kind:** method of `AiInsights`
- **Source:** `lib/features/ai/services/ai_insights_cache.dart` (approx. line 118)
- **Purpose:** Serialize the store.
- **Inputs:** None.
- **Returns:** `Map<String, dynamic>` — `version: 1`, `categories`, `hiddenRecommendations`.
- **Side effects:** None.
- **Algorithm:** Write the `categories` keys in sorted order and `hiddenRecommendations` sorted.
- **Usage:** `AiInsightsCache.save`.
- **Notes:** Sorting means an unchanged store writes identical bytes.

### `static Future<AiInsights> load({Set<String>? liveIds})` <a id="aiinsightscache-load"></a>
- **Kind:** static method of `AiInsightsCache`
- **Source:** `lib/features/ai/services/ai_insights_cache.dart` (approx. line 186)
- **Purpose:** Load the cache, pruning entries for deleted records.
- **Inputs:** `liveIds` — ids of the records that still exist, or `null` to skip pruning.
- **Returns:** `Future<AiInsights>` — empty when the file is absent or unreadable.
- **Side effects:** Reads `ai_insights.json`.
- **Algorithm:** Decode through `AiInsights.fromJson`; when `liveIds` is given, remove every
  `categories` entry and `hiddenRecommendations` id not in it. Any exception yields an empty store.
- **Usage:** `CategoryClassifier` loads with the library's ids; the detail and management pages load
  without pruning, only to resolve categories.
- **Notes:** Pruning happens in memory; the next `save` writes it out.

### `static Future<void> save(AiInsights insights)` <a id="aiinsightscache-save"></a>
- **Kind:** static method of `AiInsightsCache`
- **Source:** `lib/features/ai/services/ai_insights_cache.dart` (approx. line 210)
- **Purpose:** Save the cache.
- **Inputs:** `insights`.
- **Returns:** None.
- **Side effects:** Writes `ai_insights.json.tmp` with `JsonEncoder.withIndent('  ')`, then renames it
  over the file.
- **Usage:** `CategoryClassifier._run`, after every classified record.
- **Notes:** Never calls `AutoSyncService.notifySaved` — the file never syncs.
