# lib/features/recommendations/views/recommendation_trash_page.dart

`RecommendationTrashPage`（1.6.2）是推荐垃圾箱，位于 `/recommendations/trash`。不带 `?anime=<id>` 时，它是
「接下来看什么」背后的全局垃圾箱：先列出移入垃圾箱的片库记录，再列出移入垃圾箱的缺失续作卡片。带上它时，它是该记录的相关推荐
背后该记录自己的垃圾箱，标题为「垃圾箱 · <标题>」。**恢复**把一个条目移出垃圾箱，使其可以再次被推荐；应用栏中的*全部恢复*
恢复当前显示的全部条目。见
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md#垃圾箱)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `RecommendationTrashPage.new` | 构造函数 | B | 创建页面；全局垃圾箱的 `animeId` 为 null。 |
| `RecommendationTrashPage.createState` | 方法 | B | 创建状态对象。 |
| `_RecommendationTrashPageState.initState` | 方法 | B | 向自动同步注册并加载。 |
| `_RecommendationTrashPageState.dispose` | 方法 | B | 从自动同步注销。 |
| [`_load`](#_load) | 方法 | A | 读取片库和存储。 |
| [`_records`](#_records) | getter | A | 列出本页显示的已移入垃圾箱的记录。 |
| `_sequels` | getter | B | 列出已移入垃圾箱的缺失续作卡片，最新的在前；在记录自己的垃圾箱中为空。 |
| `_newestFirst` | 静态方法 | B | 比较器：时间戳最新的在前，没有时间戳的在后，再按键排序。 |
| [`_restore`](#_restore) | 方法 | A | 从本页显示的垃圾箱中恢复记录。 |
| `_restoreSequels` | 方法 | B | 恢复已移入垃圾箱的缺失续作卡片。 |
| `_restoreAll` | 方法 | B | 恢复当前显示的全部条目；已删除记录的条目保持不动。 |
| [`build`](#build) | 方法 | A | 构建页面。 |

## 文档

### `Future<void> _load()` <a id="_load"></a>
- **种类：** `_RecommendationTrashPageState` 的方法
- **来源：** `lib/features/recommendations/views/recommendation_trash_page.dart`（约第 73 行）
- **用途：** 读取本页要显示的内容。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 读取 `anime_data.json` 和 `recommendations.json`；运行一次
  `RecommendationStore.migrateFromInsights`。
- **算法：** 迁移，把片库加载成按 id 索引的映射，加载存储，`setState`。
- **用法：** `initState`、自动同步的本地数据回调，以及每次恢复之后。
- **备注：** 无。

### `List<(HiddenEntry, Anime)> get _records` <a id="_records"></a>
- **种类：** `_RecommendationTrashPageState` 的 getter
- **来源：** `lib/features/recommendations/views/recommendation_trash_page.dart`（约第 91 行）
- **用途：** 把每个已移入垃圾箱的 id 与其记录配对。
- **输入：** 无。
- **返回：** 最新的在前。
- **副作用：** 无。
- **算法：** 取全局的 `hidden` 映射，或 `related[animeId].hidden`；保留记录仍存在的条目；用 `_newestFirst`
  排序。
- **用法：** `build`、`_restoreAll`。
- **备注：** 已删除记录的条目会被跳过而不是删除：删除它们会以恢复的形式同步出去。

### `Future<void> _restore(Iterable<String> ids)` <a id="_restore"></a>
- **种类：** `_RecommendationTrashPageState` 的方法
- **来源：** `lib/features/recommendations/views/recommendation_trash_page.dart`（约第 138 行）
- **用途：** 恢复记录。
- **输入：** `ids`。
- **返回：** 无。
- **副作用：** 写入 `recommendations.json`（会同步）；重新加载。
- **算法：** 全局垃圾箱用 `RecommendationStore.restore`，否则用 `restoreRelated(animeId, …)`。
- **用法：** 每一行的**恢复**，以及 `_restoreAll`。
- **备注：** 恢复的相关推荐不会被放回已保存的列表；它可能在该卡片下次换一批时再次出现。

### `Widget build(BuildContext context)` <a id="build"></a>
- **种类：** `_RecommendationTrashPageState` 的方法
- **来源：** `lib/features/recommendations/views/recommendation_trash_page.dart`（约第 177 行）
- **用途：** 构建页面。
- **输入：** `context`。
- **返回：** 一个 `Scaffold`。
- **副作用：** 无；点击记录行会压栈其详情页。
- **算法：** 标题为 `recommendationsTrash`，记录自己的垃圾箱则为 `relatedTrashTitle(title)`；应用栏中的*全部恢复*
  在为空时禁用。每条记录一个 `ListTile`（经 `recommendationCover` 显示 40×56 的封面、标题、经
  `MaterialLocalizations.formatMediumDate` 格式化的「<日期> 移入」、**恢复**），然后——仅全局垃圾箱——一个
  「番剧库里还没有的续作」小标题，每个移入垃圾箱的续作一行（`seriesMissingSequel(title, source)`、来源记录仍存在时显示
  「《<来源记录>》的下一部」、日期、**恢复**）。两个列表都为空时显示 `recommendationsTrashEmpty`。
- **用法：** Flutter。
- **备注：** 普通列表；本页没有列数按钮。
