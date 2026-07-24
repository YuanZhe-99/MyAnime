# Data Formats

This page describes the `Anime` data model (`lib/features/anime/models/anime.dart`), the
forward-compatibility pattern used everywhere unknown JSON is encountered, and the full inventory
of files the app persists to disk. For how these records get merged across devices, see
[`sync.md`](sync.md) and [`algorithms/three-way-merge.md`](algorithms/three-way-merge.md). For the
quarter-placement logic built on top of these fields, see
[`features/anime-tracking.md`](features/anime-tracking.md).

## The `Anime` model

### Identity

- `id` — a UUID, stable across edits, sync, and merges.
- `title` — main display title (Chinese/English). If null, `titleJa` is used instead.
- `titleJa` — optional Japanese title. At least one of `title`/`titleJa` must be set.
- `season` — a season identifier string, e.g. `"Season 1"`.

### URLs

- `infoUrl` — source/reference page (also where search results save their source URL).
- `watchUrl` — streaming/watch page.

### Schedule

- `airDayOfWeek` — day of week the anime airs, Japan time, encoded as **Monday = 1 .. Sunday = 7**.
  Null when `effectiveType` is `allAtOnce`.
- `airTime` — air time in Japan time as a string, e.g. `"21:00"`. Late-night broadcast slots use
  values past midnight such as `"25:00"` (meaning 01:00 the following calendar day) — this is a
  real convention in Japanese TV scheduling, and the model's `getEpisodeAirDate()` explicitly
  supports parsing hour values ≥ 24 by adding the duration to midnight of the scheduled broadcast
  date.
- `firstAirDate` — optional first-episode date.

When `airDayOfWeek` disagrees with the weekday of `firstAirDate`, episode dates snap forward to
the next occurrence of the air day, so episode 1 never lands before `firstAirDate`. Both
`getEpisodeAirDate()` (JST timestamp, with late-night rollover applied) and
`getEpisodeCalendarDate()` (JST calendar date, no rollover — stays on the scheduled broadcast date
even for `24:00`/`25:00` times) implement this same forward-snap.

### Episodes

- `startEpisode` — first episode number, default 1.
- `endEpisode` — last episode number; `null` means long-running/unknown end. `totalEpisodes` is
  derived as `endEpisode! - startEpisode + 1` when `endEpisode` is set, else `null`.
- `episodeStatuses` — a per-episode status map (key = episode number) of `EpisodeStatus`
  (`unwatched`, `watched`, `skippedThisWeek`).
- `episodeWeekOffsets` — cumulative week adjustments for batch premieres, delays, and schedule
  corrections. `weekOffsetFor(episodeNumber)` sums every offset entry whose key is `<=` the
  requested episode number, and that cumulative offset feeds directly into both episode-date
  getters and into quarter placement (see
  [`features/anime-tracking.md`](features/anime-tracking.md)).

### Status derivation

Viewing status (`AnimeViewingStatus`: `completed`, `watching`, `dropped`, `notStarted`) is
**derived from `episodeStatuses`**, not stored as a separate field. There is no persisted "status"
value to fall out of sync with the episode data.

### `AnimeType`

```dart
enum AnimeType {
  singleCour,   // ≤13 episodes
  halfYear,     // 14–26 episodes
  fullYear,     // 27–52 episodes
  longRunning,  // no end episode set, ongoing
  allAtOnce,    // all episodes released at once (Netflix style)
}
```

- `autoType` infers the type purely from episode count via the thresholds above.
- `manualType` is an optional override that, when set, **always takes precedence**: `effectiveType`
  returns `manualType` if present, otherwise falls back to `autoType`.

### `AnimeRating`

Optional per-anime rating with a manual overall score plus five sub-scores, all on a 0–10 scale:

- `overall` — manual overall score.
- `visual`, `story`, `character`, `music`, `enjoyment` — sub-scores (visual/direction, story,
  character, music/sound, enjoyment/recommendation).

`effectiveOverall` returns `overall` when set; otherwise it averages whichever sub-scores are
non-null (`scores.fold(...) / scores.length`), returning `null` only when every sub-score is also
null. In short: **manual overall wins; if empty, the effective overall is the average of filled
sub-scores.**

### Compatibility: unknown-JSON-field preservation (`extraJson`)

`Anime`, `AnimeRating`, and `AnimeData` (the top-level `{animes: [...]}` container) each carry an
`extraJson` map holding any JSON keys the current app version doesn't recognize. The pattern:

