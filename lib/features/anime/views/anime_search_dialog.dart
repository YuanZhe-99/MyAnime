import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/image_service.dart';
import '../models/anime.dart';
import '../services/anime_search_service.dart';

/// Purpose: Shows the anime search dialog.
/// Inputs: `context`, `initialQuery`, `currentTitle`, `currentTitleJa`, `currentEndEp`, `currentFirstAirDate`, `currentAirDay`, `currentAirTime`, `currentCoverImage`, `currentNotes`, `currentExternalMeta`.
/// Returns: `Future<Map<String, dynamic>?>`.
/// Side effects: May perform network or file-system operations.
/// Notes: Shows the anime search dialog. Returns a map of field names → values to apply, or null if cancelled.
Future<Map<String, dynamic>?> showAnimeSearchDialog(
  BuildContext context, {
  String? initialQuery,
  String? currentTitle,
  String? currentTitleJa,
  int? currentEndEp,
  DateTime? currentFirstAirDate,
  int? currentAirDay,
  String? currentAirTime,
  String? currentCoverImage,
  String? currentNotes,
  AnimeExternalMeta? currentExternalMeta,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _SearchDialog(
      initialQuery: initialQuery,
      currentTitle: currentTitle,
      currentTitleJa: currentTitleJa,
      currentEndEp: currentEndEp,
      currentFirstAirDate: currentFirstAirDate,
      currentAirDay: currentAirDay,
      currentAirTime: currentAirTime,
      currentCoverImage: currentCoverImage,
      currentNotes: currentNotes,
      currentExternalMeta: currentExternalMeta,
    ),
  );
}

enum _Phase { search, preview }

/// Ordering applied to the search result list.
enum _SearchSort {
  /// Fuzzy match quality against the query, best first.
  relevance,

  /// Newest first air date first; results without one sink to the bottom.
  firstAirDate,

  /// Highest episode count first; results without one sink to the bottom.
  episodes,

  /// Grouped alphabetically by source name.
  source,
}

class _SearchDialog extends StatefulWidget {
  final String? initialQuery;
  final String? currentTitle;
  final String? currentTitleJa;
  final int? currentEndEp;
  final DateTime? currentFirstAirDate;
  final int? currentAirDay;
  final String? currentAirTime;
  final String? currentCoverImage;
  final String? currentNotes;
  final AnimeExternalMeta? currentExternalMeta;

