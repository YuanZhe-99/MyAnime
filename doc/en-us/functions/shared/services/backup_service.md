# lib/shared/services/backup_service.dart

**Facade over the shared engine.** Bundle creation, the content-addressed blob store,
reference-counted GC, retention, and v1/v2 restore moved to the `myapps_data` package
(`lib/src/backup/backup_engine.dart`). This file kept every public name and signature, so
`test/backup_service_test.dart` runs unmodified.

The backup format is unchanged: `backups/backup_<yyyyMMdd_HHmmss>.json` bundles holding
`_backupFormat`, one raw JSON string per module, and `_imageRefs` pointing at
`backups/blobs/<sha256><ext>`. Legacy v1 bundles with inline base64 `_images` remain restorable.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`appDirProvider`](#appdirprovider) | static field | A | Test seam redirecting all backup I/O. |
| [`modules`](#modules) | static field | A | File name to backup module key, derived from the registry. |
| [`autoBackupEnabled`](#settings) | static getter/setter | A | Whether the daily auto-backup runs. |
| [`retentionDays`](#settings) | static getter/setter | A | Days to keep backups; 0 keeps forever. |
| [`loadSettings()`](#settings) | static method | A | Read both settings from `storage_config.json`. |
| [`saveSettings()`](#settings) | static method | A | Persist both settings. |
| [`createBackup()`](#createbackup) | static method | A | Write a v2 bundle plus any new blobs. |
| [`runAutoBackupIfNeeded()`](#runautobackupifneeded) | static method | A | Take the once-per-day backup when due. |
| [`listBackups()`](#listbackups) | static method | A | List bundles newest first, flagging corrupt ones. |
| [`getBackupModules(file)`](#getbackupmodules) | static method | A | Module ids a bundle contains. |
| [`restoreBackup(file, {moduleKeys})`](#restorebackup) | static method | A | Validate-then-restore a bundle. |
| [`deleteBackup(file)`](#deletebackup) | static method | A | Delete a bundle, then GC orphaned blobs. |

Re-exported from the package with unchanged shapes: `BackupInfo{file, date, sizeBytes, corrupt}` and
`RestoreResult{ok, wroteAnything, missingImages}`.

## Documentation

### `appDirProvider` <a id="appdirprovider"></a>
- **Kind:** static field, `@visibleForTesting`
- **Purpose:** Redirect backup I/O to a temporary directory in tests.
- **Notes:** Passed to the storage adapter as a tear-off and read on **every** call, so a test that
  swaps the provider between cases still takes effect on the already-built engine.

### `modules` <a id="modules"></a>
- **Kind:** static field, `Map<String, String>`
- **Purpose:** Maps data-file name to backup module key (`anime_data.json` to `anime`).
- **Notes:** Now derived from the module registry rather than being a second hardcoded map.

### Settings: `autoBackupEnabled`, `retentionDays`, `loadSettings()`, `saveSettings()` <a id="settings"></a>
- **Purpose:** Read and write the two backup settings.
- **Side effects:** `storage_config.json`, under the unchanged keys `autoBackupEnabled` and
  `backupRetentionDays`. Unrelated keys are preserved.

### `createBackup()` <a id="createbackup"></a>
- **Returns:** `Future<File?>` — the bundle, or null on failure.
- **Side effects:** Writes the bundle, dedupes image blobs by sha256, then runs retention cleanup and
  blob GC.

### `runAutoBackupIfNeeded()` <a id="runautobackupifneeded"></a>
- **Side effects:** May create a backup.
- **Notes:** No-op when `autoBackupEnabled` is false. Re-entrancy guarded. "Already backed up today"
  is decided by scanning bundle file names, so a corrupt bundle does not count and the day retries.
  Driven by the periodic tick and resume hooks in `auto_sync_service.dart`.

### `listBackups()` <a id="listbackups"></a>
- **Returns:** `Future<List<BackupInfo>>`, newest first.
- **Notes:** Bundles at or below 4 MiB are parsed to compute validity and referenced-blob sizes;
  larger ones are listed by file size alone. Unparseable bundles are flagged `corrupt`, never hidden.

### `getBackupModules(file)` <a id="getbackupmodules"></a>
- **Returns:** `Future<List<String>>`; empty for an unparseable bundle.
- **Purpose:** Drives the per-module restore checkboxes.

### `restoreBackup(file, {moduleKeys})` <a id="restorebackup"></a>
- **Returns:** `Future<RestoreResult>`.
- **Side effects:** Overwrites data files atomically and restores images from blobs (v2) or inline
  base64 (v1).
- **Notes:** Every selected payload is validated through the registry's parser **before the first
  write**. WebDAV auto-sync is disabled before the first write and re-enabled only when the restore
  failed without writing anything, so restored-old data cannot propagate deletions to other devices.

### `deleteBackup(file)` <a id="deletebackup"></a>
- **Side effects:** Removes the bundle, then garbage-collects blobs no remaining bundle references.
- **Notes:** Blobs younger than a 10-minute grace window are never collected, protecting a backup
  being written concurrently. An unparseable bundle aborts the whole GC pass rather than risking
  deletion of blobs it might reference.

## Where the engine documentation lives

`packages/myapps_data/doc/en-us/functions/src/backup/backup_engine.md`.
