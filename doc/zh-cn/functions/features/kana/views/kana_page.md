# lib/features/kana/views/kana_page.dart

`KanaPage` 是第四个底部导航标签：一个纯 UI 的平假名/片假名速查。它不读任何动画数据、没有持久化状态、不属于同步——功能概览见 [`../../../../features/kana-reference.md`](../../../../features/kana-reference.md)，它如何落在 `go_router` 外壳中见 [`../../../../architecture.md`](../../../../architecture.md)。本文件定义了一个私有 `_KanaScript` 枚举（hiragana/katakana）和三个小型数据类（`_KanaEntry`、`_KanaRow`、`_KanaRule`），支撑三个顶层 `const` 表——`_basicRows`、`_voicedRows`、`_yoonRows`——它们保存实际的五十音/浊音/拗音假名数据。文件其余部分是 `_KanaPageState`，它渲染假名切换、搜索字段、三个静态表（搜索查询为空时）、搜索结果网格（非空时）和一组发音规则卡片。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `KanaPage.new` | 构造函数（`KanaPage`） | B | 创建 `KanaPage` 实例。 |
| `KanaPage.createState` | 方法（`KanaPage`） | B | 为此组件创建可变状态对象。 |
| `_KanaPageState.dispose` | 方法（`_KanaPageState`） | B | 释放搜索文本控制器。 |
| `_KanaPageState.build` | 方法（`_KanaPageState`，组件构建） | B | 构建页面脚手架：假名切换、搜索字段，以及静态表或搜索结果，外加规则卡片。 |
| [`_KanaPageState._matchingEntries`](#_matchingentries) | 方法（`_KanaPageState`） | A | 查找跨所有表、匹配搜索查询的每个唯一假名条目。 |
| `_KanaPageState._buildKanaTable` | 方法（组件辅助） | B | 为一个列集渲染一个带标题的假名表（页头行 + 数据行）。 |
| `_KanaPageState._buildHeaderRow` | 方法（组件辅助） | B | 渲染表的列标签页头行。 |
| `_KanaPageState._buildKanaRow` | 方法（组件辅助） | B | 渲染一个辅音行的假名格加其行标签。 |
| `_KanaPageState._buildKanaCell` | 方法（组件辅助） | B | 渲染一个假名/罗马字格，缺失组合用空白占位。 |
| `_KanaPageState._buildSearchResults` | 方法（组件辅助） | B | 渲染搜索结果网格，无匹配时显示空状态消息。 |
| `_KanaPageState._buildResultTile` | 方法（组件辅助） | B | 把一个假名条目渲染为搜索结果块。 |
| `_KanaPageState._buildRules` | 方法（组件辅助） | B | 在响应式 1 或 2 列换行中排布发音规则卡片。 |
| `_KanaPageState._buildRuleCard` | 方法（组件辅助） | B | 渲染一张发音规则卡片（图标、标题、正文）。 |
| `_KanaPageState._sectionTitle` | 方法（组件辅助） | B | 渲染表与规则小节共享的小节标题（图标 + 标签）。 |
| `_KanaEntry.new` | 构造函数（`_KanaEntry`） | B | 创建假名条目（平假名、片假名和罗马字形式）。 |
| [`_KanaEntry.kana`](#kana) | 方法（`_KanaEntry`） | A | 为活动假名选择此条目的平假名或片假名渲染。 |
| [`_KanaEntry.matches`](#matches) | 方法（`_KanaEntry`） | A | 测试小写化搜索查询是否匹配此条目的平假名、片假名或罗马字。 |
| `_KanaRow.new` | 构造函数（`_KanaRow`） | B | 创建最多五个假名条目的带标签行（部分槽位可能为 `null`）。 |
| `_KanaRule.new` | 构造函数（`_KanaRule`） | B | 创建发音规则卡片的显示数据（图标、标题、正文、颜色）。 |

## 文档

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
