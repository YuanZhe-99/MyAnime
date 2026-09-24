# lib/features/recommendations/views/recommendations_page.dart

`RecommendationsPage`（1.6.0，M5）即「接下来看什么」，位于 `/recommendations`，从只在推荐开启时显示的首页应用栏操作
压栈进入。它把 [`RecommendationService.rank`](../services/recommendation_service.md#recommendationservice-rank) 排好的
候选列为带理由标签的卡片，追加资料库列出但片库中没有的续作，并在端侧 AI 开启且模型就绪时填入至多三条生成的简短理由。见
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md)
和 [`../../../../adaptive-layout.md`](../../../../adaptive-layout.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `RecommendationsPage.new` | 构造函数（`RecommendationsPage`） | B | 创建推荐页。 |
| `RecommendationsPage.createState` | 方法（`RecommendationsPage`） | B | 创建状态对象。 |
| `_RecommendationsPageState.initState` | 方法（`_RecommendationsPageState`） | B | 首次构建时启动 `_load`。 |
| [`_RecommendationsPageState._load`](#_recommendationspagestate-_load) | 方法（`_RecommendationsPageState`） | A | 对片库排序，然后请模型写理由。 |
| [`_RecommendationsPageState._requestAiReasons`](#_recommendationspagestate-_requestaireasons) | 方法（`_RecommendationsPageState`） | A | 在端侧模型能回答时请它写理由。 |
| [`_RecommendationsPageState._hide`](#_recommendationspagestate-_hide) | 方法（`_RecommendationsPageState`） | A | 在本设备上隐藏一个候选。 |
| [`_RecommendationsPageState._reasonLabel`](#_recommendationspagestate-_reasonlabel) | 方法（`_RecommendationsPageState`） | A | 为一个理由标签生成文字。 |
| [`_RecommendationsPageState.build`](#_recommendationspagestate-build) | 方法（`_RecommendationsPageState`） | A | 构建页面。 |
| [`_RecommendationsPageState._card`](#_recommendationspagestate-_card) | 方法（`_RecommendationsPageState`） | A | 构建一张推荐卡片。 |
| [`_RecommendationsPageState._missingCard`](#_recommendationspagestate-_missingcard) | 方法（`_RecommendationsPageState`） | A | 为片库中没有的续作构建卡片。 |
| `_RecommendationsPageState._cover` | 方法（`_RecommendationsPageState`） | B | 通过 `ImageService.resolve` 构建 56×80 的封面，或占位。 |

## 文档

### `Future<void> _load()` <a id="_recommendationspagestate-_load"></a>
- **种类：** `_RecommendationsPageState` 的方法
- **来源：** `lib/features/recommendations/views/recommendations_page.dart`（约第 72 行）
- **用途：** 对片库排序，然后请模型写理由。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 读取 `anime_data.json` 和 `ai_insights.json`（按现存 id 修剪）；设置状态；可能运行一次模型。
- **算法：** 1) 加载片库和 `AiInsightsCache.load(liveIds: …)`。2) 用 `JstTime.now()` 调用 `rank`。3) 缺失续作：对每条
  已看完、且是所在系列最后一个成员（或不属于两个及以上成员的系列）的记录，取
  [`SeriesIndex.missingSequelFor`](../../anime/services/series_service.md#missingsequelfor)，按目标 URL 或标题去重。
  4) 显示列表。5) await `_requestAiReasons`。
- **用法：** `initState`，以及缺失续作卡片打开的创建页返回之后再调用一次。
- **备注：** 确定性列表立即渲染；没有任何东西等待模型。

### `Future<void> _requestAiReasons()` <a id="_recommendationspagestate-_requestaireasons"></a>
- **种类：** `_RecommendationsPageState` 的方法
- **来源：** `lib/features/recommendations/views/recommendations_page.dart`（约第 115 行）
- **用途：** 在端侧模型能回答时请它写理由。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 等待期间在应用栏下显示 2 px 的进度条；运行一次模型；把理由存入状态。
- **算法：** `canGenerate` 为 false 或没有排好的候选时返回。在 iOS 与 macOS 上，若 `ai.coreInfo?.localeSupported` 仍未知，先以界面语言区域标签调用 `ai.refreshStatus`，以获知 Apple 的 `supportsLocale` 答复；若此后模型已无法生成则返回。再用
  [`ReasonLanguage.forLocale`](../services/ai_reason_service.md#reasonlanguage-forlocale) 挑选语言，传入
  `ai.coreInfo?.localeSupported`；返回 null（没有可用语言）时返回。否则以 `insights: _insights` 调用 [`writeAiReasons`](../services/ai_reason_service.md#writeaireasons)。
- **用法：** `_load`。
- **备注：** 理由只为本页保存；离开再回来会重新请求。

### `Future<void> _hide(Anime anime)` <a id="_recommendationspagestate-_hide"></a>
- **种类：** `_RecommendationsPageState` 的方法
- **来源：** `lib/features/recommendations/views/recommendations_page.dart`（约第 143 行）
- **用途：** 在本设备上隐藏一个候选。
- **输入：** `anime`。
- **返回：** 无。
- **副作用：** 把 id 加入 `hiddenRecommendations` 并写入 `ai_insights.json`；移除该卡片。
- **算法：** 加入、`AiInsightsCache.save`，然后过滤排好的列表。
- **用法：** 每张卡片上的*不感兴趣*按钮。
- **备注：** 仅限本设备：`ai_insights.json` 既不同步也不备份。没有撤销的界面；只有记录被删除时该 id 才会被移除。

### `String _reasonLabel(RecommendationReason reason, AppLocalizations l10n)` <a id="_recommendationspagestate-_reasonlabel"></a>
- **种类：** `_RecommendationsPageState` 的方法
- **来源：** `lib/features/recommendations/views/recommendations_page.dart`（约第 160 行）
- **用途：** 为一个理由标签生成文字。
- **输入：** `reason`、`l10n`。
- **返回：** `String`。
- **副作用：** 无。
- **算法：** `NextAfterReason` → `reasonNextAfter(title)`；`CategoryMatchReason` → 把 id 经
  [`categoryLabel`](../../anime/views/category_widgets.md#categorylabel) 转换后以逗号连接，交给 `reasonLikeCategories`；
  `SameStudioReason` → `reasonSameStudio(title)`；`ExternalScoreReason` → `<source> <保留一位小数的分数>`，不做本地化；
  `CatchUpReason` → `reasonCatchUp`。
- **用法：** `_card`。
- **备注：** 该 `switch` 对 sealed 类是穷尽的。

### `Widget build(BuildContext context)` <a id="_recommendationspagestate-build"></a>
- **种类：** `_RecommendationsPageState` 的方法
- **来源：** `lib/features/recommendations/views/recommendations_page.dart`（约第 182 行）
- **用途：** 构建页面。
- **输入：** `context`。
- **返回：** 一个 `Scaffold`。
- **副作用：** 无。
- **算法：** 列数来自 [`listColumnCount`](../../../shared/utils/adaptive_layout.md#listcolumncount)，以屏幕宽度作为内容
  宽度、`settings.homeListColumns` 作为偏好。条目依次是排好的卡片和缺失续作卡片，由
  [`adaptiveTileRows`](../../../shared/widgets/adaptive_tile_grid.md#adaptivetilerows) 在 `ListView` 中排布。加载中显示
  转圈；没有内容时显示 `recommendationsEmpty`。
- **用法：** Flutter。
- **备注：** 本页没有自己的列数按钮；它沿用首页列表的偏好。

### `Widget _card(Recommendation r, AppLocalizations l10n)` <a id="_recommendationspagestate-_card"></a>
- **种类：** `_RecommendationsPageState` 的方法
- **来源：** `lib/features/recommendations/views/recommendations_page.dart`（约第 237 行）
- **用途：** 构建一张推荐卡片。
- **输入：** `r`、`l10n`。
- **返回：** `Widget`。
- **副作用：** 无；点击压栈 `/anime/detail/<id>`。
- **算法：** 封面、标题（两行）、理由标签组成的 `Wrap`，然后——有 AI 理由时——闪光图标加 `aiGeneratedLabel` 和该理由，
  以及一个*不感兴趣*按钮。
- **用法：** `build`。
- **备注：** AI 理由总会标注为在本设备上生成。

### `Widget _missingCard(Anime source, AnimeExternalRelation sequel, AppLocalizations l10n)` <a id="_recommendationspagestate-_missingcard"></a>
- **种类：** `_RecommendationsPageState` 的方法
- **来源：** `lib/features/recommendations/views/recommendations_page.dart`（约第 312 行）
- **用途：** 为片库中没有的续作构建卡片。
- **输入：** `source` — 它所接续的成员；`sequel`；`l10n`。
- **返回：** `Widget`。
- **副作用：** 点击后以 [`NextSeasonPrefill.fromRelation`](../../anime/services/series_service.md#nextseasonprefill-fromrelation)
  压栈 `/anime/edit`，返回后重新加载。
- **算法：** 一个 `ListTile`，标题为 `seriesMissingSequel(title, source)`，副标题为 `recommendationsNotInLibrary`
  （「番剧库里还没有」）。
- **用法：** `build`。
- **备注：** 预填的搜索只在完整版中启动。这些卡片没有*不感兴趣*按钮。
