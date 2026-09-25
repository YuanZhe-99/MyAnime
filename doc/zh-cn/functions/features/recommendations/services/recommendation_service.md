# lib/features/recommendations/services/recommendation_service.dart

推荐中确定性的那一半（1.6.0，M5）：纯 Dart，不涉及模型。它对片库里自己的未开始和观看中的记录排序，并以带类型的
理由说明原因，由页面变成标签。权重是 `RecommendationWeights` 中的具名常量，集中在一处。可选的 AI 理由由
[`ai_reason_service.md`](ai_reason_service.md) 叠加。自 1.6.2 起，它还为详情页对一条记录的**相关推荐**列表排序
（`related`），为 `recommendations.json` 编码该列表的理由，并为缺失续作卡片生成用于垃圾箱的键。见
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `RecommendationReason.new` | 构造函数（`RecommendationReason`，sealed） | B | 创建一个理由；子类携带数据，界面负责本地化。 |
| `NextAfterReason.new` | 构造函数（`NextAfterReason`） | B | 「《…》的下一部」，携带它所接续的已看完成员。 |
| `CategoryMatchReason.new` | 构造函数（`CategoryMatchReason`） | B | 「与你评分高的作品相似：…」，携带至多两个共同分类 id，最强的在前。 |
| `SameStudioReason.new` | 构造函数（`SameStudioReason`） | B | 「与《…》同一制作公司」，携带喜欢的记录和制作公司。 |
| `ExternalScoreReason.new` | 构造函数（`ExternalScoreReason`） | B | 「AniList 8.9」，携带资料库名称和 0–10 分。 |
| `CatchUpReason.new` | 构造函数（`CatchUpReason`） | B | 「有新的集数待补」。 |
| `SharedCategoriesReason.new` | 构造函数（`SharedCategoriesReason`） | B | 相关推荐列表（1.6.2）：「同为恋爱、校园」，携带两条记录共有的至多两个分类。 |
| `SharedStudioReason.new` | 构造函数（`SharedStudioReason`） | B | 相关推荐列表（1.6.2）：「同为 <studio> 制作」。 |
| `RelatedByDatabaseReason.new` | 构造函数（`RelatedByDatabaseReason`） | B | 相关推荐列表（1.6.2）：资料库把两条记录列为关联作品，携带关联类型。 |
| `SharedTitleReason.new` | 构造函数（`SharedTitleReason`） | B | 相关推荐列表（1.6.2）：「标题相近」——共有的基础标题键。 |
| [`encodeRelatedReason`](#encoderelatedreason) | 顶层函数 | A | 为 `recommendations.json` 编码一条相关推荐理由（1.6.2）。 |
| [`decodeRelatedReason`](#decoderelatedreason) | 顶层函数 | A | 解码一条持久保存的相关推荐理由（1.6.2）。 |
| [`sequelTrashKey`](#sequeltrashkey) | 顶层函数 | A | 为缺失续作卡片生成用于去重和垃圾箱的键（1.6.2）。 |
| `Recommendation.new` | 构造函数（`Recommendation`） | B | 创建一个已排序的候选：记录、总分、至多三个理由。 |
| [`preferenceOf`](#preferenceof) | 顶层函数 | A | 读取用户对一条记录的喜爱程度。 |
| [`hasAiredUnwatched`](#hasairedunwatched) | 顶层函数 | A | 报告一条记录是否有已播出但未看的集。 |
| [`isAiring`](#isairing) | 顶层函数 | A | 报告一条记录是否正在播出。 |
| `RecommendationService._` | 构造函数（`RecommendationService`） | B | 禁止实例化；该服务只有静态成员。 |
| [`RecommendationService.rank`](#recommendationservice-rank) | 静态方法（`RecommendationService`） | A | 对接下来看什么排序。 |
| [`RecommendationService.related`](#recommendationservice-related) | 静态方法（`RecommendationService`） | A | 对与一条记录相关的片库记录排序（1.6.2）。 |
| [`RecommendationService._eligible`](#recommendationservice-_eligible) | 静态方法（`RecommendationService`） | A | 判断一条记录能否被推荐。 |
| [`RecommendationService._bestExternal`](#recommendationservice-_bestexternal) | 静态方法（`RecommendationService`） | A | 为理由标签挑出最高的外部评分。 |

`RecommendationWeights` 只含 `static const` 值，理由类的字段也没有 `/// Purpose:` 注释，因此都不作为行。权重如下：

| 常量 | 值 | 含义 |
|---|---|---|
| `nextInSeries` | 3.0 | 候选所在系列的上一个成员已看完 |
| `nextInSeriesRatedHigh` | 1.0 | 该成员评分达到 `highRating` 或更高时追加 |
| `highRating` | 8.0 | 达到或高于此分即视为「评分高」 |
| `categoryMatch` | 2.0 | 乘以口味画像与候选分类的余弦相似度 |
| `studioMatch` | 0.5 | 乘以最高的制作公司亲和度，钳制到 −1…1 |
| `externalScore` | 0.3 | 乘以外部平均分减 `externalPivot`，钳制到 ±2 |
| `externalPivot` | 7.0 | 视为中性的外部评分 |
| `catchUp` | 0.8 | 观看中且有已播出未看的集 |
| `airing` | 0.4 | 正在播出 |
| `globalBatch` | 10 | 全局页面每批的卡片数（1.6.2；之前为 30） |
| `relatedBatch` | 5 | 一条记录的相关推荐列表每批的条目数（1.6.2） |
| `relatedCategory` | 2.0 | 相关推荐列表：乘以两条记录的分类余弦相似度 |
| `relatedStudio` | 0.5 | 相关推荐列表：两条记录有相同的制作公司 |
| `relatedRelation` | 3.0 | 相关推荐列表：资料库把其中一条列为另一条的关联作品 |
| `relatedBaseTitle` | 1.0 | 相关推荐列表：两条记录有相同的基础标题键 |

## 文档

### `String? encodeRelatedReason(RecommendationReason reason)` <a id="encoderelatedreason"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/recommendations/services/recommendation_service.dart`（约第 193 行）
- **用途：** 把一条相关推荐理由转成存储代码。
- **输入：** `reason`。
- **返回：** `categories:<id>,<id>`、`studio:<name>`、`relation:<type>` 或 `baseTitle`；相关推荐列表不会产生的理由为
  null。
- **副作用：** 无。
- **算法：** 对四种相关推荐理由类型做一次 `switch`。
- **用法：** `RelatedRecommendationsCard._generate`。
- **备注：** 这些代码是 `recommendations.json` 中的持久格式：只能新增，永不改名。

### `RecommendationReason? decodeRelatedReason(String code)` <a id="decoderelatedreason"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/recommendations/services/recommendation_service.dart`（约第 208 行）
- **用途：** 把存储代码转回理由。
- **输入：** `code`。
- **返回：** `RecommendationReason?` — 本构建不认识的代码（包括不认识的关联类型）为 null。
- **副作用：** 无。
- **算法：** `baseTitle` 精确匹配；否则在第一个 `:` 处拆分并匹配前缀。
- **用法：** `RelatedRecommendationsCard._row`。
- **备注：** 未知代码留在磁盘上，只是不显示，因此新构建的标签在旧构建中得以保留。

### `String sequelTrashKey(AnimeExternalRelation sequel)` <a id="sequeltrashkey"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/recommendations/services/recommendation_service.dart`（约第 234 行）
- **用途：** 为缺失续作卡片生成键。
- **输入：** `sequel`。
- **返回：** `canonicalDatabaseKey(targetUrl)`（`anilist:1`、`mal:1`、`bgm:1`），否则 `targetUrl`，否则 `title`，否则为空。
- **副作用：** 无。
- **算法：** 取第一个存在的值。
- **用法：** 推荐页，用于给卡片去重，并作为 `hiddenSequels` 的键。
- **备注：** 1.6.1 及之前页面按原始 URL 去重，因此在 `bgm.tv` 和 `bangumi.tv` 下列出的同一部续作可能显示两次。

### `double preferenceOf(Anime anime)` <a id="preferenceof"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/recommendations/services/recommendation_service.dart`（约第 267 行）
- **用途：** 读取用户对一条记录的喜爱程度。
- **输入：** `anime`。
- **返回：** −1…1 之间的 `double`。
- **副作用：** 无。
- **算法：** 有评分时为 `(effectiveOverall − 6) / 4`，钳制到 −1…1。没有评分时：已看完 `+0.5`，弃坑 `−0.7`，其他 `0`。
- **用法：** `RecommendationService.rank`（口味画像、制作公司亲和度）和 `writeAiReasons`（精简画像）。
- **备注：** 评分总是优先于观看状态。

### `bool hasAiredUnwatched(Anime anime, DateTime nowJst)` <a id="hasairedunwatched"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/recommendations/services/recommendation_service.dart`（约第 282 行）
- **用途：** 报告一条记录是否有已播出但未看的集。
- **输入：** `anime`、`nowJst`。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** 取 `nextUnwatchedEpisode`；当它计算出的播出时间（`getEpisodeAirDate`）存在且不晚于 `nowJst` 时为真。
- **用法：** `_eligible` 以及 `rank` 中的补番加分。
- **备注：** 没有播出排期的记录永远不算有已播出的集。

### `bool isAiring(Anime anime, DateTime nowJst)` <a id="isairing"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/recommendations/services/recommendation_service.dart`（约第 295 行）
- **用途：** 报告一条记录是否正在播出。
- **输入：** `anime`、`nowJst`。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** `externalMeta.status` 为 `RELEASING`（AniList）或 `Currently Airing`（MyAnimeList）时为真。否则只有当首播
  不在未来、且最后一集的播出时间尚未到来时为真。
- **用法：** `rank` 中的播出中加分。
- **备注：** 播出中加分没有理由标签。

### `static List<Recommendation> rank(List<Anime> library, {AiInsights? insights, Set<String> hidden = const {}, required DateTime nowJst, int limit = RecommendationWeights.globalBatch})` <a id="recommendationservice-rank"></a>
- **种类：** `RecommendationService` 的静态方法
- **来源：** `lib/features/recommendations/services/recommendation_service.dart`（约第 328 行）
- **用途：** 对接下来看什么排序。
- **输入：** `library`；`insights` — 来自 `ai_insights.json` 的 AI 分类；`hidden` — 全局垃圾箱中的 id
  （`recommendations.json`，1.6.2）；`nowJst`；`limit` — 每批的数量，10（1.6.1 及之前为 30）。
- **返回：** `List<Recommendation>` — 最好的在前，至多 `limit` 条。
- **副作用：** 无。
- **算法：**
  1. 构建 `SeriesIndex`，并求出每条记录的有效分类（`resolveCategories`，带上 `insights` 中的 AI 分类）。
  2. **口味画像：** 对每条 `preferenceOf` 非零的记录，把它加到自己的每个分类上；**制作公司亲和度：** 把它加到自己的
     每个制作公司上，并记住每个制作公司最喜欢的记录。用欧氏长度归一化画像。
  3. **候选：** 跳过隐藏的 id。对于有两个或更多成员的系列，每个系列只考虑一次它的第一个未看完成员；如果该成员被隐藏
     或不满足 [`_eligible`](#recommendationservice-_eligible)，该系列就不提供候选。不属于此类系列的记录在满足条件时
     成为候选。
  4. 每个候选的**得分**为各项贡献之和：上一个成员已看完时 `nextInSeries`（加 `nextInSeriesRatedHigh`）；
     `categoryMatch ×` 画像与分类的余弦；`studioMatch ×` 最高的制作公司亲和度，钳制到 −1…1；
     `externalScore × (averageNormalizedScore − 7)`，钳制到 ±2；观看中且有已播出未看的集时 `catchUp`；
     [`isAiring`](#isairing) 时 `airing`。
  5. **理由：** 把各项贡献从大到小排序，保留为正且带理由的，至多三个。分类理由列出画像喜欢的至多两个共同分类；喜欢的
     记录就是候选本身时省略制作公司理由。
  6. **顺序：** 全库既无评分也无已看完记录时（冷启动），先是系列下一部，再按外部平均分，再按最新的 `createdAt`；否则按
     得分。平分时回退到 id，因此顺序稳定。
- **用法：** `_RecommendationsPageState._load`；`test/recommendations_test.dart`。
- **备注：** 第 1 季看完之前绝不推荐第 3 季。缺失续作（不在片库中）不在这里排序，由页面追加。

### `static List<Recommendation> related(Anime subject, List<Anime> library, {AiInsights? insights, Set<String> exclude = const {}, int limit = RecommendationWeights.relatedBatch})` <a id="recommendationservice-related"></a>
- **种类：** `RecommendationService` 的静态方法
- **来源：** `lib/features/recommendations/services/recommendation_service.dart`（约第 500 行）
- **用途：** 对与一条记录相关的片库记录排序（1.6.2）。
- **输入：** `subject`；`library`；`insights` — AI 分类；`exclude` — 主体记录自己的相关推荐垃圾箱；`limit` — 默认为 5。
- **返回：** `List<Recommendation>` — 最好的在前，每个得分都大于零。
- **副作用：** 无。
- **算法：**
  1. 跳过主体记录、它自己所在系列的每个成员（`SeriesIndex.seriesOf`）以及 `exclude`。
  2. 各项贡献，权重见下：两者之间任一方向的资料库关联关系——一方 `externalMeta.relations` 的目标与另一方的
     `databaseKeysOf` 匹配，任何类型——`relatedRelation`；两条记录有效分类集合的余弦，
     `|shared| / √(|a|·|b|)`，乘以 `relatedCategory`；相同的制作公司，`relatedStudio`；相同的
     `seriesBaseKeys` 键，`relatedBaseTitle`。
  3. 没有任何贡献的记录被丢弃。理由是从大到小排列的各项贡献，至多三个。
  4. **其他每个系列只保留一个成员：** 在有两个或更多成员的同一系列中，保留得分最高的；得分相同时取系列顺序中较早的成员。
  5. 按得分、再按 id 排序；截断到 `limit`。
- **用法：** `RelatedRecommendationsCard._generate`；`test/recommendations_test.dart`。
- **备注：** 观看状态不起作用：该列表回答「什么与它相似」，而不是「接下来看什么」。

### `static bool _eligible(Anime anime, DateTime nowJst)` <a id="recommendationservice-_eligible"></a>
- **种类：** `RecommendationService` 的静态方法（私有）
- **来源：** `lib/features/recommendations/services/recommendation_service.dart`（约第 604 行）
- **用途：** 判断一条记录能否被推荐。
- **输入：** `anime`、`nowJst`。
- **返回：** `bool` — 未开始，或观看中且有已播出未看的集时为真。
- **副作用：** 无。
- **算法：** 按 `viewingStatus` 分支：`notStarted` → 真；`watching` → [`hasAiredUnwatched`](#hasairedunwatched)；其他 → 假。
- **用法：** `rank` 第 3 步。
- **备注：** 已追平的观看中记录不是候选。

### `static ExternalScoreReason? _bestExternal(Anime anime)` <a id="recommendationservice-_bestexternal"></a>
- **种类：** `RecommendationService` 的静态方法（私有）
- **来源：** `lib/features/recommendations/services/recommendation_service.dart`（约第 616 行）
- **用途：** 为理由标签挑出最高的外部评分。
- **输入：** `anime`。
- **返回：** `ExternalScoreReason?` — 没有任何来源有归一化评分时为 null。
- **副作用：** 无。
- **算法：** 取 `externalMeta.ratings` 中 `normalizedScore` 最高的一项。
- **用法：** `rank` 的外部评分贡献。
- **备注：** 贡献使用所有来源的平均分；标签显示单个最高的来源。
