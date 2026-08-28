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

  test('external metadata round-trips through JSON', () {
    final anime = Anime.fromJson({
      'id': 'anime-1',
      'title': 'Frieren',
      'season': 'Season 1',
      'startEpisode': 1,
      'endEpisode': 28,
      'externalMeta': {
        'synonyms': ['Frieren at the Funeral'],
        'titleRomaji': 'Sousou no Frieren',
        'titleEn': 'Frieren: Beyond Journey\'s End',
        'format': 'TV',
        'status': 'FINISHED',
        'durationMinutes': 24,
        'genres': ['Adventure', 'Drama'],
        'studios': ['Madhouse'],
        'endDate': '2024-03-22T00:00:00.000Z',
        'ratings': [
          {
            'source': 'AniList',
            'sourceUrl': 'https://anilist.co/anime/154587',
            'score': 9.2,
            'scoreMax': 10.0,
            'votes': 300000,
            'rank': 1,
            'fetchedAt': '2026-08-26T12:00:00.000Z',
          },
        ],
        'refreshedAt': '2026-08-26T12:00:00.000Z',
      },
      'createdAt': createdAt,
      'modifiedAt': modifiedAt,
    });

    final meta = anime.externalMeta;
    expect(meta?.titleRomaji, 'Sousou no Frieren');
    expect(meta?.studios, ['Madhouse']);
    expect(meta?.durationMinutes, 24);
    expect(meta?.ratings.single.source, 'AniList');
    expect(meta?.ratings.single.sourceUrl, 'https://anilist.co/anime/154587');
    expect(meta?.ratings.single.score, 9.2);

    final json = anime.toJson()['externalMeta'] as Map<String, dynamic>;
    expect(json['synonyms'], ['Frieren at the Funeral']);
    expect(json['genres'], ['Adventure', 'Drama']);
    expect(json['refreshedAt'], '2026-08-26T12:00:00.000Z');
    expect((json['ratings'] as List).single, {
      'source': 'AniList',
      'sourceUrl': 'https://anilist.co/anime/154587',
      'score': 9.2,
      'scoreMax': 10.0,
      'votes': 300000,
      'rank': 1,
      'fetchedAt': '2026-08-26T12:00:00.000Z',
    });
  });

  test('endDate keeps its calendar day instead of being shifted to UTC', () {
    // `endDate` is a broadcast date, not an instant. It is written as local
    // midnight, so normalizing it to UTC on read would push it behind midnight
    // for every timezone east of UTC — Japan is UTC+9 — and `DateFormat.yMd()`
    // would then render the previous day.
    final meta = AnimeExternalMeta.fromJson({
      'endDate': '2024-03-22T00:00:00.000',
    });

    expect(meta.endDate!.isUtc, isFalse);
    expect(meta.endDate!.year, 2024);
    expect(meta.endDate!.month, 3);
    expect(meta.endDate!.day, 22);

    // And the value must survive a save/load round-trip unchanged.
    final reparsed = AnimeExternalMeta.fromJson(meta.toJson());
    expect(reparsed.toJson()['endDate'], meta.toJson()['endDate']);
    expect(reparsed.endDate, meta.endDate);
  });

  test('fetchedAt and refreshedAt are still normalized to UTC', () {
    // These two are real instants compared across devices, so unlike endDate
    // they must keep the repo-wide UTC rule.
    final meta = AnimeExternalMeta.fromJson({
      'refreshedAt': '2026-08-26T12:00:00.000Z',
      'ratings': [
        {'source': 'AniList', 'score': 9.2, 'fetchedAt': '2026-08-26T12:00:00.000Z'},
      ],
    });
    expect(meta.refreshedAt!.isUtc, isTrue);
    expect(meta.ratings.single.fetchedAt!.isUtc, isTrue);
  });

  test('an anime without external metadata omits the externalMeta key', () {
    final anime = Anime.fromJson({
      'id': 'anime-1',
      'title': 'Plain',
      'season': 'Season 1',
      'startEpisode': 1,
      'endEpisode': 12,
      'createdAt': createdAt,
      'modifiedAt': modifiedAt,
    });

    expect(anime.externalMeta, isNull);
    expect(anime.toJson().containsKey('externalMeta'), isFalse);
  });

  test('external metadata preserves unknown and unparseable fields', () {
    final anime = Anime.fromJson({
      'id': 'anime-1',
      'title': 'Future data',
      'season': 'Season 1',
      'startEpisode': 1,
      'endEpisode': 12,
      'externalMeta': {
        'format': 'TV',
        // Written by a newer build this version does not understand.
        'futureField': {'source': 'newer-app'},
        // Wrong shapes must survive verbatim rather than being dropped.
        'genres': 'not-a-list',
        'durationMinutes': 'twenty-four',
        'ratings': [
          {
            'source': 'AniList',
            'score': 9.2,
            'fetchedAt': '2026-08-26T12:00:00.000Z',
            'futureMetric': 7,
          },
        ],
      },
      'createdAt': createdAt,
      'modifiedAt': modifiedAt,
    });

    expect(anime.externalMeta?.format, 'TV');
    expect(anime.externalMeta?.genres, isEmpty);
    expect(anime.externalMeta?.durationMinutes, isNull);

    final json = anime.toJson()['externalMeta'] as Map<String, dynamic>;
    expect(json['futureField'], {'source': 'newer-app'});
    expect(json['genres'], 'not-a-list');
    expect(json['durationMinutes'], 'twenty-four');
    expect((json['ratings'] as List).single, containsPair('futureMetric', 7));
  });

  test('refreshing one source keeps what another source contributed', () {
    final fetchedAt = DateTime.utc(2026, 8, 26, 12);
    const existing = AnimeExternalMeta(
      studios: ['Madhouse'],
      format: 'TV',
      ratings: [
        AnimeExternalRating(
          source: 'bangumi.tv',
          sourceUrl: 'https://bgm.tv/subject/400602',
          score: 8.6,
        ),
      ],
    );
    final refreshed = existing.mergedWith(
      AnimeExternalMeta(
        status: 'FINISHED',
        ratings: [
          AnimeExternalRating(
            source: 'AniList',
            sourceUrl: 'https://anilist.co/anime/154587',
            score: 9.2,
            fetchedAt: fetchedAt,
          ),
        ],
      ),
      refreshedAt: fetchedAt,
    );

    // The AniList fetch did not report studios, so Madhouse survives.
    expect(refreshed.studios, ['Madhouse']);
    expect(refreshed.format, 'TV');
    expect(refreshed.status, 'FINISHED');
    expect(refreshed.ratings, hasLength(2));
    expect(refreshed.ratingFor('bangumi.tv')?.score, 8.6);
    expect(refreshed.ratingFor('AniList')?.score, 9.2);
    expect(refreshed.refreshedAt, fetchedAt);
  });

  test('refreshing the same source replaces its previous rating', () {
    const existing = AnimeExternalMeta(
      ratings: [AnimeExternalRating(source: 'AniList', score: 8.0, votes: 100)],
    );
    final refreshed = existing.mergedWith(
      const AnimeExternalMeta(
        ratings: [
          AnimeExternalRating(source: 'AniList', score: 9.2, votes: 500),
        ],
      ),
    );
    expect(refreshed.ratings, hasLength(1));
    expect(refreshed.ratingFor('AniList')?.score, 9.2);
    expect(refreshed.ratingFor('AniList')?.votes, 500);
  });

  test('sync keeps unknown external metadata fields from the non-winning side', () {
    final local = jsonEncode({
      'animes': [
        {
          'id': 'anime-1',
          'title': 'Local wins',
          'season': 'Season 1',
          'startEpisode': 1,
          'endEpisode': 12,
          'externalMeta': {'format': 'TV'},
          'createdAt': createdAt,
          'modifiedAt': '2026-01-03T00:00:00.000Z',
        },
      ],
    });
    final remote = jsonEncode({
      'animes': [
        {
          'id': 'anime-1',
          'title': 'Remote loses',
          'season': 'Season 1',
          'startEpisode': 1,
          'endEpisode': 12,
          'externalMeta': {'format': 'TV', 'futureMetric': 42},
          'createdAt': createdAt,
          'modifiedAt': '2026-01-02T00:00:00.000Z',
        },
      ],
    });

    final result = mergeAnimeData(local, remote, null, autoResolve: true);
    final animeJson = result.merged.single.toJson();
    final metaJson = animeJson['externalMeta'] as Map<String, dynamic>;

    expect(animeJson['title'], 'Local wins');
    expect(metaJson['format'], 'TV');
    expect(metaJson['futureMetric'], 42);
  });

  test('external scores are rebased onto ten before they are compared', () {
    // scoreMax is stored per entry, so a source on another scale must not be
    // read raw — that would rank a 7/10 above an 85/100.
    const tenPoint = AnimeExternalRating(source: 'bangumi.tv', score: 7);
    const hundredPoint = AnimeExternalRating(
      source: 'MyAnimeList',
      score: 85,
      scoreMax: 100,
    );
    expect(tenPoint.normalizedScore, closeTo(7, 0.001));
    expect(hundredPoint.normalizedScore, closeTo(8.5, 0.001));
    expect(
      const AnimeExternalRating(source: 'AniList').normalizedScore,
      isNull,
    );
    expect(
      const AnimeExternalRating(
        source: 'AniList',
        score: 8,
        scoreMax: 0,
      ).normalizedScore,
      isNull,
    );
  });

  test('external meta averages only the sources that reported a score', () {
    const meta = AnimeExternalMeta(
      ratings: [
        AnimeExternalRating(source: 'bangumi.tv', score: 7),
        AnimeExternalRating(source: 'MyAnimeList', score: 85, scoreMax: 100),
        AnimeExternalRating(source: 'AniList', votes: 100),
      ],
    );
    expect(meta.averageNormalizedScore, closeTo(7.75, 0.001));
    expect(meta.normalizedScoreFor('bangumi.tv'), closeTo(7, 0.001));
    expect(meta.normalizedScoreFor('AniList'), isNull);
    expect(meta.normalizedScoreFor('nowhere.example'), isNull);
    expect(meta.scoredSources, ['bangumi.tv', 'MyAnimeList']);
    expect(const AnimeExternalMeta().averageNormalizedScore, isNull);
  });

  test('local API ranking can rank by database score instead of own rating', () {
    final ownRatingOnly = Anime.create(
      title: 'Mine',
      endEpisode: 12,
      firstAirDate: DateTime(2026, 4, 1),
      rating: const AnimeRating(overall: 10),
    );
    final databaseOnly = Anime.create(
      title: 'Database',
      endEpisode: 12,
      firstAirDate: DateTime(2026, 4, 1),
      externalMeta: const AnimeExternalMeta(
        ratings: [AnimeExternalRating(source: 'bangumi.tv', score: 7)],
      ),
    );
    final both = Anime.create(
      title: 'Both',
      endEpisode: 12,
      firstAirDate: DateTime(2026, 4, 1),
      rating: const AnimeRating(overall: 1),
      externalMeta: const AnimeExternalMeta(
        ratings: [
          AnimeExternalRating(source: 'bangumi.tv', score: 9),
          AnimeExternalRating(source: 'MyAnimeList', score: 70, scoreMax: 100),
        ],
      ),
    );

    // Averaged across sources: Both is (9 + 7) / 2 = 8, ahead of Database's 7.
    // The anime with only a personal rating drops out entirely.
    final averaged = LocalApiServer.buildRankingSnapshotForQuery(
      [ownRatingOnly, databaseOnly, both],
      {'scoreSource': 'external'},
    );
    expect(averaged.error, isNull);
    expect(averaged.data!['total'], 2);
    expect(
      (averaged.data!['data'] as List).map((row) => row['title']).toList(),
      ['Both', 'Database'],
    );
    expect((averaged.data!['sort'] as Map)['scoreSource'], 'external');

    // Pinned to one source, Both scores 7.0 and ties with Database, so the
    // title tiebreak decides.
    final pinned = LocalApiServer.buildRankingSnapshotForQuery(
      [ownRatingOnly, databaseOnly, both],
      {'scoreSource': 'external', 'externalSource': 'MyAnimeList'},
    );
    expect(pinned.error, isNull);
    expect(pinned.data!['total'], 1);
    expect((pinned.data!['data'] as List).first['score'], closeTo(7, 0.001));
    expect((pinned.data!['sort'] as Map)['externalSource'], 'MyAnimeList');

    // Default is unchanged, so existing API clients keep their old answer.
    final personal = LocalApiServer.buildRankingSnapshotForQuery(
      [ownRatingOnly, databaseOnly, both],
      const {},
    );
    expect(personal.data!['total'], 2);
    expect(
      (personal.data!['data'] as List).map((row) => row['title']).toList(),
      ['Mine', 'Both'],
    );
    expect((personal.data!['sort'] as Map)['scoreSource'], 'personal');
    expect((personal.data!['sort'] as Map).containsKey('externalSource'), isFalse);
  });

  test('pinning a database source without selecting one is rejected', () {
    final result = LocalApiServer.buildRankingSnapshotForQuery(
      const [],
      {'externalSource': 'bangumi.tv'},
    );
    expect(result.error, 'externalSource requires scoreSource=external');
    expect(
      LocalApiServer.buildRankingSnapshotForQuery(
        const [],
        {'scoreSource': 'nonsense'},
      ).error,
      'invalid scoreSource',
    );
  });
}
