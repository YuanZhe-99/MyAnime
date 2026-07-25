/// Purpose: MyAnime's WebDAV sync API, now a facade over the shared
/// `WebDavSyncEngine` from the `myapps_data` package.
/// Inputs: `WebDAVConfig` values from the config page and auto-sync service.
/// Returns: App-typed `SyncResult`/`PendingSync` values.
/// Side effects: Delegates all local and remote I/O to the shared engine.
/// Notes: Every public member below kept its name, signature,
/// and semantics so call sites, the conflict dialog, and the existing tests
/// compile and behave unchanged (I7). The ~1400 lines of transport, lock,
/// merge-pipeline, and image-sync code this file used to hold now live in the
/// package, exercised by its own test suite plus the P0.2 goldens.
library;

import 'package:flutter/foundation.dart';
import 'package:myapps_data/myapps_data.dart' as shared;
import 'package:myapps_data/myapps_data.dart' show SyncProgress;

import '../../app/data_modules.dart';
import '../../features/anime/models/anime.dart';
import 'sync_merge.dart';

// The config and transport value types are the package's now. They are
// re-exported under their original names so `WebDAVConfig` written by an older
// build and this one stay the same type to every call site (I7). Field names,
// JSON keys, and the `.nextcloud()` factory are unchanged (I1/I2).
export 'package:myapps_data/myapps_data.dart'
    show WebDAVConfig, WebDAVUploadLock, RemoteFile, RemoteFileStatus;

/// Result of a sync operation.
class SyncResult {
  /// Whether the operation completed without a fatal or per-file error.
  final bool success;

  /// Error text shown to the user when [success] is false.
  final String? error;

  /// Unresolved conflicts awaiting the conflict dialog.
  final PendingSync? pending;

  /// Non-fatal warnings collected during sync (e.g. individual image failures).
  final List<String> warnings;

  /// Purpose: Create a sync result instance.
  /// Inputs: `success`, `error`, `pending`, `warnings`.
  /// Returns: A new `SyncResult` instance.
  /// Side effects: None.
  /// Notes: None.
  const SyncResult({
    required this.success,
    this.error,
    this.pending,
    this.warnings = const [],
  });

  /// Purpose: Return the current conflicts value.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get hasConflicts => pending != null;
}

/// Holds pending merge results that contain per-record conflicts.
class PendingSync {
  /// The app-typed merge result the conflict dialog reads.
  final AnimeMergeResult? animeMerge;

  /// Engine-side pending state used to finalize under a fresh remote lock.
  ///
  /// Kept private to callers: the UI only ever passes a `PendingSync` straight
  /// back to [WebDAVService.finalizePendingSync].
  final shared.EnginePendingSync? enginePending;

  /// Purpose: Create a pending sync instance.
  /// Inputs: `animeMerge`, `enginePending`.
  /// Returns: A new `PendingSync` instance.
  /// Side effects: None.
  /// Notes: `enginePending` is null only for values built by older test code.
  const PendingSync({this.animeMerge, this.enginePending});

  /// Purpose: Implement the all conflicts behavior for this file.
  /// Inputs: None.
  /// Returns: `List<RecordConflict<Anime>>`.
  /// Side effects: None.
  /// Notes: None.
  List<RecordConflict<Anime>> get allConflicts => [...?animeMerge?.conflicts];
}

/// WebDAV sync facade over the shared engine.
class WebDAVService {
  /// Lazily-built engine shared by every static entry point.
  ///
  /// One long-lived instance preserves the in-flight guard, the sticky
  /// local-data-changed flag, and the progress notifier identity that the old
  /// static implementation held in class fields.
  static final shared.WebDavSyncEngine _engine = shared.WebDavSyncEngine(
    storage: const AnimeStorageAdapter(),
    modules: animeModuleRegistry,
    defaultRemotePath: animeDefaultRemotePath,
  );

  /// Live sync progress for the config page's progress bar.
  static ValueNotifier<SyncProgress> get progress => _engine.progress;

  /// Purpose: Read and clear the "local data changed" signal.
  /// Inputs: None.
  /// Returns: `bool` — whether sync wrote local data or downloaded images.
  /// Side effects: Resets the flag.
  /// Notes: Open pages call this to decide whether to reload from disk.
  static bool consumeLocalDataChanged() => _engine.consumeLocalDataChanged();

