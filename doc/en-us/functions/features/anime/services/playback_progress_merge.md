# lib/features/anime/services/playback_progress_merge.dart

The three-way merge for `playback_progress.json` (1.6.5). It never produces a conflict. Entries
merge per key through `mergeKeyedSet`, imported from
[`../../recommendations/services/recommendation_merge.md`](../../recommendations/services/recommendation_merge.md).
See [`../../../../sync.md`](../../../../sync.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `encodePlaybackProgress` | function | B | Encode the store the way it is saved (two-space pretty JSON). |
| [`mergePlaybackProgress`](#mergeplaybackprogress) | function | A | Merge local, remote and base contents. |
| `mergePlaybackProgressJson` | function | B | Merge raw JSON for the sync engine; an unreadable base counts as absent. |

## mergePlaybackProgress

- **Algorithm:** an entry on both sides keeps the later `updatedAt` (a tie keeps local). An entry
  on one side only is kept when the base lacks it and dropped when the base had it: the other
  device finished or cleared that episode, so a completion beats a later partial update. Unknown
  top-level keys are unioned with local winning; the higher `version` is kept.
