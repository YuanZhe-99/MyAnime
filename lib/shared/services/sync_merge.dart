import 'dart:convert';

import '../../features/anime/models/anime.dart';

// ─── Generic record merge ───────────────────────────────────────────

/// A single record-level conflict: same ID, both sides changed since base.
class RecordConflict<T> {
  final String id;
  final T localRecord;
  final T remoteRecord;
  final String displayName;

  /// Purpose: Create a record conflict instance.
  /// Inputs: `id`, `localRecord`, `remoteRecord`, `displayName`.
  /// Returns: A new `RecordConflict` instance.
  /// Side effects: None.
  /// Notes: None.
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

/// Purpose: Merge record lists by ID using the last synced base snapshot.
/// Inputs: `local`, `remote`, `base`, `getId`, `getModifiedAt`, `getDisplayName`, `autoResolve`, optional `serialize`.
/// Returns: `RecordMergeResult<T>`.
/// Side effects: None.
/// Notes: Uses the base snapshot to distinguish pure edits, deletions, and true conflicts.
/// When `serialize` is provided, records whose serialized content is identical are
/// merged without raising a conflict even if both sides bumped `modifiedAt` (e.g.
/// after a stale base caused by an earlier failed upload).
RecordMergeResult<T> mergeRecords<T>({
  required List<T> local,
  required List<T> remote,
  required List<T>? base,
  required String Function(T) getId,
  required DateTime Function(T) getModifiedAt,
  required String Function(T) getDisplayName,
  bool autoResolve = false,
  String Function(T)? serialize,
}) {
  final localMap = {for (final r in local) getId(r): r};
  final remoteMap = {for (final r in remote) getId(r): r};
  final baseMap = base != null
      ? {for (final r in base) getId(r): r}
      : <String, T>{};

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
          if (serialize != null && serialize(l) == serialize(r)) {
            // Identical content on both sides is not a real conflict.
            merged.add(l);
          } else if (autoResolve) {
            // LWW per record: pick the one with newer modifiedAt
            merged.add(getModifiedAt(l).isAfter(getModifiedAt(r)) ? l : r);
          } else {
            conflicts.add(
              RecordConflict(
                id: id,
                localRecord: l,
                remoteRecord: r,
                displayName: getDisplayName(l),
              ),
            );
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
