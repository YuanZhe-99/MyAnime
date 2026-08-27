# lib/features/anime/services/metadata_cache.dart

`MetadataCache` owns `metadata_updates.json` — the device-local record of background metadata work
and the update candidates already downloaded — plus the optional `metadata_covers/` prefetch
directory.

It is the only file that reads or writes either. See
[`../models/metadata_update.md`](../models/metadata_update.md) for the document shape and
[`../../../../features/metadata-auto-update.md`](../../../../features/metadata-auto-update.md) for
the feature.

## Why this file is not synced

The sync and backup engines iterate `ModuleRegistry` and only ever touch the file names it lists
plus `images/`. `metadata_updates.json` is deliberately **not** registered in
[`../../../app/data_modules.md`](../../../app/data_modules.md), which is the whole mechanism — no
exclusion list, no special case. It still lives under `AnimeStorage.getAppDir()`, so
`setStoragePath` carries it along with everything else in the folder.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `MetadataCache._` | constructor | B | Prevent instantiation. |
| `_file` | method | B | Resolve the cache file inside the active storage directory. |
| [`_atomicWrite`](#_atomicwrite) | method | A | Write via tmp-then-rename. |
| [`load`](#load) | method | A | Load the cache, degrading to empty on any failure. |
| [`save`](#save) | method | A | Persist the cache. |
| `_coverDir` | method | B | Resolve the prefetch directory, creating it on demand. |
| [`prefetchCover`](#prefetchcover) | method | A | Download a candidate's cover ahead of time. |
| [`deleteCover`](#deletecover) | method | A | Delete one prefetched cover. |
| [`pruneCovers`](#prunecovers) | method | A | Delete prefetched covers nothing references. |

## Documentation

### `static Future<void> _atomicWrite(File, String)` <a id="_atomicwrite"></a>
- **Kind:** static method of `MetadataCache`
- **Purpose:** Write a file through a temporary file and a rename.
- **Side effects:** Writes `<path>.tmp`, then renames it over the target.
- **Notes:** Mirrors `AnimeStorage._atomicWrite`. The cache is rebuildable, so corruption is not a
  data-loss risk — but a truncated file would still cost a full re-scan of the library over the
  network, which is worth one rename to avoid.

### `static Future<MetadataUpdateStore> load()` <a id="load"></a>
- **Kind:** static method of `MetadataCache`
- **Returns:** `Future<MetadataUpdateStore>` — an empty store when the file is absent, blank, or
  unreadable.
- **Notes:** A parse failure yields an empty store rather than throwing. Losing this file costs
  network work, never user data, so degrading quietly beats blocking startup on it.

### `static Future<void> save(MetadataUpdateStore)` <a id="save"></a>
- **Kind:** static method of `MetadataCache`
- **Side effects:** Writes the cache file atomically.
- **Notes:** Pretty-printed via `JsonEncoder.withIndent('  ')` like every other file this app
  writes. Deliberately does **not** call `AutoSyncService.notifySaved()` — this file never syncs, so
  scheduling an upload for it would be pure churn against the 30-second save debounce.

### `static Future<String?> prefetchCover(String, String)` <a id="prefetchcover"></a>
- **Kind:** static method of `MetadataCache`
- **Inputs:** `animeId`, `url`.
- **Returns:** `Future<String?>` — the path relative to the app directory, or `null` on failure.
- **Side effects:** One HTTP GET (20 s timeout) and one file write.
- **Notes:** Only called when the user enabled cover prefetch, which is **off by default**: covers
  are the only large data in this cache. Failure is silent because the review screen falls back to
  streaming the source URL, so a failed prefetch costs nothing visible.

### `static Future<void> deleteCover(String?)` <a id="deletecover"></a>
- **Kind:** static method of `MetadataCache`
- **Notes:** Called once a proposal is applied or dismissed, so the prefetch directory cannot grow
  without bound. A missing file is not an error.

### `static Future<void> pruneCovers(MetadataUpdateStore)` <a id="prunecovers"></a>
- **Kind:** static method of `MetadataCache`
- **Side effects:** Deletes every file in `metadata_covers/` that no entry references.
- **Notes:** Paired with `MetadataUpdateStore.prunedTo` so covers belonging to deleted anime go too.
  Opportunistic — any failure is swallowed and retried on the next prune.
