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
- `season` — a season identifier string, e.g. `"Season 1"`. Since 1.6.1 a default label
  (`Season 1` or empty) is replaced with `Season N` when a title names season N, without changing
  `modifiedAt` — see [`features/series-linking.md`](features/series-linking.md).

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

### `AnimeExternalMeta` and `AnimeExternalRating`

Optional per-anime record of **public metadata pulled from external anime databases** by the online
search (see [`features/multi-source-search.md`](features/multi-source-search.md)). Stored under the
`externalMeta` key:

```json
"externalMeta": {
  "synonyms": ["Frieren at the Funeral"],
  "titleRomaji": "Sousou no Frieren",
  "titleEn": "Frieren: Beyond Journey's End",
  "format": "TV",
  "status": "FINISHED",
  "durationMinutes": 24,
  "genres": ["Adventure", "Drama"],
  "studios": ["Madhouse"],
  "endDate": "2024-03-22T00:00:00.000Z",
  "ratings": [
    {
      "source": "AniList",
      "sourceUrl": "https://anilist.co/anime/154587",
      "score": 9.2,
      "scoreMax": 10.0,
      "votes": 300000,
      "rank": 1,
      "fetchedAt": "2026-08-26T12:00:00.000Z"
    }
  ],
  "refreshedAt": "2026-08-26T12:00:00.000Z"
}
```

- `synonyms` — alternate titles in any language, as reported by the sources.
- `titleRomaji` / `titleEn` — romanized and English titles. These do **not** replace `title` /
  `titleJa`; they are extra names, used for display, for the search dialog's "all titles" sheet, and
  as cross-language backfill queries.
- `format` — release format (`TV`, `MOVIE`, `OVA`, `ONA`, `SPECIAL`), stored as the source reports
  it. This is **not** `AnimeType`: `AnimeType` describes cour length and drives scheduling, while
  `format` is descriptive metadata only.
- `status` — broadcast status as the source reports it (`FINISHED`, `RELEASING`, `Finished Airing`,
  …). Deliberately unnormalized: viewing status stays derived from `episodeStatuses`, and this
  field never feeds it.
- `durationMinutes` — per-episode runtime.
- `genres`, `studios` — tags and animation studios.
- `endDate` — date the final episode aired, when known.
- `refreshedAt` — UTC timestamp of the last refresh.
- `watchProgress` — since 1.5.7, what the watch site (anime1.me) listed for `watchUrl` when last
  checked, as an `AnimeWatchProgress` object:

  ```json
  "watchProgress": {
    "sourceUrl": "https://anime1.me/?cat=1935",
    "catId": 1935,
    "latestEpisode": 9,
    "episodesText": "連載中(09)",
    "ongoing": true,
    "checkedAt": "2026-09-01T12:00:00.000Z"
  }
  ```

  `sourceUrl` is the `watchUrl` the record was read for; `Anime.validWatchProgress` returns the
  record only while they still match, so editing the URL hides a stale count. `latestEpisode` is
  `null` for films and specials, and `episodesText` keeps the site's cell verbatim (`1-12+OVA`).
  Unknown keys inside the object are preserved like everywhere else. It sits inside `externalMeta`
  because it is the same kind of data — a cache of public site information written through
  `AnimeStorage.patchExternalMeta`, never touching `modifiedAt`. See
  [`features/watch-url-lookup.md`](features/watch-url-lookup.md).
- `relations` — since 1.6.0, the related works the databases list, as `AnimeExternalRelation`
  entries:

  ```json
  "relations": [
    {
      "source": "AniList",
      "type": "sequel",
      "targetUrl": "https://anilist.co/anime/12345",
      "title": "葬送のフリーレン 第2期",
      "format": "TV"
    },
    {
      "source": "AniList",
      "type": "other",
      "targetUrl": "https://anilist.co/anime/67890",
      "title": "Crossover Short",
      "format": "ONA",
      "rawType": "CHARACTER"
    }
  ]
  ```

  `source` is the database's display name and `targetUrl` the related work's page there. `type` is
  normalised to `prequel`, `sequel`, `parent`, `sideStory`, `summary`, `spinOff`, `alternative` or
  `other`; when the source's own name maps to `other`, it is kept verbatim as `rawType`. `title` and
  `format` are what the source reports (Jikan and bangumi.tv give no format). Only anime targets are
  kept. A `type` this build does not recognise is preserved verbatim on write rather than
  downgraded to `other`, and unknown keys inside each entry survive as everywhere else. Written only
  by a refresh, through `AnimeStorage.patchExternalMeta`, never touching `modifiedAt`; search results
  never carry relations. The key is omitted when the list is empty. Series linking reads it — see
  [`features/series-linking.md`](features/series-linking.md).

