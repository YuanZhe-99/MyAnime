# lib/features/recommendations/views/recommendations_page.dart

`RecommendationsPage`（1.6.0，M5）即「接下来看什么」，位于 `/recommendations`，从只在推荐开启时显示的首页应用栏操作
压栈进入。它把 [`RecommendationService.rank`](../services/recommendation_service.md#recommendationservice-rank)
排好的候选列为带理由标签的卡片，追加资料库列出但片库中没有的续作，并在端侧 AI 开启且模型就绪时填入至多三条生成的简短理由。

自 1.6.2 起，页面每次显示**一批十条**，每张卡片（包括缺失续作）都有*不感兴趣*，把它移入 `recommendations.json` 中
**会同步**的垃圾箱（[`../services/recommendation_store.md`](../services/recommendation_store.md)），应用栏中还有
**换一批**——把当前显示的整批移入垃圾箱、显示下一批，可撤销——以及**垃圾箱**，打开
[`recommendation_trash_page.md`](recommendation_trash_page.md)。见
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md)
和 [`../../../../adaptive-layout.md`](../../../../adaptive-layout.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `RecommendationsPage.new` | 构造函数（`RecommendationsPage`） | B | 创建推荐页。 |
| `RecommendationsPage.createState` | 方法（`RecommendationsPage`） | B | 创建状态对象。 |
| `_RecommendationsPageState.initState` | 方法（`_RecommendationsPageState`） | B | 向自动同步注册 `_load` 并启动它。 |
| `_RecommendationsPageState.dispose` | 方法（`_RecommendationsPageState`） | B | 从自动同步注销（1.6.2）。 |
| [`_RecommendationsPageState._load`](#_recommendationspagestate-_load) | 方法（`_RecommendationsPageState`） | A | 对片库排序，然后请模型写理由。 |
| [`_RecommendationsPageState._requestAiReasons`](#_recommendationspagestate-_requestaireasons) | 方法（`_RecommendationsPageState`） | A | 在端侧模型能回答时请它写理由。 |
| [`_RecommendationsPageState._hide`](#_recommendationspagestate-_hide) | 方法（`_RecommendationsPageState`） | A | 把一张片库卡片移入垃圾箱。 |
| [`_RecommendationsPageState._hideSequel`](#_recommendationspagestate-_hidesequel) | 方法（`_RecommendationsPageState`） | A | 把一张缺失续作卡片移入垃圾箱（1.6.2）。 |
| `_RecommendationsPageState._sequelEntry` | 方法（`_RecommendationsPageState`） | B | 把一张缺失续作卡片描述为 `HiddenSequelEntry`（1.6.2）。 |
| [`_RecommendationsPageState._refreshBatch`](#_recommendationspagestate-_refreshbatch) | 方法（`_RecommendationsPageState`） | A | 把当前整批移入垃圾箱并显示下一批（1.6.2）。 |
| `_RecommendationsPageState._openTrash` | 方法（`_RecommendationsPageState`） | B | 压栈 `/recommendations/trash`，然后重新加载（1.6.2）。 |
| [`_RecommendationsPageState.build`](#_recommendationspagestate-build) | 方法（`_RecommendationsPageState`） | A | 构建页面。 |
| [`_RecommendationsPageState._card`](#_recommendationspagestate-_card) | 方法（`_RecommendationsPageState`） | A | 构建一张推荐卡片。 |
| [`_RecommendationsPageState._missingCard`](#_recommendationspagestate-_missingcard) | 方法（`_RecommendationsPageState`） | A | 为片库中没有的续作构建卡片。 |
| `_RecommendationsPageState._cover` | 方法（`_RecommendationsPageState`） | B | 委托给 `recommendationCover`。 |
| `recommendationCover` | 顶层函数 | B | 通过 `ImageService.resolve` 构建封面（默认 56×80），或占位；与垃圾箱页和相关推荐卡片共用（1.6.2）。 |

直到 1.6.1，本页还包含 `_reasonLabel`；自 1.6.2 起，理由标签的文字由共用的
[`reasonLabel`](reason_labels.md) 生成。

## 文档

### `Future<void> _load()` <a id="_recommendationspagestate-_load"></a>
- **种类：** `_RecommendationsPageState` 的方法
- **来源：** `lib/features/recommendations/views/recommendations_page.dart`（约第 92 行）
- **用途：** 对片库排序，然后请模型写理由。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 读取 `anime_data.json`、`recommendations.json` 和 `ai_insights.json`（按现存 id 修剪）；
  把 1.6.0–1.6.1 的*不感兴趣*列表一次性移入会同步的垃圾箱；设置状态；可能运行一次模型。
- **算法：** 1) `RecommendationStore.migrateFromInsights()`。2) 加载片库、存储和
  `AiInsightsCache.load(liveIds: …)`。3) 以存储的全局垃圾箱作为 `hidden:`、配合 `JstTime.now()` 调用 `rank`。4) 缺失续作：
  对每条已看完、且是所在系列最后一个成员（或不属于两个及以上成员的系列）的记录，取
  [`SeriesIndex.missingSequelFor`](../../anime/services/series_service.md#missingsequelfor)，以
  [`sequelTrashKey`](../services/recommendation_service.md#sequeltrashkey) 为键，跳过 `hiddenSequels` 中的键和重复项。
  5) 显示列表，批次变化时清空 AI 理由。
  6) 批次变化或当前没有显示理由时请求理由。
- **用法：** `initState`、自动同步的本地数据回调、垃圾箱页和缺失续作卡片打开的创建页返回之后，以及换一批之后。
- **备注：** 确定性列表立即渲染；没有任何东西等待模型。未改变本页任何内容的同步会保留已有的理由。

### `Future<void> _requestAiReasons()` <a id="_recommendationspagestate-_requestaireasons"></a>
- **种类：** `_RecommendationsPageState` 的方法
- **来源：** `lib/features/recommendations/views/recommendations_page.dart`（约第 145 行）
- **用途：** 在端侧模型能回答时请它写理由。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 等待期间在应用栏下显示 2 px 的进度条；运行一次模型；把理由存入状态。
- **算法：** `canGenerate` 为 false、没有排好的候选，或已有请求在进行时返回。在 iOS 与 macOS 上，若
  `ai.coreInfo?.localeSupported` 仍未知，先以界面语言区域标签调用 `ai.refreshStatus`，以获知 Apple 的 `supportsLocale`
  答复；若此后模型已无法生成则返回。再用
  [`ReasonLanguage.forLocale`](../services/ai_reason_service.md#reasonlanguage-forlocale) 挑选语言，传入
  `ai.coreInfo?.localeSupported`；没有可用语言时返回。否则以 `insights: _insights` 调用
  [`writeAiReasons`](../services/ai_reason_service.md#writeaireasons)。
- **用法：** `_load`。
- **备注：** 理由只为本页保存；离开再回来会重新请求。

### `Future<void> _hide(Anime anime)` <a id="_recommendationspagestate-_hide"></a>
- **种类：** `_RecommendationsPageState` 的方法
- **来源：** `lib/features/recommendations/views/recommendations_page.dart`（约第 187 行）
- **用途：** 把一张片库卡片移入垃圾箱。
- **输入：** `anime`。
- **返回：** 无。
- **副作用：** `RecommendationStore.hide([id])`——写入会同步的 `recommendations.json`；
  移除该卡片。
- **算法：** 移入垃圾箱，然后过滤排好的列表。
- **用法：** 每张卡片上的*不感兴趣*按钮。
- **备注：** 直到 1.6.1，这会写入仅限本设备的 `ai_insights.json`，且无法撤销。
  自 1.6.2 起它会同步，并可在垃圾箱页恢复。

### `Future<void> _hideSequel(Anime source, AnimeExternalRelation sequel)` <a id="_recommendationspagestate-_hidesequel"></a>
- **种类：** `_RecommendationsPageState` 的方法
- **来源：** `lib/features/recommendations/views/recommendations_page.dart`（约第 203 行）
- **用途：** 把一张缺失续作卡片移入垃圾箱。
- **输入：** `source` — 它所接续的记录；`sequel`。
- **返回：** 无。
- **副作用：** `RecommendationStore.hideSequels`——写入 `recommendations.json`；移除该
  卡片。
- **算法：** 保存 `_sequelEntry(source, sequel)`（键、来源 id、标题、资料库），然后按键过滤
  缺失续作列表。
- **用法：** 每张缺失续作卡片上的*不感兴趣*按钮。
- **备注：** 标题和资料库会被保留，这样即使关联关系已消失，垃圾箱仍能为该条目标注名称。

### `Future<void> _refreshBatch()` <a id="_recommendationspagestate-_refreshbatch"></a>
- **种类：** `_RecommendationsPageState` 的方法
- **来源：** `lib/features/recommendations/views/recommendations_page.dart`（约第 236 行）
- **用途：** 略过屏幕上的这一批并显示下一批。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 写入一次 `recommendations.json`（会同步）；重新加载；显示 snack bar
  「已将 N 项移入垃圾箱」，带**撤销**。
- **算法：** 收集当前显示的已排序 id 和缺失续作条目；
  `RecommendationStore.hideBatch`；`_load`；snack bar 的撤销对恰好这一批调用 `restore(ids)` 和
  `restoreSequels(keys)`，然后重新加载。
- **用法：** 应用栏的换一批按钮，加载中或没有显示任何内容时禁用。
- **备注：** 这就是换一批的含义：用户看过并略过的这一批即为「不感兴趣」。所有内容都仍可从垃圾箱恢复。

### `Widget build(BuildContext context)` <a id="_recommendationspagestate-build"></a>
- **种类：** `_RecommendationsPageState` 的方法
- **来源：** `lib/features/recommendations/views/recommendations_page.dart`（约第 281 行）
- **用途：** 构建页面。
- **输入：** `context`。
- **返回：** 一个 `Scaffold`。
- **副作用：** 无。
- **算法：** 应用栏：标题、**换一批**（`Icons.refresh`）和**垃圾箱**（`Icons.delete_outline`），
  AI 理由待定时显示 2 px 的进度条。列数来自
  [`listColumnCount`](../../../shared/utils/adaptive_layout.md#listcolumncount)，以屏幕宽度作为内容宽度、
  `settings.homeListColumns` 作为偏好。条目依次是排好的卡片和缺失续作卡片，由
  [`adaptiveTileRows`](../../../shared/widgets/adaptive_tile_grid.md#adaptivetilerows) 在
  `ListView` 中排布。加载中显示转圈；没有内容时显示 `recommendationsEmpty`。
- **用法：** Flutter。
- **备注：** 本页没有自己的列数按钮；它沿用首页列表的偏好。

### `Widget _card(Recommendation r, AppLocalizations l10n)` <a id="_recommendationspagestate-_card"></a>
- **种类：** `_RecommendationsPageState` 的方法
- **来源：** `lib/features/recommendations/views/recommendations_page.dart`（约第 348 行）
- **用途：** 构建一张推荐卡片。
- **输入：** `r`、`l10n`。
- **返回：** `Widget`。
- **副作用：** 无；点击压栈 `/anime/detail/<id>`。
- **算法：** 封面、标题（两行）、由 [`reasonLabel`](reason_labels.md) 生成文字的理由标签组成的 `Wrap`，
  然后——有 AI 理由时——闪光图标加 `aiGeneratedLabel` 和该理由，以及一个*不感兴趣*按钮。
- **用法：** `build`。
- **备注：** AI 理由总会标注为在本设备上生成。

### `Widget _missingCard(Anime source, AnimeExternalRelation sequel, AppLocalizations l10n)` <a id="_recommendationspagestate-_missingcard"></a>
- **种类：** `_RecommendationsPageState` 的方法
- **来源：** `lib/features/recommendations/views/recommendations_page.dart`（约第 424 行）
- **用途：** 为片库中没有的续作构建卡片。
- **输入：** `source` — 它所接续的成员；`sequel`；`l10n`。
- **返回：** `Widget`。
- **副作用：** 点击后以
  [`NextSeasonPrefill.fromRelation`](../../anime/services/series_service.md#nextseasonprefill-fromrelation)
  压栈 `/anime/edit`，返回后重新加载。
- **算法：** 一个 `ListTile`，标题为 `seriesMissingSequel(title, source)`，副标题为
  `recommendationsNotInLibrary`（「番剧库里还没有」），其下是一个调用 `_hideSequel` 的*不感兴趣*按钮
  （1.6.2）。
- **用法：** `build`。
- **备注：** 预填的搜索只在完整版中启动。
