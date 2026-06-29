import 'dart:io';
import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/image_service.dart';
import '../../../shared/services/share_service.dart';
import '../models/anime.dart';
import '../services/anime_storage.dart';
import 'quarter_picker_dialog.dart';

enum _StatsView { summary, ranking }

enum _TimeScope { quarter, year, all }

enum _TrendGranularity { quarter, year }

enum _RankingTimeFilter { all, quarter, year, custom }

enum _SummarySharePriority { recent, oldest }

class StatisticsPage extends StatefulWidget {
  /// Purpose: Create a statistics page instance.
  /// Inputs: None.
  /// Returns: A new `StatisticsPage` instance.
  /// Side effects: None.
  /// Notes: None.
  const StatisticsPage({super.key});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  List<Anime> _allAnime = [];
  _StatsView _view = _StatsView.summary;
  _TimeScope _scope = _TimeScope.quarter;
  _TrendGranularity _allTrendGranularity = _TrendGranularity.quarter;
  _RankingTimeFilter _rankingTimeFilter = _RankingTimeFilter.all;
  AnimeType? _rankingTypeFilter;
  AnimeRatingField _rankingSortField = AnimeRatingField.overall;
  bool _rankingDescending = true;

  // For quarter scope
  late int _selectedYear;
  late int _selectedQuarter;

  // For ranking quarter filter
  late int _rankingSelectedYear;
  late int _rankingSelectedQuarter;

  // For year scope
  late int _selectedYearOnly;

  // For ranking year filter
  late int _rankingSelectedYearOnly;

  late int _rankingStartYear;
  late int _rankingStartQuarter;
  late int _rankingEndYear;
  late int _rankingEndQuarter;

  final ScrollController _trendScrollController = ScrollController();

