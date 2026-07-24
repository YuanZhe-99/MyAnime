# Duplicate Detection and Merge

`duplicate_service.dart` provides duplicate detection and merge logic for anime records. It's
reused in two places: the dedicated "Check Duplicates" settings page, and import conflict
resolution for `.myanimeitem` bundles (see [`share-and-import.md`](share-and-import.md)).

## Grouping algorithm

Duplicate detection groups records by any of:

- Same `id`.
- Same non-empty `infoUrl` or `watchUrl`.
- Same normalized title + season + `firstAirDate`.

Groups are formed **transitively** using a union-find structure: if A matches B and B matches C
(even if A doesn't directly match C), all three land in one group. Each anime appears in at most
one group.

## Merge precedence rules

When merging a duplicate group down to one record:

- The **primary** record's `id` is preserved, and the primary record's fields win any conflict.
- Missing fields on the primary are filled in from fallback (non-primary) records.
- Episode statuses merge per-episode with precedence **watched > skipped > unwatched** — i.e. if
  any duplicate marked an episode watched, the merged result keeps it watched even if another
  duplicate has it unwatched.
- Rating sub-scores fill in from fallback records where the primary is missing a value (see
  `AnimeRating` in [`../data-formats.md`](../data-formats.md)).
- Notes are concatenated (not deduplicated against each other).
- Unknown JSON fields are preserved via the `extraJson` pattern (see
  [`../data-formats.md`](../data-formats.md)), the same as every other merge path in the app.

## UI entry points

- Settings has a **"Check Duplicates"** entry that opens a dedicated page listing every duplicate
  group with keep/merge/delete options.
- Import conflict resolution reuses this same detection to decide whether an incoming
  `.myanimeitem` record conflicts with an existing local record, showing a per-conflict dialog
  with keep-local/use-imported/merge options — see
  [`share-and-import.md`](share-and-import.md).

Note: this is a **local, one-time merge** operation distinct from WebDAV sync's per-record
three-way merge (see [`../algorithms/three-way-merge.md`](../algorithms/three-way-merge.md)) —
duplicate merge combines two *different* records with different IDs into one, while sync merge
reconciles the *same* record's `id` across two devices.
