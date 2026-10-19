import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/ai/services/insight_prompts.dart';
import 'package:my_anime/features/anime/models/anime.dart';
import 'package:my_anime/features/anime/services/statistics_insight_facts.dart';

final _created = DateTime.utc(2026, 1, 1);

/// Purpose: Build one anime for the statistics facts.
/// Inputs: `id`; `watched` episodes of `end`; `dropped`; `rating` and
/// sub-scores; `external` score on 0–10; `studios`; `categories`.
/// Returns: `Anime`.
/// Side effects: None.
/// Notes: Test helper.
Anime _a(
  String id, {
  int watched = 0,
  int end = 12,
  bool dropped = false,
  double? rating,
  double? story,
  double? music,
  double? external,
  List<String> studios = const [],
  List<String> categories = const [],
}) => Anime(
  id: id,
  title: 'Title $id',
  endEpisode: end,
  categories: categories,
  // Dropped: every episode is watched or skipped, at least one skipped.
  episodeStatuses: {
    for (var e = 1; e <= watched; e++) e: EpisodeStatus.watched,
    if (dropped)
      for (var e = watched + 1; e <= end; e++) e: EpisodeStatus.skippedThisWeek,
  },
  rating: rating == null
      ? null
      : AnimeRating(overall: rating, story: story, music: music),
  externalMeta: AnimeExternalMeta(
    studios: studios,
    ratings: [
      if (external != null)
        AnimeExternalRating(source: 'bangumi.tv', score: external),
    ],
  ),
  createdAt: _created,
  modifiedAt: _created,
);

/// Purpose: Test the Statistics insight facts (1.9.1).
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: Rates and gaps are worked out in Dart, so they are checked exactly.
void main() {
  final now = DateTime(2026, 10, 19, 9);

  test('summary: rates, change, categories, studios and backlog', () {
    final current = [
      _a('1', watched: 12, studios: ['Madhouse'], categories: ['drama']),
      _a('2', watched: 12, studios: ['Madhouse'], categories: ['drama']),
      _a('3', dropped: true, watched: 2, categories: ['comedy']),
      _a('4', dropped: true, watched: 1, categories: ['comedy']),
      _a('5', watched: 10, categories: ['comedy']),
      _a('6', external: 8.8),
    ];
    final previous = [_a('p1', watched: 12), _a('p2')];
    final facts = buildStatsSummaryInsightFacts(
      now: now,
      period: '2026 Q3',
      current: current,
      previous: previous,
      categoriesOf: (a) => a.categories ?? const [],
    )!;
    final text = facts.lines.join('\n');
    expect(
      text,
      contains(
        '- Tracked: 6; completed 2 (33%), dropped 2 (33%), watching 1, '
        'not started 1',
      ),
    );
    expect(text, contains('change: completion -17 points, drop +33 points'));
    expect(text, contains('- Top categories: comedy 3, drama 2'));
    expect(
      text,
      contains('- Most dropped category: comedy (67% of 3 dropped)'),
    );
    expect(text, contains('- Top studios: Madhouse 2'));
    expect(
      text,
      contains(
        '- Backlog candidates: Title 5 (watching, 2 episodes left); '
        'Title 6 (not started, rated 8.8 externally)',
      ),
    );
    expect(facts.quotedTerms, containsAll(['Title 5', 'Madhouse', 'comedy']));
    expect(facts.module, InsightModule.statsSummary);
    final plain = buildStatsSummaryInsightFacts(
      now: now,
      period: '2026 Q3',
      current: current,
      categoriesOf: (a) => a.categories ?? const [],
      includeTitles: false,
    )!;
    expect(plain.lines.join('\n'), isNot(contains('Title ')));
    expect(plain.slots.map((s) => s.id), facts.slots.map((s) => s.id));
    expect(
      buildStatsSummaryInsightFacts(
        now: now,
        period: 'all time',
        current: const [],
        categoriesOf: (_) => const [],
      ),
      isNull,
    );
  });

  test('ranking: strictness, sub-scores and divergence', () {
    final pool = [
      _a('a', rating: 9.5, story: 9, music: 7, external: 7.5),
      _a('b', rating: 8, story: 8, music: 6, external: 8.2),
      _a('c', rating: 5, story: 6, music: 5, external: 8.0),
      _a('d', rating: 7),
      _a('e'),
    ];
    final facts = buildStatsRankingInsightFacts(
      now: now,
      scope: 'all time',
      pool: pool,
    )!;
    final text = facts.lines.join('\n');
    expect(text, contains('- Personally rated: 4; mean 7.4, median 7.5'));
    expect(
      text,
      contains('- Highest rated: Title a 9.5; Title b 8.0; Title d 7.0'),
    );
    expect(text, contains('- Lowest rated: Title c 5.0'));
    expect(
      text,
      contains(
        '- Sub-score averages: story 7.7, music 6.0; '
        'most generous story, strictest music',
      ),
    );
    expect(
      text,
      contains(
        '- Personal favorite above consensus: Title a personal 9.5 vs '
        'external 7.5 (+2.0)',
      ),
    );
    expect(
      text,
      contains(
        '- Popular but not for them: Title c personal 5.0 vs external 8.0 '
        '(-3.0)',
      ),
    );
    expect(
      buildStatsRankingInsightFacts(
        now: now,
        scope: 'x',
        pool: pool.take(2).toList(),
      ),
      isNull,
    );
  });
}
