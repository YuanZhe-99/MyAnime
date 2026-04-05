import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/image_service.dart';
import '../../../shared/utils/jst_time.dart';
import '../models/anime.dart';
import '../services/anime_storage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime _focusedDay = JstTime.today();
  DateTime? _selectedDay;
  List<Anime> _allAnime = [];
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = JstTime.today();
    _load();
  }

  Future<void> _load() async {
    final data = await AnimeStorage.load();
    if (mounted) setState(() => _allAnime = data.animeList);
  }

  /// Get anime episodes airing on a specific day.
  List<_AiringEpisode> _getEventsForDay(DateTime day) {
    final events = <_AiringEpisode>[];
    final dayOnly = DateTime(day.year, day.month, day.day);
    for (final anime in _allAnime) {
      final lastEp = anime.endEpisode ?? anime.startEpisode;
      for (var ep = anime.startEpisode; ep <= lastEp; ep++) {
        final calDate = anime.getEpisodeCalendarDate(ep);
        if (calDate != null && calDate == dayOnly) {
          events.add(_AiringEpisode(anime: anime, episode: ep));
        }
      }
    }
    return events;
  }

  /// Get the earliest unwatched episode per anime, sorted by air date.
  List<_AiringEpisode> _getUnwatchedEpisodes() {
    final episodes = <_AiringEpisode>[];
    for (final anime in _allAnime) {
      final lastEp = anime.endEpisode ?? anime.startEpisode;
      for (var ep = anime.startEpisode; ep <= lastEp; ep++) {
        final status = anime.episodeStatuses[ep] ?? EpisodeStatus.unwatched;
        if (status == EpisodeStatus.unwatched) {
          final airDate = anime.getEpisodeAirDate(ep);
          if (airDate != null && !airDate.isAfter(JstTime.now())) {
            episodes.add(_AiringEpisode(anime: anime, episode: ep));
          }
          break; // only the earliest unwatched episode per anime
        }
      }
    }
    episodes.sort((a, b) {
      final aDate = a.anime.getEpisodeAirDate(a.episode);
      final bDate = b.anime.getEpisodeAirDate(b.episode);
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });
    return episodes;
  }

  Future<void> _toggleWatched(_AiringEpisode ep) async {
    final current =
        ep.anime.episodeStatuses[ep.episode] ?? EpisodeStatus.unwatched;
    final newStatus = current == EpisodeStatus.watched
        ? EpisodeStatus.unwatched
        : EpisodeStatus.watched;
    final updated = ep.anime.copyWith(
      episodeStatuses: Map.of(ep.anime.episodeStatuses)
        ..[ep.episode] = newStatus,
      modifiedAt: DateTime.now().toUtc(),
    );
    await AnimeStorage.addOrUpdate(updated);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final selectedEvents =
        _selectedDay != null ? _getEventsForDay(_selectedDay!) : <_AiringEpisode>[];
    // Sort: skipped episodes go to the end
    selectedEvents.sort((a, b) {
      final aSkipped = (a.anime.episodeStatuses[a.episode] ?? EpisodeStatus.unwatched) ==
          EpisodeStatus.skippedThisWeek;
      final bSkipped = (b.anime.episodeStatuses[b.episode] ?? EpisodeStatus.unwatched) ==
          EpisodeStatus.skippedThisWeek;
      if (aSkipped != bSkipped) return aSkipped ? 1 : -1;
      return 0;
    });
    final unwatched = _getUnwatchedEpisodes();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            // Calendar
            TableCalendar<_AiringEpisode>(
              firstDay: DateTime(2020),
              lastDay: DateTime(2030),
              focusedDay: _focusedDay,
              currentDay: JstTime.today(),
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                setState(() => _calendarFormat = format);
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              eventLoader: _getEventsForDay,
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  if (events.isEmpty) return null;
                  final allWatched = events.every((ep) {
                    final s = ep.anime.episodeStatuses[ep.episode] ??
                        EpisodeStatus.unwatched;
                    return s == EpisodeStatus.watched;
                  });
                  return Positioned(
                    bottom: 1,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: allWatched
                            ? theme.colorScheme.outlineVariant
                            : theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              ),
              calendarStyle: CalendarStyle(
                markersMaxCount: 1,
                markerDecoration: const BoxDecoration(),
                todayDecoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  l10n.homeCalendarJst,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),

            // Selected day episodes
            if (selectedEvents.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  l10n.homeAiringOn(
                      DateFormat.MMMd().format(_selectedDay!)),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              ...selectedEvents.map((ep) => _buildEpisodeTile(ep, theme, l10n)),
            ],

            // Unwatched section
            if (unwatched.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  l10n.homeUnwatched(unwatched.length),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
              ...unwatched.map((ep) => _buildEpisodeTile(ep, theme, l10n)),
            ],

            if (selectedEvents.isEmpty && unwatched.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    l10n.homeEmpty,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/anime/edit');
          await _load();
        },
        tooltip: l10n.animeAdd,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEpisodeTile(
      _AiringEpisode ep, ThemeData theme, AppLocalizations l10n) {
    final status =
        ep.anime.episodeStatuses[ep.episode] ?? EpisodeStatus.unwatched;
    final isWatched = status == EpisodeStatus.watched;
    final isSkipped = status == EpisodeStatus.skippedThisWeek;
    final airDate = ep.anime.getEpisodeAirDate(ep.episode);
    final airStr = airDate != null ? DateFormat.MMMd().format(airDate) : '';

    return Opacity(
      opacity: isSkipped ? 0.5 : 1.0,
      child: ListTile(
        leading: ep.anime.coverImage != null
            ? FutureBuilder<File>(
                future: ImageService.resolve(ep.anime.coverImage!),
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
          ep.anime.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text('${l10n.animeEpisodeShort(ep.episode)}  $airStr'),
            if (isSkipped) ...[
              const SizedBox(width: 6),
              Icon(Icons.skip_next, size: 16, color: theme.colorScheme.tertiary),
              const SizedBox(width: 2),
              Text(l10n.animeSkipped,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                )),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ep.anime.watchUrl != null)
              IconButton(
                icon: Icon(Icons.open_in_browser,
                    color: theme.colorScheme.tertiary),
                tooltip: l10n.animeOpenUrl,
                onPressed: () => launchUrl(
                  Uri.parse(ep.anime.watchUrl!),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            IconButton(
              icon: Icon(
                isSkipped
                    ? Icons.skip_next
                    : isWatched
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                color: isSkipped
                    ? theme.colorScheme.tertiary
                    : isWatched
                        ? theme.colorScheme.primary
                        : null,
              ),
              onPressed: () => _toggleWatched(ep),
            ),
          ],
        ),
        onTap: () async {
          await context.push('/anime/detail/${ep.anime.id}');
          await _load();
        },
      ),
    );
  }
}

class _AiringEpisode {
  final Anime anime;
  final int episode;
  const _AiringEpisode({required this.anime, required this.episode});
}
