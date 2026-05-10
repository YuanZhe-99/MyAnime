import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/file_open_service.dart';
import '../../../shared/services/image_service.dart';
import '../../../shared/widgets/delete_confirm.dart';
import '../models/anime.dart';
import '../services/anime_storage.dart';
import 'quarter_picker_dialog.dart';

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
    _currentQuarterIndex = _quarters.indexWhere(
      (q) => q.year == currentQ.year && q.q == currentQ.q,
    );
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
    }).toList()..sort((a, b) {
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
    }).toList()..sort((a, b) => a.displayTitle.compareTo(b.displayTitle));
  }

  String _quarterLabel(_Quarter q) {
    final l10n = AppLocalizations.of(context)!;
    final seasons = [
      '',
      l10n.seasonWinter,
      l10n.seasonSpring,
      l10n.seasonSummer,
      l10n.seasonFall,
    ];
    return '${q.year} ${seasons[q.q]}';
  }

  String _dayLabel(int? dow) {
    if (dow == null) return '?';
    final l10n = AppLocalizations.of(context)!;
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

  Future<void> _deleteAnime(Anime anime) async {
    final ok = await confirmDelete(context, anime.displayTitle);
    if (!ok) return;
    await AnimeStorage.deleteAnime(anime.id);
    await _load();
  }

  Future<void> _showAddOptions(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.animeAdd),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'create'),
            child: ListTile(
              leading: const Icon(Icons.add),
              title: Text(l10n.addAnimeCreate),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'import'),
            child: ListTile(
              leading: const Icon(Icons.file_open),
              title: Text(l10n.addAnimeImport),
            ),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;

    if (choice == 'create') {
      final newId = await context.push<String>('/anime/edit');
      await _load();
      if (newId != null && mounted) {
        await context.push('/anime/detail/$newId');
        await _load();
        _jumpToAnimeQuarter(newId);
      }
    } else {
      final importedId = await FileOpenService.importFromPicker();
      await _load();
      if (importedId != null && mounted) {
        await context.push('/anime/detail/$importedId');
        await _load();
        _jumpToAnimeQuarter(importedId);
      }
    }
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
    final idx = _quarters.indexWhere((q) => q.year == sq.$1 && q.q == sq.$2);
    if (idx >= 0 && idx != _currentQuarterIndex) {
      _pageController.jumpToPage(idx);
    }
  }

  Future<void> _showQuarterPicker() async {
    final l10n = AppLocalizations.of(context)!;
    final current = _isOtherPage ? null : _quarters[_currentQuarterIndex];

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

    final result = await showQuarterPickerDialog(
      context: context,
      title: l10n.manageJumpToQuarter,
      minYear: minYear,
      maxYear: maxYear,
      current: current != null
          ? QuarterSelection(current.year, current.q)
          : null,
      countBuilder: (year, q) =>
          _allAnime.where((a) => a.airsInQuarter(year, q)).length,
      includeOther: true,
      otherLabel: l10n.manageOther,
      otherCount: _otherAnime.length,
      isOtherSelected: _isOtherPage,
    );

    if (result != null) {
      if (result.isOther) {
        final otherIdx = _quarters.length;
        if (otherIdx != _currentQuarterIndex) {
          _pageController.jumpToPage(otherIdx);
        }
      } else {
        final idx = _quarters.indexWhere(
          (q) => q.year == result.year && q.q == result.quarter,
        );
        if (idx >= 0 && idx != _currentQuarterIndex) {
          _pageController.jumpToPage(idx);
        }
      }
    }
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
      body: isSearching
          ? _buildSearchResults(theme, l10n)
          : _buildQuarterView(theme, l10n),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOptions(context),
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
                        Icon(
                          Icons.arrow_drop_down,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
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
    final totalEps =
        (anime.endEpisode ?? anime.startEpisode) - anime.startEpisode + 1;
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