  /// Purpose: Create a search dialog instance.
  /// Inputs: `initialQuery`, `currentTitle`, `currentTitleJa`, `currentEndEp`, `currentFirstAirDate`, `currentAirDay`, `currentAirTime`, `currentCoverImage`, `currentNotes`, `currentExternalMeta`.
  /// Returns: A new `_SearchDialog` instance.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  const _SearchDialog({
    this.initialQuery,
    this.currentTitle,
    this.currentTitleJa,
    this.currentEndEp,
    this.currentFirstAirDate,
    this.currentAirDay,
    this.currentAirTime,
    this.currentCoverImage,
    this.currentNotes,
    this.currentExternalMeta,
  });

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  late final TextEditingController _queryController;

  _Phase _phase = _Phase.search;

  // Search phase
  List<AnimeSearchResult> _results = [];
  List<String> _queryVariants = const [];
  String? _searchLanguage;
  bool _searching = false;
  AnimeSearchProgress? _progress;
  String? _error;

  // Result list controls
  _SearchSort _sort = _SearchSort.relevance;
  final Set<String> _hiddenSources = {};
  bool _onlyWithCover = false;
  bool _onlyWithAirDate = false;
  bool _groupBySource = false;

  // Preview phase
  AnimeSearchResult? _selected;
  final Map<String, bool> _toggles = {};
  bool _fetchingCover = false;
  String? _fetchedCoverPath;
  ImageProvider? _coverPreview;

  /// Purpose: Initialize listeners, controllers, and first-load work for this state object.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Initializes owned state, listeners, or async work.
  /// Notes: Flutter lifecycle override.
  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery ?? '');
  }

  /// Purpose: Release listeners, controllers, and other owned resources.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Disposes controllers, listeners, and other owned resources.
  /// Notes: Flutter lifecycle override.
  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  /// Purpose: Provide the internal search helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May perform network or file-system operations.
  /// Notes: Internal helper used within this file only. Passes the active UI
  /// locale so the service can favour titles in the user's own language.
  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;
    final language = Localizations.localeOf(context).toLanguageTag();

    setState(() {
      _searching = true;
      _progress = null;
      _error = null;
      _results = [];
      _hiddenSources.clear();
      _onlyWithCover = false;
      _onlyWithAirDate = false;
    });

    try {
      final results = await AnimeSearchService.searchAll(
        query,
        preferredLanguage: language,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      if (!mounted) return;
      setState(() {
        _progress = null;
        _results = results;
        _queryVariants = AnimeSearchService.queryVariants(query);
        _searchLanguage = language;
        _searching = false;
        if (results.isEmpty) {
          _error = AppLocalizations.of(context)!.searchNoResults;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _progress = null;
        _error = e.toString();
      });
    }
  }

  /// Purpose: Apply the active filters and sort order to the raw result list.
  /// Inputs: None.
  /// Returns: `List<AnimeSearchResult>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Results missing the
  /// value being sorted on always sink to the bottom instead of sorting as
  /// zero, so an unknown episode count never outranks a known one.
  List<AnimeSearchResult> get _visibleResults {
    final filtered = _results.where((r) {
      if (_hiddenSources.contains(r.source)) return false;
      if (_onlyWithCover && r.coverImageUrl == null) return false;
      if (_onlyWithAirDate && r.firstAirDate == null) return false;
      return true;
    }).toList();

    switch (_sort) {
      case _SearchSort.relevance:
        filtered.sort(
          (a, b) => _relevance(b).compareTo(_relevance(a)),
        );
      case _SearchSort.firstAirDate:
        filtered.sort((a, b) {
          if (a.firstAirDate == null && b.firstAirDate == null) return 0;
          if (a.firstAirDate == null) return 1;
          if (b.firstAirDate == null) return -1;
          return b.firstAirDate!.compareTo(a.firstAirDate!);
        });
      case _SearchSort.episodes:
        filtered.sort((a, b) {
          if (a.episodes == null && b.episodes == null) return 0;
          if (a.episodes == null) return 1;
          if (b.episodes == null) return -1;
          return b.episodes!.compareTo(a.episodes!);
        });
      case _SearchSort.source:
        filtered.sort((a, b) {
          final cmp = a.source.compareTo(b.source);
          if (cmp != 0) return cmp;
          return _relevance(b).compareTo(_relevance(a));
        });
    }
    return filtered;
  }

  /// Purpose: Score one result the same way the service ranked the raw list.
  /// Inputs: `r`.
  /// Returns: `double`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Passes the cached query
  /// variants and search language so re-sorting here reproduces exactly the
  /// order `searchAll` returned, instead of drifting on near-ties.
  double _relevance(AnimeSearchResult r) => AnimeSearchService.relevance(
    r,
    _queryVariants,
    preferredLanguage: _searchLanguage,
  );

  /// Purpose: List the source names present in the current raw results.
  /// Inputs: None.
  /// Returns: `List<String>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Drives the source
  /// filter chips, so a source that returned nothing is not offered.
  List<String> get _availableSources {
    final names = <String>{for (final r in _results) r.source};
    return AnimeSearchSource.all.where(names.contains).toList();
  }

  /// Purpose: Provide the internal select result helper for this file.
  /// Inputs: `result`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  void _selectResult(AnimeSearchResult result) {
    setState(() {
      _selected = result;
      _phase = _Phase.preview;
      _fetchedCoverPath = null;
      _coverPreview = null;
      _toggles.clear();
      if (result.title?.isNotEmpty == true) _toggles['title'] = true;
      if (result.titleJa?.isNotEmpty == true) _toggles['titleJa'] = true;
      if (result.episodes != null) _toggles['episodes'] = true;
      if (result.firstAirDate != null) _toggles['firstAirDate'] = true;
      if (result.airDayOfWeek != null) _toggles['airDayOfWeek'] = true;
      if (result.airTime != null) _toggles['airTime'] = true;
      if (result.summary?.isNotEmpty == true) _toggles['notes'] = true;
      if (_externalMetaFieldCount(result) > 0) _toggles['externalMeta'] = true;
      // Cover is off by default — requires explicit fetch
      if (result.coverImageUrl != null) _toggles['cover'] = false;
    });
  }

  /// Purpose: Count how many external-metadata fields a result actually carries.
  /// Inputs: `r`.
  /// Returns: `int`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Zero means the source
  /// supplied nothing beyond the basic fields, so no checkbox is offered.
  int _externalMetaFieldCount(AnimeSearchResult r) {
    var count = 0;
    if (r.synonyms.isNotEmpty) count++;
    if (r.titleRomaji != null) count++;
    if (r.titleEn != null) count++;
    if (r.format != null) count++;
    if (r.status != null) count++;
    if (r.durationMinutes != null) count++;
    if (r.genres.isNotEmpty) count++;
    if (r.studios.isNotEmpty) count++;
    if (r.endDate != null) count++;
    if (r.score != null || r.scoreVotes != null || r.scoreRank != null) count++;
    return count;
  }

  /// Purpose: Provide the internal fetch cover helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Downloads the cover image and writes it into app storage.
  /// Notes: Internal helper used within this file only.
  Future<void> _fetchCover() async {
    if (_selected?.coverImageUrl == null) return;
    setState(() => _fetchingCover = true);
    try {
      final path = await ImageService.saveImageFromUrl(
        _selected!.coverImageUrl!,
      );
      if (path != null && mounted) {
        final file = await ImageService.resolve(path);
        setState(() {
          _fetchedCoverPath = path;
          _coverPreview = FileImage(file);
          _toggles['cover'] = true;
          _fetchingCover = false;
        });
      } else {
        if (mounted) setState(() => _fetchingCover = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _fetchingCover = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.searchCoverFetchFailed('$e'),
            ),
          ),
        );
      }
    }
  }

  /// Purpose: Provide the internal apply helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Closes the dialog with the selected field values.
  /// Notes: Internal helper used within this file only.
  void _apply() {
    if (_selected == null) return;
    final r = _selected!;
    final result = <String, dynamic>{};
    if (_toggles['title'] == true && r.title != null) {
      result['title'] = r.title;
    }
    if (_toggles['titleJa'] == true && r.titleJa != null) {
      result['titleJa'] = r.titleJa;
    }
    if (_toggles['episodes'] == true && r.episodes != null) {
      result['endEpisode'] = r.episodes;
    }
    if (_toggles['firstAirDate'] == true && r.firstAirDate != null) {
      result['firstAirDate'] = r.firstAirDate;
    }
    if (_toggles['airDayOfWeek'] == true && r.airDayOfWeek != null) {
      result['airDayOfWeek'] = r.airDayOfWeek;
    }
    if (_toggles['airTime'] == true && r.airTime != null) {
      result['airTime'] = r.airTime;
    }
    // Auto-derive airDayOfWeek from firstAirDate if not provided by source
    if (_toggles['firstAirDate'] == true &&
        r.firstAirDate != null &&
        r.airDayOfWeek == null &&
        !result.containsKey('airDayOfWeek')) {
      result['airDayOfWeek'] = r.firstAirDate!.weekday; // 1=Mon..7=Sun
    }
    if (_toggles['notes'] == true && r.summary != null) {
      result['notes'] = r.summary;
    }
    if (_toggles['externalMeta'] == true) {
      final fetched = AnimeSearchService.toExternalMeta(r);
      // Fold into whatever another source already contributed instead of
      // replacing it, so applying a second result keeps the first one's fields.
      result['externalMeta'] =
          widget.currentExternalMeta?.mergedWith(fetched) ?? fetched;
    }
    if (_toggles['cover'] == true && _fetchedCoverPath != null) {
      result['coverImage'] = _fetchedCoverPath;
    }
    // Always set infoUrl from sourceUrl when applying search result
    if (r.sourceUrl != null && r.sourceUrl!.isNotEmpty) {
      result['infoUrl'] = r.sourceUrl;
    }
    Navigator.of(context).pop(result);
  }

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 40),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 520,
        child: _phase == _Phase.search
            ? _buildSearchView(l10n)
            : _buildPreviewView(l10n),
      ),
    );
  }

  // ──── Search view ────

  /// Purpose: Provide the internal build search view helper for this file.
  /// Inputs: `l10n`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _buildSearchView(AppLocalizations l10n) {
    return Column(
      children: [
        _buildHeader(l10n, showBack: false),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _queryController,
                  decoration: InputDecoration(
                    hintText: l10n.searchHint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _searching ? null : _search,
                child: Text(l10n.searchButton),
              ),
            ],
          ),
        ),
        if (_results.isNotEmpty) _buildResultToolbar(l10n),
        Expanded(child: _buildSearchResults(l10n)),
      ],
    );
  }

  /// Purpose: Build the sort/filter/group toolbar shown above the result list.
  /// Inputs: `l10n`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Only rendered once a
  /// search has produced results, so an empty dialog stays uncluttered.
  Widget _buildResultToolbar(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final visible = _visibleResults.length;
    final filtersActive =
        _hiddenSources.isNotEmpty || _onlyWithCover || _onlyWithAirDate;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.searchResultCount(visible, _results.length),
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(
              _groupBySource ? Icons.segment : Icons.view_list_outlined,
              size: 20,
            ),
            tooltip: l10n.searchGroupBySource,
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _groupBySource = !_groupBySource),
          ),
          PopupMenuButton<_SearchSort>(
            icon: const Icon(Icons.sort, size: 20),
            tooltip: l10n.searchSort,
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (context) => [
              for (final sort in _SearchSort.values)
                PopupMenuItem(value: sort, child: Text(_sortLabel(sort, l10n))),
            ],
          ),
          IconButton(
            icon: Icon(
              filtersActive ? Icons.filter_alt : Icons.filter_alt_outlined,
              size: 20,
            ),
            tooltip: l10n.searchFilter,
            visualDensity: VisualDensity.compact,
            onPressed: () => _showFilterSheet(l10n),
          ),
        ],
      ),
    );
  }

  /// Purpose: Provide the internal sort label helper for this file.
  /// Inputs: `sort`, `l10n`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String _sortLabel(_SearchSort sort, AppLocalizations l10n) {
    switch (sort) {
      case _SearchSort.relevance:
        return l10n.searchSortRelevance;
      case _SearchSort.firstAirDate:
        return l10n.searchSortAirDate;
      case _SearchSort.episodes:
        return l10n.searchSortEpisodes;
      case _SearchSort.source:
        return l10n.searchSortSource;
    }
  }

  /// Purpose: Show the source and field filters in a bottom sheet.
  /// Inputs: `l10n`.
  /// Returns: None.
  /// Side effects: Opens a modal sheet and mutates filter state as the user toggles.
  /// Notes: Internal helper used within this file only. The sheet drives the
  /// parent's state directly through `setState` so the list updates live.
  Future<void> _showFilterSheet(AppLocalizations l10n) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            void toggle(void Function() mutate) {
              setState(mutate);
              setSheetState(() {});
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.searchFilterSources,
                            style: Theme.of(sheetContext).textTheme.titleSmall,
                          ),
                        ),
                        TextButton(
                          onPressed: () => toggle(() {
                            _hiddenSources.clear();
                            _onlyWithCover = false;
                            _onlyWithAirDate = false;
                          }),
                          child: Text(l10n.searchFilterReset),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final source in _availableSources)
                          FilterChip(
                            label: Text(source),
                            selected: !_hiddenSources.contains(source),
                            onSelected: (selected) => toggle(() {
                              if (selected) {
                                _hiddenSources.remove(source);
                              } else {
                                _hiddenSources.add(source);
                              }
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _onlyWithCover,
                      title: Text(l10n.searchFilterWithCover),
                      onChanged: (v) => toggle(() => _onlyWithCover = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _onlyWithAirDate,
                      title: Text(l10n.searchFilterWithAirDate),
                      onChanged: (v) => toggle(() => _onlyWithAirDate = v),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Purpose: Provide the internal build search results helper for this file.
  /// Inputs: `l10n`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _buildSearchResults(AppLocalizations l10n) {
    if (_searching) {
      return _buildSearchProgress(l10n);
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return const SizedBox.shrink();
    }
    final visible = _visibleResults;
    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.searchNoMatchingResults,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }
    if (_groupBySource) {
      return _buildGroupedResults(l10n, visible);
    }
    return ListView.builder(
      itemCount: visible.length,
      padding: const EdgeInsets.only(bottom: 8),
      itemBuilder: (_, i) => _resultTile(l10n, visible[i]),
    );
  }

  /// Purpose: Show which sources have answered while a search is running.
  /// Inputs: `l10n`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. A search can take half
  /// a minute — each source has its own 10–15 second timeout, and sources that
  /// come back empty are queried again with titles harvested from the first
  /// round. A bare spinner over that is indistinguishable from a hang, so each
  /// source reports itself as it lands and the slow one is visible by name.
  Widget _buildSearchProgress(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final progress = _progress;
    if (progress == null || progress.total == 0) {
      return const Center(child: CircularProgressIndicator());
    }
    final label = progress.round >= 2
        ? l10n.searchProgressRound2(progress.done, progress.total)
        : l10n.searchProgressRound1(progress.done, progress.total);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(value: progress.fraction),
          const SizedBox(height: 12),
          Text(label, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final source in progress.sources)
                _sourceChip(l10n, theme, progress, source),
            ],
          ),
        ],
      ),
    );
  }

  /// Purpose: Render one source's state during a search.
  /// Inputs: `l10n`, `theme`, `progress`, `source`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. A source that threw and
  /// a source that legitimately found nothing look different here, because they
  /// mean different things to someone deciding whether to search again.
  Widget _sourceChip(
    AppLocalizations l10n,
    ThemeData theme,
    AnimeSearchProgress progress,
    String source,
  ) {
    final pending = progress.isPending(source);
    final failed = progress.failed.contains(source);
    final count = progress.counts[source];

    Widget leading;
    if (pending) {
      leading = const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (failed) {
      leading = Icon(
        Icons.error_outline,
        size: 14,
        color: theme.colorScheme.error,
      );
    } else {
      leading = const Icon(Icons.check, size: 14);
    }

    final trailing = pending
        ? ''
        : failed
        ? ' · ${l10n.searchSourceFailed}'
        : ' · ${l10n.searchSourceCount(count ?? 0)}';

    return Chip(
      avatar: leading,
      label: Text('$source$trailing', style: theme.textTheme.labelSmall),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  /// Purpose: Render the result list as one collapsible section per source.
  /// Inputs: `l10n`, `visible`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Sections keep the
  /// canonical source order rather than the current sort order, so the list
  /// does not reshuffle when the sort changes.
  Widget _buildGroupedResults(
    AppLocalizations l10n,
    List<AnimeSearchResult> visible,
  ) {
    final grouped = <String, List<AnimeSearchResult>>{};
    for (final r in visible) {
      grouped.putIfAbsent(r.source, () => []).add(r);
    }
    final sources = AnimeSearchSource.all
        .where(grouped.containsKey)
        .toList();
    return ListView.builder(
      itemCount: sources.length,
      padding: const EdgeInsets.only(bottom: 8),
      itemBuilder: (_, i) {
        final source = sources[i];
        final items = grouped[source]!;
        return ExpansionTile(
          initiallyExpanded: true,
          dense: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(
            source,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          trailing: Text(
            '${items.length}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          children: [for (final r in items) _resultTile(l10n, r)],
        );
      },
    );
  }

  /// Purpose: Build one row of the search result list.
  /// Inputs: `l10n`, `r`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. The title is clipped to
  /// one line; a long-press (or a hover tooltip on desktop) opens the full
  /// detail sheet, which is where untruncated titles live.
  Widget _resultTile(AppLocalizations l10n, AnimeSearchResult r) {
    final theme = Theme.of(context);
    final secondLine = _secondaryLine(l10n, r);
    return ListTile(
      leading: r.coverImageUrl != null
          ? SizedBox(
              width: 36,
              height: 50,
              child: Image.network(
                r.coverImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, e, s) =>
                    const Icon(Icons.image_not_supported, size: 20),
              ),
            )
          : const SizedBox(width: 36, child: Icon(Icons.movie_outlined)),
      title: Tooltip(
        message: r.allTitles.join('\n'),
        child: Text(
          r.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              r.source,
              if (r.titleJa != null && r.title != null) r.titleJa,
              if (r.episodes != null) l10n.searchEpisodesCount(r.episodes!),
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          if (secondLine != null)
            Text(
              secondLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      isThreeLine: secondLine != null,
      dense: true,
      onTap: () => _selectResult(r),
      onLongPress: () => _showResultDetails(l10n, r),
    );
  }

  /// Purpose: Compose the secondary metadata line shown under a result.
  /// Inputs: `l10n`, `r`.
  /// Returns: `String?` — `null` when the source supplied none of these fields.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String? _secondaryLine(AppLocalizations l10n, AnimeSearchResult r) {
    final parts = <String>[
      if (r.score != null)
        '★ ${r.score!.toStringAsFixed(1)}/${r.scoreMax.toStringAsFixed(0)}',
      if (r.format != null) r.format!,
      if (r.airDayOfWeek != null)
        [_dayName(r.airDayOfWeek!), if (r.airTime != null) r.airTime!].join(' '),
      if (r.airDayOfWeek == null && r.firstAirDate != null)
        DateFormat.yMd().format(r.firstAirDate!),
      if (r.studios.isNotEmpty) r.studios.first,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Purpose: Show every title and field a result carries, untruncated.
  /// Inputs: `l10n`, `r`.
  /// Returns: None.
  /// Side effects: Opens a modal sheet; copying writes to the system clipboard.
  /// Notes: Internal helper used within this file only. Titles are rendered as
  /// `SelectableText` so a name can be copied out even when it is too long to
  /// fit the list row that triggered this sheet.
  Future<void> _showResultDetails(
    AppLocalizations l10n,
    AnimeSearchResult r,
  ) async {
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            builder: (context, scrollController) => ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.searchDetailsTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Chip(
                      label: Text(r.source),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(l10n.searchAllTitles, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                for (final title in r.allTitles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: SelectableText(title)),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          tooltip: l10n.copyAction,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _copyToClipboard(l10n, title),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 24),
                ..._detailRows(l10n, r, theme),
                if (r.summary?.isNotEmpty == true) ...[
                  const Divider(height: 24),
                  SelectableText(
                    r.summary!,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Purpose: Build the labelled metadata rows for the result detail sheet.
  /// Inputs: `l10n`, `r`, `theme`.
  /// Returns: `List<Widget>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Fields the source did
  /// not supply are omitted rather than shown blank.
  List<Widget> _detailRows(
    AppLocalizations l10n,
    AnimeSearchResult r,
    ThemeData theme,
  ) {
    final rows = <(String, String)>[
      if (r.episodes != null) (l10n.animeEndEp, '${r.episodes}'),
      if (r.firstAirDate != null)
        (l10n.animeFirstAirDate, DateFormat.yMd().format(r.firstAirDate!)),
      if (r.endDate != null)
        (l10n.animeEndDate, DateFormat.yMd().format(r.endDate!)),
      if (r.airDayOfWeek != null)
        (l10n.animeAirDay, _dayName(r.airDayOfWeek!)),
      if (r.airTime != null) (l10n.animeAirTime, r.airTime!),
      if (r.format != null) (l10n.animeFormat, r.format!),
      if (r.status != null) (l10n.animeStatus, r.status!),
      if (r.durationMinutes != null)
        (l10n.animeDuration, l10n.animeDurationValue(r.durationMinutes!)),
      if (r.studios.isNotEmpty) (l10n.animeStudios, r.studios.join(', ')),
      if (r.genres.isNotEmpty) (l10n.animeGenres, r.genres.join(', ')),
      if (r.score != null)
        (
          l10n.animeExternalRatings,
          '${r.score!.toStringAsFixed(1)} / ${r.scoreMax.toStringAsFixed(0)}'
              '${r.scoreVotes != null ? ' · ${l10n.animeExternalVotes(r.scoreVotes!)}' : ''}'
              '${r.scoreRank != null ? ' · ${l10n.animeExternalRank(r.scoreRank!)}' : ''}',
        ),
      if (r.sourceUrl != null) (l10n.animeInfoUrl, r.sourceUrl!),
    ];

    return [
      for (final (label, value) in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: SelectableText(
                  value,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
    ];
  }

  /// Purpose: Copy one value to the clipboard and confirm it to the user.
  /// Inputs: `l10n`, `value`.
  /// Returns: None.
  /// Side effects: Writes to the system clipboard and shows a snack bar.
  /// Notes: Internal helper used within this file only.
  Future<void> _copyToClipboard(AppLocalizations l10n, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.copiedToClipboard)));
  }

  // ──── Preview view ────

  /// Purpose: Provide the internal build preview view helper for this file.
  /// Inputs: `l10n`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _buildPreviewView(AppLocalizations l10n) {
    final r = _selected;
    if (r == null) return const SizedBox.shrink();

    return Column(
      children: [
        _buildHeader(l10n, showBack: true),
        const Divider(height: 1),
        // Source badge
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Chip(
                label: Text(r.source),
                avatar: const Icon(Icons.public, size: 16),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 20),
                tooltip: l10n.searchDetailsTitle,
                visualDensity: VisualDensity.compact,
                onPressed: () => _showResultDetails(l10n, r),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildFieldList(l10n, r)),
        const Divider(height: 1),
        // Buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _toggles.values.any((v) => v) ? _apply : null,
                child: Text(l10n.searchApply),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Purpose: Provide the internal build field list helper for this file.
  /// Inputs: `l10n`, `r`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _buildFieldList(AppLocalizations l10n, AnimeSearchResult r) {
    final externalCount = _externalMetaFieldCount(r);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        if (r.title?.isNotEmpty == true)
          _fieldTile('title', l10n.animeTitle, widget.currentTitle, r.title!),
        if (r.titleJa?.isNotEmpty == true)
          _fieldTile(
            'titleJa',
            l10n.animeTitleJa,
            widget.currentTitleJa,
            r.titleJa!,
          ),
        if (r.episodes != null)
          _fieldTile(
            'episodes',
            l10n.animeEndEp,
            widget.currentEndEp?.toString(),
            r.episodes.toString(),
          ),
        if (r.firstAirDate != null)
          _fieldTile(
            'firstAirDate',
            l10n.animeFirstAirDate,
            widget.currentFirstAirDate != null
                ? DateFormat.yMd().format(widget.currentFirstAirDate!)
                : null,
            DateFormat.yMd().format(r.firstAirDate!),
          ),
        if (r.airDayOfWeek != null)
          _fieldTile(
            'airDayOfWeek',
            l10n.animeAirDay,
            widget.currentAirDay != null
                ? _dayName(widget.currentAirDay!)
                : null,
            _dayName(r.airDayOfWeek!),
          ),
        if (r.airTime != null)
          _fieldTile(
            'airTime',
            l10n.animeAirTime,
            widget.currentAirTime,
            r.airTime!,
          ),
        if (r.summary?.isNotEmpty == true)
          _fieldTile(
            'notes',
            l10n.animeNotes,
            _truncate(widget.currentNotes, 50),
            _truncate(r.summary, 100)!,
          ),
        if (externalCount > 0)
          _fieldTile(
            'externalMeta',
            l10n.searchExternalMeta,
            widget.currentExternalMeta?.hasAnyData == true
                ? l10n.animeExternalMeta
                : null,
            l10n.searchExternalMetaValue(externalCount, r.source),
          ),
        if (externalCount > 0) _buildExternalMetaSummary(l10n, r),
        // Cover image section
        if (r.coverImageUrl != null) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Checkbox(
                  value: _toggles['cover'] ?? false,
                  onChanged: _fetchedCoverPath != null
                      ? (v) => setState(() => _toggles['cover'] = v ?? false)
                      : null,
                ),
                Expanded(
                  child: Text(
                    l10n.searchCoverImage,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (_fetchingCover)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (_fetchedCoverPath == null)
                  TextButton.icon(
                    onPressed: _fetchCover,
                    icon: const Icon(Icons.download, size: 16),
                    label: Text(l10n.searchFetchCover),
                  ),
              ],
            ),
          ),
          if (_coverPreview != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  if (widget.currentCoverImage != null) ...[
                    _coverColumn(
                      l10n.searchCurrent,
                      FutureBuilder<File>(
                        future: ImageService.resolve(widget.currentCoverImage!),
                        builder: (context, snap) {
                          if (snap.hasData && snap.data!.existsSync()) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.file(
                                snap.data!,
                                width: 55,
                                height: 77,
                                fit: BoxFit.cover,
                              ),
                            );
                          }
                          return const SizedBox(width: 55, height: 77);
                        },
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward, size: 16),
                    ),
                  ],
                  _coverColumn(
                    l10n.searchFetched,
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image(
                        image: _coverPreview!,
                        width: 55,
                        height: 77,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  /// Purpose: Show the metadata that the external-metadata checkbox would apply.
  /// Inputs: `l10n`, `r`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Read-only — the single
  /// checkbox above it governs whether any of it is written.
  Widget _buildExternalMetaSummary(AppLocalizations l10n, AnimeSearchResult r) {
    final theme = Theme.of(context);
    final chips = <String>[
      if (r.format != null) r.format!,
      if (r.status != null) r.status!,
      if (r.durationMinutes != null)
        l10n.animeDurationValue(r.durationMinutes!),
      ...r.studios,
      ...r.genres,
      if (r.score != null)
        '★ ${r.score!.toStringAsFixed(1)}/${r.scoreMax.toStringAsFixed(0)}',
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 0, 16, 8),
      child: Wrap(
        spacing: 6,
        runSpacing: -6,
        children: [
          for (final chip in chips)
            Chip(
              label: Text(chip, style: theme.textTheme.labelSmall),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }

  /// Purpose: Provide the internal cover column helper for this file.
  /// Inputs: `label`, `image`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _coverColumn(String label, Widget image) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        image,
      ],
    );
  }

  /// Purpose: Provide the internal field tile helper for this file.
  /// Inputs: `key`, `label`, `current`, `fetched`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _fieldTile(String key, String label, String? current, String fetched) {
    final l10n = AppLocalizations.of(context)!;
    return CheckboxListTile(
      value: _toggles[key] ?? false,
      onChanged: (v) => setState(() => _toggles[key] = v ?? false),
      title: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (current != null && current.isNotEmpty)
            Text(
              '${l10n.searchCurrent}: $current',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          Text(
            '${l10n.searchFetched}: $fetched',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  // ──── Header ────

  /// Purpose: Provide the internal build header helper for this file.
  /// Inputs: `l10n`, `showBack`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _buildHeader(AppLocalizations l10n, {required bool showBack}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () => setState(() => _phase = _Phase.search),
              visualDensity: VisualDensity.compact,
            ),
          Icon(
            Icons.travel_explore,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.searchAnimeInfo,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  // ──── Helpers ────

  /// Purpose: Provide the internal day name helper for this file.
  /// Inputs: `dow`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String _dayName(int dow) {
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

  /// Purpose: Provide the internal truncate helper for this file.
  /// Inputs: `text`, `maxLen`.
  /// Returns: `String?`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String? _truncate(String? text, int maxLen) {
    if (text == null) return null;
    return text.length > maxLen ? '${text.substring(0, maxLen)}...' : text;
  }
}
