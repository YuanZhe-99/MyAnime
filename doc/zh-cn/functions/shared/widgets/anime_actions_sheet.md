# lib/shared/widgets/anime_actions_sheet.dart

被应用中每一个动画列表行共用的长按操作面板。它之所以存在，是因为三个数据浏览模块中的列表行都把标题截断为单行
（`maxLines: 1, overflow: TextOverflow.ellipsis`），因此长名称在原地无法读全，而且不先打开详情页就没有办法对该
条目执行操作。

一个公开入口 `showAnimeActionsSheet`，外加一个私有操作枚举。由四处条目构建器调用：`home_page.dart` 的
`_buildEpisodeTile`、`management_page.dart` 的 `_buildAnimeTile`，以及 `statistics_page.dart` 中的
`_buildRankingTile` 与分组列表条目——每一处都经由一个单行的 `_showActions` 辅助方法，在数据发生变化时重新加载
页面。

以 `anime_search_dialog.dart` 中既有的 `_showResultDetails` 为范本，后者出于同样的理由展示搜索结果未截断的标题。

## 声明

| 声明 | 种类 | 层级 | 用途 |
|---|---|---|---|
| [`showAnimeActionsSheet`](#showanimeactionssheet) | 顶层函数 | A | 展示某个动画的完整名称及其编辑与删除操作。 |

私有的 `_AnimeQuickAction` 枚举（`edit`、`delete`）只负责把面板的结果带回调用方，本身没有任何逻辑，因此在此以
散文描述，而不作为独立行编入索引。

## 文档

### `Future<bool> showAnimeActionsSheet(BuildContext context, Anime anime)` <a id="showanimeactionssheet"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/widgets/anime_actions_sheet.dart`（约第 24 行）
- **用途：** 展示该动画的完整名称并提供编辑与删除，随后执行所选操作。
- **输入：** `context`——生命周期长于该面板的页面 context；`anime`。
- **返回：** `Future<bool>`——当该动画被编辑或删除时为 `true`，调用方应重新加载其列表。面板被关闭、或删除确认
  被拒绝时为 `false`。
- **副作用：** 展示一个模态底部面板。可能跳转到 `/anime/edit/{id}`、展示删除确认对话框，并从存储中删除该动画。
- **算法：**
  1. 收集要展示的标题：非空时取 `anime.title`，随后在非空且与 `anime.title` 不同时取 `anime.titleJa`。
  2. `showModalBottomSheet<_AnimeQuickAction>`，`showDragHandle: true`，把每个标题渲染为**不带 `maxLines`** 的
     `SelectableText`，随后是一条分隔线，再是编辑行（`l10n.animeEdit`）与删除行（`l10n.delete`，使用错误色）。
  3. 未选择任何项、或调用方的 context 已消失时返回 `false`。
  4. `edit`——`await context.push('/anime/edit/${anime.id}')`，返回 `true`。
  5. `delete`——`confirmDelete(context, anime.displayTitle)`；被拒绝则返回 `false`，否则执行
     `AnimeStorage.deleteAnime(anime.id)` 并返回 `true`。
- **用法：**
  ```dart
  Future<void> _showActions(Anime anime) async {
    final changed = await showAnimeActionsSheet(context, anime);
    if (changed && mounted) await _load();
  }
  ```
  （出自 `_ManagementPageState`；首页与统计页带有同样的辅助方法）
- **备注：** 面板返回一个选择并在所选操作执行**之前**被关闭，因此确认对话框与编辑路由使用的是调用方那个仍然
  挂载的页面 context，而不是彼时已经消失的面板 context。面板关闭后会检查 `context.mounted`。

  删除走共用的 `confirmDelete`（[delete_confirm.md](delete_confirm.md)），因此这条路径免费继承了它全局五分钟的
  "不再询问"抑制窗口，其行为与从详情页删除或滑动管理页某一行删除完全一致。

  触屏上通过长按抵达该面板，桌面端通过**右键**——条目构建器用带 `onSecondaryTapUp` 的 `GestureDetector` 包裹，
  或在条目本身已是 `InkWell` 处使用 `InkWell.onSecondaryTap`——因为在 Windows 上按住鼠标键不放并不是一个自然的
  手势。
