import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/image_service.dart';
import '../../../shared/widgets/delete_confirm.dart';
import '../models/anime.dart';
import '../services/anime_storage.dart';

class ManagementPage extends StatefulWidget {
  const ManagementPage({super.key});

  @override
  State<ManagementPage> createState() => _ManagementPageState();
}

class _ManagementPageState extends State<ManagementPage> {
  List<Anime> _allAnime = [];
  String _searchQuery = '';
  late PageController _pageController;
  late int _currentQuarterIndex;

  // Quarter list: wide range for PageView (lazy, so no perf issue)
  // Last page (_quarters.length) is the "Other" page for anime without firstAirDate.
  static final List<_Quarter> _quarters = [
    for (var y = 2000; y <= 2040; y++)
      for (var q = 1; q <= 4; q++) _Quarter(y, q),
  ];

  bool get _isOtherPage => _currentQuarterIndex == _quarters.length;

  @override
  void initState() {
    super.initState();
    _load();
    final now = DateTime.now();
    final currentQ = _Quarter(now.year, ((now.month - 1) ~/ 3) + 1);
    _currentQuarterIndex =
        _quarters.indexWhere((q) => q.year == currentQ.year && q.q == currentQ.q);
    if (_currentQuarterIndex < 0) _currentQuarterIndex = 0;
    _pageController = PageController(initialPage: _currentQuarterIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await AnimeStorage.load();
    if (mounted) setState(() => _allAnime = data.animeList);
  }

  List<Anime> _animeForQuarter(_Quarter quarter) {
    return _allAnime.where((a) {
      return a.airsInQuarter(quarter.year, quarter.q);
    }).toList()
      ..sort((a, b) {
        // Sort by air day of week
        final aDow = a.airDayOfWeek ?? 8;
        final bDow = b.airDayOfWeek ?? 8;
        if (aDow != bDow) return aDow.compareTo(bDow);
        return a.displayTitle.compareTo(b.displayTitle);
      });
  }

  /// Anime without a firstAirDate — shown on the "Other" page.
  List<Anime> get _otherAnime {
    return _allAnime.where((a) => a.firstAirDate == null).toList()
      ..sort((a, b) => a.displayTitle.compareTo(b.displayTitle));
  }

  List<Anime> _searchResults() {
    final q = _searchQuery.toLowerCase();
    return _allAnime.where((a) {
      return (a.title?.toLowerCase().contains(q) ?? false) ||
          (a.titleJa?.toLowerCase().contains(q) ?? false);
    }).toList()
      ..sort((a, b) => a.displayTitle.compareTo(b.displayTitle));
  }

  static String _quarterLabel(_Quarter q) {
    const seasons = ['', 'Winter', 'Spring', 'Summer', 'Fall'];
    return '${q.year} ${seasons[q.q]}';
  }

  static String _dayLabel(int? dow) {
    if (dow == null) return '?';
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dow.clamp(1, 7)];
  }

  Future<void> _deleteAnime(Anime anime) async {
    final ok = await confirmDelete(context, anime.displayTitle);
    if (!ok) return;
    await AnimeStorage.deleteAnime(anime.id);
    await _load();
  }

  void _jumpToAnimeQuarter(String animeId) {
    final anime = _allAnime.where((a) => a.id == animeId).firstOrNull;
    if (anime == null) return;
    final sq = anime.startQuarter;
    if (sq == null) {
      // No date — jump to "Other" page
      final otherIdx = _quarters.length;
      if (otherIdx != _currentQuarterIndex) {
        _pageController.jumpToPage(otherIdx);
      }
      return;
    }
    // sq.$2 is already the quarter number (1-4)
    final idx = _quarters.indexWhere(
        (q) => q.year == sq.$1 && q.q == sq.$2);
    if (idx >= 0 && idx != _currentQuarterIndex) {
      _pageController.jumpToPage(idx);
    }
  }

