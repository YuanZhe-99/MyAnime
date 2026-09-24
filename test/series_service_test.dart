import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/models/anime.dart';
import 'package:my_anime/features/anime/services/series_service.dart';
import 'package:my_anime/shared/utils/season_label.dart';

final _created = DateTime.utc(2024, 1, 1);

/// Purpose: Build a fixture record.
/// Inputs: `id`, `title`, and optional `titleJa`, `season`, `date`, `link`.
/// Returns: `Anime`.
/// Side effects: None.
/// Notes: Test helper.
Anime rec(
  String id,
  String title, {
  String? titleJa,
  String season = 'Season 1',
  DateTime? date,
  AnimeSeriesLink? link,
  List<String> synonyms = const [],
}) => Anime(
  id: id,
  title: title,
  titleJa: titleJa,
  season: season,
  firstAirDate: date,
  seriesLink: link,
  externalMeta: synonyms.isEmpty ? null : AnimeExternalMeta(synonyms: synonyms),
  createdAt: _created,
  modifiedAt: _created,
);

/// Purpose: Return the member ids of the series `id` belongs to.
/// Inputs: `index`, `id`.
/// Returns: `List<String>?`.
/// Side effects: None.
/// Notes: Test helper.
List<String>? membersOf(SeriesIndex index, String id) =>
    index.seriesOf(id)?.members.map((a) => a.id).toList();

