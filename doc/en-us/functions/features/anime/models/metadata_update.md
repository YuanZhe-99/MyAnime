# lib/features/anime/models/metadata_update.dart

Pure model code for the background metadata updater: the device-local cache document
(`metadata_updates.json`), the network policy stored in `storage_config.json`, and the pure diff and
apply helpers shared by the background service and the review screen.

Nothing here touches Flutter, the network, or the disk — which is what makes the decisions that
matter (what counts as a mismatch, what may be proposed, what may be overwritten) directly unit
testable. See [`../../../../features/metadata-auto-update.md`](../../../../features/metadata-auto-update.md)
for the behavior and [`../services/metadata_update_service.md`](../services/metadata_update_service.md)
for the service that drives it.

This data is deliberately **not** synced and **not** backed up: it is per-device bookkeeping plus a
rebuildable download cache. See [`../../../../data-formats.md`](../../../../data-formats.md).

## Types

| Type | Kind | Purpose |
|---|---|---|
| `MetadataUpdatePolicy` | enum | When background work may use the network: `off`, `noCellular`, `always`. |
| `MetadataUpdateStatus` | enum | Where an anime stands: `proposed`, `needsManualPick`, `dismissed`, `noMatch`, `upToDate`. |
| `MetadataField` | enum | The core `Anime` fields the pipeline may propose changing. |
| `MetadataFieldChange` | class | One field's current and proposed values, for display. |
| `MetadataUpdateEntry` | class | One anime's cache entry: status, candidate, attempt/backoff state. |
| `MetadataUpdateStore` | class | The whole `metadata_updates.json` document. |
| `MetadataScanPhase` | enum | Where a user-triggered scan stands: `idle`, `scanning`, `done`, `cancelled`. |
| `MetadataScanProgress` | class | Immutable snapshot of a manual scan, published through a `ValueNotifier`. |

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`parseMetadataUpdatePolicy`](#parsemetadataupdatepolicy) | function | A | Parse the persisted network policy, falling back rather than throwing. |
| `MetadataFieldChange` | constructor | B | Create a field change record. |
| `MetadataUpdateEntry` | constructor | B | Create a cache entry. |
| [`MetadataUpdateEntry.isPending`](#ispending) | getter | A | Whether this entry is waiting on the user. |
| [`MetadataUpdateEntry.isDue`](#isdue) | method | A | Whether the backoff gate currently allows another attempt. |
| [`MetadataUpdateEntry.copyWith`](#entrycopywith) | method | A | Create a modified copy, with explicit clear flags. |
| `MetadataUpdateEntry.toJson` | method | B | Serialize, unknown fields first. |
| [`MetadataUpdateEntry.fromJson`](#entryfromjson) | static method | A | Parse defensively, preserving unparseable values. |
| `MetadataUpdateStore` | constructor | B | Create a store. |
| `MetadataUpdateStore.entryFor` | method | B | Look up one anime's entry. |
| `MetadataUpdateStore.withEntry` | method | B | Replace or insert one entry. |
| [`MetadataUpdateStore.prunedTo`](#prunedto) | method | A | Drop entries whose anime no longer exists. |
| `MetadataUpdateStore.toJson` | method | B | Serialize the document. |
| [`MetadataUpdateStore.fromJson`](#storefromjson) | factory | A | Parse, skipping malformed entries individually. |
| [`hasEpisodeCountMismatch`](#hasepisodecountmismatch) | function | A | Whether an episode count genuinely disagrees with a source. |
| [`needsMetadataDiscovery`](#needsmetadatadiscovery) | function | A | Whether a record is incomplete enough to search for. |
| [`diffCandidate`](#diffcandidate) | function | A | Work out which core fields a candidate would change. |
| [`applyMetadataChanges`](#applymetadatachanges) | function | A | Write the accepted fields onto an anime record. |
| `MetadataScanProgress` | constructor | B | Create a scan progress snapshot. |
| [`MetadataScanProgress.fraction`](#scanfraction) | getter | A | Completed fraction, or `null` when there is nothing to measure. |
| `MetadataScanProgress.isRunning` | getter | B | Whether a scan is in flight. |

## Documentation

### `MetadataUpdatePolicy parseMetadataUpdatePolicy(String?, MetadataUpdatePolicy)` <a id="parsemetadataupdatepolicy"></a>
- **Kind:** top-level function
- **Purpose:** Turn the raw `metadataAutoUpdate` string from `storage_config.json` into a policy.
- **Inputs:** `value` — the stored string, possibly `null`; `fallback` — the platform default.
- **Returns:** `MetadataUpdatePolicy`.
- **Side effects:** None.
- **Notes:** An unknown string falls back rather than throwing, so a config written by a newer build
  never breaks an older one. The caller supplies the fallback because it is platform-dependent:
  `noCellular` on Android and iOS, `always` on desktop.

### `bool get isPending` <a id="ispending"></a>
- **Kind:** getter on `MetadataUpdateEntry`
- **Purpose:** Report whether this entry is waiting for a user decision.
- **Returns:** `bool` — true for `proposed` and `needsManualPick`.
- **Notes:** Drives the management page's badge count. `needsManualPick` counts because the user
  still has something to do, even though a batch action will skip it.

### `bool isDue(DateTime now)` <a id="isdue"></a>
- **Kind:** method on `MetadataUpdateEntry`
- **Purpose:** Report whether the backoff gate currently allows another attempt.
- **Inputs:** `now`, in UTC.
- **Returns:** `bool`.
- **Notes:** An entry that has never been attempted (`nextAttemptAt == null`) is always due.

### `MetadataUpdateEntry copyWith({...})` <a id="entrycopywith"></a>
- **Kind:** method on `MetadataUpdateEntry`
- **Purpose:** Produce a modified copy.
- **Inputs:** Each field, plus `clearCandidate`, `clearNextAttemptAt`, and `clearCoverCachePath`.
- **Returns:** `MetadataUpdateEntry`.
- **Notes:** The explicit clear flags exist because a `null` argument means "leave unchanged". A
  resolved proposal has to actively drop its candidate, and a successful attempt has to actively
  drop its backoff deadline; neither is expressible by passing `null`.

### `static MetadataUpdateEntry? fromJson(Map<String, dynamic>)` <a id="entryfromjson"></a>
- **Kind:** static method on `MetadataUpdateEntry`
- **Purpose:** Parse one entry.
- **Returns:** `MetadataUpdateEntry?` — `null` when there is no usable `animeId`, since an entry
  that cannot be keyed to an anime is unusable.
- **Notes:** Follows the `AnimeLocalArchive.fromJson` pattern: a value that fails to parse is kept
  verbatim in `extraJson` rather than dropped, so a newer build's data survives an older build
  rewriting the file. An unrecognized `status` yields `upToDate` *and* stashes the raw value.

### `MetadataUpdateStore prunedTo(Set<String>)` <a id="prunedto"></a>
- **Kind:** method on `MetadataUpdateStore`
- **Purpose:** Drop entries whose anime no longer exists.
- **Inputs:** `liveIds` — every id currently in `anime_data.json`.
- **Notes:** Without this the cache would grow forever as anime are deleted. The service pairs it
  with `MetadataCache.pruneCovers` so orphaned prefetched covers go too.

### `factory MetadataUpdateStore.fromJson(Map<String, dynamic>)` <a id="storefromjson"></a>
- **Kind:** factory constructor
- **Purpose:** Parse the whole document.
- **Notes:** Malformed entries are skipped **individually** rather than failing the file. This is a
  rebuildable cache, so partial recovery beats discarding everything and re-fetching a whole
  library over the network.

### `bool hasEpisodeCountMismatch(Anime, AnimeSearchResult)` <a id="hasepisodecountmismatch"></a>
- **Kind:** top-level function
- **Purpose:** Report whether an anime's episode count genuinely disagrees with a source.
- **Returns:** `bool`.
- **Algorithm:**
  1. Return false when the source reports no positive episode count.
  2. **Return false when `startEpisode != 1`.**
  3. Return false when `totalEpisodes` is null (open-ended).
  4. Otherwise compare `totalEpisodes` with the source's count.
- **Notes:** Step 2 is the important one. Tracking the second cour of a 24-episode show as
  `startEpisode: 13, endEpisode: 24` gives `totalEpisodes == 12` while the source reports 24 — and
  that is the *correct* way to record it. Without the guard, this feature would raise false alarms
  on exactly the records a user curated most carefully. Step 3 routes open-ended records to the
  "missing field" path instead, which proposes a value rather than reporting a conflict.

### `bool needsMetadataDiscovery(Anime)` <a id="needsmetadatadiscovery"></a>
- **Kind:** top-level function
- **Purpose:** Report whether a record is incomplete enough to be worth a full multi-source search.
- **Notes:** A record with neither an `infoUrl` nor any `externalMeta` always qualifies, because
  there is nothing to refresh *from*. Otherwise it qualifies when a first air date, broadcast
  weekday, end episode, or cover is missing.

### `List<MetadataFieldChange> diffCandidate(Anime, AnimeSearchResult)` <a id="diffcandidate"></a>
- **Kind:** top-level function
- **Purpose:** Work out which core fields a candidate would change.
- **Returns:** `List<MetadataFieldChange>` — empty when nothing would change.
- **Notes:** **Never proposes overwriting a non-empty user value**, with exactly one deliberate
  exception: `endEpisode` when `hasEpisodeCountMismatch` says the counts genuinely disagree. That
  rule is what makes a batch "update all" defensible — it can only fill blanks and correct a
  demonstrable mismatch.

  Recomputed on demand rather than persisted, so it always reflects the record's current state. A
  proposal whose changes the user has since made by hand simply produces an empty diff and drops
  out of the review list.

### `Anime applyMetadataChanges(Anime, {...})` <a id="applymetadatachanges"></a>
- **Kind:** top-level function
- **Purpose:** Write the accepted fields onto an anime record.
- **Inputs:** `changes`, `selected` — the fields the user accepted; `coverImagePath` — the
  already-downloaded relative path, when the cover was accepted.
- **Returns:** `Anime`.
- **Notes:** Restores the original `modifiedAt` before returning, so the **caller** decides whether
  this counts as a user edit. That restoration is required, not cosmetic: `Anime.copyWith` stamps
  `modifiedAt` with the current time whenever the argument is omitted, so every `copyWith` in the
  loop would otherwise bump it. See
  [`../../../../sync.md`](../../../../sync.md) for why that distinction matters.

  The cover field is special: its proposed value is a remote URL, so the caller downloads it first
  and passes the resulting `images/...` path back in.

### `double? MetadataScanProgress.fraction` <a id="scanfraction"></a>
- **Kind:** getter
- **Purpose:** Report how far a user-triggered scan has got.
- **Inputs:** None.
- **Returns:** `double?` in 0..1, or `null` when `total` is zero.
- **Side effects:** None.
- **Notes:** Deliberately mirrors `SyncProgress.fraction` in `myapps_data`, so both progress UIs
  bind the same way and a `null` means "show no determinate bar" rather than "show an empty one".

  A `total` of zero is a real outcome, not a failure: everything that could be checked was checked
  recently enough that asking again would change nothing. The review screen turns that into
  "everything is already up to date" instead of a bar that never moves.

  The denominator is fixed when the scan starts — the queue is a snapshot — so the bar only ever
  moves forwards.
