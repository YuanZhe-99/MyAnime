# lib/shared/services/sync_merge.dart

The generic per-record three-way merge engine used by WebDAV sync. `mergeRecords<T>()` is
type-parameterized over accessor functions so it has no `Anime`-specific knowledge; `mergeAnimeData()`
is the thin anime-specific wrapper that [`webdav_service.md`](webdav_service.md) actually calls (its
`_syncLocked` step 4/8 — see [`../../../sync.md`](../../../sync.md)). The algorithm itself — the
three-way branch logic, deletion-by-absence semantics, and identical-content conflict suppression —
is documented in full in
[`../../../algorithms/three-way-merge.md`](../../../algorithms/three-way-merge.md); this page covers
each declaration's signature, inputs/outputs, and real call sites without re-deriving that algorithm.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`RecordConflict(...)`](#recordconflict-new) | constructor (`RecordConflict<T>`) | A | Represent one record ID where both sides changed and couldn't auto-resolve. |
| [`mergeRecords<T>`](#mergerecords) | top-level function | A | Generic per-record three-way merge by ID. |
| [`AnimeMergeResult(...)`](#animemergeresult-new) | constructor (`AnimeMergeResult`) | A | Wrap merged anime records, conflicts, and preserved extra JSON. |
| `hasConflicts` | getter (`AnimeMergeResult`) | B | Whether `conflicts` is non-empty. |
| [`buildResolved`](#buildresolved) | method (`AnimeMergeResult`) | A | Apply user conflict resolutions and produce the final `AnimeData`. |
| [`mergeAnimeData`](#mergeanimedata) | top-level function | A | Anime-specific wrapper around `mergeRecords` with unknown-JSON preservation. |

## Documentation

### `const RecordConflict({required id, required localRecord, required remoteRecord, required displayName})` <a id="recordconflict-new"></a>
- **Kind:** constructor of `RecordConflict<T>`
- **Source:** `lib/shared/services/sync_merge.dart` (line 19)
- **Purpose:** Hold one record ID where both local and remote changed since the base snapshot and the merge could not auto-resolve it.
- **Inputs:** `id`, `localRecord`, `remoteRecord`, `displayName` (for showing the user which record conflicted).
- **Returns:** A new `RecordConflict<T>`.
- **Side effects:** None.
- **Algorithm:** Plain field assignment; no branching.
- **Usage:**
  ```dart
  conflicts.add(
    RecordConflict(id: id, localRecord: l, remoteRecord: r, displayName: getDisplayName(l)),
  );
  ```
  (`mergeRecords<T>`, same file)
- **Notes:** `RecordMergeResult<T>` (the sibling class holding `merged`/`conflicts`) has no documented constructor of its own in this file — it is a plain `const` data holder.

### `RecordMergeResult<T> mergeRecords<T>({required local, required remote, required base, required getId, required getModifiedAt, required getDisplayName, bool autoResolve = false, String Function(T)? serialize})` <a id="mergerecords"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/services/sync_merge.dart` (line 43)
- **Purpose:** Merge two lists of records of type `T` by ID, using an optional last-synced base list to distinguish edits, deletions, and true conflicts.
- **Inputs:** `local`, `remote`, `base` (nullable — absent on a first sync); `getId`/`getModifiedAt`/`getDisplayName` accessor functions; `autoResolve` (last-writer-wins on true conflicts when `true`, default `false`); optional `serialize` (enables identical-content conflict suppression).
- **Returns:** `RecordMergeResult<T>` — `merged` list plus any `conflicts`.
- **Side effects:** None (pure function over its inputs).
- **Algorithm:** Full branch-by-branch logic (three-way case, base-absent case, one-sided-presence-as-deletion case) is documented in
  [`../../../algorithms/three-way-merge.md`](../../../algorithms/three-way-merge.md) — this is the exact function that doc describes. In short: build ID→record maps for all three lists, union the IDs, and for each ID decide keep-local / keep-remote / conflict / drop based on which side(s) changed relative to `base`.
- **Usage:**
  ```dart
  final result = mergeRecords<Anime>(
    local: localData.animes,
    remote: remoteData.animes,
    base: baseData?.animes,
    getId: (a) => a.id,
    getModifiedAt: (a) => a.modifiedAt,
    getDisplayName: (a) => a.displayTitle,
    autoResolve: autoResolve,
    serialize: (a) => jsonEncode(a.toJson()),
  );
  ```
  (`mergeAnimeData`, same file)
- **Notes:** Has no knowledge of `Anime` at all — every type-specific behavior comes in through the accessor closures the caller supplies, which is what lets `duplicate_service.dart` reuse the same merge shape for duplicate-group resolution with a different, non-generic routine (see
  [`../../../algorithms/three-way-merge.md`](../../../algorithms/three-way-merge.md) intro).

### `const AnimeMergeResult({required merged, conflicts = const [], extraJson = const {}})` <a id="animemergeresult-new"></a>
- **Kind:** constructor of `AnimeMergeResult`
- **Source:** `lib/shared/services/sync_merge.dart` (line 145)
- **Purpose:** Hold the anime-specific merge outcome: cleanly-merged records, any per-record conflicts, and preserved top-level `extraJson`.
- **Inputs:** `merged`, `conflicts` (default empty), `extraJson` (default empty).
- **Returns:** A new `AnimeMergeResult`.
- **Side effects:** None.
- **Algorithm:** Plain field assignment.
- **Usage:**
  ```dart
  return AnimeMergeResult(merged: merged, conflicts: result.conflicts, extraJson: extraJson);
  ```
  (`mergeAnimeData`, same file)
- **Notes:** This is the type wrapped by `WebDAVService`'s `PendingSync.animeMerge` (see [`webdav_service.md`](webdav_service.md)) when a sync attempt has to defer to manual conflict resolution.

### `bool get hasConflicts` (in `AnimeMergeResult`)
(Table row only — trivial getter, Tier B; see the Declarations table. `conflicts.isNotEmpty`.)

### `AnimeData buildResolved(Map<String, Anime> resolutions)` <a id="buildresolved"></a>
- **Kind:** method of `AnimeMergeResult`
- **Source:** `lib/shared/services/sync_merge.dart` (line 163)
- **Purpose:** Combine the already-clean merged records with the user's chosen resolution for each conflicting record, producing the final `AnimeData` to force-upload.
- **Inputs:** `resolutions` — maps each conflicting anime ID to the `Anime` record the user chose to keep.
- **Returns:** `AnimeData` (the cleanly-merged list plus one resolved record per conflict, with `extraJson`).
- **Side effects:** None (pure).
- **Algorithm:**
  1. Start from `merged` (the already-conflict-free records).
  2. For each conflict, look up `resolutions[c.id]`, falling back to `c.localRecord` if the caller didn't supply a resolution for that ID.
  3. Run the chosen record through `withPreservedUnknownJson([c.localRecord, c.remoteRecord])` so any `extraJson` fields unknown to this app version survive onto the resolved record (see [`../../../data-formats.md`](../../../data-formats.md)).
  4. Append each resolved record to the merged list and wrap the result in `AnimeData(animes: all, extraJson: extraJson)`.
- **Usage:**
  ```dart
  final mergedData = pending.animeMerge!.buildResolved(resolutions);
  ```
  (`WebDAVService.finalizePendingSync`, [`webdav_service.md`](webdav_service.md#finalizependingsync))
- **Notes:** Falling back to `c.localRecord` when a conflict ID is missing from `resolutions` means an incomplete resolutions map silently keeps the local copy for any unresolved conflict, rather than throwing.

### `AnimeMergeResult mergeAnimeData(String localJson, String remoteJson, String? baseJson, {bool autoResolve = false})` <a id="mergeanimedata"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/services/sync_merge.dart` (line 178)
- **Purpose:** Merge local, remote, and base `anime_data.json` strings into one conflict-aware result; this is the function `sync.md` step 4 actually calls.
- **Inputs:** `localJson`, `remoteJson` (required), `baseJson` (nullable — no base on a first sync); `autoResolve` (default `false`).
- **Returns:** `AnimeMergeResult`.
- **Side effects:** None (pure over its string inputs).
- **Algorithm:**
  1. Parse all three JSON strings into `AnimeData` via `AnimeData.fromJson` (`baseData` stays `null` if `baseJson` is `null`).
  2. Build local/remote ID→`Anime` maps for later unknown-JSON preservation.
  3. Call [`mergeRecords<Anime>`](#mergerecords) with `getId: (a) => a.id`, `getModifiedAt: (a) => a.modifiedAt`, `getDisplayName: (a) => a.displayTitle`, and `serialize: (a) => jsonEncode(a.toJson())` (this is what powers identical-content conflict suppression for anime specifically — see [`../../../algorithms/three-way-merge.md`](../../../algorithms/three-way-merge.md)).
  4. Run every merged record through `withPreservedUnknownJson([localMap[id], remoteMap[id]])` so unknown per-anime JSON fields survive.
  5. Merge top-level `extraJson` from local and remote `AnimeData` the same way (`localData.withPreservedUnknownJson([remoteData]).extraJson`).
  6. Return `AnimeMergeResult(merged, conflicts: result.conflicts, extraJson)`.
- **Usage:**
  ```dart
  var result = mergeAnimeData(currentLocalRaw, remoteRaw!, baseJson, autoResolve: autoResolve);
  ```
  (`WebDAVService._syncLocked`, [`webdav_service.md`](webdav_service.md#synclocked))
- **Notes:** Every production caller passes `autoResolve: false` (see [`../../../sync.md`](../../../sync.md) "Manual vs. auto-sync conflict handling") — true two-sided conflicts always come back as `conflicts`, never silently last-writer-wins resolved.
