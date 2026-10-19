# lib/features/anime/services/statistics_insight_facts.dart

The pure fact builders behind the Statistics page's AI cards (1.9.1). `buildStatsSummaryInsightFacts` takes the anime the summary view counts for a period (and the previous quarter's or year's) and works out completion and drop rates and their change in points, the backlog, the top categories and studios, the most-dropped category and up to two backlog titles; `buildStatsRankingInsightFacts` takes the anime the ranking's time and type filters keep and works out the personal mean and median, the highest and lowest titles, sub-score averages and the largest personal-versus-external gaps. Both have a title-free variant for `fallbackFacts`. See [On-device AI — Statistics insight cards](../../../../on-device-ai.md#statistics-insight-cards).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `_pct` | private declaration | B | Format a share as a whole percent. |
| `_watched` | private declaration | B | Count the watched episodes of an anime. |
| `_ranked` | private declaration | B | Rank names by how often they occur, most first. |
| `buildStatsSummaryInsightFacts` | declaration | A | Build the Statistics summary card's facts for one period. |
| `buildStatsRankingInsightFacts` | declaration | A | Build the Statistics ranking card's facts. |

`grep -c 'Purpose:' lib/features/anime/services/statistics_insight_facts.dart` reports 5, one row each.
