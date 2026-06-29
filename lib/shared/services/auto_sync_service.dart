import 'dart:async';

import 'package:flutter/widgets.dart';

import 'backup_service.dart';
import 'reminder_service.dart';
import 'webdav_service.dart';

/// Singleton service that triggers WebDAV sync automatically when enabled.
class AutoSyncService with WidgetsBindingObserver {
  /// Purpose: Prevent direct instantiation and expose only static members.
  /// Inputs: None.
  /// Returns: A new `AutoSyncService._` instance.
  /// Side effects: Implementation-dependent.
  /// Notes: Implementations should preserve this contract.
  AutoSyncService._();
  static final instance = AutoSyncService._();

  Timer? _debounce;
  Timer? _periodicSync;
  bool _syncing = false;
  bool _started = false;
  DateTime? _lastSuccessAt;
  DateTime? _lastFailureAt;
  String? _lastError;
  bool _hasPendingConflicts = false;

  static const _debounceDuration = Duration(seconds: 30);
  static const _periodicSyncInterval = Duration(minutes: 15);

  // Callbacks for UI reload after sync writes local files.
  final List<void Function()> _onLocalDataChanged = [];
  final List<VoidCallback> _onStatusChanged = [];

  /// Purpose: Return the last successful sync time recorded by this service.
  /// Inputs: None.
  /// Returns: `DateTime?`.
  /// Side effects: None.
  /// Notes: Used by settings UI to surface sync health.
  DateTime? get lastSuccessAt => _lastSuccessAt;

  /// Purpose: Return the last failed sync time recorded by this service.
  /// Inputs: None.
  /// Returns: `DateTime?`.
  /// Side effects: None.
  /// Notes: Used by settings UI to surface sync health.
  DateTime? get lastFailureAt => _lastFailureAt;

  /// Purpose: Return the most recent sync failure message.
  /// Inputs: None.
  /// Returns: `String?`.
  /// Side effects: None.
  /// Notes: Null after a successful sync.
  String? get lastError => _lastError;

  /// Purpose: Return whether auto-sync found conflicts needing manual resolution.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Conflicts are not auto-resolved during background sync.
  bool get hasPendingConflicts => _hasPendingConflicts;

  /// Purpose: Register a callback invoked when auto-sync updates local data.
  /// Inputs: `cb`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Register a callback invoked when auto-sync updates local data.
  void addOnLocalDataChanged(void Function() cb) => _onLocalDataChanged.add(cb);

  /// Purpose: Remove a previously registered callback.
  /// Inputs: `cb`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Remove a previously registered callback.
  void removeOnLocalDataChanged(void Function() cb) =>
      _onLocalDataChanged.remove(cb);

  /// Purpose: Register a callback invoked when sync status changes.
  /// Inputs: `cb`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: UI pages use this to refresh visible sync warnings.
  void addOnStatusChanged(VoidCallback cb) => _onStatusChanged.add(cb);

  /// Purpose: Remove a previously registered sync-status callback.
  /// Inputs: `cb`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Must be paired with `addOnStatusChanged` in widget dispose.
  void removeOnStatusChanged(VoidCallback cb) => _onStatusChanged.remove(cb);

  /// Purpose: Record a sync result triggered outside the auto-sync loop.
  /// Inputs: `result`.
  /// Returns: None.
  /// Side effects: Updates sync status and notifies listeners.
  /// Notes: Manual sync pages call this so status banners clear after success.
  void recordSyncResult(SyncResult result) {
    if (result.hasConflicts) {
      _recordFailure(
        'Sync conflicts require manual resolution${result.error != null ? ': ${result.error}' : ''}',
        conflicts: true,
      );
    } else if (!result.success) {
      _recordFailure(result.error ?? 'Unknown sync failure');
    } else {
      _recordSuccess();
    }
  }

  /// Purpose: Record a conflict-finalization result.
  /// Inputs: `ok`.
  /// Returns: None.
  /// Side effects: Updates sync status and notifies listeners.
  /// Notes: Used after users resolve conflicts manually.
  void recordFinalizeResult(bool ok) {
    if (ok) {
      _recordSuccess();
    } else {
      _recordFailure('Failed to upload resolved sync conflicts');
    }
  }

  /// Purpose: Implement the start behavior for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    requestSyncNow();
    _periodicSync = Timer.periodic(
      _periodicSyncInterval,
      (_) => requestSyncNow(),
    );
  }

  /// Purpose: Implement the stop behavior for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  void stop() {
    _debounce?.cancel();
    _debounce = null;
    _periodicSync?.cancel();
    _periodicSync = null;
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }

  /// Purpose: Called by storage save methods to schedule a debounced sync.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Called by storage save methods to schedule a debounced sync.
  void notifySaved() {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, _trySync);
  }

  /// Purpose: Trigger a sync as soon as possible without waiting for the debounce timer.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Trigger a sync as soon as possible without waiting for the debounce timer.
  void requestSyncNow() {
    _debounce?.cancel();
    _debounce = null;
    unawaited(_trySync());
  }

  /// Purpose: Implement the did change app lifecycle state behavior for this file.
  /// Inputs: `state`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: On resume also refreshes mobile reminder schedules so per-day
  /// notification bodies are recomputed from current data after suspension.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      requestSyncNow();
      BackupService.runAutoBackupIfNeeded();
      ReminderService.notifyDataChanged();
    }
  }

  /// Purpose: Provide the internal try sync helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  Future<void> _trySync() async {
    if (_syncing) return;
    final config = await WebDAVService.loadConfig();
    if (config == null || !config.isConfigured || !config.autoSync) return;
    _syncing = true;
    try {
      final result = await WebDAVService.sync(config);
      if (result.hasConflicts) {
        _recordFailure(
          'Sync conflicts require manual resolution${result.error != null ? ': ${result.error}' : ''}',
          conflicts: true,
        );
      } else if (!result.success) {
        _recordFailure(result.error ?? 'Unknown sync failure');
      } else {
        _recordSuccess();
      }
      if (WebDAVService.consumeLocalDataChanged()) {
        for (final cb in List.of(_onLocalDataChanged)) {
          cb();
        }
      }
    } catch (e) {
      _recordFailure(e.toString());
    } finally {
      _syncing = false;
    }
  }

  /// Purpose: Record a successful sync.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Clears failure state and notifies status listeners.
  /// Notes: Internal helper used within this file only.
  void _recordSuccess() {
    _lastSuccessAt = DateTime.now();
    _lastError = null;
    _hasPendingConflicts = false;
    _notifyStatusChanged();
  }

  /// Purpose: Record a failed sync.
  /// Inputs: `error`, optional `conflicts`.
  /// Returns: None.
  /// Side effects: Updates failure state and notifies status listeners.
  /// Notes: Internal helper used within this file only.
  void _recordFailure(String error, {bool conflicts = false}) {
    _lastFailureAt = DateTime.now();
    _lastError = error;
    _hasPendingConflicts = conflicts;
    _notifyStatusChanged();
  }

  /// Purpose: Notify all registered sync status listeners.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Invokes UI callbacks.
  /// Notes: Internal helper used within this file only.
  void _notifyStatusChanged() {
    for (final cb in List.of(_onStatusChanged)) {
      cb();
    }
  }
}