- `fromJson()` computes `extraJson` as "every key in the raw JSON minus the known keys for this
  type" (via an internal `_unknownJson` helper), and also routes any value that fails to parse as
  its expected type (e.g. a rating sub-score that isn't a `num`) back into `extraJson` instead of
  discarding it.
- `toJson()` starts from a copy of `extraJson` and then overlays the known fields on top, so
  unknown keys ride along unchanged.
- `withPreservedUnknownJson(sources)` merges `extraJson` from multiple candidate sources (e.g. the
  local and remote copy of the same record during a sync merge) so a field unknown to *this*
  version of the app, but present on either side, survives the merge.

This is what lets an older app version avoid silently deleting a field introduced by a newer
version during ordinary saves, imports, or sync merges — see the merge engine in
[`algorithms/three-way-merge.md`](algorithms/three-way-merge.md) for how `extraJson` participates
in per-record sync merges specifically.

### Timestamps

`modifiedAt` is a `DateTime`, always stored and compared in **UTC** (`DateTime.now().toUtc()`).
Local-time `modifiedAt` values would break sync conflict detection, since the three-way merge
algorithm compares `modifiedAt` timestamps from devices that may be in different timezones — see
[`sync.md`](sync.md).

### JSON pretty-printing

All JSON written to disk — data files, sync uploads, backups — uses
`JsonEncoder.withIndent('  ')`. This is not just cosmetic: sync writes merged JSON with the same
formatting as local `AnimeStorage` saves, so an unchanged file hits a raw string-equality fast path
on the next sync instead of triggering a spurious re-upload.

## Persisted Data Inventory

The default app data directory is `Documents/MyAnime` on desktop, or the platform app documents
directory on mobile. Custom storage paths are stored in `storage_config.json`; changing the path
migrates data files, backups, and images.

| Data | File | Synced | Notes |
| --- | --- | --- | --- |
| Anime records | `anime_data.json` | Yes | Per-record by `id` and `modifiedAt`; unknown fields preserved |
| Cover images | `images/` | Yes | Referenced-only additive sync by filename |
| Theme mode | `storage_config.json` | No | Device-specific preference |
| Locale | `storage_config.json` | No | Device-specific preference |
| Calendar week start day | `storage_config.json` | No | Device-specific preference, default Sunday, ignored while Japanese home calendar layout is active |
| Home calendar layout | `storage_config.json` | No | Device-specific local-vs-Japanese calendar label preference |
| Home calendar time basis | `storage_config.json` | No | Device-specific JST-vs-local date grid preference; anime schedule timestamps remain JST-based |
| Storage path override | `storage_config.json` | No | Device-specific path |
| Auto-backup enabled | `storage_config.json` | No | Device-specific config |
| Backup retention days | `storage_config.json` | No | Device-specific config |
| Reminder enabled/time/last reminder date | `storage_config.json` | No | Device-specific local-time reminder config and internal state |
| API server enabled/listen address/port/credentials | `storage_config.json` | No | Local desktop config; credentials must not be committed |
| Tray and launch-at-startup preferences | `storage_config.json` | No | Local desktop config |
| WebDAV configuration | `webdav_config.json` | No | Local secret/config only |
| Sync base snapshot | `.sync_base/anime_data.json` | No | Local merge tracking |
| Local backups | `backups/backup_*.json` | No | Local recovery; v2 bundles reference deduplicated image blobs |
| Backup image blobs | `backups/blobs/` | No | Content-addressed (`sha256`), shared across backups, reference-counted GC |

### `storage_config.json`

Holds every device-local preference from the table above that isn't WebDAV configuration: theme
mode, locale, calendar week-start/layout/time-basis preferences, storage path override,
auto-backup enabled + retention days (`backupRetentionDays`), reminder settings, API server
enabled/listen address/port/credentials, and tray/launch-at-startup preferences. None of this file
is synced — it is intentionally device-specific.

### `webdav_config.json`

WebDAV connection details and sync preferences (server URL, credentials, auto-sync toggle). Never
synced itself — it's the configuration that drives sync, not data sync would touch. See
[`sync.md`](sync.md).

### `.sync_base/`

Holds `.sync_base/anime_data.json`, the last-known-merged snapshot used as the three-way merge
base on the next sync, and `.sync_base/upload_lock.json`, which lets the next launch detect an
upload that was interrupted mid-flight. See [`sync.md`](sync.md) for how both are used.

### `backups/`

- `backups/backup_*.json` — backup bundles (format v2 described in
  [`backup-restore.md`](backup-restore.md)).
- `backups/blobs/<sha256><ext>` — content-addressed image blobs referenced by bundles via an
  `_imageRefs` map.

### `.myanimeitem` (share/file-import format)

JSON file used for exporting/importing individual or multiple anime (see
[`features/share-and-import.md`](features/share-and-import.md) for the surrounding UI flow).

- **Version 1** (single anime): `{"version": 1, "anime": {...}, "coverImage": "<base64>",
  "coverImageExt": ".jpg"}` — `coverImage`/`coverImageExt` are optional.
- **Version 2** (multi-anime bundle): `{"version": 2, "items": [{"anime": {...}, "coverImage":
  "<base64>", "coverImageExt": ".jpg"}, ...]}` — each item has the same optional cover fields as
  v1.

Export strips personal viewing data (`episodeStatuses`, `episodeWeekOffsets`) from each `anime`
payload before writing. Import always assigns a new UUID and never overwrites an existing local
record; multi-anime bundle imports run the same conflict detection as
[`features/duplicate-detection.md`](features/duplicate-detection.md) to decide whether an
incoming record collides with a local one, offering keep-local/use-imported/merge per conflict.
