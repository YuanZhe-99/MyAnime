import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/models/anime.dart';
import 'package:my_anime/features/anime/services/metadata_update_service.dart';

/// Purpose: Pin the persisted watch-progress record and its refresh rules.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: The network path is not exercised; what matters is the JSON shape,
/// the "same URL" validity rule, and which records the background loop picks.
void main() {
  final checkedAt = DateTime.utc(2026, 9, 1, 12);

  Anime anime({
    String id = 'a1',
    String? watchUrl = 'https://anime1.me/?cat=1134',
    AnimeWatchProgress? progress,
    int? endEpisode = 12,
    bool allWatched = false,
  }) => Anime(
    id: id,
    title: 'Show',
    season: 'S1',
    endEpisode: endEpisode,
    episodeStatuses: allWatched && endEpisode != null
        ? {for (var e = 1; e <= endEpisode; e++) e: EpisodeStatus.watched}
        : const {},
    watchUrl: watchUrl,
    externalMeta: progress == null
        ? null
        : AnimeExternalMeta(watchProgress: progress),
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026, 1, 2),
  );

  AnimeWatchProgress progress({
    String sourceUrl = 'https://anime1.me/?cat=1134',
    int? latest = 9,
    bool ongoing = true,
    DateTime? at,
  }) => AnimeWatchProgress(
    sourceUrl: sourceUrl,
    catId: 1134,
    latestEpisode: latest,
    episodesText: ongoing ? '連載中(0$latest)' : '1-$latest',
    ongoing: ongoing,
    checkedAt: at ?? checkedAt,
  );

  group('JSON', () {
    test('round-trips inside externalMeta and preserves unknown keys', () {
      final json = anime(progress: progress()).toJson();
      final stored = json['externalMeta']['watchProgress'] as Map;
      expect(stored['latestEpisode'], 9);
      expect(stored['ongoing'], isTrue);
      expect(stored['checkedAt'], '2026-09-01T12:00:00.000Z');

      stored['futureField'] = {'x': 1};
      final back = Anime.fromJson(json);
      final p = back.externalMeta!.watchProgress!;
      expect(p.sourceUrl, 'https://anime1.me/?cat=1134');
      expect(p.catId, 1134);
      expect(p.latestEpisode, 9);
      expect(p.episodesText, '連載中(09)');
      expect(p.checkedAt, checkedAt);
      expect(p.extraJson['futureField'], {'x': 1});
      expect(back.toJson()['externalMeta']['watchProgress']['futureField'], {
        'x': 1,
      });
    });

    test('a malformed record is kept as unknown JSON rather than dropped', () {
      final json = anime(progress: progress()).toJson();
      json['externalMeta']['watchProgress'] = 'nonsense';
      final back = Anime.fromJson(json);
      expect(back.externalMeta!.watchProgress, isNull);
      expect(back.externalMeta!.extraJson['watchProgress'], 'nonsense');
    });

    test('an anime without progress writes no watchProgress key', () {
      final json = anime().toJson();
      expect(json.containsKey('externalMeta'), isFalse);
    });

    test('mergedWith keeps the old progress when the new meta has none', () {
      final merged = AnimeExternalMeta(
        watchProgress: progress(),
      ).mergedWith(const AnimeExternalMeta(status: 'RELEASING'));
      expect(merged.watchProgress?.latestEpisode, 9);
      expect(merged.status, 'RELEASING');
      final replaced = merged.mergedWith(
        AnimeExternalMeta(watchProgress: progress(latest: 10)),
      );
      expect(replaced.watchProgress?.latestEpisode, 10);
    });
  });

  group('validWatchProgress', () {
    test('only applies while the watch URL is the one it was read for', () {
      expect(anime(progress: progress()).validWatchProgress, isNotNull);
      expect(
        anime(
          watchUrl: 'https://anime1.me/?cat=999',
          progress: progress(),
        ).validWatchProgress,
        isNull,
      );
      expect(anime(watchUrl: null, progress: progress()).validWatchProgress, isNull);
    });
  });

  group('selectWatchProgressTargets', () {
    final service = MetadataUpdateService.instance;
    final now = DateTime.utc(2026, 9, 2);

    test('never-checked anime1 URLs are due; other hosts never are', () {
      final targets = service.selectWatchProgressTargets([
        anime(id: 'a'),
        anime(id: 'b', watchUrl: 'https://example.com/x'),
        anime(id: 'c', watchUrl: null),
      ], now);
      expect(targets.map((a) => a.id), ['a']);
    });

    test('ongoing runs are due after six hours, finished ones after a week', () {
      final fresh = anime(id: 'fresh', progress: progress(at: now.subtract(const Duration(hours: 5))));
      final stale = anime(id: 'stale', progress: progress(at: now.subtract(const Duration(hours: 7))));
      final doneFresh = anime(
        id: 'doneFresh',
        progress: progress(ongoing: false, latest: 12, at: now.subtract(const Duration(days: 6))),
      );
      final doneStale = anime(
        id: 'doneStale',
        progress: progress(ongoing: false, latest: 12, at: now.subtract(const Duration(days: 8))),
      );
      final targets = service.selectWatchProgressTargets([
        fresh,
        stale,
        doneFresh,
        doneStale,
      ], now);
      expect(targets.map((a) => a.id), ['stale', 'doneStale']);
    });

    test('a fully watched anime with a complete run is left alone', () {
      final finished = anime(
        id: 'f',
        allWatched: true,
        progress: progress(ongoing: false, latest: 12, at: now.subtract(const Duration(days: 30))),
      );
      final stillAiring = anime(
        id: 's',
        allWatched: true,
        progress: progress(at: now.subtract(const Duration(days: 30))),
      );
      expect(
        service.selectWatchProgressTargets([finished, stillAiring], now).map((a) => a.id),
        ['s'],
      );
    });

    test('a progress stored for a different URL counts as never read', () {
      final moved = anime(
        id: 'm',
        progress: progress(sourceUrl: 'https://anime1.me/?cat=1', at: now),
      );
      expect(service.selectWatchProgressTargets([moved], now), hasLength(1));
    });
  });
}
