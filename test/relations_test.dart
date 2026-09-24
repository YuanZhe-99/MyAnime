import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/models/anime.dart';
import 'package:my_anime/features/anime/services/anime_search_service.dart';
import 'package:my_anime/features/anime/services/series_service.dart';

final _t = DateTime.utc(2024, 1, 1);

/// Purpose: Build a fixture record with database pages and relations.
/// Inputs: `id`, `title`, `infoUrl`, `relations`, `link`.
/// Returns: `Anime`.
/// Side effects: None.
/// Notes: Test helper.
Anime rec(
  String id,
  String title, {
  String? infoUrl,
  List<AnimeExternalRelation> relations = const [],
  AnimeSeriesLink? link,
}) => Anime(
  id: id,
  title: title,
  infoUrl: infoUrl,
  seriesLink: link,
  externalMeta: relations.isEmpty
      ? null
      : AnimeExternalMeta(relations: relations),
  createdAt: _t,
  modifiedAt: _t,
);

AnimeExternalRelation rel(
  AnimeRelationType type,
  String url, [
  String? title,
]) => AnimeExternalRelation(
  source: 'AniList',
  type: type,
  targetUrl: url,
  title: title,
);

void main() {
  group('mappers', () {
    test('AniList keeps anime nodes and normalises the relation type', () {
      final out = AnimeSearchService.mapAniListRelations({
        'relations': {
          'edges': [
            {
              'relationType': 'SEQUEL',
              'node': {
                'id': 182255,
                'type': 'ANIME',
                'format': 'TV',
                'siteUrl': 'https://anilist.co/anime/182255',
                'title': {
                  'romaji': 'Sousou no Frieren 2nd Season',
                  'native': '葬送のフリーレン 第2期',
                },
              },
            },
            {
              'relationType': 'SOURCE',
              'node': {'id': 118586, 'type': 'MANGA'},
            },
            {
              'relationType': 'CHARACTER',
              'node': {'id': 169811, 'type': 'ANIME'},
            },
          ],
        },
      });
      expect(out, hasLength(2));
      expect(out[0].type, AnimeRelationType.sequel);
      expect(out[0].title, '葬送のフリーレン 第2期');
      expect(out[0].format, 'TV');
      expect(out[1].type, AnimeRelationType.other);
      expect(out[1].extraJson['rawType'], 'CHARACTER');
      expect(out[1].targetUrl, 'https://anilist.co/anime/169811');
      expect(AnimeSearchService.mapAniListRelations({}), isEmpty);
    });

    test('Jikan maps anime entries of the /full relations', () {
      final out = AnimeSearchService.mapJikanRelations({
        'relations': [
          {
            'relation': 'Sequel',
            'entry': [
              {
                'mal_id': 59978,
                'type': 'anime',
                'name': 'Sousou no Frieren 2nd Season',
              },
            ],
          },
          {
            'relation': 'Adaptation',
            'entry': [
              {'mal_id': 126287, 'type': 'manga', 'name': 'Sousou no Frieren'},
            ],
          },
          {
            'relation': 'Side Story',
            'entry': [
              {'mal_id': 56885, 'type': 'anime', 'name': 'Mahou'},
            ],
          },
        ],
      });
      expect(out.map((r) => r.type), [
        AnimeRelationType.sequel,
        AnimeRelationType.sideStory,
      ]);
      expect(out.first.targetUrl, 'https://myanimelist.net/anime/59978');
      expect(out.first.source, 'MyAnimeList');
    });

    test('bangumi.tv maps anime subjects and its Chinese relation names', () {
      final out = AnimeSearchService.mapBangumiRelations([
        {
          'id': 515759,
          'type': 2,
          'relation': '续集',
          'name': 'x',
          'name_cn': '葬送的芙莉莲 第二季',
        },
        {
          'id': 55770,
          'type': 2,
          'relation': '前传',
          'name': '進撃の巨人',
          'name_cn': '',
        },
        {'id': 459283, 'type': 2, 'relation': '衍生', 'name': 'y', 'name_cn': ''},
        {'id': 141781, 'type': 2, 'relation': '不同世界观', 'name': 'z'},
        {'id': 770, 'type': 2, 'relation': '角色出演', 'name': 'w'},
        {'id': 459398, 'type': 1, 'relation': '其他', 'name': 'book'},
      ]);
      expect(out.map((r) => r.type), [
        AnimeRelationType.sequel,
        AnimeRelationType.prequel,
        AnimeRelationType.spinOff,
        AnimeRelationType.alternative,
        AnimeRelationType.other,
      ]);
      expect(out[0].title, '葬送的芙莉莲 第二季');
      expect(out[1].title, '進撃の巨人');
      expect(out[4].extraJson['rawType'], '角色出演');
      expect(out[0].targetUrl, 'https://bgm.tv/subject/515759');
    });

    test('toExternalMeta carries the relations', () {
      final meta = AnimeSearchService.toExternalMeta(
        AnimeSearchResult(
          source: 'AniList',
          relations: [
            rel(AnimeRelationType.sequel, 'https://anilist.co/anime/2'),
          ],
        ),
      );
      expect(meta.relations, hasLength(1));
    });
  });

  group('model', () {
    test('mergedWith replaces one source and keeps the others', () {
      const old = AnimeExternalMeta(
        relations: [
          AnimeExternalRelation(
            source: 'AniList',
            type: AnimeRelationType.sequel,
            targetUrl: 'https://anilist.co/anime/1',
          ),
          AnimeExternalRelation(
            source: 'bangumi.tv',
            type: AnimeRelationType.sequel,
            targetUrl: 'https://bgm.tv/subject/9',
          ),
        ],
      );
      final merged = old.mergedWith(
        const AnimeExternalMeta(
          relations: [
            AnimeExternalRelation(
              source: 'AniList',
              type: AnimeRelationType.prequel,
              targetUrl: 'https://anilist.co/anime/3',
            ),
          ],
        ),
      );
      expect(merged.relations.map((r) => r.targetUrl), [
        'https://bgm.tv/subject/9',
        'https://anilist.co/anime/3',
      ]);
      expect(old.mergedWith(const AnimeExternalMeta()).relations, hasLength(2));
    });

    test('JSON round-trips and keeps unknown relation types verbatim', () {
      final meta = AnimeExternalMeta.fromJson({
        'relations': [
          {
            'source': 'AniList',
            'type': 'sequel',
            'targetUrl': 'https://anilist.co/anime/2',
            'title': 'S2',
            'format': 'TV',
          },
          {'source': 'AniList', 'type': 'crossover', 'future': 1},
          'not-a-map',
        ],
      });
      expect(meta.relations, hasLength(2));
      expect(meta.relations[1].type, AnimeRelationType.other);
      final json = meta.toJson();
      final list = json['relations'] as List;
      expect(list[0], {
        'source': 'AniList',
        'type': 'sequel',
        'targetUrl': 'https://anilist.co/anime/2',
        'title': 'S2',
        'format': 'TV',
      });
      expect(list[1], {'type': 'crossover', 'future': 1, 'source': 'AniList'});
      expect(AnimeExternalMeta.fromJson(json).relations, hasLength(2));
    });

    test('a search result caches its relations', () {
      final r = AnimeSearchResult(
        source: 'AniList',
        relations: [
          rel(AnimeRelationType.sequel, 'https://anilist.co/anime/2'),
        ],
      );
      expect(
        AnimeSearchResult.fromJson(r.toJson()).relations.single.targetUrl,
        'https://anilist.co/anime/2',
      );
    });
  });

  group('series index', () {
    test('canonical keys treat host aliases as one site', () {
      expect(canonicalDatabaseKey('https://bangumi.tv/subject/12'), 'bgm:12');
      expect(canonicalDatabaseKey('https://chii.in/subject/12'), 'bgm:12');
      expect(
        canonicalDatabaseKey('https://myanimelist.net/anime/5/Some_Slug'),
        'mal:5',
      );
      expect(canonicalDatabaseKey('https://example.com'), isNull);
    });

    test('a sequel relation links titles that share nothing', () {
      final index = SeriesIndex.build([
        rec(
          'a',
          '葬送のフリーレン',
          infoUrl: 'https://anilist.co/anime/154587',
          relations: [
            rel(AnimeRelationType.sequel, 'https://anilist.co/anime/182255'),
          ],
        ),
        rec(
          'b',
          'Frieren Season 2',
          infoUrl: 'https://anilist.co/anime/182255',
        ),
      ]);
      expect(index.seriesOf('b')?.members.map((a) => a.id), ['a', 'b']);
    });

    test('a relation beats a base title when choosing a curated series', () {
      const sidA = 'series-a';
      const sidB = 'series-b';
      final index = SeriesIndex.build([
        rec(
          'a1',
          'Alpha Works',
          infoUrl: 'https://anilist.co/anime/1',
          link: const AnimeSeriesLink(seriesId: sidA),
        ),
        rec('b1', 'Beta Story', link: const AnimeSeriesLink(seriesId: sidB)),
        rec(
          'c',
          'Beta Story Season 2',
          relations: [
            rel(AnimeRelationType.prequel, 'https://anilist.co/anime/1'),
          ],
        ),
      ]);
      expect(index.seriesOf('c')?.seriesId, sidA);
    });

    test('spin-offs are suggestions, never links', () {
      final index = SeriesIndex.build([
        rec(
          'a',
          'Main Show',
          infoUrl: 'https://anilist.co/anime/1',
          relations: [
            rel(AnimeRelationType.spinOff, 'https://anilist.co/anime/2'),
          ],
        ),
        rec('b', 'Chibi Theatre', infoUrl: 'https://anilist.co/anime/2'),
      ]);
      expect(index.seriesOf('a'), isNull);
      final fromA = index.suggestionsFor('a');
      expect(fromA.single.anime.id, 'b');
      expect(fromA.single.relation, AnimeRelationType.spinOff);
      expect(index.suggestionsFor('b').single.anime.id, 'a');
    });

    test('a standalone record gets no relation edges', () {
      final index = SeriesIndex.build([
        rec(
          'a',
          'One',
          infoUrl: 'https://anilist.co/anime/1',
          relations: [
            rel(AnimeRelationType.sequel, 'https://anilist.co/anime/2'),
          ],
        ),
        rec(
          'b',
          'Two',
          infoUrl: 'https://anilist.co/anime/2',
          link: const AnimeSeriesLink(standalone: true),
        ),
      ]);
      expect(index.seriesOf('a'), isNull);
    });

    test(
      'the missing sequel is the last member\'s sequel not in the library',
      () {
        final index = SeriesIndex.build([
          rec(
            'a',
            '葬送的芙莉莲',
            infoUrl: 'https://anilist.co/anime/1',
            relations: [
              rel(AnimeRelationType.sequel, 'https://anilist.co/anime/2'),
            ],
          ),
          rec(
            'b',
            '葬送的芙莉莲 第二季',
            infoUrl: 'https://anilist.co/anime/2',
            relations: [
              rel(AnimeRelationType.prequel, 'https://anilist.co/anime/1'),
              rel(AnimeRelationType.sequel, 'https://anilist.co/anime/3', 'S3'),
            ],
          ),
        ]);
        expect(index.missingSequelFor('a')?.title, 'S3');
        expect(index.missingSequelFor('b')?.title, 'S3');
        final complete = SeriesIndex.build([
          rec(
            'a',
            'Solo',
            relations: [
              rel(AnimeRelationType.sequel, 'https://anilist.co/anime/2'),
            ],
          ),
          rec('b', 'Other', infoUrl: 'https://anilist.co/anime/2'),
        ]);
        expect(complete.missingSequelFor('a'), isNull);
      },
    );
  });
}
