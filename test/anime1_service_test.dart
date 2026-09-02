import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/services/anime1_service.dart';
import 'package:my_anime/features/anime/services/anime_search_service.dart';
import 'package:my_anime/features/anime/views/anime1_labels.dart';
import 'package:my_anime/l10n/app_localizations_en.dart';

/// Purpose: Pure-function coverage for the anime1.me index lookup.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: The HTTP paths take no injectable client and are not exercised;
/// the parsers, the fold, and the ranking are where the site-specific risk is.
void main() {
  const indexJson =
      '[[1939,"奇招百出的維多利亞","連載中(09)","2026","夏",""],'
      '[1935,"GRAND BLUE 碧藍之海 第三季","連載中(09)","2026","夏",""],'
      '[1644,"劇場總集篇 孤獨搖滾！Re:Re:","劇場版","2024","夏","千夏"],'
      '[1134,"孤獨搖滾！","1-12","2022","秋","動漫國"],'
      '[1500,"SPY×FAMILY間諜家家酒 第三季","1-13","2025","秋",""],'
      '[1300,"SPY×FAMILY間諜家家酒 第二季","1-12","2023","秋",""],'
      '[1100,"SPY×FAMILY間諜家家酒","1-12","2022","春",""],'
      '[1400,"葬送的芙莉蓮","1-28","2023","秋",""],'
      '[1700,"葬送的芙莉蓮 第二季","連載中(04)","2026","冬",""],'
      '[1200,"【我推的孩子】","1-11","2023","春",""],'
      '[700,"我的英雄學院","1-13","2016","春",""],'
      '[1600,"鬼滅之刃 柱訓練篇","1-8","2024","春",""],'
      '["oops","bad id","1-1","2020","春",""],'
      '[9,"","1-1","2020","春",""],'
      '[8,"Tom &amp; Jerry","1-1"]]';

  late List<Anime1IndexEntry> index;
  setUpAll(() => index = Anime1Service.parseIndex(indexJson));

  Anime1Match top(List<Anime1Match> m) => m.first;

  group('parseIndex', () {
    test('reads every well-formed row in file order and skips bad ones', () {
      expect(index.map((e) => e.catId).take(4), [1939, 1935, 1644, 1134]);
      expect(index.any((e) => e.title == 'bad id'), isFalse);
      expect(index.any((e) => e.catId == 9), isFalse);
      final short = index.singleWhere((e) => e.catId == 8);
      expect(short.title, 'Tom & Jerry');
      expect(short.year, '');
      expect(short.fansub, '');
    });

    test('folds titles and builds the ?cat= URL', () {
      final bocchi = index.singleWhere((e) => e.catId == 1134);
      expect(bocchi.foldedTitle, '孤独摇滚');
      expect(bocchi.url, 'https://anime1.me/?cat=1134');
      expect(bocchi.season, '秋');
      expect(bocchi.fansub, '動漫國');
    });

    test('accepts an object with a data array and rejects other shapes', () {
      expect(Anime1Service.parseIndex('{"data":[[1,"A","1-1"]]}'), hasLength(1));
      expect(Anime1Service.parseIndex('{"x":1}'), isEmpty);
    });
  });

  group('parseEpisodes', () {
    Anime1EpisodeInfo p(String s) => Anime1Service.parseEpisodes(s);

    test('recognizes every shape the live index uses', () {
      final range = p('1-12');
      expect(range.kind, Anime1EpisodeKind.range);
      expect((range.first, range.last, range.latest), (1, 12, 12));
      expect(range.extras, isNull);

      final ongoing = p('連載中(09)');
      expect(ongoing.kind, Anime1EpisodeKind.ongoing);
      expect(ongoing.latest, 9);
      expect(ongoing.isOngoing, isTrue);

      final ongoingEp = p('連載中(3 EP4)');
      expect(ongoingEp.latest, 3);
      expect(ongoingEp.extras, 'EP4');

      expect(p('劇場版').kind, Anime1EpisodeKind.movie);
      expect(p('特別編').kind, Anime1EpisodeKind.special);
      expect(p('OVA').kind, Anime1EpisodeKind.other);
      expect(p('SP').kind, Anime1EpisodeKind.other);
      expect(p('ONA').kind, Anime1EpisodeKind.other);

      final ova = p('1-12+OVA');
      expect((ova.first, ova.last, ova.extras), (1, 12, '+OVA'));
      expect(p('1-13+SP1-2').extras, '+SP1-2');
      expect(p('1-12+OAD').extras, '+OAD');
      expect(p('1-12+劇場版').kind, Anime1EpisodeKind.range);
      expect(p('1-12+2').extras, '+2');

      final half = p('1-12.5');
      expect(half.last, 12);
      expect(half.extras, isNull);

      final single = p('1');
      expect((single.first, single.last, single.latest), (1, 1, 1));

      final cour = p('13-24');
      expect((cour.first, cour.last), (13, 24));
      expect(p('  1-12  ').raw, '1-12');
    });
  });

  group('foldTitle', () {
    test('normalizes width, case, punctuation and script', () {
      expect(
        AnimeSearchService.foldTitle('ＳＰＹ×ＦＡＭＩＬＹ 間諜家家酒 第三季'),
        'spyfamily间谍家家酒第三季',
      );
      expect(AnimeSearchService.foldTitle('孤獨搖滾！'), '孤独摇滚');
      expect(AnimeSearchService.foldTitle('ぼっち・ざ・ろっく！'), 'ぼっちざろっく');
      expect(AnimeSearchService.foldTitle('【推しの子】'), '推しの子');
      expect(AnimeSearchService.foldTitle('洗乾淨'), '洗干净');
      expect(AnimeSearchService.foldTitle('鬼滅の刃'), '鬼灭の刃');
      expect(AnimeSearchService.foldTitle(''), '');
    });
  });

  group('season helpers', () {
    test('quarterIndexFor snaps a late-quarter premiere forward', () {
      expect(
        Anime1Service.quarterIndexFor(DateTime(2023, 9, 29)),
        Anime1Service.seasonIndex('2023', '秋'),
      );
      expect(
        Anime1Service.quarterIndexFor(DateTime(2023, 9, 10)),
        Anime1Service.seasonIndex('2023', '夏'),
      );
      expect(
        Anime1Service.quarterIndexFor(DateTime(2023, 12, 25)),
        Anime1Service.seasonIndex('2024', '冬'),
      );
      expect(Anime1Service.quarterIndexFor(null), isNull);
    });

    test('seasonIndex reads combined cells and rejects junk', () {
      expect(Anime1Service.seasonIndex('2024', '春/秋'), 2024 * 4 + 1);
      expect(Anime1Service.seasonIndex('', '春'), isNull);
      expect(Anime1Service.seasonIndex('2024', ''), isNull);
    });

    test('seasonOrdinal understands Chinese, English and short forms', () {
      expect(Anime1Service.seasonOrdinal('葬送的芙莉蓮 第二季'), 2);
      expect(Anime1Service.seasonOrdinal('第3期'), 3);
      expect(Anime1Service.seasonOrdinal('第十季'), 10);
      expect(Anime1Service.seasonOrdinal('Season 2'), 2);
      expect(Anime1Service.seasonOrdinal('2nd Season'), 2);
      expect(Anime1Service.seasonOrdinal('S3'), 3);
      expect(Anime1Service.seasonOrdinal('Part 2'), 2);
      expect(Anime1Service.seasonOrdinal('Season 1'), 1);
      expect(Anime1Service.seasonOrdinal('孤獨搖滾！'), isNull);
    });
  });

  group('querySet', () {
    test('folds, drops blanks and one-rune queries, and dedupes', () {
      expect(
        Anime1Service.querySet('孤独摇滚', ['', 'x', '孤獨搖滾！']),
        ['孤独摇滚'],
      );
    });
  });

  group('rank', () {
    test('a Simplified query finds the Traditional row at full score', () {
      final m = Anime1Service.rank(index, Anime1Service.querySet('孤独摇滚', []));
      expect(top(m).catId, 1134);
      expect(top(m).score, 1.0);
      expect(m.map((x) => x.catId), contains(1644));
    });

    test('a Latin title alone misses, and matches through an alias', () {
      expect(
        Anime1Service.rank(index, Anime1Service.querySet('Bocchi the Rock!', [])),
        isEmpty,
      );
      final m = Anime1Service.rank(
        index,
        Anime1Service.querySet('Bocchi the Rock!', ['孤獨搖滾！']),
      );
      expect(top(m).catId, 1134);
    });

    test('the premiere quarter picks the right season of a franchise', () {
      final q = Anime1Service.querySet('SPY×FAMILY', []);
      int pick(DateTime? date) => top(
        Anime1Service.rank(
          index,
          q,
          quarterIndex: Anime1Service.quarterIndexFor(date),
        ),
      ).catId!;
      expect(pick(null), 1100);
      expect(pick(DateTime(2022, 4, 9)), 1100);
      expect(pick(DateTime(2023, 10, 7)), 1300);
      expect(pick(DateTime(2025, 10, 4)), 1500);
    });

    test('the season label ordinal picks the sequel without a date', () {
      final m = Anime1Service.rank(
        index,
        Anime1Service.querySet('葬送的芙莉莲', []),
        ordinal: Anime1Service.seasonOrdinal('第二季'),
      );
      expect(top(m).catId, 1700);
    });

    test('punctuation-wrapped titles and unrelated rows behave', () {
      final oshi = Anime1Service.rank(index, Anime1Service.querySet('我推的孩子', []));
      expect(top(oshi).catId, 1200);
      final hero = Anime1Service.rank(index, Anime1Service.querySet('我的英雄学院', []));
      expect(hero.map((x) => x.catId), [700]);
      final kimetsu = Anime1Service.rank(index, Anime1Service.querySet('鬼滅の刃', []));
      expect(top(kimetsu).catId, 1600);
    });
  });

  group('URL helpers', () {
    test('isAnime1Url and catIdFromUrl', () {
      expect(Anime1Service.isAnime1Url('https://anime1.me/?cat=1134'), isTrue);
      expect(
        Anime1Service.isAnime1Url('https://anime1.me/category/2022年秋季/孤獨搖滾'),
        isTrue,
      );
      expect(Anime1Service.isAnime1Url('https://www.anime1.me/19159'), isTrue);
      expect(Anime1Service.isAnime1Url('https://youtube.com/x'), isFalse);
      expect(Anime1Service.isAnime1Url(null), isFalse);
      expect(Anime1Service.isAnime1Url(''), isFalse);
      expect(Anime1Service.catIdFromUrl('https://anime1.me/?cat=1134'), 1134);
      expect(Anime1Service.catIdFromUrl('https://anime1.me/category/x/y'), isNull);
    });
  });

  group('parseCategoryPage', () {
    const page = '''
<body class="archive category category-1134 wp-theme-basic-shop">
<h1 class="page-title">孤獨搖滾！</h1>
<h2 class="entry-title"><a href="https://anime1.me/19159" rel="bookmark">孤獨搖滾！ [12]</a></h2>
<h2 class="entry-title"><a href="https://anime1.me/19115" rel="bookmark">孤獨搖滾！ [11]</a></h2>
<h2 class="entry-title"><a href="https://anime1.me/19000" rel="bookmark">孤獨搖滾！ [OVA]</a></h2>
<a href="https://anime1.me/category/2022%e5%b9%b4/x" rel="category tag">孤獨搖滾！</a>
''';

    test('reads id, title, newest numbered episode and the category link', () {
      final r = Anime1Service.parseCategoryPage(page);
      expect(r.catId, 1134);
      expect(r.title, '孤獨搖滾！');
      expect(r.latestEpisode, 12);
      expect(r.categoryUrl, 'https://anime1.me/category/2022%e5%b9%b4/x');
    });

    test('a page without numbered posts yields no episode', () {
      final r = Anime1Service.parseCategoryPage('<body class="home"><p>x</p>');
      expect(r.catId, isNull);
      expect(r.latestEpisode, isNull);
      expect(r.title, isNull);
    });
  });

  group('labels', () {
    final en = AppLocalizationsEn();

    test('episode cells localize by kind', () {
      expect(
        anime1EpisodesLabel(en, Anime1Service.parseEpisodes('連載中(09)')),
        'Updated to episode 9',
      );
      expect(
        anime1EpisodesLabel(en, Anime1Service.parseEpisodes('1-12+OVA')),
        'Episodes 1-12+OVA',
      );
      expect(
        anime1EpisodesLabel(en, Anime1Service.parseEpisodes('1-12')),
        'Episodes 1-12',
      );
      expect(anime1EpisodesLabel(en, Anime1Service.parseEpisodes('劇場版')), 'Movie');
      expect(anime1SeasonLabel(en, '2022', '秋'), '2022 Fall');
      expect(anime1SeasonLabel(en, '', ''), isNull);
    });

    test('a match carries its info line and a stored progress its label', () {
      final m = Anime1Service.rank(index, Anime1Service.querySet('孤独摇滚', []));
      expect(anime1InfoLine(en, top(m)), '2022 Fall · Episodes 1-12 · 動漫國');
      final progress = top(m).toProgress(DateTime.utc(2026, 9, 1));
      expect(progress.sourceUrl, 'https://anime1.me/?cat=1134');
      expect(progress.latestEpisode, 12);
      expect(progress.ongoing, isFalse);
      expect(watchProgressLabel(en, progress), 'Episodes 1-12');
    });
  });

  group('alias candidates', () {
    test('keeps Chinese and Latin titles of confident hits only', () {
      const good = AnimeSearchResult(
        source: 'bangumi.tv',
        title: '间谍过家家',
        titleJa: 'SPY×FAMILY',
        synonyms: ['SPY×FAMILY間諜家家酒', 'スパイファミリー'],
      );
      const bad = AnimeSearchResult(source: 'bangumi.tv', title: '完全无关的作品');
      final variants = AnimeSearchService.queryVariants('间谍过家家');
      final aliases = AnimeSearchService.aliasCandidatesFrom([good, bad], variants);
      expect(aliases, contains('SPY×FAMILY間諜家家酒'));
      expect(aliases, isNot(contains('スパイファミリー')));
      expect(aliases, isNot(contains('完全无关的作品')));
    });
  });

  group('relevance regression', () {
    test('folded pass scores a Simplified query fully against Traditional', () {
      const result = AnimeSearchResult(source: 'bangumi.tv', title: '葬送的芙莉蓮');
      final variants = AnimeSearchService.queryVariants('葬送的芙莉莲');
      expect(AnimeSearchService.relevance(result, variants), 1.0);
    });
  });
}
