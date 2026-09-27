# lib/features/anime/models/playback_progress.dart

The contents of `playback_progress.json` (1.6.5): one resume point per episode played in the app,
keyed `<animeId>/<localEpisode>` for numbered episodes and `<animeId>/extra/<pageUrl>` for extra
pages. Every class keeps unknown JSON keys in `extraJson`. The file is its own synced module — see
[`../../../app/data_modules.md`](../../../app/data_modules.md) and
[`../../../../data-formats.md`](../../../../data-formats.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `playbackProgressKey` | function | B | Build the key for a numbered local episode. |
| `playbackProgressExtraKey` | function | B | Build the key for an extra page without a local number. |
| [`classifyPlayback`](#classifyplayback) | function | A | Classify a position against the 5% / 95% thresholds. |
| `_unknown` | function | B | Collect JSON keys this build does not know. |
| `PlaybackProgressEntry` | constructor | B | Create one resume point; `updatedAt` normalized to UTC. |
| [`PlaybackProgressEntry.fromJson`](#playbackprogressentryfromjson) | static method | A | Read one entry tolerantly. |
| `PlaybackProgressEntry.toJson` | method | B | Serialize one entry; null fields omitted. |
| `PlaybackProgressEntry.position` | getter | B | The position as a `Duration`. |
| `PlaybackProgressEntry.duration` | getter | B | The duration as a `Duration`. |
| `PlaybackProgressEntry.fraction` | getter | B | How far through the episode, clamped to 0–1. |
| `PlaybackProgressEntry.newerOf` | method | B | Pick the later of two records of one key; a tie keeps local. |
| `PlaybackProgressData` | constructor | B | Create the store contents. |
| [`PlaybackProgressData.fromJson`](#playbackprogressdatafromjson) | factory | A | Read the file tolerantly; reject a non-object. |
| `PlaybackProgressData.toJson` | method | B | Serialize with entries sorted by key. |
| `PlaybackProgressData.latestFor` | method | B | Most recently updated entry of one record. |

`playbackMinFraction` (0.05), `playbackDoneFraction` (0.95) and the `PlaybackProgressRule` enum
(`ignore`, `save`, `complete`) carry no `/// Purpose:` comment.

## classifyPlayback

- **Returns:** `ignore` when the duration is unknown (zero or negative) or the position is under
  5%; `complete` when it is strictly past 95%; otherwise `save`. Exactly 5% and exactly 95% save.
- **Usage:** the single rule both the player page and `PlaybackProgressService.report` apply.

## PlaybackProgressEntry.fromJson

- **Returns:** null unless `positionMs` and `durationMs` are ints, `durationMs` is positive and
  `updatedAt` parses. A negative position reads as 0. `animeId` falls back to the part of the key
  before its first `/`.

## PlaybackProgressData.fromJson

- **Notes:** throws `FormatException` when the input is not a JSON object, which is what the sync
  module's `validate` relies on; malformed entries inside are dropped. A newer `version` is kept.
