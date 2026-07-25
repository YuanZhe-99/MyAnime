/// Purpose: MyAnime's auto-sync trigger service, now a facade over the shared
/// `AutoSyncScheduler` from the `myapps_data` package.
/// Inputs: Lifecycle events, storage saves, and manual sync results.
/// Returns: Sync status for the settings UI.
/// Side effects: Schedules and runs background syncs; runs the daily backup.
/// Notes: The scheduler owns only the trigger topology —
/// launch, resume, the 15-minute timer, and the 30-second save debounce. What
/// MyAnime does that the other apps do not stays here as hooks: the periodic
/// tick and resume both run the daily auto-backup, and resume also refreshes
/// reminders. Every public member kept its name and signature (I7).
library;

import 'package:flutter/widgets.dart';
import 'package:myapps_data/myapps_data.dart' as shared;

import 'backup_service.dart';
import 'reminder_service.dart';
import 'webdav_service.dart';

/// Singleton service that triggers WebDAV sync automatically when enabled.
class AutoSyncService {
  /// Purpose: Prevent direct instantiation and expose only the singleton.
  /// Inputs: None.
  /// Returns: A new `AutoSyncService._` instance.
  /// Side effects: Builds the shared scheduler with MyAnime's hooks.
  /// Notes: Implementations should preserve this contract.
  AutoSyncService._();
  static final instance = AutoSyncService._();

  /// Shared scheduler wired to MyAnime's trigger topology.
  late final shared.AutoSyncScheduler _scheduler = shared.AutoSyncScheduler(
    isAutoSyncActive: () async {
      final config = await WebDAVService.loadConfig();
      return config != null && config.isConfigured && config.autoSync;
    },
    runSync: () async {
      final config = await WebDAVService.loadConfig();
      // The gate above already ran; a config that vanished in between simply
      // reports failure rather than throwing.
      if (config == null) {
        return const shared.AutoSyncResult(success: false);
      }
      final result = await WebDAVService.sync(config);
      return shared.AutoSyncResult(
        success: result.success,
        hasConflicts: result.hasConflicts,
        error: result.error,
      );
    },
    consumeLocalDataChanged: WebDAVService.consumeLocalDataChanged,
    // The periodic timer also runs the daily auto-backup check so a desktop
    // instance left running across midnight still creates its daily backup
    // without a launch or resume event.
    onPeriodicTick: BackupService.runAutoBackupIfNeeded,
    // On resume also refresh mobile reminder schedules so per-day notification
    // bodies are recomputed from current data after suspension.
    onResume: () async {
      await BackupService.runAutoBackupIfNeeded();
      ReminderService.notifyDataChanged();
    },
  );

  /// Purpose: Return the last successful sync time recorded by this service.
  /// Inputs: None.
  /// Returns: `DateTime?`.
  /// Side effects: None.
  /// Notes: Used by settings UI to surface sync health.
  DateTime? get lastSuccessAt => _scheduler.lastSuccessAt;

  /// Purpose: Return the last failed sync time recorded by this service.
  /// Inputs: None.
  /// Returns: `DateTime?`.
  /// Side effects: None.
  /// Notes: Used by settings UI to surface sync health.
  DateTime? get lastFailureAt => _scheduler.lastFailureAt;

  /// Purpose: Return the most recent sync failure message.
  /// Inputs: None.
  /// Returns: `String?`.
  /// Side effects: None.
  /// Notes: Null after a successful sync.
  String? get lastError => _scheduler.lastError;

  /// Purpose: Return whether auto-sync found conflicts needing manual resolution.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Conflicts are not auto-resolved during background sync.
  bool get hasPendingConflicts => _scheduler.hasPendingConflicts;

  /// Purpose: Register a callback invoked when auto-sync updates local data.
  /// Inputs: `cb`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Register a callback invoked when auto-sync updates local data.
  void addOnLocalDataChanged(void Function() cb) =>
      _scheduler.addOnLocalDataChanged(cb);

  /// Purpose: Remove a previously registered callback.
  /// Inputs: `cb`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Remove a previously registered callback.
  void removeOnLocalDataChanged(void Function() cb) =>
      _scheduler.removeOnLocalDataChanged(cb);

  /// Purpose: Register a callback invoked when sync status changes.
  /// Inputs: `cb`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: UI pages use this to refresh visible sync warnings.
  void addOnStatusChanged(VoidCallback cb) => _scheduler.addOnStatusChanged(cb);

  /// Purpose: Remove a previously registered sync-status callback.
  /// Inputs: `cb`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Must be paired with `addOnStatusChanged` in widget dispose.
  void removeOnStatusChanged(VoidCallback cb) =>
      _scheduler.removeOnStatusChanged(cb);

  /// Purpose: Record a sync result triggered outside the auto-sync loop.
  /// Inputs: `result`.
  /// Returns: None.
  /// Side effects: Updates sync status and notifies listeners.
  /// Notes: Manual sync pages call this so status banners clear after success.
  void recordSyncResult(SyncResult result) => _scheduler.recordSyncResult(
    shared.AutoSyncResult(
      success: result.success,
      hasConflicts: result.hasConflicts,
      error: result.error,
    ),
  );

  /// Purpose: Notify UI reload listeners after a manual sync or force
  /// operation wrote local data files.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Consumes the WebDAV local-data-changed flag and invokes
  /// registered reload callbacks.
  /// Notes: Manual sync pages call this so open pages reload without waiting
  /// for the next background sync.
  void notifyLocalDataChangedIfNeeded() =>
      _scheduler.notifyLocalDataChangedIfNeeded();

  /// Purpose: Notify UI reload listeners unconditionally after local data
  /// files were replaced outside of sync (backup restore, ZIP import).
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Invokes registered reload callbacks.
  /// Notes: Unlike [notifyLocalDataChangedIfNeeded] this does not depend on
  /// the WebDAV local-data-changed flag.
  void notifyLocalDataChangedNow() => _scheduler.notifyLocalDataChangedNow();

  /// Purpose: Record a conflict-finalization result.
  /// Inputs: `ok`.
  /// Returns: None.
  /// Side effects: Updates sync status and notifies listeners.
  /// Notes: Used after users resolve conflicts manually.
  void recordFinalizeResult(bool ok) => _scheduler.recordFinalizeResult(ok);

  /// Purpose: Begin observing the app lifecycle and start the sync timers.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Registers a lifecycle observer, syncs once, and starts the
  /// 15-minute periodic timer.
  /// Notes: Idempotent — a second call while started is ignored.
  void start() => _scheduler.start();

  /// Purpose: Stop the timers and stop observing the app lifecycle.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Cancels the debounce and periodic timers.
  /// Notes: None.
  void stop() => _scheduler.stop();

  /// Purpose: Called by storage save methods to schedule a debounced sync.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Restarts the 30-second debounce timer.
  /// Notes: Ignored before `start()` so early storage writes cannot schedule
  /// a sync while the service is not yet observing the app lifecycle.
  void notifySaved() => _scheduler.notifySaved();

  /// Purpose: Trigger a sync as soon as possible without waiting for the debounce timer.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Cancels any pending debounce and starts a sync.
  /// Notes: Overlapping triggers are silently skipped by the in-flight guard.
  void requestSyncNow() => _scheduler.requestSyncNow();
}
