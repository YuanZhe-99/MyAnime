import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/image_service.dart';
import '../models/anime.dart';
import '../services/anime_storage.dart';

enum _TimeScope { quarter, year, all }

enum _AnimeStatus { watching, completed, dropped, notStarted }

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  List<Anime> _allAnime = [];
  _TimeScope _scope = _TimeScope.quarter;

  // For quarter scope
  late int _selectedYear;
  late int _selectedQuarter;

  // For year scope
  late int _selectedYearOnly;

  final ScrollController _trendScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedQuarter = ((now.month - 1) ~/ 3) + 1;
    _selectedYearOnly = now.year;
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
        _trendScrollController
            .jumpTo(_trendScrollController.position.maxScrollExtent);
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
      final hasWatched =
          statuses.values.any((s) => s == EpisodeStatus.watched);
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
      if (_scope == _TimeScope.quarter) {
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
      if (_scope == _TimeScope.quarter) {
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
      final animeInQ =
          _allAnime.where((a) => a.airsInQuarter(yq.$1, yq.$2)).toList();
      int tracked = animeInQ.length;
      int completed =
          animeInQ.where((a) => _deriveStatus(a) == _AnimeStatus.completed).length;
      int dropped =
          animeInQ.where((a) => _deriveStatus(a) == _AnimeStatus.dropped).length;
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.statsTitle)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 80),
          children: [
            // Scope selector
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SegmentedButton<_TimeScope>(
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
                selected: {_scope},
                onSelectionChanged: (s) {
                  setState(() => _scope = s.first);
                  _scrollTrendToEnd();
                },
              ),
            ),

            // Period navigation (quarter/year only)
            if (_scope != _TimeScope.all)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
      ThemeData theme, String label, int count, Color color) {
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

  Widget _buildTrendChart(ThemeData theme, AppLocalizations l10n) {
    final data = _trendData;
    if (data.isEmpty) return const SizedBox.shrink();

    final maxY = data.fold<int>(
            0, (m, e) => e.tracked > m ? e.tracked : m) +
        1;
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
                      SizedBox(
                        width: 32,
                        child: _buildYAxisStub(maxY, theme),
                      ),
                      // Scrollable chart
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _trendScrollController,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: data.length * 50.0,
                            child: _buildBarChart(
                              data, maxY, theme, l10n,
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
          topTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
              final values = [
                entry.tracked,
                entry.completed,
                entry.dropped,
              ];
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
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 10),
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
          topTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval:
              maxY > 10 ? (maxY / 5).ceilToDouble() : 1,
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
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(2)),
              ),
              BarChartRodData(
                toY: e.completed.toDouble(),
                color: Colors.green,
                width: 8,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(2)),
              ),
              BarChartRodData(
                toY: e.dropped.toDouble(),
                color: Colors.red,
                width: 8,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(2)),
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
                          child: Image.file(snap.data!,
                              width: 40, height: 56, fit: BoxFit.cover),
                        );
                      }
                      return const SizedBox(
                          width: 40, height: 56, child: Icon(Icons.movie));
                    },
                  )
                : const SizedBox(
                    width: 40, height: 56, child: Icon(Icons.movie)),
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
                    backgroundColor:
                        theme.colorScheme.surfaceContainerHighest,
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

  static String _quarterLabel(int year, int quarter) {
    const seasons = ['', 'Winter', 'Spring', 'Summer', 'Fall'];
    return '$year ${seasons[quarter]}';
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
