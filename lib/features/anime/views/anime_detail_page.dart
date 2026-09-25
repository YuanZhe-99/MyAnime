import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/flavor.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/services/image_service.dart';
import '../../../shared/services/share_service.dart';
import '../../../shared/utils/detail_layout.dart';
import '../../../shared/widgets/delete_confirm.dart';
import '../../ai/services/ai_insights_cache.dart';
import '../../categories/services/category_service.dart';
import '../models/anime.dart';
import '../models/anime_category.dart';
import '../services/anime_search_service.dart';
import '../services/anime1_service.dart';
import '../services/anime_storage.dart';
import '../services/metadata_update_service.dart';
import '../services/series_service.dart';
import 'anime1_labels.dart';
import 'archive_labels.dart';
import 'category_widgets.dart';
import 'series_widgets.dart';

class AnimeDetailPage extends StatefulWidget {
  final String animeId;

  /// Purpose: Create a anime detail page instance.
  /// Inputs: `key`, `animeId`.
  /// Returns: A new `AnimeDetailPage` instance.
  /// Side effects: None.
  /// Notes: None.
  const AnimeDetailPage({super.key, required this.animeId});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  State<AnimeDetailPage> createState() => _AnimeDetailPageState();
}

class _AnimeDetailPageState extends State<AnimeDetailPage> {
  Anime? _anime;
  SeriesIndex? _seriesIndex;
  AnimeSeries? _series;
  AnimeExternalRelation? _missingSequel;
  bool _categoriesOn = false;
  EffectiveCategories _categories = EffectiveCategories.empty;
  bool _refreshingMeta = false;
  bool _checkingProgress = false;

