# Duplicate Detection and Merge

`duplicate_service.dart` provides duplicate detection and merge logic for anime records. It's
reused in two places: the dedicated "Check Duplicates" settings page, and import conflict
resolution for `.myanimeitem` bundles (see [`share-and-import.md`](share-and-import.md)).

## Grouping algorithm

Duplicate detection groups records by any of:

- Same `id`.
- Same non-empty `infoUrl` or `watchUrl`.
- Same normalized title + season + `firstAirDate`.

Because the season label is part of the title rule, members of one series with different season
labels (`Season 1`, `Season 2`) are never duplicates — `test/duplicate_service_test.dart` pins this
since series linking arrived in 1.6.0. Grouping seasons together is
[`series-linking.md`](series-linking.md)'s job, and it in turn refuses to link two records that look
like duplicates.

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
- The local-archive record is taken **whole** from the first record that has one — the primary if it
  does, otherwise the first fallback that does. Unlike ratings, it is not merged field-by-field: an
  archive describes one physical copy, so combining a `source` from one record with a `location`
  from another would describe a copy that does not exist (see `AnimeLocalArchive` in
  [`../data-formats.md`](../data-formats.md)).
- The series link (`seriesLink`, 1.6.0) is taken whole: the primary's if it has one, else the first
  fallback's. This keeps a curated membership or a standalone choice from being lost when the
  primary had none.
- The user's categories (`categories`, 1.6.0) follow the same rule: the primary's if it has the field
  — even `[]` — else the first fallback's; if none has it, the merged record stays automatic.
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
