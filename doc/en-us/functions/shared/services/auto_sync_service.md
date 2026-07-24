# lib/shared/services/auto_sync_service.dart

The singleton (`AutoSyncService.instance`) that triggers `WebDAVService.sync()` in the background —
on app launch/resume, a 30-second debounce after storage saves, immediately after saving WebDAV
config, and on a 15-minute periodic timer that also runs the daily auto-backup check (see
[`backup_service.md`](backup_service.md) / [`../../../backup-restore.md`](../../../backup-restore.md)).
It records the latest success/failure/pending-conflict state in memory so Settings and the WebDAV
page can surface sync health, and exposes two independent callback registries so UI pages can
reload after a background sync writes local data, or refresh a visible sync-status banner. See
[`../../../sync.md`](../../../sync.md) "Auto-sync triggers" for the full trigger list and the
`WidgetsBindingObserver` lifecycle rationale.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `AutoSyncService._()` | constructor (`AutoSyncService`) | B | Prevent direct instantiation; expose only the `instance` singleton. |
| [`lastSuccessAt`](#lastsuccessat) | getter (`AutoSyncService`) | B | Last successful sync time. |
| [`lastFailureAt`](#lastfailureat) | getter (`AutoSyncService`) | B | Last failed sync time. |
| [`lastError`](#lasterror) | getter (`AutoSyncService`) | B | Most recent sync failure message. |
| [`hasPendingConflicts`](#haspendingconflicts) | getter (`AutoSyncService`) | B | Whether auto-sync found unresolved conflicts. |
| [`addOnLocalDataChanged`](#addonlocaldatachanged) | method (`AutoSyncService`) | A | Register a callback for "local data changed" reloads. |
| [`removeOnLocalDataChanged`](#removeonlocaldatachanged) | method (`AutoSyncService`) | A | Unregister a local-data-changed callback. |
| [`addOnStatusChanged`](#addonstatuschanged) | method (`AutoSyncService`) | A | Register a callback for sync-status changes. |
| [`removeOnStatusChanged`](#removeonstatuschanged) | method (`AutoSyncService`) | A | Unregister a sync-status callback. |
| [`recordSyncResult`](#recordsyncresult) | method (`AutoSyncService`) | A | Record a sync result from outside the auto-sync loop (manual sync/force ops). |
| [`notifyLocalDataChangedIfNeeded`](#notifylocaldatachangedifneeded) | method (`AutoSyncService`) | A | Notify reload listeners if `WebDAVService` reports local data changed. |
| [`notifyLocalDataChangedNow`](#notifylocaldatachangednow) | method (`AutoSyncService`) | A | Unconditionally notify reload listeners (backup restore/ZIP import). |
| [`recordFinalizeResult`](#recordfinalizeresult) | method (`AutoSyncService`) | A | Record a conflict-finalization result. |
| [`start`](#start) | method (`AutoSyncService`) | A | Begin observing app lifecycle and start the periodic sync/backup timer. |
| [`stop`](#stop) | method (`AutoSyncService`) | A | Cancel timers and stop observing app lifecycle. |
| [`notifySaved`](#notifysaved) | method (`AutoSyncService`) | A | Schedule a debounced sync after a storage save. |
| [`requestSyncNow`](#requestsyncnow) | method (`AutoSyncService`) | A | Trigger a sync immediately, bypassing the debounce. |
| [`didChangeAppLifecycleState`](#didchangeapplifecyclestate) | method (`AutoSyncService`) | A | `WidgetsBindingObserver` override: resync and refresh reminders on resume. |
| [`_trySync`](#trysync) | method (`AutoSyncService`) | A | Run one auto-sync attempt if not already syncing and auto-sync is enabled. |
| [`_recordSuccess`](#recordsuccess) | method (`AutoSyncService`) | A | Update state for a successful sync. |
| [`_recordFailure`](#recordfailure) | method (`AutoSyncService`) | A | Update state for a failed sync or pending conflicts. |
| [`_notifyStatusChanged`](#notifystatuschanged) | method (`AutoSyncService`) | A | Invoke every registered status-changed callback. |

## Documentation

### `AutoSyncService._()`
(Table row only — trivial private constructor, Tier B; `static final instance = AutoSyncService._();` is the only place it's called, establishing the singleton.)

### `DateTime? get lastSuccessAt` <a id="lastsuccessat"></a>
(Table row only — trivial getter, Tier B; returns `_lastSuccessAt`, used by settings UI to surface sync health.)

### `DateTime? get lastFailureAt` <a id="lastfailureat"></a>
(Table row only — trivial getter, Tier B; returns `_lastFailureAt`.)

### `String? get lastError` <a id="lasterror"></a>
(Table row only — trivial getter, Tier B; returns `_lastError`, `null` after a successful sync.)

### `bool get hasPendingConflicts` <a id="haspendingconflicts"></a>
(Table row only — trivial getter, Tier B; returns `_hasPendingConflicts`, set by `_recordFailure(..., conflicts: true)`.)

### `void addOnLocalDataChanged(void Function() cb)` <a id="addonlocaldatachanged"></a>
- **Kind:** method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (line 68)
- **Purpose:** Register a callback invoked whenever auto-sync (or a manual sync/force operation routed through this service) writes new local data.
- **Inputs:** `cb`.
- **Returns:** None.
- **Side effects:** Appends `cb` to the internal `_onLocalDataChanged` list.
- **Algorithm:** `_onLocalDataChanged.add(cb)` — no de-duplication, so registering the same callback twice invokes it twice.
- **Usage:**
  ```dart
  @override
  void initState() {
    super.initState();
    AutoSyncService.instance.addOnLocalDataChanged(_load);
  }
  ```
  (`lib/features/anime/views/home_page.dart`; the same pattern is used by `management_page.dart` and `statistics_page.dart`)
- **Notes:** Must be paired with [`removeOnLocalDataChanged`](#removeonlocaldatachanged) in the widget's `dispose()`, or the callback (and the disposed widget's `State` it closes over) leaks.

### `void removeOnLocalDataChanged(void Function() cb)` <a id="removeonlocaldatachanged"></a>
- **Kind:** method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (line 76)
- **Purpose:** Unregister a previously registered local-data-changed callback.
- **Inputs:** `cb`.
- **Returns:** None.
- **Side effects:** Removes `cb` from `_onLocalDataChanged` (first matching instance, per `List.remove`).
- **Algorithm:** `_onLocalDataChanged.remove(cb)`.
- **Usage:**
  ```dart
  @override
  void dispose() {
    AutoSyncService.instance.removeOnLocalDataChanged(_load);
    super.dispose();
  }
  ```
  (`lib/features/anime/views/home_page.dart`)
- **Notes:** Requires the exact same function reference passed to `add` — a fresh closure/tear-off would not remove.

### `void addOnStatusChanged(VoidCallback cb)` <a id="addonstatuschanged"></a>
- **Kind:** method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (line 83)
- **Purpose:** Register a callback invoked whenever sync status (success/failure/pending-conflicts) changes, so UI can refresh a visible sync warning.
- **Inputs:** `cb`.
- **Returns:** None.
- **Side effects:** Appends `cb` to `_onStatusChanged`.
- **Algorithm:** `_onStatusChanged.add(cb)`.
- **Usage:**
  ```dart
  AutoSyncService.instance.addOnStatusChanged(_refreshSyncStatus);
  ```
  (`lib/features/settings/views/settings_page.dart` and `lib/shared/views/webdav_config_page.dart`)
- **Notes:** Same pairing requirement as `addOnLocalDataChanged` — pair with [`removeOnStatusChanged`](#removeonstatuschanged) in `dispose()`.

### `void removeOnStatusChanged(VoidCallback cb)` <a id="removeonstatuschanged"></a>
- **Kind:** method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (line 90)
- **Purpose:** Unregister a previously registered sync-status callback.
- **Inputs:** `cb`.
- **Returns:** None.
- **Side effects:** Removes `cb` from `_onStatusChanged`.
- **Algorithm:** `_onStatusChanged.remove(cb)`.
- **Usage:**
  ```dart
  AutoSyncService.instance.removeOnStatusChanged(_refreshSyncStatus);
  ```
  (`lib/features/settings/views/settings_page.dart`)
- **Notes:** None.

### `void recordSyncResult(SyncResult result)` <a id="recordsyncresult"></a>
- **Kind:** method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (line 97)
- **Purpose:** Record the outcome of a sync/force operation that ran *outside* the internal auto-sync loop (i.e. a manual sync or force upload/download triggered from a UI page) so status banners reflect it the same way a background sync would.
- **Inputs:** `result` (a `WebDAVService.SyncResult` — see [`webdav_service.md`](webdav_service.md)).
- **Returns:** None.
- **Side effects:** Calls [`_recordFailure`](#recordfailure) or [`_recordSuccess`](#recordsuccess), which update state and notify status listeners.
- **Algorithm:** If `result.hasConflicts`, record a failure with a conflicts-specific message (including `result.error` if present) and `conflicts: true`; else if `!result.success`, record a failure with `result.error` (or a generic message); else record success.
- **Usage:**
  ```dart
  result = await WebDAVService.forceUpload(_currentConfig);
  ...
  AutoSyncService.instance.recordSyncResult(result);
  AutoSyncService.instance.notifyLocalDataChangedIfNeeded();
  ```
  (`lib/shared/views/webdav_config_page.dart`, `_forceUpload`)
- **Notes:** This is exactly the same three-way dispatch [`_trySync`](#trysync) uses internally for background sync results, kept in sync so manual and automatic sync report status identically.

### `void notifyLocalDataChangedIfNeeded()` <a id="notifylocaldatachangedifneeded"></a>
- **Kind:** method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (line 118)
- **Purpose:** After a manual sync or force operation, reload any open page whose data was actually changed by that operation.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Consumes `WebDAVService`'s local-data-changed flag (see [`webdav_service.md`](webdav_service.md#consumelocaldatachanged)); if it was set, invokes every registered `_onLocalDataChanged` callback.
- **Algorithm:** `if (WebDAVService.consumeLocalDataChanged()) { for (final cb in List.of(_onLocalDataChanged)) cb(); }` — iterates a snapshot copy (`List.of(...)`) so a callback that registers/unregisters during iteration can't corrupt the loop.
- **Usage:**
  ```dart
  AutoSyncService.instance.notifyLocalDataChangedIfNeeded();
  ```
  (`lib/shared/views/webdav_config_page.dart`, after `_syncNow`/`_forceUpload`/`_forceDownload`)
- **Notes:** Unlike [`notifyLocalDataChangedNow`](#notifylocaldatachangednow), this is conditional on the WebDAV flag — calling it when nothing changed is a safe no-op.

### `void notifyLocalDataChangedNow()` <a id="notifylocaldatachangednow"></a>
- **Kind:** method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (line 133)
- **Purpose:** Reload open pages unconditionally after local data files were replaced by something other than WebDAV sync (backup restore, ZIP import).
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Invokes every registered `_onLocalDataChanged` callback.
- **Algorithm:** `for (final cb in List.of(_onLocalDataChanged)) cb();` — no flag check, unlike `notifyLocalDataChangedIfNeeded`.
- **Usage:**
  ```dart
  AutoSyncService.instance.notifyLocalDataChangedNow();
  ```
  (`lib/features/settings/views/backup_page.dart`, after a successful backup restore — see [`../../../backup-restore.md`](../../../backup-restore.md))
- **Notes:** Use this specifically when data changed through a path that never touches `WebDAVService`'s local-data-changed flag; using `notifyLocalDataChangedIfNeeded` there would silently skip the reload.

### `void recordFinalizeResult(bool ok)` <a id="recordfinalizeresult"></a>
- **Kind:** method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (line 144)
- **Purpose:** Record the outcome after the user manually resolves sync conflicts and `finalizePendingSync` runs.
- **Inputs:** `ok`.
- **Returns:** None.
- **Side effects:** Calls `_recordSuccess()` or `_recordFailure(...)`.
- **Algorithm:** `if (ok) _recordSuccess(); else _recordFailure('Failed to upload resolved sync conflicts');`
- **Usage:**
  ```dart
  ok = await WebDAVService.finalizePendingSync(_currentConfig, pending, resolutions);
  ...
  AutoSyncService.instance.recordFinalizeResult(ok);
  ```
  (`lib/shared/views/webdav_config_page.dart`)
- **Notes:** None.

### `void start()` <a id="start"></a>
- **Kind:** method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (line 159)
- **Purpose:** Begin the auto-sync lifecycle: observe app lifecycle events, run an immediate sync, and start the 15-minute periodic timer.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Registers `this` as a `WidgetsBindingObserver`; calls `requestSyncNow()` immediately; starts `Timer.periodic(_periodicSyncInterval, ...)` (15 minutes) that both requests a sync and calls `BackupService.runAutoBackupIfNeeded()` (see [`backup_service.md`](backup_service.md)) on every tick.
- **Algorithm:** Guarded by `_started` so calling `start()` twice is a no-op.
- **Usage:**
  ```dart
  AutoSyncService.instance.start();
  ```
  (`lib/main.dart`, app startup)
- **Notes:** The same periodic timer driving both sync and auto-backup checks is deliberate — it's what lets a desktop instance left running across midnight still create its daily backup without needing a fresh app launch or resume event (see [`../../../backup-restore.md`](../../../backup-restore.md)).

### `void stop()` <a id="stop"></a>
- **Kind:** method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (line 175)
- **Purpose:** Tear down the auto-sync lifecycle (not currently called anywhere in this repo, but provided for completeness/tests).
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Cancels both the debounce and periodic timers, removes `this` as a `WidgetsBindingObserver`, clears `_started`.
- **Algorithm:** Cancels `_debounce`/`_periodicSync` if set, nulls them, calls `WidgetsBinding.instance.removeObserver(this)`, sets `_started = false`.
- **Usage:** No call site currently in this repo's `lib/` code; the singleton is started once in `main.dart` and runs for the app's lifetime.
- **Notes:** Safe to call even if `start()` was never called, since cancelling a `null` timer is a no-op via `?.cancel()`.

### `void notifySaved()` <a id="notifysaved"></a>
- **Kind:** method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (line 190)
- **Purpose:** Called by storage save methods to schedule a debounced background sync after a local write.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Cancels any pending debounce timer and starts a new one for `_debounceDuration` (30 seconds).
- **Algorithm:** Returns immediately if `!_started` (ignored before `start()` runs, so early storage writes during app init can't schedule a sync while the service isn't yet observing the app lifecycle). Otherwise cancels the existing `_debounce` timer and creates a new `Timer(_debounceDuration, _trySync)` — so repeated saves within 30 seconds of each other coalesce into a single sync attempt.
- **Usage:**
  ```dart
  AutoSyncService.instance.notifySaved();
  ```
  (`lib/features/anime/services/anime_storage.dart`, after writing `anime_data.json`)
- **Notes:** Any storage-layer `save()` method should call this so non-UI writes are covered by auto-sync, per [`../../../sync.md`](../../../sync.md).

### `void requestSyncNow()` <a id="requestsyncnow"></a>
- **Kind:** method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (line 201)
- **Purpose:** Trigger a background sync attempt as soon as possible, bypassing the debounce timer.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Cancels any pending debounce timer; fires off `_trySync()` without awaiting it (`unawaited`).
- **Algorithm:** Cancel and null `_debounce`, then `unawaited(_trySync())`.
- **Usage:**
  ```dart
  if (config.isConfigured && config.autoSync) {
    AutoSyncService.instance.requestSyncNow();
  }
  ```
  (`lib/shared/views/webdav_config_page.dart`, immediately after saving WebDAV config — see [`../../../sync.md`](../../../sync.md) "Auto-sync triggers")
- **Notes:** Fire-and-forget — callers that need the result should call `WebDAVService.sync()` directly instead (as the manual sync/force-operation UI paths do) rather than relying on this method's return.

### `void didChangeAppLifecycleState(AppLifecycleState state)` <a id="didchangeapplifecyclestate"></a>
- **Kind:** method override of `AutoSyncService` (`WidgetsBindingObserver`)
- **Source:** `lib/shared/services/auto_sync_service.dart` (line 214)
- **Purpose:** React to the app resuming from the background: resync, check auto-backup, and refresh reminder schedules.
- **Inputs:** `state`.
- **Returns:** None.
- **Side effects:** On `AppLifecycleState.resumed`: calls `requestSyncNow()`, `BackupService.runAutoBackupIfNeeded()` ([`backup_service.md`](backup_service.md)), and `ReminderService.notifyDataChanged()`.
- **Algorithm:** Single `if (state == AppLifecycleState.resumed) { ... }` guard; no action on any other lifecycle state.
- **Usage:** Invoked by the Flutter framework automatically once `WidgetsBinding.instance.addObserver(this)` has run (inside [`start`](#start)) — not called directly by app code.
- **Notes:** Refreshing reminder schedules on resume recomputes per-day notification bodies from current data after the app may have been suspended for a long time.

### `Future<void> _trySync()` <a id="trysync"></a>
- **Kind:** method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (line 227)
- **Purpose:** Run one actual background sync attempt, if auto-sync is configured and enabled and no sync is already in flight.
- **Inputs:** None.
- **Returns:** A future that completes when the attempt (if any) finishes.
- **Side effects:** May call `WebDAVService.sync(config)`; updates success/failure/conflict state; notifies both callback registries as appropriate; sets/clears the internal `_syncing` guard.
- **Algorithm:**
  1. Return immediately if `_syncing` is already `true` (no concurrent auto-sync attempts).
  2. Load config via `WebDAVService.loadConfig()`; return if it's `null`, not `isConfigured`, or `autoSync` is off.
  3. Set `_syncing = true`; call `WebDAVService.sync(config)` (with `autoResolve` left at its default `false`).
  4. Dispatch the result exactly like [`recordSyncResult`](#recordsyncresult) does (conflicts → failure with conflicts message; `!success` → failure; else success).
  5. If `WebDAVService.consumeLocalDataChanged()` is true, invoke every `_onLocalDataChanged` callback (same pattern as `notifyLocalDataChangedIfNeeded`).
  6. Any exception is caught into `_recordFailure(e.toString())`.
  7. `finally` clears `_syncing`.
- **Usage:** Called internally by [`requestSyncNow`](#requestsyncnow) (via `unawaited`) and by the 15-minute periodic timer started in [`start`](#start); not called directly elsewhere.
- **Notes:** This is the actual background sync engine — every "auto-sync trigger" described in [`../../../sync.md`](../../../sync.md) ultimately funnels through either `requestSyncNow()` or the periodic timer into this method.

### `void _recordSuccess()` <a id="recordsuccess"></a>
- **Kind:** method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (line 261)
- **Purpose:** Update in-memory state to reflect a successful sync.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Sets `_lastSuccessAt = DateTime.now()`, clears `_lastError` and `_hasPendingConflicts`, notifies status listeners.
- **Algorithm:** Straight-line field assignment followed by `_notifyStatusChanged()`.
- **Usage:** Called from [`_trySync`](#trysync), [`recordSyncResult`](#recordsyncresult), and [`recordFinalizeResult`](#recordfinalizeresult) on success.
- **Notes:** None.

### `void _recordFailure(String error, {bool conflicts = false})` <a id="recordfailure"></a>
- **Kind:** method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (line 273)
- **Purpose:** Update in-memory state to reflect a failed sync or unresolved conflicts.
- **Inputs:** `error` message; `conflicts` (default `false`) — whether the failure is specifically pending record conflicts rather than a hard error.
- **Returns:** None.
- **Side effects:** Sets `_lastFailureAt = DateTime.now()`, `_lastError = error`, `_hasPendingConflicts = conflicts`, notifies status listeners.
- **Algorithm:** Straight-line field assignment followed by `_notifyStatusChanged()`.
- **Usage:** Called from [`_trySync`](#trysync), [`recordSyncResult`](#recordsyncresult), and [`recordFinalizeResult`](#recordfinalizeresult) on failure.
- **Notes:** `conflicts: true` and a hard failure both set `_lastError`/`_lastFailureAt` identically — only `_hasPendingConflicts` distinguishes them for the UI.

### `void _notifyStatusChanged()` <a id="notifystatuschanged"></a>
- **Kind:** method of `AutoSyncService`
- **Source:** `lib/shared/services/auto_sync_service.dart` (line 285)
- **Purpose:** Invoke every registered sync-status callback after state changes.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Invokes each callback in `_onStatusChanged`.
- **Algorithm:** `for (final cb in List.of(_onStatusChanged)) cb();` — iterates a snapshot copy so callbacks that add/remove listeners mid-iteration can't corrupt the loop.
- **Usage:** Called internally by [`_recordSuccess`](#recordsuccess) and [`_recordFailure`](#recordfailure) only.
- **Notes:** None.