**`ratings` is separate from `AnimeRating` on purpose.** `AnimeRating` holds the *user's own* scores
and is never written by a fetch; `externalMeta.ratings` holds each external database's score,
normalized onto a 10-point scale (`scoreMax`, default `10`). Every entry keeps the `sourceUrl` it
was read from, which is exactly what a later refresh re-queries — see the refresh flow in
[`features/multi-source-search.md`](features/multi-source-search.md). Entries are keyed by `source`:
refreshing one source replaces that source's entry and leaves the others alone.

`AnimeExternalMeta.mergedWith(other)` implements that fold. Scalar and list fields are taken from
`other` only when it actually supplies them, so refreshing against AniList — which reports no
studios for some titles — never erases the studios bangumi.tv contributed. `relations` are replaced
per source like `ratings`: a source that supplies any replaces its own earlier list, and the other
sources' lists are kept.

**The whole object is omitted when empty**, following the same rule as `AnimeLocalArchive`:
`hasAnyData` is false for an all-empty record, `Anime.toJson()` then writes no `externalMeta` key,
and `Anime.fromJson()` discards an all-empty parsed record. An anime that never had a search result
applied serializes exactly as it did before this field existed.

**Where it does and does not travel.** Unlike `AnimeLocalArchive`, this is public information about
the work rather than personal infrastructure, so it is **not** stripped from share files. Every part
of it — `ratings`, `watchProgress` and `relations` included — travels the same way:

| Surface | Included? |
|---|---|
| `anime_data.json` on disk | **Yes** |
| WebDAV sync | **Yes** — rides the ordinary whole-record merge, no sync-layer change |
| Backup bundles | **Yes** |
| Local HTTP API | **Yes** |
| Shared image cards | **No** — never drawn |
| `.myanimeitem` share files | **Yes** — public metadata, not personal data; import carries it through since 1.6.0 (earlier builds dropped it on import) |

### `AnimeLocalArchive`

Optional per-anime record of a **downloaded local copy** — whether one is kept, at what quality, in
how many copies, and where. Stored under the `localArchive` key:

```json
"localArchive": {
  "archived": true,
  "source": "bd",
  "resolution": "fhd1080p",
  "copies": 2,
  "location": "NAS-01, HDD-C3"
}
```

- `archived` — whether a local copy is kept. This is the "big switch"; everything else is detail.
- `source` — `ArchiveSource`: `bd`, `dvd`, `web`, `tv`, `other`. Displayed as `BD`/`DVD`/`WEB`/`TV`.
- `resolution` — `ArchiveResolution`: `uhd2160p`, `fhd1080p`, `hd720p`, `sd480p`, `other`.
  Displayed as `2160p`/`1080p`/`720p`/`480p`. Source and resolution are separate axes, so `BD`
  `1080p` and `WEB` `1080p` are distinguishable.
- `copies` — how many archived copies are kept (a positive integer).
- `location` — free-text repository code or physical location. Free text deliberately, so several
  codes can be listed in one field when the copies live in different places.

Both enums serialize by their Dart `.name`, matching `AnimeType` and `EpisodeStatus`. The enum
member names are storage identifiers, not display strings — `fhd1080p` is what lands on disk,
`1080p` is what the user sees.

