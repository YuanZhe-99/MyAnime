import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/providers/app_settings.dart';
import '../../../shared/services/image_service.dart';
import '../../../shared/utils/adaptive_layout.dart';
import '../../../shared/utils/jst_time.dart';
import '../../../shared/widgets/adaptive_tile_grid.dart';
import '../../ai/services/ai_insights_cache.dart';
import '../../ai/services/on_device_ai_service.dart';
import '../../anime/models/anime.dart';
import '../../anime/services/anime_storage.dart';
import '../../anime/services/series_service.dart';
import '../../anime/views/category_widgets.dart';
import '../services/ai_reason_service.dart';
import '../services/recommendation_service.dart';

/// "What to watch next": the library's own unwatched and in-progress records,
/// ranked, with reason chips; sequels the databases list but the library
/// lacks are appended, clearly marked. With on-device AI on and a model
/// available, up to three cards gain a short generated reason.
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

  /// Purpose: Load and rank on first build.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Reads storage; may run the model once.
  /// Notes: Flutter lifecycle override.
  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Purpose: Rank the library, then ask the model for reasons.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Reads `anime_data.json` and `ai_insights.json`; runs the
  /// model when AI is on and ready.
  /// Notes: Internal helper used within this file only. The deterministic list
  /// renders at once; nothing waits on the model. Reasons are kept for this
  /// page only.
  Future<void> _load() async {
    final data = await AnimeStorage.load();
    final insights = await AiInsightsCache.load(
      liveIds: {for (final a in data.animes) a.id},
    );
    final ranked = RecommendationService.rank(
      data.animes,
      insights: insights,
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
      if (sequel != null && seen.add(sequel.targetUrl ?? sequel.title ?? '')) {
        missing.add((last, sequel));
      }
    }
    if (!mounted) return;
    setState(() {
      _library = data.animes;
      _insights = insights;
      _ranked = ranked;
      _missing = missing;
      _loading = false;
    });
    await _requestAiReasons();
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
    if (!ai.canGenerate || _ranked.isEmpty) return;
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

  /// Purpose: Hide a candidate on this device.
  /// Inputs: `anime`.
  /// Returns: None.
  /// Side effects: Writes `ai_insights.json`.
  /// Notes: Internal helper used within this file only. Per device: the
  /// hidden list is not synced.
  Future<void> _hide(Anime anime) async {
    _insights.hiddenRecommendations.add(anime.id);
    await AiInsightsCache.save(_insights);
    if (!mounted) return;
    setState(() {
      _ranked = [
        for (final r in _ranked)
          if (r.anime.id != anime.id) r,
      ];
    });
  }

  /// Purpose: Word one reason chip.
  /// Inputs: `reason`, `l10n`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String _reasonLabel(RecommendationReason reason, AppLocalizations l10n) =>
      switch (reason) {
        NextAfterReason(:final previous) => l10n.reasonNextAfter(
          previous.displayTitle,
        ),
        CategoryMatchReason(:final categoryIds) => l10n.reasonLikeCategories(
          categoryIds.map((id) => categoryLabel(id, l10n)).join(', '),
        ),
        SameStudioReason(:final liked) => l10n.reasonSameStudio(
          liked.displayTitle,
        ),
        ExternalScoreReason(:final source, :final score) =>
          '$source ${score.toStringAsFixed(1)}',
        CatchUpReason() => l10n.reasonCatchUp,
      };

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
                            label: Text(_reasonLabel(reason, l10n)),
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
  /// create page; the search starts only in full builds.
  Widget _missingCard(
    Anime source,
    AnimeExternalRelation sequel,
    AppLocalizations l10n,
  ) {
    return Card(
      child: ListTile(
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
    );
  }

  /// Purpose: Build a small cover, or a placeholder.
  /// Inputs: `anime`.
  /// Returns: `Widget`.
  /// Side effects: Reads the cover file.
  /// Notes: Internal helper used within this file only.
  Widget _cover(Anime anime) {
    const size = Size(56, 80);
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
}
