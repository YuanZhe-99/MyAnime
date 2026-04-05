import 'dart:async';

import 'package:flutter/widgets.dart';

import 'backup_service.dart';
import 'webdav_service.dart';

/// Singleton service that triggers WebDAV sync automatically when enabled.
class AutoSyncService with WidgetsBindingObserver {
  AutoSyncService._();
  static final instance = AutoSyncService._();

  Timer? _debounce;
  bool _syncing = false;
  bool _started = false;

  static const _debounceDuration = Duration(seconds: 30);

  // Callbacks for UI reload after sync writes local files.
  final List<void Function()> _onLocalDataChanged = [];

  /// Register a callback invoked when auto-sync updates local data.
  void addOnLocalDataChanged(void Function() cb) =>
      _onLocalDataChanged.add(cb);

  /// Remove a previously registered callback.
  void removeOnLocalDataChanged(void Function() cb) =>
      _onLocalDataChanged.remove(cb);

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _trySync();
  }

  void stop() {
    _debounce?.cancel();
    _debounce = null;
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }

  /// Called by storage save methods to schedule a debounced sync.
  void notifySaved() {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, _trySync);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _trySync();
      BackupService.runAutoBackupIfNeeded();
    }
  }

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