**The whole object is omitted when empty.** `AnimeLocalArchive.hasAnyData` is
`archived || <any detail set> || extraJson.isNotEmpty`; `Anime.toJson()` writes a `localArchive` key
only when that is true, and `Anime.fromJson()` discards an all-empty parsed record. An anime that
never touched the feature therefore serializes byte-identically to how it did before the feature
existed — which is why adding it required no change to the WebDAV request goldens.

**Where it does and does not travel.** This is personal infrastructure information, so:

| Surface | Included? |
|---|---|
| `anime_data.json` on disk | **Yes** |
| WebDAV sync (the user's own devices) | **Yes** — no sync-layer change was needed; the field rides the ordinary whole-record merge |
| Backup bundles | **Yes** — backups carry `anime_data.json` verbatim |
| Local HTTP API (`/anime/list` etc.) | **Yes** — loopback-bound and Basic-Auth protected |
| Shared image cards | **No** — never drawn |
| `.myanimeitem` share files | **No** — stripped alongside `episodeStatuses`/`episodeWeekOffsets` |

See [`features/share-and-import.md`](features/share-and-import.md) for the sharing side of that
table.

### `AnimeSeriesLink`

Optional (1.6.0) record of the **series** the user placed an anime in — see
[`features/series-linking.md`](features/series-linking.md). Stored under the `seriesLink` key, in one
of two shapes:

```json
"seriesLink": {
  "seriesId": "0b5d0c1e-7f59-4f3e-9d5e-2a1c1b9e8f00",
  "order": 2
}
```

```json
"seriesLink": { "standalone": true }
```

- `seriesId` — a lowercase UUID v4 shared by every member of one curated series.
- `order` — optional positive integer: the member's position after the user reordered the series.
- `standalone` — written only when `true`: the user took the record out of every series. If a
  hand-edited file carries both `standalone` and `seriesId`, `standalone` wins and `seriesId` is
  preserved untouched.

Membership is a shared group id, not prev/next pointers, so no record ever references another
record's `id`: deleting, merging or importing a record cannot leave a dangling link. A record
without the key is an **auto** record that the app groups by itself; nothing about a derived series
is stored.

**The whole object is omitted when empty** (`hasAnyData`), as for `AnimeLocalArchive`, so a library
the user never curated serializes byte-identically to 1.5.7 and needs no migration. The object has
its own `extraJson`, which `withPreservedUnknownJson` deep-merges; unparseable values — a numeric
`seriesId`, a string `order` — are preserved verbatim and treated as absent.

**Where it does and does not travel.**

| Surface | Included? |
|---|---|
| `anime_data.json` on disk | **Yes** |
| WebDAV sync | **Yes**, verbatim — rides the ordinary whole-record merge, no sync-layer change |
| Backup bundles | **Yes**, verbatim |
| ZIP export and import | **Yes**, verbatim |
| Local HTTP API | **No** — unchanged; the API's own record projection does not include it |
| Shared image cards | **No** |
| `.myanimeitem` share files | **No** — stripped on export **and dropped on import**. A foreign `seriesId` means nothing in another library and would pin the imported record out of automatic grouping. This differs on purpose from `localArchive`, which import carries through. |

### `categories`

Since 1.6.0, the user's own classification (see
[`features/categories-and-recommendations.md`](features/categories-and-recommendations.md)): a JSON
list of category ids from the app's taxonomy.

```json
"categories": ["romance", "school"]
```

| Stored value | Meaning |
|---|---|
| key absent | Automatic: categories come from the genre mapping, else the on-device model |
| a non-empty list | The user's choice; it wins |
| `[]` | The user decided there are no categories; it wins too |

**This is the one exception to omit-when-empty.** `[]` is written, synced and backed up, because
dropping it would turn "none" back into automatic. Only an absent field (`null` in Dart) omits the
key. Ids this build does not know are kept and written back but not shown; a value that is not a
list of strings is preserved verbatim in `extraJson` and treated as absent. The field is not personal
data: it syncs through the ordinary whole-record merge, is included in backups and ZIP export, and
stays in `.myanimeitem` share files and survives their import. Classifications the model produced
are **not** stored here — they live in `ai_insights.json` (below).

### Compatibility: unknown-JSON-field preservation (`extraJson`)

