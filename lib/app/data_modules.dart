/// Purpose: Single source of truth describing MyAnime's syncable data files to
/// the shared `myapps_data` engines.
/// Inputs: `AnimeStorage` for storage paths/settings, `mergeAnimeData` for the
/// app's record merge, and the `AnimeData`/`Anime` models for parsing.
/// Returns: A `StorageAdapter` implementation and the app's `ModuleRegistry`.
/// Side effects: None at import time; callbacks perform parsing and storage I/O.
/// Notes: Every hardcoded `anime_data.json` list in the shared services is
/// replaced by this registry. File names and module IDs are
/// persisted compatibility contracts (I1/I2) and must never change.
library;

import 'dart:convert';
import 'dart:io';

import 'package:myapps_data/myapps_data.dart';
import 'package:path/path.dart' as p;

import '../features/anime/models/anime.dart';
import '../features/anime/services/anime_storage.dart';
import '../shared/services/sync_merge.dart';

/// Pretty-printer matching `AnimeStorage`'s local save format.
///
/// Sync writes must use the same indentation the storage hub uses, otherwise an
/// otherwise-unchanged file misses the raw-equality fast path on the next sync
/// and re-uploads forever (I6).
const _prettyJson = JsonEncoder.withIndent('  ');

/// Purpose: Bridge the shared engines to MyAnime's storage hub.
/// Inputs: Optional [appDir] resolver overriding the hub lookup.
/// Returns: Storage root and `storage_config.json` access.
/// Side effects: Delegates to `AnimeStorage`, which performs file I/O.
/// Notes: [appDir] exists so `BackupService` can keep honoring its
/// `@visibleForTesting appDirProvider` seam (I7); it is read on every call, so
/// tests that swap the provider between cases still work.
class AnimeStorageAdapter implements StorageAdapter {
  /// Purpose: Create an adapter over `AnimeStorage`.
  /// Inputs: Optional [appDir] resolver.
  /// Returns: A new adapter.
  /// Side effects: None.
  /// Notes: Pass [appDir] only to preserve an existing test seam.
  const AnimeStorageAdapter({Future<Directory> Function()? appDir})
    : _appDir = appDir;

  final Future<Directory> Function()? _appDir;

  /// Purpose: Resolve the active app data directory.
  /// Inputs: None.
  /// Returns: The custom storage path when configured, else the platform dir.
  /// Side effects: May create the directory via the hub.
  /// Notes: Honors the injected resolver first so `appDirProvider` still wins.
  @override
  Future<Directory> getAppDir() => (_appDir ?? AnimeStorage.getAppDir)();

  /// Purpose: Read `storage_config.json`.
  /// Inputs: None.
  /// Returns: The parsed settings map.
  /// Side effects: Reads local storage.
  /// Notes: Delegates so app-owned keys stay owned by the hub.
  @override
  Future<Map<String, dynamic>> readConfig() => AnimeStorage.readConfig();

  /// Purpose: Persist `storage_config.json`.
  /// Inputs: [config] complete settings map.
  /// Returns: A future completing after the write.
  /// Side effects: Writes local storage.
  /// Notes: The engines read-modify-write, so unknown keys survive.
  @override
  Future<void> writeConfig(Map<String, dynamic> config) =>
      AnimeStorage.writeConfig(config);
}

/// Local and remote name of MyAnime's only data file (I1/I2).
const animeDataFileName = 'anime_data.json';

/// Backup bundle module key for that file (I2).
const animeModuleId = 'anime';

/// Default remote WebDAV directory for MyAnime.
const animeDefaultRemotePath = '/MyAnime';

/// Archive name prefix for ZIP exports.
const animeArchiveNamePrefix = 'myanime_export_';

/// Purpose: Validate an `anime_data.json` payload before it is written.
/// Inputs: [json] raw module content.
/// Returns: None; throws when the payload is not parseable anime data.
/// Side effects: None.
/// Notes: Deliberately the same bare `AnimeData.fromJson(jsonDecode(...))` call
/// the backup and import paths used before extraction, so the exception types
/// and messages callers already surface are unchanged (I8).
void validateAnimeJson(String json) {
  AnimeData.fromJson(jsonDecode(json) as Map<String, dynamic>);
}

