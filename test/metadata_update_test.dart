import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/l10n/app_localizations.dart';
import 'package:my_anime/l10n/app_localizations_en.dart';
import 'package:my_anime/l10n/app_localizations_zh.dart';
import 'package:my_anime/features/anime/models/anime.dart';
import 'package:my_anime/features/anime/models/metadata_update.dart';
import 'package:my_anime/features/anime/services/anime_search_service.dart';
import 'package:my_anime/features/anime/services/metadata_update_service.dart';
import 'package:my_anime/shared/services/sync_merge.dart';

/// Purpose: Cover the pure logic of the background metadata updater.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: The network paths are untestable here — `AnimeSearchService`'s HTTP
/// calls are static and take no injectable client — so these pin the decisions
/// that determine what the service *does* with what it fetches.
void main() {
  Anime anime({
    String id = 'a1',
    String? title = 'Some Show',
    String? titleJa,
    int startEpisode = 1,
    int? endEpisode,
    DateTime? firstAirDate,
    int? airDayOfWeek,
    String? airTime,
    String? coverImage,
    String? infoUrl,
    String? notes,
    AnimeExternalMeta? externalMeta,
    String modifiedAt = '2026-01-02T00:00:00.000Z',
  }) => Anime(
    id: id,
    title: title,
    titleJa: titleJa,
    season: 'S1',
    startEpisode: startEpisode,
    endEpisode: endEpisode,
    firstAirDate: firstAirDate,
    airDayOfWeek: airDayOfWeek,
    airTime: airTime,
    coverImage: coverImage,
    infoUrl: infoUrl,
    notes: notes,
    externalMeta: externalMeta,
    createdAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
    modifiedAt: DateTime.parse(modifiedAt),
  );

  AnimeSearchResult result({
    String source = 'AniList',
    String? sourceUrl = 'https://anilist.co/anime/1',
    String? title = 'Some Show',
    int? episodes,
    DateTime? firstAirDate,
    int? airDayOfWeek,
    String? summary,
    List<String> synonyms = const [],
  }) => AnimeSearchResult(
    source: source,
    sourceUrl: sourceUrl,
    title: title,
    episodes: episodes,
    firstAirDate: firstAirDate,
    airDayOfWeek: airDayOfWeek,
    summary: summary,
    synonyms: synonyms,
  );

  group('episode count mismatch', () {
    test('flags a genuine disagreement when the record starts at episode 1', () {
      expect(
        hasEpisodeCountMismatch(
          anime(startEpisode: 1, endEpisode: 12),
          result(episodes: 13),
        ),
        isTrue,
      );
    });

    test('agrees when the counts match', () {
      expect(
        hasEpisodeCountMismatch(
          anime(startEpisode: 1, endEpisode: 12),
          result(episodes: 12),
        ),
        isFalse,
      );
    });

    // The guard that keeps this feature from spamming the records a user
    // curated most carefully: tracking the second cour of a 24-episode show as
    // episodes 13-24 is correct, and must never be reported as an error.
    test('never flags a split-cour record that starts past episode 1', () {
      expect(
        hasEpisodeCountMismatch(
          anime(startEpisode: 13, endEpisode: 24),
          result(episodes: 24),
        ),
        isFalse,
      );
    });

    test('treats an open-ended record as missing, not mismatched', () {
      expect(
        hasEpisodeCountMismatch(anime(endEpisode: null), result(episodes: 12)),
        isFalse,
      );
    });

    test('ignores a source that reports no episode count', () {
      expect(
        hasEpisodeCountMismatch(
          anime(startEpisode: 1, endEpisode: 12),
          result(episodes: null),
        ),
        isFalse,
      );
    });
  });

  group('discovery eligibility', () {
    test('a record with no source at all always qualifies', () {
      expect(needsMetadataDiscovery(anime()), isTrue);
    });

    test('a complete record with a source URL does not', () {
      expect(
        needsMetadataDiscovery(
          anime(
            infoUrl: 'https://anilist.co/anime/1',
            endEpisode: 12,
            firstAirDate: DateTime(2026, 1, 8),
            airDayOfWeek: 4,
            coverImage: 'images/x.jpg',
          ),
        ),
        isFalse,
      );
    });

    test('a record with a source URL but missing details qualifies', () {
      expect(
        needsMetadataDiscovery(
          anime(infoUrl: 'https://anilist.co/anime/1', endEpisode: 12),
        ),
        isTrue,
      );
    });
  });

  group('diffCandidate', () {
    test('fills blanks', () {
      final changes = diffCandidate(
        anime(title: null, endEpisode: null),
        result(title: 'Fetched', episodes: 12, summary: 'Synopsis'),
      );
      final fields = changes.map((c) => c.field).toSet();
      expect(fields, contains(MetadataField.title));
      expect(fields, contains(MetadataField.endEpisode));
      expect(fields, contains(MetadataField.notes));
    });

    test('never proposes overwriting a non-empty user value', () {
      final changes = diffCandidate(
        anime(title: 'My Own Title', notes: 'My own notes'),
        result(title: 'Fetched Title', summary: 'Fetched synopsis'),
      );
      final fields = changes.map((c) => c.field).toSet();
      expect(fields, isNot(contains(MetadataField.title)));
      expect(fields, isNot(contains(MetadataField.notes)));
    });

    test('does propose correcting a demonstrably wrong episode count', () {
      final changes = diffCandidate(
        anime(startEpisode: 1, endEpisode: 12),
        result(episodes: 13),
      );
      final change = changes.singleWhere(
        (c) => c.field == MetadataField.endEpisode,
      );
      expect(change.currentValue, 12);
      expect(change.proposedValue, 13);
    });

    test('proposes nothing for a split-cour record with a matching source', () {
      final changes = diffCandidate(
        anime(
          startEpisode: 13,
          endEpisode: 24,
          firstAirDate: DateTime(2026, 1, 8),
          airDayOfWeek: 4,
          coverImage: 'images/x.jpg',
          infoUrl: 'https://anilist.co/anime/1',
          notes: 'kept',
        ),
        result(episodes: 24),
      );
      expect(changes, isEmpty);
    });
  });

  group('applyMetadataChanges', () {
    test('writes only the accepted fields and leaves modifiedAt alone', () {
      final original = anime(title: null, endEpisode: null);
      final changes = diffCandidate(
        original,
        result(title: 'Fetched', episodes: 12),
      );
      final updated = applyMetadataChanges(
        original,
        changes: changes,
        selected: {MetadataField.endEpisode},
      );
      expect(updated.endEpisode, 12);
      expect(updated.title, isNull, reason: 'title was not accepted');
      expect(updated.modifiedAt, original.modifiedAt);
    });
  });

  group('cache serialization', () {
    test('round-trips an entry and preserves unknown fields', () {
      final store = MetadataUpdateStore.fromJson({
        'futureRoot': {'enabled': true},
        'entries': [
          {
            'animeId': 'a1',
            'status': 'proposed',
            'relevance': 0.9,
            'failureCount': 2,
            'lastAttemptAt': '2026-02-01T10:00:00.000Z',
            'nextAttemptAt': '2026-02-01T16:00:00.000Z',
            'candidate': {'source': 'AniList', 'title': 'Some Show'},
            'futureField': 'kept',
          },
        ],
      });

      final entry = store.entryFor('a1')!;
      expect(entry.status, MetadataUpdateStatus.proposed);
      expect(entry.relevance, 0.9);
      expect(entry.failureCount, 2);
      expect(entry.candidate!.title, 'Some Show');
      expect(entry.extraJson['futureField'], 'kept');

      final json = jsonDecode(jsonEncode(store.toJson()))
          as Map<String, dynamic>;
      expect(json['futureRoot'], {'enabled': true});
      final entryJson =
          (json['entries'] as List<dynamic>).single as Map<String, dynamic>;
      expect(entryJson['futureField'], 'kept');
      expect(entryJson['status'], 'proposed');
      expect(entryJson['candidate'], isA<Map<String, dynamic>>());
    });

    test('keeps an unparseable status in extraJson instead of dropping it', () {
      final entry = MetadataUpdateEntry.fromJson({
        'animeId': 'a1',
        'status': 'somethingNewer',
      })!;
      expect(entry.status, MetadataUpdateStatus.upToDate);
      expect(entry.extraJson['status'], 'somethingNewer');
      expect(entry.toJson()['status'], 'upToDate');
    });

    test('skips malformed entries rather than failing the whole file', () {
      final store = MetadataUpdateStore.fromJson({
        'entries': [
          {'noId': true},
          {'animeId': 'good'},
        ],
      });
      expect(store.entries.map((e) => e.animeId), ['good']);
    });

    test('prunes entries whose anime is gone', () {
      final store = MetadataUpdateStore(
        entries: const [
          MetadataUpdateEntry(animeId: 'alive'),
          MetadataUpdateEntry(animeId: 'deleted'),
        ],
      ).prunedTo({'alive'});
      expect(store.entries.map((e) => e.animeId), ['alive']);
    });
  });

  group('search result caching', () {
    test('round-trips a candidate without shifting calendar dates', () {
      const original = AnimeSearchResult(
        source: 'AniList',
        sourceUrl: 'https://anilist.co/anime/1',
        title: 'Some Show',
        episodes: 12,
        airDayOfWeek: 3,
        airTime: '25:00',
        synonyms: ['Alt'],
        score: 8.4,
      );
      final restored = AnimeSearchResult.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(restored.source, 'AniList');
      expect(restored.episodes, 12);
      expect(restored.airDayOfWeek, 3);
      expect(restored.airTime, '25:00');
      expect(restored.synonyms, ['Alt']);
      expect(restored.score, 8.4);
      expect(restored.scoreMax, 10);
    });

    test('a local-midnight air date survives the round trip unshifted', () {
      final original = AnimeSearchResult(
        source: 'AniList',
        firstAirDate: DateTime(2026, 3, 22),
      );
      final restored = AnimeSearchResult.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(restored.firstAirDate, DateTime(2026, 3, 22));
      expect(restored.firstAirDate!.isUtc, isFalse);
    });
  });

  // Caught on screen during interactive testing: the batch dialogs read
  // "Apply all 1 updates?" and "This changes 1 records at once." The counts are
  // ints, so the ungrammatical form compiles and only shows up when a batch
  // happens to hold exactly one record — the most common case of all.
  group('English batch labels are grammatical at every count', () {
    final AppLocalizations en = AppLocalizationsEn();

    test('singular', () {
      expect(en.metaUpdatesConfirmAll(1), 'Apply this update?');
      expect(en.metaUpdatesConfirmAgain(1), 'This changes one record. Apply it?');
      expect(en.metaUpdatesApplied(1), '1 record updated');
      expect(
        en.metaUpdatesExcludedManual(1),
        '1 record needing manual selection is excluded',
      );
    });

    test('plural', () {
      expect(en.metaUpdatesConfirmAll(3), 'Apply all 3 updates?');
      expect(
        en.metaUpdatesConfirmAgain(3),
        'This changes 3 records at once. Apply them?',
      );
      expect(en.metaUpdatesApplied(3), '3 records updated');
      expect(
        en.metaUpdatesExcludedManual(3),
        '3 records needing manual selection are excluded',
      );
    });

    test('zero applied reads as none, not "0 records updated"', () {
      expect(en.metaUpdatesApplied(0), 'No records updated');
    });

    test('the CJK locales carry the count without inflecting', () {
      final AppLocalizations zh = AppLocalizationsZh();
      expect(zh.metaUpdatesConfirmAll(1), contains('1'));
      expect(zh.metaUpdatesConfirmAll(3), contains('3'));
    });
  });

  group('backoff', () {
    test('climbs the ladder and clamps at the top rung', () {
      expect(MetadataUpdateService.backoffFor(1), const Duration(hours: 1));
      expect(MetadataUpdateService.backoffFor(2), const Duration(hours: 6));
      expect(MetadataUpdateService.backoffFor(3), const Duration(days: 1));
      expect(MetadataUpdateService.backoffFor(4), const Duration(days: 7));
      expect(MetadataUpdateService.backoffFor(99), const Duration(days: 7));
    });
  });

  group('refresh queue priority', () {
    final now = DateTime.parse('2026-06-01T00:00:00.000Z');
    final service = MetadataUpdateService.instance;

    AnimeExternalMeta meta(String refreshedAt) =>
        AnimeExternalMeta(refreshedAt: DateTime.parse(refreshedAt));

    test('a record with a URL but no cached metadata wins outright', () {
      final never = anime(id: 'never', infoUrl: 'https://anilist.co/anime/1');
      final stale = anime(
        id: 'stale',
        infoUrl: 'https://anilist.co/anime/2',
        externalMeta: meta('2020-01-01T00:00:00.000Z'),
      );
      expect(service.selectRefreshTarget([stale, never], now)?.id, 'never');
    });

    test('otherwise the oldest refresh goes first', () {
      final older = anime(
        id: 'older',
        infoUrl: 'https://anilist.co/anime/1',
        externalMeta: meta('2020-01-01T00:00:00.000Z'),
      );
      final newer = anime(
        id: 'newer',
        infoUrl: 'https://anilist.co/anime/2',
        externalMeta: meta('2025-01-01T00:00:00.000Z'),
      );
      expect(service.selectRefreshTarget([newer, older], now)?.id, 'older');
    });

    // Found by running the real app: each record was fetched twice. A finished
    // refresh sits in the write buffer, so the on-disk record still looked
    // never-fetched and was queued again — spending a second request on a
    // result already in hand. The buffer batches disk writes; it must not make
    // the queue forget what it just did.
    test('a record already in the write buffer is not queued again', () {
      final target = anime(id: 'x', infoUrl: 'https://anilist.co/anime/1');
      final other = anime(id: 'y', infoUrl: 'https://anilist.co/anime/2');
      expect(service.selectRefreshTarget([target, other], now)?.id, 'x');
      expect(
        service
            .selectRefreshTarget(
              [target, other],
              now,
              pending: {'x': meta('2026-06-01T00:00:00.000Z')},
            )
            ?.id,
        'y',
        reason: 'x is already fetched and awaiting flush',
      );
      expect(
        service.selectRefreshTarget(
          [target, other],
          now,
          pending: {
            'x': meta('2026-06-01T00:00:00.000Z'),
            'y': meta('2026-06-01T00:00:00.000Z'),
          },
        ),
        isNull,
        reason: 'nothing left to fetch this sweep',
      );
    });

    test('a record with no refreshable URL is never queued', () {
      expect(service.selectRefreshTarget([anime(id: 'bare')], now), isNull);
    });

    test('recently refreshed records are left alone', () {
      final fresh = anime(
        id: 'fresh',
        infoUrl: 'https://anilist.co/anime/1',
        externalMeta: meta('2026-05-31T23:00:00.000Z'),
      );
      expect(service.selectRefreshTarget([fresh], now), isNull);
    });

    test('an entry inside its backoff window is skipped', () {
      final target = anime(id: 'x', infoUrl: 'https://anilist.co/anime/1');
      final store = MetadataUpdateStore(
        entries: [
          MetadataUpdateEntry(
            animeId: 'x',
            failureCount: 2,
            nextAttemptAt: now.add(const Duration(hours: 5)),
          ),
        ],
      );
      expect(
        service.selectRefreshTarget([target], now, store: store),
        isNull,
      );
      expect(
        service
            .selectRefreshTarget(
              [target],
              now.add(const Duration(hours: 6)),
              store: store,
            )
            ?.id,
        'x',
      );
    });
  });

  group('discovery queue', () {
    final now = DateTime.parse('2026-06-01T00:00:00.000Z');
    final service = MetadataUpdateService.instance;

    test('picks an incomplete record', () {
      expect(service.selectDiscoveryTarget([anime(id: 'x')], now)?.id, 'x');
    });

    test('skips a record the user dismissed', () {
      final store = const MetadataUpdateStore(
        entries: [
          MetadataUpdateEntry(
            animeId: 'x',
            status: MetadataUpdateStatus.dismissed,
          ),
        ],
      );
      expect(
        service.selectDiscoveryTarget([anime(id: 'x')], now, store: store),
        isNull,
      );
    });

    test('skips a record already awaiting the user', () {
      final store = const MetadataUpdateStore(
        entries: [
          MetadataUpdateEntry(
            animeId: 'x',
            status: MetadataUpdateStatus.proposed,
          ),
        ],
      );
      expect(
        service.selectDiscoveryTarget([anime(id: 'x')], now, store: store),
        isNull,
      );
    });

    test('skips a record with no title to search for', () {
      expect(
        service.selectDiscoveryTarget(
          [anime(id: 'x', title: null, titleJa: null)],
          now,
        ),
        isNull,
      );
    });
  });

  // The property the whole background write path depends on. `mergeRecords`
  // decides "changed" purely from `modifiedAt` versus the base, so a background
  // refresh that bumped it would resurrect records deleted elsewhere and raise
  // conflicts the user never caused.
  group('background writes and the sync merge', () {
    String encode(List<Map<String, dynamic>> animes) =>
        jsonEncode({'animes': animes});

    Map<String, dynamic> record({
      String id = 'a1',
      String modifiedAt = '2026-01-02T00:00:00.000Z',
      Map<String, dynamic>? externalMeta,
    }) => {
      'id': id,
      'title': 'Some Show',
      'season': 'S1',
      'startEpisode': 1,
      'endEpisode': 12,
      'createdAt': '2026-01-01T00:00:00.000Z',
      'modifiedAt': modifiedAt,
      'externalMeta': ?externalMeta,
    };

    // Pins the trap that made the two tests below necessary: omitting
    // `modifiedAt` does not preserve it, it stamps the current time. Any code
    // writing cached metadata must pass the old value back in explicitly.
    test('copyWith stamps modifiedAt unless it is passed through', () {
      final original = anime();
      expect(
        original.copyWith(externalMeta: const AnimeExternalMeta()).modifiedAt,
        isNot(original.modifiedAt),
      );
      expect(
        original
            .copyWith(
              externalMeta: const AnimeExternalMeta(),
              modifiedAt: original.modifiedAt,
            )
            .modifiedAt,
        original.modifiedAt,
      );
    });

    test('a refreshed record deleted remotely stays deleted', () {
      final base = encode([record()]);
      final local = encode([
        record(
          externalMeta: {'refreshedAt': '2026-06-01T00:00:00.000Z'},
        ),
      ]);
      final remote = encode([]);

      final merged = mergeAnimeData(local, remote, base);
      expect(merged.hasConflicts, isFalse);
      expect(
        merged.merged,
        isEmpty,
        reason: 'the background refresh must not undo another device\'s delete',
      );
    });

    test('a refreshed record never conflicts with a remote edit', () {
      final base = encode([record()]);
      final local = encode([
        record(
          externalMeta: {'refreshedAt': '2026-06-01T00:00:00.000Z'},
        ),
      ]);
      final remote = encode([
        record(modifiedAt: '2026-05-01T00:00:00.000Z'),
      ]);

      final merged = mergeAnimeData(local, remote, base);
      expect(merged.hasConflicts, isFalse);
      expect(merged.merged.single.id, 'a1');
    });

    test('the same change with a bumped modifiedAt would conflict', () {
      final base = encode([record()]);
      final local = encode([
        record(
          modifiedAt: '2026-06-01T00:00:00.000Z',
          externalMeta: {'refreshedAt': '2026-06-01T00:00:00.000Z'},
        ),
      ]);
      final remote = encode([
        record(modifiedAt: '2026-05-01T00:00:00.000Z'),
      ]);

      final merged = mergeAnimeData(local, remote, base);
      expect(
        merged.hasConflicts,
        isTrue,
        reason: 'this is exactly what leaving modifiedAt alone avoids',
      );
    });
  });

  group('manual scan queue', () {
    final now = DateTime.parse('2026-06-01T00:00:00.000Z');
    final service = MetadataUpdateService.instance;

    AnimeExternalMeta meta(String refreshedAt) =>
        AnimeExternalMeta(refreshedAt: DateTime.parse(refreshedAt));

    test('an entry inside its backoff window is still queued', () {
      final target = anime(id: 'x');
      final store = MetadataUpdateStore(
        entries: [
          MetadataUpdateEntry(
            animeId: 'x',
            status: MetadataUpdateStatus.noMatch,
            failureCount: 3,
            nextAttemptAt: now.add(const Duration(days: 6)),
          ),
        ],
      );
      final queue = service.buildScanQueue([target], store, now);
      expect(
        queue.discover.map((a) => a.id),
        ['x'],
        reason: 'pressing the button means "try again now"',
      );
    });

    test('a record the user dismissed is left alone', () {
      final target = anime(id: 'x');
      final store = MetadataUpdateStore(
        entries: [
          const MetadataUpdateEntry(
            animeId: 'x',
            status: MetadataUpdateStatus.dismissed,
          ),
        ],
      );
      final queue = service.buildScanQueue([target], store, now);
      expect(
        queue.discover,
        isEmpty,
        reason: 're-proposing a refusal would make "ignore" meaningless',
      );
    });

    test('a record already awaiting the user is not queued again', () {
      final target = anime(id: 'x');
      final store = MetadataUpdateStore(
        entries: [
          const MetadataUpdateEntry(
            animeId: 'x',
            status: MetadataUpdateStatus.proposed,
          ),
        ],
      );
      expect(
        service.buildScanQueue([target], store, now).discover,
        isEmpty,
      );
    });

    test('a record with fresh cached metadata is not refreshed', () {
      final fresh = anime(
        id: 'fresh',
        infoUrl: 'https://anilist.co/anime/1',
        firstAirDate: DateTime.parse('2026-01-01T00:00:00.000Z'),
        airDayOfWeek: 1,
        endEpisode: 12,
        coverImage: 'images/a.jpg',
        externalMeta: meta('2026-05-31T23:00:00.000Z'),
      );
      final queue = service.buildScanQueue(
        [fresh],
        const MetadataUpdateStore(),
        now,
      );
      expect(queue.refresh, isEmpty);
      expect(queue.discover, isEmpty);
    });

    test('a stale record with a URL is refreshed, not searched for', () {
      final stale = anime(
        id: 'stale',
        infoUrl: 'https://anilist.co/anime/1',
        externalMeta: meta('2020-01-01T00:00:00.000Z'),
      );
      final queue = service.buildScanQueue(
        [stale],
        const MetadataUpdateStore(),
        now,
      );
      expect(queue.refresh.map((a) => a.id), ['stale']);
      expect(
        queue.discover,
        isEmpty,
        reason: 'each record is worth exactly one request per scan',
      );
    });

    test('an incomplete record whose cache is fresh is searched for', () {
      final incomplete = anime(
        id: 'gap',
        infoUrl: 'https://anilist.co/anime/1',
        externalMeta: meta('2026-05-31T23:00:00.000Z'),
      );
      final queue = service.buildScanQueue(
        [incomplete],
        const MetadataUpdateStore(),
        now,
      );
      expect(queue.refresh, isEmpty);
      expect(queue.discover.map((a) => a.id), ['gap']);
    });

    test('a record with no title to search for is skipped', () {
      final blank = anime(id: 'blank', title: null);
      expect(
        service.buildScanQueue([blank], const MetadataUpdateStore(), now)
            .discover,
        isEmpty,
      );
    });
  });

  group('MetadataScanProgress', () {
    test('an empty queue reports no measurable fraction', () {
      const progress = MetadataScanProgress(
        phase: MetadataScanPhase.done,
      );
      expect(
        progress.fraction,
        isNull,
        reason: 'nothing to check is a finished scan, not an empty bar',
      );
    });

    test('fraction tracks done over total', () {
      const progress = MetadataScanProgress(
        phase: MetadataScanPhase.scanning,
        done: 3,
        total: 12,
      );
      expect(progress.fraction, closeTo(0.25, 1e-9));
      expect(progress.isRunning, isTrue);
    });

    test('terminal phases are not running', () {
      for (final phase in [
        MetadataScanPhase.idle,
        MetadataScanPhase.done,
        MetadataScanPhase.cancelled,
      ]) {
        expect(MetadataScanProgress(phase: phase).isRunning, isFalse);
      }
    });
  });

  group('AnimeSearchProgress', () {
    test('a failed source counts as answered', () {
      const progress = AnimeSearchProgress(
        round: 1,
        sources: ['bangumi.tv', 'AniList'],
        counts: {'bangumi.tv': 0},
        failed: {'bangumi.tv'},
      );
      expect(progress.done, 1);
      expect(progress.total, 2);
      expect(progress.fraction, closeTo(0.5, 1e-9));
      expect(progress.isPending('bangumi.tv'), isFalse);
      expect(progress.isPending('AniList'), isTrue);
    });

    test('the second round uses its own denominator', () {
      const second = AnimeSearchProgress(
        round: 2,
        sources: ['filmarks.com'],
        counts: {'filmarks.com': 4},
      );
      expect(
        second.fraction,
        1.0,
        reason: 'only the sources that came back empty are re-queried, so the '
            'bar fills twice instead of jumping backwards',
      );
    });
  });

  group('scan labels in English', () {
    final en = AppLocalizationsEn();

    test('a finished scan reads correctly at zero, one, and many', () {
      expect(en.metaUpdatesScanDone(0), contains('No updates'));
      expect(en.metaUpdatesScanDone(1), contains('1 update found'));
      expect(en.metaUpdatesScanDone(3), contains('3 updates found'));
    });

    test('a stopped scan reads correctly at one', () {
      expect(en.metaUpdatesScanCancelled(1), contains('1 update found'));
    });

    test('per-source counts are not pluralized at one', () {
      expect(en.searchSourceCount(1), '1 result');
      expect(en.searchSourceCount(2), '2 results');
    });
  });
}
