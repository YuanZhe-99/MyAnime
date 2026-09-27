import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_anime/features/anime/models/anime.dart';
import 'package:my_anime/features/anime/models/anime_episode.dart';
import 'package:my_anime/features/anime/services/anime1_service.dart';
import 'package:my_anime/features/anime/services/anime_episode_service.dart';
import 'package:my_anime/features/anime/services/anime_media_service.dart';
import 'package:my_anime/shared/services/file_open_service.dart';

const source = 'https://anime1.me/?cat=7';

/// Purpose: Build public page fixtures with arbitrary numbering and season groups.
/// Inputs: Site label, title group and optional unique id.
/// Returns: Episode page.
/// Side effects: None.
/// Notes: No live URLs or tokens are requested by these tests.
AnimeEpisodePage page(
  String number, {
  String group = 'Example 第二季',
  String? id,
}) => AnimeEpisodePage(
  url: 'https://anime1.me/${id ?? number}',
  title: '$group [$number]',
  label: number,
  group: group,
);

/// Purpose: Build a season with cached directory evidence.
/// Inputs: Pages, completeness and optional trusted index range.
/// Returns: Anime fixture.
/// Side effects: None.
/// Notes: Uses a sequel so unmarked titles cannot accidentally pass as season evidence.
Anime record(
  List<AnimeEpisodePage> pages, {
  bool complete = true,
  String? range,
  int start = 1,
  AnimeEpisodeMapping? mapping,
}) => Anime(
  id: 'season',
  title: 'Example 第二季',
  season: 'Season 2',
  startEpisode: start,
  endEpisode: start + 11,
  watchUrl: source,
  episodeMapping: mapping,
  externalMeta: AnimeExternalMeta(
    episodeCatalog: AnimeEpisodeCatalog(
      sourceUrl: source,
      categoryUrl: source,
      title: 'Example 第二季',
      catId: 7,
      indexTitle: 'Example 第二季',
      indexEpisodes: range,
      complete: complete,
      checkedAt: DateTime.utc(2026),
      pages: pages,
    ),
  ),
  createdAt: DateTime.utc(2025),
  modifiedAt: DateTime.utc(2025),
);

/// Purpose: Render realistic WordPress article markup for pagination tests.
/// Inputs: Episode labels and optional next link.
/// Returns: HTML archive.
/// Side effects: None.
/// Notes: Sidebar titles must not become episode links.
String archive(List<int> numbers, {String? next}) =>
    '''
<body class="archive category category-7"><h1 class="page-title">Example 第二季</h1>
${numbers.map((n) => '<article><h2 class="entry-title"><a href="/$n">Example 第二季 [$n]</a></h2></article>').join()}
<aside><h2 class="entry-title"><a href="/999">Other [999]</a></h2></aside>
${next == null ? '' : '<div class="nav-previous"><a href="$next">Older</a></div>'}</body>''';