void main() {
  group('season labels', () {
    test('stripSeasonMarkers removes every marker form', () {
      expect(stripSeasonMarkers('進撃の巨人 Season 2'), '進撃の巨人');
      expect(stripSeasonMarkers('進撃の巨人 The Final Season'), '進撃の巨人');
      expect(stripSeasonMarkers('葬送的芙莉莲 第二季'), '葬送的芙莉莲');
      expect(stripSeasonMarkers('【我推的孩子】第二季'), '【我推的孩子】');
      expect(stripSeasonMarkers('ゆるキャン△ SEASON２'), 'ゆるキャン△');
      expect(stripSeasonMarkers('かぐや様は告らせたい 2期'), 'かぐや様は告らせたい');
      expect(stripSeasonMarkers('Overlord III'), 'Overlord');
      expect(stripSeasonMarkers('Title (2nd Season)'), 'Title');
      expect(stripSeasonMarkers('Dr. STONE 第3期 第2クール'), 'Dr. STONE');
      expect(stripSeasonMarkers('鬼灭之刃 游郭篇'), '鬼灭之刃 游郭篇');
    });

    test('titleSeasonOrdinal reads numbers, words and final markers', () {
      expect(titleSeasonOrdinal('進撃の巨人 Season 2'), 2);
      expect(titleSeasonOrdinal('ゆるキャン△ SEASON３'), 3);
      expect(titleSeasonOrdinal('かぐや様 2期'), 2);
      expect(titleSeasonOrdinal('Title Second Season'), 2);
      expect(titleSeasonOrdinal('進撃の巨人 The Final Season'), finalSeasonOrdinal);
      expect(titleSeasonOrdinal('Overlord III'), 3);
      expect(titleSeasonOrdinal('進撃の巨人'), isNull);
    });

    test('seasonOrdinal keeps its anime1 behaviour', () {
      expect(seasonOrdinal('第二十三季'), 23);
      expect(seasonOrdinal('孤獨搖滾！'), isNull);
    });

    test('nextSeasonLabel keeps the numeral style', () {
      expect(nextSeasonLabel('Season 1'), 'Season 2');
      expect(nextSeasonLabel('第一季'), '第二季');
      expect(nextSeasonLabel('第九季'), '第十季');
      expect(nextSeasonLabel('第1期'), '第2期');
      expect(nextSeasonLabel('2nd Season'), '3rd Season');
      expect(nextSeasonLabel('S2'), 'S3');
      expect(nextSeasonLabel('TV'), isNull);
    });
  });

  group('automatic grouping', () {
    final library = [
      rec('aot1', '進撃の巨人', date: DateTime(2013, 4, 7)),
      rec('aot2', '進撃の巨人 Season 2', date: DateTime(2017, 4, 1)),
      rec('aotf', '進撃の巨人 The Final Season', date: DateTime(2020, 12, 7)),
      rec('fr1', '葬送的芙莉莲', date: DateTime(2023, 9, 29)),
      rec('fr2', '葬送的芙莉莲 第二季', date: DateTime(2026, 1, 16)),
      rec('spy1', 'SPY×FAMILY', date: DateTime(2022, 4, 9)),
      rec('spy2', 'SPY×FAMILY Season 2', date: DateTime(2023, 10, 7)),
      rec('oshi1', '【我推的孩子】', date: DateTime(2023, 4, 12)),
      rec('oshi2', '【我推的孩子】第二季', date: DateTime(2024, 7, 3)),
      rec('leg10', '某科学的超电磁炮', season: 'Season 10'),
      rec('leg2', '某科学的超电磁炮', season: 'Season 2'),
      rec('gseed', '機動戦士ガンダムSEED'),
      rec('gibo', '機動戦士ガンダム 鉄血のオルフェンズ'),
      rec('fz', 'Fate/Zero'),
      rec('fsn', 'Fate/stay night'),
      rec('ll', 'Love Live!'),
      rec('lls', 'Love Live! Sunshine!!'),
    ];
    final index = SeriesIndex.build(library);

    test('links seasons whose titles differ only by a marker', () {
      expect(membersOf(index, 'aot2'), ['aot1', 'aot2', 'aotf']);
      expect(membersOf(index, 'fr1'), ['fr1', 'fr2']);
      expect(membersOf(index, 'spy1'), ['spy1', 'spy2']);
      expect(membersOf(index, 'oshi2'), ['oshi1', 'oshi2']);
    });

    test('orders legacy identical titles numerically, not as strings', () {
      expect(membersOf(index, 'leg2'), ['leg2', 'leg10']);
      final s = index.seriesOf('leg2')!;
      expect(s.nextOf('leg2')!.id, 'leg10');
      expect(s.previousOf('leg2'), isNull);
      expect(s.isCurated, isFalse);
      expect(s.key, 'auto:leg10');
    });

    test('does not link different works that share a prefix', () {
      expect(index.seriesOf('gseed'), isNull);
      expect(index.seriesOf('gibo'), isNull);
      expect(index.seriesOf('fz'), isNull);
      expect(index.seriesOf('fsn'), isNull);
      expect(index.seriesOf('ll'), isNull);
      expect(index.seriesOf('lls'), isNull);
    });

    test('offers a related title as a suggestion only', () {
      final ids = index.suggestionsFor('ll').map((s) => s.anime.id);
      expect(ids, contains('lls'));
      expect(
        index.suggestionsFor('fr1').map((s) => s.anime.id),
        isNot(contains('fr2')),
      );
    });

    test('gives identical output for shuffled input', () {
      final shuffled = [...library]..shuffle();
      final again = SeriesIndex.build(shuffled);
      expect(
        again.series.map((s) => [s.key, ...s.members.map((a) => a.id)]),
        index.series.map((s) => [s.key, ...s.members.map((a) => a.id)]),
      );
    });

    test('does not link two copies of the same season', () {
      final dupes = SeriesIndex.build([
        rec('a', '孤独摇滚', date: DateTime(2022, 10, 9)),
        rec('b', '孤獨搖滾', date: DateTime(2022, 10, 9)),
        rec('c', '孤独摇滚'),
      ]);
      expect(dupes.series, isEmpty);
    });

    test('ignores keys too short to mean anything', () {
      final short = SeriesIndex.build([
        rec('a', 'K', date: DateTime(2012, 10, 5)),
        rec('b', 'K Season 2', date: DateTime(2015, 10, 3)),
      ]);
      expect(short.series, isEmpty);
    });
  });

  group('curated series', () {
    const sidA = 'aaaaaaaa-0000-4000-8000-000000000001';
    const sidB = 'bbbbbbbb-0000-4000-8000-000000000002';

    test('explicit order comes first, and new auto members land after', () {
      final index = SeriesIndex.build([
        rec(
          'x1',
          '进击的巨人',
          link: const AnimeSeriesLink(seriesId: sidA, order: 2),
        ),
        rec(
          'x2',
          'Attack on Titan S2',
          link: const AnimeSeriesLink(seriesId: sidA, order: 1),
        ),
        rec('x3', '进击的巨人 第三季', date: DateTime(2018, 7, 23)),
      ]);
      expect(membersOf(index, 'x3'), ['x2', 'x1', 'x3']);
      expect(index.seriesOf('x3')!.seriesId, sidA);
    });

    test('two curated series never fuse, and a tie attaches nothing', () {
      final index = SeriesIndex.build([
        rec('a1', '魔法少女小圆', link: const AnimeSeriesLink(seriesId: sidA)),
        rec(
          'b1',
          '魔法少女小圆 第二季',
          date: DateTime(2020, 1, 1),
          link: const AnimeSeriesLink(seriesId: sidB),
        ),
        rec('c', '魔法少女小圆 第三季', date: DateTime(2021, 1, 1)),
      ]);
      expect(membersOf(index, 'a1'), ['a1']);
      expect(membersOf(index, 'b1'), ['b1']);
      expect(index.seriesOf('c'), isNull);
    });

    test('the strongest edge wins', () {
      final index = SeriesIndex.build([
        // Legacy edge (identical title, different label) into A.
        rec(
          'a1',
          '夏目友人帐',
          season: 'Season 1',
          link: const AnimeSeriesLink(seriesId: sidA),
        ),
        // Only a base-title edge into B.
        rec(
          'b1',
          '夏目友人帐 第五季',
          date: DateTime(2016, 10, 4),
          link: const AnimeSeriesLink(seriesId: sidB),
        ),
        rec('c', '夏目友人帐', season: 'Season 6', date: DateTime(2017, 4, 11)),
      ]);
      expect(index.seriesOf('c')!.seriesId, sidA);
    });

    test('standalone records neither join nor attract', () {
      final index = SeriesIndex.build([
        rec('s', '间谍过家家', link: const AnimeSeriesLink(standalone: true)),
        rec('t', '间谍过家家 第二季', date: DateTime(2023, 10, 7)),
      ]);
      expect(index.seriesOf('s'), isNull);
      expect(index.seriesOf('t'), isNull);
    });
  });

  group('SeriesEditor', () {
    final now = DateTime.utc(2026, 9, 24, 12);
    var n = 0;
    String newId() => 'new-${++n}';
    setUp(() => n = 0);

    test('linking to a derived series materialises it first', () {
      final a = rec('a', '葬送的芙莉莲', date: DateTime(2023, 9, 29));
      final b = rec('b', '葬送的芙莉莲 第二季', date: DateTime(2026, 1, 16));
      final c = rec(
        'c',
        'Frieren: Beyond Journey\'s End Season 2',
        titleJa: '葬送のフリーレン',
        link: const AnimeSeriesLink(standalone: true),
      );
      final editor = SeriesEditor(
        SeriesIndex.build([a, b, c]),
        now: now,
        newId: newId,
      );
      final writes = {for (final w in editor.link(c, a)) w.id: w};
      expect(writes.keys.toSet(), {'a', 'b', 'c'});
      for (final w in writes.values) {
        expect(w.seriesLink!.seriesId, 'new-1');
        expect(w.seriesLink!.standalone, isFalse);
        expect(w.modifiedAt, now);
      }
      final after = SeriesIndex.build(writes.values);
      expect(membersOf(after, 'c'), ['a', 'b', 'c']);
    });

    test('linking to a record in no series starts a new series', () {
      final a = rec('a', 'Mushishi');
      final b = rec('b', '蟲師 続章');
      final editor = SeriesEditor(
        SeriesIndex.build([a, b]),
        now: now,
        newId: newId,
      );
      final writes = editor.link(b, a);
      expect(writes.map((w) => w.id).toSet(), {'a', 'b'});
      expect(writes.map((w) => w.seriesLink!.seriesId).toSet(), {'new-1'});
    });

    test('remove writes standalone and leaves the others alone', () {
      final a = rec('a', '葬送的芙莉莲', date: DateTime(2023, 9, 29));
      final b = rec('b', '葬送的芙莉莲 第二季', date: DateTime(2026, 1, 16));
      final editor = SeriesEditor(SeriesIndex.build([a, b]), now: now);
      final writes = editor.removeFromSeries(b);
      expect(writes.single.id, 'b');
      expect(writes.single.seriesLink!.standalone, isTrue);
      expect(writes.single.toJson()['seriesLink'], {'standalone': true});
    });

    test('reorder writes a dense order to every member', () {
      final a = rec('a', '葬送的芙莉莲', date: DateTime(2023, 9, 29));
      final b = rec('b', '葬送的芙莉莲 第二季', date: DateTime(2026, 1, 16));
      final c = rec('c', '葬送的芙莉莲 第三季', date: DateTime(2027, 1, 1));
      final index = SeriesIndex.build([a, b, c]);
      final editor = SeriesEditor(index, now: now, newId: newId);
      final writes = editor.reorder(index.seriesOf('a')!, ['c', 'a']);
      final byId = {for (final w in writes) w.id: w.seriesLink!};
      expect(byId['c']!.order, 1);
      expect(byId['a']!.order, 2);
      expect(byId['b']!.order, 3);
      expect(membersOf(SeriesIndex.build(writes), 'a'), ['c', 'a', 'b']);
    });

    test('let the app decide removes the link but keeps unknown fields', () {
      final a = rec(
        'a',
        'x',
        link: const AnimeSeriesLink(
          seriesId: 'sid',
          extraJson: {'futureField': 1},
        ),
      );
      final editor = SeriesEditor(SeriesIndex.build([a]), now: now);
      final w = editor.letAppDecide(a).single;
      expect(w.seriesLink!.curatedSeriesId, isNull);
      expect(w.toJson()['seriesLink'], {'futureField': 1});
      expect(editor.letAppDecide(rec('b', 'y')), isEmpty);
    });

    test('add next season increments the label and links on save', () {
      final a = rec('a', '葬送的芙莉莲', titleJa: '葬送のフリーレン');
      final prefill = NextSeasonPrefill.after(a);
      expect(prefill.season, 'Season 2');
      expect(prefill.title, '葬送的芙莉莲');
      expect(prefill.linkToAnimeId, 'a');
      expect(
        NextSeasonPrefill.after(rec('b', 'x', season: '第一季')).season,
        '第二季',
      );
      expect(
        NextSeasonPrefill.after(rec('c', '葬送的芙莉莲 第二季')).season,
        'Season 3',
      );

      final created = rec('new', '葬送的芙莉莲 第二季', season: prefill.season);
      final editor = SeriesEditor(
        SeriesIndex.build([a]),
        now: now,
        newId: newId,
      );
      final writes = editor.link(created, a);
      expect(writes.map((w) => w.id).toSet(), {'a', 'new'});
    });
  });
}
