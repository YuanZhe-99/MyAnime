# lib/features/recommendations/views/recommendation_trash_page.dart

`RecommendationTrashPage` (1.6.2) is the recommendation trash, at `/recommendations/trash`. Without
`?anime=<id>` it is the global bin behind "What to watch next": trashed library records, then
trashed missing-sequel cards. With it, it is that record's own bin behind its related list, titled
"Trash · <title>". **Restore** takes an entry out so it can be recommended again; *Restore all* in the
app bar restores everything shown. See
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md#the-trash).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `RecommendationTrashPage.new` | constructor | B | Create the page; `animeId` null for the global bin. |
| `RecommendationTrashPage.createState` | method | B | Create the state object. |
| `_RecommendationTrashPageState.initState` | method | B | Register with auto-sync and load. |
| `_RecommendationTrashPageState.dispose` | method | B | Unregister from auto-sync. |
| [`_load`](#_load) | method | A | Read the library and the store. |
| [`_records`](#_records) | getter | A | List the trashed records this page shows. |
| `_sequels` | getter | B | List trashed missing-sequel cards, newest first; empty for a record's own bin. |
| `_newestFirst` | static method | B | Comparator: newest timestamp first, missing last, then by key. |
| [`_restore`](#_restore) | method | A | Restore trashed records from the bin this page shows. |
| `_restoreSequels` | method | B | Restore trashed missing-sequel cards. |
| `_restoreAll` | method | B | Restore everything shown; entries for deleted records are left alone. |
| [`build`](#build) | method | A | Build the page. |

## Documentation

### `Future<void> _load()` <a id="_load"></a>
- **Kind:** method of `_RecommendationTrashPageState`
- **Source:** `lib/features/recommendations/views/recommendation_trash_page.dart` (approx. line 73)
- **Purpose:** Read what the page shows.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Reads `anime_data.json` and `recommendations.json`; runs
  `RecommendationStore.migrateFromInsights` once.
- **Algorithm:** Migrate, load the library into an id map, load the store, `setState`.
- **Usage:** `initState`, auto-sync's local-data callback, and after every restore.
- **Notes:** None.

### `List<(HiddenEntry, Anime)> get _records` <a id="_records"></a>
- **Kind:** getter of `_RecommendationTrashPageState`
- **Source:** `lib/features/recommendations/views/recommendation_trash_page.dart` (approx. line 91)
- **Purpose:** Pair each trashed id with its record.
- **Inputs:** None.
- **Returns:** Newest first.
- **Side effects:** None.
- **Algorithm:** The global `hidden` map, or `related[animeId].hidden`; keep entries whose record
  exists; sort with `_newestFirst`.
- **Usage:** `build`, `_restoreAll`.
- **Notes:** Entries for deleted records are skipped, not deleted: removing them would sync as a
  restore.

### `Future<void> _restore(Iterable<String> ids)` <a id="_restore"></a>
- **Kind:** method of `_RecommendationTrashPageState`
- **Source:** `lib/features/recommendations/views/recommendation_trash_page.dart` (approx. line 138)
- **Purpose:** Restore records.
- **Inputs:** `ids`.
- **Returns:** None.
- **Side effects:** Writes `recommendations.json` (synced); reloads.
- **Algorithm:** `RecommendationStore.restore` for the global bin, else `restoreRelated(animeId, …)`.
- **Usage:** Each row's **Restore**, and `_restoreAll`.
- **Notes:** A restored related item is not put back into the stored list; it can appear again on
  the card's next refresh.

### `Widget build(BuildContext context)` <a id="build"></a>
- **Kind:** method of `_RecommendationTrashPageState`
- **Source:** `lib/features/recommendations/views/recommendation_trash_page.dart` (approx. line 177)
- **Purpose:** Build the page.
- **Inputs:** `context`.
- **Returns:** A `Scaffold`.
- **Side effects:** None; a record row's tap pushes its detail page.
- **Algorithm:** Title `recommendationsTrash`, or `relatedTrashTitle(title)` for a record's bin;
  *Restore all* in the app bar, disabled when empty. One `ListTile` per record (40×56 cover through
  `recommendationCover`, title, "Trashed <date>" through `MaterialLocalizations.formatMediumDate`,
  **Restore**), then — global bin only — a "Sequels not in your library" heading and one row per
  trashed sequel (`seriesMissingSequel(title, source)`, "Next after <source record>" when it still
  exists, the date, **Restore**). `recommendationsTrashEmpty` when both lists are empty.
- **Usage:** Flutter.
- **Notes:** A plain list; the page has no column button.
