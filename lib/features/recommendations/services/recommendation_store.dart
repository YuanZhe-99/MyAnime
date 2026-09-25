import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../shared/services/auto_sync_service.dart';
import '../../ai/services/ai_insights_cache.dart';
import '../../anime/services/anime_storage.dart';
import '../models/recommendation_data.dart';
import 'recommendation_merge.dart';

/// Owns `recommendations.json` (1.6.2): the global and per-record
/// recommendation trash bins and the persisted related-recommendation
/// snapshots.
///
/// Unlike `ai_insights.json` this file is registered in
/// `lib/app/data_modules.dart`, so it syncs over WebDAV and is backed up; a
/// save therefore notifies auto-sync. Every write is a read-modify-write
/// through [update], serialised inside this process, so a snapshot save
/// racing a "Not interested" tap cannot drop either change.
class RecommendationStore {
  /// Purpose: Prevent direct instantiation and expose only static members.
  /// Inputs: None.
  /// Returns: A new `RecommendationStore._` instance.
  /// Side effects: None.
  /// Notes: None.
  const RecommendationStore._();

  /// The file's name under the app directory. Must match
  /// `recommendationsFileName` in `lib/app/data_modules.dart`.
  static const fileName = 'recommendations.json';

  static Future<void> _tail = Future.value();

  /// Purpose: Resolve the file.
  /// Inputs: None.
  /// Returns: `Future<File>`.
  /// Side effects: May create the app directory.
  /// Notes: Internal helper used within this file only.
  static Future<File> _file() async {
    final dir = await AnimeStorage.getAppDir();
    return File(p.join(dir.path, fileName));
  }