/// Purpose: Exercise season boundaries, gap preservation and temporary playback sources.
/// Inputs: None.
/// Returns: None.
/// Side effects: Mock HTTP only.
/// Notes: Tests observable mappings rather than parser implementation details.
void main() {
  test(
    'sync keeps future nested fields without restoring removed manual overrides',
    () {
      final older = record([
        page('1'),
      ], mapping: const AnimeEpisodeMapping(sourceUrl: source));
      final json = older.toJson();
      (json['episodeMapping'] as Map)['futureSetting'] = true;
      (json['episodeMapping']['overrides'] as Map)['3'] =
          'https://anime1.me/old';
      (json['externalMeta']['episodeCatalog'] as Map)['futureDirectory'] =
          'keep';
      (json['externalMeta']['episodeCatalog']['pages'][0]
              as Map)['futurePage'] =
          'keep';
      final merged = older.withPreservedUnknownJson([
        Anime.fromJson(json),
      ]).toJson();
      expect(merged['episodeMapping']['futureSetting'], true);
      expect(merged['episodeMapping']['overrides'], isEmpty);
      expect(
        merged['externalMeta']['episodeCatalog']['futureDirectory'],
        'keep',
      );
      expect(
        merged['externalMeta']['episodeCatalog']['pages'][0]['futurePage'],
        'keep',
      );
    },
  );

  test(
    'unrecognized optional field formats round trip without breaking legacy records',
    () {
      final json = record([page('1')]).toJson();
      json['episodeMapping'] = 'future-version-format';
      json['externalMeta']['episodeCatalog'] = ['future-version-format'];
      expect(Anime.fromJson(json).toJson(), json);
    },
  );

  test(
    'confirmed arbitrary start maps without assuming a twelve-episode prequel',
    () {
      final anime = record([page('27'), page('29')], range: '27-38', start: 5);
      final result = AnimeEpisodeService.resolve(anime);
      expect(result.links[5]?.number, 27);
      expect(result.links.containsKey(6), false);
      expect(result.links[7]?.number, 29);
    },
  );

  test(
    'smallest observed sequel number cannot establish its first episode',
    () {
      final result = AnimeEpisodeService.resolve(
        record([page('15'), page('24')]),
      );
      expect(result.needsConfirmation, true);
      expect(result.links, isEmpty);
    },
  );

  test('a confirmed range preserves missing first episodes', () {
    final result = AnimeEpisodeService.resolve(
      record([page('15'), page('24')], range: '13-24'),
    );
    expect(result.links.keys, [3, 12]);
    expect(result.links[1], isNull);
  });

  test('partial pagination cannot establish even an apparent episode one', () {
    final result = AnimeEpisodeService.resolve(
      record([page('1')], complete: false, range: '1-12'),
    );
    expect(result.links, isEmpty);
    expect(result.needsConfirmation, true);
  });

  test(
    'mixed season collection chooses explicit current season with reset numbering',
    () {
      final result = AnimeEpisodeService.resolve(
        record([
          page('1', group: 'Example 第一季', id: 'old'),
          page('1'),
          page('2'),
        ]),
      );
      expect(result.links[1]?.group, 'Example 第二季');
      expect(result.links[2]?.number, 2);
    },
  );

  test(
    'mixed continuous numbering requires current-season start confirmation',
    () {
      final anime = record([
        page('1', group: 'Example 第一季'),
        page('13'),
        page('15'),
      ], range: '1-24');
      expect(AnimeEpisodeService.resolve(anime).links, isEmpty);
      final mapped = AnimeEpisodeService.resolve(
        anime,
        choices: const AnimeEpisodeMapping(
          sourceUrl: source,
          group: 'Example 第二季',
          first: 13,
          last: 24,
        ),
      );
      expect(mapped.links.keys, [1, 3]);
    },
  );

  test(
    'duplicate numbers and specials never silently substitute for regular episodes',
    () {
      final anime = record([
        page('1'),
        page('2'),
        page('2', id: 'duplicate'),
        page('2.5'),
        page('OVA'),
      ]);
      final result = AnimeEpisodeService.resolve(anime);
      expect(result.links.keys, [1]);
      expect(result.needsConfirmation, true);
      final corrected = AnimeEpisodeService.resolve(
        anime,
        choices: const AnimeEpisodeMapping(
          sourceUrl: source,
          overrides: {
            2: 'https://anime1.me/duplicate',
            3: 'https://anime1.me/OVA',
          },
        ),
      );
      expect(corrected.links[2]?.url, 'https://anime1.me/duplicate');
      expect(corrected.links[3]?.label, 'OVA');
    },
  );

  test('new source invalidates directory and manual choices', () {
    final anime = record(
      [page('1')],
      mapping: const AnimeEpisodeMapping(
        sourceUrl: source,
        first: 1,
        overrides: {1: 'https://anime1.me/1'},
      ),
    );
    expect(
      AnimeEpisodeService.resolve(
        anime.copyWith(watchUrl: 'https://anime1.me/?cat=8'),
      ).links,
      isEmpty,
    );
  });

  test('title/season disagreement cannot be overridden by counts or dates', () {
    final anime = record([
      page('1', group: 'Example 第三季'),
    ]).copyWith(firstAirDate: DateTime(2026, 1));
    expect(AnimeEpisodeService.resolve(anime).links, isEmpty);
  });

  test(
    'pagination collects actual links, excludes sidebars and deduplicates',
    () async {
      final client = MockClient(
        (request) async => http.Response(
          request.url.path == '/page/2'
              ? archive([1, 2])
              : archive([2, 3], next: '/page/2'),
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        ),
      );
      final catalog = await AnimeEpisodeService.fetch(source, client: client);
      expect(catalog.complete, true);
      expect(catalog.pages.map((p) => p.number).toSet(), {1, 2, 3});
      client.close();
    },
  );

  test(
    'failed pagination returns incomplete directory, not a guessed season start',
    () async {
      final client = MockClient(
        (r) async => r.url.path == '/page/2'
            ? http.Response('Unavailable', 503)
            : http.Response(
                archive([15, 16], next: '/page/2'),
                200,
                headers: {'content-type': 'text/html; charset=utf-8'},
              ),
      );
      final catalog = await AnimeEpisodeService.fetch(source, client: client);
      expect(catalog.complete, false);
      expect(catalog.pages.length, 2);
      client.close();
    },
  );

  test(
    'single episode follows its category and preserves the saved source identity',
    () async {
      final client = MockClient(
        (r) async => http.Response(
          r.url.path == '/episode'
              ? '<body class="single"><article><a rel="category tag" href="/?cat=7">Series</a></article></body>'
              : archive([1]),
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        ),
      );
      final catalog = await AnimeEpisodeService.fetch(
        'https://anime1.me/episode',
        client: client,
        index: const [
          Anime1IndexEntry(
            catId: 7,
            title: 'Example 第二季',
            foldedTitle: 'example',
            episodesText: '1-12',
          ),
        ],
      );
      expect(catalog.complete, true);
      expect(catalog.sourceUrl, 'https://anime1.me/episode');
      expect(catalog.indexEpisodes, '1-12');
      client.close();
    },
  );

  test('redirects leaving the site are rejected', () async {
    var requests = 0;
    final client = MockClient((r) async {
      requests++;
      return http.Response(
        '',
        302,
        headers: {'location': 'https://unrelated.test/page'},
      );
    });
    final catalog = await AnimeEpisodeService.fetch(source, client: client);
    expect(catalog.complete, false);
    expect(requests, 1);
    client.close();
  });

  test('new metadata and corrections round trip and survive share import', () {
    final anime = record(
      [page('13')],
      range: '13-24',
      mapping: const AnimeEpisodeMapping(
        sourceUrl: source,
        first: 13,
        extraJson: {'futureMapping': true},
      ),
    );
    final json = anime.toJson();
    (json['externalMeta']['episodeCatalog'] as Map)['futureCatalog'] = {
      'enabled': true,
    };
    final copy = Anime.fromJson(json);
    expect(copy.toJson(), json);
    expect(copy.copyWith(title: 'Edited').episodeMapping?.first, 13);
    expect(
      FileOpenService.importedCopy(
        copy,
        id: 'import',
        now: DateTime.utc(2026),
      ).episodeMapping?.first,
      13,
    );
    expect(
      copy
          .copyWith(clearEpisodeMapping: true)
          .toJson()
          .containsKey('episodeMapping'),
      false,
    );
  });

  test('media resolver scopes credentials to the actual video host', () {
    final media = AnimeMediaService.parseSource(
      {
        's': [
          {'src': '//edge.v.anime1.me/video.mp4'},
        ],
      },
      'https://anime1.me/1',
      [
        Cookie('session', 'test')..domain = '.anime1.me',
        Cookie('other', 'hidden')..domain = 'unrelated.test',
      ],
    );
    expect(media?.headers['Cookie'], 'session=test');
    expect(
      AnimeMediaService.parseSource(
        {
          's': [
            {'src': 'https://unrelated.test/video.mp4'},
          ],
        },
        source,
        [],
      ),
      isNull,
    );
    expect(
      AnimeMediaService.parseSource(
        {
          's': [
            {'src': 'http://edge.v.anime1.me/video.mp4'},
          ],
        },
        source,
        [],
      ),
      isNull,
    );
    expect(
      AnimeMediaService.parseSource({'error': 'expired'}, source, []),
      isNull,
    );
  });
}
