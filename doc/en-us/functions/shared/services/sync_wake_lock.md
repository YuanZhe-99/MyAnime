# lib/shared/services/sync_wake_lock.dart

A thin, reference-counted, ownership-tracked wrapper around the `wakelock_plus` plugin, used to
keep the screen awake during foreground WebDAV operations (manual sync, conflict finalize, force
upload/download). See [`../../../sync.md`](../../../sync.md) "Wake lock" section for the acquire/release
rules (reference-counted, only-if-not-already-held, acquired only after destructive-action
confirmation, released in `finally`, never used by background auto-sync). Callers are
`lib/shared/views/webdav_config_page.dart` and `lib/features/settings/views/backup_page.dart`.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`SyncWakeLock`](#syncwakelock) | class | A | Reference-counted, ownership-tracked wake lock for foreground sync operations. |
| `SyncWakeLock._()` | constructor (`SyncWakeLock`) | B | Prevent instantiation; only static members are used. |
| [`acquire`](#acquire) | static method (`SyncWakeLock`) | A | Acquire the wake lock for one foreground operation. |
| [`release`](#release) | static method (`SyncWakeLock`) | A | Release the wake lock for one foreground operation. |

## Documentation

### `class SyncWakeLock` <a id="syncwakelock"></a>
- **Kind:** class
- **Source:** `lib/shared/services/sync_wake_lock.dart` (line 14)
- **Purpose:** Keep the device/screen awake while a foreground sync operation is running, without fighting another feature that already holds a wake lock or double-disabling one shared by concurrent operations.
- **Inputs:** N/A (class-level).
- **Returns:** N/A.
- **Side effects:** Its two static methods enable/disable the platform wake lock through `wakelock_plus`.
- **Algorithm:** Maintains two static fields: `_refCount` (how many foreground operations currently hold the lock) and `_enabledBySync` (whether *this class* was the one that turned the platform wake lock on, as opposed to some other feature). See [`acquire`](#acquire)/[`release`](#release) for the exact reference-counting logic.
- **Usage:**
  ```dart
  await SyncWakeLock.acquire();
  try {
    result = await WebDAVService.sync(_currentConfig);
  } finally {
    await SyncWakeLock.release();
  }
  ```
  (`lib/shared/views/webdav_config_page.dart`, `_syncNow`)
- **Notes:** Background auto-sync (`AutoSyncService`, see [`auto_sync_service.md`](auto_sync_service.md)) must never call this class — only foreground, user-initiated operations hold the wake lock (see [`../../../sync.md`](../../../sync.md)).

### `SyncWakeLock._()`
(Table row only — trivial private constructor, Tier B; exists solely so the class cannot be instantiated and is used via static members only.)

### `static Future<void> acquire()` <a id="acquire"></a>
- **Kind:** static method of `SyncWakeLock`
- **Source:** `lib/shared/services/sync_wake_lock.dart` (line 33)
- **Purpose:** Acquire the wake lock for one foreground operation, sharing it with any already-in-flight operation.
- **Inputs:** None.
- **Returns:** A future completing once the wake-lock state (if changed) is applied.
- **Side effects:** On the first concurrent acquire (`_refCount` going 0→1), enables the platform wake lock via `WakelockPlus.enable()` — but only if it isn't already enabled by something else.
- **Algorithm:**
  1. Increment `_refCount`; if it's now greater than 1 (another operation already holds it), return immediately without touching the plugin.
  2. Otherwise, check `WakelockPlus.enabled`; if not already enabled, call `WakelockPlus.enable()` and record `_enabledBySync = true` (so `release()` knows *this* class turned it on).
  3. Any plugin exception is caught and swallowed — a wake-lock failure must never break the sync operation it's protecting.
- **Usage:**
  ```dart
  await SyncWakeLock.acquire();
  ```
  (`lib/shared/views/webdav_config_page.dart`, before `_syncNow`/`_forceUpload`/`_forceDownload`/conflict finalize; also `lib/features/settings/views/backup_page.dart` around a post-restore force upload)
- **Notes:** Acquired only *after* the user confirms a destructive force-action dialog, not before (see [`../../../sync.md`](../../../sync.md)).

### `static Future<void> release()` <a id="release"></a>
- **Kind:** static method of `SyncWakeLock`
- **Source:** `lib/shared/services/sync_wake_lock.dart` (line 53)
- **Purpose:** Release this operation's hold on the wake lock, disabling it only when the last holder releases and only if this class was the one that enabled it.
- **Inputs:** None.
- **Returns:** A future completing once the wake-lock state (if changed) is applied.
- **Side effects:** On the last concurrent release (`_refCount` reaching 0) and only if `_enabledBySync` is `true`, disables the platform wake lock via `WakelockPlus.disable()`.
- **Algorithm:**
  1. If `_refCount` is already 0, return immediately (safe to call when nothing is held).
  2. Decrement `_refCount`; if it's still greater than 0, or `_enabledBySync` is `false` (some other feature enabled the lock, not this class), return without touching the plugin.
  3. Otherwise set `_enabledBySync = false` and call `WakelockPlus.disable()`, swallowing any plugin exception.
- **Usage:**
  ```dart
  } finally {
    await SyncWakeLock.release();
    if (mounted) setState(() => _syncing = false);
  }
  ```
  (`lib/shared/views/webdav_config_page.dart`, `_syncNow`)
- **Notes:** Always called in a `finally` block, so completion, failure, cancellation, and exceptions all release the lock — never conditionally skipped on the happy path only.
