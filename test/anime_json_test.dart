import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/models/anime.dart';
import 'package:my_anime/shared/services/local_api_server.dart';
import 'package:my_anime/shared/services/sync_merge.dart';

/// Purpose: Initialize startup services and launch the app entry point.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: None.
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

  test(
    'rating uses manual overall first and preserves unknown rating fields',
    () {
      final anime = Anime.fromJson({
        'id': 'anime-1',
        'title': 'Rated',
        'season': 'Season 1',
        'startEpisode': 1,
        'endEpisode': 12,
        'rating': {
          'overall': 9,
          'visual': 8.5,
          'story': 8,
          'futureCategory': 10,
        },
        'createdAt': createdAt,
        'modifiedAt': modifiedAt,
      });

      expect(anime.rating?.effectiveOverall, 9);
      expect(anime.rating?.hasManualOverall, isTrue);

      final json = anime.copyWith(title: 'Edited').toJson();
      expect(json['title'], 'Edited');
      expect(json['rating'], {
        'futureCategory': 10,
        'overall': 9.0,
        'visual': 8.5,
        'story': 8.0,
      });
    },
  );

  test(
    'rating computes overall from sub-scores when manual overall is empty',
    () {
      const rating = AnimeRating(visual: 9, story: 8, music: 7);

      expect(rating.hasManualOverall, isFalse);
      expect(rating.effectiveOverall, closeTo(8, 0.001));
      expect(rating.scoreFor(AnimeRatingField.overall), closeTo(8, 0.001));
    },
  );

  test('local archive round-trips through JSON', () {
    final anime = Anime.fromJson({
      'id': 'anime-1',
      'title': 'Archived',
      'season': 'Season 1',
      'startEpisode': 1,
      'endEpisode': 12,
      'localArchive': {
        'archived': true,
        'source': 'bd',
        'resolution': 'fhd1080p',
        'copies': 2,
        'location': 'NAS-01, HDD-C3',
      },
      'createdAt': createdAt,
      'modifiedAt': modifiedAt,
    });

    expect(anime.localArchive?.archived, isTrue);
    expect(anime.localArchive?.source, ArchiveSource.bd);
    expect(anime.localArchive?.resolution, ArchiveResolution.fhd1080p);
    expect(anime.localArchive?.copies, 2);
    expect(anime.localArchive?.location, 'NAS-01, HDD-C3');

    expect(anime.toJson()['localArchive'], {
      'archived': true,
      'source': 'bd',
      'resolution': 'fhd1080p',
      'copies': 2,
      'location': 'NAS-01, HDD-C3',
    });
  });

  test('an anime without archive data omits the localArchive key', () {
    final anime = Anime.fromJson({
      'id': 'anime-1',
      'title': 'Plain',
      'season': 'Season 1',
      'startEpisode': 1,
      'endEpisode': 12,
      'createdAt': createdAt,
      'modifiedAt': modifiedAt,
    });

    expect(anime.localArchive, isNull);
    expect(anime.toJson().containsKey('localArchive'), isFalse);

    // An all-empty archive is dropped rather than written out, so records that
    // never touched the feature keep serializing exactly as before.
    const empty = AnimeLocalArchive();
    expect(empty.hasAnyData, isFalse);
    expect(
      anime.copyWith(localArchive: empty).toJson().containsKey('localArchive'),
      isFalse,
    );
  });

  test('local archive preserves unknown and unparseable fields', () {
    final anime = Anime.fromJson({
      'id': 'anime-1',
      'title': 'Archived',
      'season': 'Season 1',
      'startEpisode': 1,
      'endEpisode': 12,
      'localArchive': {
        'archived': true,
        'source': 'futureSource',
        'resolution': 'fhd1080p',
        'copies': 'two',
        'futureArchiveField': {'codec': 'AV1'},
      },
      'createdAt': createdAt,
      'modifiedAt': modifiedAt,
    });

    // Values this build cannot parse are kept, not dropped.
    expect(anime.localArchive?.source, isNull);
    expect(anime.localArchive?.copies, isNull);
    expect(anime.localArchive?.resolution, ArchiveResolution.fhd1080p);

    final json = anime.copyWith(title: 'Edited').toJson();
    expect(json['title'], 'Edited');
    expect(json['localArchive'], {
      'archived': true,
      'source': 'futureSource',
      'copies': 'two',
      'futureArchiveField': {'codec': 'AV1'},
      'resolution': 'fhd1080p',
    });
  });

  test('sync keeps unknown local archive fields from the non-winning side', () {
    final base = jsonEncode({
      'animes': [
        {
          'id': 'anime-1',
          'title': 'Base',
          'season': 'Season 1',
          'startEpisode': 1,
          'endEpisode': 12,
          'episodeStatuses': <String, dynamic>{},
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
          'episodeStatuses': <String, dynamic>{},
          'localArchive': {'archived': true, 'source': 'bd', 'copies': 1},
          'createdAt': createdAt,
          'modifiedAt': '2026-01-03T00:00:00.000Z',
        },
      ],
    });
    final remote = jsonEncode({
      'animes': [
        {
          'id': 'anime-1',
          'title': 'Remote has future data',
          'season': 'Season 1',
          'startEpisode': 1,
          'endEpisode': 12,
          'episodeStatuses': <String, dynamic>{},
          'localArchive': {'archived': true, 'futureArchiveField': 'keep-me'},
          'createdAt': createdAt,
          'modifiedAt': '2026-01-02T00:00:00.000Z',
        },
      ],
    });

    final result = mergeAnimeData(local, remote, base, autoResolve: true);
    final mergedJson = AnimeData(
      animes: result.merged,
      extraJson: result.extraJson,
    ).toJson();
    final animeJson =
        (mergedJson['animes'] as List<dynamic>).single as Map<String, dynamic>;

    expect(animeJson['title'], 'Local wins');
    expect(animeJson['localArchive'], {
      'futureArchiveField': 'keep-me',
      'archived': true,
      'source': 'bd',
      'copies': 1,
    });
  });

  test('anime viewing status is derived consistently', () {
    final baseAnime = Anime.create(
      title: 'Status test',
      endEpisode: 3,
      firstAirDate: DateTime(2026, 1, 1),
    );

    expect(baseAnime.viewingStatus, AnimeViewingStatus.notStarted);
    expect(
      baseAnime
          .copyWith(
            episodeStatuses: {1: EpisodeStatus.watched},
            modifiedAt: DateTime.parse(modifiedAt),
          )
          .viewingStatus,
      AnimeViewingStatus.watching,
    );
    expect(
      baseAnime
          .copyWith(
            episodeStatuses: {
              1: EpisodeStatus.watched,
              2: EpisodeStatus.watched,
              3: EpisodeStatus.watched,
            },
            modifiedAt: DateTime.parse(modifiedAt),
          )
          .viewingStatus,
      AnimeViewingStatus.completed,
    );
    expect(
      baseAnime
          .copyWith(
            episodeStatuses: {
              1: EpisodeStatus.watched,
              2: EpisodeStatus.skippedThisWeek,
              3: EpisodeStatus.skippedThisWeek,
            },
            modifiedAt: DateTime.parse(modifiedAt),
          )
          .viewingStatus,
      AnimeViewingStatus.dropped,
    );
  });

  test('local API ranking filters and sorts rated anime', () {
    final high = Anime.create(
      title: 'High',
      endEpisode: 12,
      firstAirDate: DateTime(2026, 4, 1),
      rating: const AnimeRating(visual: 9, story: 8),
    );
    final low = Anime.create(
      title: 'Low',
      endEpisode: 12,
      firstAirDate: DateTime(2026, 4, 1),
      rating: const AnimeRating(overall: 6, visual: 10),
    );
    final unrated = Anime.create(
      title: 'Unrated',
      endEpisode: 12,
      firstAirDate: DateTime(2026, 4, 1),
    );
    final outsideQuarter = Anime.create(
      title: 'Outside',
      endEpisode: 12,
      firstAirDate: DateTime(2026, 7, 1),
      rating: const AnimeRating(overall: 10),
    );

    final result = LocalApiServer.buildRankingSnapshotForQuery(
      [low, unrated, outsideQuarter, high],
      {'time': 'quarter', 'season': '2026Q2', 'field': 'overall'},
    );

    expect(result.error, isNull);
    final data = result.data!;
    expect(data['total'], 2);
    expect(data['filters'], containsPair('season', '2026Q2'));

    final rows = data['data'] as List<dynamic>;
    expect(rows.map((row) => row['title']).toList(), ['High', 'Low']);
    expect(rows.first['rank'], 1);
    expect(rows.first['score'], closeTo(8.5, 0.001));
    expect(rows.first['rating']['effectiveOverall'], closeTo(8.5, 0.001));
    expect(rows.first['status'], AnimeViewingStatus.notStarted.name);
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
          'rating': {'futureCategory': 10},
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
    expect(animeJson['rating'], {'futureCategory': 10});
    expect(animeJson['episodeStatuses'], {'1': 'watched', '2': 'futureStatus'});
  });
}
