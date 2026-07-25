/// Purpose: MyAnime's local backup API, now a facade over the shared
/// `BackupEngine` from the `myapps_data` package.
/// Inputs: Backup files and module selections from the backup page.
/// Returns: `BackupInfo` listings and `RestoreResult` outcomes.
/// Side effects: Delegates bundle, blob, and restore I/O to the shared engine.
/// Notes: PLAN.md P3.1.3. Every public member kept its name and signature so
/// `backup_service_test.dart` and the backup page compile and behave unchanged
/// (I7) — including the `@visibleForTesting appDirProvider` seam, which is
/// wired into the storage adapter and read on every call.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:myapps_data/myapps_data.dart' as shared;

import '../../app/data_modules.dart';
import '../../features/anime/services/anime_storage.dart';

// The bundle format and its result types are the package's now. Shapes are
// unchanged: RestoreResult{ok, wroteAnything, missingImages} and
// BackupInfo{file, date, sizeBytes, corrupt}.
export 'package:myapps_data/myapps_data.dart' show BackupInfo, RestoreResult;

/// Manages local backups with manual/auto creation and retention policies.
///
/// Backup format v2: each `backup_*.json` bundle stores data-module JSON
/// strings plus an `_imageRefs` map pointing at content-addressed image
/// blobs under `backups/blobs/<sha256><ext>`. Identical images are stored
/// once and shared by every backup that references them; a blob is deleted
/// only when no remaining backup references it. Legacy v1 bundles with
/// inline base64 `_images` remain restorable.
class BackupService {
  /// Purpose: Allow tests to redirect backup I/O to a temporary directory.
  /// Inputs: None.
  /// Returns: The overridden app directory future, or null in production.
  /// Side effects: None.
  /// Notes: Only set from tests; production always uses [AnimeStorage].
  @visibleForTesting
  static Future<Directory> Function()? appDirProvider;

  /// Purpose: Resolve the app data directory honoring the test override.
  /// Inputs: None.
  /// Returns: `Future<Directory>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Passed to the adapter
  /// as a tear-off so swapping [appDirProvider] between tests still takes
  /// effect on the already-built engine.
  static Future<Directory> _getAppDir() {
    final provider = appDirProvider;
    if (provider != null) return provider();
    return AnimeStorage.getAppDir();
  }

  /// Data module identifiers used for per-module restore.
  ///
  /// Derived from the app registry — the file name and module id are written
  /// down once, in `lib/app/data_modules.dart`.
  static final Map<String, String> modules = {
    for (final module in animeModuleRegistry.modules)
      module.fileName: module.moduleId,
  };

  /// Lazily-built engine backing every static entry point.
  static final shared.BackupEngine _engine = shared.BackupEngine(
    storage: AnimeStorageAdapter(appDir: _getAppDir),
    modules: animeModuleRegistry,
    defaultRemotePath: animeDefaultRemotePath,
  );

  /// Whether a backup is taken automatically once per day.
  static bool get autoBackupEnabled => _engine.autoBackupEnabled;

  static set autoBackupEnabled(bool value) => _engine.autoBackupEnabled = value;

  /// Days to keep backups; 0 keeps them forever.
  static int get retentionDays => _engine.retentionDays;

  static set retentionDays(int value) => _engine.retentionDays = value;

  /// Purpose: Load backup settings from `storage_config.json`.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Populates [autoBackupEnabled] and [retentionDays].
  /// Notes: Keys are unchanged (`autoBackupEnabled`, `backupRetentionDays`).
  static Future<void> loadSettings() => _engine.loadSettings();

  /// Purpose: Persist backup settings to `storage_config.json`.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Writes the storage config, preserving unrelated keys.
  /// Notes: None.
  static Future<void> saveSettings() => _engine.saveSettings();

  /// Purpose: Create a v2 backup bundle plus any new image blobs.
  /// Inputs: None.
  /// Returns: `Future<File?>` — the bundle, or null on failure.
  /// Side effects: Writes the bundle, dedupes blobs, then runs retention
  /// cleanup and blob GC.
  /// Notes: None.
  static Future<File?> createBackup() => _engine.createBackup();

  /// Purpose: Take the once-per-day automatic backup when it is due.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: May create a backup.
  /// Notes: No-op when [autoBackupEnabled] is false; re-entrancy guarded, and
  /// "already backed up today" is decided by scanning bundle file names.
  static Future<void> runAutoBackupIfNeeded() => _engine.runAutoBackupIfNeeded();

  /// Purpose: List backups, newest first.
  /// Inputs: None.
  /// Returns: `Future<List<BackupInfo>>`.
  /// Side effects: Reads the backups directory and probes small bundles.
  /// Notes: Unparseable bundles are flagged `corrupt`, never hidden.
  static Future<List<shared.BackupInfo>> listBackups() => _engine.listBackups();

  /// Purpose: List the module ids a bundle contains.
  /// Inputs: `file` bundle.
  /// Returns: `Future<List<String>>`; empty when unparseable.
  /// Side effects: Reads the bundle.
  /// Notes: Drives the per-module restore checkboxes.
  static Future<List<String>> getBackupModules(File file) =>
      _engine.getBackupModules(file);

  /// Purpose: Restore from a backup file, optionally only specific modules.
  /// Inputs: `file`, `moduleKeys`.
  /// Returns: `Future<RestoreResult>` describing success, whether any file
  /// was written, and how many v2 image references had no blob on disk.
  /// Side effects: Overwrites app data files atomically and restores images.
  /// Notes: Every selected payload is validated before anything is written,
  /// and WebDAV auto-sync is disabled before the first write, re-enabled only
  /// when the restore failed without writing (I5).
  static Future<shared.RestoreResult> restoreBackup(
    File file, {
    Set<String>? moduleKeys,
  }) => _engine.restoreBackup(file, moduleKeys: moduleKeys);

  /// Purpose: Delete one backup bundle.
  /// Inputs: `file`.
  /// Returns: `Future<void>`.
  /// Side effects: Removes the bundle, then garbage-collects orphaned blobs.
  /// Notes: Blobs younger than the grace window are never collected.
  static Future<void> deleteBackup(File file) => _engine.deleteBackup(file);
}
