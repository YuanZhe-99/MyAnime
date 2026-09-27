/// The three-way merge for `playback_progress.json` (1.6.5). It never
/// produces a conflict: each resume point is a keyed entry where the newer
/// position wins, and an entry the other device deleted (finished) stays
/// deleted.
library;

import 'dart:convert';

import '../../recommendations/services/recommendation_merge.dart'
    show mergeKeyedSet;
import '../models/playback_progress.dart';

const _prettyJson = JsonEncoder.withIndent('  ');

/// Purpose: Encode the store the way `PlaybackProgressStore` writes it.
/// Inputs: `data`.
/// Returns: Pretty-printed JSON.
/// Side effects: None.
/// Notes: Merge output and local saves must be byte-identical for the same
/// data, or an unchanged file would re-upload on every sync.
String encodePlaybackProgress(PlaybackProgressData data) =>
    _prettyJson.convert(data.toJson());

/// Purpose: Merge local, remote and base store contents.
/// Inputs: `local`, `remote`; `base` — null on a first sync.
/// Returns: `PlaybackProgressData`.
/// Side effects: None.
/// Notes: Entries on both sides keep the later `updatedAt` (a tie keeps
/// local). An entry on one side only is kept when the base lacks it and
/// dropped when the base had it — the other device finished or cleared it,
/// so a completion beats a later partial update. Unknown top-level keys are
/// unioned with local winning; the higher `version` is kept.
PlaybackProgressData mergePlaybackProgress(
  PlaybackProgressData local,
  PlaybackProgressData remote,
  PlaybackProgressData? base,
) => PlaybackProgressData(
  version: local.version > remote.version ? local.version : remote.version,
  entries: mergeKeyedSet(
    local.entries,
    remote.entries,
    base?.entries,
    (l, r) => l.newerOf(r),
  ),
  extraJson: {...remote.extraJson, ...local.extraJson},
);

/// Purpose: Merge the raw JSON of the three sides for the sync engine.
/// Inputs: `localJson`, `remoteJson`; `baseJson` — null on a first sync.
/// Returns: The merged file as pretty-printed JSON.
/// Side effects: None.
/// Notes: An unreadable base is treated as absent (every entry kept rather
/// than any dropped). Throws when local or remote is not a JSON object.
String mergePlaybackProgressJson(
  String localJson,
  String remoteJson,
  String? baseJson,
) {
  PlaybackProgressData? base;
  if (baseJson != null) {
    try {
      base = PlaybackProgressData.fromJson(jsonDecode(baseJson));
    } catch (_) {
      base = null;
    }
  }
  return encodePlaybackProgress(
    mergePlaybackProgress(
      PlaybackProgressData.fromJson(jsonDecode(localJson)),
      PlaybackProgressData.fromJson(jsonDecode(remoteJson)),
      base,
    ),
  );
}
