import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/image_service.dart';
import '../../../shared/services/share_service.dart';
import '../../../shared/widgets/delete_confirm.dart';
import '../models/anime.dart';
import '../services/anime_storage.dart';

class AnimeDetailPage extends StatefulWidget {
  final String animeId;
  const AnimeDetailPage({super.key, required this.animeId});

  @override
  State<AnimeDetailPage> createState() => _AnimeDetailPageState();
}

class _AnimeDetailPageState extends State<AnimeDetailPage> {
  Anime? _anime;
  String? _prevSeasonId;
  String? _nextSeasonId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await AnimeStorage.load();
    final found = data.animeList
        .where((a) => a.id == widget.animeId)
        .firstOrNull;
    if (found != null && mounted) {
      // Find prev/next season: same title, different season
      final title = found.displayTitle;
      final sameTitleAnime = data.animeList
          .where((a) => a.id != found.id && a.displayTitle == title)
          .toList();
      // Sort by season string
      sameTitleAnime.sort((a, b) => a.season.compareTo(b.season));
      String? prev, next;
      for (final a in sameTitleAnime) {
        if (a.season.compareTo(found.season) < 0) {
          prev = a.id; // keep updating to get the closest previous
        }
      }
      for (final a in sameTitleAnime) {
        if (a.season.compareTo(found.season) > 0) {
          next = a.id;
          break; // first one after is the closest next
        }
      }
      setState(() {
        _anime = found;
        _prevSeasonId = prev;
        _nextSeasonId = next;
      });
    } else if (mounted) {
      setState(() => _anime = found);
    }
  }

  Future<void> _toggleEpisode(int ep) async {
    if (_anime == null) return;
    final current =
        _anime!.episodeStatuses[ep] ?? EpisodeStatus.unwatched;
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

  /// Shift episode [ep] and all subsequent episodes by [delta] weeks.
  /// delta > 0 = delay (push back), delta < 0 = advance (pull forward).
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

  /// Reset all episode week offsets to original schedule based on firstAirDate.
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

  Future<void> _delete() async {
    if (_anime == null) return;
    final ok = await confirmDelete(context, _anime!.displayTitle);
    if (!ok) return;
    await AnimeStorage.deleteAnime(_anime!.id);
    if (mounted) context.pop();
  }

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
      body: ListView(
        children: [
          // Cover image (portrait)
          if (anime.coverImage != null)
            Padding(
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
                          height: 260,
                          width: 180,
                          fit: BoxFit.cover,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),

          // Info section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    if (anime.watchUrl != null)
                      ActionChip(
                        avatar: const Icon(Icons.open_in_browser, size: 16),
                        label: Text(l10n.animeOpenUrl),
                        onPressed: () => launchUrl(
                          Uri.parse(anime.watchUrl!),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: totalEps > 0 ? watchedCount / totalEps : 0,
                ),
                const SizedBox(height: 4),
                Text(
                  '$watchedCount / $totalEps ${l10n.animeEpisodes}',
                  style: theme.textTheme.bodySmall,
                ),
                if (anime.notes != null && anime.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    anime.notes!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],

                // Prev/Next season navigation
                if (_prevSeasonId != null || _nextSeasonId != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_prevSeasonId != null)
                        TextButton.icon(
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: Text(l10n.animePrevSeason),
                          onPressed: () => context.go('/anime/detail/$_prevSeasonId'),
                        ),
                      if (_prevSeasonId != null && _nextSeasonId != null)
                        const SizedBox(width: 16),
                      if (_nextSeasonId != null)
                        TextButton.icon(
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: Text(l10n.animeNextSeason),
                          onPressed: () => context.go('/anime/detail/$_nextSeasonId'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),

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
                  child: Text(anime.isCompleted
                      ? l10n.animeMarkAllUnwatched
                      : l10n.animeMarkAllWatched),
                ),
              ],
            ),
          ),
          ...List.generate(anime.endEpisode != null ? anime.endEpisode! - anime.startEpisode + 1 : 0, (i) {
            final ep = anime.startEpisode + i;
            final status =
                anime.episodeStatuses[ep] ?? EpisodeStatus.unwatched;
            final airDate = anime.getEpisodeCalendarDate(ep);
            final airStr =
                airDate != null ? DateFormat.MMMd().format(airDate) : '';

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
          }),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _toggleAllWatched() async {
    if (_anime == null || _anime!.endEpisode == null) return;
    final allWatched = _anime!.isCompleted;
    final newStatuses = <int, EpisodeStatus>{};
    for (var ep = _anime!.startEpisode; ep <= _anime!.endEpisode!; ep++) {
      newStatuses[ep] =
          allWatched ? EpisodeStatus.unwatched : EpisodeStatus.watched;
    }
    final updated = _anime!.copyWith(
      episodeStatuses: newStatuses,
      modifiedAt: DateTime.now().toUtc(),
    );
    await AnimeStorage.addOrUpdate(updated);
    await _load();
  }

  Widget _buildAbandonOrResume(Anime anime, AppLocalizations l10n) {
    final statuses = anime.episodeStatuses;
    final hasUnwatched = Iterable.generate(
      anime.endEpisode! - anime.startEpisode + 1,
      (i) => anime.startEpisode + i,
    ).any((ep) =>
        (statuses[ep] ?? EpisodeStatus.unwatched) == EpisodeStatus.unwatched);
    final hasSkipped = statuses.values
        .any((s) => s == EpisodeStatus.skippedThisWeek);

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

  String _dayName(int? dow, AppLocalizations l10n) {
    if (dow == null) return '?';
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dow.clamp(1, 7)];
  }

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
