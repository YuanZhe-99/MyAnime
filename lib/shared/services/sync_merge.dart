import 'dart:convert';

import '../../features/anime/models/anime.dart';

// ─── Generic record merge ───────────────────────────────────────────

/// A single record-level conflict: same ID, both sides changed since base.
class RecordConflict<T> {
  final String id;
  final T localRecord;
  final T remoteRecord;
  final String displayName;

  const RecordConflict({
    required this.id,
    required this.localRecord,
    required this.remoteRecord,
    required this.displayName,
  });
}

/// Result of merging a list of records.
class RecordMergeResult<T> {
  final List<T> merged;
  final List<RecordConflict<T>> conflicts;

  const RecordMergeResult({required this.merged, this.conflicts = const []});
}

/// Three-way merge for a list of records by ID.
///
/// Uses [base] (last synced version) to detect which side changed:
/// - Only local changed → use local
/// - Only remote changed → use remote
/// - Both changed → conflict (or LWW when [autoResolve] is true)
/// - Neither changed → use either
/// - New record on one side only → include it
/// - Record deleted on one side, unchanged on other → exclude
/// - Record deleted on one side, modified on other → keep the modification
RecordMergeResult<T> mergeRecords<T>({
  required List<T> local,
  required List<T> remote,
  required List<T>? base,
  required String Function(T) getId,
  required DateTime Function(T) getModifiedAt,
  required String Function(T) getDisplayName,
  bool autoResolve = false,
}) {
  final localMap = {for (final r in local) getId(r): r};
  final remoteMap = {for (final r in remote) getId(r): r};
  final baseMap =
      base != null ? {for (final r in base) getId(r): r} : <String, T>{};

  final allIds = {...localMap.keys, ...remoteMap.keys, ...baseMap.keys};
  final merged = <T>[];
  final conflicts = <RecordConflict<T>>[];

  for (final id in allIds) {
    final l = localMap[id];
    final r = remoteMap[id];
    final b = baseMap[id];

    if (l != null && r != null) {
      // Both sides have the record
      if (b != null) {
        // Three-way: check who changed from base
        final localChanged = getModifiedAt(l).isAfter(getModifiedAt(b));
        final remoteChanged = getModifiedAt(r).isAfter(getModifiedAt(b));

        if (localChanged && remoteChanged) {
          if (autoResolve) {
            // LWW per record: pick the one with newer modifiedAt
            merged.add(getModifiedAt(l).isAfter(getModifiedAt(r)) ? l : r);
          } else {
            conflicts.add(RecordConflict(
              id: id,
              localRecord: l,
              remoteRecord: r,
              displayName: getDisplayName(l),
            ));
          }
        } else if (localChanged) {
          merged.add(l);
        } else if (remoteChanged) {
          merged.add(r);
        } else {
          merged.add(l); // neither changed, use local
        }
      } else {
        // No base — first sync or both added same ID
        merged.add(getModifiedAt(l).isAfter(getModifiedAt(r)) ? l : r);
      }
    } else if (l != null && r == null) {
      if (b != null) {
        // Was in base, missing from remote → deleted remotely
        final localChanged = getModifiedAt(l).isAfter(getModifiedAt(b));
        if (localChanged) {
          merged.add(l); // Modified locally after remote deleted → keep
        }
        // else: not modified locally, remote deleted → exclude
      } else {
        merged.add(l); // New locally → include
      }
    } else if (l == null && r != null) {
      if (b != null) {
        // Was in base, missing from local → deleted locally
        final remoteChanged = getModifiedAt(r).isAfter(getModifiedAt(b));
        if (remoteChanged) {
          merged.add(r); // Modified remotely after local deleted → keep
        }
        // else: not modified remotely, local deleted → exclude
      } else {
        merged.add(r); // New remotely → include
      }
    }
    // else: both null, was in base → deleted both sides → exclude
  }

  return RecordMergeResult(merged: merged, conflicts: conflicts);
}

// ─── Anime-specific merge ───────────────────────────────────────────

/// Result of merging anime data with possible per-record conflicts.
class AnimeMergeResult {
  final List<Anime> merged;
  final List<RecordConflict<Anime>> conflicts;

  const AnimeMergeResult({required this.merged, this.conflicts = const []});

  bool get hasConflicts => conflicts.isNotEmpty;

  /// Build final AnimeData applying user resolutions for conflicts.
  /// [resolutions] maps anime ID → chosen Anime record.
  AnimeData buildResolved(Map<String, Anime> resolutions) {
    final all = <Anime>[...merged];
    for (final c in conflicts) {
      all.add(resolutions[c.id] ?? c.localRecord);
    }
    return AnimeData(animes: all);
  }
}

/// Three-way merge for anime data.
AnimeMergeResult mergeAnimeData(
  String localJson,
  String remoteJson,
  String? baseJson, {
  bool autoResolve = false,
}) {
  final local =
      AnimeData.fromJson(jsonDecode(localJson) as Map<String, dynamic>);
  final remote =
      AnimeData.fromJson(jsonDecode(remoteJson) as Map<String, dynamic>);
  final base = baseJson != null
      ? AnimeData.fromJson(jsonDecode(baseJson) as Map<String, dynamic>)
      : null;

  final result = mergeRecords<Anime>(
    local: local.animes,
    remote: remote.animes,
    base: base?.animes,
    getId: (a) => a.id,
    getModifiedAt: (a) => a.modifiedAt,
    getDisplayName: (a) => a.displayTitle,
    autoResolve: autoResolve,
  );

  return AnimeMergeResult(
    merged: result.merged,
    conflicts: result.conflicts,
  );
}
