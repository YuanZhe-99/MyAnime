# lib/features/anime/services/playback_progress_service.dart

`PlaybackProgressService` (1.6.5) applies the playback-progress rules. See
[`../../../../features/watch-url-lookup.md`](../../../../features/watch-url-lookup.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `PlaybackProgressService._` | constructor | B | Prevent instantiation. |
| `keyFor` | static method | B | Key for a numbered episode, or for an extra page when `episode` is null. |
| [`report`](#report) | static method | A | Record one playback position. |
| [`markWatched`](#markwatched) | static method | A | Mark one local episode watched. |
| `resumePoint` | static method | B | Return the stored entry for a key. |

## report

- **Algorithm:** `classifyPlayback`. `ignore` leaves the store untouched, so briefly reopening an
  episode near its start never erases where it stopped. `save` puts the entry with `updatedAt`
  now (UTC). `complete` removes the entry and, for a numbered episode, calls `markWatched`.
- **Returns:** the rule applied.

## markWatched

- **Side effects:** rewrites `anime_data.json` with `episodeStatuses[episode] = watched` and a fresh
  `modifiedAt`, the same write as the home page's watched toggle — this is a visible status change,
  unlike the cache writes that go through `patchExternalMeta`.
- **Notes:** no-op, returning false, when the record is gone or the episode is already watched.