  /// Purpose: Initialize listeners, controllers, and first-load work for this state object.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Initializes owned state, listeners, or async work.
  /// Notes: Flutter lifecycle override.
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedQuarter = ((now.month - 1) ~/ 3) + 1;
    _rankingSelectedYear = now.year;
    _rankingSelectedQuarter = ((now.month - 1) ~/ 3) + 1;
    _selectedYearOnly = now.year;
    _rankingSelectedYearOnly = now.year;
    _rankingStartYear = now.year;
    _rankingStartQuarter = ((now.month - 1) ~/ 3) + 1;
    _rankingEndYear = now.year;
    _rankingEndQuarter = ((now.month - 1) ~/ 3) + 1;
    _load();
  }

  /// Purpose: Release listeners, controllers, and other owned resources.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Disposes controllers, listeners, and other owned resources.
  /// Notes: Flutter lifecycle override.
  @override
  void dispose() {
    _trendScrollController.dispose();
    super.dispose();
  }

  /// Purpose: Provide the internal load helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  Future<void> _load() async {
    final data = await AnimeStorage.load();
    if (mounted) {
      setState(() => _allAnime = data.animeList);
      _scrollTrendToEnd();
    }
  }

  /// Purpose: Scroll the trend chart to its final entry after layout completes.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Moves the trend chart scroll controller when attached.
  /// Notes: Internal helper used within this file only.
  void _scrollTrendToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_trendScrollController.hasClients) {
        _trendScrollController.jumpTo(
          _trendScrollController.position.maxScrollExtent,
        );
      }
    });
  }

  /// Purpose: Scroll the trend chart to the currently selected summary period.
  /// Inputs: `fallbackToEnd`.
  /// Returns: None.
  /// Side effects: Moves the trend chart scroll controller when attached.
  /// Notes: Falls back to the chart end when no focus entry is available and requested.
  void _scrollTrendToFocused({bool fallbackToEnd = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_trendScrollController.hasClients) return;

      final position = _trendScrollController.position;
      final data = _trendData;
      final focusedIndex = _focusedTrendIndex(data);
      final double target;
      if (focusedIndex == null) {
        if (!fallbackToEnd) return;
        target = position.maxScrollExtent;
      } else {
        const entryWidth = 50.0;
        target =
            focusedIndex * entryWidth +
            entryWidth / 2 -
            position.viewportDimension / 2;
      }

      _trendScrollController.jumpTo(
        target
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble(),
      );
    });
  }

  // --- Filtering ---

  /// Purpose: Provide the internal filtered anime helper for this file.
  /// Inputs: None.
  /// Returns: `List<Anime>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  List<Anime> get _filteredAnime {
    switch (_scope) {
      case _TimeScope.quarter:
        return _allAnime
            .where((a) => a.airsInQuarter(_selectedYear, _selectedQuarter))
            .toList();
      case _TimeScope.year:
        return _allAnime.where((a) {
          for (int q = 1; q <= 4; q++) {
            if (a.airsInQuarter(_selectedYearOnly, q)) return true;
          }
          return false;
        }).toList();
      case _TimeScope.all:
        return _allAnime;
    }
  }

  /// Purpose: Provide the internal ranking anime helper for this file.
  /// Inputs: None.
  /// Returns: `List<Anime>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  List<Anime> get _rankingAnime {
    final filtered = _allAnime.where((anime) {
      if (!_matchesRankingTimeFilter(anime)) return false;
      if (_rankingTypeFilter != null &&
          anime.effectiveType != _rankingTypeFilter) {
        return false;
      }
      return anime.rating?.scoreFor(_rankingSortField) != null;
    }).toList();

    filtered.sort((a, b) {
      final aScore = a.rating!.scoreFor(_rankingSortField)!;
      final bScore = b.rating!.scoreFor(_rankingSortField)!;
      final scoreCompare = _rankingDescending
          ? bScore.compareTo(aScore)
          : aScore.compareTo(bScore);
      if (scoreCompare != 0) return scoreCompare;
      return a.displayTitle.compareTo(b.displayTitle);
    });
    return filtered;
  }

  /// Purpose: Provide the internal ranking share entries helper for this file.
  /// Inputs: `rankedAnime`.
  /// Returns: `List<RankingShareEntry>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  List<RankingShareEntry> _rankingShareEntries(List<Anime> rankedAnime) {
    return List.generate(rankedAnime.length, (index) {
      final anime = rankedAnime[index];
      return RankingShareEntry(
        anime: anime,
        rank: index + 1,
        score: anime.rating!.scoreFor(_rankingSortField)!,
      );
    });
  }

  /// Purpose: Provide the internal share ranking helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Shows optional limit/progress dialogs, generates an image,
  /// and invokes the platform share flow.
  /// Notes: Internal helper used within this file only. Keeps the current
  /// ranking sort/filter order; if limited, shares the first N rows.
  Future<void> _shareRanking() async {
    final l10n = AppLocalizations.of(context)!;
    final rankedAnime = _rankingAnime;
    if (rankedAnime.isEmpty) return;

    var entries = _rankingShareEntries(rankedAnime);
    final totalCount = entries.length;
    if (entries.length > 50) {
      final limit = await _showRankingShareLimitDialog(l10n, entries.length);
      if (limit == null || !mounted) return;
      if (limit.limitEnabled) {
        final limitCount = limit.limit.clamp(1, entries.length).toInt();
        entries = entries.take(limitCount).toList();
      }
    }

    final subtitle = _shareSubtitleWithTruncation(
      _rankingShareSubtitle(l10n),
      entries.length,
      totalCount,
      l10n,
    );
    final pages = await _generateImageWithProgress(
      l10n: l10n,
      coverCount: _shareCoverCount(entries.map((e) => e.anime)),
      generate: (progress) => ShareService.generateRankingShareBytes(
        entries: entries,
        title: l10n.statsRanking,
        subtitle: subtitle,
        sortLabel: _ratingFieldLabel(_rankingSortField, l10n),
        orderLabel: _rankingDescending
            ? l10n.statsRankingDescending
            : l10n.statsRankingAscending,
        l10n: l10n,
        progress: progress,
      ),
    );
    if (pages == null || !mounted) return;
    await ShareService.shareImageBytesMulti(
      context,
      pages,
      l10n,
      fileNameBase: 'myanime_ranking',
    );
  }

  /// Purpose: Provide the internal summary share subtitle helper for this file.
  /// Inputs: `l10n`, `count`, `totalCount`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Appends a truncation
  /// note when the rendered count is smaller than the source count.
  String _summaryShareSubtitle(
    AppLocalizations l10n,
    int count, {
    int? totalCount,
  }) {
    final scope = switch (_scope) {
      _TimeScope.quarter => _quarterLabel(_selectedYear, _selectedQuarter),
      _TimeScope.year => '$_selectedYearOnly',
      _TimeScope.all => l10n.statsAll,
    };
    return _shareSubtitleWithTruncation(
      l10n.statsShareSummary(scope, count),
      count,
      totalCount ?? count,
      l10n,
    );
  }

  /// Purpose: Provide the internal summary share entries helper for this file.
  /// Inputs: `grouped`, `l10n`.
  /// Returns: `List<StatisticsShareEntry>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Builds entries in the
  /// same display order as the UI grouped lists: completed, watching, dropped,
  /// not-started.
  List<StatisticsShareEntry> _summaryShareEntries(
    Map<AnimeViewingStatus, List<Anime>> grouped,
    AppLocalizations l10n,
  ) {
    final order = [
      (AnimeViewingStatus.completed, l10n.statsCompleted),
      (AnimeViewingStatus.watching, l10n.statsWatching),
      (AnimeViewingStatus.dropped, l10n.statsDropped),
      (AnimeViewingStatus.notStarted, l10n.statsNotStarted),
    ];
    final entries = <StatisticsShareEntry>[];
    var rank = 1;
    for (final (status, label) in order) {
      for (final anime in grouped[status]!) {
        final watchedCount = anime.episodeStatuses.values
            .where((s) => s == EpisodeStatus.watched)
            .length;
        final totalEps =
            (anime.endEpisode ?? anime.startEpisode) - anime.startEpisode + 1;
        entries.add(
          StatisticsShareEntry(
            anime: anime,
            rank: rank++,
            statusLabel: label,
            progressLabel: '$watchedCount/$totalEps',
            score: anime.rating?.effectiveOverall,
          ),
        );
      }
    }
    return entries;
  }

  /// Purpose: Append a truncation label to an image subtitle when needed.
  /// Inputs: `base`, `shown`, `total`, `l10n`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String _shareSubtitleWithTruncation(
    String base,
    int shown,
    int total,
    AppLocalizations l10n,
  ) {
    if (shown >= total) return base;
    return '$base · ${l10n.statsShareTruncated(shown, total)}';
  }

  /// Purpose: Count unique cover images that may be loaded for a share image.
  /// Inputs: `animes`.
  /// Returns: Unique non-empty cover image count.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  int _shareCoverCount(Iterable<Anime> animes) {
    final covers = <String>{};
    for (final anime in animes) {
      final cover = anime.coverImage;
      if (cover != null && cover.isNotEmpty) covers.add(cover);
    }
    return covers.length;
  }

  /// Purpose: Reassign 1-based ranks after sorting or limiting share entries.
  /// Inputs: `entries`.
  /// Returns: New `StatisticsShareEntry` list with sequential ranks.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  List<StatisticsShareEntry> _renumberStatisticsEntries(
    List<StatisticsShareEntry> entries,
  ) {
    return List.generate(entries.length, (index) {
      final entry = entries[index];
      return StatisticsShareEntry(
        anime: entry.anime,
        rank: index + 1,
        statusLabel: entry.statusLabel,
        progressLabel: entry.progressLabel,
        score: entry.score,
      );
    });
  }

  /// Purpose: Sort summary share entries by first air date for limit priority.
  /// Inputs: `entries`, `priority`.
  /// Returns: Sorted `StatisticsShareEntry` list.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Entries without
  /// `firstAirDate` always sort last.
  List<StatisticsShareEntry> _sortSummaryShareEntries(
    List<StatisticsShareEntry> entries,
    _SummarySharePriority priority,
  ) {
    final sorted = [...entries];
    sorted.sort((a, b) {
      final aDate = a.anime.firstAirDate;
      final bDate = b.anime.firstAirDate;
      if (aDate == null && bDate == null) {
        return a.anime.displayTitle.compareTo(b.anime.displayTitle);
      }
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      final compare = aDate.compareTo(bDate);
      if (compare != 0) {
        return priority == _SummarySharePriority.recent ? -compare : compare;
      }
      return a.anime.displayTitle.compareTo(b.anime.displayTitle);
    });
    return sorted;
  }

  /// Purpose: Build a summary count from the entries that will be rendered.
  /// Inputs: `entries`.
  /// Returns: `StatisticsShareSummary` reflecting the final image rows.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  StatisticsShareSummary _summaryFromEntries(
    List<StatisticsShareEntry> entries,
  ) {
    var completed = 0;
    var dropped = 0;
    for (final entry in entries) {
      switch (entry.anime.viewingStatus) {
        case AnimeViewingStatus.completed:
          completed++;
        case AnimeViewingStatus.dropped:
          dropped++;
        case AnimeViewingStatus.watching:
        case AnimeViewingStatus.notStarted:
          break;
      }
    }
    return StatisticsShareSummary(
      tracked: entries.length,
      completed: completed,
      dropped: dropped,
    );
  }

  /// Purpose: Generate image pages while showing a blocking progress dialog.
  /// Inputs: `l10n`, `coverCount`, `generate`.
  /// Returns: A list of PNG page byte lists, or null when generation fails.
  /// Side effects: Shows/dismisses a dialog and may show a failure snackbar.
  /// Notes: Internal helper used within this file only. The platform share UI is
  /// shown after this dialog closes, so desktop preview is not covered.
  Future<List<Uint8List>?> _generateImageWithProgress({
    required AppLocalizations l10n,
    required int coverCount,
    required Future<List<Uint8List>> Function(ValueNotifier<double> progress)
    generate,
  }) async {
    final progress = ValueNotifier<double>(0);
    final dialogFuture = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(l10n.statsShareLimitTitle),
          content: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (ctx, value, child) {
              final normalized = value.clamp(0.0, 1.0).toDouble();
              final done = coverCount == 0
                  ? 0
                  : (normalized * coverCount)
                        .ceil()
                        .clamp(0, coverCount)
                        .toInt();
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.statsShareGenerating),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: coverCount == 0 ? null : normalized,
                  ),
                  if (coverCount > 0) ...[
                    const SizedBox(height: 8),
                    Text(l10n.statsShareGeneratingProgress(done, coverCount)),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    List<Uint8List>? pages;
    Object? error;
    try {
      pages = await generate(progress);
    } catch (e) {
      error = e;
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        await dialogFuture;
      }
      progress.dispose();
    }

    if (error != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.shareFailed)));
    }
    return pages;
  }

  /// Purpose: Ask which viewing statuses to include in the summary image.
  /// Inputs: `l10n`.
  /// Returns: Selected status set, or null when canceled.
  /// Side effects: Shows a dialog.
  /// Notes: Internal helper used within this file only. Defaults to all statuses.
  Future<Set<AnimeViewingStatus>?> _showSummaryStatusSelectionDialog(
    AppLocalizations l10n,
  ) async {
    final selected = <AnimeViewingStatus>{
      AnimeViewingStatus.completed,
      AnimeViewingStatus.watching,
      AnimeViewingStatus.dropped,
      AnimeViewingStatus.notStarted,
    };
    final options = [
      (AnimeViewingStatus.completed, l10n.statsCompleted),
      (AnimeViewingStatus.watching, l10n.statsWatching),
      (AnimeViewingStatus.dropped, l10n.statsDropped),
      (AnimeViewingStatus.notStarted, l10n.statsNotStarted),
    ];
    return showDialog<Set<AnimeViewingStatus>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.statsShareStatusTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.statsShareStatusHint),
              const SizedBox(height: 8),
              for (final (status, label) in options)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(label),
                  value: selected.contains(status),
                  onChanged: (value) {
                    setDialogState(() {
                      if (value ?? false) {
                        selected.add(status);
                      } else {
                        selected.remove(status);
                      }
                    });
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(ctx, Set.of(selected)),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  /// Purpose: Ask for summary-image limit and first-air-date priority.
  /// Inputs: `l10n`, `totalCount`.
  /// Returns: Limit settings, or null when canceled.
  /// Side effects: Shows a dialog.
  /// Notes: Internal helper used within this file only. Default is no limit and
  /// recent-first priority.
  Future<({bool limitEnabled, int limit, _SummarySharePriority priority})?>
  _showSummaryShareLimitDialog(AppLocalizations l10n, int totalCount) async {
    var limitEnabled = false;
    var priority = _SummarySharePriority.recent;
    final controller = TextEditingController(text: '50');
    try {
      return await showDialog<
        ({bool limitEnabled, int limit, _SummarySharePriority priority})
      >(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(l10n.statsShareLimitTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.statsShareLimitWarning(totalCount)),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.statsShareLimitEnable),
                    value: limitEnabled,
                    onChanged: (value) =>
                        setDialogState(() => limitEnabled = value),
                  ),
                  TextField(
                    controller: controller,
                    enabled: limitEnabled,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.statsShareLimitCount,
                      helperText: '1-$totalCount',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<_SummarySharePriority>(
                    initialValue: priority,
                    decoration: InputDecoration(
                      labelText: l10n.statsShareLimitPriority,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: _SummarySharePriority.recent,
                        child: Text(l10n.statsSharePriorityRecent),
                      ),
                      DropdownMenuItem(
                        value: _SummarySharePriority.oldest,
                        child: Text(l10n.statsSharePriorityOldest),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => priority = value);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () {
                  final limit = int.tryParse(controller.text.trim()) ?? 50;
                  Navigator.pop(ctx, (
                    limitEnabled: limitEnabled,
                    limit: limit.clamp(1, totalCount).toInt(),
                    priority: priority,
                  ));
                },
                child: Text(l10n.save),
              ),
            ],
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  /// Purpose: Ask for ranking-image limit without changing ranking order.
  /// Inputs: `l10n`, `totalCount`.
  /// Returns: Limit settings, or null when canceled.
  /// Side effects: Shows a dialog.
  /// Notes: Internal helper used within this file only. Default is no limit;
  /// when enabled, the current first N ranked rows are shared.
  Future<({bool limitEnabled, int limit})?> _showRankingShareLimitDialog(
    AppLocalizations l10n,
    int totalCount,
  ) async {
    var limitEnabled = false;
    final controller = TextEditingController(text: '50');
    try {
      return await showDialog<({bool limitEnabled, int limit})>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(l10n.statsShareLimitTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.statsShareLimitWarning(totalCount)),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.statsShareLimitEnable),
                    value: limitEnabled,
                    onChanged: (value) =>
                        setDialogState(() => limitEnabled = value),
                  ),
                  TextField(
                    controller: controller,
                    enabled: limitEnabled,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.statsShareLimitCount,
                      helperText: '1-$totalCount',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () {
                  final limit = int.tryParse(controller.text.trim()) ?? 50;
                  Navigator.pop(ctx, (
                    limitEnabled: limitEnabled,
                    limit: limit.clamp(1, totalCount).toInt(),
                  ));
                },
                child: Text(l10n.save),
              ),
            ],
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  /// Purpose: Provide the internal share statistics helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Shows dialogs, generates images, shares files.
  /// Notes: Internal helper used within this file only. Asks the user whether
  /// to share as an image or a data file, then generates the appropriate
  /// output for the current statistics view (summary or ranking).
  Future<void> _shareStatistics() async {
    final l10n = AppLocalizations.of(context)!;
    final isRanking = _view == _StatsView.ranking;

    final shareType = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.shareTypeTitle),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'image'),
            child: ListTile(
              leading: const Icon(Icons.image),
              title: Text(l10n.shareAsImage),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'data'),
            child: ListTile(
              leading: const Icon(Icons.file_present),
              title: Text(l10n.shareAsData),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'txt'),
            child: ListTile(
              leading: const Icon(Icons.text_snippet),
              title: Text(l10n.shareAsTxt),
            ),
          ),
        ],
      ),
    );
    if (shareType == null || !mounted) return;

    final animes = isRanking ? _rankingAnime : _filteredAnime;
    final displayName = isRanking
        ? 'myanime_ranking'
        : switch (_scope) {
            _TimeScope.quarter =>
              'myanime_${_selectedYear}_Q$_selectedQuarter',
            _TimeScope.year => 'myanime_$_selectedYearOnly',
            _TimeScope.all => 'myanime_all',
          };

    if (shareType == 'txt') {
      await ShareService.shareStatisticsTxt(
        context,
        animes: animes,
        displayName: displayName,
        l10n: l10n,
      );
      return;
    }

    if (shareType == 'data') {
      if (animes.isEmpty) return;
      await ShareService.shareStatisticsData(
        context,
        animes: animes,
        displayName: displayName,
        l10n: l10n,
      );
      return;
    }

    // Image share.
    if (isRanking) {
      await _shareRanking();
    } else {
      final selectedStatuses = await _showSummaryStatusSelectionDialog(l10n);
      if (selectedStatuses == null || !mounted) return;
      final grouped = _groupedAnime;
      final selectedGrouped = <AnimeViewingStatus, List<Anime>>{
        AnimeViewingStatus.completed:
            selectedStatuses.contains(AnimeViewingStatus.completed)
            ? grouped[AnimeViewingStatus.completed]!
            : <Anime>[],
        AnimeViewingStatus.watching:
            selectedStatuses.contains(AnimeViewingStatus.watching)
            ? grouped[AnimeViewingStatus.watching]!
            : <Anime>[],
        AnimeViewingStatus.dropped:
            selectedStatuses.contains(AnimeViewingStatus.dropped)
            ? grouped[AnimeViewingStatus.dropped]!
            : <Anime>[],
        AnimeViewingStatus.notStarted:
            selectedStatuses.contains(AnimeViewingStatus.notStarted)
            ? grouped[AnimeViewingStatus.notStarted]!
            : <Anime>[],
      };
      var entries = _summaryShareEntries(selectedGrouped, l10n);
      if (entries.isEmpty) return;
      final totalCount = entries.length;
      if (entries.length > 50) {
        final limit = await _showSummaryShareLimitDialog(l10n, entries.length);
        if (limit == null || !mounted) return;
        entries = _sortSummaryShareEntries(entries, limit.priority);
        if (limit.limitEnabled) {
          final limitCount = limit.limit.clamp(1, entries.length).toInt();
          entries = entries.take(limitCount).toList();
        }
        entries = _renumberStatisticsEntries(entries);
      }
      final summary = _summaryFromEntries(entries);
      final subtitle = _summaryShareSubtitle(
        l10n,
        entries.length,
        totalCount: totalCount,
      );
      final pages = await _generateImageWithProgress(
        l10n: l10n,
        coverCount: _shareCoverCount(entries.map((e) => e.anime)),
        generate: (progress) => ShareService.generateStatisticsShareBytes(
          entries: entries,
          title: l10n.statsTitle,
          subtitle: subtitle,
          l10n: l10n,
          summary: summary,
          progress: progress,
        ),
      );
      if (pages == null || !mounted) return;
      await ShareService.shareImageBytesMulti(
        context,
        pages,
        l10n,
        fileNameBase: 'myanime_stats',
      );
    }
  }

  /// Purpose: Provide the internal matches ranking time filter helper for this file.
  /// Inputs: `anime`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  bool _matchesRankingTimeFilter(Anime anime) {
    switch (_rankingTimeFilter) {
      case _RankingTimeFilter.all:
        return true;
      case _RankingTimeFilter.quarter:
        return anime.airsInQuarter(
          _rankingSelectedYear,
          _rankingSelectedQuarter,
        );
      case _RankingTimeFilter.year:
        for (int q = 1; q <= 4; q++) {
          if (anime.airsInQuarter(_rankingSelectedYearOnly, q)) return true;
        }
        return false;
      case _RankingTimeFilter.custom:
        var startIdx = _quarterIndex(_rankingStartYear, _rankingStartQuarter);
        var endIdx = _quarterIndex(_rankingEndYear, _rankingEndQuarter);
        if (endIdx < startIdx) {
          final tmp = startIdx;
          startIdx = endIdx;
          endIdx = tmp;
        }
        for (var idx = startIdx; idx <= endIdx; idx++) {
          final (year, quarter) = _quarterFromIndex(idx);
          if (anime.airsInQuarter(year, quarter)) return true;
        }
        return false;
    }
  }

  /// Purpose: Provide the internal grouped anime helper for this file.
  /// Inputs: None.
  /// Returns: `Map<AnimeViewingStatus, List<Anime>>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Map<AnimeViewingStatus, List<Anime>> get _groupedAnime {
    final map = <AnimeViewingStatus, List<Anime>>{
      AnimeViewingStatus.watching: [],
      AnimeViewingStatus.completed: [],
      AnimeViewingStatus.dropped: [],
      AnimeViewingStatus.notStarted: [],
    };
    for (final anime in _filteredAnime) {
      map[anime.viewingStatus]!.add(anime);
    }
    return map;
  }

  // --- Navigation helpers ---

  /// Purpose: Provide the internal prev period helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  void _prevPeriod() {
    var shouldScrollSummaryTrend = false;
    setState(() {
      if (_view == _StatsView.ranking &&
          _rankingTimeFilter == _RankingTimeFilter.quarter) {
        _rankingSelectedQuarter--;
        if (_rankingSelectedQuarter < 1) {
          _rankingSelectedQuarter = 4;
          _rankingSelectedYear--;
        }
      } else if (_view == _StatsView.ranking &&
          _rankingTimeFilter == _RankingTimeFilter.year) {
        _rankingSelectedYearOnly--;
      } else if (_scope == _TimeScope.quarter) {
        _selectedQuarter--;
        if (_selectedQuarter < 1) {
          _selectedQuarter = 4;
          _selectedYear--;
        }
        shouldScrollSummaryTrend = true;
      } else if (_scope == _TimeScope.year) {
        _selectedYearOnly--;
        shouldScrollSummaryTrend = true;
      }
    });
    if (shouldScrollSummaryTrend) _scrollTrendToFocused();
  }

  /// Purpose: Provide the internal next period helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  void _nextPeriod() {
    var shouldScrollSummaryTrend = false;
    setState(() {
      if (_view == _StatsView.ranking &&
          _rankingTimeFilter == _RankingTimeFilter.quarter) {
        _rankingSelectedQuarter++;
        if (_rankingSelectedQuarter > 4) {
          _rankingSelectedQuarter = 1;
          _rankingSelectedYear++;
        }
      } else if (_view == _StatsView.ranking &&
          _rankingTimeFilter == _RankingTimeFilter.year) {
        _rankingSelectedYearOnly++;
      } else if (_scope == _TimeScope.quarter) {
        _selectedQuarter++;
        if (_selectedQuarter > 4) {
          _selectedQuarter = 1;
          _selectedYear++;
        }
        shouldScrollSummaryTrend = true;
      } else if (_scope == _TimeScope.year) {
        _selectedYearOnly++;
        shouldScrollSummaryTrend = true;
      }
    });
    if (shouldScrollSummaryTrend) _scrollTrendToFocused();
  }

  /// Purpose: Build the selectable year range for summary and ranking pickers.
  /// Inputs: None.
  /// Returns: `(int, int)`.
  /// Side effects: None.
  /// Notes: Includes anime data years, current context, and current/future year defaults.
  (int, int) get _availableYearRange {
    final dataYears = <int>{};
    for (final anime in _allAnime) {
      final sq = anime.startQuarter;
      if (sq != null) dataYears.add(sq.$1);
    }
    final now = DateTime.now();
    dataYears.addAll([
      now.year,
      now.year + 1,
      _selectedYear,
      _selectedYearOnly,
      _rankingSelectedYear,
      _rankingSelectedYearOnly,
      _rankingStartYear,
      _rankingEndYear,
    ]);
    return (
      dataYears.reduce((a, b) => a < b ? a : b),
      dataYears.reduce((a, b) => a > b ? a : b),
    );
  }

  /// Purpose: Let the user directly choose the summary quarter.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Shows a dialog and mutates selected summary quarter state.
  /// Notes: Internal helper used within this file only.
  Future<void> _pickSummaryQuarter() async {
    final range = _availableYearRange;
    final selected = await showQuarterPickerDialog(
      context: context,
      title: AppLocalizations.of(context)!.manageJumpToQuarter,
      minYear: range.$1,
      maxYear: range.$2,
      current: QuarterSelection(_selectedYear, _selectedQuarter),
      countBuilder: _countAnimeInQuarter,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedYear = selected.year;
      _selectedQuarter = selected.quarter;
    });
    _scrollTrendToFocused();
  }

  /// Purpose: Let the user directly choose the summary year.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Shows a dialog and mutates selected summary year state.
  /// Notes: Internal helper used within this file only.
  Future<void> _pickSummaryYear() async {
    final l10n = AppLocalizations.of(context)!;
    final range = _availableYearRange;
    final selected = await _showYearPickerDialog(
      title: l10n.statsRankingSelectYear,
      minYear: range.$1,
      maxYear: range.$2,
      currentYear: _selectedYearOnly,
    );
    if (selected == null || !mounted) return;
    setState(() => _selectedYearOnly = selected);
    _scrollTrendToFocused();
  }

  /// Purpose: Provide the internal pick ranking quarter helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Shows a dialog and mutates selected ranking quarter state.
  /// Notes: Internal helper used within this file only.
  Future<void> _pickRankingQuarter() async {
    final range = _availableYearRange;
    final selected = await showQuarterPickerDialog(
      context: context,
      title: AppLocalizations.of(context)!.manageJumpToQuarter,
      minYear: range.$1,
      maxYear: range.$2,
      current: QuarterSelection(_rankingSelectedYear, _rankingSelectedQuarter),
      countBuilder: _countAnimeInQuarter,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _rankingSelectedYear = selected.year;
      _rankingSelectedQuarter = selected.quarter;
    });
  }

  /// Purpose: Provide the internal pick ranking year helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Shows a dialog and mutates selected ranking year state.
  /// Notes: Internal helper used within this file only.
  Future<void> _pickRankingYear() async {
    final l10n = AppLocalizations.of(context)!;
    final range = _availableYearRange;
    final selected = await _showYearPickerDialog(
      title: l10n.statsRankingSelectYear,
      minYear: range.$1,
      maxYear: range.$2,
      currentYear: _rankingSelectedYearOnly,
    );
    if (selected == null || !mounted) return;
    setState(() => _rankingSelectedYearOnly = selected);
  }

  /// Purpose: Provide the internal pick ranking range start helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  Future<void> _pickRankingRangeStart() async {
    final range = _availableYearRange;
    final selected = await showQuarterPickerDialog(
      context: context,
      title: AppLocalizations.of(context)!.statsRankingStartQuarter,
      minYear: range.$1,
      maxYear: range.$2,
      current: QuarterSelection(_rankingStartYear, _rankingStartQuarter),
      countBuilder: _countAnimeInQuarter,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _rankingStartYear = selected.year;
      _rankingStartQuarter = selected.quarter;
      _normalizeRankingCustomRange();
    });
  }

  /// Purpose: Provide the internal pick ranking range end helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Future<void> _pickRankingRangeEnd() async {
    final range = _availableYearRange;
    final selected = await showQuarterPickerDialog(
      context: context,
      title: AppLocalizations.of(context)!.statsRankingEndQuarter,
      minYear: range.$1,
      maxYear: range.$2,
      current: QuarterSelection(_rankingEndYear, _rankingEndQuarter),
      countBuilder: _countAnimeInQuarter,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _rankingEndYear = selected.year;
      _rankingEndQuarter = selected.quarter;
      _normalizeRankingCustomRange();
    });
  }

  /// Purpose: Provide the internal show year picker dialog helper for this file.
  /// Inputs: `title`, `minYear`, `maxYear`, `currentYear`.
  /// Returns: `Future<int?>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Future<int?> _showYearPickerDialog({
    required String title,
    required int minYear,
    required int maxYear,
    required int currentYear,
  }) async {
    const itemHeight = 48.0;
    final initialOffset = ((currentYear - minYear - 3) * itemHeight).clamp(
      0.0,
      double.infinity,
    );
    final scrollCtrl = ScrollController(initialScrollOffset: initialOffset);
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: Text(title),
          contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
          content: SizedBox(
            width: 260,
            height: 320,
            child: ListView.builder(
              controller: scrollCtrl,
              itemCount: maxYear - minYear + 1,
              itemExtent: itemHeight,
              itemBuilder: (context, index) {
                final year = minYear + index;
                final isCurrent = year == currentYear;
                final count = _countAnimeInYear(year);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Material(
                    color: isCurrent
                        ? theme.colorScheme.primary
                        : count > 0
                        ? theme.colorScheme.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => Navigator.pop(dialogContext, year),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(
                              '$year',
                              style: TextStyle(
                                color: isCurrent
                                    ? theme.colorScheme.onPrimary
                                    : null,
                                fontWeight: isCurrent ? FontWeight.bold : null,
                              ),
                            ),
                            const Spacer(),
                            if (count > 0)
                              Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isCurrent
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                MaterialLocalizations.of(dialogContext).cancelButtonLabel,
              ),
            ),
          ],
        );
      },
    );
    scrollCtrl.dispose();
    return result;
  }

  /// Purpose: Provide the internal count anime in quarter helper for this file.
  /// Inputs: `year`, `quarter`.
  /// Returns: `int`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  int _countAnimeInQuarter(int year, int quarter) {
    return _allAnime.where((a) => a.airsInQuarter(year, quarter)).length;
  }

  /// Purpose: Provide the internal count anime in year helper for this file.
  /// Inputs: `year`.
  /// Returns: `int`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  int _countAnimeInYear(int year) {
    return _allAnime.where((anime) {
      for (int q = 1; q <= 4; q++) {
        if (anime.airsInQuarter(year, q)) return true;
      }
      return false;
    }).length;
  }

  /// Purpose: Provide the internal normalize ranking custom range helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  void _normalizeRankingCustomRange() {
    final startIdx = _quarterIndex(_rankingStartYear, _rankingStartQuarter);
    final endIdx = _quarterIndex(_rankingEndYear, _rankingEndQuarter);
    if (endIdx >= startIdx) return;

    final startYear = _rankingStartYear;
    final startQuarter = _rankingStartQuarter;
    _rankingStartYear = _rankingEndYear;
    _rankingStartQuarter = _rankingEndQuarter;
    _rankingEndYear = startYear;
    _rankingEndQuarter = startQuarter;
  }

  /// Purpose: Provide the internal quarter index helper for this file.
  /// Inputs: `year`, `quarter`.
  /// Returns: `int`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static int _quarterIndex(int year, int quarter) => year * 4 + quarter;

  /// Purpose: Convert a compact quarter index back into year and quarter values.
  /// Inputs: `index`.
  /// Returns: `(int, int)`.
  /// Side effects: None.
  /// Notes: Quarter indexes use the same year * 4 + quarter convention as `_quarterIndex`.
  static (int, int) _quarterFromIndex(int index) {
    final year = (index - 1) ~/ 4;
    final quarter = ((index - 1) % 4) + 1;
    return (year, quarter);
  }

  // --- Trend data ---

  /// Purpose: Build the trend chart data for the active summary scope.
  /// Inputs: None.
  /// Returns: `List<_TrendEntry>`.
  /// Side effects: None.
  /// Notes: Quarter/year scopes keep full timelines; All can switch quarter/year granularity.
  List<_TrendEntry> get _trendData {
    switch (_scope) {
      case _TimeScope.quarter:
        return _quarterTrendData(includeFocused: true);
      case _TimeScope.year:
        return _yearTrendData(includeFocused: true);
      case _TimeScope.all:
        return switch (_allTrendGranularity) {
          _TrendGranularity.quarter => _quarterTrendData(includeFocused: false),
          _TrendGranularity.year => _yearTrendData(includeFocused: false),
        };
    }
  }

  /// Purpose: Build quarter-level trend entries across the full known timeline.
  /// Inputs: `includeFocused`.
  /// Returns: `List<_TrendEntry>`.
  /// Side effects: None.
  /// Notes: Includes the selected quarter when a quarter scope needs focus.
  List<_TrendEntry> _quarterTrendData({required bool includeFocused}) {
    final now = DateTime.now();
    final currentQuarter = ((now.month - 1) ~/ 3) + 1;
    var startIndex = _quarterIndex(now.year, currentQuarter);
    var endIndex = startIndex;
    var hasData = false;

    for (final anime in _allAnime) {
      final startQuarter = anime.startQuarter;
      if (startQuarter == null) continue;
      final index = _quarterIndex(startQuarter.$1, startQuarter.$2);
      startIndex = index < startIndex ? index : startIndex;
      endIndex = index > endIndex ? index : endIndex;
      hasData = true;
    }

    if (includeFocused) {
      final focusedIndex = _quarterIndex(_selectedYear, _selectedQuarter);
      startIndex = focusedIndex < startIndex ? focusedIndex : startIndex;
      endIndex = focusedIndex > endIndex ? focusedIndex : endIndex;
    } else if (!hasData) {
      return [];
    }

    return [
      for (var index = startIndex; index <= endIndex; index++)
        _quarterTrendEntry(_quarterFromIndex(index)),
    ];
  }

  /// Purpose: Build year-level trend entries across the full known timeline.
  /// Inputs: `includeFocused`.
  /// Returns: `List<_TrendEntry>`.
  /// Side effects: None.
  /// Notes: Includes the selected year when a year scope needs focus.
  List<_TrendEntry> _yearTrendData({required bool includeFocused}) {
    final now = DateTime.now();
    var startYear = now.year;
    var endYear = now.year;
    var hasData = false;

    for (final anime in _allAnime) {
      final startQuarter = anime.startQuarter;
      if (startQuarter == null) continue;
      startYear = startQuarter.$1 < startYear ? startQuarter.$1 : startYear;
      endYear = startQuarter.$1 > endYear ? startQuarter.$1 : endYear;
      hasData = true;
    }

    if (includeFocused) {
      startYear = _selectedYearOnly < startYear ? _selectedYearOnly : startYear;
      endYear = _selectedYearOnly > endYear ? _selectedYearOnly : endYear;
    } else if (!hasData) {
      return [];
    }

    return [
      for (var year = startYear; year <= endYear; year++) _yearTrendEntry(year),
    ];
  }

  /// Purpose: Build one quarter-level trend entry.
  /// Inputs: `yearQuarter`.
  /// Returns: `_TrendEntry`.
  /// Side effects: None.
  /// Notes: Counts anime that air in the quarter, including multi-cour spans.
  _TrendEntry _quarterTrendEntry((int, int) yearQuarter) {
    final animeInQuarter = _allAnime
        .where((a) => a.airsInQuarter(yearQuarter.$1, yearQuarter.$2))
        .toList();
    return _TrendEntry(
      year: yearQuarter.$1,
      quarter: yearQuarter.$2,
      tracked: animeInQuarter.length,
      completed: animeInQuarter
          .where((a) => a.viewingStatus == AnimeViewingStatus.completed)
          .length,
      dropped: animeInQuarter
          .where((a) => a.viewingStatus == AnimeViewingStatus.dropped)
          .length,
    );
  }

  /// Purpose: Build one year-level trend entry.
  /// Inputs: `year`.
  /// Returns: `_TrendEntry`.
  /// Side effects: None.
  /// Notes: Counts anime once when they air in any quarter of the year.
  _TrendEntry _yearTrendEntry(int year) {
    final animeInYear = _allAnime.where((a) {
      for (var quarter = 1; quarter <= 4; quarter++) {
        if (a.airsInQuarter(year, quarter)) return true;
      }
      return false;
    }).toList();
    return _TrendEntry(
      year: year,
      quarter: 0,
      tracked: animeInYear.length,
      completed: animeInYear
          .where((a) => a.viewingStatus == AnimeViewingStatus.completed)
          .length,
      dropped: animeInYear
          .where((a) => a.viewingStatus == AnimeViewingStatus.dropped)
          .length,
    );
  }

  /// Purpose: Locate the trend entry matching the currently selected summary period.
  /// Inputs: `data`.
  /// Returns: `int?`.
  /// Side effects: None.
  /// Notes: All scope has no focused period and returns null.
  int? _focusedTrendIndex(List<_TrendEntry> data) {
    final index = switch (_scope) {
      _TimeScope.quarter => data.indexWhere(
        (e) => e.year == _selectedYear && e.quarter == _selectedQuarter,
      ),
      _TimeScope.year => data.indexWhere(
        (e) => e.year == _selectedYearOnly && e.quarter == 0,
      ),
      _TimeScope.all => -1,
    };
    return index < 0 ? null : index;
  }

  // --- Build ---

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final grouped = _groupedAnime;
    final isRanking = _view == _StatsView.ranking;
    final rankedAnime = isRanking ? _rankingAnime : const <Anime>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.statsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: l10n.statsShare,
            onPressed:
                (isRanking ? rankedAnime.isNotEmpty : _filteredAnime.isNotEmpty)
                ? _shareStatistics
                : null,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 80),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: SegmentedButton<_TimeScope>(
                      emptySelectionAllowed: isRanking,
                      segments: [
                        ButtonSegment(
                          value: _TimeScope.quarter,
                          label: Text(l10n.statsQuarter),
                        ),
                        ButtonSegment(
                          value: _TimeScope.year,
                          label: Text(l10n.statsYear),
                        ),
                        ButtonSegment(
                          value: _TimeScope.all,
                          label: Text(l10n.statsAll),
                        ),
                      ],
                      selected: isRanking ? <_TimeScope>{} : {_scope},
                      onSelectionChanged: (s) {
                        if (s.isEmpty) return;
                        setState(() {
                          _scope = s.first;
                          _view = _StatsView.summary;
                        });
                        if (_scope == _TimeScope.all) {
                          _scrollTrendToEnd();
                        } else {
                          _scrollTrendToFocused(fallbackToEnd: true);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: () => setState(() => _view = _StatsView.ranking),
                    icon: const Icon(Icons.leaderboard),
                    label: Text(l10n.statsRanking),
                    style: FilledButton.styleFrom(
                      backgroundColor: isRanking
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                      foregroundColor: isRanking
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            if (isRanking) ...[
              _buildRankingView(theme, l10n, rankedAnime),
            ] else ...[
              // Period navigation (quarter/year only)
              if (_scope != _TimeScope.all)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _prevPeriod,
                      ),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: _scope == _TimeScope.quarter
                              ? _pickSummaryQuarter
                              : _pickSummaryYear,
                          icon: const Icon(Icons.arrow_drop_down),
                          iconAlignment: IconAlignment.end,
                          label: Text(
                            _scope == _TimeScope.quarter
                                ? _quarterLabel(_selectedYear, _selectedQuarter)
                                : '$_selectedYearOnly',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _nextPeriod,
                      ),
                    ],
                  ),
                ),

              // Summary cards
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    _buildSummaryCard(
                      theme,
                      l10n.statsWatching,
                      grouped[AnimeViewingStatus.watching]!.length,
                      theme.colorScheme.primary,
                    ),
                    _buildSummaryCard(
                      theme,
                      l10n.statsCompleted,
                      grouped[AnimeViewingStatus.completed]!.length,
                      Colors.green,
                    ),
                    _buildSummaryCard(
                      theme,
                      l10n.statsDropped,
                      grouped[AnimeViewingStatus.dropped]!.length,
                      Colors.red,
                    ),
                    _buildSummaryCard(
                      theme,
                      l10n.statsNotStarted,
                      grouped[AnimeViewingStatus.notStarted]!.length,
                      theme.colorScheme.outline,
                    ),
                  ],
                ),
              ),

              // Trend chart
              _buildTrendChart(theme, l10n),

              const Divider(height: 32),

              // Anime lists by status
              ..._buildGroupedLists(grouped, theme, l10n),
            ],
          ],
        ),
      ),
    );
  }

  /// Purpose: Provide the internal build summary card helper for this file.
  /// Inputs: `theme`, `label`, `count`, `color`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _buildSummaryCard(
    ThemeData theme,
    String label,
    int count,
    Color color,
  ) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            children: [
              Text(
                '$count',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Purpose: Provide the internal build ranking view helper for this file.
  /// Inputs: `theme`, `l10n`, `rankedAnime`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _buildRankingView(
    ThemeData theme,
    AppLocalizations l10n,
    List<Anime> rankedAnime,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.statsRankingFilters, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          _buildRankingFilters(theme, l10n),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                l10n.statsRankingCount(rankedAnime.length),
                style: theme.textTheme.titleSmall,
              ),
              const Spacer(),
              Text(
                _rankingDescending
                    ? l10n.statsRankingDescending
                    : l10n.statsRankingAscending,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (rankedAnime.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text(l10n.statsRankingEmpty)),
            )
          else
            ...List.generate(
              rankedAnime.length,
              (index) =>
                  _buildRankingTile(rankedAnime[index], index + 1, theme, l10n),
            ),
        ],
      ),
    );
  }

  /// Purpose: Provide the internal build ranking filters helper for this file.
  /// Inputs: `theme`, `l10n`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _buildRankingFilters(ThemeData theme, AppLocalizations l10n) {
    return Column(
      children: [
        DropdownButtonFormField<_RankingTimeFilter>(
          initialValue: _rankingTimeFilter,
          decoration: InputDecoration(
            labelText: l10n.statsRankingTimeFilter,
            border: const OutlineInputBorder(),
          ),
          items: _RankingTimeFilter.values
              .map(
                (filter) => DropdownMenuItem(
                  value: filter,
                  child: Text(_rankingTimeFilterLabel(filter, l10n)),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _rankingTimeFilter = value);
            }
          },
        ),
        if (_rankingTimeFilter == _RankingTimeFilter.quarter ||
            _rankingTimeFilter == _RankingTimeFilter.year)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _prevPeriod,
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _rankingTimeFilter == _RankingTimeFilter.quarter
                        ? _pickRankingQuarter
                        : _pickRankingYear,
                    icon: const Icon(Icons.arrow_drop_down),
                    iconAlignment: IconAlignment.end,
                    label: Text(
                      _rankingTimeFilter == _RankingTimeFilter.quarter
                          ? _quarterLabel(
                              _rankingSelectedYear,
                              _rankingSelectedQuarter,
                            )
                          : '$_rankingSelectedYearOnly',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _nextPeriod,
                ),
              ],
            ),
          ),
        if (_rankingTimeFilter == _RankingTimeFilter.custom) ...[
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 560;
              final startButton = _buildRankingRangeButton(
                onPressed: _pickRankingRangeStart,
                icon: Icons.date_range,
                label: l10n.statsRankingStartQuarter,
                quarterLabel: _quarterLabel(
                  _rankingStartYear,
                  _rankingStartQuarter,
                ),
              );
              final endButton = _buildRankingRangeButton(
                onPressed: _pickRankingRangeEnd,
                icon: Icons.event,
                label: l10n.statsRankingEndQuarter,
                quarterLabel: _quarterLabel(
                  _rankingEndYear,
                  _rankingEndQuarter,
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [startButton, const SizedBox(height: 8), endButton],
                );
              }

              return Row(
                children: [
                  Expanded(child: startButton),
                  const SizedBox(width: 8),
                  Expanded(child: endButton),
                ],
              );
            },
          ),
        ],
        const SizedBox(height: 12),
        DropdownButtonFormField<AnimeType?>(
          initialValue: _rankingTypeFilter,
          decoration: InputDecoration(
            labelText: l10n.statsRankingTypeFilter,
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem<AnimeType?>(
              value: null,
              child: Text(l10n.statsRankingAllTypes),
            ),
            ...AnimeType.values.map(
              (type) => DropdownMenuItem<AnimeType?>(
                value: type,
                child: Text(_typeLabel(type, l10n)),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _rankingTypeFilter = value),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<AnimeRatingField>(
                initialValue: _rankingSortField,
                decoration: InputDecoration(
                  labelText: l10n.statsRankingSortBy,
                  border: const OutlineInputBorder(),
                ),
                items: AnimeRatingField.values
                    .map(
                      (field) => DropdownMenuItem(
                        value: field,
                        child: Text(_ratingFieldLabel(field, l10n)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _rankingSortField = value);
                },
              ),
            ),
            const SizedBox(width: 12),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.south),
                  label: Text(l10n.statsRankingDescShort),
                ),
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.north),
                  label: Text(l10n.statsRankingAscShort),
                ),
              ],
              selected: {_rankingDescending},
              onSelectionChanged: (value) {
                setState(() => _rankingDescending = value.first);
              },
            ),
          ],
        ),
      ],
    );
  }

  /// Purpose: Provide the internal build ranking range button helper for this file.
  /// Inputs: `onPressed`, `icon`, `label`, `quarterLabel`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _buildRankingRangeButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required String quarterLabel,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text('$label: $quarterLabel', overflow: TextOverflow.ellipsis),
    );
  }

  /// Purpose: Provide the internal build ranking tile helper for this file.
  /// Inputs: `anime`, `rank`, `theme`, `l10n`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _buildRankingTile(
    Anime anime,
    int rank,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final sortScore = anime.rating!.scoreFor(_rankingSortField)!;
    final overallScore = anime.rating!.effectiveOverall;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await context.push('/anime/detail/${anime.id}');
          await _load();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildCoverThumbnail(anime),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      anime.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        _typeLabel(anime.effectiveType, l10n),
                        if (overallScore != null)
                          '${l10n.animeRatingOverall}: '
                              '${_formatScore(overallScore)}',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatScore(sortScore),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _ratingFieldLabel(_rankingSortField, l10n),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Purpose: Provide the internal build cover thumbnail helper for this file.
  /// Inputs: `anime`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _buildCoverThumbnail(Anime anime) {
    if (anime.coverImage == null) return _coverPlaceholder();
    return FutureBuilder<File>(
      future: ImageService.resolve(anime.coverImage!),
      builder: (context, snap) {
        if (snap.hasData && snap.data!.existsSync()) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(
              snap.data!,
              width: 44,
              height: 62,
              fit: BoxFit.cover,
            ),
          );
        }
        return _coverPlaceholder();
      },
    );
  }

  /// Purpose: Provide the internal cover placeholder helper for this file.
  /// Inputs: None.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _coverPlaceholder() {
    return SizedBox(
      width: 44,
      height: 62,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.movie),
      ),
    );
  }

  /// Purpose: Provide the internal build trend chart helper for this file.
  /// Inputs: `theme`, `l10n`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _buildTrendChart(ThemeData theme, AppLocalizations l10n) {
    final data = _trendData;
    if (data.isEmpty) return const SizedBox.shrink();

    final maxY = data.fold<int>(0, (m, e) => e.tracked > m ? e.tracked : m) + 1;
    final needsScroll = data.length > 8;
    final focusedIndex = _focusedTrendIndex(data);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(l10n.statsTrend, style: theme.textTheme.titleSmall),
              if (_scope == _TimeScope.all) ...[
                const Spacer(),
                SegmentedButton<_TrendGranularity>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: _TrendGranularity.quarter,
                      label: Text(l10n.statsQuarter),
                    ),
                    ButtonSegment(
                      value: _TrendGranularity.year,
                      label: Text(l10n.statsYear),
                    ),
                  ],
                  selected: {_allTrendGranularity},
                  onSelectionChanged: (selection) {
                    setState(() => _allTrendGranularity = selection.first);
                    _scrollTrendToEnd();
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // Legend
          Row(
            children: [
              _legendDot(theme.colorScheme.primary, l10n.statsTracked),
              const SizedBox(width: 12),
              _legendDot(Colors.green, l10n.statsCompleted),
              const SizedBox(width: 12),
              _legendDot(Colors.red, l10n.statsDropped),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: needsScroll
                ? Row(
                    children: [
                      // Sticky Y-axis
                      SizedBox(width: 32, child: _buildYAxisStub(maxY, theme)),
                      // Scrollable chart
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _trendScrollController,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: data.length * 50.0,
                            child: _buildBarChart(
                              data,
                              maxY,
                              theme,
                              l10n,
                              focusedIndex: focusedIndex,
                              showLeftTitles: false,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : _buildBarChart(
                    data,
                    maxY,
                    theme,
                    l10n,
                    focusedIndex: focusedIndex,
                  ),
          ),
        ],
      ),
    );
  }

  /// Purpose: Provide the internal build yaxis stub helper for this file.
  /// Inputs: `maxY`, `theme`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _buildYAxisStub(int maxY, ThemeData theme) {
    final interval = maxY > 10 ? (maxY / 5).ceilToDouble() : 1.0;
    return BarChart(
      BarChartData(
        maxY: maxY.toDouble(),
        titlesData: FlTitlesData(
          show: true,
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: interval,
              getTitlesWidget: (value, meta) {
                if (value == value.roundToDouble()) {
                  return Text(
                    '${value.toInt()}',
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (_, _) => const SizedBox.shrink(),
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: false),
        barGroups: [],
        barTouchData: BarTouchData(enabled: false),
      ),
    );
  }

  /// Purpose: Provide the internal build bar chart helper for this file.
  /// Inputs: `data`, `maxY`, `theme`, `l10n`, `showLeftTitles`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _buildBarChart(
    List<_TrendEntry> data,
    int maxY,
    ThemeData theme,
    AppLocalizations l10n, {
    int? focusedIndex,
    bool showLeftTitles = true,
  }) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY.toDouble(),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final entry = data[groupIndex];
              final labels = [
                l10n.statsTracked,
                l10n.statsCompleted,
                l10n.statsDropped,
              ];
              final values = [entry.tracked, entry.completed, entry.dropped];
              return BarTooltipItem(
                '${labels[rodIndex]}: ${values[rodIndex]}',
                TextStyle(
                  color: theme.colorScheme.onInverseSurface,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) {
                  return const SizedBox.shrink();
                }
                final e = data[index];
                final label = e.quarter == 0
                    ? '${e.year}'
                    : "'${e.year % 100}Q${e.quarter}";
                final isFocused = index == focusedIndex;
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isFocused ? theme.colorScheme.primary : null,
                      fontSize: 10,
                      fontWeight: isFocused ? FontWeight.bold : null,
                    ),
                  ),
                );
              },
              reservedSize: 28,
            ),
          ),
          leftTitles: showLeftTitles
              ? AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: maxY > 10 ? (maxY / 5).ceilToDouble() : 1,
                    getTitlesWidget: (value, meta) {
                      if (value == value.roundToDouble()) {
                        return Text(
                          '${value.toInt()}',
                          style: const TextStyle(fontSize: 10),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                )
              : AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 10 ? (maxY / 5).ceilToDouble() : 1,
        ),
        barGroups: List.generate(data.length, (i) {
          final e = data[i];
          final isFocused = i == focusedIndex;
          final barWidth = isFocused ? 10.0 : 8.0;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: e.tracked.toDouble(),
                color: theme.colorScheme.primary,
                width: barWidth,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(2),
                ),
              ),
              BarChartRodData(
                toY: e.completed.toDouble(),
                color: Colors.green,
                width: barWidth,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(2),
                ),
              ),
              BarChartRodData(
                toY: e.dropped.toDouble(),
                color: Colors.red,
                width: barWidth,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(2),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  /// Purpose: Provide the internal legend dot helper for this file.
  /// Inputs: `color`, `label`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  /// Purpose: Provide the internal build grouped lists helper for this file.
  /// Inputs: `grouped`, `theme`, `l10n`.
  /// Returns: `List<Widget>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  List<Widget> _buildGroupedLists(
    Map<AnimeViewingStatus, List<Anime>> grouped,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final order = [
      (
        AnimeViewingStatus.completed,
        l10n.statsCompleted,
        _scope != _TimeScope.all,
      ),
      (
        AnimeViewingStatus.watching,
        l10n.statsWatching,
        _scope != _TimeScope.all,
      ),
      (AnimeViewingStatus.dropped, l10n.statsDropped, false),
      (AnimeViewingStatus.notStarted, l10n.statsNotStarted, false),
    ];

    return order.map((entry) {
      final status = entry.$1;
      final label = entry.$2;
      final initiallyExpanded = entry.$3;
      final list = grouped[status]!;

      return ExpansionTile(
        title: Text('$label (${list.length})'),
        initiallyExpanded: initiallyExpanded && list.isNotEmpty,
        children: list.map((anime) {
          final watchedCount = anime.episodeStatuses.values
              .where((s) => s == EpisodeStatus.watched)
              .length;
          final totalEps =
              (anime.endEpisode ?? anime.startEpisode) - anime.startEpisode + 1;
          final progress = totalEps > 0 ? watchedCount / totalEps : 0.0;

          return ListTile(
            leading: anime.coverImage != null
                ? FutureBuilder<File>(
                    future: ImageService.resolve(anime.coverImage!),
                    builder: (context, snap) {
                      if (snap.hasData && snap.data!.existsSync()) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.file(
                            snap.data!,
                            width: 40,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                        );
                      }
                      return const SizedBox(
                        width: 40,
                        height: 56,
                        child: Icon(Icons.movie),
                      );
                    },
                  )
                : const SizedBox(
                    width: 40,
                    height: 56,
                    child: Icon(Icons.movie),
                  ),
            title: Text(
              anime.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Row(
              children: [
                Text('$watchedCount/$totalEps'),
                const SizedBox(width: 8),
                Expanded(
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
            onTap: () async {
              await context.push('/anime/detail/${anime.id}');
              await _load();
            },
          );
        }).toList(),
      );
    }).toList();
  }

  /// Purpose: Provide the internal quarter label helper for this file.
  /// Inputs: `year`, `quarter`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String _quarterLabel(int year, int quarter) {
    final l10n = AppLocalizations.of(context)!;
    final seasons = [
      '',
      l10n.seasonWinter,
      l10n.seasonSpring,
      l10n.seasonSummer,
      l10n.seasonFall,
    ];
    return '$year ${seasons[quarter]}';
  }

  /// Purpose: Provide the internal ranking time filter label helper for this file.
  /// Inputs: `filter`, `l10n`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String _rankingTimeFilterLabel(
    _RankingTimeFilter filter,
    AppLocalizations l10n,
  ) {
    switch (filter) {
      case _RankingTimeFilter.all:
        return l10n.statsAll;
      case _RankingTimeFilter.quarter:
        return l10n.statsQuarter;
      case _RankingTimeFilter.year:
        return l10n.statsYear;
      case _RankingTimeFilter.custom:
        return l10n.statsRankingCustomRange;
    }
  }

  /// Purpose: Provide the internal ranking share subtitle helper for this file.
  /// Inputs: `l10n`.
  /// Returns: `String`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  String _rankingShareSubtitle(AppLocalizations l10n) {
    final time = switch (_rankingTimeFilter) {
      _RankingTimeFilter.all => l10n.statsAll,
      _RankingTimeFilter.quarter => _quarterLabel(
        _rankingSelectedYear,
        _rankingSelectedQuarter,
      ),
      _RankingTimeFilter.year => '$_rankingSelectedYearOnly',
      _RankingTimeFilter.custom =>
        '${_quarterLabel(_rankingStartYear, _rankingStartQuarter)} - '
            '${_quarterLabel(_rankingEndYear, _rankingEndQuarter)}',
    };
    final type = _rankingTypeFilter == null
        ? l10n.statsRankingAllTypes
        : _typeLabel(_rankingTypeFilter!, l10n);
    return '${l10n.statsRankingTimeFilter}: $time · '
        '${l10n.statsRankingTypeFilter}: $type';
  }

  /// Purpose: Provide the internal rating field label helper for this file.
  /// Inputs: `field`, `l10n`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String _ratingFieldLabel(AnimeRatingField field, AppLocalizations l10n) {
    switch (field) {
      case AnimeRatingField.overall:
        return l10n.animeRatingOverall;
      case AnimeRatingField.visual:
        return l10n.animeRatingVisual;
      case AnimeRatingField.story:
        return l10n.animeRatingStory;
      case AnimeRatingField.character:
        return l10n.animeRatingCharacter;
      case AnimeRatingField.music:
        return l10n.animeRatingMusic;
      case AnimeRatingField.enjoyment:
        return l10n.animeRatingEnjoyment;
    }
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

  /// Purpose: Provide the internal format score helper for this file.
  /// Inputs: `score`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String _formatScore(double score) {
    if (score == score.roundToDouble()) return score.toInt().toString();
    return score.toStringAsFixed(1);
  }
}

class _TrendEntry {
  final int year;
  final int quarter;
  final int tracked;
  final int completed;
  final int dropped;

  /// Purpose: Create a trend entry instance.
  /// Inputs: `year`, `quarter`, `tracked`, `completed`, `dropped`.
  /// Returns: A new `_TrendEntry` instance.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  const _TrendEntry({
    required this.year,
    required this.quarter,
    required this.tracked,
    required this.completed,
    required this.dropped,
  });
}
