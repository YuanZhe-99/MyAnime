# lib/shared/services/webdav_service.dart

**Facade over the shared engine.** The WebDAV transport, upload-lock lifecycle, merge pipeline,
`.sync_base` snapshots, and referenced-image sync moved to the `myapps_data` package
(`lib/src/webdav/sync_engine.dart` and friends). This file kept every public name and signature it
had, so call sites, the conflict dialog, and the existing tests are unchanged.

The app's data files are described once in
[`../../app/data_modules.md`](../../app/data_modules.md); the hardcoded `_dataFileNames` list is gone.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`SyncResult`](#syncresult) | class | A | Success flag, error text, pending conflicts, non-fatal warnings. |
| [`PendingSync`](#pendingsync) | class | A | Unresolved conflicts plus the engine state needed to finalize. |
| [`WebDAVService.progress`](#progress) | static getter | A | Live `ValueNotifier<SyncProgress>` for the progress bar. |
| [`consumeLocalDataChanged()`](#consumelocaldatachanged) | static method | A | Read and clear the "sync wrote local data" signal. |
| [`loadConfig()`](#loadconfig) | static method | A | Read `webdav_config.json`. |
| [`saveConfig(config)`](#saveconfig) | static method | A | Atomically write `webdav_config.json`. |
| [`deleteConfig()`](#deleteconfig) | static method | A | Remove `webdav_config.json`. |
| [`testConnection(config)`](#testconnection) | static method | A | One PROPFIND; 207 or 404 means reachable. |
| [`sync(config, {autoResolve})`](#sync) | static method | A | Full two-way sync under the remote `.lock`. |
| [`finalizePendingSync(...)`](#finalizependingsync) | static method | A | Upload the user's conflict resolutions. |
| [`forceUpload(config)`](#forceupload) | static method | A | Overwrite remote with local, no merge. |
| [`forceDownload(config)`](#forcedownload) | static method | A | Overwrite local with remote, no merge. |

Re-exported from the package under their original names, so every call site sees the same type:
`WebDAVConfig`, `WebDAVUploadLock`, `RemoteFile`, `RemoteFileStatus`.

## Documentation

### `class SyncResult` <a id="syncresult"></a>
- **Purpose:** Outcome of a sync, force-upload, or force-download.
- **Fields:** `success`, `error`, `pending` (`PendingSync?`), `warnings` (non-fatal, e.g. individual
  image transfer failures).
- **Getter:** `hasConflicts` — true when `pending != null`.
- **Notes:** Shape unchanged from before the extraction. Built from the engine's `EngineSyncResult`
  by a private adapter.

### `class PendingSync` <a id="pendingsync"></a>
- **Purpose:** Carries unresolved conflicts to the dialog and back.
- **Fields:** `animeMerge` (`AnimeMergeResult?`, the app-typed merge state) and `enginePending`
  (opaque engine state used by `finalizePendingSync`).
- **Getter:** `allConflicts` — `List<RecordConflict<Anime>>` for the dialog.
- **Notes:** The engine never inspects the app's merge result; it carries it through as opaque
  `state`, which is why the dialog still receives real `Anime` records.

### `progress` <a id="progress"></a>
- **Kind:** static getter → `ValueNotifier<SyncProgress>`
- **Purpose:** The engine's live progress notifier, exposed for the settings page.

### `consumeLocalDataChanged()` <a id="consumelocaldatachanged"></a>
- **Returns:** `bool` — whether sync wrote local data or downloaded images since the last call.
- **Side effects:** Resets the flag.

### `loadConfig()` <a id="loadconfig"></a>
- **Returns:** `Future<WebDAVConfig?>`; null when absent, malformed, or unreadable.
- **Notes:** A missing or null `remotePath` still defaults to `/MyAnime`. An explicit empty string
  stays empty — it can mean the WebDAV account root.

### `saveConfig(config)` <a id="saveconfig"></a>
- **Side effects:** Atomic tmp-then-rename write of `webdav_config.json`, compact JSON.
- **Notes:** Credentials remain plaintext; unchanged and out of scope.

### `deleteConfig()` <a id="deleteconfig"></a>
- **Side effects:** Deletes the config when present. Base snapshots and the client ID are left alone.

### `testConnection(config)` <a id="testconnection"></a>
- **Returns:** `Future<bool>` — true for HTTP 207 or 404.
- **Notes:** 404 counts as reachable because the collection may not exist yet.

### `sync(config, {autoResolve = false})` <a id="sync"></a>
- **Returns:** `Future<SyncResult>`.
- **Side effects:** Acquires the remote `.lock`, downloads, merges, uploads, saves base snapshots,
  syncs referenced images, updates `progress`.
- **Notes:** `autoResolve` is false at every production call site — conflicts are never silently
  auto-resolved.

### `finalizePendingSync(config, pending, resolutions)` <a id="finalizependingsync"></a>
- **Inputs:** `resolutions` maps anime ID to the chosen `Anime`.
- **Returns:** `Future<bool>` — false when applying or uploading fails.
- **Side effects:** Reacquires the lock, **re-downloads the remote data file**, writes local, uploads,
  saves the base.
- **Notes:** The re-download was adopted from MyDay/MyDevice during the extraction. It does not
  re-merge known fields; it guards against uploading a resolution over a remote that has become
  unreadable. The base is only saved after a successful upload.

### `forceUpload(config)` <a id="forceupload"></a>
- **Side effects:** Overwrites remote data and uploads missing referenced images under the `.lock`.
- **Notes:** Remote changes since the last sync are lost.

### `forceDownload(config)` <a id="forcedownload"></a>
- **Side effects:** Replaces local data files and base snapshots; downloads missing images. Lock-free.
- **Notes:** Local changes since the last sync are lost. Remote payloads are validated syntax-only.

## Where the engine documentation lives

`packages/myapps_data/doc/en-us/functions/src/webdav/` — `sync_engine.md`, `webdav_client.md`,
`webdav_config.md`, `upload_lock.md`.
