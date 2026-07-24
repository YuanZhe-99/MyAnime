# lib/features/settings/views/backup_page.dart

`BackupPage` is the Settings -> Backup sub-page: it lists local backup bundles produced by
`BackupService` (`lib/shared/services/backup_service.dart`,
[`../../../shared/services/backup_service.md`](../../../shared/services/backup_service.md)),
lets the user create a backup on demand, toggle daily auto-backup, choose a retention window, and
restore or delete individual bundles. Unlike most view files in this batch, several of its
callbacks carry real orchestration logic rather than pure widget composition — most notably
`_restoreBackup`, which implements the safety-critical "disable WebDAV auto-sync before the first
restored byte is written" rule, and `_handlePostRestoreSync`, which offers a post-restore
force-upload under the sync wake lock. Both are the `backup_page.dart` half of the flow documented
in full in [`../../../backup-restore.md`](../../../../backup-restore.md) (see "The critical safety
rule: WebDAV auto-sync around restore") and walked through concretely in
[`../../../examples/backup-restore-walkthrough.md`](../../../../examples/backup-restore-walkthrough.md).
The nested private `_RestoreModuleDialog` widget lets the user pick which backup modules (currently
just `anime`) to restore before the confirmation dialog in `_restoreBackup` runs.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `BackupPage({super.key})` | constructor (`BackupPage`) | B | Create a backup page instance. |
| `createState` | method (widget lifecycle) | B | Create the mutable state object for this widget. |
| `initState` | method (widget lifecycle) | B | Kick off the initial backup-list/settings load. |
| [`_load`](#load) | method (`_BackupPageState`) | A | Load backup settings and the current backup list from `BackupService`. |
| [`_createBackup`](#createbackup) | method (`_BackupPageState`) | A | Create a new backup bundle and refresh the list. |
| [`_restoreBackup`](#restorebackup) | method (`_BackupPageState`) | A | Confirm, disable auto-sync if needed, and restore a backup bundle. |
| [`_handlePostRestoreSync`](#handlepostrestoresync) | method (`_BackupPageState`) | A | Offer a force upload to WebDAV after a restore. |
| [`_deleteBackup`](#deletebackup) | method (`_BackupPageState`) | A | Confirm and delete a backup bundle. |
| [`_toggleAutoBackup`](#toggleautobackup) | method (`_BackupPageState`) | A | Persist the auto-backup on/off setting. |
| [`_setRetention`](#setretention) | method (`_BackupPageState`) | A | Persist the backup retention-days setting. |
| `_buildSection` | method (widget helper) | B | Render a titled settings section. |
| `build` | method (widget build) | B | Render the current backup settings/history UI state. |
| `_RestoreModuleDialog({required availableModules})` | constructor (`_RestoreModuleDialog`) | B | Create a restore module dialog instance. |
| `createState` | method (widget lifecycle) | B | Create the mutable state object for this dialog widget. |
| `initState` | method (widget lifecycle) | B | Seed the selected-modules set from all available modules. |
| `build` | method (widget build) | B | Render the module checklist dialog. |

## Documentation

### `Future<void> _load()` <a id="load"></a>
- **Kind:** method of `_BackupPageState`
- **Source:** `lib/features/settings/views/backup_page.dart` (line 52)
- **Purpose:** Load persisted backup settings and the current backup bundle list, then populate
  the page's state.
- **Inputs:** None.
- **Returns:** None (updates `State` fields via `setState`).
- **Side effects:** Reads backup settings and re-enumerates `backups/` on disk through
  `BackupService`; triggers a rebuild.
- **Algorithm:**
  1. Await `BackupService.loadSettings()` to populate the service's static `autoBackupEnabled`/
     `retentionDays` fields
     ([`../../../shared/services/backup_service.md#loadsettings`](../../../shared/services/backup_service.md#loadsettings)).
  2. Await `BackupService.listBackups()`
     ([`../../../shared/services/backup_service.md#listbackups`](../../../shared/services/backup_service.md#listbackups))
     to get the current `List<BackupInfo>`.
  3. If still `mounted`, `setState` to store the list and settings and clear `_loading`.
- **Usage:**
  ```dart
  @override
  void initState() {
    super.initState();
    _load();
  }
  ```
  Also re-invoked after `_createBackup` succeeds and after `_deleteBackup` completes, so the list
  reflects the on-disk state after any mutation.
- **Notes:** Guards every state write with `mounted` since it runs after an `await` and the page
  may have been disposed in the meantime.

### `Future<void> _createBackup()` <a id="createbackup"></a>
- **Kind:** method of `_BackupPageState`
- **Source:** `lib/features/settings/views/backup_page.dart` (line 71)
- **Purpose:** Create a new backup bundle on demand and report success or failure.
- **Inputs:** None (reads `context` for localization/snackbars).
- **Returns:** None.
- **Side effects:** Writes a new `backups/backup_*.json` bundle (and any new content-addressed
  blobs) via `BackupService.createBackup()`; shows a snackbar; reloads the list on success.
- **Algorithm:**
  1. Await `BackupService.createBackup()`
     ([`../../../shared/services/backup_service.md#createbackup`](../../../shared/services/backup_service.md#createbackup)).
  2. If it returned a non-null `File`, show the `backupCreated` snackbar and call [`_load`](#load)
     to refresh the displayed history.
  3. Otherwise show the `backupFailed` snackbar.
- **Usage:**
  ```dart
  ListTile(
    leading: const Icon(Icons.backup),
    title: Text(l10n.backupCreate),
    trailing: const Icon(Icons.chevron_right),
    onTap: _createBackup,
  ),
  ```
- **Notes:** Does not disable the button while the backup is being created, so a fast double-tap
  could start two overlapping `createBackup()` calls; nothing in this method guards against that.

### `Future<void> _restoreBackup(BackupInfo backup)` <a id="restorebackup"></a>
- **Kind:** method of `_BackupPageState`
- **Source:** `lib/features/settings/views/backup_page.dart` (line 98)
- **Purpose:** Walk the user through selecting modules and confirming a restore, then perform the
  restore with the WebDAV auto-sync safety rule applied before any file is written.
- **Inputs:** `backup` — the `BackupInfo` entry the user picked (its `.file` is passed through to
  `BackupService`).
- **Returns:** None.
- **Side effects:** May disable WebDAV auto-sync in `webdav_config.json`, overwrite local data/image
  files via `BackupService.restoreBackup`, re-enable auto-sync on a no-op failure, notify
  `AutoSyncService`/`ReminderService` listeners, and show dialogs/snackbars.
- **Algorithm:**
  1. Fetch `BackupService.getBackupModules(backup.file)`
     ([`../../../shared/services/backup_service.md#getbackupmodules`](../../../shared/services/backup_service.md#getbackupmodules));
     if empty, show `backupRestoreFailed` and stop.
  2. Show `_RestoreModuleDialog` to let the user pick which modules to restore; if the user
     cancels or picks nothing, stop.
  3. Show a confirmation `AlertDialog`; if not confirmed, stop.
  4. **Before writing anything:** load the current `WebDAVService.loadConfig()`
     ([`../../../shared/services/webdav_service.md#loadconfig`](../../../shared/services/webdav_service.md#loadconfig)).
     If it is configured and `autoSync` is currently on, immediately
     `WebDAVService.saveConfig(config.copyWith(autoSync: false))` — with **no** `mounted` gate on
     this specific call, so a crash or page disposal right after this line still leaves auto-sync
     off before the restore proceeds.
  5. Call `BackupService.restoreBackup(backup.file, moduleKeys: selected)`
     ([`../../../shared/services/backup_service.md#restorebackup`](../../../shared/services/backup_service.md#restorebackup)).
  6. If `result.ok` is `false`: re-enable auto-sync **only** if it had been on **and**
     `result.wroteAnything` is `false` (i.e. local data is provably untouched); show
     `backupRestoreFailed` and stop either way.
  7. On success: call `AutoSyncService.instance.notifyLocalDataChangedNow()` and
     `ReminderService.notifyDataChanged()` so open pages/reminders pick up the restored data.
  8. If `result.missingImages > 0`, show the `backupRestoreMissingImages(n)` snackbar.
  9. Call [`_handlePostRestoreSync`](#handlepostrestoresync) with the pre-restore config (or
     `null` if WebDAV wasn't configured).
- **Usage:**
  ```dart
  IconButton(
    icon: const Icon(Icons.restore),
    tooltip: l10n.backupRestore,
    onPressed: b.corrupt ? null : () => _restoreBackup(b),
  ),
  ```
- **Notes:** Step 4's lack of a `mounted` gate is deliberate (see the file's own doc comment and
  [`../../../backup-restore.md`](../../../../backup-restore.md)) — gating it on `mounted` would risk
  skipping the disable if the page were disposed between the `await` and the check, which is
  exactly the failure mode this code exists to prevent. The re-enable branch in step 6 is the only
  place auto-sync is ever turned back on automatically; a partially-written failed restore
  (`wroteAnything == true`) leaves auto-sync off until the user sorts it out manually.

### `Future<void> _handlePostRestoreSync(WebDAVConfig? config)` <a id="handlepostrestoresync"></a>
- **Kind:** method of `_BackupPageState`
- **Source:** `lib/features/settings/views/backup_page.dart` (line 194)
- **Purpose:** After a successful restore, offer to force-upload the restored (now-older) data to
  the configured WebDAV remote so it becomes the new source of truth everywhere, since auto-sync
  was already turned off before the restore.
- **Inputs:** `config` — the WebDAV config captured *before* the restore ran, or `null` if WebDAV
  sync isn't configured.
- **Returns:** None.
- **Side effects:** May force-upload local data/images to the WebDAV remote under the sync wake
  lock, record the result with `AutoSyncService`, and show a dialog/snackbar.
- **Algorithm:**
  1. If `config == null` (WebDAV not configured), just show the `backupRestored` snackbar and
     return — there's nothing to offer to sync.
  2. Otherwise show a non-dismissible (`barrierDismissible: false`) `AlertDialog` explaining that
     sync is now disabled, offering "force upload" or "skip".
  3. If the user didn't choose force upload (dismissed, chose skip, or the page was unmounted),
     return without touching the remote — auto-sync stays off until the user re-enables it
     manually.
  4. Otherwise: `SyncWakeLock.acquire()`
     ([`../../../shared/services/sync_wake_lock.md#acquire`](../../../shared/services/sync_wake_lock.md#acquire)),
     call `WebDAVService.forceUpload(config)`
     ([`../../../shared/services/webdav_service.md#forceupload`](../../../shared/services/webdav_service.md#forceupload))
     inside a `try`/`finally` that always releases the wake lock
     ([`#release`](../../../shared/services/sync_wake_lock.md#release)), then record the result via
     `AutoSyncService.instance.recordSyncResult(result)` and show a success/failure snackbar.
- **Usage:**
  ```dart
  // Tail of _restoreBackup, after a successful restore:
  if (!mounted) return;
  await _handlePostRestoreSync(webDavConfigured ? config : null);
  ```
- **Notes:** This method never re-enables `autoSync` itself — per
  [`../../../backup-restore.md`](../../../../backup-restore.md), letting auto-sync resume and merge a
  freshly-restored (older) snapshot against a live remote could propagate stale records/deletions
  outward, so the user must explicitly re-enable it later from the WebDAV settings page.

### `Future<void> _deleteBackup(BackupInfo backup)` <a id="deletebackup"></a>
- **Kind:** method of `_BackupPageState`
- **Source:** `lib/features/settings/views/backup_page.dart` (line 252)
- **Purpose:** Confirm with the user, then permanently delete a backup bundle.
- **Inputs:** `backup` — the `BackupInfo` entry to delete.
- **Returns:** None.
- **Side effects:** Deletes the bundle file (and runs reference-counted blob GC inside
  `BackupService`); reloads the backup list.
- **Algorithm:**
  1. Show a confirm `AlertDialog`; if not confirmed (or the page was unmounted meanwhile), return.
  2. Await `BackupService.deleteBackup(backup.file)`
     ([`../../../shared/services/backup_service.md#deletebackup`](../../../shared/services/backup_service.md#deletebackup)).
  3. Call [`_load`](#load) to refresh the displayed history.
- **Usage:**
  ```dart
  IconButton(
    icon: const Icon(Icons.delete_outline),
    tooltip: l10n.delete,
    onPressed: () => _deleteBackup(b),
  ),
  ```
- **Notes:** Available even for `corrupt` bundles (unlike the restore button, which is disabled for
  them), since a corrupt bundle is still safe to delete.

### `Future<void> _toggleAutoBackup(bool value)` <a id="toggleautobackup"></a>
- **Kind:** method of `_BackupPageState`
- **Source:** `lib/features/settings/views/backup_page.dart` (line 282)
- **Purpose:** Persist the user's auto-backup on/off choice.
- **Inputs:** `value` — the new switch state.
- **Returns:** None.
- **Side effects:** Updates `BackupService.autoBackupEnabled` and writes it to disk via
  `BackupService.saveSettings()`.
- **Algorithm:**
  1. `setState` to update the local `_autoBackup` field immediately (optimistic UI update).
  2. Set the static `BackupService.autoBackupEnabled` field.
  3. Await `BackupService.saveSettings()`
     ([`../../../shared/services/backup_service.md#savesettings`](../../../shared/services/backup_service.md#savesettings))
     to persist it.
- **Usage:**
  ```dart
  SwitchListTile(
    secondary: const Icon(Icons.schedule_outlined),
    title: Text(l10n.backupAutoBackup),
    subtitle: Text(l10n.backupAutoBackupDesc),
    value: _autoBackup,
    onChanged: _toggleAutoBackup,
  ),
  ```
- **Notes:** None.

### `Future<void> _setRetention(int days)` <a id="setretention"></a>
- **Kind:** method of `_BackupPageState`
- **Source:** `lib/features/settings/views/backup_page.dart` (line 293)
- **Purpose:** Persist the user's chosen backup retention window.
- **Inputs:** `days` — one of the fixed `_retentionOptions` values (`0, 3, 7, 14, 30, 60, 90`; `0`
  means keep forever).
- **Returns:** None.
- **Side effects:** Updates `BackupService.retentionDays` and writes it to disk via
  `BackupService.saveSettings()`.
- **Algorithm:** Same three-step shape as [`_toggleAutoBackup`](#toggleautobackup): optimistic
  `setState`, update the static service field, then `await BackupService.saveSettings()`.
- **Usage:**
  ```dart
  DropdownButton<int>(
    value: _retentionDays,
    items: _retentionOptions.map((d) {
      final label = d == 0 ? l10n.backupKeepForever : l10n.backupKeepDays(d);
      return DropdownMenuItem(value: d, child: Text(label));
    }).toList(),
    onChanged: (v) {
      if (v != null) _setRetention(v);
    },
  ),
  ```
- **Notes:** This page only sets the value; the actual retention cleanup (deleting bundles older
  than `retentionDays`) runs inside `BackupService`, not here — see
  [`../../../backup-restore.md`](../../../../backup-restore.md).
