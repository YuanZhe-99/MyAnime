# Three-Way Merge Engine

This is a deep dive on the generic merge engine in `lib/shared/services/sync_merge.dart` (221
lines total). It is the algorithm behind step 4 of the WebDAV sync flow described in
[`../sync.md`](../sync.md), and the same file also merges duplicate-detection groups (see
[`../features/duplicate-detection.md`](../features/duplicate-detection.md)) — though that path
uses a different, non-generic merge routine in `duplicate_service.dart`, not this engine.

## Types

```dart
class RecordConflict<T> {
  final String id;
  final T localRecord;
  final T remoteRecord;
  final String displayName;
}

class RecordMergeResult<T> {
  final List<T> merged;
  final List<RecordConflict<T>> conflicts;
}
```

`RecordConflict<T>` represents one record ID where both sides changed since the base snapshot and
the change couldn't be auto-resolved. `RecordMergeResult<T>` is the overall outcome: the list of
records that merged cleanly, plus any unresolved conflicts.

## `mergeRecords<T>()`

```dart
RecordMergeResult<T> mergeRecords<T>({
  required List<T> local,
  required List<T> remote,
  required List<T>? base,
  required String Function(T) getId,
  required DateTime Function(T) getModifiedAt,
  required String Function(T) getDisplayName,
  bool autoResolve = false,
  String Function(T)? serialize,
})
```

This is a **generic** engine — it doesn't know anything about `Anime` specifically. It's
parameterized by accessor functions (`getId`, `getModifiedAt`, `getDisplayName`) and an optional
`serialize` function used only for identical-content detection.

### Algorithm

1. Build `id -> record` maps for `local`, `remote`, and `base` (base may be absent, e.g. on a
   first-ever sync).
2. Compute `allIds` as the union of every ID present in any of the three maps.
3. For each ID, look up `l` (local), `r` (remote), `b` (base) and branch:

   - **Present on both sides (`l != null && r != null`):**
     - **With a base record (`b != null`, three-way case):**
       - Compute `localChanged = getModifiedAt(l).isAfter(getModifiedAt(b))` and similarly for
         `remoteChanged`.
       - **Both changed:**
         - **Identical-content conflict suppression:** if `serialize` is provided and
           `serialize(l) == serialize(r)`, this is *not* treated as a real conflict even though
           both sides bumped `modifiedAt` independently — the local copy is kept as-is. This
           specifically handles the case where a stale base (e.g. from an earlier failed upload)
           makes two sides look like they diverged when the actual record content is identical.
         - Otherwise, if `autoResolve` is true, pick whichever record has the later `modifiedAt`
           (last-writer-wins per record).
         - Otherwise, emit a `RecordConflict` for the caller to resolve.
       - **Only local changed:** keep local.
       - **Only remote changed:** keep remote.
       - **Neither changed:** keep local (arbitrary but stable, since content should be identical).
     - **Without a base record (`b == null`):** this is a first sync, or both sides independently
       added a record with the same ID. There's no "who changed" question to ask, so the engine
       just picks whichever has the later `modifiedAt`.
   - **Present locally only (`l != null && r == null`):**
     - **With a base** where the record existed: it was deleted remotely. If `l` changed since
       base, the local edit is treated as intentional and kept (edit wins over concurrent remote
       deletion). If local didn't change, the remote deletion is respected and the record is
       dropped.
     - **Without a base:** the record is new locally and is kept unconditionally.
   - **Present remotely only (`l == null && r != null`):** symmetric to the above — a base record
     missing locally means "deleted locally"; kept only if the remote side changed since base,
     otherwise dropped in favor of the local deletion. Without a base, it's new remotely and kept.
   - **Present nowhere (both null, but was in base):** the record was deleted on both sides — it's
     simply excluded from the merged result.

4. Return `RecordMergeResult(merged: merged, conflicts: conflicts)`.

### Deletion semantics

There is no explicit "tombstone" concept in this engine — deletion is inferred purely from
**absence relative to the base snapshot**:

- A record present in `base` but missing from one side is that side's deletion.
- If the *other* side also touched the record after the base snapshot, the edit takes precedence
  over the deletion (nothing is silently lost to a delete race).
- If neither side touched it further, the deletion is honored.
- A record missing from `base` entirely (i.e. not part of the last sync) is always additive —
  whichever side has it, it's new and gets included, never treated as "deleted."

## `mergeAnimeData()` — the anime-specific wrapper

```dart
AnimeMergeResult mergeAnimeData(
  String localJson,
  String remoteJson,
  String? baseJson, {
  bool autoResolve = false,
})
```

This is the function `sync.md`'s step 4 actually calls. It:

1. Parses `localJson`/`remoteJson`/`baseJson` into `AnimeData` via `AnimeData.fromJson`.
2. Calls the generic `mergeRecords<Anime>()` above with:
   - `getId: (a) => a.id`
   - `getModifiedAt: (a) => a.modifiedAt`
   - `getDisplayName: (a) => a.displayTitle`
   - `serialize: (a) => jsonEncode(a.toJson())` — this is what powers identical-content conflict
     suppression for anime records specifically.
3. Runs every merged record through `withPreservedUnknownJson([localCopy, remoteCopy])` so
   `extraJson` fields unknown to this app version survive the merge (see
   [`../data-formats.md`](../data-formats.md)).
4. Merges top-level `extraJson` from local and remote `AnimeData` the same way.
5. Wraps the result in `AnimeMergeResult { merged, conflicts, extraJson }`, which exposes
   `hasConflicts` and a `buildResolved(Map<String, Anime> resolutions)` helper: once the caller has
   resolved every conflict (mapping conflict ID -> chosen `Anime`), `buildResolved` appends the
   resolved records — each also run through `withPreservedUnknownJson` against both the local and
   remote conflicting copies — onto the cleanly-merged list, producing the final `AnimeData` to
   force-upload (`sync.md` steps 8–9).

See [`../examples/sync-walkthrough.md`](../examples/sync-walkthrough.md) for this whole pipeline
traced through concrete JSON.
