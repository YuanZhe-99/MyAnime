# lib/shared/views/webdav_config_page.dart

`WebDAVConfigPage` is the Settings -> WebDAV Sync screen: it edits a `WebDAVConfig`
(`lib/shared/services/webdav_service.dart`,
[`../services/webdav_service.md`](../services/webdav_service.md)), tests the connection, runs
manual sync, force-upload/force-download, and — the file's most substantial logic — walks the user
through resolving per-record sync conflicts one at a time via the private `_ConflictDialog` widget.
This page is the UI half of the ten-step sync flow, conflict handling, wake-lock, and force-op
rules documented in [`../../sync.md`](../../../sync.md), with a concrete worked conflict scenario in
[`../../examples/sync-walkthrough.md`](../../../examples/sync-walkthrough.md). Nearly every non-`build`
method here does real work (service calls under a busy flag and a screen wake lock, or actual
conflict-resolution branching) rather than pure widget composition, matching the "real
state/conflict-resolution logic" expected of this file.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `WebDAVConfigPage({super.key})` | constructor (`WebDAVConfigPage`) | B | Create a web dav config page instance. |
| `createState` | method (widget lifecycle) | B | Create the mutable state object for this widget. |
| `initState` | method (widget lifecycle) | B | Register the sync-status listener and kick off the config load. |
| `_refreshSyncStatus` | method (widget helper) | B | Rebuild the page when background sync status changes. |
| [`_loadConfig`](#loadconfig) | method (`_WebDAVConfigPageState`) | A | Load the persisted WebDAV config into the text controllers and flags. |
| `dispose` | method (widget lifecycle) | B | Release the sync-status listener and text controllers. |
| [`_currentConfig`](#currentconfig) | getter (`_WebDAVConfigPageState`) | A | Build a `WebDAVConfig` from the current form field values. |
| [`_saveConfig`](#saveconfig) | method (`_WebDAVConfigPageState`) | A | Persist the current form as the WebDAV config and request a sync if applicable. |
| [`_testConnection`](#testconnection) | method (`_WebDAVConfigPageState`) | A | Test connectivity to the configured WebDAV server. |
| [`_syncNow`](#syncnow) | method (`_WebDAVConfigPageState`) | A | Run a manual sync under the wake lock and route conflicts to resolution. |
| [`_showSyncResult`](#showsyncresult) | method (`_WebDAVConfigPageState`) | A | Present a non-conflict sync/force result as a dialog or snackbar. |
| [`_forceUpload`](#forceupload) | method (`_WebDAVConfigPageState`) | A | Confirm and run a destructive force upload (local overwrites remote). |
| [`_forceDownload`](#forcedownload) | method (`_WebDAVConfigPageState`) | A | Confirm and run a destructive force download (remote overwrites local). |
| `_confirmForceAction` | method (widget helper) | B | Show a shared yes/no confirmation dialog for a destructive force action. |
| [`_progressText`](#progresstext) | method (`_WebDAVConfigPageState`) | A | Map a `SyncProgress` snapshot to a localized status line. |
| [`_resolveConflicts`](#resolveconflicts) | method (`_WebDAVConfigPageState`) | A | Ask the user to resolve each pending sync conflict, then upload the result. |
| [`_disconnect`](#disconnect) | method (`_WebDAVConfigPageState`) | A | Delete the WebDAV config and reset the form. |
| `_fillNextcloud` | method (widget helper) | B | Prefill the form with a placeholder Nextcloud URL/path. |
| [`_syncStatusText`](#syncstatustext) | method (`_WebDAVConfigPageState`) | A | Build a short sync health summary line for display. |
| `build` | method (widget build) | B | Render the WebDAV config form and sync/status controls. |
| `_ConflictDialog({required conflict})` | constructor (`_ConflictDialog`) | B | Create a conflict dialog instance. |
| `build` | method (widget build) | B | Render the local-vs-remote comparison for one conflicting record. |

## Documentation

### `Future<void> _loadConfig()` <a id="loadconfig"></a>
- **Kind:** method of `_WebDAVConfigPageState`
- **Source:** `lib/shared/views/webdav_config_page.dart` (line 65)
- **Purpose:** Populate the form's text controllers and flags from the persisted `WebDAVConfig`, if
  one exists.
- **Inputs:** None.
- **Returns:** None (mutates the four `TextEditingController`s and `_isConfigured`/`_autoSync`).
- **Side effects:** Reads `webdav_config.json` via `WebDAVService.loadConfig()`.
- **Algorithm:**
  1. Await `WebDAVService.loadConfig()`
     ([`../services/webdav_service.md#loadconfig`](../services/webdav_service.md#loadconfig)).
  2. If a config was found, copy `serverUrl`/`username`/`password`/`remotePath` into the matching
     controllers and set `_isConfigured`/`_autoSync` from it.
  3. If still `mounted`, `setState` to clear `_loading`.
- **Usage:**
  ```dart
  @override
  void initState() {
    super.initState();
    AutoSyncService.instance.addOnStatusChanged(_refreshSyncStatus);
    _loadConfig();
  }
  ```
- **Notes:** If no config exists yet, the controllers keep their constructor defaults (an empty
  URL/user/password and `/MyAnime` as the remote path).

### `WebDAVConfig get _currentConfig` <a id="currentconfig"></a>
- **Kind:** getter of `_WebDAVConfigPageState`
- **Source:** `lib/shared/views/webdav_config_page.dart` (line 98)
- **Purpose:** Construct a `WebDAVConfig` snapshot from the form's current field values, trimmed of
  surrounding whitespace.
- **Inputs:** None (reads the four `TextEditingController`s and `_autoSync`).
- **Returns:** A new `WebDAVConfig`
  ([`../services/webdav_service.md#webdavconfig-new`](../services/webdav_service.md#webdavconfig-new)).
- **Side effects:** None.
- **Algorithm:** Build `WebDAVConfig(serverUrl: ..., username: ..., password: ..., remotePath:
  ..., autoSync: _autoSync)`, calling `.trim()` on each of the four text values.
- **Usage:** Read by every action that needs the config the user currently has typed in —
  ```dart
  Future<void> _saveConfig() async {
    final config = _currentConfig;
    await WebDAVService.saveConfig(config);
    ...
  }
  ```
  and similarly by [`_testConnection`](#testconnection), [`_syncNow`](#syncnow),
  [`_forceUpload`](#forceupload), [`_forceDownload`](#forcedownload), and
  [`_resolveConflicts`](#resolveconflicts).
- **Notes:** Because this is a getter (not a cached value), every call re-reads the controllers, so
  it always reflects the latest on-screen edits even if the user typed something after the page
  loaded but before saving.

### `Future<void> _saveConfig()` <a id="saveconfig"></a>
- **Kind:** method of `_WebDAVConfigPageState`
- **Source:** `lib/shared/views/webdav_config_page.dart` (line 111)
- **Purpose:** Persist the current form as the WebDAV config, and immediately request a sync if the
  saved config is both configured and has auto-sync on.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Writes `webdav_config.json` via `WebDAVService.saveConfig`; may trigger an
  immediate background sync via `AutoSyncService.requestSyncNow()`; shows a snackbar.
- **Algorithm:**
  1. Read [`_currentConfig`](#currentconfig) and `await WebDAVService.saveConfig(config)`
     ([`../services/webdav_service.md#saveconfig`](../services/webdav_service.md#saveconfig)).
  2. If `config.isConfigured && config.autoSync`, call
     `AutoSyncService.instance.requestSyncNow()`
     ([`../services/auto_sync_service.md#requestsyncnow`](../services/auto_sync_service.md#requestsyncnow))
     — per [`../../sync.md`](../../../sync.md), this is the "immediate sync right after
     enabling/saving auto-sync configuration" trigger.
  3. `setState` to refresh `_isConfigured`.
  4. If `mounted`, show the `settingsWebDAVConfigSaved` snackbar.
- **Usage:**
  ```dart
  Expanded(
    child: FilledButton(
      onPressed: _saveConfig,
      child: Text(l10n.save),
    ),
  ),
  ```
  Also called directly from the auto-sync `SwitchListTile`'s `onChanged`, so toggling auto-sync
  saves immediately without a separate "Save" tap.
- **Notes:** None.

### `Future<void> _testConnection()` <a id="testconnection"></a>
- **Kind:** method of `_WebDAVConfigPageState`
- **Source:** `lib/shared/views/webdav_config_page.dart` (line 134)
- **Purpose:** Verify that the currently-entered WebDAV credentials/URL can actually reach the
  server, without saving anything.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Performs a network request via `WebDAVService.testConnection`; shows a
  success/failure snackbar; toggles `_testing` (drives the button's spinner).
- **Algorithm:**
  1. `setState(() => _testing = true)`.
  2. Await `WebDAVService.testConnection(_currentConfig)`
     ([`../services/webdav_service.md#testconnection`](../services/webdav_service.md#testconnection)).
  3. If `mounted`, `setState(() => _testing = false)` and show
     `settingsWebDAVConnectionSuccess`/`settingsWebDAVConnectionFailed` based on the result.
- **Usage:**
  ```dart
  Expanded(
    child: OutlinedButton(
      onPressed: _testing ? null : _testConnection,
      child: _testing
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Text(l10n.settingsWebDAVTestConnection),
    ),
  ),
  ```
- **Notes:** Uses the unsaved [`_currentConfig`](#currentconfig), so the user can test credentials
  before committing them with `_saveConfig`.

### `Future<void> _syncNow()` <a id="syncnow"></a>
- **Kind:** method of `_WebDAVConfigPageState`
- **Source:** `lib/shared/views/webdav_config_page.dart` (line 160)
- **Purpose:** Run a full manual sync cycle (the ten-step flow in
  [`../../sync.md`](../../../sync.md)) under the screen wake lock, then either route any conflicts to
  resolution or show the plain result.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Holds the sync wake lock for the duration; may write local data/image files and
  upload to the WebDAV remote via `WebDAVService.sync`; records the outcome with
  `AutoSyncService`; may trigger a local-data-changed notification; shows a dialog or snackbar.
- **Algorithm:**
  1. `setState(() => _syncing = true)`.
  2. `await SyncWakeLock.acquire()`
     ([`../services/sync_wake_lock.md#acquire`](../services/sync_wake_lock.md#acquire)).
  3. In a `try`/`finally`: run `WebDAVService.sync(_currentConfig)` (this repo calls
     `WebDAVService.sync` with the default `autoResolve: false`, matching the "manual sync never
     silently resolves conflicts" rule in [`../../sync.md`](../../../sync.md)); the `finally` always
     releases the wake lock and resets `_syncing`, regardless of success/failure/exception.
  4. If unmounted after the `await`, return.
  5. `AutoSyncService.instance.recordSyncResult(result)`
     ([`../services/auto_sync_service.md#recordsyncresult`](../services/auto_sync_service.md#recordsyncresult))
     and `.notifyLocalDataChangedIfNeeded()`
     ([`#notifylocaldatachangedifneeded`](../services/auto_sync_service.md#notifylocaldatachangedifneeded)).
  6. If `result.hasConflicts`, delegate the rest of the flow to
     [`_resolveConflicts(result)`](#resolveconflicts) and return.
  7. Otherwise show the plain result via [`_showSyncResult(result)`](#showsyncresult).
- **Usage:**
  ```dart
  FilledButton.icon(
    onPressed: _syncing ? null : () => _syncNow(),
    icon: _syncing
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : const Icon(Icons.sync),
    label: Text(_syncing ? l10n.settingsWebDAVSyncing : l10n.settingsWebDAVSyncNow),
  ),
  ```
- **Notes:** The wake lock and `_syncing` flag are reset in `finally`, so an exception thrown by
  `WebDAVService.sync` still leaves the UI in a clean, re-triggerable state (matching the "released
  in a `finally` block on completion, failure, cancellation, or exception" rule in
  [`../../sync.md`](../../../sync.md)).

### `Future<void> _showSyncResult(SyncResult result)` <a id="showsyncresult"></a>
- **Kind:** method of `_WebDAVConfigPageState`
- **Source:** `lib/shared/views/webdav_config_page.dart` (line 187)
- **Purpose:** Present a sync/force-op result that has no pending conflicts, choosing between a
  failure dialog, a warnings dialog, or a plain success snackbar.
- **Inputs:** `result` — the `SyncResult` to display (`hasConflicts` is assumed false by the
  caller).
- **Returns:** None.
- **Side effects:** Shows an `AlertDialog` (for failure or warnings) or a `SnackBar` (for plain
  success).
- **Algorithm:**
  1. If `!result.success`, show an `AlertDialog` with `result.error` (or `'-'`) in a
     `SelectableText` and return.
  2. Else if `result.warnings.isNotEmpty`, show an `AlertDialog` listing the warning count and each
     warning string, and return — this is the UI surface for the image-sync warnings described in
     [`../../sync.md`](../../../sync.md) ("Remote image directory listings return `null` on any
     failure... skips the image phase with a visible warning").
  3. Otherwise show the plain `settingsWebDAVSyncSuccess` snackbar.
- **Usage:** Called from [`_syncNow`](#syncnow) (non-conflict path), [`_forceUpload`](#forceupload),
  and [`_forceDownload`](#forcedownload) — always as the final step after recording the result.
- **Notes:** Per [`../../sync.md`](../../../sync.md), "Sync errors and image transfer warnings are
  shown in dialogs, not only snackbars, since they need to stay visible" — this method is exactly
  where that rule is implemented; only the fully-clean case falls through to a transient snackbar.

### `Future<void> _forceUpload()` <a id="forceupload"></a>
- **Kind:** method of `_WebDAVConfigPageState`
- **Source:** `lib/shared/views/webdav_config_page.dart` (line 257)
- **Purpose:** After explicit user confirmation, overwrite the remote data/images with the local
  copy, bypassing merge entirely.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Shows a destructive-confirmation dialog; holds the sync wake lock; overwrites
  the WebDAV remote via `WebDAVService.forceUpload`; records the result; shows the outcome.
- **Algorithm:**
  1. `await _confirmForceAction(...)` with the force-upload confirmation copy; if not confirmed (or
     unmounted), stop.
  2. `setState(() => _syncing = true)`, `await SyncWakeLock.acquire()`.
  3. In `try`/`finally`: `WebDAVService.forceUpload(_currentConfig)`
     ([`../services/webdav_service.md#forceupload`](../services/webdav_service.md#forceupload));
     `finally` releases the wake lock and resets `_syncing`.
  4. If unmounted, return; otherwise `recordSyncResult`, `notifyLocalDataChangedIfNeeded`, and
     [`_showSyncResult(result)`](#showsyncresult).
- **Usage:**
  ```dart
  Expanded(
    child: OutlinedButton.icon(
      onPressed: _syncing ? null : _forceUpload,
      icon: const Icon(Icons.upload, size: 18),
      label: Text(l10n.settingsWebDAVForceUpload),
    ),
  ),
  ```
  Also invoked (via `WebDAVService.forceUpload` directly, not this method) from `backup_page.dart`
  after a restore — see
  [`../../../features/settings/views/backup_page.md#handlepostrestoresync`](../../features/settings/views/backup_page.md#handlepostrestoresync).
- **Notes:** Mirrors [`_forceDownload`](#forcedownload) almost exactly, differing only in which
  confirmation copy and which `WebDAVService` method is called. The wake lock is only acquired
  after confirmation, per the rule in [`../../sync.md`](../../../sync.md).

### `Future<void> _forceDownload()` <a id="forcedownload"></a>
- **Kind:** method of `_WebDAVConfigPageState`
- **Source:** `lib/shared/views/webdav_config_page.dart` (line 288)
- **Purpose:** After explicit user confirmation, overwrite the local data/images with the remote
  copy, bypassing merge entirely.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Shows a destructive-confirmation dialog; holds the sync wake lock; overwrites
  local files via `WebDAVService.forceDownload`; records the result; shows the outcome.
- **Algorithm:** Identical shape to [`_forceUpload`](#forceupload), calling
  `WebDAVService.forceDownload(_currentConfig)`
  ([`../services/webdav_service.md#forcedownload`](../services/webdav_service.md#forcedownload))
  instead.
- **Usage:**
  ```dart
  Expanded(
    child: OutlinedButton.icon(
      onPressed: _syncing ? null : _forceDownload,
      icon: const Icon(Icons.download, size: 18),
      label: Text(l10n.settingsWebDAVForceDownload),
    ),
  ),
  ```
- **Notes:** Per [`../../sync.md`](../../../sync.md), `forceDownload` takes **no** remote lock (unlike
  `forceUpload`, which uploads under `.lock`); this method itself doesn't distinguish that — it
  just awaits whichever `SyncResult` comes back.

### `String _progressText(AppLocalizations l10n, SyncProgress progress)` <a id="progresstext"></a>
- **Kind:** method of `_WebDAVConfigPageState`
- **Source:** `lib/shared/views/webdav_config_page.dart` (line 349)
- **Purpose:** Translate one `SyncProgress` phase snapshot into a localized status line shown under
  the progress bar while a sync/force operation is running.
- **Inputs:** `l10n` — current `AppLocalizations`; `progress` — a `SyncProgress` value from
  `WebDAVService.progress` (`ValueNotifier<SyncProgress>`,
  [`../../sync.md`](../../../sync.md#syncprogress-phases)).
- **Returns:** A localized `String`, or `''` for the `idle`/`done`/`error` phases (nothing useful
  to show under the progress bar for those).
- **Side effects:** None.
- **Algorithm:** `switch (progress.phase)`: `connecting` -> plain label;
  `downloadingData`/`uploadingData`/`merging` -> label parameterized with `progress.detail`
  (file name) and, for `downloadingData`, also `current`/`total`; `uploadingImages`/
  `downloadingImages` -> label parameterized with `current`/`total`; `idle`/`done`/`error` -> `''`.
- **Usage:**
  ```dart
  ValueListenableBuilder<SyncProgress>(
    valueListenable: WebDAVService.progress,
    builder: (context, progress, _) {
      if (!progress.isRunning) return const SizedBox.shrink();
      return Column(
        children: [
          LinearProgressIndicator(value: progress.fraction),
          Text(_progressText(l10n, progress), style: theme.textTheme.bodySmall),
        ],
      );
    },
  ),
  ```
- **Notes:** The `switch` is exhaustive over `SyncPhase` (no `default` branch) — a new phase value
  added to the enum without updating this `switch` would fail to compile, which is a deliberate
  safety net for this presentation-only mapping.

### `Future<void> _resolveConflicts(SyncResult result)` <a id="resolveconflicts"></a>
- **Kind:** method of `_WebDAVConfigPageState`
- **Source:** `lib/shared/views/webdav_config_page.dart` (line 387)
- **Purpose:** Walk the user through resolving every pending per-record sync conflict one at a
  time, then upload the fully-resolved data under a freshly-acquired lock.
- **Inputs:** `result` — a `SyncResult` with `result.pending` non-null (i.e. `hasConflicts` was
  true).
- **Returns:** None.
- **Side effects:** Shows one non-dismissible `_ConflictDialog` per conflict; holds the sync wake
  lock while finalizing; force-uploads the resolved data via
  `WebDAVService.finalizePendingSync`; records the outcome; shows a snackbar.
- **Algorithm:** (matches the conflict branch of the ten-step flow in
  [`../../sync.md`](../../../sync.md), worked through concretely in
  [`../../examples/sync-walkthrough.md`](../../../examples/sync-walkthrough.md), Scenario 2)
  1. For each `conflict` in `result.pending!.allConflicts`: if unmounted, stop; show
     `_ConflictDialog(conflict: conflict)` (`barrierDismissible: false`) and await the user's chosen
     `Anime` record (`local` or `remote`).
  2. **If the user dismisses a dialog** (returns `null`, e.g. system back): record the original
     `result` via `AutoSyncService.recordSyncResult` (leaving the conflict pending), show the
     `settingsWebDAVSyncFailed` snackbar, and return immediately — no upload happens and no
     remaining conflicts are even shown.
  3. Otherwise store `resolutions[conflict.id] = chosen` and continue to the next conflict.
  4. Once every conflict has a resolution: `await SyncWakeLock.acquire()`, then in `try`/`finally`
     call `WebDAVService.finalizePendingSync(_currentConfig, pending, resolutions)`
     ([`../services/webdav_service.md#finalizependingsync`](../services/webdav_service.md#finalizependingsync))
     — `finally` always releases the wake lock.
  5. `AutoSyncService.instance.recordFinalizeResult(ok)`
     ([`../services/auto_sync_service.md#recordfinalizeresult`](../services/auto_sync_service.md#recordfinalizeresult)).
  6. If still `mounted`, show `settingsWebDAVSyncSuccess` or `settingsWebDAVSyncFailed` depending on
     `ok`.
- **Usage:**
  ```dart
  if (result.hasConflicts) {
    await _resolveConflicts(result);
    return;
  }
  ```
  (from [`_syncNow`](#syncnow), the only caller).
- **Notes:** This method never notifies `AutoSyncService.notifyLocalDataChangedIfNeeded()` itself
  after a successful finalize — that notification already happened in `_syncNow` before this method
  was even called, for the initial (conflicting) sync attempt. `_currentConfig` is re-read fresh
  for the `finalizePendingSync` call, in case the user edited the form while resolving conflicts.

### `Future<void> _disconnect()` <a id="disconnect"></a>
- **Kind:** method of `_WebDAVConfigPageState`
- **Source:** `lib/shared/views/webdav_config_page.dart` (line 446)
- **Purpose:** Remove the persisted WebDAV configuration entirely and reset the form to its
  unconfigured defaults.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Deletes `webdav_config.json` via `WebDAVService.deleteConfig()`; clears the
  form controllers; shows a snackbar.
- **Algorithm:**
  1. `await WebDAVService.deleteConfig()`
     ([`../services/webdav_service.md#deleteconfig`](../services/webdav_service.md#deleteconfig)).
  2. Clear the URL/user/password controllers and reset the path controller to `/MyAnime`.
  3. `setState` to clear `_isConfigured` and `_autoSync`.
  4. If `mounted`, show `settingsWebDAVConfigRemoved`.
- **Usage:**
  ```dart
  OutlinedButton.icon(
    onPressed: _disconnect,
    icon: const Icon(Icons.link_off),
    label: Text(l10n.settingsWebDAVDisconnect),
    style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
  ),
  ```
- **Notes:** No confirmation dialog guards this action — unlike `_forceUpload`/`_forceDownload`,
  disconnecting has no `_confirmForceAction` step before it runs.

### `String? _syncStatusText(AppLocalizations l10n)` <a id="syncstatustext"></a>
- **Kind:** method of `_WebDAVConfigPageState`
- **Source:** `lib/shared/views/webdav_config_page.dart` (line 484)
- **Purpose:** Build the short sync-health line shown above the progress indicator, reflecting
  `AutoSyncService`'s last recorded outcome.
- **Inputs:** `l10n` — current `AppLocalizations`.
- **Returns:** A localized status string, or `null` if there is neither an error nor a recorded
  success timestamp yet.
- **Side effects:** None (pure read of `AutoSyncService.instance` state).
- **Algorithm:**
  1. If `AutoSyncService.instance.lastError != null`: return the conflict-flavored or
     failure-flavored message (`settingsWebDAVAutoSyncConflict`/`settingsWebDAVAutoSyncFailed`)
     depending on `hasPendingConflicts`, followed by the raw error string.
  2. Else if `lastSuccessAt != null`: return `settingsWebDAVLastSuccess` followed by the localized
     timestamp (`.toLocal()`).
  3. Else return `null`.
- **Usage:**
  ```dart
  @override
  Widget build(BuildContext context) {
    final syncStatus = _syncStatusText(l10n);
    ...
  ```
- **Notes:** This is the same status text and error-vs-conflict branching also surfaced on the main
  Settings page's WebDAV row (`functions/features/settings/views/settings_page.md`), read there
  directly from `AutoSyncService.instance.lastError`/`hasPendingConflicts` rather than through this
  helper — the two pages independently format the same underlying state.
