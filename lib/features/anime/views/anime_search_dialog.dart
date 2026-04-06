import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/image_service.dart';
import '../services/anime_search_service.dart';

/// Shows the anime search dialog.
/// Returns a map of field names → values to apply, or null if cancelled.
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
    ),
  );
}

enum _Phase { search, preview }

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
  });

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  late final TextEditingController _queryController;

  _Phase _phase = _Phase.search;

  // Search phase
  List<AnimeSearchResult> _results = [];
  bool _searching = false;
  String? _error;

  // Preview phase
  AnimeSearchResult? _selected;
  final Map<String, bool> _toggles = {};
  bool _fetchingCover = false;
  String? _fetchedCoverPath;
  ImageProvider? _coverPreview;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery ?? '');
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _error = null;
      _results = [];
    });

    try {
      final results = await AnimeSearchService.searchAll(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
        if (results.isEmpty) {
          _error = AppLocalizations.of(context)!.searchNoResults;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = e.toString();
      });
    }
  }

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
      // Cover is off by default — requires explicit fetch
      if (result.coverImageUrl != null) _toggles['cover'] = false;
    });
  }

  Future<void> _fetchCover() async {
    if (_selected?.coverImageUrl == null) return;
    setState(() => _fetchingCover = true);
    try {
      final path =
          await ImageService.saveImageFromUrl(_selected!.coverImageUrl!);
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

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
    if (_toggles['cover'] == true && _fetchedCoverPath != null) {
      result['coverImage'] = _fetchedCoverPath;
    }
    // Always set infoUrl from sourceUrl when applying search result
    if (r.sourceUrl != null && r.sourceUrl!.isNotEmpty) {
      result['infoUrl'] = r.sourceUrl;
    }
    Navigator.of(context).pop(result);
  }

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
                        horizontal: 12, vertical: 10),
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
        Expanded(child: _buildSearchResults(l10n)),
      ],
    );
  }

  Widget _buildSearchResults(AppLocalizations l10n) {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
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
    return ListView.builder(
      itemCount: _results.length,
      padding: const EdgeInsets.only(bottom: 8),
      itemBuilder: (_, i) {
        final r = _results[i];
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
              : const SizedBox(
                  width: 36,
                  child: Icon(Icons.movie_outlined),
                ),
          title: Text(
            r.title ?? r.titleJa ?? '?',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            [
              r.source,
              if (r.titleJa != null && r.title != null) r.titleJa,
              if (r.episodes != null) '${r.episodes} eps',
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          dense: true,
          onTap: () => _selectResult(r),
        );
      },
    );
  }

  // ──── Preview view ────

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
                onPressed:
                    _toggles.values.any((v) => v) ? _apply : null,
                child: Text(l10n.searchApply),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFieldList(AppLocalizations l10n, AnimeSearchResult r) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        if (r.title?.isNotEmpty == true)
          _fieldTile('title', l10n.animeTitle, widget.currentTitle, r.title!),
        if (r.titleJa?.isNotEmpty == true)
          _fieldTile(
              'titleJa', l10n.animeTitleJa, widget.currentTitleJa, r.titleJa!),
        if (r.episodes != null)
          _fieldTile('episodes', l10n.animeEndEp,
              widget.currentEndEp?.toString(), r.episodes.toString()),
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
              'airTime', l10n.animeAirTime, widget.currentAirTime, r.airTime!),
        if (r.summary?.isNotEmpty == true)
          _fieldTile(
            'notes',
            l10n.animeNotes,
            _truncate(widget.currentNotes, 50),
            _truncate(r.summary, 100)!,
          ),
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
                      ? (v) =>
                          setState(() => _toggles['cover'] = v ?? false)
                      : null,
                ),
                Expanded(
                  child: Text(l10n.searchCoverImage,
                      style: Theme.of(context).textTheme.titleSmall),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  if (widget.currentCoverImage != null) ...[
                    _coverColumn(
                      l10n.searchCurrent,
                      FutureBuilder<File>(
                        future:
                            ImageService.resolve(widget.currentCoverImage!),
                        builder: (context, snap) {
                          if (snap.hasData && snap.data!.existsSync()) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.file(snap.data!,
                                  width: 55, height: 77, fit: BoxFit.cover),
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

  Widget _coverColumn(String label, Widget image) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        image,
      ],
    );
  }

  Widget _fieldTile(
      String key, String label, String? current, String fetched) {
    final l10n = AppLocalizations.of(context)!;
    return CheckboxListTile(
      value: _toggles[key] ?? false,
      onChanged: (v) => setState(() => _toggles[key] = v ?? false),
      title: Text(label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600)),
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
          Icon(Icons.travel_explore,
              color: Theme.of(context).colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(l10n.searchAnimeInfo,
                style: Theme.of(context).textTheme.titleMedium),
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

  String _dayName(int dow) {
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dow.clamp(1, 7)];
  }

  String? _truncate(String? text, int maxLen) {
    if (text == null) return null;
    return text.length > maxLen ? '${text.substring(0, maxLen)}...' : text;
  }
}
