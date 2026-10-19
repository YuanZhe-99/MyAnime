import '../../ai/services/insight_prompts.dart';
import '../models/anime.dart';

/// How many categories, studios or titles one fact line lists at most.
const int statsInsightMaxNames = 3;

/// The smallest number of tracked anime a category needs before its drop
/// rate is worth naming.
const int statsInsightMinCategorySample = 3;

/// The gap between a personal and an external score, on 0–10, that counts as
/// a notable divergence.
const double statsInsightDivergence = 1.5;

/// The slots the summary view's card asks for.
const List<InsightSlot> statsSummaryInsightSlots = [
  InsightSlot(
    'pace',
    'Compare this period\'s completion and drop rates against the previous '
        'period to sum up viewing momentum.',
  ),
  InsightSlot(
    'taste',
    'Highlight which categories or studios dominated this period and how they '
        'relate to completed vs dropped shows.',
  ),
  InsightSlot(
    'backlogAdvice',
    'Recommend one concrete action for the watching or not-started backlog, '
        'naming a specific title to finish or drop when available.',
  ),
];

/// The slots the ranking view's card asks for.
const List<InsightSlot> statsRankingInsightSlots = [
  InsightSlot(
    'ratingProfile',
    'Characterize the user\'s rating strictness and which sub-score dimension '
        '(story, visuals, music, character) drives their top ratings.',
  ),
  InsightSlot(
    'divergence',
    'Point out the most notable gap between personal ratings and external '
        'database scores to highlight their unique taste.',
  ),
];

/// Purpose: Format a share as a whole percent.
/// Inputs: `part`, `whole`.
/// Returns: `int` — 0 when `whole` is 0.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
int _pct(int part, int whole) => whole == 0 ? 0 : (part * 100 / whole).round();

/// Purpose: Count the watched episodes of an anime.
/// Inputs: `anime`.
/// Returns: `int`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
int _watched(Anime anime) => anime.episodeStatuses.values
    .where((s) => s == EpisodeStatus.watched)
    .length;

/// Purpose: Rank names by how often they occur, most first.
/// Inputs: `counts`.
/// Returns: `List<String>` — ties broken by name for a stable fingerprint.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
List<String> _ranked(Map<String, int> counts) =>
    counts.keys.toList()..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : a.compareTo(b);
    });

