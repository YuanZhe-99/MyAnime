# lib/shared/services/auto_sync_service.dart

**Facade over the shared scheduler.** The lifecycle observer, 30-second save debounce, 15-minute
periodic timer, in-flight guard, and status bookkeeping moved to the `myapps_data` package
(`lib/src/sync/auto_sync_scheduler.dart`). This app's extras stay here as hooks.

## Hooks this app supplies

| Hook | Value |
|---|---|
| `isAutoSyncActive` | Config exists, is configured, and has `autoSync` enabled. |
| `runSync` | `WebDAVService.sync(config)` — never with `autoResolve`. |
| `consumeLocalDataChanged` | `WebDAVService.consumeLocalDataChanged`. |
| `onPeriodicTick` | `BackupService.runAutoBackupIfNeeded`, so a desktop instance left running across midnight still takes its daily backup. |
| `onResume` | The daily backup **and** `ReminderService.notifyDataChanged()`. |

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `instance` | static field | A | The singleton. |
| `lastSuccessAt` / `lastFailureAt` / `lastError` / `hasPendingConflicts` | getters | A | In-memory sync status for the settings UI. |
| `addOnLocalDataChanged` / `removeOnLocalDataChanged` | methods | A | Register and remove UI reload callbacks. |
| `addOnStatusChanged` / `removeOnStatusChanged` | methods | A | Register and remove status-change callbacks. |
| `recordSyncResult(result)` | method | A | Record a manually triggered sync into the same status path. |
| `recordFinalizeResult(ok)` | method | A | Record a conflict finalization. |
| `notifyLocalDataChangedIfNeeded()` | method | A | Fire reload callbacks **if** the engine flag is set. |
| `notifyLocalDataChangedNow()` | method | A | Fire reload callbacks unconditionally (restore, ZIP import). |
| `start()` / `stop()` | methods | A | Begin and end observing lifecycle and running timers. |
| `notifySaved()` | method | A | Storage hook: restart the 30-second debounce. |
| `requestSyncNow()` | method | A | Cancel any pending debounce and sync immediately. |

## Notes

- Status is in-memory only and is never persisted.
- Auto-sync leaves `autoResolve` disabled: true two-sided conflicts are recorded as visible pending
  status rather than silently applying last-writer-wins.
- Overlapping triggers are silently skipped by the in-flight guard, so a background tick never
  surfaces a spurious "sync already in progress" banner.
- `notifySaved()` is ignored before `start()`, so early storage writes cannot schedule a sync while
  the service is not yet observing the lifecycle.
- Launch, resume, and the periodic tick all cancel a pending debounce before syncing.

## Where the scheduler documentation lives

`packages/myapps_data/doc/en-us/functions/src/sync/auto_sync_scheduler.md`.
