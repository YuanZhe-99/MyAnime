import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/models/anime.dart';
import 'package:my_anime/shared/services/sync_merge.dart';

void main() {
  const createdAt = '2026-01-01T00:00:00.000Z';
  const modifiedAt = '2026-01-02T00:00:00.000Z';

  test('preserves unknown anime and top-level JSON fields', () {
    final data = AnimeData.fromJson({
      'schemaVersion': 2,
      'futureRoot': {'enabled': true},
      'animes': [
        {
          'id': 'anime-1',
          'title': 'Original',
          'season': 'Season 1',
          'startEpisode': 1,
          'endEpisode': 12,
          'manualType': 'futureCour',
          'episodeStatuses': {'1': 'watched', '2': 'futureStatus'},
          'futureRating': {'score': 98, 'source': 'newer-app'},
          'createdAt': createdAt,
          'modifiedAt': modifiedAt,
        },
      ],
    });

    final json = data.toJson();
    expect(json['schemaVersion'], 2);
    expect(json['futureRoot'], {'enabled': true});

    final animeJson =
        (json['animes'] as List<dynamic>).single as Map<String, dynamic>;
    expect(animeJson['manualType'], 'futureCour');
    expect(animeJson['futureRating'], {'score': 98, 'source': 'newer-app'});
    expect(animeJson['episodeStatuses'], {'1': 'watched', '2': 'futureStatus'});

    final edited = data.animes.single.copyWith(title: 'Edited');
    final editedJson = edited.toJson();
    expect(editedJson['title'], 'Edited');
    expect(editedJson['manualType'], 'futureCour');
    expect(editedJson['futureRating'], {'score': 98, 'source': 'newer-app'});
  });

  test('auto-resolved sync keeps unknown fields from the non-winning side', () {
    final base = jsonEncode({
      'animes': [
        {
          'id': 'anime-1',
          'title': 'Base',
          'season': 'Season 1',
          'startEpisode': 1,
          'endEpisode': 12,
          'episodeStatuses': {},
          'createdAt': createdAt,
          'modifiedAt': '2026-01-01T00:00:00.000Z',
        },
      ],
    });
    final local = jsonEncode({
      'animes': [
        {
          'id': 'anime-1',
          'title': 'Local wins',
          'season': 'Season 1',
          'startEpisode': 1,
          'endEpisode': 12,
          'episodeStatuses': {'1': 'watched'},
          'createdAt': createdAt,
          'modifiedAt': '2026-01-03T00:00:00.000Z',
        },
      ],
    });
    final remote = jsonEncode({
      'futureRoot': 'keep-me',
      'animes': [
        {
          'id': 'anime-1',
          'title': 'Remote has future data',
          'season': 'Season 1',
          'startEpisode': 1,
          'endEpisode': 12,
          'episodeStatuses': {'2': 'futureStatus'},
          'futureRating': {'score': 100},
          'createdAt': createdAt,
          'modifiedAt': '2026-01-02T00:00:00.000Z',
        },
      ],
    });

    final result = mergeAnimeData(local, remote, base, autoResolve: true);
    final mergedData = AnimeData(
      animes: result.merged,
      extraJson: result.extraJson,
    );
    final mergedJson = mergedData.toJson();
    final animeJson =
        (mergedJson['animes'] as List<dynamic>).single as Map<String, dynamic>;

    expect(mergedJson['futureRoot'], 'keep-me');
    expect(animeJson['title'], 'Local wins');
    expect(animeJson['futureRating'], {'score': 100});
    expect(animeJson['episodeStatuses'], {'1': 'watched', '2': 'futureStatus'});
  });
}
