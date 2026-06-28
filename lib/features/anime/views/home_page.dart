import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/providers/app_settings.dart';
import '../../../shared/widgets/import_bundle_dialog.dart';
import '../../../shared/services/image_service.dart';
import '../../../shared/utils/calendar_preferences.dart';
import '../../../shared/utils/jst_time.dart';
import '../models/anime.dart';
import '../services/anime_storage.dart';

class HomePage extends ConsumerStatefulWidget {
  /// Purpose: Create a home page instance.
  /// Inputs: None.
  /// Returns: A new `HomePage` instance.
  /// Side effects: None.
  /// Notes: None.
  const HomePage({super.key});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  DateTime? _focusedDay;
  DateTime? _selectedDay;
  List<Anime> _allAnime = [];
  CalendarFormat _calendarFormat = CalendarFormat.month;

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
    if (mounted) setState(() => _allAnime = data.animeList);
  }

  /// Purpose: Collect airing episodes scheduled for the requested calendar day.
  /// Inputs: `day`, `timeBasis`.
  /// Returns: `List<_AiringEpisode>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  List<_AiringEpisode> _getEventsForDay(
    DateTime day,
    HomeCalendarTimeBasis timeBasis,
  ) {
    final events = <_AiringEpisode>[];
    final dayOnly = DateTime(day.year, day.month, day.day);
    for (final anime in _allAnime) {
      final lastEp = anime.endEpisode ?? anime.startEpisode;
      for (var ep = anime.startEpisode; ep <= lastEp; ep++) {
        final calDate = _getEpisodeCalendarDate(anime, ep, timeBasis);
        if (calDate != null && calDate == dayOnly) {
          events.add(_AiringEpisode(anime: anime, episode: ep));
        }
      }
    }
    return events;
  }

  /// Purpose: Return the current date for the selected home calendar time basis.
  /// Inputs: `timeBasis`.
  /// Returns: `DateTime`.
  /// Side effects: None.
  /// Notes: The returned value is date-only in either JST or local time.
  DateTime _today(HomeCalendarTimeBasis timeBasis) {
    return switch (timeBasis) {
      HomeCalendarTimeBasis.jst => JstTime.today(),
      HomeCalendarTimeBasis.local => JstTime.localToday(),
    };
  }

  /// Purpose: Return the calendar date for an episode under the selected home calendar time basis.
  /// Inputs: `anime`, `episode`, `timeBasis`.
  /// Returns: `DateTime?`.
  /// Side effects: None.
  /// Notes: Local mode converts episode air timestamps to the device timezone; all-at-once releases keep their release date.
  DateTime? _getEpisodeCalendarDate(
    Anime anime,
    int episode,
    HomeCalendarTimeBasis timeBasis,
  ) {
    if (timeBasis == HomeCalendarTimeBasis.jst) {
      return anime.getEpisodeCalendarDate(episode);
    }

    if (anime.effectiveType == AnimeType.allAtOnce) {
      return anime.getEpisodeCalendarDate(episode);
    }

    final airDate = anime.getEpisodeAirDate(episode);
    if (airDate == null) return anime.getEpisodeCalendarDate(episode);
    final local = JstTime.toLocal(airDate);
    return DateTime(local.year, local.month, local.day);
  }

  /// Purpose: Return the display air date for an episode under the selected home calendar time basis.
  /// Inputs: `anime`, `episode`, `timeBasis`.
  /// Returns: `DateTime?`.
  /// Side effects: None.
  /// Notes: The anime model still calculates the source timestamp in Japan time; all-at-once releases keep their release date.
  DateTime? _getEpisodeDisplayAirDate(
    Anime anime,
    int episode,
    HomeCalendarTimeBasis timeBasis,
  ) {
    if (anime.effectiveType == AnimeType.allAtOnce) {
      return anime.getEpisodeCalendarDate(episode);
    }

    final airDate = anime.getEpisodeAirDate(episode);
    if (airDate == null) return null;
    return timeBasis == HomeCalendarTimeBasis.local
        ? JstTime.toLocal(airDate)
        : airDate;
  }

  /// Purpose: Build the earliest unwatched aired episode for each anime and sort them by air date.
  /// Inputs: None.
  /// Returns: `List<_AiringEpisode>`.
  /// Side effects: None.
  /// Notes: Keeps the visible list focused on the next episode to watch per anime.
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

  /// Purpose: Count all aired unwatched episodes across every anime.
  /// Inputs: None.
  /// Returns: `int`.
  /// Side effects: None.
  /// Notes: Used for summary text while the visible list still shows one row per anime.
  int _countUnwatchedAiredEpisodes() {
    var count = 0;
    final now = JstTime.now();
    for (final anime in _allAnime) {
      final lastEp = anime.endEpisode ?? anime.startEpisode;
      for (var ep = anime.startEpisode; ep <= lastEp; ep++) {
        final status = anime.episodeStatuses[ep] ?? EpisodeStatus.unwatched;
        if (status != EpisodeStatus.unwatched) continue;

        final airDate = anime.getEpisodeAirDate(ep);
        if (airDate != null && !airDate.isAfter(now)) {
          count++;
        }
      }
    }
    return count;
  }

  /// Purpose: Provide the internal toggle watched helper for this file.
  /// Inputs: `ep`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Show add/import choices and open the created or imported anime.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Shows dialogs, navigates, imports files, and reloads anime data.
  /// Notes: Internal helper used within this file only.
  Future<void> _showAddOptions() async {
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
      }
    } else {
      final result = await showImportBundleFlow(context);
      await _load();
      if (result != null &&
          result.importedIds.isNotEmpty &&
          mounted) {
        await context.push('/anime/detail/${result.importedIds.first}');
        await _load();
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
    final settings = ref.watch(appSettingsProvider);
    final calendarToday = _today(settings.homeCalendarTimeBasis);
    final focusedDay = _focusedDay ?? calendarToday;
    final selectedDay = _selectedDay ?? calendarToday;
    final selectedEvents = _getEventsForDay(
      selectedDay,
      settings.homeCalendarTimeBasis,
    );
    // Sort: skipped episodes go to the end
    selectedEvents.sort((a, b) {
      final aSkipped =
          (a.anime.episodeStatuses[a.episode] ?? EpisodeStatus.unwatched) ==
          EpisodeStatus.skippedThisWeek;
      final bSkipped =
          (b.anime.episodeStatuses[b.episode] ?? EpisodeStatus.unwatched) ==
          EpisodeStatus.skippedThisWeek;
      if (aSkipped != bSkipped) return aSkipped ? 1 : -1;
      return 0;
    });
    final unwatched = _getUnwatchedEpisodes();
    final unwatchedEpisodeCount = _countUnwatchedAiredEpisodes();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            // Calendar
            TableCalendar<_AiringEpisode>(
              firstDay: DateTime(2020),
              lastDay: DateTime(2030),
              focusedDay: focusedDay,
              currentDay: calendarToday,
              locale: _calendarDateLocale(settings, l10n),
              startingDayOfWeek: _startingDayOfWeek(
                settings.effectiveWeekStartDay,
              ),
              availableCalendarFormats: {
                CalendarFormat.month: l10n.calendarFormatMonth,
                CalendarFormat.twoWeeks: l10n.calendarFormatTwoWeeks,
                CalendarFormat.week: l10n.calendarFormatWeek,
              },
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(selectedDay, day),
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
              eventLoader: (day) =>
                  _getEventsForDay(day, settings.homeCalendarTimeBasis),
              headerStyle: HeaderStyle(
                formatButtonShowsNext: false,
                titleTextFormatter: (date, _) => _formatCalendarMonth(
                  date,
                  settings.homeCalendarLayout,
                  l10n,
                ),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                dowTextFormatter: (date, _) => _calendarWeekdayLabel(
                  date.weekday,
                  settings.homeCalendarLayout,
                  l10n,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  if (events.isEmpty) return null;
                  final hasUnwatched = events.any((ep) {
                    final s =
                        ep.anime.episodeStatuses[ep.episode] ??
                        EpisodeStatus.unwatched;
                    return s == EpisodeStatus.unwatched;
                  });
                  return Positioned(
                    bottom: 1,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: hasUnwatched
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
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
                  _calendarTimeNote(settings.homeCalendarTimeBasis, l10n),
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
                    DateFormat.MMMd(
                      _calendarDateLocale(settings, l10n),
                    ).format(selectedDay),
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              ...selectedEvents.map(
                (ep) => _buildEpisodeTile(ep, theme, l10n, settings),
              ),
            ],

            // Unwatched section
            if (unwatched.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  l10n.homeUnwatched(unwatched.length, unwatchedEpisodeCount),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
              ...unwatched.map(
                (ep) => _buildEpisodeTile(ep, theme, l10n, settings),
              ),
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
        onPressed: _showAddOptions,
        tooltip: l10n.animeAdd,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Purpose: Return the locale used for home calendar month and date labels.
  /// Inputs: `settings`, `l10n`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Japanese calendar layout intentionally uses Japanese month/day labels.
  String _calendarDateLocale(AppSettings settings, AppLocalizations l10n) {
    return settings.homeCalendarLayout == HomeCalendarLayout.japanese
        ? 'ja'
        : l10n.localeName;
  }

  /// Purpose: Return a localized calendar header month label.
  /// Inputs: `date`, `layout`, `l10n`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Japanese layout uses Japanese month names regardless of the app language.
  String _formatCalendarMonth(
    DateTime date,
    HomeCalendarLayout layout,
    AppLocalizations l10n,
  ) {
    final locale = layout == HomeCalendarLayout.japanese
        ? 'ja'
        : l10n.localeName;
    return DateFormat.yMMMM(locale).format(date);
  }

  /// Purpose: Return the weekday label shown in the home calendar header row.
  /// Inputs: `weekday`, `layout`, `l10n`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Japanese layout uses single-character 日月火水木金土 labels.
  String _calendarWeekdayLabel(
    int weekday,
    HomeCalendarLayout layout,
    AppLocalizations l10n,
  ) {
    if (layout == HomeCalendarLayout.japanese) {
      const days = ['', '月', '火', '水', '木', '金', '土', '日'];
      return days[weekday.clamp(1, 7)];
    }
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
    return days[weekday.clamp(1, 7)];
  }

  /// Purpose: Convert a Dart weekday value into TableCalendar's week-start enum.
  /// Inputs: `weekday`.
  /// Returns: `StartingDayOfWeek`.
  /// Side effects: None.
  /// Notes: Weekday values use Dart's Monday=1 through Sunday=7 numbering.
  StartingDayOfWeek _startingDayOfWeek(int weekday) {
    return StartingDayOfWeek.values[normalizeWeekStartDay(weekday) - 1];
  }

  /// Purpose: Return the explanatory note for the selected home calendar time basis.
  /// Inputs: `timeBasis`, `l10n`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Anime broadcast timestamps remain Japan-time based in both modes.
  String _calendarTimeNote(
    HomeCalendarTimeBasis timeBasis,
    AppLocalizations l10n,
  ) {
    return switch (timeBasis) {
      HomeCalendarTimeBasis.jst => l10n.homeCalendarTimeNoteJst,
      HomeCalendarTimeBasis.local => l10n.homeCalendarTimeNoteLocal,
    };
  }

  /// Purpose: Provide the internal build episode tile helper for this file.
  /// Inputs: `ep`, `theme`, `l10n`, `settings`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _buildEpisodeTile(
    _AiringEpisode ep,
    ThemeData theme,
    AppLocalizations l10n,
    AppSettings settings,
  ) {
    final status =
        ep.anime.episodeStatuses[ep.episode] ?? EpisodeStatus.unwatched;
    final isWatched = status == EpisodeStatus.watched;
    final isSkipped = status == EpisodeStatus.skippedThisWeek;
    final airDate = _getEpisodeDisplayAirDate(
      ep.anime,
      ep.episode,
      settings.homeCalendarTimeBasis,
    );
    final airStr = airDate != null
        ? DateFormat.MMMd(_calendarDateLocale(settings, l10n)).format(airDate)
        : '';

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
          ep.anime.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text('${l10n.animeEpisodeShort(ep.episode)}  $airStr'),
            if (isSkipped) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.skip_next,
                size: 16,
                color: theme.colorScheme.tertiary,
              ),
              const SizedBox(width: 2),
              Text(
                l10n.animeSkipped,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ep.anime.watchUrl != null)
              IconButton(
                icon: Icon(
                  Icons.open_in_browser,
                  color: theme.colorScheme.tertiary,
                ),
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

  /// Purpose: Create a airing episode instance.
  /// Inputs: `anime`, `episode`.
  /// Returns: A new `_AiringEpisode` instance.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  const _AiringEpisode({required this.anime, required this.episode});
}
