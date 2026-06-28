import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/models/anime.dart';
import 'package:my_anime/shared/services/duplicate_service.dart';

/// Purpose: Test duplicate detection and merge logic.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: Covers same-id, same-url, same-title-season detection, transitive
/// grouping, and merge semantics (episode statuses, ratings, notes, fields).
void main() {
  const createdAt = '2026-01-01T00:00:00.000Z';
  const modifiedAt = '2026-01-02T00:00:00.000Z';

  Anime makeAnime({
    String id = 'a1',
    String title = 'Test',
    String? titleJa,
    String season = 'Season 1',
    int? endEpisode = 12,
    String? infoUrl,
    String? watchUrl,
    DateTime? firstAirDate,
    Map<int, EpisodeStatus> episodeStatuses = const {},
    String? notes,
    AnimeRating? rating,
  }) {
    return Anime.fromJson({
      'id': id,
      'title': title,
      if (titleJa != null) 'titleJa': titleJa,
      'season': season,
      'startEpisode': 1,
      if (endEpisode != null) 'endEpisode': endEpisode,
      if (infoUrl != null) 'infoUrl': infoUrl,
      if (watchUrl != null) 'watchUrl': watchUrl,
      if (firstAirDate != null)
        'firstAirDate': firstAirDate.toIso8601String(),
      'episodeStatuses': {
        for (final e in episodeStatuses.entries) e.key.toString(): e.value.name,
      },
      if (notes != null) 'notes': notes,
      if (rating != null) 'rating': rating.toJson(),
      'createdAt': createdAt,
      'modifiedAt': modifiedAt,
    });
  }

  group('DuplicateService.detect', () {
    test('finds no duplicates in a clean list', () {
      final animes = [
        makeAnime(id: 'a1', title: 'Alpha'),
        makeAnime(id: 'a2', title: 'Beta'),
        makeAnime(id: 'a3', title: 'Gamma'),
      ];
      final result = DuplicateService.detect(animes);
      expect(result.hasDuplicates, isFalse);
      expect(result.groups, isEmpty);
    });

    test('groups by same ID', () {
      final animes = [
        makeAnime(id: 'a1', title: 'Alpha'),
        makeAnime(id: 'a1', title: 'Alpha copy'),
        makeAnime(id: 'a2', title: 'Beta'),
      ];
      final result = DuplicateService.detect(animes);
      expect(result.groups, hasLength(1));
      expect(result.groups.first.animes, hasLength(2));
      expect(result.groups.first.reason, DuplicateReason.sameId);
    });

    test('groups by same info URL', () {
      final animes = [
        makeAnime(id: 'a1', title: 'Alpha', infoUrl: 'https://example.com/a'),
        makeAnime(id: 'a2', title: 'Alpha Clone', infoUrl: 'https://example.com/a'),
        makeAnime(id: 'a3', title: 'Beta'),
      ];
      final result = DuplicateService.detect(animes);
      expect(result.groups, hasLength(1));
      expect(result.groups.first.reason, DuplicateReason.sameUrl);
    });

    test('groups by same title and season', () {
      final animes = [
        makeAnime(id: 'a1', title: 'Frieren', firstAirDate: DateTime(2026, 1, 5)),
        makeAnime(id: 'a2', title: 'Frieren', firstAirDate: DateTime(2026, 1, 5)),
      ];
      final result = DuplicateService.detect(animes);
      expect(result.groups, hasLength(1));
      expect(result.groups.first.reason, DuplicateReason.sameTitleSeason);
    });

    test('does not group same title with different air dates', () {
      final animes = [
        makeAnime(id: 'a1', title: 'Reboot', firstAirDate: DateTime(2025, 4, 1)),
        makeAnime(id: 'a2', title: 'Reboot', firstAirDate: DateTime(2026, 4, 1)),
      ];
      final result = DuplicateService.detect(animes);
      expect(result.hasDuplicates, isFalse);
    });

    test('transitive grouping merges A-B and B-C', () {
      final animes = [
        makeAnime(id: 'a1', title: 'Show', infoUrl: 'https://x.com/1'),
        makeAnime(id: 'a2', title: 'Show', infoUrl: 'https://x.com/1'),
        makeAnime(id: 'a3', title: 'Show', infoUrl: 'https://x.com/2'),
      ];
      final result = DuplicateService.detect(animes);
      expect(result.groups, hasLength(1));
      expect(result.groups.first.animes, hasLength(3));
    });

    test('findConflict returns local match for incoming candidate', () {
      final local = [
        makeAnime(id: 'L1', title: 'Frieren', infoUrl: 'https://example.com/f'),
      ];
      final candidate = makeAnime(id: 'NEW', title: 'Frieren', infoUrl: 'https://example.com/f');
      final match = DuplicateService.findConflict(local, candidate);
      expect(match, isNotNull);
      expect(match!.id, 'L1');
    });
  });

  group('DuplicateService.merge', () {
    test('primary wins title, fills missing endEpisode from other', () {
      final primary = makeAnime(id: 'p1', title: 'Primary', endEpisode: null);
      final other = makeAnime(id: 'o1', title: 'Primary Clone', endEpisode: 24);
      final merged = DuplicateService.merge(primary, [other]);
      expect(merged.title, 'Primary');
      expect(merged.endEpisode, 24);
    });

    test('merges episode statuses with watched > skipped > unwatched', () {
      final primary = makeAnime(
        id: 'p1',
        title: 'Show',
        endEpisode: 3,
        episodeStatuses: {1: EpisodeStatus.watched, 2: EpisodeStatus.unwatched},
      );
      final other = makeAnime(
        id: 'o1',
        title: 'Show',
        endEpisode: 3,
        episodeStatuses: {
          2: EpisodeStatus.skippedThisWeek,
          3: EpisodeStatus.watched,
        },
      );
      final merged = DuplicateService.merge(primary, [other]);
      expect(merged.episodeStatuses[1], EpisodeStatus.watched);
      expect(merged.episodeStatuses[2], EpisodeStatus.skippedThisWeek);
      expect(merged.episodeStatuses[3], EpisodeStatus.watched);
    });

    test('watched wins over skipped in merge', () {
      final primary = makeAnime(
        id: 'p1',
        title: 'Show',
        endEpisode: 2,
        episodeStatuses: {1: EpisodeStatus.skippedThisWeek},
      );
      final other = makeAnime(
        id: 'o1',
        title: 'Show',
        endEpisode: 2,
        episodeStatuses: {1: EpisodeStatus.watched},
      );
      final merged = DuplicateService.merge(primary, [other]);
      expect(merged.episodeStatuses[1], EpisodeStatus.watched);
    });

    test('merges rating sub-scores from fallbacks', () {
      final primary = makeAnime(
        id: 'p1',
        title: 'Show',
        rating: const AnimeRating(overall: 8, visual: 7),
      );
      final other = makeAnime(
        id: 'o1',
        title: 'Show',
        rating: const AnimeRating(story: 9, music: 6),
      );
      final merged = DuplicateService.merge(primary, [other]);
      expect(merged.rating?.overall, 8);
      expect(merged.rating?.visual, 7);
      expect(merged.rating?.story, 9);
      expect(merged.rating?.music, 6);
    });

    test('concatenates non-duplicate notes', () {
      final primary = makeAnime(id: 'p1', title: 'Show', notes: 'Good art');
      final other = makeAnime(id: 'o1', title: 'Show', notes: 'Great music');
      final merged = DuplicateService.merge(primary, [other]);
      expect(merged.notes, contains('Good art'));
      expect(merged.notes, contains('Great music'));
    });

    test('does not duplicate identical notes', () {
      final primary = makeAnime(id: 'p1', title: 'Show', notes: 'Same note');
      final other = makeAnime(id: 'o1', title: 'Show', notes: 'Same note');
      final merged = DuplicateService.merge(primary, [other]);
      expect(merged.notes, 'Same note');
    });

    test('fills missing infoUrl from other', () {
      final primary = makeAnime(id: 'p1', title: 'Show', infoUrl: null);
      final other = makeAnime(
        id: 'o1',
        title: 'Show',
        infoUrl: 'https://example.com/show',
      );
      final merged = DuplicateService.merge(primary, [other]);
      expect(merged.infoUrl, 'https://example.com/show');
    });

    test('primary infoUrl wins when both set', () {
      final primary = makeAnime(
        id: 'p1',
        title: 'Show',
        infoUrl: 'https://primary.com',
      );
      final other = makeAnime(
        id: 'o1',
        title: 'Show',
        infoUrl: 'https://other.com',
      );
      final merged = DuplicateService.merge(primary, [other]);
      expect(merged.infoUrl, 'https://primary.com');
    });

    test('preserves primary id', () {
      final primary = makeAnime(id: 'keep-this-id', title: 'Show');
      final other = makeAnime(id: 'discard-this-id', title: 'Show');
      final merged = DuplicateService.merge(primary, [other]);
      expect(merged.id, 'keep-this-id');
    });
  });
}
