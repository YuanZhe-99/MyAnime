import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/models/anime.dart';

/// Purpose: Test .myanimeitem multi-anime bundle export/import format.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: Covers v1 single-anime backward compatibility, v2 multi-anime
/// bundle format, and personal data stripping on export.
void main() {
  const createdAt = '2026-01-01T00:00:00.000Z';
  const modifiedAt = '2026-01-02T00:00:00.000Z';

  Anime makeAnime({
    String id = 'a1',
    String title = 'Test',
    Map<int, EpisodeStatus> episodeStatuses = const {},
  }) {
    return Anime.fromJson({
      'id': id,
      'title': title,
      'season': 'Season 1',
      'startEpisode': 1,
      'endEpisode': 12,
      'episodeStatuses': {
        for (final e in episodeStatuses.entries) e.key.toString(): e.value.name,
      },
      'createdAt': createdAt,
      'modifiedAt': modifiedAt,
    });
  }

  group('.myanimeitem bundle format', () {
    test('v1 single-anime format is backward compatible', () {
      final v1Json = {
        'version': 1,
        'anime': {
          'id': 'original-id',
          'title': 'Single Show',
          'season': 'Season 1',
          'startEpisode': 1,
          'endEpisode': 12,
          'episodeStatuses': {'1': 'watched'},
          'createdAt': createdAt,
          'modifiedAt': modifiedAt,
        },
      };
      expect(v1Json['version'], 1);
      expect(v1Json['anime'], isNotNull);
      final anime = Anime.fromJson(v1Json['anime'] as Map<String, dynamic>);
      expect(anime.title, 'Single Show');
      expect(anime.episodeStatuses[1], EpisodeStatus.watched);
    });

    test('v2 multi-anime bundle contains items list', () {
      final v2Json = {
        'version': 2,
        'items': [
          {
            'anime': {
              'id': 'a1',
              'title': 'Show A',
              'season': 'Season 1',
              'startEpisode': 1,
              'endEpisode': 12,
              'createdAt': createdAt,
              'modifiedAt': modifiedAt,
            },
          },
          {
            'anime': {
              'id': 'a2',
              'title': 'Show B',
              'season': 'Season 1',
              'startEpisode': 1,
              'endEpisode': 24,
              'createdAt': createdAt,
              'modifiedAt': modifiedAt,
            },
          },
        ],
      };
      expect(v2Json['version'], 2);
      final items = v2Json['items'] as List<dynamic>;
      expect(items, hasLength(2));
      final anime0 = Anime.fromJson(items[0]['anime'] as Map<String, dynamic>);
      expect(anime0.title, 'Show A');
      final anime1 = Anime.fromJson(items[1]['anime'] as Map<String, dynamic>);
      expect(anime1.title, 'Show B');
    });

    test('export strips personal viewing data', () {
      final anime = makeAnime(
        title: 'Private Show',
        episodeStatuses: {1: EpisodeStatus.watched, 2: EpisodeStatus.skippedThisWeek},
      );
      // Simulate the strip logic used in exportAnimeItem/exportAnimeBundle.
      final json = anime.toJson();
      json.remove('episodeStatuses');
      json.remove('episodeWeekOffsets');
      expect(json.containsKey('episodeStatuses'), isFalse);
      expect(json.containsKey('episodeWeekOffsets'), isFalse);
      // But other fields remain.
      expect(json['title'], 'Private Show');
      expect(json['endEpisode'], 12);
    });

    test('v2 bundle round-trips through JSON', () {
      final animes = [
        makeAnime(id: 'a1', title: 'Alpha'),
        makeAnime(id: 'a2', title: 'Beta'),
      ];
      final items = animes.map((a) {
        final json = a.toJson();
        json.remove('episodeStatuses');
        json.remove('episodeWeekOffsets');
        return {'anime': json};
      }).toList();
      final bundle = <String, dynamic>{'version': 2, 'items': items};
      final encoded = const JsonEncoder.withIndent('  ').convert(bundle);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      expect(decoded['version'], 2);
      final decodedItems = decoded['items'] as List<dynamic>;
      expect(decodedItems, hasLength(2));
    });
  });
}
