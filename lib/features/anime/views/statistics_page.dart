import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/image_service.dart';
import '../models/anime.dart';
import '../services/anime_storage.dart';
import 'quarter_picker_dialog.dart';

enum _StatsView { summary, ranking }

enum _TimeScope { quarter, year, all }

enum _RankingTimeFilter { all, quarter, year, custom }

enum _AnimeStatus { watching, completed, dropped, notStarted }

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  List<Anime> _allAnime = [];
  _StatsView _view = _StatsView.summary;
  _TimeScope _scope = _TimeScope.quarter;
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

  @override
  void dispose() {
    _trendScrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await AnimeStorage.load();
    if (mounted) {
      setState(() => _allAnime = data.animeList);
      _scrollTrendToEnd();
    }
  }

  void _scrollTrendToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_trendScrollController.hasClients) {
        _trendScrollController.jumpTo(
          _trendScrollController.position.maxScrollExtent,
        );
      }
    });
  }

  // --- Status derivation ---

  static _AnimeStatus _deriveStatus(Anime anime) {
    if (anime.isCompleted) return _AnimeStatus.completed;

    final statuses = anime.episodeStatuses;
    final end = anime.endEpisode;
    if (end == null) {
      // Long-running: check if has any watched
      final hasWatched = statuses.values.any((s) => s == EpisodeStatus.watched);
      return hasWatched ? _AnimeStatus.watching : _AnimeStatus.notStarted;
    }

    bool hasUnwatched = false;
    bool hasWatched = false;
    bool hasSkipped = false;
    for (int ep = anime.startEpisode; ep <= end; ep++) {
      final s = statuses[ep] ?? EpisodeStatus.unwatched;
      if (s == EpisodeStatus.unwatched) hasUnwatched = true;
      if (s == EpisodeStatus.watched) hasWatched = true;
      if (s == EpisodeStatus.skippedThisWeek) hasSkipped = true;
    }

    if (hasSkipped && !hasUnwatched) return _AnimeStatus.dropped;
    if (hasWatched) return _AnimeStatus.watching;
    return _AnimeStatus.notStarted;
  }

  // --- Filtering ---

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

  Map<_AnimeStatus, List<Anime>> get _groupedAnime {
    final map = <_AnimeStatus, List<Anime>>{
      _AnimeStatus.watching: [],
      _AnimeStatus.completed: [],
      _AnimeStatus.dropped: [],
      _AnimeStatus.notStarted: [],
    };
    for (final anime in _filteredAnime) {
      map[_deriveStatus(anime)]!.add(anime);
    }
    return map;
  }

  // --- Navigation helpers ---

  void _prevPeriod() {
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
      } else if (_scope == _TimeScope.year) {
        _selectedYearOnly--;
      }
    });
  }

  void _nextPeriod() {
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
      } else if (_scope == _TimeScope.year) {
        _selectedYearOnly++;
      }
    });
  }

  (int, int) get _rankingYearRange {
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

  Future<void> _pickRankingQuarter() async {
    final range = _rankingYearRange;
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

  Future<void> _pickRankingYear() async {
    final l10n = AppLocalizations.of(context)!;
    final range = _rankingYearRange;
    final selected = await _showYearPickerDialog(
      title: l10n.statsRankingSelectYear,
      minYear: range.$1,
      maxYear: range.$2,
      currentYear: _rankingSelectedYearOnly,
    );
    if (selected == null || !mounted) return;
    setState(() => _rankingSelectedYearOnly = selected);
  }

  Future<void> _pickRankingRangeStart() async {
    final range = _rankingYearRange;
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

  Future<void> _pickRankingRangeEnd() async {
    final range = _rankingYearRange;
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

  int _countAnimeInQuarter(int year, int quarter) {
    return _allAnime.where((a) => a.airsInQuarter(year, quarter)).length;
  }

  int _countAnimeInYear(int year) {
    return _allAnime.where((anime) {
      for (int q = 1; q <= 4; q++) {
        if (anime.airsInQuarter(year, q)) return true;
      }
      return false;
    }).length;
  }

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

  static int _quarterIndex(int year, int quarter) => year * 4 + quarter;

  static (int, int) _quarterFromIndex(int index) {
    final year = (index - 1) ~/ 4;
    final quarter = ((index - 1) % 4) + 1;
    return (year, quarter);
  }

  // --- Trend data ---

  List<_TrendEntry> get _trendData {
    // Collect quarters that have data
    final quarterSet = <(int, int)>{};
    for (final anime in _allAnime) {
      final sq = anime.startQuarter;
      if (sq != null) {
        final q = _monthToQuarter(sq.$2);
        quarterSet.add((sq.$1, q));
      }
    }

    // Also add current context quarters
    final now = DateTime.now();
    final currentYear = now.year;
    final currentQ = ((now.month - 1) ~/ 3) + 1;

    List<(int, int)> quarters;
    switch (_scope) {
      case _TimeScope.quarter:
        // Show recent 8 quarters ending at selected
        quarters = [];
        int y = _selectedYear, q = _selectedQuarter;
        for (int i = 0; i < 8; i++) {
          quarters.insert(0, (y, q));
          q--;
          if (q < 1) {
            q = 4;
            y--;
          }
        }
      case _TimeScope.year:
        // Show recent 5 years ending at selected year (per-year aggregation)
        return List.generate(5, (i) => _selectedYearOnly - 4 + i).map((y) {
          final animeInYear = _allAnime.where((a) {
            for (int q = 1; q <= 4; q++) {
              if (a.airsInQuarter(y, q)) return true;
            }
            return false;
          }).toList();
          return _TrendEntry(
            year: y,
            quarter: 0,
            tracked: animeInYear.length,
            completed: animeInYear
                .where((a) => _deriveStatus(a) == _AnimeStatus.completed)
                .length,
            dropped: animeInYear
                .where((a) => _deriveStatus(a) == _AnimeStatus.dropped)
                .length,
          );
        }).toList();
      case _TimeScope.all:
        // All quarters from earliest to latest data
        if (quarterSet.isEmpty) return [];
        final sorted = quarterSet.toList()
          ..sort((a, b) {
            if (a.$1 != b.$1) return a.$1.compareTo(b.$1);
            return a.$2.compareTo(b.$2);
          });
        final first = sorted.first;
        final last = (currentYear, currentQ);
        quarters = [];
        int y = first.$1, q = first.$2;
        while (y < last.$1 || (y == last.$1 && q <= last.$2)) {
          quarters.add((y, q));
          q++;
          if (q > 4) {
            q = 1;
            y++;
          }
        }
    }

    return quarters.map((yq) {
      final animeInQ = _allAnime
          .where((a) => a.airsInQuarter(yq.$1, yq.$2))
          .toList();
      int tracked = animeInQ.length;
      int completed = animeInQ
          .where((a) => _deriveStatus(a) == _AnimeStatus.completed)
          .length;
      int dropped = animeInQ
          .where((a) => _deriveStatus(a) == _AnimeStatus.dropped)
          .length;
      return _TrendEntry(
        year: yq.$1,
        quarter: yq.$2,
        tracked: tracked,
        completed: completed,
        dropped: dropped,
      );
    }).toList();
  }

  static int _monthToQuarter(int month) {
    if (month <= 3) return 1;
    if (month <= 6) return 2;
    if (month <= 9) return 3;
    return 4;
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final grouped = _groupedAnime;
    final isRanking = _view == _StatsView.ranking;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.statsTitle)),
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
                        _scrollTrendToEnd();
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
                          ? theme.colorScheme.secondaryContainer
                          : null,
                      foregroundColor: isRanking
                          ? theme.colorScheme.onSecondaryContainer
                          : null,
                    ),
                  ),
                ],
              ),
            ),

            if (isRanking) ...[
              _buildRankingView(theme, l10n),
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
                        child: Center(
                          child: Text(
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
                      grouped[_AnimeStatus.watching]!.length,
                      theme.colorScheme.primary,
                    ),
                    _buildSummaryCard(
                      theme,
                      l10n.statsCompleted,
                      grouped[_AnimeStatus.completed]!.length,
                      Colors.green,
                    ),
                    _buildSummaryCard(
                      theme,
                      l10n.statsDropped,
                      grouped[_AnimeStatus.dropped]!.length,
                      Colors.red,
                    ),
                    _buildSummaryCard(
                      theme,
                      l10n.statsNotStarted,
                      grouped[_AnimeStatus.notStarted]!.length,
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

  Widget _buildRankingView(ThemeData theme, AppLocalizations l10n) {
    final rankedAnime = _rankingAnime;

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

  Widget _buildTrendChart(ThemeData theme, AppLocalizations l10n) {
    final data = _trendData;
    if (data.isEmpty) return const SizedBox.shrink();

    final maxY = data.fold<int>(0, (m, e) => e.tracked > m ? e.tracked : m) + 1;
    final needsScroll = data.length > 8;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.statsTrend, style: theme.textTheme.titleSmall),
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
                              showLeftTitles: false,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : _buildBarChart(data, maxY, theme, l10n),
          ),
        ],
      ),
    );
  }

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

  Widget _buildBarChart(
    List<_TrendEntry> data,
    int maxY,
    ThemeData theme,
    AppLocalizations l10n, {
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
                return SideTitleWidget(
                  meta: meta,
                  child: Text(label, style: const TextStyle(fontSize: 10)),
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
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: e.tracked.toDouble(),
                color: theme.colorScheme.primary,
                width: 8,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(2),
                ),
              ),
              BarChartRodData(
                toY: e.completed.toDouble(),
                color: Colors.green,
                width: 8,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(2),
                ),
              ),
              BarChartRodData(
                toY: e.dropped.toDouble(),
                color: Colors.red,
                width: 8,
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

  List<Widget> _buildGroupedLists(
    Map<_AnimeStatus, List<Anime>> grouped,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final order = [
      (_AnimeStatus.completed, l10n.statsCompleted, true),
      (_AnimeStatus.watching, l10n.statsWatching, true),
      (_AnimeStatus.dropped, l10n.statsDropped, false),
      (_AnimeStatus.notStarted, l10n.statsNotStarted, false),
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

  const _TrendEntry({
    required this.year,
    required this.quarter,
    required this.tracked,
    required this.completed,
    required this.dropped,
  });
}
