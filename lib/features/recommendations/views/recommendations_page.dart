import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/providers/app_settings.dart';
import '../../../shared/services/auto_sync_service.dart';
import '../../../shared/services/image_service.dart';
import '../../../shared/utils/adaptive_layout.dart';
import '../../../shared/utils/jst_time.dart';
import '../../../shared/widgets/adaptive_tile_grid.dart';
import '../../ai/services/ai_insights_cache.dart';
import '../../ai/services/on_device_ai_service.dart';
import '../../anime/models/anime.dart';
import '../../anime/services/anime_storage.dart';
import '../../anime/services/series_service.dart';
import '../models/recommendation_data.dart';
import '../services/ai_reason_service.dart';
import '../services/recommendation_service.dart';
import '../services/recommendation_store.dart';
import 'reason_labels.dart';

/// "What to watch next": the library's own unwatched and in-progress records,
/// ranked, with reason chips; sequels the databases list but the library
/// lacks are appended, clearly marked. With on-device AI on and a model
/// available, up to three cards gain a short generated reason. Since 1.6.2
/// the page shows a batch of ten, every card can go to the synced trash, and
/// the refresh action trashes the whole batch and shows the next one.
class RecommendationsPage extends ConsumerStatefulWidget {
  /// Purpose: Create the recommendations page.
  /// Inputs: None.
  /// Returns: A new `RecommendationsPage`.
  /// Side effects: None.
  /// Notes: Reached from the Home app bar while recommendations are on.
  const RecommendationsPage({super.key});

  /// Purpose: Create the state object.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  ConsumerState<RecommendationsPage> createState() =>
      _RecommendationsPageState();
}

class _RecommendationsPageState extends ConsumerState<RecommendationsPage> {
  List<Anime> _library = const [];
  List<Recommendation> _ranked = const [];
  List<(Anime, AnimeExternalRelation)> _missing = const [];
  AiInsights _insights = AiInsights();
  Map<String, String> _aiReasons = const {};
  bool _loading = true;
  bool _aiPending = false;

  /// Purpose: Load and rank on first build, and follow synced changes.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Reads storage; may run the model once; registers with
  /// auto-sync so a trash change from another device reloads the page.
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

  /// Purpose: Rank the library, then ask the model for reasons.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Reads `anime_data.json`, `recommendations.json` and
  /// `ai_insights.json`; moves a pre-1.6.2 "Not interested" list into the
  /// synced trash once; runs the model when AI is on and ready.
  /// Notes: Internal helper used within this file only. The deterministic list
  /// renders at once; nothing waits on the model. Reasons are kept for this
  /// page only.
  Future<void> _load() async {
    await RecommendationStore.migrateFromInsights();
    final data = await AnimeStorage.load();
    final store = await RecommendationStore.load();
    final insights = await AiInsightsCache.load(
      liveIds: {for (final a in data.animes) a.id},
    );
    final ranked = RecommendationService.rank(
      data.animes,
      insights: insights,
      hidden: store.hidden.keys.toSet(),
      nowJst: JstTime.now(),
    );
    final index = SeriesIndex.build(data.animes);
    final missing = <(Anime, AnimeExternalRelation)>[];
    final seen = <String>{};
    for (final a in data.animes) {
      if (a.viewingStatus != AnimeViewingStatus.completed) continue;
      final series = index.seriesOf(a.id);
      final last = series != null && series.members.length >= 2
          ? series.members.last
          : a;
      if (last.id != a.id) continue;
      final sequel = index.missingSequelFor(a.id);
      if (sequel == null) continue;
      final key = sequelTrashKey(sequel);
      if (store.hiddenSequels.containsKey(key) || !seen.add(key)) continue;
      missing.add((last, sequel));
    }
    if (!mounted) return;
    final sameBatch =
        ranked.map((r) => r.anime.id).join('|') ==
        _ranked.map((r) => r.anime.id).join('|');
    setState(() {
      _library = data.animes;
      _insights = insights;
      _ranked = ranked;
      _missing = missing;
      _loading = false;
      if (!sameBatch) _aiReasons = const {};
    });
    if (!sameBatch || _aiReasons.isEmpty) await _requestAiReasons();
  }

