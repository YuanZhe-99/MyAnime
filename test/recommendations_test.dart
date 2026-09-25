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

  test('trashed candidates are left out', () {
    final out = RecommendationService.rank(
      [rec('a', 'A'), rec('b', 'B')],
      hidden: {'a'},
      nowJst: _now,
    );
    expect(ids(out), ['b']);
  });

  test('the per-device hidden list no longer hides anything', () {
    // Since 1.6.2 the trash lives in the synced recommendations.json; the
    // old list is only read to migrate it.
    final out = RecommendationService.rank(
      [rec('a', 'A'), rec('b', 'B')],
      insights: AiInsights(hiddenRecommendations: {'a'}),
      nowJst: _now,
    );
    expect(ids(out), containsAll(['a', 'b']));
  });

  test('a batch is ten by default', () {
    final out = RecommendationService.rank([
      for (var i = 0; i < 15; i++) rec('r$i', 'Title $i'),
    ], nowJst: _now);
    expect(out, hasLength(RecommendationWeights.globalBatch));
    expect(RecommendationWeights.globalBatch, 10);
  });

  test('a trashed first member keeps the rest of its series out', () {
    AnimeSeriesLink link(int order) => AnimeSeriesLink(
      seriesId: '11111111-1111-4111-8111-111111111111',
      order: order,
    );
    final s1 = rec('s1', 'Show').copyWith(seriesLink: link(1));
    final s2 = rec('s2', 'Show 2').copyWith(seriesLink: link(2));
    final out = RecommendationService.rank(
      [s1, s2, rec('other', 'Other')],
      hidden: {'s1'},
      nowJst: _now,
    );
    expect(ids(out), ['other']);
  });

  group('related', () {
    test('ranks by shared categories, studio and database relations', () {
      final subject = rec(
        'subject',
        'Subject',
        genres: ['Romance', 'School'],
        studios: ['Madhouse'],
      ).copyWith(infoUrl: 'https://anilist.co/anime/1');
      final spinOff = rec('spin', 'Spin', genres: ['Action']).copyWith(
        infoUrl: 'https://anilist.co/anime/2/slug',
        externalMeta: const AnimeExternalMeta(
          relations: [
            AnimeExternalRelation(
              source: 'AniList',
              type: AnimeRelationType.spinOff,
              targetUrl: 'https://anilist.co/anime/1',
            ),
          ],
        ),
      );
      final alike = rec(
        'alike',
        'Alike',
        genres: ['Romance', 'School'],
        studios: ['Madhouse'],
      );
      final unrelated = rec('none', 'None', genres: ['Horror']);
      final out = RecommendationService.related(subject, [
        subject,
        spinOff,
        alike,
        unrelated,
      ]);
      expect(ids(out), ['spin', 'alike']);
      expect(out.first.reasons.first, isA<RelatedByDatabaseReason>());
      final kinds = out[1].reasons.map((r) => r.runtimeType).toList();
      expect(kinds, [SharedCategoriesReason, SharedStudioReason]);
    });

    test('leaves out the subject, its own series and its trash', () {
      AnimeSeriesLink link(int order) => AnimeSeriesLink(
        seriesId: '22222222-2222-4222-8222-222222222222',
        order: order,
      );
      final subject = rec(
        'subject',
        'Subject',
        genres: ['Romance'],
      ).copyWith(seriesLink: link(1));
      final sibling = rec(
        'sibling',
        'Sibling',
        genres: ['Romance'],
      ).copyWith(seriesLink: link(2));
      final trashed = rec('trashed', 'Trashed', genres: ['Romance']);
      final kept = rec('kept', 'Kept', genres: ['Romance']);
      final out = RecommendationService.related(
        subject,
        [subject, sibling, trashed, kept],
        exclude: {'trashed'},
      );
      expect(ids(out), ['kept']);
    });

    test('offers one member per other series and at most five', () {
      AnimeSeriesLink link(int order) => AnimeSeriesLink(
        seriesId: '33333333-3333-4333-8333-333333333333',
        order: order,
      );
      final subject = rec('subject', 'Subject', genres: ['Romance']);
      final library = [
        subject,
        rec('a1', 'A', genres: ['Romance']).copyWith(seriesLink: link(1)),
        rec('a2', 'A 2', genres: ['Romance']).copyWith(seriesLink: link(2)),
        for (var i = 0; i < 8; i++) rec('x$i', 'X$i', genres: ['Romance']),
      ];
      final out = RecommendationService.related(subject, library);
      expect(out, hasLength(RecommendationWeights.relatedBatch));
      expect(ids(out).where((id) => id.startsWith('a')), hasLength(1));
      expect(ids(out), contains('a1'));
    });

    test('reason codes round-trip, unknown codes are skipped', () {
      const reasons = <RecommendationReason>[
        SharedCategoriesReason(['romance', 'school']),
        SharedStudioReason('Madhouse'),
        RelatedByDatabaseReason(AnimeRelationType.alternative),
        SharedTitleReason(),
      ];
      final codes = [for (final r in reasons) encodeRelatedReason(r)!];
      expect(codes, [
        'categories:romance,school',
        'studio:Madhouse',
        'relation:alternative',
        'baseTitle',
      ]);
      final back = [for (final c in codes) decodeRelatedReason(c)];
      expect(back.map((r) => r.runtimeType), [
        SharedCategoriesReason,
        SharedStudioReason,
        RelatedByDatabaseReason,
        SharedTitleReason,
      ]);
      expect(decodeRelatedReason('future:thing'), isNull);
      expect(decodeRelatedReason('relation:unknownType'), isNull);
      expect(encodeRelatedReason(const CatchUpReason()), isNull);
    });

    test('sequel trash keys use the canonical database key', () {
      const a = AnimeExternalRelation(
        source: 'bangumi.tv',
        type: AnimeRelationType.sequel,
        targetUrl: 'https://bangumi.tv/subject/42',
      );
      const b = AnimeExternalRelation(
        source: 'bangumi.tv',
        type: AnimeRelationType.sequel,
        targetUrl: 'https://bgm.tv/subject/42',
      );
      expect(sequelTrashKey(a), 'bgm:42');
      expect(sequelTrashKey(b), sequelTrashKey(a));
      expect(
        sequelTrashKey(
          const AnimeExternalRelation(
            source: 'X',
            type: AnimeRelationType.sequel,
            title: 'Only a title',
          ),
        ),
        'Only a title',
      );
    });
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
