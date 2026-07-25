import 'dart:convert';

import 'package:myapps_data/myapps_data.dart';

import '../../features/anime/models/anime.dart';

// ─── Generic record merge ───────────────────────────────────────────
//
// `mergeRecords<T>`, `RecordConflict<T>`, and `RecordMergeResult<T>` used to be
// defined here, byte-identically to MyDay's copy. They now live in the shared
// package and are re-exported so every existing import of this file — call
// sites, conflict dialogs, and tests — keeps compiling unchanged (I7).
//
// The package signature is MyDevice's superset: it adds one optional
// `mergeUnknownFields` callback. MyAnime does not pass it (unknown-field
// preservation is baked into the models), so behavior here is identical.
export 'package:myapps_data/myapps_data.dart'
    show RecordConflict, RecordMergeResult, mergeRecords;

// ─── Anime-specific merge ───────────────────────────────────────────

/// Result of merging anime data with possible per-record conflicts.
class AnimeMergeResult {
  final List<Anime> merged;
  final List<RecordConflict<Anime>> conflicts;
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a anime merge result instance.
  /// Inputs: `merged`, `conflicts`, `extraJson`.
  /// Returns: A new `AnimeMergeResult` instance.
  /// Side effects: None.
  /// Notes: None.
  const AnimeMergeResult({
    required this.merged,
    this.conflicts = const [],
    this.extraJson = const {},
  });

  /// Purpose: Return the current conflicts value.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get hasConflicts => conflicts.isNotEmpty;

  /// Purpose: Build the final merged anime dataset from conflict resolutions.
  /// Inputs: `resolutions`.
  /// Returns: `AnimeData`.
  /// Side effects: None.
  /// Notes: `resolutions` maps each conflicting anime ID to the chosen record.
  AnimeData buildResolved(Map<String, Anime> resolutions) {
    final all = <Anime>[...merged];
    for (final c in conflicts) {
      final chosen = resolutions[c.id] ?? c.localRecord;
      all.add(chosen.withPreservedUnknownJson([c.localRecord, c.remoteRecord]));
    }
    return AnimeData(animes: all, extraJson: extraJson);
  }
}

/// Purpose: Merge local, remote, and base anime JSON into one conflict-aware result.
/// Inputs: `localJson`, `remoteJson`, `baseJson`, `autoResolve`.
/// Returns: `AnimeMergeResult`.
/// Side effects: None.
/// Notes: Preserves unknown JSON fields while delegating per-record decisions to `mergeRecords`.
AnimeMergeResult mergeAnimeData(
  String localJson,
  String remoteJson,
  String? baseJson, {
  bool autoResolve = false,
}) {
  final localData = AnimeData.fromJson(
    jsonDecode(localJson) as Map<String, dynamic>,
  );
  final remoteData = AnimeData.fromJson(
    jsonDecode(remoteJson) as Map<String, dynamic>,
  );
  final baseData = baseJson != null
      ? AnimeData.fromJson(jsonDecode(baseJson) as Map<String, dynamic>)
      : null;
  final localMap = {for (final anime in localData.animes) anime.id: anime};
  final remoteMap = {for (final anime in remoteData.animes) anime.id: anime};

  final result = mergeRecords<Anime>(
    local: localData.animes,
    remote: remoteData.animes,
    base: baseData?.animes,
    getId: (a) => a.id,
    getModifiedAt: (a) => a.modifiedAt,
    getDisplayName: (a) => a.displayTitle,
    autoResolve: autoResolve,
    serialize: (a) => jsonEncode(a.toJson()),
  );
  final merged = result.merged
      .map(
        (anime) => anime.withPreservedUnknownJson([
          localMap[anime.id],
          remoteMap[anime.id],
        ]),
      )
      .toList();
  final extraJson = localData.withPreservedUnknownJson([remoteData]).extraJson;

  return AnimeMergeResult(
    merged: merged,
    conflicts: result.conflicts,
    extraJson: extraJson,
  );
}