  /// Purpose: Ask the on-device model for reasons, if it can answer.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Runs the model once as an interactive request.
  /// Notes: Internal helper used within this file only. Skipped when Apple
  /// reports the UI language unsupported (except Traditional Chinese, which
  /// is requested in Simplified and converted). On iOS and macOS the status
  /// is refreshed once with the UI locale first when Apple's answer for it
  /// is not known yet.
  Future<void> _requestAiReasons() async {
    final ai = ref.read(onDeviceAiServiceProvider);
    if (!ai.canGenerate || _ranked.isEmpty || _aiPending) return;
    final locale = Localizations.localeOf(context);
    // Apple reports whether the model supports the UI language only when it
    // is asked with a locale, so ask once here if nothing has yet.
    if (ai.coreInfo?.localeSupported == null &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      await ai.refreshStatus(
        localeTag: locale.countryCode == null
            ? locale.languageCode
            : '${locale.languageCode}_${locale.countryCode}',
      );
      if (!mounted || !ai.canGenerate) return;
    }
    final language = ReasonLanguage.forLocale(
      locale,
      localeSupported: ai.coreInfo?.localeSupported,
    );
    if (language == null) return;
    setState(() => _aiPending = true);
    final reasons = await writeAiReasons(
      ai,
      ranked: _ranked,
      library: _library,
      language: language,
      insights: _insights,
    );
    if (!mounted) return;
    setState(() {
      _aiReasons = reasons;
      _aiPending = false;
    });
  }

  /// Purpose: Put one library card into the trash.
  /// Inputs: `anime`.
  /// Returns: None.
  /// Side effects: Writes `recommendations.json` (synced); removes the card.
  /// Notes: Internal helper used within this file only. Restored from the
  /// trash page.
  Future<void> _hide(Anime anime) async {
    await RecommendationStore.hide([anime.id]);
    if (!mounted) return;
    setState(() {
      _ranked = [
        for (final r in _ranked)
          if (r.anime.id != anime.id) r,
      ];
    });
  }

  /// Purpose: Put one missing-sequel card into the trash.
  /// Inputs: `source` — the record it follows; `sequel`.
  /// Returns: None.
  /// Side effects: Writes `recommendations.json` (synced); removes the card.
  /// Notes: Internal helper used within this file only.
  Future<void> _hideSequel(Anime source, AnimeExternalRelation sequel) async {
    final key = sequelTrashKey(sequel);
    await RecommendationStore.hideSequels([_sequelEntry(source, sequel)]);
    if (!mounted) return;
    setState(() {
      _missing = [
        for (final m in _missing)
          if (sequelTrashKey(m.$2) != key) m,
      ];
    });
  }

  /// Purpose: Describe a missing-sequel card as a trash entry.
  /// Inputs: `source`, `sequel`.
  /// Returns: `HiddenSequelEntry` without a timestamp.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  HiddenSequelEntry _sequelEntry(Anime source, AnimeExternalRelation sequel) =>
      HiddenSequelEntry(
        sequelTrashKey(sequel),
        sourceId: source.id,
        title: sequel.title,
        source: sequel.source,
      );

