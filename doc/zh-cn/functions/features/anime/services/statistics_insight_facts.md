# lib/features/anime/services/statistics_insight_facts.dart

统计页面 AI 卡片背后的纯函数事实构建器（1.9.1）。`buildStatsSummaryInsightFacts` 接收总览视图在某时间段计数的作品（以及上一季度或上一年的），算出完结率和弃番率及其百分点变化、积压、最常见的分类和制作公司、弃番最多的分类以及积压中至多两部作品；`buildStatsRankingInsightFacts` 接收排行的时间和类型筛选保留的作品，算出个人评分的均值和中位数、最高和最低的作品、分项均分以及个人评分与外部评分差距最大的作品。两者都有不含标题的变体，用作 `fallbackFacts`。参见[端侧 AI — 统计页洞察卡片](../../../../on-device-ai.md#statistics-insight-cards)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `_pct` | 私有声明 | B | 把占比格式化为整数百分比。 |
| `_watched` | 私有声明 | B | 统计一部作品已看的集数。 |
| `_ranked` | 私有声明 | B | 按出现次数从多到少排列名称。 |
| `buildStatsSummaryInsightFacts` | 声明 | A | 为一个时间段构建统计总览卡片的事实。 |
| `buildStatsRankingInsightFacts` | 声明 | A | 构建统计排行卡片的事实。 |

`grep -c 'Purpose:' lib/features/anime/services/statistics_insight_facts.dart` 报告 5，每个一行。
