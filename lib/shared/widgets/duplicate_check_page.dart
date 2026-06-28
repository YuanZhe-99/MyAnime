import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/anime/models/anime.dart';
import '../../features/anime/services/anime_storage.dart';
import '../../l10n/app_localizations.dart';
import '../services/duplicate_service.dart';
import '../services/file_open_service.dart';
import '../services/image_service.dart';

/// Purpose: Display and resolve duplicate anime groups.
/// Inputs: None.
/// Returns: None.
/// Side effects: Reads and mutates anime storage.
/// Notes: Scans the full anime library for duplicates and lets the user keep,
/// merge, or delete redundant records group by group.
class DuplicateCheckPage extends StatefulWidget {
  /// Purpose: Create a duplicate check page instance.
  /// Inputs: None.
  /// Returns: A new `DuplicateCheckPage` instance.
  /// Side effects: None.
  /// Notes: None.
  const DuplicateCheckPage({super.key});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  State<DuplicateCheckPage> createState() => _DuplicateCheckPageState();
}

class _DuplicateCheckPageState extends State<DuplicateCheckPage> {
  List<Anime> _allAnime = [];
  DuplicateResult? _result;
  bool _loading = true;

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

  /// Purpose: Provide the internal load helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  Future<void> _load() async {
    final data = await AnimeStorage.load();
    if (!mounted) return;
    setState(() {
      _allAnime = data.animes;
      _result = DuplicateService.detect(_allAnime);
      _loading = false;
    });
  }

  /// Purpose: Provide the internal resolve group helper for this file.
  /// Inputs: `group`, `keepIndex`, `merge`.
  /// Returns: None.
  /// Side effects: Mutates storage, removing redundant records and optionally
  /// merging fields from deleted records into the kept one.
  /// Notes: Internal helper used within this file only. When `merge` is true,
  /// the kept record absorbs fields from the others before they are deleted.
  Future<void> _resolveGroup(
    DuplicateGroup group,
    int keepIndex, {
    required bool merge,
  }) async {
    final kept = group.animes[keepIndex];
    final others = [
      for (var i = 0; i < group.animes.length; i++)
        if (i != keepIndex) group.animes[i],
    ];

    if (merge) {
      final merged = DuplicateService.merge(kept, others);
      await AnimeStorage.addOrUpdate(merged);
    }

    await FileOpenService.deleteAnimeByIds(others.map((a) => a.id));
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.duplicateResolved)),
      );
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.duplicateCheckTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _result == null || !_result!.hasDuplicates
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.duplicateCheckEmpty,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 80),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    l10n.duplicateCheckFound(_result!.groups.length),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                ...List.generate(_result!.groups.length, (gi) {
                  final group = _result!.groups[gi];
                  return _buildGroupCard(group, gi, _result!.groups.length, theme, l10n);
                }),
              ],
            ),
    );
  }

  /// Purpose: Provide the internal build group card helper for this file.
  /// Inputs: `group`, `index`, `total`, `theme`, `l10n`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _buildGroupCard(
    DuplicateGroup group,
    int index,
    int total,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.duplicateGroupLabel(index + 1, total, group.label(l10n)),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(group.animes.length, (i) {
              return _buildAnimeTile(
                group,
                i,
                theme,
                l10n,
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Purpose: Provide the internal build anime tile helper for this file.
  /// Inputs: `group`, `index`, `theme`, `l10n`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Each tile offers keep,
  /// merge-all, and delete-others actions.
  Widget _buildAnimeTile(
    DuplicateGroup group,
    int index,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final anime = group.animes[index];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _buildCover(anime),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                await context.push('/anime/detail/${anime.id}');
                _load();
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    anime.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    [
                      anime.season,
                      if (anime.firstAirDate != null)
                        '${anime.firstAirDate!.year}-${anime.firstAirDate!.month.toString().padLeft(2, '0')}',
                      if (anime.infoUrl != null) anime.infoUrl!,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'ID: ${anime.id.substring(0, 8)}...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => _resolveGroup(group, index, merge: false),
                child: Text(l10n.duplicateKeepFirst),
              ),
              TextButton(
                onPressed: () => _resolveGroup(group, index, merge: true),
                child: Text(l10n.duplicateMergeAll),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Purpose: Provide the internal build cover helper for this file.
  /// Inputs: `anime`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _buildCover(Anime anime) {
    if (anime.coverImage == null) {
      return SizedBox(
        width: 40,
        height: 56,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.movie, size: 20),
        ),
      );
    }
    return FutureBuilder<File>(
      future: ImageService.resolve(anime.coverImage!),
      builder: (context, snap) {
        if (snap.hasData && snap.data!.existsSync()) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(
              snap.data!,
              width: 40,
              height: 56,
              fit: BoxFit.cover,
            ),
          );
        }
        return SizedBox(
          width: 40,
          height: 56,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.movie, size: 20),
          ),
        );
      },
    );
  }
}