  Future<void> _showQuarterPicker() async {
    final l10n = AppLocalizations.of(context)!;
    final current = _isOtherPage ? null : _quarters[_currentQuarterIndex];

    // Compute year range from anime data
    final dataYears = <int>{};
    for (final anime in _allAnime) {
      final sq = anime.startQuarter;
      if (sq != null) dataYears.add(sq.$1);
    }
    final now = DateTime.now();
    dataYears.add(now.year);
    dataYears.add(now.year + 1);
    final minYear = dataYears.reduce((a, b) => a < b ? a : b);
    final maxYear = dataYears.reduce((a, b) => a > b ? a : b);

    const rowHeight = 44.0;
    final currentRow = current != null ? current.year - minYear : 0;
    final initialOffset =
        ((currentRow - 3) * rowHeight).clamp(0.0, double.infinity);
    final scrollCtrl = ScrollController(initialScrollOffset: initialOffset);

    final otherCount = _otherAnime.length;

    // Use sentinel _Quarter(0, 0) for "Other"
    final result = await showDialog<_Quarter>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: Text(l10n.manageJumpToQuarter),
          contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
          content: SizedBox(
            width: 300,
            height: 360,
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const SizedBox(width: 48),
                      for (final label in ['Q1', 'Q2', 'Q3', 'Q4'])
                        Expanded(
                          child: Center(
                            child: Text(
                              label,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Grid
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    itemCount: maxYear - minYear + 1,
                    itemExtent: rowHeight,
                    itemBuilder: (context, index) {
                      final year = minYear + index;
                      return Row(
                        children: [
                          SizedBox(
                            width: 48,
                            child: Text(
                              '$year',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          for (int q = 1; q <= 4; q++)
                            Expanded(
                              child: _quarterGridCell(
                                year, q, current, theme, dialogContext,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                // "Other" button
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Material(
                    color: _isOtherPage
                        ? theme.colorScheme.primary
                        : otherCount > 0
                            ? theme.colorScheme.primaryContainer
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () =>
                          Navigator.pop(dialogContext, const _Quarter(0, 0)),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Text(
                              l10n.manageOther,
                              style: TextStyle(
                                color: _isOtherPage
                                    ? theme.colorScheme.onPrimary
                                    : null,
                                fontWeight:
                                    _isOtherPage ? FontWeight.bold : null,
                              ),
                            ),
                            const Spacer(),
                            if (otherCount > 0)
                              Text(
                                '$otherCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _isOtherPage
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );
    scrollCtrl.dispose();

    if (result != null) {
      // Sentinel _Quarter(0, 0) means "Other" page
      if (result.year == 0 && result.q == 0) {
        final otherIdx = _quarters.length;
        if (otherIdx != _currentQuarterIndex) {
          _pageController.jumpToPage(otherIdx);
        }
      } else {
        final idx = _quarters.indexWhere(
            (q) => q.year == result.year && q.q == result.q);
        if (idx >= 0 && idx != _currentQuarterIndex) {
          _pageController.jumpToPage(idx);
        }
      }
    }
  }

  Widget _quarterGridCell(
    int year,
    int q,
    _Quarter? current,
    ThemeData theme,
    BuildContext dialogContext,
  ) {
    final isCurrent = current != null && year == current.year && q == current.q;
    final count = _allAnime.where((a) => a.airsInQuarter(year, q)).length;
    final hasData = count > 0;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: isCurrent
            ? theme.colorScheme.primary
            : hasData
                ? theme.colorScheme.primaryContainer
                : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => Navigator.pop(dialogContext, _Quarter(year, q)),
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Text(
              hasData ? '$count' : '',
              style: TextStyle(
                fontSize: 12,
                color: isCurrent
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onPrimaryContainer,
                fontWeight: isCurrent ? FontWeight.bold : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isSearching = _searchQuery.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navManage),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.animeSearchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ),
      ),
      body: isSearching ? _buildSearchResults(theme, l10n) : _buildQuarterView(theme, l10n),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newId = await context.push<String>('/anime/edit');
          await _load();
          if (newId != null && mounted) {
            await context.push('/anime/detail/$newId');
            await _load();
            _jumpToAnimeQuarter(newId);
          }
        },
        tooltip: l10n.animeAdd,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchResults(ThemeData theme, AppLocalizations l10n) {
    final results = _searchResults();
    if (results.isEmpty) {
      return Center(
        child: Text(
          l10n.manageNoSearchResults,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: results.length,
      itemBuilder: (context, i) => _buildAnimeTile(results[i], theme, l10n),
    );
  }

  Widget _buildQuarterView(ThemeData theme, AppLocalizations l10n) {
    return Column(
      children: [
        // Quarter navigation
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentQuarterIndex > 0
                    ? () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    : null,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _showQuarterPicker,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isOtherPage
                              ? l10n.manageOther
                              : _quarterLabel(_quarters[_currentQuarterIndex]),
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentQuarterIndex < _quarters.length
                    ? () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    : null,
              ),
            ],
          ),
        ),
        // Quarter pages + "Other" page
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _quarters.length + 1,
            onPageChanged: (index) {
              setState(() => _currentQuarterIndex = index);
            },
            itemBuilder: (context, index) {
              // "Other" page (last)
              if (index == _quarters.length) {
                final animeList = _otherAnime;
                if (animeList.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.animeNoResults,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: animeList.length,
                  itemBuilder: (context, i) =>
                      _buildAnimeTile(animeList[i], theme, l10n),
                );
              }

              final quarter = _quarters[index];
              final animeList = _animeForQuarter(quarter);

              if (animeList.isEmpty) {
                return Center(
                  child: Text(
                    l10n.animeNoResults,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: animeList.length,
                itemBuilder: (context, i) {
                  final anime = animeList[i];
                  return _buildAnimeTile(anime, theme, l10n);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAnimeTile(Anime anime, ThemeData theme, AppLocalizations l10n) {
    final watchedCount = anime.episodeStatuses.values
        .where((s) => s == EpisodeStatus.watched)
        .length;
    final totalEps = (anime.endEpisode ?? anime.startEpisode) - anime.startEpisode + 1;
    final progress = totalEps > 0 ? watchedCount / totalEps : 0.0;
    final dayStr = _dayLabel(anime.airDayOfWeek);

    return Dismissible(
      key: ValueKey(anime.id),
      background: Container(
        color: theme.colorScheme.primaryContainer,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Icon(Icons.edit, color: theme.colorScheme.primary),
      ),
      secondaryBackground: Container(
        color: theme.colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete, color: theme.colorScheme.error),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await context.push('/anime/edit/${anime.id}');
          await _load();
          return false;
        } else {
          await _deleteAnime(anime);
          return false;
        }
      },
      child: ListTile(
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
            : const SizedBox(width: 40, height: 56, child: Icon(Icons.movie)),
        title: Text(
          anime.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text('$dayStr · $watchedCount/$totalEps'),
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
      ),
    );
  }
}

class _Quarter {
  final int year;
  final int q;
  const _Quarter(this.year, this.q);
}
