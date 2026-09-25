import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/flavor.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/providers/app_settings.dart';
import '../../../shared/services/auto_sync_service.dart';
import '../../../shared/utils/adaptive_layout.dart';
import '../../../shared/widgets/adaptive_tile_grid.dart';
import '../../../shared/widgets/anime_actions_sheet.dart';
import '../../../shared/widgets/import_bundle_dialog.dart';
import '../../../shared/services/image_service.dart';
import '../../../shared/widgets/delete_confirm.dart';
import '../../ai/services/ai_insights_cache.dart';
import '../../categories/services/category_service.dart';
import '../models/anime.dart';
import '../models/anime_category.dart';
import '../services/anime_storage.dart';
import '../services/manage_grouping.dart';
import '../services/series_service.dart';
import '../services/metadata_update_service.dart';
import 'category_widgets.dart';
import 'quarter_picker_dialog.dart';

class ManagementPage extends ConsumerStatefulWidget {
  /// Purpose: Create a management page instance.
  /// Inputs: None.
  /// Returns: A new `ManagementPage` instance.
  /// Side effects: None.
  /// Notes: None.
  const ManagementPage({super.key});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  ConsumerState<ManagementPage> createState() => _ManagementPageState();
}

class _ManagementPageState extends ConsumerState<ManagementPage> {
  List<Anime> _allAnime = [];
  String _searchQuery = '';
  _ArchiveFilter _archiveFilter = _ArchiveFilter.all;

  /// The category to show, or null for all. View state only, like the
  /// archive filter; offered only while automatic categories are on.
  String? _categoryFilter;

  /// The AI category cache, read only while on-device AI is on, so
  /// AI-suggested categories stop matching once it is turned off.
  AiInsights? _insights;

  /// Series-view groups the user has expanded, by group key. Session only.
  final Set<String> _expandedGroups = {};
  late PageController _pageController;
  late int _currentQuarterIndex;

  // Quarter list: wide range for PageView (lazy, so no perf issue)
  // Last page (_quarters.length) is the "Other" page for anime without firstAirDate.
  static final List<_Quarter> _quarters = [
    for (var y = 2000; y <= 2040; y++)
      for (var q = 1; q <= 4; q++) _Quarter(y, q),
  ];

  /// Purpose: Provide the internal is other page helper for this file.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  bool get _isOtherPage => _currentQuarterIndex == _quarters.length;

  /// Purpose: Initialize listeners, controllers, and first-load work for this state object.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Initializes owned state, listeners, or async work.
  /// Notes: Flutter lifecycle override.
  @override
  void initState() {
    super.initState();
    AutoSyncService.instance.addOnLocalDataChanged(_load);
    MetadataUpdateService.instance.addListener(_onMetadataUpdatesChanged);
    _load();
    final now = DateTime.now();
    final currentQ = _Quarter(now.year, ((now.month - 1) ~/ 3) + 1);
    _currentQuarterIndex = _quarters.indexWhere(
      (q) => q.year == currentQ.year && q.q == currentQ.q,
    );
    if (_currentQuarterIndex < 0) _currentQuarterIndex = 0;
    _pageController = PageController(initialPage: _currentQuarterIndex);
  }

  /// Purpose: Release listeners, controllers, and other owned resources.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Disposes controllers, listeners, and other owned resources.
  /// Notes: Flutter lifecycle override. Unregisters the sync reload callback.
  @override
  void dispose() {
    AutoSyncService.instance.removeOnLocalDataChanged(_load);
    MetadataUpdateService.instance.removeListener(_onMetadataUpdatesChanged);
    _pageController.dispose();
    super.dispose();
  }

  /// Purpose: Refresh the available-updates badge when the queue changes.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Triggers a rebuild.
  /// Notes: Internal helper used within this file only. The background service
  /// fires this off-frame, so the mounted check is required.
  void _onMetadataUpdatesChanged() {
    if (mounted) setState(() {});
  }

  /// Purpose: Report how many records are waiting for an update decision.
  /// Inputs: None.
  /// Returns: `int`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Zero hides the badge
  /// entirely, so the action never appears without something behind it.
  int get _pendingUpdateCount => MetadataUpdateService.instance.pendingCount;

