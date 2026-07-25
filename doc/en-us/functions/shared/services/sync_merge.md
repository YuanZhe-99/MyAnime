# lib/shared/services/sync_merge.dart

**Split file.** The generic three-way record merge — `mergeRecords<T>`, `RecordConflict<T>`, and
`RecordMergeResult<T>` — moved to the `myapps_data` package (`lib/src/merge/sync_merge.dart`) and is
re-exported here, so every existing import keeps compiling. The anime-specific wrapper stays.

The package signature is MyDevice's superset: it adds one optional `mergeUnknownFields` callback.
MyAnime does not pass it — unknown-field preservation is baked into the models via
`withPreservedUnknownJson` — so behavior here is identical to before the extraction.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`AnimeMergeResult`](#animemergeresult) | class | A | Merged list, conflicts, and preserved top-level unknown JSON. |
| [`hasConflicts`](#animemergeresult) | getter | A | Whether manual resolution is required. |
| [`buildResolved(resolutions)`](#buildresolved) | method | A | Apply user choices and produce final `AnimeData`. |
| [`mergeAnimeData(...)`](#mergeanimedata) | function | A | Three-way merge of local/remote/base anime JSON. |
| `RecordConflict<T>` / `RecordMergeResult<T>` / `mergeRecords<T>` | re-export | A | The generic engine, from the package. |

## Documentation

### `class AnimeMergeResult` <a id="animemergeresult"></a>
- **Fields:** `merged` (`List<Anime>`), `conflicts` (`List<RecordConflict<Anime>>`), `extraJson`
  (unknown top-level fields preserved across the merge).
- **Getter:** `hasConflicts` — whether any record needs manual resolution.
- **Notes:** Carried through the sync engine as opaque `state`, which is how the conflict dialog
  still receives real `Anime` records.

### `buildResolved(resolutions)` <a id="buildresolved"></a>
- **Inputs:** `resolutions` maps anime ID to the chosen `Anime`.
- **Returns:** `AnimeData`.
- **Notes:** A missing choice falls back to the local record. The winning record is re-merged with
  both sides through `withPreservedUnknownJson`, so unknown fields survive resolution.

### `mergeAnimeData(localJson, remoteJson, baseJson, {autoResolve})` <a id="mergeanimedata"></a>
- **Returns:** `AnimeMergeResult`.
- **Notes:** Delegates per-record decisions to the shared `mergeRecords`, passing `serialize` so two
  sides with identical serialized content do not raise a conflict. Deletion semantics, identical-
  content suppression, and the no-base last-writer-wins rule all live in the package now and are
  covered by its test suite.

## Where the generic engine documentation lives

`packages/myapps_data/doc/en-us/functions/src/merge/sync_merge.md`.