  /// Purpose: Load the saved WebDAV configuration.
  /// Inputs: None.
  /// Returns: `Future<WebDAVConfig?>` — null when absent or unreadable.
  /// Side effects: Reads `webdav_config.json`.
  /// Notes: A missing `remotePath` still defaults to `/MyAnime`.
  static Future<shared.WebDAVConfig?> loadConfig() => _engine.loadConfig();

  /// Purpose: Save the WebDAV configuration.
  /// Inputs: `config`.
  /// Returns: `Future<void>`.
  /// Side effects: Atomically writes `webdav_config.json`.
  /// Notes: Credentials remain plaintext, unchanged from before (out of scope).
  static Future<void> saveConfig(shared.WebDAVConfig config) =>
      _engine.saveConfig(config);

  /// Purpose: Delete the saved WebDAV configuration.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Removes `webdav_config.json` when present.
  /// Notes: Base snapshots and the client ID are intentionally left in place.
  static Future<void> deleteConfig() => _engine.deleteConfig();

  /// Purpose: Check that the server is reachable with these credentials.
  /// Inputs: `config`, possibly unsaved values from the config page.
  /// Returns: `Future<bool>` — true for HTTP 207 or 404.
  /// Side effects: Issues one PROPFIND.
  /// Notes: 404 counts as reachable because the collection may not exist yet.
  static Future<bool> testConnection(shared.WebDAVConfig config) =>
      _engine.testConnection(config);

  /// Purpose: Run a full two-way sync under the remote upload lock.
  /// Inputs: `config`, `autoResolve` (false everywhere in production, I4).
  /// Returns: `Future<SyncResult>`, carrying `PendingSync` on true conflicts.
  /// Side effects: Local and remote data/image/lock I/O; updates [progress].
  /// Notes: Conflicts are never silently auto-resolved.
  static Future<SyncResult> sync(
    shared.WebDAVConfig config, {
    bool autoResolve = false,
  }) async {
    return _toSyncResult(await _engine.sync(config, autoResolve: autoResolve));
  }

  /// Purpose: Finalize sync by applying the user's conflict resolutions.
  /// Inputs: `config`, `pending`, `resolutions` (anime ID → chosen record).
  /// Returns: `Future<bool>` — false when applying or uploading fails.
  /// Side effects: Reacquires the remote lock, writes local data, uploads.
  /// Notes: The base snapshot is only saved after a successful upload under
  /// the held remote `.lock`.
  static Future<bool> finalizePendingSync(
    shared.WebDAVConfig config,
    PendingSync pending,
    Map<String, Anime> resolutions,
  ) async {
    final enginePending = pending.enginePending;
    if (enginePending == null) return false;
    return _engine.finalizePendingSync(config, enginePending, {
      animeModuleId: resolutions,
    });
  }

  /// Purpose: Overwrite remote data with local data, without merging.
  /// Inputs: `config`.
  /// Returns: `Future<SyncResult>`.
  /// Side effects: Overwrites remote files, uploads images, saves base
  /// snapshots, and publishes progress.
  /// Notes: Remote changes since the last sync are lost. Runs under the remote
  /// `.lock` and the in-flight guard, like a normal sync.
  static Future<SyncResult> forceUpload(shared.WebDAVConfig config) async {
    return _toSyncResult(await _engine.forceUpload(config));
  }

  /// Purpose: Overwrite local data with remote data, without merging.
  /// Inputs: `config`.
  /// Returns: `Future<SyncResult>`.
  /// Side effects: Replaces local data files and base snapshots, downloads
  /// missing referenced images.
  /// Notes: Local changes since the last sync are lost.
  static Future<SyncResult> forceDownload(shared.WebDAVConfig config) async {
    return _toSyncResult(await _engine.forceDownload(config));
  }

  /// Purpose: Convert an engine result into the app-typed result.
  /// Inputs: `result` from the shared engine.
  /// Returns: `SyncResult` with the app's `PendingSync` shape rebuilt.
  /// Side effects: None.
  /// Notes: The engine carries the app's `AnimeMergeResult` through as opaque
  /// `state`, so the conflict dialog still receives real `Anime` records.
  static SyncResult _toSyncResult(shared.EngineSyncResult result) {
    final pending = result.pending;
    return SyncResult(
      success: result.success,
      error: result.error,
      warnings: result.warnings,
      pending: pending == null
          ? null
          : PendingSync(
              animeMerge:
                  pending.forModuleId(animeModuleId)?.state
                      as AnimeMergeResult?,
              enginePending: pending,
            ),
    );
  }
}