  /// Purpose: Load the store.
  /// Inputs: None.
  /// Returns: `Future<RecommendationData>` — empty when the file is absent or
  /// unreadable.
  /// Side effects: Reads the file.
  /// Notes: Entries for records that no longer exist are kept on disk; the
  /// readers skip them. Pruning here would be read by sync as a deliberate
  /// removal and could delete another device's entries for a record this
  /// device has not received yet.
  static Future<RecommendationData> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return RecommendationData();
      return RecommendationData.fromJson(jsonDecode(await file.readAsString()));
    } catch (_) {
      return RecommendationData();
    }
  }

  /// Purpose: Apply one change to the store and save it.
  /// Inputs: `mutate` — edits the loaded data in place.
  /// Returns: `Future<RecommendationData>` — the data after the change.
  /// Side effects: Writes the file atomically (tmp then rename) and notifies
  /// auto-sync, but only when the bytes changed; never creates the file for
  /// an empty store.
  /// Notes: Calls are queued, so concurrent updates apply one after another.
  static Future<RecommendationData> update(
    void Function(RecommendationData data) mutate,
  ) {
    final done = Completer<RecommendationData>();
    _tail = _tail.then((_) async {
      try {
        done.complete(await _apply(mutate));
      } catch (e, s) {
        done.completeError(e, s);
      }
    });
    return done.future;
  }

  /// Purpose: Run one queued update.
  /// Inputs: `mutate`.
  /// Returns: `Future<RecommendationData>`.
  /// Side effects: See [update].
  /// Notes: Internal helper used within this file only.
  static Future<RecommendationData> _apply(
    void Function(RecommendationData data) mutate,
  ) async {
    final file = await _file();
    final exists = await file.exists();
    final before = exists ? await file.readAsString() : null;
    RecommendationData data;
    try {
      data = before == null
          ? RecommendationData()
          : RecommendationData.fromJson(jsonDecode(before));
    } catch (_) {
      data = RecommendationData();
    }
    mutate(data);
    final after = encodeRecommendationData(data);
    if (after == before) return data;
    if (before == null &&
        after == encodeRecommendationData(RecommendationData())) {
      return data;
    }
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(after, flush: true);
    await tmp.rename(file.path);
    AutoSyncService.instance.notifySaved();
    return data;
  }

  /// Purpose: Put records into the global trash.
  /// Inputs: `ids`.
  /// Returns: `Future<RecommendationData>`.
  /// Side effects: Writes the file.
  /// Notes: An id already trashed keeps its original `hiddenAt`. Trashing a
  /// pinned record unpins it (1.6.3).
  static Future<RecommendationData> hide(Iterable<String> ids) {
    final now = DateTime.now().toUtc();
    return update((d) {
      for (final id in ids) {
        d.hidden.putIfAbsent(id, () => HiddenEntry(id, hiddenAt: now));
        d.pinned.remove(id);
      }
    });
  }

  /// Purpose: Pin library cards on "What to watch next".
  /// Inputs: `ids`.
  /// Returns: `Future<RecommendationData>`.
  /// Side effects: Writes the file.
  /// Notes: 1.6.3. A pinned card survives refresh and is shown first. Pinning
  /// also takes the record out of the global trash, if it was there.
  static Future<RecommendationData> pin(Iterable<String> ids) {
    final now = DateTime.now().toUtc();
    return update((d) {
      for (final id in ids) {
        d.pinned.putIfAbsent(id, () => PinnedEntry(id, pinnedAt: now));
        d.hidden.remove(id);
      }
    });
  }

  /// Purpose: Unpin library cards.
  /// Inputs: `ids`.
  /// Returns: `Future<RecommendationData>`.
  /// Side effects: Writes the file.
  /// Notes: The card stays on screen until the next refresh.
  static Future<RecommendationData> unpin(Iterable<String> ids) =>
      update((d) => d.pinned.removeWhere((id, _) => ids.contains(id)));

  /// Purpose: Pin missing-sequel cards.
  /// Inputs: `keys` — dedupe keys from `sequelTrashKey`.
  /// Returns: `Future<RecommendationData>`.
  /// Side effects: Writes the file.
  /// Notes: 1.6.3. Also takes the card out of the trash.
  static Future<RecommendationData> pinSequels(Iterable<String> keys) {
    final now = DateTime.now().toUtc();
    return update((d) {
      for (final k in keys) {
        d.pinnedSequels.putIfAbsent(k, () => PinnedEntry(k, pinnedAt: now));
        d.hiddenSequels.remove(k);
      }
    });
  }

  /// Purpose: Unpin missing-sequel cards.
  /// Inputs: `keys`.
  /// Returns: `Future<RecommendationData>`.
  /// Side effects: Writes the file.
  /// Notes: None.
  static Future<RecommendationData> unpinSequels(Iterable<String> keys) =>
      update((d) => d.pinnedSequels.removeWhere((k, _) => keys.contains(k)));

  /// Purpose: Store what was fetched about one missing sequel.
  /// Inputs: `key` — the dedupe key; `info`.
  /// Returns: `Future<RecommendationData>`.
  /// Side effects: Writes the file.
  /// Notes: 1.6.3. Ignored while the card is in the trash, so a fetch that
  /// finishes after the user trashed the card cannot bring its cover back.
  static Future<RecommendationData> putSequelInfo(
    String key,
    SequelInfo info,
  ) => update((d) {
    if (d.hiddenSequels.containsKey(key)) return;
    d.sequelInfo[key] = info;
  });

  /// Purpose: Drop fetched info for sequels no longer shown anywhere.
  /// Inputs: `keys`.
  /// Returns: `Future<RecommendationData>`.
  /// Side effects: Writes the file when anything was removed.
  /// Notes: Used when a sequel was added to the library or its relation
  /// disappeared, so the synced file does not keep dead thumbnails.
  static Future<RecommendationData> removeSequelInfo(Iterable<String> keys) =>
      update((d) => d.sequelInfo.removeWhere((k, _) => keys.contains(k)));

  /// Purpose: Take records out of the global trash.
  /// Inputs: `ids`.
  /// Returns: `Future<RecommendationData>`.
  /// Side effects: Writes the file.
  /// Notes: The records become recommendable again.
  static Future<RecommendationData> restore(Iterable<String> ids) =>
      update((d) => d.hidden.removeWhere((id, _) => ids.contains(id)));

  /// Purpose: Put missing-sequel cards into the global trash.
  /// Inputs: `entries` — `hiddenAt` is stamped when absent.
  /// Returns: `Future<RecommendationData>`.
  /// Side effects: Writes the file.
  /// Notes: Since 1.6.3 this also unpins the card and deletes its fetched
  /// synopsis and thumbnail: the trash keeps only the basic labels.
  static Future<RecommendationData> hideSequels(
    Iterable<HiddenSequelEntry> entries,
  ) {
    final now = DateTime.now().toUtc();
    return update((d) {
      for (final e in entries) {
        d.hiddenSequels.putIfAbsent(
          e.key,
          () => HiddenSequelEntry(
            e.key,
            sourceId: e.sourceId,
            title: e.title,
            source: e.source,
            hiddenAt: e.hiddenAt ?? now,
          ),
        );
        d.pinnedSequels.remove(e.key);
        d.sequelInfo.remove(e.key);
      }
    });
  }

  /// Purpose: Take missing-sequel cards out of the global trash.
  /// Inputs: `keys`.
  /// Returns: `Future<RecommendationData>`.
  /// Side effects: Writes the file.
  /// Notes: None.
  static Future<RecommendationData> restoreSequels(Iterable<String> keys) =>
      update((d) => d.hiddenSequels.removeWhere((k, _) => keys.contains(k)));

  /// Purpose: Trash the global page's current batch in one write.
  /// Inputs: `ids` — the shown library cards; `sequels` — the shown
  /// missing-sequel cards.
  /// Returns: `Future<RecommendationData>`.
  /// Side effects: One write, one auto-sync notification.
  /// Notes: What the page's refresh action means. Callers leave pinned cards
  /// out (1.6.3); the trashed sequels' fetched info is deleted.
  static Future<RecommendationData> hideBatch(
    Iterable<String> ids,
    Iterable<HiddenSequelEntry> sequels,
  ) {
    final now = DateTime.now().toUtc();
    return update((d) {
      for (final id in ids) {
        d.hidden.putIfAbsent(id, () => HiddenEntry(id, hiddenAt: now));
        d.pinned.remove(id);
      }
      for (final e in sequels) {
        d.pinnedSequels.remove(e.key);
        d.sequelInfo.remove(e.key);
        d.hiddenSequels.putIfAbsent(
          e.key,
          () => HiddenSequelEntry(
            e.key,
            sourceId: e.sourceId,
            title: e.title,
            source: e.source,
            hiddenAt: now,
          ),
        );
      }
    });
  }

  /// Purpose: Put records into one record's own related trash.
  /// Inputs: `animeId` — whose list; `ids` — the related records.
  /// Returns: `Future<RecommendationData>`.
  /// Side effects: Writes the file.
  /// Notes: Also removes them from the persisted list, so the card stops
  /// showing them at once, and unpins them (1.6.3).
  static Future<RecommendationData> hideRelated(
    String animeId,
    Iterable<String> ids,
  ) {
    final now = DateTime.now().toUtc();
    return update((d) {
      final s = d.relatedFor(animeId);
      for (final id in ids) {
        s.hidden.putIfAbsent(id, () => HiddenEntry(id, hiddenAt: now));
        s.pinned.remove(id);
      }
      s.items.removeWhere((i) => ids.contains(i.id));
    });
  }

  /// Purpose: Pin items in one record's related list.
  /// Inputs: `animeId` — whose list; `ids`.
  /// Returns: `Future<RecommendationData>`.
  /// Side effects: Writes the file.
  /// Notes: 1.6.3. Pinned items survive the card's refresh; pinning also
  /// takes them out of that record's trash.
  static Future<RecommendationData> pinRelated(
    String animeId,
    Iterable<String> ids,
  ) {
    final now = DateTime.now().toUtc();
    return update((d) {
      final s = d.relatedFor(animeId);
      for (final id in ids) {
        s.pinned.putIfAbsent(id, () => PinnedEntry(id, pinnedAt: now));
        s.hidden.remove(id);
      }
    });
  }

  /// Purpose: Unpin items in one record's related list.
  /// Inputs: `animeId`, `ids`.
  /// Returns: `Future<RecommendationData>`.
  /// Side effects: Writes the file.
  /// Notes: The item stays in the list until the next refresh.
  static Future<RecommendationData> unpinRelated(
    String animeId,
    Iterable<String> ids,
  ) => update((d) {
    d.related[animeId]?.pinned.removeWhere((id, _) => ids.contains(id));
  });

  /// Purpose: Take records out of one record's related trash.
  /// Inputs: `animeId`, `ids`.
  /// Returns: `Future<RecommendationData>`.
  /// Side effects: Writes the file.
  /// Notes: The persisted list is not regenerated here; a restored record
  /// can appear again on the next refresh.
  static Future<RecommendationData> restoreRelated(
    String animeId,
    Iterable<String> ids,
  ) => update((d) {
    d.related[animeId]?.hidden.removeWhere((id, _) => ids.contains(id));
  });

  /// Purpose: Persist one record's generated related list.
  /// Inputs: `animeId`; `items`; `generatedAt` — defaults to now.
  /// Returns: `Future<RecommendationData>`.
  /// Side effects: Writes the file.
  /// Notes: Keeps the record's trash and pins untouched; callers put the
  /// pinned items at the front of `items` themselves.
  static Future<RecommendationData> putRelated(
    String animeId,
    List<RelatedItem> items, {
    DateTime? generatedAt,
  }) {
    final at = (generatedAt ?? DateTime.now()).toUtc();
    return update((d) {
      final s = d.relatedFor(animeId);
      d.related[animeId] = RelatedSnapshot(
        generatedAt: at,
        items: items,
        hidden: s.hidden,
        pinned: s.pinned,
        extraJson: s.extraJson,
      );
    });
  }

  /// Purpose: Move the pre-1.6.2 per-device "Not interested" list into the
  /// synced global trash, once.
  /// Inputs: None.
  /// Returns: `Future<bool>` — whether anything moved.
  /// Side effects: May write both `recommendations.json` and
  /// `ai_insights.json`.
  /// Notes: Called by both readers of the trash. The ids are removed from
  /// `ai_insights.json` only after the store saved them.
  static Future<bool> migrateFromInsights() async {
    final insights = await AiInsightsCache.load();
    if (insights.hiddenRecommendations.isEmpty) return false;
    await hide(insights.hiddenRecommendations);
    insights.hiddenRecommendations.clear();
    await AiInsightsCache.save(insights);
    return true;
  }
}
