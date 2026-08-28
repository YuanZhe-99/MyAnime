# lib/features/kana/views/kana_page.dart

`KanaPage` 是第四个底部导航标签：一个纯 UI 的平假名/片假名速查。它不读任何动画数据、没有持久化状态、不属于同步——功能概览见 [`../../../../features/kana-reference.md`](../../../../features/kana-reference.md)，它如何落在 `go_router` 外壳中见 [`../../../../architecture.md`](../../../../architecture.md)。本文件定义了一个私有 `_KanaScript` 枚举（hiragana/katakana）和三个小型数据类（`_KanaEntry`、`_KanaRow`、`_KanaRule`），支撑三个顶层 `const` 表——`_basicRows`、`_voicedRows`、`_yoonRows`——它们保存实际的五十音/浊音/拗音假名数据。文件其余部分是 `_KanaPageState`，它渲染假名切换、搜索字段、三个静态表（搜索查询为空时）、搜索结果网格（非空时）和一组发音规则卡片。

自 1.5.4 起本页是自适应的：在全应用拆分规则允许、且宽到足以放下两张表的窗口上，它把各节排成两列，并把假名
切换放到搜索字段旁边。两个文件级常量承载这两个最小宽度——`_kanaTableMinWidth`（330）与
`_kanaRuleMinWidth`（320）——两者都交给共用的 `columnCapacity`。`adaptive-layout.md` 里曾作为已知例外记录
的那个写死的 `constraints.maxWidth >= 720` 也归到了这里；`lib/` 中不再有第二条布局规则。见
[`../../../../adaptive-layout.md`](../../../../adaptive-layout.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `KanaPage.new` | 构造函数（`KanaPage`） | B | 创建 `KanaPage` 实例。 |
| `KanaPage.createState` | 方法（`KanaPage`） | B | 为此组件创建可变状态对象。 |
| `_KanaPageState.dispose` | 方法（`_KanaPageState`） | B | 释放搜索文本控制器。 |
| [`_KanaPageState.build`](#kanabuild) | 方法（`_KanaPageState`，组件构建） | A | 以单列或双列构建页面脚手架：假名切换、搜索字段，以及静态表或搜索结果，外加规则卡片。 |
| [`_KanaPageState._matchingEntries`](#_matchingentries) | 方法（`_KanaPageState`） | A | 查找跨所有表、匹配搜索查询的每个唯一假名条目。 |
| `_KanaPageState._buildKanaTable` | 方法（组件辅助） | B | 为一个列集渲染一个带标题的假名表（页头行 + 数据行）。 |
| `_KanaPageState._buildHeaderRow` | 方法（组件辅助） | B | 渲染表的列标签页头行。 |
| `_KanaPageState._buildKanaRow` | 方法（组件辅助） | B | 渲染一个辅音行的假名格加其行标签。 |
| `_KanaPageState._buildKanaCell` | 方法（组件辅助） | B | 渲染一个假名/罗马字格，缺失组合用空白占位。 |
| `_KanaPageState._buildSearchResults` | 方法（组件辅助） | B | 渲染搜索结果网格，无匹配时显示空状态消息。 |
| `_KanaPageState._buildResultTile` | 方法（组件辅助） | B | 把一个假名条目渲染为搜索结果块。 |
| [`_KanaPageState._buildRules`](#kanabuildrules) | 方法（组件辅助） | A | 在响应式 1 或 2 列换行中排布发音规则卡片。 |
| `_KanaPageState._buildRuleCard` | 方法（组件辅助） | B | 渲染一张发音规则卡片（图标、标题、正文）。 |
| `_KanaPageState._sectionTitle` | 方法（组件辅助） | B | 渲染表与规则小节共享的小节标题（图标 + 标签）。 |
| `_KanaEntry.new` | 构造函数（`_KanaEntry`） | B | 创建假名条目（平假名、片假名和罗马字形式）。 |
| [`_KanaEntry.kana`](#kana) | 方法（`_KanaEntry`） | A | 为活动假名选择此条目的平假名或片假名渲染。 |
| [`_KanaEntry.matches`](#matches) | 方法（`_KanaEntry`） | A | 测试小写化搜索查询是否匹配此条目的平假名、片假名或罗马字。 |
| `_KanaRow.new` | 构造函数（`_KanaRow`） | B | 创建最多五个假名条目的带标签行（部分槽位可能为 `null`）。 |
| `_KanaRule.new` | 构造函数（`_KanaRule`） | B | 创建发音规则卡片的显示数据（图标、标题、正文、颜色）。 |

## 文档

### `Widget build(BuildContext context)` <a id="kanabuild"></a>
- **种类：** `_KanaPageState` 的方法（组件构建）
- **来源：** `lib/features/kana/views/kana_page.dart`（约第 63 行）
- **用途：** 依据窗口以单列或双列构建页面。
- **输入：** `context`。
- **返回：** 该页的控件树。
- **副作用：** 除构建控件外无。
- **算法：**
  1. 内容宽度为 `shellContentWidth(screen.width) - 32`，并以页面自身 1080 的上限封顶。
  2. `twoColumn` 为 `canSplitLayout(screen.width, screen.height)` **且**
     `columnCapacity(contentWidth, minItemWidth: _kanaTableMinWidth, maxColumns: 2) >= 2`。
  3. 把假名切换、搜索字段、三张表与规则一节构建为局部变量。
  4. 页首：`twoColumn` 时在一个 `Row` 中并排，否则如旧上下堆叠。
  5. 页身：有查询时是搜索结果加规则；否则 `twoColumn` 时是（清音、拗音）与（浊音、规则）的双列 `Row`；再否则
     是原本的堆叠顺序。
- **用法：**
  ```dart
  GoRoute(path: '/kana', builder: (context, state) => const KanaPage()),
  ```
  （出自 `lib/app/router.dart` 中的 `appRouter`）
- **备注：** **刻意门控两次。** 第一道是全应用的形状规则；第二道问的是两张不低于 330 逻辑像素的表是否真的放得
  下。第二道正是让较窄的展开态折叠屏——Z Fold 5 有 546 的内容宽，而两张表需要 672——保持单列而无需自己的断点
  的原因。Z Fold 8 Ultra 与 Pixel 10 Pro Fold 则放得下，每格约 58 逻辑像素，与手机单列下所得持平。

  两列是指派的而非流式排布，这样才平衡：高的清音表与拗音表在左，矮的浊音表加规则在右。

### `List<_KanaEntry> _matchingEntries(String query)` <a id="_matchingentries"></a>
- **种类：** `_KanaPageState` 的方法
- **来源：** `lib/features/kana/views/kana_page.dart`（第 140 行）
- **用途：** 收集基本、浊音和拗音表中平假名、片假名或罗马字匹配当前搜索查询的每个假名条目，无重复。
- **输入：** `query` — 已被调用方（`build`）修剪并小写化。
- **返回：** `List<_KanaEntry>` — 按表顺序的匹配条目（基本行、然后浊音行、然后拗音行），重复保留首次出现。
- **副作用：** 无。
- **算法：**
  1. 用 `'${entry.hiragana}:${entry.romaji}'` 作键的 `Set<String>` 跟踪已见条目。
  2. 遍历 `[..._basicRows, ..._voicedRows, ..._yoonRows]`，然后每行的 `entries`（不存在的假名槽位为 `null`，如 `wi`/`wu`/`we`）。
  3. 跳过 `null` 槽位和 `matches(query)`（见 [`_KanaEntry.matches`](#matches)）为 false 的任何条目。
  4. 只在去重键未在 `seen` 中时才把条目加入结果列表——这很重要，因为 `_basicRows`/`_voicedRows`/`_yoonRows` 只会作为三个独立列表被搜索，所以今天同一底层假名实践中不会重复，但若未来某表复用条目，该守卫使函数保持安全。
- **用法：**
  ```dart
  final matches = query.isEmpty ? <_KanaEntry>[] : _matchingEntries(query);
  ```
  （来自 `_KanaPageState.build`，同一文件，第 50 行）
- **备注：** 查询预期已小写化；本函数自己不小写化（大小写折叠在 `build` 中做一次，罗马字比较时 `matches` 内逐字段再做一次）。

### `Widget _buildRules(ThemeData theme, AppLocalizations l10n)` <a id="kanabuildrules"></a>
- **种类：** `_KanaPageState` 的方法（组件辅助）
- **来源：** `lib/features/kana/views/kana_page.dart`（约第 445 行）
- **用途：** 把七张发音规则卡排成一列或两列。
- **输入：** `theme`、`l10n`。
- **返回：** `Widget`——一个小节标题，其下是一组定宽卡片的 `Wrap`。
- **副作用：** 除构建控件外无。
- **算法：** 在 `LayoutBuilder` 内取
  `columnCapacity(constraints.maxWidth, minItemWidth: _kanaRuleMinWidth, maxColumns: 2)`，用可用宽度扣除间距
  后除以它，并把该宽度赋给 `Wrap` 中的每一张卡片。
- **用法：**
  ```dart
  final rules = _buildRules(theme, l10n);
  ```
  （出自同一文件的 `_KanaPageState.build`）
- **备注：** 量的是这一节实际获得的宽度——单列时是整个页宽，双列时是其一半——因此卡片会自行回流，而不需要知道
  页面处于哪一种模式。

  1.5.4 用它取代了一个写死的 `constraints.maxWidth >= 720`，而这次改动**保住**了行为而非改变它：侧边导航栏
  使平板竖持只剩 655 逻辑像素的规则宽度，那个 `720` 字面量如今会在此落空，而共用的算式则通过。上限为两列是
  因为这些是段落：第三列会让行宽低于舒适的阅读尺度。

### `String kana(_KanaScript script)` <a id="kana"></a>

- **种类：** `_KanaEntry` 的方法
- **来源：** `lib/features/kana/views/kana_page.dart`（第 553 行）
- **用途：** 按当前选中的假名返回此条目的平假名或片假名拼写。
- **输入：** `script` — 活动 `_KanaScript`（hiragana 或 katakana）。
- **返回：** `String` — 切换选中的 `hiragana` 或 `katakana`。
- **副作用：** 无。
- **算法：** 对 `script` 的 `switch` 表达式，返回匹配的存储字段。
- **用法：**
  ```dart
  Text(
    entry.kana(_script),
    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
  ),
  ```
  （来自 `_KanaPageState._buildKanaCell`，同一文件，第 274 行）
- **备注：** 无。

### `bool matches(String query)` <a id="matches"></a>
- **种类：** `_KanaEntry` 的方法
- **来源：** `lib/features/kana/views/kana_page.dart`（第 565 行）
- **用途：** 决定此条目是否应出现在给定查询的搜索结果中。
- **输入：** `query` — 搜索文本，预期已被调用方小写化。
- **返回：** `bool` — `query` 出现在 `hiragana`、`katakana` 或小写化的 `romaji` 中时为 true。
- **副作用：** 无。
- **算法：** `hiragana.contains(query) || katakana.contains(query) || romaji.toLowerCase().contains(query)` — 对三个字段各做普通子串测试；`hiragana`/`katakana` 原样比较（它们没有大小写），而 `romaji` 在比较前小写化，使查询无需匹配存储罗马字的大小写。
- **用法：**
  ```dart
  if (entry == null || !entry.matches(query)) continue;
  ```
  （来自 `_KanaPageState._matchingEntries`，同一文件，第 145 行）
- **备注：** 只做子串匹配——除小写化外没有罗马字规范化（如搜索 `"si"` 不匹配存储为 `"shi"` 的条目）。
