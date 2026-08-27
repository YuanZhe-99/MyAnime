import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/models/anime.dart';
import 'package:my_anime/features/anime/services/anime_search_service.dart';
import 'package:my_anime/l10n/app_localizations.dart';
import 'package:my_anime/l10n/app_localizations_en.dart';
import 'package:my_anime/l10n/app_localizations_zh.dart';

/// Pure-function coverage for the search service's parsing and ranking logic.
///
/// The HTTP calls themselves are static and take no injectable client, so the
/// network paths are deliberately not exercised here — only the mappers and
/// scorers, which is where the format-specific risk lives.
void main() {
  group('relevance ranking', () {
    test('scores a result by its best-matching title, in any language', () {
      const result = AnimeSearchResult(
        source: 'AniList',
        title: 'Frieren: Beyond Journey\'s End',
        titleJa: '葬送のフリーレン',
        titleRomaji: 'Sousou no Frieren',
      );
      final variants = AnimeSearchService.queryVariants('葬送のフリーレン');
      expect(AnimeSearchService.relevance(result, variants), greaterThan(0.9));
    });

    test('a Simplified query still matches a Traditional title', () {
      const result = AnimeSearchResult(source: 'bangumi.tv', title: '葬送的芙莉蓮');
      final variants = AnimeSearchService.queryVariants('葬送的芙莉莲');
      expect(AnimeSearchService.relevance(result, variants), greaterThan(0.9));
    });

    test('an unrelated title scores far below a matching one', () {
      const match = AnimeSearchResult(source: 'AniList', title: 'Steins;Gate');
      const other = AnimeSearchResult(source: 'AniList', title: 'Bocchi the Rock!');
      final variants = AnimeSearchService.queryVariants('Steins;Gate');
      expect(
        AnimeSearchService.relevance(match, variants),
        greaterThan(AnimeSearchService.relevance(other, variants)),
      );
    });

    test('the UI language settles a near-tie but cannot override a real gap', () {
      const chinese = AnimeSearchResult(source: 'bangumi.tv', title: '葬送的芙莉莲');
      const english = AnimeSearchResult(
        source: 'AniList',
        title: 'Frieren',
        titleEn: 'Frieren',
      );
      final variants = AnimeSearchService.queryVariants('葬送的芙莉莲');

      // Same query, Chinese UI: the Chinese-titled hit wins.
      expect(
        AnimeSearchService.relevance(chinese, variants, preferredLanguage: 'zh'),
        greaterThan(
          AnimeSearchService.relevance(
            english,
            variants,
            preferredLanguage: 'zh',
          ),
        ),
      );

      // The bonus must not lift a poor match over a good one.
      const poorButEnglish = AnimeSearchResult(
        source: 'AniList',
        title: 'Bocchi the Rock!',
        titleEn: 'Bocchi the Rock!',
      );
      expect(
        AnimeSearchService.relevance(
          chinese,
          variants,
          preferredLanguage: 'en',
        ),
        greaterThan(
          AnimeSearchService.relevance(
            poorButEnglish,
            variants,
            preferredLanguage: 'en',
          ),
        ),
      );
    });

    test('queryVariants keeps the raw query first and drops duplicates', () {
      final variants = AnimeSearchService.queryVariants('Steins;Gate');
      expect(variants.first, 'Steins;Gate');
      expect(variants.length, 1);
    });
  });

  group('allTitles', () {
    test('deduplicates and drops blanks across every title field', () {
      const result = AnimeSearchResult(
        source: 'MyAnimeList',
        title: 'Frieren',
        titleJa: '葬送のフリーレン',
        titleRomaji: 'Frieren',
        titleEn: '   ',
        synonyms: ['Frieren at the Funeral'],
      );
      expect(result.allTitles, [
        'Frieren',
        '葬送のフリーレン',
        'Frieren at the Funeral',
      ]);
      expect(result.displayTitle, 'Frieren');
    });
  });

  group('bangumi.tv v0 mapping', () {
    // Shaped after a real /v0/search/subjects response.
    final subject = <String, dynamic>{
      'id': 400602,
      'name': '葬送のフリーレン',
      'name_cn': '葬送的芙莉莲',
      'date': '2023-09-29',
      'eps': 28,
      'total_episodes': 36,
      'image': 'https://lain.bgm.tv/pic/cover/l/13/c5/400602_ZI8Y9.jpg',
      'rating': {'score': 8.5, 'total': 36032, 'rank': 41},
      'tags': [
        {'name': '奇幻', 'count': 100},
        {'name': '冒险', 'count': 90},
      ],
      'infobox': [
        {'key': '中文名', 'value': '葬送的芙莉莲'},
        {
          'key': '别名',
          'value': [
            {'v': "Frieren: Beyond Journey's End"},
            {'v': 'Sousou no Frieren'},
            {'v': '葬送的芙莉蓮'},
          ],
        },
        {'key': '话数', 'value': '28'},
        {'key': '放送开始', 'value': '2023年9月29日'},
        {'key': '放送星期', 'value': '星期五'},
        {'key': '播放结束', 'value': '2024年3月22日'},
        {'key': '动画制作', 'value': 'MADHOUSE'},
      ],
    };

    test('reads titles, schedule, studio, and rating out of a v0 subject', () {
      final result = AnimeSearchService.mapBangumiSubject(subject);
      expect(result.source, 'bangumi.tv');
      expect(result.sourceUrl, 'https://bgm.tv/subject/400602');
      expect(result.title, '葬送的芙莉莲');
      expect(result.titleJa, '葬送のフリーレン');
      expect(result.synonyms, [
        "Frieren: Beyond Journey's End",
        'Sousou no Frieren',
        '葬送的芙莉蓮',
      ]);
      // `eps` (the TV run) wins over `total_episodes`, which counts specials.
      expect(result.episodes, 28);
      expect(result.firstAirDate, DateTime(2023, 9, 29));
      expect(result.endDate, DateTime(2024, 3, 22));
      expect(result.airDayOfWeek, DateTime.friday);
      expect(result.studios, ['MADHOUSE']);
      expect(result.genres, ['奇幻', '冒险']);
      expect(result.score, 8.5);
      expect(result.scoreVotes, 36032);
      expect(result.scoreRank, 41);
      expect(result.coverImageUrl, contains('lain.bgm.tv'));
    });

    test('a subject with no infobox still maps its top-level fields', () {
      final result = AnimeSearchService.mapBangumiSubject({
        'id': 1,
        'name': 'Example',
        'date': '2020-01-05',
      });
      expect(result.titleJa, 'Example');
      expect(result.firstAirDate, DateTime(2020, 1, 5));
      expect(result.airDayOfWeek, isNull);
      expect(result.synonyms, isEmpty);
      expect(result.studios, isEmpty);
    });

    test('parseBangumiWeekday accepts Simplified, Traditional, and Japanese', () {
      expect(AnimeSearchService.parseBangumiWeekday('星期一'), 1);
      expect(AnimeSearchService.parseBangumiWeekday('星期五'), 5);
      expect(AnimeSearchService.parseBangumiWeekday('週六'), 6);
      expect(AnimeSearchService.parseBangumiWeekday('周日'), 7);
      expect(AnimeSearchService.parseBangumiWeekday('星期天'), 7);
      expect(AnimeSearchService.parseBangumiWeekday('金曜日'), 5);
      expect(AnimeSearchService.parseBangumiWeekday('日曜日'), 7);
      // An unrecognized value must become "no data", never a guess.
      expect(AnimeSearchService.parseBangumiWeekday('不定期'), isNull);
      expect(AnimeSearchService.parseBangumiWeekday(''), isNull);
      expect(AnimeSearchService.parseBangumiWeekday(null), isNull);
    });
  });

  group('result count label', () {
    // The two placeholders are both ints, so swapping them compiles cleanly and
    // only shows up as nonsense on screen ("28 of 7 results"). Pin the order.
    test('reads "<shown> of <total>", not the reverse', () {
      final AppLocalizations en = AppLocalizationsEn();
      expect(en.searchResultCount(7, 28), '7 of 28 results');
    });

    test('every locale places shown and total consistently', () {
      final AppLocalizations zh = AppLocalizationsZh();
      // zh phrases it as "共 <total> 条，显示 <shown> 条".
      final text = zh.searchResultCount(7, 28);
      expect(text, contains('28'));
      expect(text, contains('7'));
      expect(text.indexOf('28'), lessThan(text.indexOf('7')));
    });
  });

  group('title script detection', () {
    test('a romanized alias is usable as a Latin backfill query', () {
      // bangumi.tv files romaji and English titles under `synonyms`, so the
      // Latin harvest has to recognize them by script rather than by field.
      const r = AnimeSearchResult(
        source: 'bangumi.tv',
        title: '葬送的芙莉莲',
        titleJa: '葬送のフリーレン',
        synonyms: ['Sousou no Frieren', '葬送的芙莉蓮'],
      );
      // allTitles keeps every form; the Chinese title stays first for display.
      expect(r.displayTitle, '葬送的芙莉莲');
      expect(r.allTitles, contains('Sousou no Frieren'));
    });
  });

  group('Jikan mapping', () {
    test('reads titles, studios, genres, score, and a Tokyo broadcast', () {
      final result = AnimeSearchService.mapJikanAnime({
        'url': 'https://myanimelist.net/anime/52991/Sousou_no_Frieren',
        'title': 'Sousou no Frieren',
        'titles': [
          {'type': 'Default', 'title': 'Sousou no Frieren'},
          {'type': 'Japanese', 'title': '葬送のフリーレン'},
          {'type': 'English', 'title': 'Frieren: Beyond Journey\'s End'},
          {'type': 'Synonym', 'title': 'Frieren at the Funeral'},
        ],
        'episodes': 28,
        'duration': '24 min per ep',
        'type': 'TV',
        'status': 'Finished Airing',
        'score': 9.3,
        'scored_by': 500000,
        'rank': 1,
        'aired': {'from': '2023-09-29T00:00:00+00:00', 'to': '2024-03-22T00:00:00+00:00'},
        'broadcast': {
          'day': 'Fridays',
          'time': '23:00',
          'timezone': 'Asia/Tokyo',
        },
        'studios': [
          {'name': 'Madhouse'},
        ],
        'genres': [
          {'name': 'Adventure'},
          {'name': 'Drama'},
        ],
      });

      expect(result.titleRomaji, 'Sousou no Frieren');
      expect(result.titleJa, '葬送のフリーレン');
      expect(result.titleEn, 'Frieren: Beyond Journey\'s End');
      expect(result.synonyms, ['Frieren at the Funeral']);
      expect(result.airDayOfWeek, 5);
      expect(result.airTime, '23:00');
      expect(result.durationMinutes, 24);
      expect(result.studios, ['Madhouse']);
      expect(result.genres, ['Adventure', 'Drama']);
      expect(result.score, 9.3);
      expect(result.endDate, isNotNull);
    });

    test('Jikan late-night broadcasts are refiled onto the previous day', () {
      final result = AnimeSearchService.mapJikanAnime({
        'title': 'Late Night Show',
        'aired': {'from': '2026-08-27T00:00:00+00:00'},
        'broadcast': {
          'day': 'Thursdays',
          'time': '01:00',
          'timezone': 'Asia/Tokyo',
        },
      });
      expect(result.airDayOfWeek, DateTime.wednesday);
      expect(result.airTime, '25:00');
      expect(result.firstAirDate!.day, 26);
    });

    test('a non-Tokyo broadcast timezone drops the time instead of mislabelling it', () {
      final result = AnimeSearchService.mapJikanAnime({
        'title': 'Example',
        'broadcast': {
          'day': 'Mondays',
          'time': '20:00',
          'timezone': 'America/New_York',
        },
      });
      expect(result.airDayOfWeek, 1);
      expect(result.airTime, isNull);
    });

    test('parseJikanDuration handles per-episode, hour, and missing forms', () {
      expect(AnimeSearchService.parseJikanDuration('24 min per ep'), 24);
      expect(AnimeSearchService.parseJikanDuration('23 min'), 23);
      expect(AnimeSearchService.parseJikanDuration('1 hr 35 min'), 95);
      expect(AnimeSearchService.parseJikanDuration('Unknown'), isNull);
      expect(AnimeSearchService.parseJikanDuration(null), isNull);
    });

    test('parseDayOfWeek accepts both singular and plural weekday names', () {
      expect(AnimeSearchService.parseDayOfWeek('Monday'), 1);
      expect(AnimeSearchService.parseDayOfWeek('Mondays'), 1);
      expect(AnimeSearchService.parseDayOfWeek('sun'), 7);
      expect(AnimeSearchService.parseDayOfWeek('someday'), isNull);
    });
  });

  group('AniList mapping', () {
    test('derives the broadcast weekday and time from the real airing schedule', () {
      // 2023-09-29T14:00:00Z is Friday 23:00 in Japan (UTC+9).
      final result = AnimeSearchService.mapAniListMedia({
        'title': {
          'romaji': 'Sousou no Frieren',
          'native': '葬送のフリーレン',
          'english': 'Frieren: Beyond Journey\'s End',
        },
        'synonyms': ['Frieren at the Funeral'],
        'episodes': 28,
        'duration': 24,
        'format': 'TV',
        'status': 'FINISHED',
        'genres': ['Adventure', 'Drama'],
        'startDate': {'year': 2023, 'month': 9, 'day': 29},
        'endDate': {'year': 2024, 'month': 3, 'day': 22},
        'studios': {
          'nodes': [
            {'name': 'Madhouse'},
          ],
        },
        'airingSchedule': {
          'nodes': [
            {'airingAt': 1695996000, 'episode': 1},
          ],
        },
        'averageScore': 92,
        'popularity': 300000,
        'siteUrl': 'https://anilist.co/anime/154587',
      });

      expect(result.airDayOfWeek, DateTime.friday);
      expect(result.airTime, '23:00');
      expect(result.score, closeTo(9.2, 0.001));
      expect(result.scoreMax, 10);
      expect(result.durationMinutes, 24);
      expect(result.studios, ['Madhouse']);
      expect(result.synonyms, ['Frieren at the Funeral']);
      expect(result.endDate, DateTime(2024, 3, 22));
    });

    test('a late-night slot is filed under the previous day as 25:00', () {
      // 2026-08-26T16:00:00Z == Thu 2026-08-27 01:00 JST, i.e. Wed 8/26 "25:00".
      final airingAt =
          DateTime.utc(2026, 8, 26, 16).millisecondsSinceEpoch ~/ 1000;
      final result = AnimeSearchService.mapAniListMedia({
        'title': {'romaji': 'Late Night Show'},
        // AniList records the wall-clock date of the first airing.
        'startDate': {'year': 2026, 'month': 8, 'day': 27},
        'airingSchedule': {
          'nodes': [
            {'airingAt': airingAt, 'episode': 1},
          ],
        },
      });

      expect(result.airDayOfWeek, DateTime.wednesday);
      expect(result.airTime, '25:00');
      // The first-air date must move with the weekday, or the forward-snap in
      // getEpisodeCalendarDate pushes episode 1 a week out.
      expect(result.firstAirDate, DateTime(2026, 8, 26));
    });

    test('a late-night result lands on the right JST calendar day', () {
      final airingAt =
          DateTime.utc(2026, 8, 26, 16).millisecondsSinceEpoch ~/ 1000;
      final result = AnimeSearchService.mapAniListMedia({
        'title': {'romaji': 'Late Night Show'},
        'startDate': {'year': 2026, 'month': 8, 'day': 27},
        'airingSchedule': {
          'nodes': [
            {'airingAt': airingAt, 'episode': 1},
          ],
        },
      });

      final anime = Anime.create(
        title: 'Late Night Show',
        firstAirDate: result.firstAirDate,
        airDayOfWeek: result.airDayOfWeek,
        airTime: result.airTime,
        endEpisode: 3,
      );

      // Filed under Wednesday 8/26 on the JST calendar...
      expect(anime.getEpisodeCalendarDate(1), DateTime(2026, 8, 26));
      expect(anime.getEpisodeCalendarDate(2), DateTime(2026, 9, 2));
      // ...while still resolving to the real 01:00 Thursday instant.
      expect(anime.getEpisodeAirDate(1), DateTime(2026, 8, 27, 1));
    });

    test('an evening slot is left exactly as the source reports it', () {
      // 2026-08-27T14:00:00Z == Thu 2026-08-27 23:00 JST — not late-night.
      final airingAt =
          DateTime.utc(2026, 8, 27, 14).millisecondsSinceEpoch ~/ 1000;
      final result = AnimeSearchService.mapAniListMedia({
        'title': {'romaji': 'Evening Show'},
        'startDate': {'year': 2026, 'month': 8, 'day': 27},
        'airingSchedule': {
          'nodes': [
            {'airingAt': airingAt, 'episode': 1},
          ],
        },
      });
      expect(result.airDayOfWeek, DateTime.thursday);
      expect(result.airTime, '23:00');
      expect(result.firstAirDate, DateTime(2026, 8, 27));
    });

    test('nextAiringEpisode wins over the schedule for a currently-airing show', () {
      final result = AnimeSearchService.mapAniListMedia({
        'title': {'romaji': 'Airing Now'},
        // 2024-01-03T16:30:00Z is Thursday 01:30 in Japan.
        'nextAiringEpisode': {'airingAt': 1704299400, 'episode': 5},
        'airingSchedule': {
          'nodes': [
            {'airingAt': 1695996000, 'episode': 1},
          ],
        },
      });
      // 01:30 JST is a late-night slot, so it is filed under Wednesday 25:30.
      expect(result.airDayOfWeek, DateTime.wednesday);
      expect(result.airTime, '25:30');
    });

    test('falls back to the first air date when nothing is scheduled', () {
      final result = AnimeSearchService.mapAniListMedia({
        'title': {'romaji': 'Old Show'},
        'startDate': {'year': 2011, 'month': 4, 'day': 6},
      });
      expect(result.airDayOfWeek, DateTime(2011, 4, 6).weekday);
      expect(result.airTime, isNull);
    });

    test('a partial start date yields no first air date at all', () {
      final result = AnimeSearchService.mapAniListMedia({
        'title': {'romaji': 'Unannounced'},
        'startDate': {'year': 2027, 'month': null, 'day': null},
      });
      expect(result.firstAirDate, isNull);
      expect(result.airDayOfWeek, isNull);
    });

    test('strips HTML out of the description', () {
      final result = AnimeSearchService.mapAniListMedia({
        'title': {'romaji': 'Example'},
        'description': 'First line.<br><i>Second</i> &amp; third.',
      });
      expect(result.summary, 'First line.\nSecond & third.');
    });
  });

  group('toExternalMeta', () {
    test('records the score together with the URL it can be refreshed from', () {
      final fetchedAt = DateTime.utc(2026, 8, 26, 12);
      const result = AnimeSearchResult(
        source: 'AniList',
        sourceUrl: 'https://anilist.co/anime/154587',
        titleRomaji: 'Sousou no Frieren',
        titleEn: 'Frieren',
        synonyms: ['Frieren at the Funeral'],
        format: 'TV',
        status: 'FINISHED',
        durationMinutes: 24,
        genres: ['Adventure'],
        studios: ['Madhouse'],
        score: 9.2,
        scoreVotes: 300000,
      );

      final meta = AnimeSearchService.toExternalMeta(
        result,
        fetchedAt: fetchedAt,
      );
      expect(meta.titleRomaji, 'Sousou no Frieren');
      expect(meta.studios, ['Madhouse']);
      expect(meta.refreshedAt, fetchedAt);
      expect(meta.ratings, hasLength(1));

      final rating = meta.ratings.single;
      expect(rating.source, 'AniList');
      expect(rating.sourceUrl, 'https://anilist.co/anime/154587');
      expect(rating.score, 9.2);
      expect(rating.votes, 300000);
      expect(rating.fetchedAt, fetchedAt);
    });

    test('a source with no score contributes metadata but no rating entry', () {
      const result = AnimeSearchResult(
        source: 'filmarks.com',
        sourceUrl: 'https://filmarks.com/animes/1/2',
        titleJa: '葬送のフリーレン',
      );
      final meta = AnimeSearchService.toExternalMeta(result);
      expect(meta.ratings, isEmpty);
    });
  });
}