  /// Purpose: List the anime the user is currently looking at.
  /// Inputs: None.
  /// Returns: `List<String>` of anime ids.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Defines what "update
  /// this page" means: the search results while searching, otherwise the
  /// quarter page (or the "Other" page) currently in view.
  List<String> get _currentPageAnimeIds {
    final settings = ref.read(appSettingsProvider);
    if (_searchQuery.isEmpty &&
        settings.manageViewMode == ManageViewMode.series) {
      return [
        for (final g in _seriesGroups(settings.manageSeriesSort))
          for (final a in g.members) a.id,
      ];
    }
    final visible = _searchQuery.isNotEmpty
        ? _searchResults()
        : (_isOtherPage
              ? _otherAnime
              : _animeForQuarter(_quarters[_currentQuarterIndex]));
    return [for (final anime in visible) anime.id];
  }

  /// Purpose: Open the available-updates review screen.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Pushes a route and reloads data when it closes.
  /// Notes: Internal helper used within this file only. Gated on
  /// `AppFlavor.isFull` at the call site, since it leads to online lookups.
  /// Routed through go_router rather than an imperative `MaterialPageRoute`:
  /// the review screen can itself push the edit page, and a declarative page
  /// added under an imperative route lands *below* it in the navigator stack.
  Future<void> _openMetadataUpdates() async {
    await context.push<void>('/metadata-updates', extra: _currentPageAnimeIds);
    if (mounted) await _load();
  }