/// Purpose: Encode a merged anime dataset the way the storage hub writes it.
/// Inputs: [data] merged dataset.
/// Returns: Pretty-printed JSON.
/// Side effects: None.
/// Notes: Shared by the merge and conflict-resolution paths.
String encodeAnimeData(AnimeData data) => _prettyJson.convert(data.toJson());

/// Purpose: Extract cover-image basenames referenced by anime records.
/// Inputs: [json] raw or merged module JSON.
/// Returns: Referenced image basenames; empty for malformed input.
/// Side effects: None.
/// Notes: The engine unions local and remote results, reproducing the previous
/// "sync referenced images from both sides, never orphans" rule.
Set<String> animeReferencedImages(String json) {
  try {
    final data = AnimeData.fromJson(jsonDecode(json) as Map<String, dynamic>);
    return data.animes
        .map((a) => a.coverImage)
        .whereType<String>()
        .map(p.basename)
        .toSet();
  } catch (_) {
    return {};
  }
}

/// Purpose: Merge local/remote/base anime JSON for the shared sync engine.
/// Inputs: [localJson], [remoteJson], optional [baseJson], [autoResolve].
/// Returns: A complete outcome, or a pending one carrying the conflicts.
/// Side effects: None.
/// Notes: Wraps the unchanged `mergeAnimeData`. The typed `AnimeMergeResult` is
/// carried through as opaque `state` so `WebDAVService` can still hand a real
/// `PendingSync` to the conflict dialog (I7).
ModuleMergeOutcome mergeAnimeModule({
  required String localJson,
  required String remoteJson,
  required String? baseJson,
  required bool autoResolve,
}) {
  final result = mergeAnimeData(
    localJson,
    remoteJson,
    baseJson,
    autoResolve: autoResolve,
  );
  if (!result.hasConflicts) {
    return ModuleMergeOutcome(
      mergedJson: encodeAnimeData(
        AnimeData(animes: result.merged, extraJson: result.extraJson),
      ),
      state: result,
    );
  }
  return ModuleMergeOutcome(
    state: result,
    conflicts: [
      for (final conflict in result.conflicts)
        ModuleConflict(
          id: conflict.id,
          localRecord: conflict.localRecord,
          remoteRecord: conflict.remoteRecord,
          displayName: conflict.displayName,
        ),
    ],
    buildResolvedJson: (resolutions) => encodeAnimeData(
      result.buildResolved({
        for (final entry in resolutions.entries)
          if (entry.value is Anime) entry.key: entry.value as Anime,
      }),
    ),
  );
}

/// Purpose: Describe `anime_data.json` to the shared engines.
/// Inputs: None.
/// Returns: The app's single [DataModule].
/// Side effects: None.
/// Notes: No `postMergeTransform` (MyAnime has no migration) and no
/// `preUploadTransform` — unknown-field preservation is baked into the models
/// via `withPreservedUnknownJson`, so merge output is already self-preserving.
DataModule buildAnimeModule() => DataModule(
  fileName: animeDataFileName,
  moduleId: animeModuleId,
  validate: validateAnimeJson,
  merge:
      ({
        required String localJson,
        required String remoteJson,
        required String? baseJson,
        required bool autoResolve,
      }) => mergeAnimeModule(
        localJson: localJson,
        remoteJson: remoteJson,
        baseJson: baseJson,
        autoResolve: autoResolve,
      ),
  referencedImages: animeReferencedImages,
);

/// Purpose: Provide MyAnime's ordered module registry.
/// Inputs: None.
/// Returns: A registry holding the single anime module.
/// Side effects: None.
/// Notes: Built once; the shared engines treat registry order as significant.
final ModuleRegistry animeModuleRegistry = ModuleRegistry([buildAnimeModule()]);
