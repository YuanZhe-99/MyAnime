import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/models/anime.dart';
import 'package:my_anime/shared/services/home_widget_service.dart';
import 'package:my_anime/shared/utils/calendar_preferences.dart';

/// Purpose: Test the home-screen widget snapshot built for the native widgets.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: The native widgets recount from this snapshot, so the queue entry,
/// today's entries and the aired-unwatched baseline must be exact.
void main() {
  Anime make(
    String id, {
    Map<int, EpisodeStatus> statuses = const {},
    int end = 12,
  }) => Anime(
    id: id,
    title: 'Title $id',
    startEpisode: 1,
    endEpisode: end,
    airDayOfWeek: 3,
    airTime: '21:00',
    firstAirDate: DateTime(2026, 1, 7),
    episodeStatuses: statuses,
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026),
  );

  // Wednesday 2026-01-28 22:00 JST: episode 4 aired an hour ago.
  final now = DateTime.utc(2026, 1, 28, 13);
  const labels = {'toWatch': 'to watch'};

  test('jstToUtc subtracts nine hours', () {
    expect(
      HomeWidgetService.jstToUtc(DateTime(2026, 1, 28, 21)),
      DateTime.utc(2026, 1, 28, 12),
    );
  });

  test('queues the earliest unwatched aired episode and today onwards', () {
    final snapshot = HomeWidgetService.buildSnapshot(
      [
        make(
          'a',
          statuses: {1: EpisodeStatus.watched, 2: EpisodeStatus.watched},
        ),
      ],
      nowUtc: now,
      basis: HomeCalendarTimeBasis.jst,
      labels: labels,
    );

    expect(snapshot['v'], HomeWidgetService.formatVersion);
    expect(snapshot['generatedAt'], now.millisecondsSinceEpoch);
    expect(snapshot['timeZone'], 'Asia/Tokyo');
    expect(snapshot['airedUnwatched'], 2);
    expect(snapshot['queueSize'], 1);
    expect(snapshot['labels'], labels);

    final episodes = (snapshot['episodes'] as List).cast<Map>();
    // Episode 3 is the queue entry, 4 aired today, 5 airs next week;
    // episode 6 is beyond the lookahead.
    expect(episodes.map((e) => e['e']), [3, 4, 5]);
    expect(episodes.every((e) => e['w'] == false), isTrue);
    expect(
      episodes[1]['at'],
      DateTime.utc(2026, 1, 28, 12).millisecondsSinceEpoch,
    );
  });

  test('watched episodes airing today stay in the snapshot as watched', () {
    final snapshot = HomeWidgetService.buildSnapshot(
      [
        make(
          'b',
          statuses: {
            for (var ep = 1; ep <= 4; ep++) ep: EpisodeStatus.watched,
          },
        ),
      ],
      nowUtc: now,
      basis: HomeCalendarTimeBasis.jst,
      labels: labels,
    );

    expect(snapshot['airedUnwatched'], 0);
    expect(snapshot['queueSize'], 0);
    final episodes = (snapshot['episodes'] as List).cast<Map>();
    expect(episodes.map((e) => [e['e'], e['w']]), [
      [4, true],
      [5, false],
    ]);
  });

  test('local basis leaves the time zone to the device', () {
    final snapshot = HomeWidgetService.buildSnapshot(
      [make('c')],
      nowUtc: now,
      basis: HomeCalendarTimeBasis.local,
      labels: labels,
    );
    expect(snapshot['timeZone'], '');
    expect(snapshot['airedUnwatched'], 4);
  });

  test('caps the episode list', () {
    final library = [
      for (var i = 0; i < 100; i++) make('x$i'),
    ];
    final snapshot = HomeWidgetService.buildSnapshot(
      library,
      nowUtc: now,
      basis: HomeCalendarTimeBasis.jst,
      labels: labels,
    );
    expect(
      (snapshot['episodes'] as List).length,
      HomeWidgetService.maxEpisodes,
    );
    expect(snapshot['airedUnwatched'], 400);
  });
}