  /// Purpose: Trash the whole current batch and show the next one.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: One write of `recommendations.json` (synced); reloads;
  /// shows a snack bar whose Undo restores exactly that batch.
  /// Notes: Internal helper used within this file only. This is what the
  /// refresh action means: the batch the user looked at and passed over is
  /// "not interested".
  Future<void> _refreshBatch() async {
    final l10n = AppLocalizations.of(context)!;
    final ids = [for (final r in _ranked) r.anime.id];
    final sequels = [for (final (s, q) in _missing) _sequelEntry(s, q)];
    if (ids.isEmpty && sequels.isEmpty) return;
    await RecommendationStore.hideBatch(ids, sequels);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            l10n.recommendationsRefreshed(ids.length + sequels.length),
          ),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () async {
              await RecommendationStore.restore(ids);
              await RecommendationStore.restoreSequels(
                sequels.map((e) => e.key),
              );
              await _load();
            },
          ),
        ),
      );
  }

  /// Purpose: Open the global trash and reload on return.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Navigation; reloads.
  /// Notes: Internal helper used within this file only.
  Future<void> _openTrash() async {
    await context.push('/recommendations/trash');
    await _load();
  }

  /// Purpose: Build the page.
  /// Inputs: `context`.
  /// Returns: The widget tree.
  /// Side effects: None.
  /// Notes: Columns follow the Home list's column preference.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider);
    final screen = MediaQuery.sizeOf(context);
    final columns = listColumnCount(
      screenWidth: screen.width,
      screenHeight: screen.height,
      contentWidth: screen.width,
      preference: settings.homeListColumns,
    );
    final items = <Widget>[
      for (final r in _ranked) _card(r, l10n),
      for (final (source, sequel) in _missing)
        _missingCard(source, sequel, l10n),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.recommendationsTitle),
        actions: [
          IconButton(
            tooltip: l10n.recommendationsRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: _loading || items.isEmpty ? null : _refreshBatch,
          ),
          IconButton(
            tooltip: l10n.recommendationsTrash,
            icon: const Icon(Icons.delete_outline),
            onPressed: _openTrash,
          ),
        ],
        bottom: _aiPending
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.recommendationsEmpty,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: adaptiveTileRows(
                columns: columns,
                itemCount: items.length,
                itemBuilder: (i) => items[i],
              ),
            ),
    );
  }

  /// Purpose: Build one recommendation card.
  /// Inputs: `r`, `l10n`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. The AI reason, when
  /// there is one, sits under its "Generated on this device" label.
  Widget _card(Recommendation r, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final aiReason = _aiReasons[r.anime.id];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/anime/detail/${r.anime.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cover(r.anime),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.anime.displayTitle,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final reason in r.reasons)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(reasonLabel(reason, l10n)),
                          ),
                      ],
                    ),
                    if (aiReason != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              l10n.aiGeneratedLabel,
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                        ],
                      ),
                      Text(aiReason, style: theme.textTheme.bodyMedium),
                    ],
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: () => _hide(r.anime),
                        child: Text(l10n.recommendationsNotInterested),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Purpose: Build a card for a sequel the library does not have.
  /// Inputs: `source` — the member it follows; `sequel`; `l10n`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Opens the prefilled
  /// create page; the search starts only in full builds. Since 1.6.2 it has a
  /// *Not interested* button like the library cards.
  Widget _missingCard(
    Anime source,
    AnimeExternalRelation sequel,
    AppLocalizations l10n,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.new_releases_outlined),
            title: Text(
              l10n.seriesMissingSequel(sequel.title ?? '?', sequel.source),
            ),
            subtitle: Text(l10n.recommendationsNotInLibrary),
            trailing: const Icon(Icons.add),
            onTap: () async {
              await context.push(
                '/anime/edit',
                extra: NextSeasonPrefill.fromRelation(source, sequel),
              );
              await _load();
            },
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 12, bottom: 4),
              child: TextButton(
                onPressed: () => _hideSequel(source, sequel),
                child: Text(l10n.recommendationsNotInterested),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Purpose: Build a small cover, or a placeholder.
  /// Inputs: `anime`.
  /// Returns: `Widget`.
  /// Side effects: Reads the cover file.
  /// Notes: Internal helper used within this file only.
  Widget _cover(Anime anime) => recommendationCover(anime);
}

/// Purpose: Build a small recommendation cover, or a placeholder.
/// Inputs: `anime`; `size` — 56×80 by default.
/// Returns: `Widget`.
/// Side effects: Reads the cover file through `ImageService.resolve`.
/// Notes: Shared by the global page, the trash page and the related card.
Widget recommendationCover(Anime anime, {Size size = const Size(56, 80)}) {
  final path = anime.coverImage;
  if (path == null) {
    return SizedBox.fromSize(
      size: size,
      child: const Icon(Icons.movie_outlined),
    );
  }
  return FutureBuilder<File>(
    future: ImageService.resolve(path),
    builder: (context, snap) => ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: snap.hasData && snap.data!.existsSync()
          ? Image.file(
              snap.data!,
              width: size.width,
              height: size.height,
              fit: BoxFit.cover,
            )
          : SizedBox.fromSize(size: size),
    ),
  );
}
