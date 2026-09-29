import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/models/anime.dart';
import 'package:my_anime/features/anime/views/home_page.dart';
import 'package:my_anime/shared/utils/calendar_preferences.dart';

/// Purpose: Test that the home calendar's precomputed airing index matches the
/// per-day scan it replaced.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: The reference below is the old `_getEventsForDay` logic, kept here
/// as the specification. The index is a pure performance change, so the two
/// must agree for every day, in both time bases.
void main() {
  Anime make(
    String id, {
    int start = 1,
    int? end = 12,
    int? airDay,
    String? airTime,
    DateTime? first,
    AnimeType? type,
    Map<int, int> offsets = const {},
  }) => Anime(
    id: id,
    title: id,
    startEpisode: start,
    endEpisode: end,
    airDayOfWeek: airDay,
    airTime: airTime,
    firstAirDate: first,
    manualType: type,
    episodeWeekOffsets: offsets,
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026),
  );

  List<(String, int)> reference(
    List<Anime> animes,
    DateTime day,
    HomeCalendarTimeBasis basis,
  ) {
    final out = <(String, int)>[];
    final dayOnly = DateTime(day.year, day.month, day.day);
    for (final anime in animes) {
      final lastEp = anime.endEpisode ?? anime.startEpisode;
      for (var ep = anime.startEpisode; ep <= lastEp; ep++) {
        final date = airingCalendarDate(anime, ep, basis);
        if (date != null && date == dayOnly) out.add((anime.id, ep));
      }
    }
    return out;
  }

  final library = <Anime>[
    make('weekly', airDay: 3, airTime: '21:00', first: DateTime(2026, 1, 7)),
    make(
      'late-night',
      airDay: 7,
      airTime: '25:30',
      first: DateTime(2026, 1, 4),
      offsets: {3: 1, 6: -1},
    ),
    make('no-time', airDay: 1, first: DateTime(2026, 2, 2), end: 24),
    make('open-ended', airDay: 5, end: null, first: DateTime(2026, 1, 2)),
    make('all-at-once', type: AnimeType.allAtOnce, first: DateTime(2026, 3, 1)),
    make('no-date', airDay: 2),
    make('no-day', first: DateTime(2026, 1, 1), type: AnimeType.singleCour),
    make('late-start', start: 5, end: 8, airDay: 4, first: DateTime(2026, 1, 8)),
  ];

  for (final basis in HomeCalendarTimeBasis.values) {
    test('index equals the per-day scan (${basis.name})', () {
      final index = buildAiringIndex(library, basis);
      var days = 0;
      for (
        var day = DateTime(2025, 12, 25);
        day.isBefore(DateTime(2026, 9, 1));
        day = DateTime(day.year, day.month, day.day + 1)
      ) {
        final indexed = [
          for (final e in index[day] ?? const <AiringEpisode>[])
            (e.anime.id, e.episode),
        ];
        expect(indexed, reference(library, day, basis), reason: '$day');
        days++;
      }
      expect(days, greaterThan(200));
      // Something must actually be scheduled, or the comparison proves nothing.
      expect(index, isNotEmpty);
    });
  }

  test('an empty library yields an empty index', () {
    expect(buildAiringIndex(const [], HomeCalendarTimeBasis.jst), isEmpty);
  });
}
