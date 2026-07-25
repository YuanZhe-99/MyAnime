# lib/app/data_modules.dart

**The seam between this app and the shared `myapps_data` package**, and the single source of truth
for MyAnime's data files. Every hardcoded `anime_data.json` list and backup-module map the app used
to carry now reads from the registry declared here.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`AnimeStorageAdapter`](#animestorageadapter) | class | A | Implements the package's `StorageAdapter` over `AnimeStorage`. |
| [`animeDataFileName`](#constants) | constant | A | `'anime_data.json'` — the local and remote file name. |
| [`animeModuleId`](#constants) | constant | A | `'anime'` — the backup bundle module key. |
| [`animeDefaultRemotePath`](#constants) | constant | A | `'/MyAnime'`. |
| [`animeArchiveNamePrefix`](#constants) | constant | A | `'myanime_export_'`. |
| [`validateAnimeJson(json)`](#validateanimejson) | function | A | Throw unless the payload parses as anime data. |
| [`encodeAnimeData(data)`](#encodeanimedata) | function | A | Pretty-print merged data the way the hub writes it. |
| [`animeReferencedImages(json)`](#animereferencedimages) | function | A | Cover-image basenames referenced by records. |
| [`mergeAnimeModule({...})`](#mergeanimemodule) | function | A | Adapt `mergeAnimeData` to the engine's merge contract. |
| [`buildAnimeModule()`](#buildanimemodule) | function | A | Build the single `DataModule`. |
| [`animeModuleRegistry`](#animemoduleregistry) | field | A | The app's `ModuleRegistry`. |

## Documentation

### `class AnimeStorageAdapter` <a id="animestorageadapter"></a>
- **Purpose:** Give the shared engines a storage root and `storage_config.json` access without the
  package knowing anything about `AnimeStorage`.
- **Constructor:** `const AnimeStorageAdapter({Future<Directory> Function()? appDir})`.
- **Methods:** `getAppDir()`, `readConfig()`, `writeConfig(config)` — all delegating to the hub.
- **Notes:** The optional `appDir` resolver exists so `BackupService` can keep honoring its
  `@visibleForTesting appDirProvider`. It is consulted on every call, so swapping the provider
  between tests still works. `AnimeStorage.getAppDir()` re-reads its config each call, so a custom
  storage-path change is picked up immediately by every engine.

### Constants <a id="constants"></a>
- **Notes:** File name and module id are persisted compatibility contracts — an older build and a
  newer one must interoperate against the same WebDAV server and the same backup bundles. Never
  change them.

### `validateAnimeJson(json)` <a id="validateanimejson"></a>
- **Throws:** Whatever `jsonDecode` or `AnimeData.fromJson` throws.
- **Notes:** Deliberately the same bare call the backup and import paths made before the extraction,
  so the exception types and messages callers surface are unchanged.

### `encodeAnimeData(data)` <a id="encodeanimedata"></a>
- **Returns:** JSON with `JsonEncoder.withIndent('  ')`.
- **Notes:** Must match `AnimeStorage`'s local save format. If it did not, an otherwise-unchanged
  file would miss the raw-equality fast path on the next sync and re-upload forever.

### `animeReferencedImages(json)` <a id="animereferencedimages"></a>
- **Returns:** Cover-image basenames; an empty set for malformed input.
- **Notes:** The engine unions the local and remote results, reproducing the previous rule: sync
  images referenced by either side, never orphans.

### `mergeAnimeModule({localJson, remoteJson, baseJson, autoResolve})` <a id="mergeanimemodule"></a>
- **Returns:** `ModuleMergeOutcome` — complete when there are no conflicts, otherwise pending with a
  resolution builder.
- **Notes:** Wraps the unchanged `mergeAnimeData`. The typed `AnimeMergeResult` is carried through as
  opaque `state` so `WebDAVService` can still hand a real `PendingSync` to the conflict dialog.

### `buildAnimeModule()` <a id="buildanimemodule"></a>
- **Notes:** No `postMergeTransform` (MyAnime has no migration) and no `preUploadTransform` —
  unknown-field preservation is baked into the models, so merge output is already self-preserving.

### `animeModuleRegistry` <a id="animemoduleregistry"></a>
- **Notes:** Built once. Registry order is behaviorally significant for sync order, progress
  reporting, and backup key order; MyAnime has a single module, so order is trivial here.

## Where the contract documentation lives

`packages/myapps_data/doc/en-us/functions/src/modules/data_module.md` and
`packages/myapps_data/doc/en-us/functions/src/storage/storage_adapter.md`.
