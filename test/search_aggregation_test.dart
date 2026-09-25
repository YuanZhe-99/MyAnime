import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/services/anime_search_service.dart';

/// Purpose: Test how multi-source search hands out results, and the
/// acgsecrets.hk page parser.
/// Inputs: None.
/// Returns: None.
/// Side effects: None — every source is replaced through
/// `AnimeSearchService.debugSourceOverrides`, so nothing touches the network.
/// Notes: The source fetchers are completed by hand, so the tests decide which
/// source answers first.
void main() {
  AnimeSearchResult hit(String source, String url, String title) =>
      AnimeSearchResult(source: source, sourceUrl: url, title: title);

  group('incremental results', () {
    late Map<String, Completer<List<AnimeSearchResult>>> pending;

    setUp(() {
      pending = {
        for (final s in AnimeSearchSource.all)
          s: Completer<List<AnimeSearchResult>>(),
      };
      AnimeSearchService.debugSourceOverrides = {
        for (final s in AnimeSearchSource.all) s: (_) => pending[s]!.future,
      };
    });

    tearDown(() => AnimeSearchService.debugSourceOverrides = null);

    test('results arrive before the slowest source answers', () async {
      final updates = <List<AnimeSearchResult>>[];
      final done = AnimeSearchService.searchAll(
        'Frieren',
        onResults: updates.add,
      );
      await Future<void>.delayed(Duration.zero);
      expect(updates, isEmpty);

      pending[AnimeSearchSource.bangumi]!.complete([
        hit(AnimeSearchSource.bangumi, 'https://bgm/1', 'Frieren'),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(updates, hasLength(1));
      expect(updates.last.single.sourceUrl, 'https://bgm/1');

      // acgsecrets.hk is still pending while the others answer.
      pending[AnimeSearchSource.mal]!.complete([
        hit(AnimeSearchSource.mal, 'https://mal/1', 'Frieren'),
      ]);
      pending[AnimeSearchSource.anilist]!.complete([
        hit(AnimeSearchSource.anilist, 'https://al/1', 'Frieren'),
      ]);
      pending[AnimeSearchSource.filmarks]!.complete([
        hit(AnimeSearchSource.filmarks, 'https://fm/1', 'Frieren'),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(updates.last, hasLength(4));

      pending[AnimeSearchSource.acgsecrets]!.completeError(
        TimeoutException('slow'),
      );
      final results = await done;
      expect(
        results.map((r) => r.sourceUrl),
        updates.last.map((r) => r.sourceUrl),
      );
      expect(results, hasLength(4));
    });

    test('a source with no results sends no update', () async {
      final updates = <List<AnimeSearchResult>>[];
      final done = AnimeSearchService.searchAll('zzz', onResults: updates.add);
      for (final c in pending.values) {
        c.complete(const []);
      }
      expect(await done, isEmpty);
      expect(updates, isEmpty);
    });
  });

  group('acgsecrets.hk', () {
    String page(List<Map<String, Object?>> items) =>
        '<html><script type="application/ld+json">'
        '${jsonEncode({'@type': 'ItemList', 'itemListElement': items})}'
        '</script></html>';

    test('one malformed entry does not drop the rest of the page', () {
      final results = AnimeSearchService.parseAcgsecretsPage(
        page([
          {
            'name': '葬送的芙莉蓮 第2季',
            'alternateName': ['葬送のフリーレン 2期', 'Frieren S2'],
            'url': 'https://acgsecrets.hk/bangumi/202601/#1',
            'startDate': '2026-01-16',
            'numberOfEpisodes': 10,
          },
          {
            'name': 'Re:從零開始的異世界生活 第4季',
            'url': 'https://acgsecrets.hk/bangumi/202604/#2',
            // The site now sometimes sends the count as a string.
            'numberOfEpisodes': '19',
          },
          {'name': 42, 'alternateName': 'ある作品', 'url': 7},
          {'name': '孤獨搖滾', 'url': 'https://acgsecrets.hk/bangumi/202604/#3'},
        ]),
      );
      expect(results.map((r) => r.title), [
        '葬送的芙莉蓮 第2季',
        'Re:從零開始的異世界生活 第4季',
        null,
        '孤獨搖滾',
      ]);
      expect(results[0].titleJa, '葬送のフリーレン 2期');
      expect(results[0].synonyms, ['Frieren S2']);
      expect(results[0].episodes, 10);
      expect(results[0].firstAirDate, DateTime(2026, 1, 16));
      expect(results[1].episodes, 19);
      expect(results[2].titleJa, 'ある作品');
      expect(results[2].sourceUrl, isNull);
    });

    test('a page without JSON-LD gives nothing', () {
      expect(AnimeSearchService.parseAcgsecretsPage('<html></html>'), isEmpty);
      expect(
        AnimeSearchService.parseAcgsecretsPage(
          '<script type="application/ld+json">{not json</script>',
        ),
        isEmpty,
      );
    });

    test('searches the current, next and two earlier seasons', () {
      expect(AnimeSearchService.acgsecretsSeasons(DateTime(2026, 9, 24)), [
        '202607',
        '202610',
        '202604',
        '202601',
      ]);
      expect(AnimeSearchService.acgsecretsSeasons(DateTime(2026, 1, 5)), [
        '202601',
        '202604',
        '202510',
        '202507',
      ]);
      expect(AnimeSearchService.acgsecretsSeasons(DateTime(2026, 12, 31)), [
        '202610',
        '202701',
        '202607',
        '202604',
      ]);
    });
  });
}