  /// Purpose: Initialize listeners, controllers, and first-load work for this state object.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Initializes owned state, listeners, or async work.
  /// Notes: Flutter lifecycle override.
  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Purpose: Reload when the page is rebuilt for a different record.
  /// Inputs: `oldWidget`.
  /// Returns: None.
  /// Side effects: Calls `_load()` when `animeId` changed.
  /// Notes: Flutter lifecycle override. The route keys the page by id, so this
  /// is a safety net: before 1.6.1, `context.go` between seasons reused one
  /// State and left the first-opened record on screen.
  @override
  void didUpdateWidget(covariant AnimeDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animeId != widget.animeId) _load();
  }

  /// Purpose: Load the record and the series it belongs to.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Reads `anime_data.json`; sets state.
  /// Notes: Internal helper used within this file only. Builds a
  /// `SeriesIndex` over the whole library, which replaced the pre-1.6.0 rule of
  /// matching an identical `displayTitle` and comparing season labels as
  /// strings (which put `Season 10` before `Season 2`). Nothing is written.
  Future<void> _load() async {
    final data = await AnimeStorage.loadFixingSeasonLabels(seasonLabelFixups);
    final found = data.animeList
        .where((a) => a.id == widget.animeId)
        .firstOrNull;
    // Categories are shown only while automatic categories are on; the AI
    // cache is read only while on-device AI is on too.
    final categoriesOn = await AnimeStorage.getAutoCategoriesEnabled();
    final insights = categoriesOn && await AnimeStorage.getOnDeviceAiEnabled()
        ? await AiInsightsCache.load()
        : null;
    if (!mounted) return;
    final index = SeriesIndex.build(data.animeList);
    final series = found == null ? null : index.seriesOf(found.id);
    setState(() {
      _anime = found;
      _seriesIndex = index;
      _series = series != null && series.members.length >= 2 ? series : null;
      _missingSequel = found == null ? null : index.missingSequelFor(found.id);
      _categoriesOn = categoriesOn;
      _categories = found == null
          ? EffectiveCategories.empty
          : resolveCategories(found, insights: insights);
    });
  }

  /// Purpose: Let the user set this record's categories.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May write the record (a user edit, `modifiedAt` stamped);
  /// reloads.
  /// Notes: Internal helper used within this file only. Saving writes the
  /// user's list, even an empty one, and keeps any ids this build does not
  /// know; "Reset to automatic" removes the field.
  Future<void> _editCategories() async {
    final anime = _anime;
    if (anime == null) return;
    final result = await showCategoryEditor(
      context,
      initial: _categories.ids,
      hasOverride: anime.categories != null,
    );
    if (result == null) return;
    final now = DateTime.now().toUtc();
    final Anime updated;
    switch (result) {
      case CategoriesChosen(:final ids):
        final unknown = [
          for (final id in anime.categories ?? const <String>[])
            if (!animeCategoryIds.contains(id)) id,
        ];
        updated = anime.copyWith(
          categories: [...ids, ...unknown],
          modifiedAt: now,
        );
      case CategoriesReset():
        updated = anime.copyWith(clearCategories: true, modifiedAt: now);
    }
    await AnimeStorage.addOrUpdate(updated);
    await _load();
  }

  /// Purpose: Open the create page for a sequel the databases list but the
  /// library lacks.
  /// Inputs: `relation`.
  /// Returns: None.
  /// Side effects: Pushes `/anime/edit`; reloads afterwards.
  /// Notes: Internal helper used within this file only. Full builds also start
  /// the online search; store builds get the title pre-filled only.
  Future<void> _addMissingSequel(AnimeExternalRelation relation) async {
    final anime = _anime;
    if (anime == null) return;
    final last = _series?.members.last ?? anime;
    await context.push(
      '/anime/edit',
      extra: NextSeasonPrefill.fromRelation(last, relation),
    );
    await _load();
  }

  /// Purpose: Run one of the series card's menu actions.
  /// Inputs: `action`.
  /// Returns: None.
  /// Side effects: May write records through `AnimeStorage.addOrUpdateAll`,
  /// open the manage sheet or the create page, and reload.
  /// Notes: Internal helper used within this file only. Every write is a user
  /// edit stamped by `SeriesEditor`.
  Future<void> _runSeriesAction(SeriesAction action) async {
    final anime = _anime;
    final index = _seriesIndex;
    if (anime == null || index == null) return;
    final editor = SeriesEditor(index);
    switch (action) {
      case SeriesAction.manage:
        final changed = await showSeriesManageSheet(
          context,
          anime: anime,
          index: index,
        );
        if (changed) await _load();
      case SeriesAction.addNextSeason:
        final last = _series?.members.last ?? anime;
        await context.push('/anime/edit', extra: NextSeasonPrefill.after(last));
        await _load();
      case SeriesAction.remove:
        await AnimeStorage.addOrUpdateAll(editor.removeFromSeries(anime));
        await _load();
      case SeriesAction.letAppDecide:
        await AnimeStorage.addOrUpdateAll(editor.letAppDecide(anime));
        await _load();
    }
  }

  /// Purpose: Provide the internal toggle episode helper for this file.
  /// Inputs: `ep`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Future<void> _toggleEpisode(int ep) async {
    if (_anime == null) return;
    final current = _anime!.episodeStatuses[ep] ?? EpisodeStatus.unwatched;
    EpisodeStatus next;
    switch (current) {
      case EpisodeStatus.unwatched:
        next = EpisodeStatus.watched;
        break;
      case EpisodeStatus.watched:
        next = EpisodeStatus.skippedThisWeek;
        break;
      case EpisodeStatus.skippedThisWeek:
        next = EpisodeStatus.unwatched;
        break;
    }
    final updated = _anime!.copyWith(
      episodeStatuses: Map.of(_anime!.episodeStatuses)..[ep] = next,
      modifiedAt: DateTime.now().toUtc(),
    );
    await AnimeStorage.addOrUpdate(updated);
    await _load();
  }

  /// Purpose: Shift episode [ep] and all subsequent episodes by [delta] weeks.
  /// Inputs: `ep`, `delta`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Shift episode [ep] and all subsequent episodes by [delta] weeks. delta > 0 = delay (push back), delta < 0 = advance (pull forward).
  Future<void> _shiftFromEpisode(int ep, int delta) async {
    if (_anime == null) return;
    final offsets = Map<int, int>.of(_anime!.episodeWeekOffsets);
    offsets[ep] = (offsets[ep] ?? 0) + delta;
    if (offsets[ep] == 0) offsets.remove(ep);
    final updated = _anime!.copyWith(
      episodeWeekOffsets: offsets,
      modifiedAt: DateTime.now().toUtc(),
    );
    await AnimeStorage.addOrUpdate(updated);
    await _load();
  }

  /// Purpose: Reset all episode week offsets to original schedule based on firstAirDate.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Reset all episode week offsets to original schedule based on firstAirDate.
  Future<void> _resetSchedule() async {
    if (_anime == null) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.animeResetSchedule),
        content: Text(l10n.animeResetScheduleConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.settingsConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final updated = _anime!.copyWith(
      episodeWeekOffsets: {},
      modifiedAt: DateTime.now().toUtc(),
    );
    await AnimeStorage.addOrUpdate(updated);
    await _load();
  }

  /// Purpose: Provide the internal delete helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  Future<void> _delete() async {
    if (_anime == null) return;
    final ok = await confirmDelete(context, _anime!.displayTitle);
    if (!ok) return;
    await AnimeStorage.deleteAnime(_anime!.id);
    if (mounted) context.pop();
  }

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (_anime == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final anime = _anime!;
    final totalEps = anime.totalEpisodes ?? 0;
    final watchedCount = anime.episodeStatuses.values
        .where((s) => s == EpisodeStatus.watched)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text(anime.displayTitle),
        actions: [
          // The series card carries these actions when there is a series; a
          // record in none — including a standalone one — reaches them here.
          if (_series == null)
            PopupMenuButton<SeriesAction>(
              icon: const Icon(Icons.link),
              tooltip: l10n.seriesTitle,
              onSelected: _runSeriesAction,
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: SeriesAction.manage,
                  child: Text(l10n.seriesLinkTo),
                ),
                PopupMenuItem(
                  value: SeriesAction.addNextSeason,
                  child: Text(l10n.seriesAddNext),
                ),
                if (anime.seriesLink != null)
                  PopupMenuItem(
                    value: SeriesAction.letAppDecide,
                    child: Text(l10n.seriesLetAppDecide),
                  ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: l10n.animeShare,
            onPressed: () => ShareService.shareAnime(context, anime),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await context.push('/anime/edit/${anime.id}');
              await _load();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screen = MediaQuery.sizeOf(context);
          final headerChildren = _buildHeaderChildren(
            anime,
            theme,
            l10n,
            totalEps,
            watchedCount,
          );
          final detailChildren = _buildDetailChildren(anime, theme, l10n);
          final episodeChildren = _buildEpisodeChildren(anime, theme, l10n);

          if (!useDetailTwoPane(screen.width, screen.height)) {
            return ListView(
              children: [
                if (anime.coverImage != null)
                  _buildCover(anime, width: 180, height: 260),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [...headerChildren, ...detailChildren],
                  ),
                ),
                ...episodeChildren,
              ],
            );
          }

          final paneWidth = detailLeftPaneWidth(constraints.maxWidth);
          final cover = detailCoverSize(paneWidth, constraints.maxHeight);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: paneWidth,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (anime.coverImage != null)
                        _buildCover(
                          anime,
                          width: cover.width,
                          height: cover.height,
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: headerChildren,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: ListView(
                  children: [
                    if (detailChildren.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: detailChildren,
                        ),
                      ),
                    ...episodeChildren,
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Purpose: Build the cover image block at an explicit size.
  /// Inputs: `anime`, `width`, `height` — the cover box in logical pixels.
  /// Returns: `Widget`.
  /// Side effects: Reads the cover file through `ImageService.resolve`.
  /// Notes: The size is a parameter because the two-pane layout sizes the cover
  /// from the space its left pane has left over, while the single-column layout
  /// keeps the original fixed 180x260 box. Callers guard on `coverImage`.
  Widget _buildCover(
    Anime anime, {
    required double width,
    required double height,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Center(
        child: FutureBuilder<File>(
          future: ImageService.resolve(anime.coverImage!),
          builder: (context, snap) {
            if (snap.hasData && snap.data!.existsSync()) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  snap.data!,
                  height: height,
                  width: width,
                  fit: BoxFit.cover,
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  /// Purpose: Build the header block: Japanese title, chips, and watch progress.
  /// Inputs: `anime`, `theme`, `l10n`, `totalEps`, `watchedCount`.
  /// Returns: `List<Widget>` for a `crossAxisAlignment.start` `Column`.
  /// Side effects: None.
  /// Notes: This is everything the two-pane layout keeps in its left pane, so
  /// the split point between this and `_buildDetailChildren` is what decides
  /// which column each section lands in.
  List<Widget> _buildHeaderChildren(
    Anime anime,
    ThemeData theme,
    AppLocalizations l10n,
    int totalEps,
    int watchedCount,
  ) {
    return [
      if (anime.titleJa != null && anime.titleJa!.isNotEmpty)
        Text(
          anime.titleJa!,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          Chip(label: Text(anime.season)),
          Chip(label: Text(_typeLabel(anime.effectiveType, l10n))),
          if (anime.airDayOfWeek != null)
            Chip(
              avatar: const Icon(Icons.today, size: 16),
              label: Text(_dayName(anime.airDayOfWeek!, l10n)),
            ),
          if (anime.airTime != null)
            Chip(
              avatar: const Icon(Icons.schedule, size: 16),
              label: Text(anime.airTime!),
            ),
          if (anime.infoUrl != null)
            ActionChip(
              avatar: const Icon(Icons.info_outline, size: 16),
              label: Text(l10n.animeOpenInfoUrl),
              onPressed: () => launchUrl(
                Uri.parse(anime.infoUrl!),
                mode: LaunchMode.externalApplication,
              ),
            ),
          // Online lookups are a full-build feature; store builds
          // must never reach AnimeSearchService.
          if (AppFlavor.isFull && _refreshableUrls(anime).isNotEmpty)
            ActionChip(
              avatar: _refreshingMeta
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync, size: 16),
              label: Text(l10n.animeRefreshMeta),
              onPressed: _refreshingMeta
                  ? null
                  : () => _refreshExternalMeta(anime),
            ),
          if (anime.watchUrl != null)
            ActionChip(
              avatar: const Icon(Icons.open_in_browser, size: 16),
              label: Text(l10n.animeOpenUrl),
              onPressed: () => launchUrl(
                Uri.parse(anime.watchUrl!),
                mode: LaunchMode.externalApplication,
              ),
            ),
          // The stored progress is public site data and renders in every
          // flavor; only the re-check (a network call) is a full-build action.
          if (Anime1Service.isAnime1Url(anime.watchUrl))
            ActionChip(
              avatar: _checkingProgress
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.update, size: 16),
              label: Text(_watchProgressChipLabel(anime, l10n)),
              onPressed: AppFlavor.isFull && !_checkingProgress
                  ? () => _checkWatchProgress(anime)
                  : null,
            ),
        ],
      ),
      if (_categoriesOn) ...[
        const SizedBox(height: 8),
        CategoryChips(categories: _categories, onEdit: _editCategories),
      ],
      const SizedBox(height: 8),
      LinearProgressIndicator(
        value: totalEps > 0 ? watchedCount / totalEps : 0,
      ),
      const SizedBox(height: 4),
      Text(
        '$watchedCount / $totalEps ${l10n.animeEpisodes}',
        style: theme.textTheme.bodySmall,
      ),
    ];
  }

  /// Purpose: Build the cards below the progress bar, plus the series card.
  /// Inputs: `anime`, `theme`, `l10n`.
  /// Returns: `List<Widget>` for a `crossAxisAlignment.start` `Column`.
  /// Side effects: None.
  /// Notes: Everything here moves to the scrollable right pane in the two-pane
  /// layout. Each entry keeps its leading `SizedBox(height: 12)` so the spacing
  /// is identical whether it follows the progress bar or opens the right pane.
  List<Widget> _buildDetailChildren(
    Anime anime,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return [
      if (anime.rating?.effectiveOverall != null) ...[
        const SizedBox(height: 12),
        _buildRatingCard(anime.rating!, theme, l10n),
      ],
      if (anime.externalMeta?.hasAnyData == true) ...[
        const SizedBox(height: 12),
        _buildExternalMetaCard(anime.externalMeta!, theme, l10n),
      ],
      if (anime.localArchive?.hasAnyData == true) ...[
        const SizedBox(height: 12),
        _buildLocalArchiveCard(anime.localArchive!, theme, l10n),
      ],
      if (anime.notes != null && anime.notes!.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(anime.notes!, style: theme.textTheme.bodyMedium),
      ],

      // A sequel the databases list that the library lacks.
      if (_missingSequel case final sequel?) ...[
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.new_releases_outlined),
            title: Text(
              l10n.seriesMissingSequel(sequel.title ?? '?', sequel.source),
            ),
            subtitle: Text(l10n.seriesMissingSequelHint),
            trailing: const Icon(Icons.add),
            onTap: () => _addMissingSequel(sequel),
          ),
        ),
      ],

      // Series card, then prev/next driven by the series index.
      if (_series case final series?) ...[
        const SizedBox(height: 12),
        SeriesCard(
          series: series,
          current: anime,
          onOpen: (a) => context.push('/anime/detail/${a.id}'),
          onAction: _runSeriesAction,
        ),
        const SizedBox(height: 8),
        // A Wrap rather than a Row, so the two buttons stack instead of
        // overflowing where long labels meet a narrow phone.
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          children: [
            if (series.previousOf(anime.id) case final prev?)
              TextButton.icon(
                icon: const Icon(Icons.arrow_back, size: 16),
                label: Text(l10n.animePrevSeason),
                onPressed: () => context.push('/anime/detail/${prev.id}'),
              ),
            if (series.nextOf(anime.id) case final next?)
              TextButton.icon(
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text(l10n.animeNextSeason),
                onPressed: () => context.push('/anime/detail/${next.id}'),
              ),
          ],
        ),
      ],
    ];
  }

  /// Purpose: Build the episode list header and one row per tracked episode.
  /// Inputs: `anime`, `theme`, `l10n`.
  /// Returns: `List<Widget>` for a scrolling list.
  /// Side effects: None.
  /// Notes: Returned flat rather than wrapped in a `Column` so the rows stay
  /// direct `ListView` children in both layouts.
  List<Widget> _buildEpisodeChildren(
    Anime anime,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return [
      const Divider(),

      // Episode list
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Row(
          children: [
            Text(
              l10n.animeEpisodeList,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const Spacer(),
            if (anime.episodeWeekOffsets.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.restart_alt, size: 20),
                tooltip: l10n.animeResetSchedule,
                onPressed: () => _resetSchedule(),
              ),
            if (anime.endEpisode != null) _buildAbandonOrResume(anime, l10n),
            TextButton(
              onPressed: () => _toggleAllWatched(),
              child: Text(
                anime.isCompleted
                    ? l10n.animeMarkAllUnwatched
                    : l10n.animeMarkAllWatched,
              ),
            ),
          ],
        ),
      ),
      ...List.generate(
        anime.endEpisode != null
            ? anime.endEpisode! - anime.startEpisode + 1
            : 0,
        (i) {
          final ep = anime.startEpisode + i;
          final status = anime.episodeStatuses[ep] ?? EpisodeStatus.unwatched;
          final airDate = anime.getEpisodeCalendarDate(ep);
          final airStr = airDate != null
              ? DateFormat.MMMd().format(airDate)
              : '';

          return ListTile(
            dense: true,
            leading: _statusIcon(status, theme),
            title: Text(l10n.animeEpisodeShort(ep)),
            subtitle: airStr.isNotEmpty ? Text(airStr) : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    tooltip: l10n.animeShiftForward,
                    icon: const Icon(Icons.keyboard_double_arrow_left),
                    onPressed: () => _shiftFromEpisode(ep, -1),
                  ),
                ),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    tooltip: l10n.animeShiftBackward,
                    icon: const Icon(Icons.keyboard_double_arrow_right),
                    onPressed: () => _shiftFromEpisode(ep, 1),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 36,
                  child: Text(
                    _statusLabel(status, l10n),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _statusColor(status, theme),
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            onTap: () => _toggleEpisode(ep),
          );
        },
      ),

      const SizedBox(height: 24),
    ];
  }

  /// Purpose: Provide the internal toggle all watched helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Future<void> _toggleAllWatched() async {
    if (_anime == null || _anime!.endEpisode == null) return;
    final allWatched = _anime!.isCompleted;
    final newStatuses = <int, EpisodeStatus>{};
    for (var ep = _anime!.startEpisode; ep <= _anime!.endEpisode!; ep++) {
      newStatuses[ep] = allWatched
          ? EpisodeStatus.unwatched
          : EpisodeStatus.watched;
    }
    final updated = _anime!.copyWith(
      episodeStatuses: newStatuses,
      modifiedAt: DateTime.now().toUtc(),
    );
    await AnimeStorage.addOrUpdate(updated);
    await _load();
  }

  /// Purpose: Provide the internal build abandon or resume helper for this file.
  /// Inputs: `anime`, `l10n`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _buildAbandonOrResume(Anime anime, AppLocalizations l10n) {
    final statuses = anime.episodeStatuses;
    final hasUnwatched =
        Iterable.generate(
          anime.endEpisode! - anime.startEpisode + 1,
          (i) => anime.startEpisode + i,
        ).any(
          (ep) =>
              (statuses[ep] ?? EpisodeStatus.unwatched) ==
              EpisodeStatus.unwatched,
        );
    final hasSkipped = statuses.values.any(
      (s) => s == EpisodeStatus.skippedThisWeek,
    );

    if (hasUnwatched) {
      return TextButton(
        onPressed: () => _abandonAnime(),
        child: Text(l10n.animeAbandon),
      );
    } else if (hasSkipped) {
      return TextButton(
        onPressed: () => _resumeAnime(),
        child: Text(l10n.animeResume),
      );
    }
    return const SizedBox.shrink();
  }

  /// Purpose: Provide the internal build local archive card helper for this file.
  /// Inputs: `archive`, `theme`, `l10n`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Read-only summary of
  /// the downloaded-copy record; editing happens on the edit page.
  Widget _buildLocalArchiveCard(
    AnimeLocalArchive archive,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final details = <String>[
      ?archiveQualityLabel(archive, l10n),
      if (archive.copies != null) l10n.animeArchiveCopiesValue(archive.copies!),
      if (archive.location != null && archive.location!.isNotEmpty)
        archive.location!,
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  archive.archived ? Icons.download_done : Icons.cloud_off,
                  color: archive.archived
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(l10n.animeLocalArchive, style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(
                  archive.archived
                      ? l10n.animeLocalArchiveArchived
                      : l10n.animeLocalArchiveNone,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: archive.archived
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: details
                    .map((detail) => Chip(label: Text(detail)))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Purpose: List the source pages this anime can be refreshed from.
  /// Inputs: `anime`.
  /// Returns: `List<String>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Delegates to
  /// `MetadataUpdateService.refreshableUrls` so the manual chip and the
  /// background refresher agree on what "refreshable" means.
  List<String> _refreshableUrls(Anime anime) =>
      MetadataUpdateService.refreshableUrls(anime);

  /// Purpose: Re-fetch external metadata from every remembered source page.
  /// Inputs: `anime`.
  /// Returns: None.
  /// Side effects: Issues HTTP requests, writes the updated anime to storage,
  /// and shows a snack bar with the outcome.
  /// Notes: Internal helper used within this file only. Only the external
  /// metadata is touched — the user's own rating, episode progress, and manual
  /// edits are left exactly as they are. Writes through
  /// `AnimeStorage.patchExternalMeta`, which deliberately leaves `modifiedAt`
  /// alone: bumping it would make a record another device deleted come back,
  /// and would raise conflicts for an edit the user never made. Callers must
  /// gate on `AppFlavor.isFull`, since store builds do not ship online lookups.
  Future<void> _refreshExternalMeta(Anime anime) async {
    final l10n = AppLocalizations.of(context)!;
    final urls = _refreshableUrls(anime);
    if (urls.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.animeRefreshMetaNone)));
      return;
    }

    setState(() => _refreshingMeta = true);
    try {
      final results = await AnimeSearchService.refreshAll(urls);
      if (!mounted) return;
      if (results.isEmpty) {
        setState(() => _refreshingMeta = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.animeRefreshMetaNone)));
        return;
      }

      final now = DateTime.now().toUtc();
      var merged = anime.externalMeta ?? const AnimeExternalMeta();
      for (final result in results) {
        merged = merged.mergedWith(
          AnimeSearchService.toExternalMeta(result, fetchedAt: now),
          refreshedAt: now,
        );
      }
      await AnimeStorage.patchExternalMeta({anime.id: merged});
      if (!mounted) return;
      setState(() => _refreshingMeta = false);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.animeRefreshMetaDone)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _refreshingMeta = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.animeRefreshMetaFailed('$e'))),
      );
    }
  }

  /// Purpose: Label the anime1.me chip from the stored watch progress.
  /// Inputs: `anime`, `l10n`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Falls back to the
  /// "check" prompt when nothing valid is stored — including when the watch
  /// URL was edited after the last check.
  String _watchProgressChipLabel(Anime anime, AppLocalizations l10n) {
    final progress = anime.validWatchProgress;
    final text = progress == null ? null : watchProgressLabel(l10n, progress);
    return text == null
        ? l10n.anime1CheckProgress
        : l10n.anime1ProgressLabel(text);
  }

  /// Purpose: Re-read what anime1.me currently lists for this record's URL.
  /// Inputs: `anime`.
  /// Returns: None.
  /// Side effects: Up to three HTTP requests, a write through
  /// `AnimeStorage.patchExternalMeta`, and a snack bar on failure.
  /// Notes: Internal helper used within this file only. Like
  /// `_refreshExternalMeta`, this never bumps `modifiedAt` — the progress is a
  /// cache of public site data, not a user edit. Callers gate on
  /// `AppFlavor.isFull`.
  Future<void> _checkWatchProgress(Anime anime) async {
    final l10n = AppLocalizations.of(context)!;
    final url = anime.watchUrl;
    if (url == null) return;
    setState(() => _checkingProgress = true);
    try {
      final progress = await Anime1Service.fetchProgress(url);
      if (!mounted) return;
      if (progress == null) {
        setState(() => _checkingProgress = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.anime1ProgressUnknown)));
        return;
      }
      final merged = (anime.externalMeta ?? const AnimeExternalMeta())
          .mergedWith(AnimeExternalMeta(watchProgress: progress));
      await AnimeStorage.patchExternalMeta({anime.id: merged});
      if (!mounted) return;
      setState(() => _checkingProgress = false);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _checkingProgress = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.anime1ProgressFailed('$e'))));
    }
  }

  /// Purpose: Render the public metadata pulled from external databases.
  /// Inputs: `meta`, `theme`, `l10n`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Kept visually distinct
  /// from the personal rating card above it — external scores never merge into
  /// the user's own rating.
  Widget _buildExternalMetaCard(
    AnimeExternalMeta meta,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final rows = <(String, String)>[
      if (meta.format != null) (l10n.animeFormat, meta.format!),
      if (meta.status != null) (l10n.animeStatus, meta.status!),
      if (meta.durationMinutes != null)
        (l10n.animeDuration, l10n.animeDurationValue(meta.durationMinutes!)),
      if (meta.endDate != null)
        (l10n.animeEndDate, DateFormat.yMd().format(meta.endDate!)),
      if (meta.studios.isNotEmpty) (l10n.animeStudios, meta.studios.join(', ')),
      if (meta.genres.isNotEmpty) (l10n.animeGenres, meta.genres.join(', ')),
      if (meta.synonyms.isNotEmpty)
        (l10n.animeAlternateTitles, meta.synonyms.join(' / ')),
    ];
    final scored = meta.ratings.where((r) => r.score != null).toList();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.travel_explore,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.animeExternalMeta,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (meta.refreshedAt != null)
                  Text(
                    l10n.animeRefreshedAt(
                      DateFormat.yMd().format(meta.refreshedAt!.toLocal()),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            for (final (label, value) in rows) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(value, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ],
            if (scored.isNotEmpty) ...[
              const Divider(height: 20),
              Text(
                l10n.animeExternalRatings,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final rating in scored)
                    Chip(
                      avatar: const Icon(Icons.star_outline, size: 16),
                      label: Text(
                        '${rating.source} '
                        '${rating.score!.toStringAsFixed(1)}'
                        '/${rating.scoreMax.toStringAsFixed(0)}'
                        '${rating.votes != null ? ' · ${l10n.animeExternalVotes(rating.votes!)}' : ''}',
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Purpose: Provide the internal build rating card helper for this file.
  /// Inputs: `rating`, `theme`, `l10n`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Shows only the user's
  /// own scores; external database scores live in the card above.
  Widget _buildRatingCard(
    AnimeRating rating,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final scoreText = _formatScore(rating.effectiveOverall);
    final sourceText = rating.hasManualOverall
        ? l10n.animeRatingManualOverall
        : l10n.animeRatingAutoOverall;
    final subScores = [
      (l10n.animeRatingVisual, rating.visual),
      (l10n.animeRatingStory, rating.story),
      (l10n.animeRatingCharacter, rating.character),
      (l10n.animeRatingMusic, rating.music),
      (l10n.animeRatingEnjoyment, rating.enjoyment),
    ].where((entry) => entry.$2 != null).toList();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(l10n.animeRating, style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(
                  scoreText != null ? '$scoreText / 10' : '-',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              sourceText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (subScores.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: subScores
                    .map(
                      (entry) => Chip(
                        label: Text('${entry.$1}: ${_formatScore(entry.$2)}'),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Purpose: Provide the internal format score helper for this file.
  /// Inputs: `score`.
  /// Returns: `String?`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String? _formatScore(double? score) {
    if (score == null) return null;
    if (score == score.roundToDouble()) return score.toInt().toString();
    return score.toStringAsFixed(1);
  }

  /// Purpose: Provide the internal abandon anime helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Future<void> _abandonAnime() async {
    if (_anime == null || _anime!.endEpisode == null) return;
    final newStatuses = Map<int, EpisodeStatus>.of(_anime!.episodeStatuses);
    for (var ep = _anime!.startEpisode; ep <= _anime!.endEpisode!; ep++) {
      if ((newStatuses[ep] ?? EpisodeStatus.unwatched) ==
          EpisodeStatus.unwatched) {
        newStatuses[ep] = EpisodeStatus.skippedThisWeek;
      }
    }
    final updated = _anime!.copyWith(
      episodeStatuses: newStatuses,
      modifiedAt: DateTime.now().toUtc(),
    );
    await AnimeStorage.addOrUpdate(updated);
    await _load();
  }

  /// Purpose: Provide the internal resume anime helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Future<void> _resumeAnime() async {
    if (_anime == null || _anime!.endEpisode == null) return;
    final newStatuses = Map<int, EpisodeStatus>.of(_anime!.episodeStatuses);
    for (var ep = _anime!.startEpisode; ep <= _anime!.endEpisode!; ep++) {
      if (newStatuses[ep] == EpisodeStatus.skippedThisWeek) {
        newStatuses[ep] = EpisodeStatus.unwatched;
      }
    }
    final updated = _anime!.copyWith(
      episodeStatuses: newStatuses,
      modifiedAt: DateTime.now().toUtc(),
    );
    await AnimeStorage.addOrUpdate(updated);
    await _load();
  }

  /// Purpose: Provide the internal type label helper for this file.
  /// Inputs: `type`, `l10n`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String _typeLabel(AnimeType type, AppLocalizations l10n) {
    switch (type) {
      case AnimeType.singleCour:
        return l10n.animeTypeSingleCour;
      case AnimeType.halfYear:
        return l10n.animeTypeHalfYear;
      case AnimeType.fullYear:
        return l10n.animeTypeFullYear;
      case AnimeType.longRunning:
        return l10n.animeTypeLongRunning;
      case AnimeType.allAtOnce:
        return l10n.animeTypeAllAtOnce;
    }
  }

  /// Purpose: Provide the internal day name helper for this file.
  /// Inputs: `dow`, `l10n`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String _dayName(int? dow, AppLocalizations l10n) {
    if (dow == null) return '?';
    final days = [
      '',
      l10n.dayMon,
      l10n.dayTue,
      l10n.dayWed,
      l10n.dayThu,
      l10n.dayFri,
      l10n.daySat,
      l10n.daySun,
    ];
    return days[dow.clamp(1, 7)];
  }

  /// Purpose: Provide the internal status icon helper for this file.
  /// Inputs: `status`, `theme`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _statusIcon(EpisodeStatus status, ThemeData theme) {
    switch (status) {
      case EpisodeStatus.watched:
        return Icon(Icons.check_circle, color: theme.colorScheme.primary);
      case EpisodeStatus.skippedThisWeek:
        return Icon(Icons.skip_next, color: theme.colorScheme.tertiary);
      case EpisodeStatus.unwatched:
        return const Icon(Icons.radio_button_unchecked);
    }
  }

  /// Purpose: Provide the internal status label helper for this file.
  /// Inputs: `status`, `l10n`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String _statusLabel(EpisodeStatus status, AppLocalizations l10n) {
    switch (status) {
      case EpisodeStatus.watched:
        return l10n.animeWatched;
      case EpisodeStatus.skippedThisWeek:
        return l10n.animeSkipped;
      case EpisodeStatus.unwatched:
        return l10n.animeUnwatched;
    }
  }

  /// Purpose: Provide the internal status color helper for this file.
  /// Inputs: `status`, `theme`.
  /// Returns: `Color?`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Color? _statusColor(EpisodeStatus status, ThemeData theme) {
    switch (status) {
      case EpisodeStatus.watched:
        return theme.colorScheme.primary;
      case EpisodeStatus.skippedThisWeek:
        return theme.colorScheme.tertiary;
      case EpisodeStatus.unwatched:
        return null;
    }
  }
}
