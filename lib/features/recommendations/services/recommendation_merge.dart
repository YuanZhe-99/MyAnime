/// The three-way merge for `recommendations.json` (1.6.2). It never produces
/// a conflict: trash bins and pins are sets, where "added on one side" and
/// "removed on the other" can be told apart against the sync base, and a
/// related snapshot and a sequel's fetched info are regenerable caches where
/// the newer one wins.
library;

import 'dart:convert';

import '../models/recommendation_data.dart';

const _prettyJson = JsonEncoder.withIndent('  ');

/// Purpose: Encode the store the way `RecommendationStore.save` writes it.
/// Inputs: `data`.
/// Returns: Pretty-printed JSON.
/// Side effects: None.
/// Notes: Merge output and local saves must be byte-identical for the same
/// data, or an unchanged file would re-upload on every sync.
String encodeRecommendationData(RecommendationData data) =>
    _prettyJson.convert(data.toJson());

/// Purpose: Merge one keyed set three ways.
/// Inputs: `local`, `remote`; `base` — null on a first sync; `both` —
/// combines an entry present on both sides.
/// Returns: `Map<String, T>`.
/// Side effects: None.
/// Notes: An entry on one side only is kept when the base lacks it (it was
/// added there) and dropped when the base has it (the other side removed
/// it). Without a base every entry is kept.
Map<String, T> mergeKeyedSet<T>(
  Map<String, T> local,
  Map<String, T> remote,
  Map<String, T>? base,
  T Function(T local, T remote) both,
) {
  final out = <String, T>{};
  for (final key in {...local.keys, ...remote.keys}) {
    final l = local[key];
    final r = remote[key];
    if (l != null && r != null) {
      out[key] = both(l, r);
    } else if (base == null || !base.containsKey(key)) {
      out[key] = (l ?? r) as T;
    }
  }
  return out;
}

/// Purpose: Merge one record's related snapshot three ways.
/// Inputs: `local`, `remote`, `base` — any may be null.
/// Returns: `RelatedSnapshot?` — null when the snapshot was removed.
/// Side effects: None.
/// Notes: The trash merges as a set; the list and `generatedAt` come from
/// whichever side generated later (a tie keeps local). A snapshot on one
/// side only follows the set rule.
RelatedSnapshot? mergeRelatedSnapshot(
  RelatedSnapshot? local,
  RelatedSnapshot? remote,
  RelatedSnapshot? base,
) {
  if (local == null || remote == null) {
    final only = local ?? remote;
    return base == null ? only : null;
  }
  final lt = local.generatedAt;
  final rt = remote.generatedAt;
  final newer = rt != null && (lt == null || rt.isAfter(lt)) ? remote : local;
  return RelatedSnapshot(
    generatedAt: newer.generatedAt,
    items: [...newer.items],
    hidden: mergeKeyedSet(
      local.hidden,
      remote.hidden,
      base?.hidden,
      (l, r) => l.mergedWith(r),
    ),
    pinned: mergeKeyedSet(
      local.pinned,
      remote.pinned,
      base?.pinned,
      (l, r) => l.mergedWith(r),
    ),
    extraJson: {...remote.extraJson, ...local.extraJson},
  );
}

/// Purpose: Restore the store's invariants after a merge.
/// Inputs: `data` — merged contents, edited in place.
/// Returns: `data`.
/// Side effects: None beyond editing `data`.
/// Notes: 1.6.3. Each side keeps a key out of a trash bin while it is pinned,
/// but two devices can disagree between syncs (one pins, the other refreshes
/// the batch away). The explicit pin wins. Then sequel info whose card is in
/// the trash is dropped, since a trashed card keeps only its basic labels.
RecommendationData normalizeRecommendations(RecommendationData data) {
  data.hidden.removeWhere((id, _) => data.pinned.containsKey(id));
  data.hiddenSequels.removeWhere((k, _) => data.pinnedSequels.containsKey(k));
  for (final s in data.related.values) {
    s.hidden.removeWhere((id, _) => s.pinned.containsKey(id));
  }
  data.sequelInfo.removeWhere((k, _) => data.hiddenSequels.containsKey(k));
  return data;
}

/// Purpose: Merge local, remote and base store contents.
/// Inputs: `local`, `remote`; `base` — null on a first sync.
/// Returns: `RecommendationData`.
/// Side effects: None.
/// Notes: Unknown top-level keys are unioned with local winning; the higher
/// `version` is kept. Pins and sequel info (1.6.3) merge as keyed sets like
/// the trash; sequel info on both sides keeps the newer fetch. The result is
/// passed through [normalizeRecommendations].
RecommendationData mergeRecommendations(
  RecommendationData local,
  RecommendationData remote,
  RecommendationData? base,
) {
  final related = <String, RelatedSnapshot>{};
  for (final id in {...local.related.keys, ...remote.related.keys}) {
    final merged = mergeRelatedSnapshot(
      local.related[id],
      remote.related[id],
      base?.related[id],
    );
    if (merged != null) related[id] = merged;
  }
  return normalizeRecommendations(
    RecommendationData(
      version: local.version > remote.version ? local.version : remote.version,
      hidden: mergeKeyedSet(
        local.hidden,
        remote.hidden,
        base?.hidden,
        (l, r) => l.mergedWith(r),
      ),
      hiddenSequels: mergeKeyedSet(
        local.hiddenSequels,
        remote.hiddenSequels,
        base?.hiddenSequels,
        (l, r) => l.mergedWith(r),
      ),
      related: related,
      pinned: mergeKeyedSet(
        local.pinned,
        remote.pinned,
        base?.pinned,
        (l, r) => l.mergedWith(r),
      ),
      pinnedSequels: mergeKeyedSet(
        local.pinnedSequels,
        remote.pinnedSequels,
        base?.pinnedSequels,
        (l, r) => l.mergedWith(r),
      ),
      sequelInfo: mergeKeyedSet(
        local.sequelInfo,
        remote.sequelInfo,
        base?.sequelInfo,
        (l, r) => l.mergedWith(r),
      ),
      extraJson: {...remote.extraJson, ...local.extraJson},
    ),
  );
}

/// Purpose: Merge the raw JSON of the three sides for the sync engine.
/// Inputs: `localJson`, `remoteJson`; `baseJson` — null on a first sync.
/// Returns: The merged file as pretty-printed JSON.
/// Side effects: None.
/// Notes: An unreadable base is treated as absent (every entry kept rather
/// than any dropped). Throws when local or remote is not a JSON object.
String mergeRecommendationJson(
  String localJson,
  String remoteJson,
  String? baseJson,
) {
  RecommendationData? base;
  if (baseJson != null) {
    try {
      base = RecommendationData.fromJson(jsonDecode(baseJson));
    } catch (_) {
      base = null;
    }
  }
  return encodeRecommendationData(
    mergeRecommendations(
      RecommendationData.fromJson(jsonDecode(localJson)),
      RecommendationData.fromJson(jsonDecode(remoteJson)),
      base,
    ),
  );
}
