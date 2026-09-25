import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/auto_sync_service.dart';
import '../../anime/models/anime.dart';
import '../../anime/services/anime_storage.dart';
import '../models/recommendation_data.dart';
import '../services/recommendation_store.dart';
import 'recommendations_page.dart' show recommendationCover;

/// The recommendation trash (1.6.2). Without an `animeId` it is the global
/// bin behind "What to watch next": trashed library records and trashed
/// missing-sequel cards. With one it is that record's own bin behind its
/// related list. **Restore** takes an entry out, so it can be recommended
/// again.
class RecommendationTrashPage extends StatefulWidget {
  /// The record whose related-list bin to show; null for the global bin.
  final String? animeId;

  /// Purpose: Create the trash page.
  /// Inputs: `animeId` — null for the global bin.
  /// Returns: A new `RecommendationTrashPage`.
  /// Side effects: None.
  /// Notes: Routed at `/recommendations/trash`, with `?anime=<id>` for a
  /// record's own bin.
  const RecommendationTrashPage({super.key, this.animeId});

  /// Purpose: Create the state object.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  State<RecommendationTrashPage> createState() =>
      _RecommendationTrashPageState();
}

class _RecommendationTrashPageState extends State<RecommendationTrashPage> {
  Map<String, Anime> _byId = const {};
  RecommendationData _data = RecommendationData();
  bool _loading = true;

  /// Purpose: Load on first build and follow synced changes.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Reads storage; registers with auto-sync.
  /// Notes: Flutter lifecycle override.
  @override
  void initState() {
    super.initState();
    AutoSyncService.instance.addOnLocalDataChanged(_load);
    _load();
  }

  /// Purpose: Stop following synced changes.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Unregisters from auto-sync.
  /// Notes: Flutter lifecycle override.
  @override
  void dispose() {
    AutoSyncService.instance.removeOnLocalDataChanged(_load);
    super.dispose();
  }

  /// Purpose: Read the library and the store.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Reads `anime_data.json` and `recommendations.json`; moves
  /// a pre-1.6.2 hidden list into the store once.
  /// Notes: Internal helper used within this file only.
  Future<void> _load() async {
    await RecommendationStore.migrateFromInsights();
    final library = await AnimeStorage.load();
    final data = await RecommendationStore.load();
    if (!mounted) return;
    setState(() {
      _byId = {for (final a in library.animes) a.id: a};
      _data = data;
      _loading = false;
    });
  }

  /// Purpose: List the trashed records this page shows.
  /// Inputs: None.
  /// Returns: `List<(HiddenEntry, Anime)>` — newest first.
  /// Side effects: None.
  /// Notes: Entries for records that no longer exist are skipped, not
  /// deleted: removing them would sync as a restore.
  List<(HiddenEntry, Anime)> get _records {
    final bin = widget.animeId == null
        ? _data.hidden
        : _data.related[widget.animeId]?.hidden ?? const {};
    final out = [
      for (final e in bin.values)
        if (_byId[e.id] case final a?) (e, a),
    ];
    out.sort(_newestFirst((x) => x.$1.hiddenAt, (x) => x.$1.id));
    return out;
  }

  /// Purpose: List the trashed missing-sequel cards.
  /// Inputs: None.
  /// Returns: `List<HiddenSequelEntry>` — newest first; empty for a
  /// record's own bin.
  /// Side effects: None.
  /// Notes: None.
  List<HiddenSequelEntry> get _sequels {
    if (widget.animeId != null) return const [];
    return _data.hiddenSequels.values.toList()
      ..sort(_newestFirst((e) => e.hiddenAt, (e) => e.key));
  }

  /// Purpose: Build a comparator: newest timestamp first, then by key.
  /// Inputs: `at`, `key`.
  /// Returns: A comparator.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Missing timestamps
  /// sort last.
  static int Function(T, T) _newestFirst<T>(
    DateTime? Function(T) at,
    String Function(T) key,
  ) => (a, b) {
    final ta = at(a);
    final tb = at(b);
    if (ta != null && tb != null && ta != tb) return tb.compareTo(ta);
    if (ta == null && tb != null) return 1;
    if (ta != null && tb == null) return -1;
    return key(a).compareTo(key(b));
  };

  /// Purpose: Restore trashed records.
  /// Inputs: `ids`.
  /// Returns: None.
  /// Side effects: Writes `recommendations.json` (synced); reloads.
  /// Notes: Internal helper used within this file only.
  Future<void> _restore(Iterable<String> ids) async {
    final animeId = widget.animeId;
    if (animeId == null) {
      await RecommendationStore.restore(ids);
    } else {
      await RecommendationStore.restoreRelated(animeId, ids);
    }
    await _load();
  }

  /// Purpose: Restore trashed missing-sequel cards.
  /// Inputs: `keys`.
  /// Returns: None.
  /// Side effects: Writes `recommendations.json` (synced); reloads.
  /// Notes: Internal helper used within this file only.
  Future<void> _restoreSequels(Iterable<String> keys) async {
    await RecommendationStore.restoreSequels(keys);
    await _load();
  }

  /// Purpose: Restore everything this page shows.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Writes `recommendations.json` (synced); reloads.
  /// Notes: Internal helper used within this file only. Entries for deleted
  /// records are left alone.
  Future<void> _restoreAll() async {
    final ids = [for (final (e, _) in _records) e.id];
    final keys = [for (final e in _sequels) e.key];
    if (ids.isNotEmpty) await _restore(ids);
    if (keys.isNotEmpty) await _restoreSequels(keys);
  }

  /// Purpose: Build the page.
  /// Inputs: `context`.
  /// Returns: The widget tree.
  /// Side effects: None.
  /// Notes: The title names the record for a record's own bin.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final records = _records;
    final sequels = _sequels;
    final subject = widget.animeId == null ? null : _byId[widget.animeId];
    final material = MaterialLocalizations.of(context);
    String hiddenOn(DateTime? at) => at == null
        ? ''
        : l10n.recommendationsTrashedOn(
            material.formatMediumDate(at.toLocal()),
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          subject == null
              ? l10n.recommendationsTrash
              : l10n.relatedTrashTitle(subject.displayTitle),
        ),
        actions: [
          TextButton(
            onPressed: records.isEmpty && sequels.isEmpty ? null : _restoreAll,
            child: Text(l10n.recommendationsRestoreAll),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : records.isEmpty && sequels.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.recommendationsTrashEmpty,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final (entry, anime) in records)
                  ListTile(
                    leading: recommendationCover(
                      anime,
                      size: const Size(40, 56),
                    ),
                    title: Text(
                      anime.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(hiddenOn(entry.hiddenAt)),
                    onTap: () => context.push('/anime/detail/${anime.id}'),
                    trailing: TextButton(
                      onPressed: () => _restore([entry.id]),
                      child: Text(l10n.recommendationsRestore),
                    ),
                  ),
                if (sequels.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      l10n.recommendationsTrashSequels,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  for (final e in sequels)
                    ListTile(
                      leading: const Icon(Icons.new_releases_outlined),
                      title: Text(
                        l10n.seriesMissingSequel(
                          e.title ?? e.key,
                          e.source ?? '?',
                        ),
                      ),
                      subtitle: Text(
                        [
                          if (_byId[e.sourceId]?.displayTitle case final t?)
                            l10n.reasonNextAfter(t),
                          hiddenOn(e.hiddenAt),
                        ].where((s) => s.isNotEmpty).join(' · '),
                      ),
                      trailing: TextButton(
                        onPressed: () => _restoreSequels([e.key]),
                        child: Text(l10n.recommendationsRestore),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
