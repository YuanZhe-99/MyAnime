import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/models/anime.dart';
import 'package:my_anime/features/anime/views/anime_edit_page.dart';
import 'package:my_anime/shared/services/sync_merge.dart';

/// Purpose: Register regression tests for the 2026-06-12 pre-release audit fixes.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: This serves as the test entry point for the file.
void main() {
  Map<String, dynamic> animeJson(String id, String title, String modifiedAt) =>
      {
        'id': id,
        'title': title,
        'season': 'Season 1',
        'startEpisode': 1,
        'endEpisode': 12,
        'createdAt': '2026-01-01T00:00:00.000Z',
        'modifiedAt': modifiedAt,
      };

  const t0 = '2026-06-01T00:00:00.000Z';
  const t1 = '2026-06-02T00:00:00.000Z';
  const t2 = '2026-06-03T00:00:00.000Z';

  test('identical concurrent edits merge without a conflict', () {
    final base = jsonEncode({
      'animes': [animeJson('a1', 'Old', t0), animeJson('a2', 'B', t0)],
    });
    // a1 received the exact same edit on both devices (same modifiedAt and
    // content); a2 changed only locally so the files differ overall.
    final local = jsonEncode({
      'animes': [animeJson('a1', 'New', t1), animeJson('a2', 'B local', t1)],
    });
    final remote = jsonEncode({
      'animes': [animeJson('a1', 'New', t1), animeJson('a2', 'B', t0)],
    });

    final result = mergeAnimeData(local, remote, base);
    expect(result.hasConflicts, isFalse);
    final titles = {for (final a in result.merged) a.id: a.title};
    expect(titles['a1'], 'New');
    expect(titles['a2'], 'B local');
  });

  test('differing concurrent edits still raise a conflict', () {
    final base = jsonEncode({
      'animes': [animeJson('a1', 'Old', t0)],
    });
    final local = jsonEncode({
      'animes': [animeJson('a1', 'Local', t1)],
    });
    final remote = jsonEncode({
      'animes': [animeJson('a1', 'Remote', t2)],
    });

    final result = mergeAnimeData(local, remote, base);
    expect(result.conflicts, hasLength(1));
  });

  test('episode air dates snap forward, never before firstAirDate', () {
    final anime = Anime.fromJson({
      ...animeJson('a1', 'Show', t0),
      // 2026-01-07 is a Wednesday; the show airs on Mondays.
      'firstAirDate': '2026-01-07T00:00:00.000',
      'airDayOfWeek': 1,
      'airTime': '12:00',
    });

    final ep1 = anime.getEpisodeAirDate(1)!;
    expect(ep1.isBefore(DateTime(2026, 1, 7)), isFalse);
    expect(ep1.weekday, DateTime.monday);
    expect(DateTime(ep1.year, ep1.month, ep1.day), DateTime(2026, 1, 12));

    final ep2 = anime.getEpisodeAirDate(2)!;
    expect(ep2.difference(ep1).inDays, 7);

    expect(anime.getEpisodeCalendarDate(1), DateTime(2026, 1, 12));
  });
  test('weekly air dates keep their calendar day across a DST change', () {
    // 23:30 local on a Saturday: adding 24-hour blocks drifts to 00:30 on the
    // next day after a spring-forward and skips a whole week. Only proves
    // itself in a DST time zone (CI: TZ=America/New_York); elsewhere it
    // still guards the arithmetic.
    final anime = Anime(
      id: 'dst',
      title: 'DST',
      airDayOfWeek: 6,
      firstAirDate: DateTime(2026, 3, 7, 23, 30),
      createdAt: DateTime.utc(2026),
      modifiedAt: DateTime.utc(2026),
    );
    for (var n = 1; n <= 30; n++) {
      final expected = DateTime(2026, 3, 7 + 7 * (n - 1));
      expect(anime.getEpisodeCalendarDate(n), expected, reason: 'ep $n');
      final air = anime.getEpisodeAirDate(n)!;
      expect(DateTime(air.year, air.month, air.day), expected);
    }
    final utc = anime.copyWith(firstAirDate: DateTime.utc(2026, 3, 7, 23, 30));
    expect(utc.getEpisodeCalendarDate(3), DateTime(2026, 3, 21));
  });

  group('resolveEndEpisode', () {
    // text, startEp, isEdit, existingEnd -> expected
    const cases = <(String, int, bool, int?, int?)>[
      ('24', 1, false, null, 24),
      ('', 1, false, null, 12), // new record defaults to 12
      ('', 1, true, null, null), // editing an open-ended record keeps null
      ('', 1, true, 26, null), // clearing the field means unknown
      (' 13 ', 1, true, 26, 13),
      ('abc', 1, true, 12, null),
      ('12', 15, false, null, 26), // start past end keeps the count
      ('12', 15, true, 12, 26),
      ('12', 15, true, 24, 38), // edit uses the stored end as the count base
      ('12', 15, true, null, 26),
    ];
    for (final c in cases) {
      test('${c.$1}|start ${c.$2}|edit ${c.$3}|old ${c.$4}', () {
        expect(
          resolveEndEpisode(
            text: c.$1,
            startEp: c.$2,
            isEdit: c.$3,
            existingEnd: c.$4,
          ),
          c.$5,
        );
      });
    }
  });
}