`Anime`, `AnimeRating`, `AnimeLocalArchive`, `AnimeExternalMeta`, `AnimeExternalRating`, and
`AnimeData` (the top-level `{animes: [...]}` container) each carry an `extraJson` map holding any JSON keys the current app version doesn't
recognize. The pattern:

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
| Recommendation trash bins and related lists | `recommendations.json` | Yes | Since 1.6.2: the global trash, trashed missing-sequel cards, and each record's persisted Related list with its own trash; since 1.6.3 also pins and each missing sequel's synopsis and cover thumbnail; conflict-free set merge; created only when first needed |
| Cover images | `images/` | Yes | Referenced-only additive sync by filename |
| Theme mode | `storage_config.json` | No | Device-specific preference |
| Locale | `storage_config.json` | No | Device-specific preference |
| Calendar week start day | `storage_config.json` | No | Device-specific preference, default Sunday, ignored while Japanese home calendar layout is active |
| Home calendar layout | `storage_config.json` | No | Device-specific local-vs-Japanese calendar label preference |
| Home calendar time basis | `storage_config.json` | No | Device-specific JST-vs-local date grid preference; anime schedule timestamps remain JST-based |
| Home calendar view format | `storage_config.json` | No | Device-specific last-used calendar view (`homeCalendarFormat`: `twoWeeks` or `week`; absent means the default full month) |
| List column count, per module | `storage_config.json` | No | Device-specific column preference for the home, management and statistics lists (`homeListColumns` / `manageListColumns` / `statsListColumns`: 1–4; absent means auto, i.e. fill whatever the width allows) |
| Manage view mode and series sort | `storage_config.json` | No | Device-specific (1.6.2): `manageViewMode` (`series`; absent means the quarter view) and `manageSeriesSort` (`title` or `modified`; absent means newest premiere first) |
| Storage path override | `storage_config.json` | No | Device-specific path |
| Auto-backup enabled | `storage_config.json` | No | Device-specific config |
| Backup retention days | `storage_config.json` | No | Device-specific config |
| Reminder enabled/time/last reminder date | `storage_config.json` | No | Device-specific local-time reminder config and internal state |
| API server enabled/listen address/port/credentials | `storage_config.json` | No | Local desktop config; credentials must not be committed |
| Tray and launch-at-startup preferences | `storage_config.json` | No | Local desktop config |
| Kana tab shown | `storage_config.json` | No | Device-specific `kanaTabEnabled`; absent means hidden (1.6.0) |
| On-device AI switch and model-size preference | `storage_config.json` | No | Device-specific `onDeviceAiEnabled` and `onDeviceAiPreferFast` (Android); absent means off (1.6.0) |
| Automatic categories | `storage_config.json` | No | Device-specific `autoCategoriesEnabled`; absent means off (1.6.0) |
| Recommendations | `storage_config.json` | No | Device-specific `recommendationsEnabled`; absent means off (1.6.0) |
| WebDAV configuration | `webdav_config.json` | No | Local secret/config only |
| Sync base snapshots | `.sync_base/anime_data.json`, `.sync_base/recommendations.json` | No | Local merge tracking, one per module |
| Local backups | `backups/backup_*.json` | No | Local recovery; v2 bundles reference deduplicated image blobs |
| Backup image blobs | `backups/blobs/` | No | Content-addressed (`sha256`), shared across backups, reference-counted GC |
| Background update queue | `metadata_updates.json` | No | Per-device attempt/backoff state plus downloaded update candidates; rebuildable cache |
| Prefetched candidate covers | `metadata_covers/` | No | Only when cover prefetch is enabled; pruned when its proposal is resolved |
| Background update policy | `storage_config.json` | No | Device-specific `metadataAutoUpdate` (`off`/`noCellular`/`always`; absent means `noCellular` on mobile, `always` on desktop) and `metadataPrefetchCovers` |
| On-device AI results | `ai_insights.json` | No | Per-device cache of AI category classifications (1.6.0); not backed up; rebuildable; pruned of deleted records on load. Its `hiddenRecommendations` list was the per-device *Not interested* list in 1.6.0–1.6.1 and is migrated to `recommendations.json`, then left empty, since 1.6.2 |

