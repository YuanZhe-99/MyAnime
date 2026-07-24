# lib/shared/services/duplicate_service.dart

`DuplicateService` implements the app's duplicate-anime detection and merge logic: grouping records
that are probably the same anime (by id, URL, or normalized title/season/air-date), and merging a
group down to one record with a documented field-precedence policy. It backs both the dedicated
"Check Duplicates" settings page (`lib/shared/widgets/duplicate_check_page.dart`) and
`.myanimeitem` import conflict resolution (`lib/shared/widgets/import_bundle_dialog.dart`, see
[`file_open_service.md`](file_open_service.md)). See
[`../../../features/duplicate-detection.md`](../../../features/duplicate-detection.md) for the full
grouping/merge algorithm write-up and how it differs from WebDAV sync's per-record three-way merge
([`../../../algorithms/three-way-merge.md`](../../../algorithms/three-way-merge.md)).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`DuplicateGroup.new`](#duplicategroup-new) | constructor (`DuplicateGroup`) | A | Create a duplicate group instance. |
| `label` | method (`DuplicateGroup`) | B | Return the localized label for this group's duplicate reason. |
| [`DuplicateResult.new`](#duplicateresult-new) | constructor (`DuplicateResult`) | A | Create a duplicate-scan result instance. |
| `hasDuplicates` | getter (`DuplicateResult`) | B | Whether any duplicate groups were found. |
| `totalDuplicates` | getter (`DuplicateResult`) | B | Total number of anime involved in duplicates. |
| [`ImportBundle.new`](#importbundle-new) | constructor (`ImportBundle`) | A | Create a parsed-import-bundle instance. |
| `hasConflicts` | getter (`ImportBundle`) | B | Whether the bundle has any conflicting records. |
| [`_normalizeTitle`](#_normalizetitle) | method (`DuplicateService`) | A | Normalize a title for duplicate comparison. |
| [`_titlesMatch`](#_titlesmatch) | method (`DuplicateService`) | A | Return whether two anime's titles (main or Japanese, cross-matched) are equal after normalization. |
| [`_datesMatch`](#_datesmatch) | method (`DuplicateService`) | A | Return whether two anime's first-air dates match, treating null as a weak match. |
| [`_seasonsMatch`](#_seasonsmatch) | method (`DuplicateService`) | A | Return whether two anime's season labels match, treating empty as a weak match. |
| [`_urlsMatch`](#_urlsmatch) | method (`DuplicateService`) | A | Return whether two anime share a non-empty info or watch URL. |
| [`_duplicateReason`](#_duplicatereason) | method (`DuplicateService`) | A | Return the strongest duplicate reason for a pair, or null if they aren't duplicates. |
| [`detect`](#detect) | method (`DuplicateService`) | A | Scan a list of anime and return transitively-grouped duplicate groups. |
| [`findConflict`](#findconflict) | method (`DuplicateService`) | A | Find the first local anime that conflicts with a candidate (used by import). |
| `_firstNonNull` | method (`DuplicateService`) | B | Return the first non-null value from an iterable. |
| [`merge`](#merge) | method (`DuplicateService`) | A | Merge a primary anime with fallback records using field-precedence rules. |

## Documentation

### `const DuplicateGroup({required this.animes, required this.reason})` <a id="duplicategroup-new"></a>
- **Kind:** constructor of `DuplicateGroup`
- **Source:** `lib/shared/services/duplicate_service.dart` (approx. line 26)
- **Purpose:** Hold a set of anime records considered duplicates of each other, plus the strongest
  matching reason.
- **Inputs:** `animes` — the group's members; `reason` — the strongest `DuplicateReason` found
  among any pair in the group.
- **Returns:** A new `DuplicateGroup`.
- **Side effects:** None.
- **Algorithm:** Direct field assignment.
- **Usage:**
  ```dart
  DuplicateGroup(animes: members, reason: strongest)
  ```
  (from [`detect`](#detect), building the result list)
- **Notes:** None.

### `const DuplicateResult({required this.groups})` <a id="duplicateresult-new"></a>
- **Kind:** constructor of `DuplicateResult`
- **Source:** `lib/shared/services/duplicate_service.dart` (approx. line 51)
- **Purpose:** Wrap the full list of duplicate groups found by a scan.
- **Inputs:** `groups` — the detected `DuplicateGroup` list.
- **Returns:** A new `DuplicateResult`.
- **Side effects:** None.
- **Algorithm:** Direct field assignment.
- **Usage:** Returned by [`detect`](#detect).
- **Notes:** None.

### `const ImportBundle({required this.animes, required this.conflictIndices, required this.localVersions})` <a id="importbundle-new"></a>
- **Kind:** constructor of `ImportBundle`
- **Source:** `lib/shared/services/duplicate_service.dart` (approx. line 85)
- **Purpose:** Hold the result of parsing a `.myanimeitem` bundle before it is applied to storage.
- **Inputs:** `animes` — parsed records (already given fresh UUIDs); `conflictIndices` — indices
  into `animes` that conflict with an existing local record; `localVersions` — the conflicting
  local record for each such index.
- **Returns:** A new `ImportBundle`.
- **Side effects:** None.
- **Algorithm:** Direct field assignment.
- **Usage:** Constructed by [`file_open_service.md`](file_open_service.md)'s `parseBundle`; consumed
  by `lib/shared/widgets/import_bundle_dialog.dart`'s conflict-resolution flow.
- **Notes:** None.

### `static String _normalizeTitle(String text)` <a id="_normalizetitle"></a>
- **Kind:** static method of `DuplicateService`
- **Source:** `lib/shared/services/duplicate_service.dart` (approx. line 107)
- **Purpose:** Normalize a title string so minor formatting differences (spacing, punctuation,
  full-width characters) don't prevent duplicate detection.
- **Inputs:** `text` — a raw title (main or Japanese).
- **Returns:** `String` — lowercased, trimmed, with common ASCII/CJK punctuation and whitespace
  (including the full-width space `　` and center dot `·`) stripped.
- **Side effects:** None.
- **Algorithm:** Lowercase the text, then `replaceAll` a character class covering whitespace, `·`,
  hyphens, underscores, full/half-width colon, `!`/`！`, `?`/`？`, `.`/`。`, `,`/`，`, parentheses
  (ASCII and full-width), brackets `[]`/`【】`, and Japanese quote marks `「」`/`『』`; trim the
  result.
- **Usage:** Called internally from [`_titlesMatch`](#_titlesmatch).
- **Notes:** Purely textual normalization — does not touch romanization or translation, so a title
  translated differently across sources will not match even after normalization.

### `static bool _titlesMatch(Anime a, Anime b)` <a id="_titlesmatch"></a>
- **Kind:** static method of `DuplicateService`
- **Source:** `lib/shared/services/duplicate_service.dart` (approx. line 120)
- **Purpose:** Decide whether two anime's titles should be considered the same anime.
- **Inputs:** `a`, `b` — the two anime being compared.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** Normalize (via [`_normalizeTitle`](#_normalizetitle)) both anime's `displayTitle`
  and `titleJa`. Match if: the normalized main titles are equal and non-empty; or the normalized
  Japanese titles are equal and non-empty; or one side's main title equals the other side's
  Japanese title (cross-match, in either direction) — this last case catches records where one
  source stored the Japanese title as the "main" title and another stored it as `titleJa`.
- **Usage:** Called internally from [`_duplicateReason`](#_duplicatereason).
- **Notes:** An empty normalized title never counts as a match on its own (guards against two
  untitled anime being grouped together).

### `static bool _datesMatch(Anime a, Anime b)` <a id="_datesmatch"></a>
- **Kind:** static method of `DuplicateService`
- **Source:** `lib/shared/services/duplicate_service.dart` (approx. line 141)
- **Purpose:** Decide whether two anime's first-air dates are compatible for duplicate grouping.
- **Inputs:** `a`, `b`.
- **Returns:** `bool` — `true` if either date is null (weak/unknown match), or if year/month/day all
  agree.
- **Side effects:** None.
- **Algorithm:** If either `firstAirDate` is null, return `true` (undated anime can still group by
  title+season alone); otherwise compare year, month, and day components.
- **Usage:** Called internally from [`_duplicateReason`](#_duplicatereason) as part of the
  title+season+date match.
- **Notes:** Treating null as a match is deliberate — it is one of three conditions ANDed together
  in [`_duplicateReason`](#_duplicatereason), so it only weakens the date check, not the whole
  match (title and season still have to agree).

### `static bool _seasonsMatch(Anime a, Anime b)` <a id="_seasonsmatch"></a>
- **Kind:** static method of `DuplicateService`
- **Source:** `lib/shared/services/duplicate_service.dart` (approx. line 153)
- **Purpose:** Decide whether two anime's season labels are compatible for duplicate grouping.
- **Inputs:** `a`, `b`.
- **Returns:** `bool` — `true` if either season string is empty (weak match) or the lowercased,
  trimmed values are equal.
- **Side effects:** None.
- **Algorithm:** Lowercase/trim both `season` fields; return `true` if either is empty, else compare
  equality.
- **Usage:** Called internally from [`_duplicateReason`](#_duplicatereason).
- **Notes:** None.

### `static bool _urlsMatch(Anime a, Anime b)` <a id="_urlsmatch"></a>
- **Kind:** static method of `DuplicateService`
- **Source:** `lib/shared/services/duplicate_service.dart` (approx. line 166)
- **Purpose:** Decide whether two anime share the same, non-empty info URL or watch URL.
- **Inputs:** `a`, `b`.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** Return `true` if both `infoUrl` values are non-empty and equal, or both `watchUrl`
  values are non-empty and equal; otherwise `false`.
- **Usage:** Called internally from [`_duplicateReason`](#_duplicatereason).
- **Notes:** None.

### `static DuplicateReason? _duplicateReason(Anime a, Anime b)` <a id="_duplicatereason"></a>
- **Kind:** static method of `DuplicateService`
- **Source:** `lib/shared/services/duplicate_service.dart` (approx. line 186)
- **Purpose:** Return the strongest reason two anime records should be treated as duplicates, or
  `null` if they are not duplicates at all.
- **Inputs:** `a`, `b`.
- **Returns:** `DuplicateReason?` — `sameId` > `sameUrl` > `sameTitleSeason`, in that precedence
  order, or `null`.
- **Side effects:** None.
- **Algorithm:**
  1. If `a.id == b.id`, return `DuplicateReason.sameId`.
  2. Else if [`_urlsMatch`](#_urlsmatch), return `DuplicateReason.sameUrl`.
  3. Else if [`_titlesMatch`](#_titlesmatch) AND [`_seasonsMatch`](#_seasonsmatch) AND
     [`_datesMatch`](#_datesmatch) all hold, return `DuplicateReason.sameTitleSeason`.
  4. Otherwise return `null`.
- **Usage:** Called internally from [`detect`](#detect) and [`findConflict`](#findconflict); this
  is the single source of truth for "are these two records the same anime".
- **Notes:** None.

### `static DuplicateResult detect(List<Anime> animes)` <a id="detect"></a>
- **Kind:** static method of `DuplicateService`
- **Source:** `lib/shared/services/duplicate_service.dart` (approx. line 203)
- **Purpose:** Scan an anime list and group records that are duplicates of each other, transitively.
- **Inputs:** `animes` — the full list to scan (typically all locally stored anime).
- **Returns:** `DuplicateResult` — groups with two or more members, sorted by the first member's
  `displayTitle`; each anime appears in at most one group.
- **Side effects:** None (pure computation).
- **Algorithm:** Union-find over list indices:
  1. Initialize `parent[i] = i` for every index.
  2. For every pair `(i, j)` with `i < j`, if [`_duplicateReason`](#_duplicatereason) is non-null,
     union their sets (path-compressing `find`).
  3. Group indices by their root parent; discard singleton groups (size 1).
  4. For each surviving group, recompute the strongest reason across all pairs within it
     (`sameId` > `sameUrl` > `sameTitleSeason`) for display.
  5. Sort groups by the first member's `displayTitle` for stable UI ordering.
- **Usage:**
  ```dart
  _result = DuplicateService.detect(_allAnime);
  ```
  (from `lib/shared/widgets/duplicate_check_page.dart`, populating the "Check Duplicates" page)
- **Notes:** O(n²) pairwise comparisons — acceptable for a typical personal anime list size but
  would need revisiting for very large libraries. See
  [`../../../features/duplicate-detection.md`](../../../features/duplicate-detection.md) for the
  transitive-grouping rationale (A~B, B~C ⇒ one group even if A doesn't directly match C).

### `static Anime? findConflict(List<Anime> local, Anime candidate)` <a id="findconflict"></a>
- **Kind:** static method of `DuplicateService`
- **Source:** `lib/shared/services/duplicate_service.dart` (approx. line 270)
- **Purpose:** Find the first existing local anime that duplicates an incoming candidate record,
  for import conflict detection.
- **Inputs:** `local` — current local anime list; `candidate` — an incoming (about-to-be-imported)
  record.
- **Returns:** `Anime?` — the first conflicting local record, or `null` if none conflicts.
- **Side effects:** None.
- **Algorithm:** Linear scan of `local`, returning the first entry for which
  [`_duplicateReason`](#_duplicatereason) is non-null against `candidate`.
- **Usage:**
  ```dart
  final match = DuplicateService.findConflict(localList, parsed[i]);
  ```
  (from [`file_open_service.md`](file_open_service.md)'s `parseBundle`, flagging bundle entries that
  conflict with existing local records before import)
- **Notes:** Returns only the *first* conflict — if a candidate matches more than one local record,
  the others are not reported.

### `static Anime merge(Anime primary, List<Anime> others)` <a id="merge"></a>
- **Kind:** static method of `DuplicateService`
- **Source:** `lib/shared/services/duplicate_service.dart` (approx. line 297)
- **Purpose:** Merge a duplicate group down to one record, with `primary` winning field conflicts
  and `others` filling in gaps.
- **Inputs:** `primary` — the record whose `id` and field values take precedence; `others` — the
  remaining duplicate records to fold in.
- **Returns:** `Anime` — a new record built from `primary.copyWith(...)`, keeping `primary.id`.
- **Side effects:** None (pure; the caller is responsible for persisting the result and deleting
  the folded-in records).
- **Algorithm:**
  1. **Episode statuses:** start from `primary`'s statuses; for each other record's per-episode
     status, keep the primary's existing value unless the incoming one is `watched` (always wins),
     or the incoming one is `skippedThisWeek` and the current value isn't `watched` — i.e.
     precedence is watched > skipped > unwatched.
  2. **Week offsets:** primary wins; missing keys are filled from `others` in order.
  3. **Rating:** built field-by-field (`overall`, `visual`, `story`, `character`, `music`,
     `enjoyment`) — primary's value wins per field, falling back to the first non-null value across
     `primary` + `others`; if primary has no rating at all, the first fallback rating with any data
     is used wholesale. Unknown rating JSON (`extraJson`) from every source is unioned in via
     `withExtraJson`.
  4. **Notes:** every non-empty, distinct (by trimmed text) note from `primary` and `others`, in
     order, joined with newlines (concatenated, not deduplicated against differently-worded notes).
  5. **Cover image:** primary wins; falls back to the first non-null cover among `others`.
  6. Builds the final `Anime` via `primary.copyWith(...)` for `endEpisode`, `manualType`,
     `airDayOfWeek`, `airTime`, `firstAirDate` (primary-wins-else-first-non-null pattern),
     `episodeStatuses`, `episodeWeekOffsets`, `coverImage`, `infoUrl`, `watchUrl`, `notes`,
     `rating`, and a fresh UTC `modifiedAt`; then calls `withPreservedUnknownJson([primary,
     ...others])` so unknown top-level JSON fields survive the merge (the `extraJson` pattern — see
     [`../../../data-formats.md`](../../../data-formats.md)).
- **Usage:**
  ```dart
  final merged = DuplicateService.merge(local, [imported]);
  ```
  (from `lib/shared/widgets/import_bundle_dialog.dart`, resolving an import conflict the user chose
  to merge; also used by `lib/shared/widgets/duplicate_check_page.dart`'s `_resolveGroup` for the
  "Check Duplicates" merge action)
- **Notes:** This is a **local, one-time** merge distinct from WebDAV sync's per-record three-way
  merge — see [`../../../features/duplicate-detection.md`](../../../features/duplicate-detection.md)
  for how the two differ (combining two different records' IDs vs. reconciling one record's ID
  across devices).
