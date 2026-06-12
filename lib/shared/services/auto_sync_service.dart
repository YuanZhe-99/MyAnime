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

  static const _debounceDuration = Duration(seconds: 30);
  static const _periodicSyncInterval = Duration(minutes: 15);

  // Callbacks for UI reload after sync writes local files.
  final List<void Function()> _onLocalDataChanged = [];

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
      await WebDAVService.sync(config, autoResolve: true);
      if (WebDAVService.consumeLocalDataChanged()) {
        for (final cb in List.of(_onLocalDataChanged)) {
          cb();
        }
      }
    } catch (_) {
      // Auto-sync failures are silent.
    } finally {
      _syncing = false;
    }
  }
}