`metadata_updates.json` and `metadata_covers/` are neither synced nor backed up, and that needs no
special handling: the sync and backup engines only touch the file names registered in
`ModuleRegistry` plus `images/`, and neither is registered in `lib/app/data_modules.dart`. Both do
live under `AnimeStorage.getAppDir()`, so a storage-path change carries them along. See
[`features/metadata-auto-update.md`](features/metadata-auto-update.md).

`ai_insights.json` (1.6.0) follows the same mechanism: it is not registered either, so it is neither
synced nor backed up, and it moves with the storage path. Its schema is in
[`features/categories-and-recommendations.md`](features/categories-and-recommendations.md).

`recommendations.json` (1.6.2) is the opposite case: it **is** registered, as the second module
after `anime_data.json`, so it syncs, is backed up, is included in ZIP export, and has its own
`.sync_base/recommendations.json`. Its schema, and why its merge never produces a conflict, are in
[`features/categories-and-recommendations.md`](features/categories-and-recommendations.md#the-file-recommendationsjson)
and [`sync.md`](sync.md#the-recommendations-file). It refers to library records by id only; the
only titles it stores are the database titles of trashed sequels, plus any generated reasons. Since
1.6.3 it also holds pins and, per missing sequel still shown, the database's synopsis (at most 600
characters) and a base64 JPEG cover thumbnail (112 px wide, at most 24 KB) — public data about the
work, deleted when the card is trashed. The thumbnail is deliberately **not** a file in `images/`,
whose sync never deletes. It is not part of `.myanimeitem` share files.

### `storage_config.json`

Holds every device-local preference from the table above that isn't WebDAV configuration: theme
mode, locale, calendar week-start/layout/time-basis/view-format preferences, storage path override,
auto-backup enabled + retention days (`backupRetentionDays`), reminder settings, API server
enabled/listen address/port/credentials, tray/launch-at-startup preferences, and the background
metadata-update settings (`metadataAutoUpdate`, `metadataPrefetchCovers`), the per-module list
column counts (`homeListColumns`, `manageListColumns`, `statsListColumns`), whether the Kana
tab is shown (`kanaTabEnabled`, written only when on), and the on-device AI switch and "Prefer the
faster model" preference (`onDeviceAiEnabled`, `onDeviceAiPreferFast`, each written only when on;
see [`on-device-ai.md`](on-device-ai.md)), and whether automatic categories are on
(`autoCategoriesEnabled`, written only when on), and whether recommendations are on
(`recommendationsEnabled`, written only when on), and since 1.6.2 the Manage tab's view and
series sort (`manageViewMode`, `manageSeriesSort`, each written only when not the default). None of this file is
synced — it is intentionally device-specific, which is the right home for a network policy that
should differ between a desktop on Ethernet and a phone on a data plan.

### `webdav_config.json`

WebDAV connection details and sync preferences (server URL, credentials, auto-sync toggle). Never
synced itself — it's the configuration that drives sync, not data sync would touch. See
[`sync.md`](sync.md).

### `.sync_base/`

Holds `.sync_base/anime_data.json`, the last-known-merged snapshot used as the three-way merge
base on the next sync — and since 1.6.2 `.sync_base/recommendations.json`, the same for the
recommendations module — and `.sync_base/upload_lock.json`, which lets the next launch detect an
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

Export strips personal data (`episodeStatuses`, `episodeWeekOffsets`, `localArchive`, and since
1.6.0 `seriesLink`) from each `anime` payload before writing. Import always assigns a new UUID and
never overwrites an existing local record; it drops any `seriesLink` a file carries, and since 1.6.0
it carries `externalMeta` through (earlier builds dropped it on import although export kept it);
`categories` is neither stripped on export nor dropped on import (1.6.0); multi-anime bundle imports run the same conflict detection as
[`features/duplicate-detection.md`](features/duplicate-detection.md) to decide whether an
incoming record collides with a local one, offering keep-local/use-imported/merge per conflict.
