import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/models/anime.dart';
import 'package:myapps_widget/myapps_widget.dart';
import 'package:my_anime/features/settings/widgets/home_widget_preview.dart';
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

    expect(snapshot['v'], widgetEnvelopeVersion);
    expect(snapshot['kind'], HomeWidgetService.kind);
    expect(snapshot['pv'], HomeWidgetService.formatVersion);
    expect(
      WidgetEnvelopeRead.decode(
        jsonEncode(snapshot),
        expectedKind: HomeWidgetService.kind,
      ).status,
      WidgetEnvelopeStatus.ok,
    );
    expect(snapshot['generatedAt'], now.millisecondsSinceEpoch);
    expect(snapshot['payload']['timeZone'], 'Asia/Tokyo');
    expect(snapshot['payload']['airedUnwatched'], 2);
    expect(snapshot['payload']['queueSize'], 1);
    expect(snapshot['payload']['labels'], labels);

    final episodes = (snapshot['payload']['episodes'] as List).cast<Map>();
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
          statuses: {for (var ep = 1; ep <= 4; ep++) ep: EpisodeStatus.watched},
        ),
      ],
      nowUtc: now,
      basis: HomeCalendarTimeBasis.jst,
      labels: labels,
    );

    expect(snapshot['payload']['airedUnwatched'], 0);
    expect(snapshot['payload']['queueSize'], 0);
    final episodes = (snapshot['payload']['episodes'] as List).cast<Map>();
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
    expect(snapshot['payload']['timeZone'], '');
    expect(snapshot['payload']['airedUnwatched'], 4);
  });

  test('caps the episode list', () {
    final library = [for (var i = 0; i < 100; i++) make('x$i')];
    final snapshot = HomeWidgetService.buildSnapshot(
      library,
      nowUtc: now,
      basis: HomeCalendarTimeBasis.jst,
      labels: labels,
    );
    expect(
      (snapshot['payload']['episodes'] as List).length,
      HomeWidgetService.maxEpisodes,
    );
    expect(snapshot['payload']['airedUnwatched'], 400);
  });

  test('writes the clamped text scale', () {
    Map<String, dynamic> build(double scale) => HomeWidgetService.buildSnapshot(
      const [],
      nowUtc: now,
      basis: HomeCalendarTimeBasis.jst,
      labels: labels,
      textScale: scale,
    );
    expect(build(1.0)['textScale'], 1.0);
    expect(build(1.3)['textScale'], 1.3);
    expect(build(3)['textScale'], HomeWidgetService.maxTextScale);
    expect(build(0.5)['textScale'], HomeWidgetService.minTextScale);
    expect(HomeWidgetService.clampTextScale(1.2000001), 1.2);
    expect(HomeWidgetService.clampTextScale(double.nan), 1.0);
  });

  test('preview state mirrors the native evaluation', () {
    final snapshot = HomeWidgetService.buildSnapshot(
      [
        make(
          'a',
          statuses: {1: EpisodeStatus.watched, 2: EpisodeStatus.watched},
        ),
        make(
          'b',
          statuses: {for (var ep = 1; ep <= 4; ep++) ep: EpisodeStatus.watched},
        ),
      ],
      nowUtc: now,
      basis: HomeCalendarTimeBasis.jst,
      labels: labels,
    );
    final state = HomeWidgetPreviewState.evaluate(snapshot, now);
    expect(state.toWatch, 2);
    expect(state.queue.map((e) => [e['id'], e['e']]), [
      ['a', 3],
    ]);
    // Both anime air episode 4 today (JST).
    expect(state.todayCount, 2);
    expect(state.nextUp?['e'], 5);
  });
}