/// Purpose: Build the Statistics summary card's facts for one period.
/// Inputs: `now` — local time; `period` — e.g. `2026 Q3`, `2026` or
/// `all time`; `current` — the anime the summary view counts for the period;
/// `previous` — the same for the period before, or null for all time;
/// `categoriesOf` — resolved category ids (user, mapped or AI);
/// `includeTitles` — false for the fallback that names no title.
/// Returns: `InsightFacts?` — null when the period tracks nothing.
/// Side effects: None.
/// Notes: Added in 1.9.1. The page passes the lists its own filters produce,
/// so the card and the view count the same anime. Rates are worked out here:
/// completion and drop rates and their change in percentage points, the
/// backlog (watching plus not started), the top three categories and studios,
/// the category dropped most often (at least
/// [statsInsightMinCategorySample] tracked), and up to two backlog titles —
/// the watching one with the fewest episodes left and the not-started one
/// rated highest elsewhere. Titles, studios and category ids are quoted
/// terms. Notes, ratings of single episodes and watch dates are never sent.
InsightFacts? buildStatsSummaryInsightFacts({
  required DateTime now,
  required String period,
  required List<Anime> current,
  List<Anime>? previous,
  required List<String> Function(Anime anime) categoriesOf,
  bool includeTitles = true,
}) {
  if (current.isEmpty) return null;
  final quoted = <String>{};
  ({int tracked, int completed, int dropped, int watching, int notStarted})
  counts(List<Anime> list) {
    var completed = 0, dropped = 0, watching = 0, notStarted = 0;
    for (final a in list) {
      switch (a.viewingStatus) {
        case AnimeViewingStatus.completed:
          completed++;
        case AnimeViewingStatus.dropped:
          dropped++;
        case AnimeViewingStatus.watching:
          watching++;
        case AnimeViewingStatus.notStarted:
          notStarted++;
      }
    }
    return (
      tracked: list.length,
      completed: completed,
      dropped: dropped,
      watching: watching,
      notStarted: notStarted,
    );
  }

  final c = counts(current);
  final lines = <String>[
    '- Today: ${factDate(now)}',
    '- Period: $period',
    '- Tracked: ${c.tracked}; completed ${c.completed} '
        '(${_pct(c.completed, c.tracked)}%), dropped ${c.dropped} '
        '(${_pct(c.dropped, c.tracked)}%), watching ${c.watching}, '
        'not started ${c.notStarted}',
    '- Backlog (watching or not started): ${c.watching + c.notStarted}',
  ];
  if (previous != null && previous.isNotEmpty) {
    final p = counts(previous);
    String points(int now, int was) {
      final d = now - was;
      return '${d >= 0 ? '+' : ''}$d points';
    }

    lines.add(
      '- Previous period: tracked ${p.tracked}, completion '
      '${_pct(p.completed, p.tracked)}%, drop ${_pct(p.dropped, p.tracked)}%; '
      'change: completion '
      '${points(_pct(c.completed, c.tracked), _pct(p.completed, p.tracked))}, '
      'drop ${points(_pct(c.dropped, c.tracked), _pct(p.dropped, p.tracked))}, '
      'tracked ${c.tracked - p.tracked >= 0 ? '+' : ''}'
      '${c.tracked - p.tracked}',
    );
  } else if (previous != null) {
    lines.add('- Previous period: nothing tracked');
  }

  // Categories and studios, and how they ended.
  final catCount = <String, int>{};
  final catDropped = <String, int>{};
  final studioCount = <String, int>{};
  for (final a in current) {
    for (final id in categoriesOf(a)) {
      catCount[id] = (catCount[id] ?? 0) + 1;
      if (a.viewingStatus == AnimeViewingStatus.dropped) {
        catDropped[id] = (catDropped[id] ?? 0) + 1;
      }
    }
    for (final s in a.externalMeta?.studios ?? const <String>[]) {
      studioCount[s] = (studioCount[s] ?? 0) + 1;
    }
  }
  if (catCount.isNotEmpty) {
    final top = _ranked(catCount).take(statsInsightMaxNames).toList();
    quoted.addAll([
      for (final id in top) ...[id, id.replaceAll('_', ' ')],
    ]);
    lines.add(
      '- Top categories: ${[for (final id in top) '$id ${catCount[id]}'].join(', ')}',
    );
    final dropRates =
        [
          for (final id in catCount.keys)
            if (catCount[id]! >= statsInsightMinCategorySample &&
                (catDropped[id] ?? 0) > 0)
              (id, _pct(catDropped[id]!, catCount[id]!)),
        ]..sort((a, b) {
          final byRate = b.$2.compareTo(a.$2);
          return byRate != 0 ? byRate : a.$1.compareTo(b.$1);
        });
    if (dropRates.isNotEmpty) {
      final (id, rate) = dropRates.first;
      quoted.addAll([id, id.replaceAll('_', ' ')]);
      lines.add(
        '- Most dropped category: $id ($rate% of ${catCount[id]} dropped)',
      );
    }
  }
  if (studioCount.isNotEmpty) {
    final top = _ranked(studioCount).take(statsInsightMaxNames).toList();
    quoted.addAll(top);
    lines.add(
      '- Top studios: ${[for (final s in top) '$s ${studioCount[s]}'].join(', ')}',
    );
  }

  // Backlog representatives.
  if (includeTitles) {
    final picks = <String>[];
    final watching =
        [
          for (final a in current)
            if (a.viewingStatus == AnimeViewingStatus.watching &&
                a.totalEpisodes != null &&
                a.totalEpisodes! > _watched(a))
              (a, a.totalEpisodes! - _watched(a)),
        ]..sort((a, b) {
          final byLeft = a.$2.compareTo(b.$2);
          return byLeft != 0
              ? byLeft
              : a.$1.displayTitle.compareTo(b.$1.displayTitle);
        });
    if (watching.isNotEmpty) {
      final (a, left) = watching.first;
      final title = clipTitle(a.displayTitle, 40);
      quoted.add(title);
      picks.add('$title (watching, $left episode${left == 1 ? '' : 's'} left)');
    }
    final waiting =
        [
          for (final a in current)
            if (a.viewingStatus == AnimeViewingStatus.notStarted &&
                a.externalMeta?.averageNormalizedScore != null)
              (a, a.externalMeta!.averageNormalizedScore!),
        ]..sort((a, b) {
          final byScore = b.$2.compareTo(a.$2);
          return byScore != 0
              ? byScore
              : a.$1.displayTitle.compareTo(b.$1.displayTitle);
        });
    if (waiting.isNotEmpty) {
      final (a, score) = waiting.first;
      final title = clipTitle(a.displayTitle, 40);
      quoted.add(title);
      picks.add(
        '$title (not started, rated ${score.toStringAsFixed(1)} externally)',
      );
    }
    if (picks.isNotEmpty) {
      lines.add('- Backlog candidates: ${picks.join('; ')}');
    }
  }

  return InsightFacts(
    module: InsightModule.statsSummary,
    lines: lines,
    slots: statsSummaryInsightSlots,
    quotedTerms: quoted.toList()..sort((a, b) => b.length.compareTo(a.length)),
  );
}

