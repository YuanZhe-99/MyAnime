# lib/features/recommendations/models/recommendation_data.dart

The model of `recommendations.json` (1.6.2): the global recommendation trash, the trashed
missing-sequel cards, and each record's persisted related list with its own trash. The file is a
synced data module (see [`../../../app/data_modules.md`](../../../app/data_modules.md)), so every
class keeps unknown JSON keys in `extraJson` and writes them back. Parsing is tolerant — a malformed
entry is dropped — except that a file which is not a JSON object is rejected, so sync validation
refuses a file that is not ours. The schema is in
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md#the-file-recommendationsjson).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `_unknown` | top-level function | B | Collect the keys a class does not know, for `extraJson`. |
| `_time` | top-level function | B | Read a UTC timestamp tolerantly. |
| `_indexed` | top-level function | B | Parse a JSON list into a map keyed by each entry's key; a later duplicate wins. |
| `_earlier` | top-level function | B | Pick the earlier of two optional timestamps. |
| `HiddenEntry.new` | constructor (`HiddenEntry`) | B | Create a trash entry: an anime id and when it was trashed. |
| `HiddenEntry.fromJson` | static method (`HiddenEntry`) | B | Read an entry; null without a string `id`. |
| `HiddenEntry.toJson` | method (`HiddenEntry`) | B | Serialize, unknown keys first. |
| [`HiddenEntry.mergedWith`](#hiddenentry-mergedwith) | method (`HiddenEntry`) | A | Combine both sides of one entry during a merge. |
| `HiddenSequelEntry.new` | constructor (`HiddenSequelEntry`) | B | Create a trashed missing-sequel entry with its labels. |
| `HiddenSequelEntry.fromJson` | static method (`HiddenSequelEntry`) | B | Read an entry; null without a string `key`. |
| `HiddenSequelEntry.toJson` | method (`HiddenSequelEntry`) | B | Serialize. |
| [`HiddenSequelEntry.mergedWith`](#hiddensequelentry-mergedwith) | method (`HiddenSequelEntry`) | A | Combine both sides of one entry during a merge. |
| `RelatedItem.new` | constructor (`RelatedItem`) | B | Create a related item: an anime id, reason codes, an optional AI reason. |
| `RelatedItem.fromJson` | static method (`RelatedItem`) | B | Read an item; null without a string `id`. |
| `RelatedItem.toJson` | method (`RelatedItem`) | B | Serialize; empty `reasons` omitted. |
| `RelatedItem.withAiReason` | method (`RelatedItem`) | B | Copy the item with a generated reason. |
| `RelatedSnapshot.new` | constructor (`RelatedSnapshot`) | B | Create a snapshot: `generatedAt`, items, trash. |
| `RelatedSnapshot.isGenerated` | getter (`RelatedSnapshot`) | B | Whether a list was ever generated (`generatedAt` set). |
| `RelatedSnapshot.isEmpty` | getter (`RelatedSnapshot`) | B | Whether nothing is worth writing; empty snapshots are dropped. |
| `RelatedSnapshot.fromJson` | static method (`RelatedSnapshot`) | B | Read a snapshot; null when not an object. |
| [`RelatedSnapshot.toJson`](#relatedsnapshot-tojson) | method (`RelatedSnapshot`) | A | Serialize with a sorted trash. |
| `RecommendationData.new` | constructor (`RecommendationData`) | B | Create the store contents with mutable collections. |
| [`RecommendationData.fromJson`](#recommendationdata-fromjson) | factory (`RecommendationData`) | A | Read the file tolerantly. |
| [`RecommendationData.toJson`](#recommendationdata-tojson) | method (`RecommendationData`) | A | Serialize the file with every collection sorted. |
| `RecommendationData.relatedFor` | method (`RecommendationData`) | B | Read one record's snapshot, creating an empty one when absent. |

`RecommendationData.currentVersion` (1) and the fields carry no `/// Purpose:` comment and are not
rows.

## Documentation

### `HiddenEntry mergedWith(HiddenEntry other)` <a id="hiddenentry-mergedwith"></a>
- **Kind:** method of `HiddenEntry`
- **Source:** `lib/features/recommendations/models/recommendation_data.dart` (approx. line 107)
- **Purpose:** Combine the local and remote sides of an entry both devices trashed.
- **Inputs:** `other` — the remote side.
- **Returns:** `HiddenEntry` with the earlier `hiddenAt` and the unknown keys of both, this side
  winning on the same key.
- **Side effects:** None.
- **Algorithm:** `_earlier(hiddenAt, other.hiddenAt)`; `{...other.extraJson, ...extraJson}`.
- **Usage:** `mergeKeyedSet` in [`../services/recommendation_merge.md`](../services/recommendation_merge.md).
- **Notes:** Both sides agree the record is trashed, so nothing can conflict.

### `HiddenSequelEntry mergedWith(HiddenSequelEntry other)` <a id="hiddensequelentry-mergedwith"></a>
- **Kind:** method of `HiddenSequelEntry`
- **Source:** `lib/features/recommendations/models/recommendation_data.dart` (approx. line 193)
- **Purpose:** Combine both sides of a trashed missing-sequel entry.
- **Inputs:** `other` — the remote side.
- **Returns:** `HiddenSequelEntry`.
- **Side effects:** None.
- **Algorithm:** `sourceId`, `title` and `source` from this side, else the other; the earlier
  `hiddenAt`; unknown keys unioned, this side winning.
- **Usage:** `mergeRecommendations`.
- **Notes:** The labels exist so the trash can name the entry after its relation disappears.

### `Map<String, dynamic> toJson()` <a id="relatedsnapshot-tojson"></a>
- **Kind:** method of `RelatedSnapshot`
- **Source:** `lib/features/recommendations/models/recommendation_data.dart` (approx. line 345)
- **Purpose:** Serialize one record's related list and trash.
- **Inputs:** None.
- **Returns:** `Map<String, dynamic>`.
- **Side effects:** None.
- **Algorithm:** Unknown keys, then `generatedAt` when set, `items` in ranked order when any, and
  `hidden` sorted by id when any.
- **Usage:** `RecommendationData.toJson`.
- **Notes:** Items keep their order because it is the ranking; the trash is sorted so unchanged data
  writes identical bytes.

### `factory RecommendationData.fromJson(Object? json)` <a id="recommendationdata-fromjson"></a>
- **Kind:** factory of `RecommendationData`
- **Source:** `lib/features/recommendations/models/recommendation_data.dart` (approx. line 399)
- **Purpose:** Read `recommendations.json`.
- **Inputs:** `json` — the decoded file.
- **Returns:** `RecommendationData`.
- **Side effects:** None.
- **Algorithm:** Throw `FormatException` unless `json` is a `Map`. Read `version` (default 1),
  `hidden` and `hiddenSequels` through `_indexed`, and `related` as a map of snapshots, dropping any
  value that is not an object. Everything else goes to `extraJson`.
- **Usage:** `RecommendationStore.load`, the merge, and `validateRecommendationsJson`.
- **Notes:** The one rejection is deliberate: sync validation must refuse a file that is not ours.

### `Map<String, dynamic> toJson()` <a id="recommendationdata-tojson"></a>
- **Kind:** method of `RecommendationData`
- **Source:** `lib/features/recommendations/models/recommendation_data.dart` (approx. line 435)
- **Purpose:** Serialize the whole file.
- **Inputs:** None.
- **Returns:** `Map<String, dynamic>`.
- **Side effects:** None.
- **Algorithm:** Unknown keys, then `version`, `hidden` sorted by id, `hiddenSequels` sorted by key,
  and `related` sorted by anime id with empty snapshots dropped.
- **Usage:** `encodeRecommendationData`.
- **Notes:** Sorting is what lets an unchanged file hit sync's raw-equality fast path.