  /// Purpose: Provide the internal load helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  Future<void> _load() async {
    final data = await AnimeStorage.loadFixingSeasonLabels(seasonLabelFixups);
    final insights = await AnimeStorage.getOnDeviceAiEnabled()
        ? await AiInsightsCache.load()
        : null;
    if (mounted) {
      setState(() {
        _allAnime = data.animeList;
        _insights = insights;
      });
    }
  }

  /// Purpose: Provide the internal anime for quarter helper for this file.
  /// Inputs: `quarter`.
  /// Returns: `List<Anime>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  List<Anime> _animeForQuarter(_Quarter quarter) {
    return _applyArchiveFilter(_allAnime).where((a) {
      return a.airsInQuarter(quarter.year, quarter.q);
    }).toList()..sort((a, b) {
      // Sort by air day of week
      final aDow = a.airDayOfWeek ?? 8;
      final bDow = b.airDayOfWeek ?? 8;
      if (aDow != bDow) return aDow.compareTo(bDow);
      return a.displayTitle.compareTo(b.displayTitle);
    });
  }

  /// Purpose: Anime without a firstAirDate — shown on the "Other" page.
  /// Inputs: None.
  /// Returns: `List<Anime>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Anime without a firstAirDate — shown on the "Other" page.
  List<Anime> get _otherAnime {
    return _applyArchiveFilter(
        _allAnime,
      ).where((a) => a.firstAirDate == null).toList()
      ..sort((a, b) => a.displayTitle.compareTo(b.displayTitle));
  }

  /// Purpose: Narrow a list to the selected local-archive and category filters.
  /// Inputs: `animes`.
  /// Returns: `List<Anime>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. "Not archived" folds
  /// together records never recorded and records explicitly marked as not
  /// downloaded, which is what "what still needs downloading" means. The
  /// category filter applies only while automatic categories are on, and
  /// matches a record's effective categories (its own, mapped or AI).
  List<Anime> _applyArchiveFilter(List<Anime> animes) {
    final byArchive = switch (_archiveFilter) {
      _ArchiveFilter.all => animes,
      _ArchiveFilter.archived =>
        animes.where((a) => a.localArchive?.archived == true).toList(),
      _ArchiveFilter.notArchived =>
        animes.where((a) => a.localArchive?.archived != true).toList(),
    };
    final category = _categoryFilter;
    if (category == null ||
        !ref.read(appSettingsProvider).autoCategoriesEnabled) {
      return byArchive;
    }
    return byArchive
        .where(
          (a) =>
              resolveCategories(a, insights: _insights).ids.contains(category),
        )
        .toList();
  }

  /// Purpose: Provide the internal archive filter label helper for this file.
  /// Inputs: `filter`, `l10n`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String _archiveFilterLabel(_ArchiveFilter filter, AppLocalizations l10n) {
    switch (filter) {
      case _ArchiveFilter.all:
        return l10n.manageFilterAll;
      case _ArchiveFilter.archived:
        return l10n.manageFilterArchived;
      case _ArchiveFilter.notArchived:
        return l10n.manageFilterNotArchived;
    }
  }

  /// Purpose: Provide the internal search results helper for this file.
  /// Inputs: None.
  /// Returns: `List<Anime>`.
  /// Side effects: May perform network or file-system operations.
  /// Notes: Internal helper used within this file only.
  List<Anime> _searchResults() {
    final q = _searchQuery.toLowerCase();
    return _applyArchiveFilter(_allAnime).where((a) {
      return (a.title?.toLowerCase().contains(q) ?? false) ||
          (a.titleJa?.toLowerCase().contains(q) ?? false);
    }).toList()..sort((a, b) => a.displayTitle.compareTo(b.displayTitle));
  }

  /// Purpose: Provide the internal quarter label helper for this file.
  /// Inputs: `q`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Provide the internal day label helper for this file.
  /// Inputs: `dow`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Provide the internal delete anime helper for this file.
  /// Inputs: `anime`.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  Future<void> _deleteAnime(Anime anime) async {
    final ok = await confirmDelete(context, anime.displayTitle);
    if (!ok) return;
    await AnimeStorage.deleteAnime(anime.id);
    await _load();
  }

  /// Purpose: Provide the internal show add options helper for this file.
  /// Inputs: `context`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
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
      final result = await showImportBundleFlow(context);
      await _load();
      if (result != null && result.importedIds.isNotEmpty && mounted) {
        await context.push('/anime/detail/${result.importedIds.first}');
        await _load();
        _jumpToAnimeQuarter(result.importedIds.first);
      }
    }
  }

  /// Purpose: Provide the internal jump to anime quarter helper for this file.
  /// Inputs: `animeId`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  void _jumpToAnimeQuarter(String animeId) {
    // The series view has no pages to jump between.
    if (!_pageController.hasClients) return;
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

  /// Purpose: Provide the internal show quarter picker helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isSearching = _searchQuery.isNotEmpty;
    final settings = ref.watch(appSettingsProvider);
    final screen = MediaQuery.sizeOf(context);
    // The shell's navigation rail, when it is showing, is not part of the
    // width this list gets, so the capacity must be measured without it.
    final contentWidth = shellContentWidth(screen.width);
    final capacity = canSplitLayout(screen.width, screen.height)
        ? listColumnCapacity(contentWidth)
        : 1;
    final columns = listColumnCount(
      screenWidth: screen.width,
      screenHeight: screen.height,
      contentWidth: contentWidth,
      preference: settings.manageListColumns,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navManage),
        actions: [
          // Always offered, badge or not: with no pending proposals there would
          // otherwise be no way into the review screen at all, and that screen
          // is where the user starts a check of their own.
          if (AppFlavor.isFull)
            IconButton(
              tooltip: l10n.metaUpdatesTooltip,
              onPressed: _openMetadataUpdates,
              icon: Badge(
                isLabelVisible: _pendingUpdateCount > 0,
                label: Text('$_pendingUpdateCount'),
                child: const Icon(Icons.cloud_download_outlined),
              ),
            ),
          IconButton(
            tooltip: settings.manageViewMode == ManageViewMode.series
                ? l10n.manageViewQuarter
                : l10n.manageViewSeries,
            icon: Icon(
              settings.manageViewMode == ManageViewMode.series
                  ? Icons.calendar_view_month
                  : Icons.account_tree_outlined,
            ),
            onPressed: () => _setViewMode(
              settings.manageViewMode == ManageViewMode.series
                  ? ManageViewMode.quarter
                  : ManageViewMode.series,
            ),
          ),
          if (settings.manageViewMode == ManageViewMode.series)
            PopupMenuButton<ManageSeriesSort>(
              icon: const Icon(Icons.sort),
              tooltip: l10n.manageSeriesSort,
              initialValue: settings.manageSeriesSort,
              onSelected: (v) =>
                  ref.read(appSettingsProvider.notifier).setManageSeriesSort(v),
              itemBuilder: (context) => [
                for (final s in ManageSeriesSort.values)
                  PopupMenuItem(
                    value: s,
                    child: Text(_seriesSortLabel(s, l10n)),
                  ),
              ],
            ),
          listColumnsButton(
            context,
            preference: settings.manageListColumns,
            capacity: capacity,
            onChanged: (value) => ref
                .read(appSettingsProvider.notifier)
                .setManageListColumns(value),
          ),
          if (settings.autoCategoriesEnabled)
            PopupMenuButton<String>(
              icon: Icon(
                _categoryFilter == null
                    ? Icons.category_outlined
                    : Icons.category,
              ),
              tooltip: l10n.manageFilterCategory,
              initialValue: _categoryFilter ?? '',
              onSelected: (v) =>
                  setState(() => _categoryFilter = v.isEmpty ? null : v),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: '',
                  child: Text(l10n.manageFilterAllCategories),
                ),
                for (final c in animeCategories)
                  PopupMenuItem(
                    value: c.id,
                    child: Text(categoryLabel(c.id, l10n)),
                  ),
              ],
            ),
          PopupMenuButton<_ArchiveFilter>(
            icon: Icon(
              _archiveFilter == _ArchiveFilter.all
                  ? Icons.filter_alt_outlined
                  : Icons.filter_alt,
            ),
            tooltip: l10n.manageFilterArchive,
            initialValue: _archiveFilter,
            onSelected: (v) => setState(() => _archiveFilter = v),
            itemBuilder: (context) => [
              for (final filter in _ArchiveFilter.values)
                PopupMenuItem(
                  value: filter,
                  child: Text(_archiveFilterLabel(filter, l10n)),
                ),
            ],
          ),
        ],
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
          ? _buildSearchResults(theme, l10n, columns)
          : settings.manageViewMode == ManageViewMode.series
          ? _buildSeriesView(theme, l10n, columns, settings.manageSeriesSort)
          : _buildQuarterView(theme, l10n, columns),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOptions(context),
        tooltip: l10n.animeAdd,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Purpose: Provide the internal build search results helper for this file.
  /// Inputs: `theme`, `l10n`.
  /// Returns: `Widget`.
  /// Side effects: May perform network or file-system operations.
  /// Notes: Internal helper used within this file only.
  Widget _buildSearchResults(
    ThemeData theme,
    AppLocalizations l10n,
    int columns,
  ) {
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
      padding: EdgeInsets.only(
        bottom: shellListBottomInset(MediaQuery.sizeOf(context).width),
      ),
      itemCount: listRowCount(results.length, columns),
      itemBuilder: (context, row) => adaptiveTileRow(
        rowIndex: row,
        columns: columns,
        itemCount: results.length,
        itemBuilder: (i) => _buildAnimeTile(results[i], theme, l10n, columns),
      ),
    );
  }

  /// Purpose: Provide the internal build quarter view helper for this file.
  /// Inputs: `theme`, `l10n`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _buildQuarterView(
    ThemeData theme,
    AppLocalizations l10n,
    int columns,
  ) {
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
                  padding: EdgeInsets.only(
                    bottom: shellListBottomInset(
                      MediaQuery.sizeOf(context).width,
                    ),
                  ),
                  itemCount: listRowCount(animeList.length, columns),
                  itemBuilder: (context, row) => adaptiveTileRow(
                    rowIndex: row,
                    columns: columns,
                    itemCount: animeList.length,
                    itemBuilder: (i) =>
                        _buildAnimeTile(animeList[i], theme, l10n, columns),
                  ),
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
                padding: EdgeInsets.only(
                  bottom: shellListBottomInset(
                    MediaQuery.sizeOf(context).width,
                  ),
                ),
                itemCount: listRowCount(animeList.length, columns),
                itemBuilder: (context, row) => adaptiveTileRow(
                  rowIndex: row,
                  columns: columns,
                  itemCount: animeList.length,
                  itemBuilder: (i) =>
                      _buildAnimeTile(animeList[i], theme, l10n, columns),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Purpose: Switch between the quarter and series views (1.6.2).
  /// Inputs: `mode`.
  /// Returns: None.
  /// Side effects: Persists the mode device-locally; recreates the page
  /// controller when returning to the quarter view.
  /// Notes: Internal helper used within this file only. A fresh controller
  /// starts on the quarter the user last looked at, because the old one was
  /// detached while the series view showed.
  void _setViewMode(ManageViewMode mode) {
    if (mode == ManageViewMode.quarter) {
      _pageController.dispose();
      _pageController = PageController(initialPage: _currentQuarterIndex);
    }
    ref.read(appSettingsProvider.notifier).setManageViewMode(mode);
  }

  /// Purpose: Group the filtered library for the series view (1.6.2).
  /// Inputs: `sort`.
  /// Returns: `List<ManageSeriesGroup>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Series are computed
  /// over the whole library; the archive and category filters only decide
  /// which members show. See `groupForSeriesView`.
  List<ManageSeriesGroup> _seriesGroups(ManageSeriesSort sort) {
    final kept = {for (final a in _applyArchiveFilter(_allAnime)) a.id};
    return groupForSeriesView(
      _allAnime,
      keep: (a) => kept.contains(a.id),
      sort: sort,
    );
  }

  /// Purpose: Localize a series-view sort for its menu.
  /// Inputs: `sort`, `l10n`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String _seriesSortLabel(ManageSeriesSort sort, AppLocalizations l10n) =>
      switch (sort) {
        ManageSeriesSort.latest => l10n.manageSeriesSortLatest,
        ManageSeriesSort.title => l10n.manageSeriesSortTitle,
        ManageSeriesSort.modified => l10n.manageSeriesSortModified,
      };

  /// Purpose: Render the series view (1.6.2).
  /// Inputs: `theme`, `l10n`, `columns`, `sort`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. A series is an
  /// expandable row whose members are the ordinary tiles, laid out with the
  /// page's column count; a record in no series is its ordinary tile.
  Widget _buildSeriesView(
    ThemeData theme,
    AppLocalizations l10n,
    int columns,
    ManageSeriesSort sort,
  ) {
    final groups = _seriesGroups(sort);
    if (groups.isEmpty) {
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
      padding: EdgeInsets.only(
        bottom: shellListBottomInset(MediaQuery.sizeOf(context).width),
      ),
      itemCount: groups.length,
      itemBuilder: (context, i) {
        final g = groups[i];
        if (!g.isGroup) {
          return _buildAnimeTile(g.members.single, theme, l10n, columns);
        }
        final completed = g.members
            .where((m) => m.viewingStatus == AnimeViewingStatus.completed)
            .length;
        return ExpansionTile(
          key: PageStorageKey<String>('series-${g.key}'),
          initiallyExpanded: _expandedGroups.contains(g.key),
          onExpansionChanged: (open) =>
              open ? _expandedGroups.add(g.key) : _expandedGroups.remove(g.key),
          leading: const Icon(Icons.account_tree_outlined),
          title: Text(g.label, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(l10n.manageSeriesMembers(g.members.length, completed)),
          childrenPadding: const EdgeInsetsDirectional.only(start: 16),
          children: adaptiveTileRows(
            columns: columns,
            itemCount: g.members.length,
            itemBuilder: (j) =>
                _buildAnimeTile(g.members[j], theme, l10n, columns),
          ),
        );
      },
    );
  }

  /// Purpose: Show the long-press action sheet for one anime and reload.
  /// Inputs: `anime`.
  /// Returns: None.
  /// Side effects: Shows a modal sheet; may edit or delete the anime and
  /// reloads the page when it did.
  /// Notes: Internal helper used within this file only.
  Future<void> _showActions(Anime anime) async {
    final changed = await showAnimeActionsSheet(context, anime);
    if (changed && mounted) await _load();
  }

  /// Purpose: Provide the internal build anime tile helper for this file.
  /// Inputs: `anime`, `theme`, `l10n`, `columns`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _buildAnimeTile(
    Anime anime,
    ThemeData theme,
    AppLocalizations l10n,
    int columns,
  ) {
    final watchedCount = anime.episodeStatuses.values
        .where((s) => s == EpisodeStatus.watched)
        .length;
    final totalEps =
        (anime.endEpisode ?? anime.startEpisode) - anime.startEpisode + 1;
    final progress = totalEps > 0 ? watchedCount / totalEps : 0.0;
    final dayStr = _dayLabel(anime.airDayOfWeek);
    // The watch site's newest episode, when a valid check is stored.
    final siteLatest = anime.validWatchProgress?.latestEpisode;
    final siteStr = siteLatest == null
        ? ''
        : ' · ${l10n.anime1Short(siteLatest)}';

    final tile = GestureDetector(
      onSecondaryTapUp: (_) => _showActions(anime),
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
            Text('$dayStr · $watchedCount/$totalEps$siteStr'),
            const SizedBox(width: 8),
            Expanded(
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
        onLongPress: () => _showActions(anime),
        onTap: () async {
          await context.push('/anime/detail/${anime.id}');
          await _load();
        },
      ),
    );

    // Swipe-to-edit and swipe-to-delete only make sense while a row spans the
    // full width. In a multi-column grid a horizontal drag inside one narrow
    // cell is ambiguous, so the long-press sheet carries both actions instead.
    if (columns > 1) return tile;

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
      child: tile,
    );
  }
}

class _Quarter {
  final int year;
  final int q;

  /// Purpose: Create a quarter instance.
  /// Inputs: `year`, `q`.
  /// Returns: A new `_Quarter` instance.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  const _Quarter(this.year, this.q);
}

/// Local-archive filter applied to every list on the management page.
enum _ArchiveFilter {
  /// No filtering.
  all,

  /// Only anime with a local copy recorded.
  archived,

  /// Anime without a local copy — never recorded, or recorded as not kept.
  notArchived,
}