/// Purpose: Build the Statistics ranking card's facts.
/// Inputs: `now` — local time; `scope` — the ranking's time and type filter
/// in words, e.g. `2026 Q3, single-cour`; `pool` — the anime the ranking's
/// time and type filters keep; `includeTitles` — false for the fallback that
/// names no title.
/// Returns: `InsightFacts?` — null with fewer than three personally rated
/// anime.
/// Side effects: None.
/// Notes: Added in 1.9.1. Personal ratings (0–10, `effectiveOverall`) are
/// read whatever score the ranking is sorted by, because the card is about
/// the user's own taste. Worked out here: the count, mean and median, the
/// three highest and the lowest titles, the average of each sub-score with
/// at least three ratings (highest and strictest named), and the titles whose
/// personal score is at least [statsInsightDivergence] above or below their
/// external average. Titles are quoted terms.
InsightFacts? buildStatsRankingInsightFacts({
  required DateTime now,
  required String scope,
  required List<Anime> pool,
  bool includeTitles = true,
}) {
  final rated =
      [
        for (final a in pool)
          if (a.rating?.effectiveOverall != null)
            (a, a.rating!.effectiveOverall!),
      ]..sort((a, b) {
        final byScore = b.$2.compareTo(a.$2);
        return byScore != 0
            ? byScore
            : a.$1.displayTitle.compareTo(b.$1.displayTitle);
      });
  if (rated.length < 3) return null;
  final quoted = <String>{};
  String name(Anime a, double score) {
    if (!includeTitles) return score.toStringAsFixed(1);
    final title = clipTitle(a.displayTitle, 40);
    quoted.add(title);
    return '$title ${score.toStringAsFixed(1)}';
  }

  final scores = [for (final (_, s) in rated) s]..sort();
  final mean = scores.reduce((a, b) => a + b) / scores.length;
  final mid = scores.length ~/ 2;
  final median = scores.length.isOdd
      ? scores[mid]
      : (scores[mid - 1] + scores[mid]) / 2;
  final lines = <String>[
    '- Today: ${factDate(now)}',
    '- Ranking scope: $scope',
    '- Personally rated: ${rated.length}; mean ${mean.toStringAsFixed(1)}, '
        'median ${median.toStringAsFixed(1)} on a 0-10 scale',
    '- Highest rated: ${rated.take(3).map((e) => name(e.$1, e.$2)).join('; ')}',
    '- Lowest rated: ${name(rated.last.$1, rated.last.$2)}',
  ];

  const dims = {
    AnimeRatingField.story: 'story',
    AnimeRatingField.visual: 'visuals',
    AnimeRatingField.music: 'music',
    AnimeRatingField.character: 'character',
  };
  final averages = <String, double>{};
  for (final e in dims.entries) {
    final values = [
      for (final (a, _) in rated)
        if (a.rating!.scoreFor(e.key) != null) a.rating!.scoreFor(e.key)!,
    ];
    if (values.length >= 3) {
      averages[e.value] = values.reduce((a, b) => a + b) / values.length;
    }
  }
  if (averages.length >= 2) {
    final order = averages.keys.toList()
      ..sort((a, b) => averages[b]!.compareTo(averages[a]!));
    lines.add(
      '- Sub-score averages: ${[for (final d in order) '$d ${averages[d]!.toStringAsFixed(1)}'].join(', ')}; '
      'most generous ${order.first}, strictest ${order.last}',
    );
  }

  final gaps = [
    for (final (a, s) in rated)
      if (a.externalMeta?.averageNormalizedScore case final ext?)
        (a, s, ext, s - ext),
  ];
  final above = gaps.where((g) => g.$4 >= statsInsightDivergence).toList()
    ..sort((a, b) => b.$4.compareTo(a.$4));
  final below = gaps.where((g) => g.$4 <= -statsInsightDivergence).toList()
    ..sort((a, b) => a.$4.compareTo(b.$4));
  String gap((Anime, double, double, double) g) {
    var title = '';
    if (includeTitles) {
      final t = clipTitle(g.$1.displayTitle, 40);
      quoted.add(t);
      title = '$t ';
    }
    return '${title}personal ${g.$2.toStringAsFixed(1)} vs external '
        '${g.$3.toStringAsFixed(1)} '
        '(${g.$4 >= 0 ? '+' : ''}${g.$4.toStringAsFixed(1)})';
  }

  if (gaps.isNotEmpty) {
    lines.add(
      '- Compared with external scores: ${gaps.length} rated anime have one; '
      '${above.length} rated ${statsInsightDivergence.toStringAsFixed(1)} or '
      'more above, ${below.length} as much below',
    );
  }
  if (above.isNotEmpty) {
    lines.add('- Personal favorite above consensus: ${gap(above.first)}');
  }
  if (below.isNotEmpty) {
    lines.add('- Popular but not for them: ${gap(below.first)}');
  }

  return InsightFacts(
    module: InsightModule.statsRanking,
    lines: lines,
    slots: statsRankingInsightSlots,
    quotedTerms: quoted.toList()..sort((a, b) => b.length.compareTo(a.length)),
  );
}
