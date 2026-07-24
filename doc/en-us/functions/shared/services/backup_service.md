# lib/shared/services/backup_service.dart

Local backup creation, listing, restore, deletion, retention cleanup, and content-addressed image
blob deduplication/GC. Backups are JSON bundles under `backups/backup_*.json`, referencing shared
image blobs under `backups/blobs/<sha256><ext>` so identical images are stored once across every
backup. See [`../../../backup-restore.md`](../../../backup-restore.md) for the full format v2
description, retention policy, and — critically — the WebDAV auto-sync safety rule the caller
(`lib/features/settings/views/backup_page.dart`) applies around `restoreBackup()`. `runAutoBackupIfNeeded()`
is triggered by [`auto_sync_service.md`](auto_sync_service.md) (`start()`, `didChangeAppLifecycleState`,
and the 15-minute periodic timer) and by `lib/main.dart` at launch.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `appDirProvider` | static field (`BackupService`) | B | Test-only hook to redirect backup I/O to a temp directory. |
| [`_getAppDir`](#getappdir) | static method (`BackupService`) | A | Resolve the app data directory, honoring the test override. |
| [`_getBackupDir`](#getbackupdir) | static method (`BackupService`) | A | Resolve/create the `backups/` directory. |
| [`_getBlobDir`](#getblobdir) | static method (`BackupService`) | A | Resolve/create the `backups/blobs/` directory. |
| [`loadSettings`](#loadsettings) | static method (`BackupService`) | A | Load `autoBackupEnabled`/`retentionDays` from config. |
| [`saveSettings`](#savesettings) | static method (`BackupService`) | A | Persist `autoBackupEnabled`/`retentionDays` to config. |
| [`_atomicWriteString`](#atomicwritestring) | static method (`BackupService`) | A | Write text to a file via tmp-then-rename. |
| [`_atomicWriteBytes`](#atomicwritebytes) | static method (`BackupService`) | A | Write bytes to a file via tmp-then-rename. |
| [`createBackup`](#createbackup) | static method (`BackupService`) | A | Create a new backup bundle, deduplicating images into blobs. |
| [`runAutoBackupIfNeeded`](#runautobackupifneeded) | static method (`BackupService`) | A | Create today's auto-backup if enabled and not already done. |
| [`listBackups`](#listbackups) | static method (`BackupService`) | A | List all backups, sorted newest first, with corruption/size detection. |
| [`getBackupModules`](#getbackupmodules) | static method (`BackupService`) | A | Return which data modules a backup bundle contains. |
| [`_safeImageRelativePath`](#safeimagerelativepath) | static method (`BackupService`) | A | Sanitize a backup image key into a safe `images/<name>` path. |
| [`restoreBackup`](#restorebackup) | static method (`BackupService`) | A | Restore selected modules/images from a backup bundle. |
| [`deleteBackup`](#deletebackup) | static method (`BackupService`) | A | Delete a backup bundle and GC now-unreferenced blobs. |
| [`_cleanOldBackups`](#cleanoldbackups) | static method (`BackupService`) | A | Delete backups older than the retention window. |
| [`_collectUnreferencedBlobs`](#collectunreferencedblobs) | static method (`BackupService`) | A | Garbage-collect image blobs no remaining backup references. |
| [`RestoreResult(...)`](#restoreresult-new) | constructor (`RestoreResult`) | A | Describe the outcome of a restore attempt. |
| [`BackupInfo(...)`](#backupinfo-new) | constructor (`BackupInfo`) | A | Describe one listed backup bundle. |
| [`displaySize`](#displaysize) | getter (`BackupInfo`) | A | Human-readable size (B/KB/MB). |

## Documentation

### `appDirProvider`
(Table row only — Tier B; `@visibleForTesting static Future<Directory> Function()? appDirProvider` lets tests redirect all backup I/O to a temp directory. `null` in production, where [`_getAppDir`](#getappdir) always falls back to `AnimeStorage.getAppDir()`.)

### `static Future<Directory> _getAppDir()` <a id="getappdir"></a>
- **Kind:** static method of `BackupService`
- **Source:** `lib/shared/services/backup_service.dart` (line 55)
- **Purpose:** Resolve the app data directory, honoring the test override if set.
- **Inputs:** None.
- **Returns:** `Future<Directory>`.
- **Side effects:** None (delegates to `AnimeStorage.getAppDir()` in production).
- **Algorithm:** Returns `appDirProvider()` if non-null, else `AnimeStorage.getAppDir()`.
- **Usage:**
  ```dart
  final appDir = await _getAppDir();
  ```
  (`BackupService.createBackup`, same file)
- **Notes:** Every other method in this file that needs the app directory goes through this indirection rather than calling `AnimeStorage.getAppDir()` directly, so tests can isolate backup I/O.

### `static Future<Directory> _getBackupDir()` <a id="getbackupdir"></a>
- **Kind:** static method of `BackupService`
- **Source:** `lib/shared/services/backup_service.dart` (line 66)
- **Purpose:** Resolve the `backups/` directory, creating it if missing.
- **Inputs:** None.
- **Returns:** `Future<Directory>`.
- **Side effects:** Creates `<appDir>/backups/` (recursively) if it doesn't exist.
- **Algorithm:** Existence check then `create(recursive: true)`.
- **Usage:**
  ```dart
  final backupDir = await _getBackupDir();
  ```
  (`BackupService.createBackup`, same file)
- **Notes:** None.

### `static Future<Directory> _getBlobDir()` <a id="getblobdir"></a>
- **Kind:** static method of `BackupService`
- **Source:** `lib/shared/services/backup_service.dart` (line 80)
- **Purpose:** Resolve the shared content-addressed image blob directory, creating it if missing.
- **Inputs:** None.
- **Returns:** `Future<Directory>`.
- **Side effects:** Creates `backups/blobs/` (recursively) if it doesn't exist.
- **Algorithm:** Delegates to `_getBackupDir()`, then existence check + `create(recursive: true)` on the `blobs` subdirectory.
- **Usage:**
  ```dart
  final blobDir = await _getBlobDir();
  ```
  (`BackupService.createBackup`, same file)
- **Notes:** All backups share this one blob directory, which is what makes cross-backup deduplication possible (see [`../../../backup-restore.md`](../../../backup-restore.md)).

### `static Future<void> loadSettings()` <a id="loadsettings"></a>
- **Kind:** static method of `BackupService`
- **Source:** `lib/shared/services/backup_service.dart` (line 94)
- **Purpose:** Load the persisted auto-backup settings into the class's static fields.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Reads `storage_config.json` via `AnimeStorage.readConfig()`; sets `BackupService.autoBackupEnabled` and `BackupService.retentionDays`.
- **Algorithm:** Reads `config['autoBackupEnabled'] as bool? ?? false` and `config['backupRetentionDays'] as int? ?? 0`.
- **Usage:**
  ```dart
  await BackupService.loadSettings();
  ```
  (`lib/features/settings/views/backup_page.dart`, `_load`; also `runAutoBackupIfNeeded`, same file)
- **Notes:** `retentionDays == 0` means "keep forever".

### `static Future<void> saveSettings()` <a id="savesettings"></a>
- **Kind:** static method of `BackupService`
- **Source:** `lib/shared/services/backup_service.dart` (line 105)
- **Purpose:** Persist the current static `autoBackupEnabled`/`retentionDays` values to config.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Reads then rewrites `storage_config.json` (merging just these two keys into whatever config already exists).
- **Algorithm:** `config = await AnimeStorage.readConfig(); config['autoBackupEnabled'] = ...; config['backupRetentionDays'] = ...; await AnimeStorage.writeConfig(config);`
- **Usage:**
  ```dart
  BackupService.autoBackupEnabled = value;
  await BackupService.saveSettings();
  ```
  (`lib/features/settings/views/backup_page.dart`, `_toggleAutoBackup`)
- **Notes:** Callers set the static field directly before calling this — there's no setter parameter; `saveSettings()` just flushes whatever the current static values are.

### `static Future<void> _atomicWriteString(File file, String content)` <a id="atomicwritestring"></a>
- **Kind:** static method of `BackupService`
- **Source:** `lib/shared/services/backup_service.dart` (line 118)
- **Purpose:** Write text to a file without ever leaving a truncated bundle behind on a crash.
- **Inputs:** `file`, `content`.
- **Returns:** None.
- **Side effects:** Creates parent directories if needed; writes a uniquely-named tmp file, then renames it onto `file`.
- **Algorithm:** Ensure `file.parent` exists (`create(recursive: true)` if not); write `content` to `<file.path>.tmp-<microsecondsSinceEpoch>`; `rename()` it onto `file.path`; if the rename itself throws, best-effort delete the leftover tmp file and rethrow.
- **Usage:**
  ```dart
  await _atomicWriteString(file, content);
  ```
  (`BackupService.createBackup`, same file)
- **Notes:** The tmp file name includes a microsecond timestamp (unlike `WebDAVService._atomicWrite`'s fixed `.tmp` suffix — see [`webdav_service.md`](webdav_service.md#atomicwrite)), so concurrent writers can't collide on the same tmp path.

### `static Future<void> _atomicWriteBytes(File file, List<int> bytes)` <a id="atomicwritebytes"></a>
- **Kind:** static method of `BackupService`
- **Source:** `lib/shared/services/backup_service.dart` (line 143)
- **Purpose:** Write bytes (image blobs, restored images) to a file atomically.
- **Inputs:** `file`, `bytes`.
- **Returns:** None.
- **Side effects:** Same tmp-then-rename shape as [`_atomicWriteString`](#atomicwritestring), for bytes.
- **Algorithm:** Identical to `_atomicWriteString` but using `writeAsBytes`/`readAsBytes`-shaped I/O.
- **Usage:**
  ```dart
  await _atomicWriteBytes(blobFile, bytes);
  ```
  (`BackupService.createBackup`, writing a new content-addressed blob)
- **Notes:** Used for both new blob writes during backup creation and restored image files during `restoreBackup`.

### `static Future<File?> createBackup()` <a id="createbackup"></a>
- **Kind:** static method of `BackupService`
- **Source:** `lib/shared/services/backup_service.dart` (line 169)
- **Purpose:** Create a new backup bundle right now, deduplicating cover images into the shared blob store.
- **Inputs:** None.
- **Returns:** `Future<File?>` — the new bundle file, or `null` on any failure.
- **Side effects:** Writes `backups/backup_<yyyyMMdd_HHmmss>.json`; may write new files under `backups/blobs/`; runs retention cleanup and blob GC afterward.
- **Algorithm:**
  1. Start `bundle = {'_backupFormat': 2}`.
  2. For each entry in `modules` (currently just `anime_data.json` → `'anime'`), if the file exists, read it as a string into `bundle[fileName]`.
  3. If `<appDir>/images/` exists, for every file in it: read its bytes, SHA-256 hash them, build a blob name `<hash><ext>`, write it into `backups/blobs/` via [`_atomicWriteBytes`](#atomicwritebytes) only if that blob doesn't already exist, and record `refs['images/<basename>'] = blobName`. If any refs were collected, set `bundle['_imageRefs'] = refs`.
  4. `jsonEncode(bundle)`, build the timestamped file name, write it via [`_atomicWriteString`](#atomicwritestring).
  5. Run [`_cleanOldBackups`](#cleanoldbackups) then [`_collectUnreferencedBlobs`](#collectunreferencedblobs).
  6. Return the new file; any exception anywhere in the above returns `null` instead of propagating.
- **Usage:**
  ```dart
  final file = await BackupService.createBackup();
  ```
  (`lib/features/settings/views/backup_page.dart`, `_createBackup`)
- **Notes:** Hashing is by content, not by file name, so two images with identical bytes (e.g. the same cover reused, or a re-imported duplicate) are stored once in `backups/blobs/` regardless of their local file names.

### `static Future<void> runAutoBackupIfNeeded()` <a id="runautobackupifneeded"></a>
- **Kind:** static method of `BackupService`
- **Source:** `lib/shared/services/backup_service.dart` (line 223)
- **Purpose:** Create today's auto-backup exactly once, if auto-backup is enabled and today's backup doesn't already exist.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** May create a new backup file (via [`createBackup`](#createbackup)); updates the in-memory `_lastAutoBackup` timestamp.
- **Algorithm:**
  1. Re-entrancy guard: return immediately if `_autoBackupRunning` is already `true`; set it `true` for the duration.
  2. `loadSettings()`; return if `autoBackupEnabled` is `false`.
  3. If `_lastAutoBackup` is set and falls on today's calendar day already, return (cheap short-circuit without listing backups).
  4. Otherwise list existing backups and check whether any **non-corrupt** one's date matches today (`if (b.corrupt) return false;` inside the `any` predicate) — a corrupt bundle from today does not count as "already backed up today". If one is found, just update `_lastAutoBackup` and return.
  5. Otherwise call `createBackup()` and update `_lastAutoBackup`.
  6. `finally` clears `_autoBackupRunning`.
- **Usage:**
  ```dart
  _periodicSync = Timer.periodic(_periodicSyncInterval, (_) {
    requestSyncNow();
    BackupService.runAutoBackupIfNeeded();
  });
  ```
  (`AutoSyncService.start`, [`auto_sync_service.md`](auto_sync_service.md#start))
- **Notes:** Excluding `corrupt` bundles from the "already done today" check is what makes an interrupted/corrupted auto-backup attempt retried on the next trigger instead of being silently skipped for the rest of the day (see [`../../../backup-restore.md`](../../../backup-restore.md)).

### `static Future<List<BackupInfo>> listBackups()` <a id="listbackups"></a>
- **Kind:** static method of `BackupService`
- **Source:** `lib/shared/services/backup_service.dart` (line 269)
- **Purpose:** List every backup bundle, newest first, with size (including referenced blobs) and corruption status.
- **Inputs:** None.
- **Returns:** `Future<List<BackupInfo>>` — empty if the backup directory doesn't exist.
- **Side effects:** None (read-only).
- **Algorithm:**
  1. Return `[]` immediately if `backups/` doesn't exist.
  2. For each `backup_*.json` file: parse its timestamp from the file name (`yyyyMMdd_HHmmss`), falling back to the file's modified time if the name doesn't parse.
  3. Start `sizeBytes` from the file's own size. If the file is at or under `_probeMaxBytes` (4 MB), parse it as JSON and, for each `_imageRefs` value, add that blob's file size (if the blob exists) to `sizeBytes`; a parse failure here sets `corrupt = true`. Larger (legacy inline-image) bundles are **not** probed — they're listed by raw file size alone.
  4. Sort the resulting list by date, descending.
- **Usage:**
  ```dart
  final backups = await BackupService.listBackups();
  ```
  (`lib/features/settings/views/backup_page.dart`, `_load`)
- **Notes:** `_probeMaxBytes` (4 MB) exists so a legacy v1 bundle with large inline base64 images isn't fully JSON-parsed just to list it — those are sized by file size alone and never flagged `corrupt` by this pass.

### `static Future<List<String>> getBackupModules(File file)` <a id="getbackupmodules"></a>
- **Kind:** static method of `BackupService`
- **Source:** `lib/shared/services/backup_service.dart` (line 331)
- **Purpose:** Report which data modules (currently just `'anime'`) a given backup bundle actually contains, for the restore module-selection dialog.
- **Inputs:** `file`.
- **Returns:** `Future<List<String>>` — empty on any read/parse failure.
- **Side effects:** None (read-only).
- **Algorithm:** Read and JSON-decode the file; filter `modules.entries` (the file-name → module-id map) to those whose file-name key is present in the bundle, and return the module ids.
- **Usage:**
  ```dart
  final availableModules = await BackupService.getBackupModules(backup.file);
  ```
  (`lib/features/settings/views/backup_page.dart`, `_restoreBackup`)
- **Notes:** An empty result (parse failure or a bundle with none of the known module keys) is what the restore-page UI treats as "backup can't be restored", showing a failure snackbar instead of the module dialog.

### `static String? _safeImageRelativePath(String rawKey)` <a id="safeimagerelativepath"></a>
- **Kind:** static method of `BackupService`
- **Source:** `lib/shared/services/backup_service.dart` (line 350)
- **Purpose:** Validate and normalize an image key from a backup bundle's `_imageRefs`/`_images` map into a safe flat `images/<name>` path, rejecting anything that could write outside the images directory.
- **Inputs:** `rawKey` (e.g. `"images/abc123.jpg"`).
- **Returns:** `String?` — the normalized path, or `null` if rejected.
- **Side effects:** None.
- **Algorithm:** Normalize the path and replace `\` with `/`; reject (return `null`) unless the result starts with `images/`, has exactly two `/`-separated segments (no nested subdirectories), contains no `..`, and is not absolute.
- **Usage:**
  ```dart
  final relPath = _safeImageRelativePath(e.key);
  if (relPath == null || blobName is! String) continue;
  ```
  (`BackupService.restoreBackup`, same file)
- **Notes:** This is the safeguard against a crafted/corrupted backup bundle writing outside `images/` (e.g. via a `../` traversal key) during restore.

### `static Future<RestoreResult> restoreBackup(File file, {Set<String>? moduleKeys})` <a id="restorebackup"></a>
- **Kind:** static method of `BackupService`
- **Source:** `lib/shared/services/backup_service.dart` (line 371)
- **Purpose:** Restore some or all data modules and their referenced images from a backup bundle.
- **Inputs:** `file`; optional `moduleKeys` (restrict to specific module ids, e.g. `{'anime'}`; `null` restores every module present).
- **Returns:** `Future<RestoreResult>` (`ok`, `wroteAnything`, `missingImages`) — see [`RestoreResult`](#restoreresult-new).
- **Side effects:** Overwrites app data files atomically; restores image files from blob references (v2) or inline base64 (legacy v1).
- **Algorithm:**
  1. Read and JSON-decode the bundle.
  2. **Validate before writing anything:** for each module in `modules` (filtered by `moduleKeys` if given) that's present in the bundle, parse its content through `AnimeData.fromJson(jsonDecode(content))` — if this throws for any selected module, the whole call throws and no file is written yet.
  3. Only after every selected payload validates, write each one via [`_atomicWriteString`](#atomicwritestring), setting `wrote = true` per write.
  4. Restore images: if `_imageRefs` (v2) is present, for each entry validate the key via [`_safeImageRelativePath`](#safeimagerelativepath) and look up the blob in `backups/blobs/`; if the blob is missing, increment `missingImages` and skip it (rather than silently dropping it unnoticed); otherwise copy the blob's bytes to the local path atomically. Else if legacy `_images` (v1, inline base64) is present, decode and write each one the same way.
  5. Return `RestoreResult(ok: true, wroteAnything: wrote, missingImages: missingImages)`.
  6. Any exception anywhere returns `RestoreResult(ok: false, wroteAnything: wrote, missingImages: missingImages)` — `wrote`/`missingImages` reflect whatever had already happened before the exception, which is exactly what callers need to decide whether local data is safely untouched.
- **Usage:**
  ```dart
  final result = await BackupService.restoreBackup(backup.file, moduleKeys: selected);
  if (!result.ok) {
    if (hadAutoSync && !result.wroteAnything) {
      await WebDAVService.saveConfig(config!.copyWith(autoSync: true));
    }
  }
  ```
  (`lib/features/settings/views/backup_page.dart`, `_restoreBackup` — see [`../../../backup-restore.md`](../../../backup-restore.md) for the full auto-sync-disable-before-write safety rule around this call)
- **Notes:** Validating every selected module **before** writing any of them means a restore selecting multiple modules can never leave a partially-valid, partially-written state from a payload failure alone — though a crash *during* the write loop itself can still leave some modules written and others not, which is exactly why `wroteAnything` (not `ok`) is the caller's signal for "is local data still trustworthy".

### `static Future<void> deleteBackup(File file)` <a id="deletebackup"></a>
- **Kind:** static method of `BackupService`
- **Source:** `lib/shared/services/backup_service.dart` (line 457)
- **Purpose:** Delete one backup bundle and reclaim any image blobs no remaining backup references.
- **Inputs:** `file`.
- **Returns:** None.
- **Side effects:** Deletes `file` if it exists; runs [`_collectUnreferencedBlobs`](#collectunreferencedblobs).
- **Algorithm:** Existence check + delete, then always run blob GC (even if the file didn't exist, harmlessly).
- **Usage:**
  ```dart
  await BackupService.deleteBackup(backup.file);
  await _load();
  ```
  (`lib/features/settings/views/backup_page.dart`)
- **Notes:** None.

### `static Future<void> _cleanOldBackups()` <a id="cleanoldbackups"></a>
- **Kind:** static method of `BackupService`
- **Source:** `lib/shared/services/backup_service.dart` (line 469)
- **Purpose:** Delete backup bundles older than the configured retention window.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Deletes backup bundle files whose date is before the cutoff.
- **Algorithm:** Return immediately if `retentionDays <= 0` (keep forever). Otherwise compute `cutoff = now - retentionDays days`, list all backups via [`listBackups`](#listbackups), and delete every one whose `date` is before `cutoff`.
- **Usage:**
  ```dart
  await _cleanOldBackups();
  ```
  (`BackupService.createBackup`, run right after a new backup is written)
- **Notes:** Callers (just `createBackup`) run blob GC (`_collectUnreferencedBlobs`) afterward, since deleting old bundles can orphan blobs only those bundles referenced.

### `static Future<void> _collectUnreferencedBlobs()` <a id="collectunreferencedblobs"></a>
- **Kind:** static method of `BackupService`
- **Source:** `lib/shared/services/backup_service.dart` (line 487)
- **Purpose:** Delete image blobs that no remaining backup bundle references, reclaiming disk space from deleted/retention-expired backups.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Deletes files under `backups/blobs/`.
- **Algorithm:**
  1. List all blob files; return immediately if there are none.
  2. Scan every remaining `backup_*.json` bundle, collecting every referenced blob basename into a `referenced` set. **If any bundle fails to parse, abort the entire pass immediately** (`return`) rather than guessing — the true reference set is unknown, so nothing is safe to delete.
  3. For each blob not in `referenced`: skip it if its modified time is younger than `_blobGcGrace` (10 minutes) — this protects a blob that's mid-write by a concurrent `createBackup()` call from being collected out from under it. Otherwise delete it (best-effort, swallowing errors).
  4. The whole method is wrapped in a top-level `try/catch` that swallows everything, so a GC failure never propagates to the caller.
- **Usage:**
  ```dart
  await _collectUnreferencedBlobs();
  ```
  (`BackupService.createBackup` and `deleteBackup`, same file)
- **Notes:** The "abort on any unparseable bundle" rule and the 10-minute grace window are both conservative-by-design per [`../../../backup-restore.md`](../../../backup-restore.md) — this function only ever deletes a blob when it's confident that blob is truly orphaned.

### `const RestoreResult({required ok, required wroteAnything, missingImages = 0})` <a id="restoreresult-new"></a>
- **Kind:** constructor of `RestoreResult`
- **Source:** `lib/shared/services/backup_service.dart` (line 545)
- **Purpose:** Describe the outcome of a [`restoreBackup`](#restorebackup) call, distinguishing "failed with nothing written" from "failed partway through".
- **Inputs:** `ok`, `wroteAnything`, `missingImages` (default 0).
- **Returns:** A new `RestoreResult`.
- **Side effects:** None.
- **Algorithm:** Plain field assignment.
- **Usage:**
  ```dart
  return RestoreResult(ok: false, wroteAnything: wrote, missingImages: missingImages);
  ```
  (`BackupService.restoreBackup`, same file)
- **Notes:** `wroteAnything == false` is the load-bearing flag callers use to decide whether it's safe to re-enable WebDAV auto-sync after a failed restore (local data is provably untouched only in that case) — see [`../../../backup-restore.md`](../../../backup-restore.md).

### `const BackupInfo({required file, required date, required sizeBytes, corrupt = false})` <a id="backupinfo-new"></a>
- **Kind:** constructor of `BackupInfo`
- **Source:** `lib/shared/services/backup_service.dart` (line 564)
- **Purpose:** Describe one backup bundle for the backup-list UI.
- **Inputs:** `file`, `date`, `sizeBytes` (includes referenced blob sizes for v2 bundles), `corrupt` (default `false`).
- **Returns:** A new `BackupInfo`.
- **Side effects:** None.
- **Algorithm:** Plain field assignment.
- **Usage:**
  ```dart
  files.add(BackupInfo(file: entity, date: date, sizeBytes: sizeBytes, corrupt: corrupt));
  ```
  (`BackupService.listBackups`, same file)
- **Notes:** None.

### `String get displaySize` <a id="displaysize"></a>
- **Kind:** getter of `BackupInfo`
- **Source:** `lib/shared/services/backup_service.dart` (line 576)
- **Purpose:** Format `sizeBytes` as a human-readable string for the backup-list UI.
- **Inputs:** None.
- **Returns:** `String` — e.g. `"512 B"`, `"3.4 KB"`, `"1.2 MB"`.
- **Side effects:** None.
- **Algorithm:** Three-way branch: `< 1024` → `"$sizeBytes B"`; `< 1024*1024` → KB with one decimal; otherwise MB with one decimal.
- **Usage:** Bound directly in the backup-list UI (`lib/features/settings/views/backup_page.dart`) as the subtitle/trailing text for each `BackupInfo` row.
- **Notes:** None.
