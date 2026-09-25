# lib/features/recommendations/views/related_card.dart

`RelatedRecommendationsCard`（1.6.2）是详情页的「相关推荐」卡片：至多五条与本作品相似的片库记录，由
[`RecommendationService.related`](../services/recommendation_service.md#recommendationservice-related)
排序并**持久保存**在 `recommendations.json` 中，因此在用户换一批之前，每次访问、每台设备上看到的列表都相同。
换一批会把当前显示的一批放进该记录自己的垃圾箱并生成下一批；每行的 ✕ 把一条移入垃圾箱；菜单打开该记录的垃圾箱。
详情页只在推荐开启时显示这张卡片。见
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md#详情页的相关推荐)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `RelatedRecommendationsCard.new` | 构造函数 | B | 基于 `library` 为 `anime` 创建卡片。 |
| `RelatedRecommendationsCard.createState` | 方法 | B | 创建状态对象。 |
| `_RelatedRecommendationsCardState.initState` | 方法 | B | 向自动同步注册并加载。 |
| `_RelatedRecommendationsCardState.didUpdateWidget` | 方法 | B | 换成另一条记录时重新加载；仅片库变化不会重新生成任何内容。 |
| `_RelatedRecommendationsCardState.dispose` | 方法 | B | 从自动同步注销。 |
| [`_load`](#_load) | 方法 | A | 读取已持久保存的列表，首次时生成它。 |
| [`_generate`](#_generate) | 方法 | A | 排出新列表并保存，然后请模型写理由。 |
| [`_aiReasons`](#_aireasons) | 方法 | A | 在端侧模型能回答时请它写理由。 |
| [`_refresh`](#_refresh) | 方法 | A | 把当前显示的一批移入垃圾箱并生成下一批。 |
| `_hide` | 方法 | B | 把一条相关记录移入垃圾箱；列表会变短，直到下次换一批。 |
| `_openTrash` | 方法 | B | 压栈 `/recommendations/trash?anime=<id>`，然后重新加载。 |
| [`_resolved`](#_resolved) | getter | A | 把每个已保存的条目与其记录配对。 |
| [`build`](#build) | 方法 | A | 构建卡片。 |
| `_row` | 方法 | B | 构建一行：封面、标题、理由标签、带标注的 AI 理由、✕。 |

`_RelatedAction`（`refresh`、`trash`）是菜单的私有枚举，没有注释。

## 文档

### `Future<void> _load()` <a id="_load"></a>
- **种类：** `_RelatedRecommendationsCardState` 的方法
- **来源：** `lib/features/recommendations/views/related_card.dart`（约第 104 行）
- **用途：** 显示已保存的列表，或生成一个。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 读取 `recommendations.json`；尚未为该记录生成过列表时写入它。
- **算法：** 加载存储。`related[id]` 不存在或不是 `isGenerated` 时，以其垃圾箱调用 `_generate`；否则直接显示。
- **用法：** `initState`、自动同步的本地数据回调、垃圾箱页返回之后。
- **备注：** 从另一台设备同步来的列表按原样显示；除了换一批，没有任何操作会重新生成它。

### `Future<void> _generate(Set<String> exclude)` <a id="_generate"></a>
- **种类：** `_RelatedRecommendationsCardState` 的方法
- **来源：** `lib/features/recommendations/views/related_card.dart`（约第 122 行）
- **用途：** 生成并持久保存一个新列表。
- **输入：** `exclude` — 该记录的垃圾箱。
- **返回：** 无。
- **副作用：** 为列表写入一次 `recommendations.json`，模型写出理由时再写一次；可能运行一次模型。
- **算法：** 1) `AiInsightsCache.load()` 取得 AI 分类。2)
  `RecommendationService.related(anime, library, insights:, exclude:)`。3) 用 `encodeRelatedReason` 编码每条理由，
  以同一个 `generatedAt` 调用 `putRelated`；显示它。4) `_aiReasons`；有理由返回时，填好 `aiReason`、以相同的
  `generatedAt` 再次调用 `putRelated`。
- **用法：** `_load`、`_refresh`。
- **备注：** 由 `_busy` 保护，因此生成期间的同步重新加载不会再启动一次生成。

### `Future<Map<String, String>> _aiReasons(List<Recommendation> ranked, AiInsights insights)` <a id="_aireasons"></a>
- **种类：** `_RelatedRecommendationsCardState` 的方法
- **来源：** `lib/features/recommendations/views/related_card.dart`（约第 167 行）
- **用途：** 取得至多三条生成的理由。
- **输入：** `ranked`、`insights`。
- **返回：** 番剧 id 到理由的映射；跳过时为空。
- **副作用：** 等待期间在标题行下显示 2 px 的进度条；运行一次模型。
- **算法：** 与全局页面相同的条件：`canGenerate`；在 iOS 与 macOS 上，未知时就界面语言区域询问一次 Apple；
  `ReasonLanguage.forLocale`；然后调用
  [`writeRelatedAiReasons`](../services/ai_reason_service.md#writerelatedaireasons)。
- **用法：** `_generate`。
- **备注：** 与全局页面的理由不同，这些理由随列表一起持久保存。

### `Future<void> _refresh()` <a id="_refresh"></a>
- **种类：** `_RelatedRecommendationsCardState` 的方法
- **来源：** `lib/features/recommendations/views/related_card.dart`（约第 209 行）
- **用途：** 略过当前显示的一批。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 写入 `recommendations.json`（会同步）。
- **算法：** `hideRelated(id, shownIds)`，然后以更新后的垃圾箱调用 `_generate`。
- **用法：** 标题行的换一批按钮和菜单中的*换一批*。
- **备注：** 没有显示任何条目时，它不移入任何东西、只是重新生成，上次生成列表之后新增的记录就是这样出现的。

### `List<(Anime, RelatedItem)> get _resolved` <a id="_resolved"></a>
- **种类：** `_RelatedRecommendationsCardState` 的 getter
- **来源：** `lib/features/recommendations/views/related_card.dart`（约第 246 行）
- **用途：** 把已保存的 id 变成行。
- **输入：** 无。
- **返回：** 记录仍存在且未移入垃圾箱的条目，按保存的顺序。
- **副作用：** 无。
- **算法：** 把片库按 id 建映射；过滤快照中的条目。
- **用法：** `build`、`_refresh`。
- **备注：** 已删除的记录只是不再出现；不会重写任何内容。

### `Widget build(BuildContext context)` <a id="build"></a>
- **种类：** `_RelatedRecommendationsCardState` 的方法
- **来源：** `lib/features/recommendations/views/related_card.dart`（约第 263 行）
- **用途：** 构建卡片。
- **输入：** `context`。
- **返回：** 首次加载前什么也不返回，之后返回一个 `Card`。
- **副作用：** 无。
- **算法：** 一个标题为 `relatedTitle` 的标题行 `ListTile`，带换一批的 `IconButton`（忙碌时禁用）和一个菜单
  （*换一批*、*垃圾箱*）；AI 理由待定时显示进度条；没有任何行能解析时显示 `relatedEmpty`；然后每个条目一个 `_row`。
  理由标签用 `decodeRelatedReason` 解码，由 [`reasonLabel`](reason_labels.md) 生成文字；未知的代码会被跳过。
- **用法：** `AnimeDetailPage._buildDetailChildren`。
- **备注：** `margin: EdgeInsets.zero`，与详情页的其他卡片一致。
