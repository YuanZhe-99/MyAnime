import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/ai/services/ai_insights_cache.dart';
import 'package:my_anime/features/anime/models/anime.dart';
import 'package:my_anime/features/recommendations/services/ai_reason_service.dart';
import 'package:my_anime/features/recommendations/services/recommendation_service.dart';

final _created = DateTime.utc(2024, 1, 1);
final _now = DateTime(2026, 9, 24, 12);

/// Purpose: Build a fixture record.
/// Inputs: see parameters.
/// Returns: `Anime`.
/// Side effects: None.
/// Notes: Test helper. `watched` marks that many episodes from 1 watched.
Anime rec(
  String id,
  String title, {
  int watched = 0,
  int end = 12,
  double? rating,
  List<String> genres = const [],
  List<String> studios = const [],
  double? score,
  DateTime? firstAirDate,
  DateTime? created,
}) => Anime(
  id: id,
  title: title,
  endEpisode: end,
  firstAirDate: firstAirDate,
  episodeStatuses: {
    for (var e = 1; e <= watched; e++) e: EpisodeStatus.watched,
  },
  rating: rating == null ? null : AnimeRating(overall: rating),
  externalMeta: genres.isEmpty && studios.isEmpty && score == null
      ? null
      : AnimeExternalMeta(
          genres: genres,
          studios: studios,
          ratings: [
            if (score != null)
              AnimeExternalRating(source: 'AniList', score: score),
          ],
        ),
  createdAt: created ?? _created,
  modifiedAt: _created,
);

List<String> ids(List<Recommendation> r) => [for (final x in r) x.anime.id];

void main() {
  test('preference reads ratings first, then completion', () {
    expect(preferenceOf(rec('a', 'a', rating: 10)), 1.0);
    expect(preferenceOf(rec('a', 'a', rating: 2)), -1.0);
    expect(preferenceOf(rec('a', 'a', watched: 12)), 0.5);
    expect(preferenceOf(rec('a', 'a')), 0.0);
  });

  test('the next season after a completed one ranks first', () {
    final out = RecommendationService.rank([
      rec(
        's1',
        '葬送的芙莉莲',
        watched: 12,
        rating: 9,
        firstAirDate: DateTime(2023, 9, 29),
      ),
      rec('s2', '葬送的芙莉莲 第二季', firstAirDate: DateTime(2026, 1, 16)),
      rec('other', 'Something else', score: 9.5),
    ], nowJst: _now);
    expect(ids(out).first, 's2');
    final reason = out.first.reasons.first;
    expect(reason, isA<NextAfterReason>());
    expect((reason as NextAfterReason).previous.id, 's1');
  });

  test('never offers season 3 before season 1 is started', () {
    final out = RecommendationService.rank([
      rec('a1', '夏目友人帐', firstAirDate: DateTime(2008, 7, 7)),
      rec('a2', '夏目友人帐 第二季', firstAirDate: DateTime(2009, 1, 5)),
      rec('a3', '夏目友人帐 第三季', firstAirDate: DateTime(2011, 7, 5)),
    ], nowJst: _now);
    expect(ids(out), ['a1']);
  });

  test('taste profile and studios lift matching candidates', () {
    final out = RecommendationService.rank([
      rec(
        'liked',
        'Liked',
        watched: 12,
        rating: 10,
        genres: ['Romance', 'School'],
        studios: ['Kyoto'],
      ),
      rec('match', 'Match', genres: ['Romance'], studios: ['Kyoto']),
      rec('miss', 'Miss', genres: ['Horror'], studios: ['Other']),
    ], nowJst: _now);
    expect(ids(out), ['match', 'miss']);
    final kinds = out.first.reasons.map((r) => r.runtimeType).toList();
    expect(kinds, contains(CategoryMatchReason));
    expect(kinds, contains(SameStudioReason));
  });

  test('hidden candidates are left out', () {
    final out = RecommendationService.rank(
      [rec('a', 'A'), rec('b', 'B')],
      insights: AiInsights(hiddenRecommendations: {'a'}),
      nowJst: _now,
    );
    expect(ids(out), ['b']);
  });

  test('cold start: external score, then newest added', () {
    final out = RecommendationService.rank([
      rec('old', 'Old', created: DateTime.utc(2020)),
      rec('new', 'New', created: DateTime.utc(2025)),
      rec('good', 'Good', score: 9.1, created: DateTime.utc(2019)),
    ], nowJst: _now);
    expect(ids(out), ['good', 'new', 'old']);
  });

  test(
    'watching with aired unwatched episodes is a candidate; caught up is not',
    () {
      final airing = rec(
        'airing',
        'Airing',
        watched: 1,
        firstAirDate: DateTime(2026, 9, 1),
      ).copyWith(airDayOfWeek: DateTime(2026, 9, 1).weekday, airTime: '23:00');
      final caughtUp = rec(
        'caught',
        'Caught',
        watched: 3,
        firstAirDate: DateTime(2026, 9, 10),
      ).copyWith(airDayOfWeek: DateTime(2026, 9, 10).weekday, airTime: '23:00');
      final out = RecommendationService.rank([airing, caughtUp], nowJst: _now);
      expect(ids(out), ['airing']);
      expect(out.first.reasons.whereType<CatchUpReason>(), isNotEmpty);
    },
  );

  group('AI reasons', () {
    test('keeps known numbers once, in the right script, under the cap', () {
      final long = 'x' * 200;
      final out = parseReasonReply(
        '1: Same studio as a show you loved.\n'
            '1: duplicate\n'
            '9: out of range\n'
            '2: 和你喜欢的作品同一工作室\n'
            '3: $long',
        3,
        'en',
      );
      expect(out, {1: 'Same studio as a show you loved.'});
      expect(parseReasonReply('**2.** 同一工作室的新作', 3, 'zh'), {2: '同一工作室的新作'});
    });

    test('chooses the request language and converts Chinese variants', () {
      final tw = ReasonLanguage.forLocale(const Locale('zh', 'TW'))!;
      expect(tw.localeTag, 'zh_TW');
      expect(tw.finish('这部动画'), '這部動畫');
      final twOnApple = ReasonLanguage.forLocale(
        const Locale('zh', 'TW'),
        localeSupported: false,
      )!;
      expect(twOnApple.localeTag, 'zh_CN');
      expect(twOnApple.finish('这部动画'), '這部動畫');
      expect(
        ReasonLanguage.forLocale(const Locale('ja'), localeSupported: false),
        isNull,
      );
      expect(ReasonLanguage.forLocale(const Locale('zh'))!.finish('這部'), '这部');
      expect(ReasonLanguage.forLocale(const Locale('en'))!.code, 'en');
    });
  });
}
