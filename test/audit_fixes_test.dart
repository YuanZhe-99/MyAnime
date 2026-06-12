import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/models/anime.dart';
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
}
