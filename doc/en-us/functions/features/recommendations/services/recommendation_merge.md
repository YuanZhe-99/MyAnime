# lib/features/recommendations/services/recommendation_merge.dart

The three-way merge for `recommendations.json` (1.6.2). It **never produces a conflict**: the trash
bins — and since 1.6.3 the pins — are sets, where "added on one side" and "removed on the other"
can be told apart against the sync base, and a related list — like, since 1.6.3, a missing sequel's
fetched info — is a regenerable cache where the newer one wins. That is why the module
in [`../../../app/data_modules.md`](../../../app/data_modules.md) always returns a complete outcome
and the conflict dialog never sees this file. See
[`../../../../sync.md`](../../../../sync.md#the-recommendations-file).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`encodeRecommendationData`](#encoderecommendationdata) | top-level function | A | Encode the store the way the store saves it. |
| [`mergeKeyedSet`](#mergekeyedset) | top-level function | A | Merge one keyed set three ways. |
| [`mergeRelatedSnapshot`](#mergerelatedsnapshot) | top-level function | A | Merge one record's related snapshot three ways. |
| [`normalizeRecommendations`](#normalizerecommendations) | top-level function | A | Restore the store's invariants after a merge: a pin beats a trash entry; trashed sequels lose their info (1.6.3). |
| [`mergeRecommendations`](#mergerecommendations) | top-level function | A | Merge local, remote and base store contents. |
| [`mergeRecommendationJson`](#mergerecommendationjson) | top-level function | A | Merge the raw JSON of the three sides for the sync engine. |

## Documentation

### `String encodeRecommendationData(RecommendationData data)` <a id="encoderecommendationdata"></a>
- **Kind:** top-level function
- **Source:** `lib/features/recommendations/services/recommendation_merge.dart` (approx. line 19)
- **Purpose:** Encode the store for disk and for upload.
- **Inputs:** `data`.
- **Returns:** Pretty-printed JSON (`JsonEncoder.withIndent('  ')`).
- **Side effects:** None.
- **Algorithm:** `_prettyJson.convert(data.toJson())`.
- **Usage:** `RecommendationStore` saves and `mergeRecommendationJson`.
- **Notes:** Both paths must produce identical bytes for the same data, or an unchanged file would
  re-upload on every sync.

### `Map<String, T> mergeKeyedSet<T>(Map<String, T> local, Map<String, T> remote, Map<String, T>? base, T Function(T, T) both)` <a id="mergekeyedset"></a>
- **Kind:** top-level function
- **Source:** `lib/features/recommendations/services/recommendation_merge.dart` (approx. line 30)
- **Purpose:** Merge one trash bin.
- **Inputs:** `local`, `remote`; `base` — null on a first sync; `both` — combines an entry on both
  sides.
- **Returns:** `Map<String, T>`.
- **Side effects:** None.
- **Algorithm:** For each key on either side: on both sides, `both(l, r)`; on one side only, keep it
  when the base lacks it (it was added there) and drop it when the base has it (the other side
  removed it). With no base, keep everything.
- **Usage:** The global trash, the trashed sequels and every record's own trash.

| Local | Remote | Base | Result |
|---|---|---|---|
| has | has | any | kept, `both` |
| has | — | — | kept: trashed locally |
| has | — | has | dropped: restored remotely |
| — | has | — | kept: trashed remotely |
| — | has | has | dropped: restored locally |

- **Notes:** A set without tombstones cannot tell every history apart. If one device restores an
  entry while another restores it and trashes it again, both between the same two syncs, the
  restore wins: an entry on one side only that the base also had reads as removed. Trashing it once
  more fixes it.

### `RelatedSnapshot? mergeRelatedSnapshot(RelatedSnapshot? local, RelatedSnapshot? remote, RelatedSnapshot? base)` <a id="mergerelatedsnapshot"></a>
- **Kind:** top-level function
- **Source:** `lib/features/recommendations/services/recommendation_merge.dart` (approx. line 56)
- **Purpose:** Merge one record's related list and its trash.
- **Inputs:** `local`, `remote`, `base` — any may be null.
- **Returns:** `RelatedSnapshot?` — null when the snapshot was removed.
- **Side effects:** None.
- **Algorithm:** On one side only, follow the set rule (keep unless the base had it). On both: the
  items and `generatedAt` of whichever side generated later (a tie keeps local), the trash through
  `mergeKeyedSet`, unknown keys unioned with local winning.
- **Usage:** `mergeRecommendations`.
- **Notes:** A related list is a cache, so "newer wins" loses nothing that cannot be regenerated; the
  trash, which is the user's decision, is never decided by timestamp.

### `RecommendationData mergeRecommendations(RecommendationData local, RecommendationData remote, RecommendationData? base)` <a id="mergerecommendations"></a>
- **Kind:** top-level function
- **Source:** `lib/features/recommendations/services/recommendation_merge.dart` (approx. line 114)
- **Purpose:** Merge the whole store.
- **Inputs:** `local`, `remote`, `base`.
- **Returns:** `RecommendationData`.
- **Side effects:** None.
- **Algorithm:** `mergeKeyedSet` for `hidden` and `hiddenSequels`, `mergeRelatedSnapshot` per record
  id, the higher `version`, and unknown top-level keys unioned with local winning. Since 1.6.3 also
  `mergeKeyedSet` for `pinned`, `pinnedSequels` (with `PinnedEntry.mergedWith`) and `sequelInfo`
  (with `SequelInfo.mergedWith`, newer fetch wins), and the result goes through
  [`normalizeRecommendations`](#normalizerecommendations).
- **Usage:** `mergeRecommendationJson`.
- **Notes:** Still never a conflict: every new collection is a set or a newer-wins cache.

### `RecommendationData normalizeRecommendations(RecommendationData data)` <a id="normalizerecommendations"></a>
- **Kind:** top-level function
- **Source:** `lib/features/recommendations/services/recommendation_merge.dart` (approx. line 96)
- **Purpose:** Restore the store's invariants after a merge (1.6.3).
- **Inputs:** `data` — merged contents, edited in place.
- **Returns:** `data`.
- **Side effects:** None beyond editing `data`.
- **Algorithm:** Remove from `hidden` every id in `pinned`; from `hiddenSequels` every key in
  `pinnedSequels`; from each related snapshot's `hidden` every id in its `pinned`. Then remove from
  `sequelInfo` every key now in `hiddenSequels`.
- **Usage:** `mergeRecommendations`.
- **Notes:** Each device's own writes never leave a card both pinned and trashed, but two devices
  can disagree between syncs: one pins a card while the other refreshes it away. **The explicit pin
  wins.** The second step keeps the rule that a trashed missing-sequel card holds only its labels,
  also when the trash came from the other device.

### `String mergeRecommendationJson(String localJson, String remoteJson, String? baseJson)` <a id="mergerecommendationjson"></a>
- **Kind:** top-level function
- **Source:** `lib/features/recommendations/services/recommendation_merge.dart` (approx. line 173)
- **Purpose:** Merge the raw files for the sync engine.
- **Inputs:** `localJson`, `remoteJson`; `baseJson` — null on a first sync.
- **Returns:** The merged file, pretty-printed.
- **Side effects:** None.
- **Algorithm:** Decode all three; an unreadable base is treated as absent; merge; encode.
- **Usage:** `mergeRecommendationsModule` in `data_modules.dart`.
- **Notes:** An unreadable base keeps every entry rather than dropping any. A local or remote file
  that is not a JSON object throws, which the engine reports as a failed merge for that module.
