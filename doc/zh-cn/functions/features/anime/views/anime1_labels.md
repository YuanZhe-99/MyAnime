# lib/features/anime/views/anime1_labels.dart

四个纯标签辅助函数，把 anime1.me 的集数单元格、年份/季节单元格、一条排序后的命中，以及已存的
`AnimeWatchProgress` 变成面向用户的文本。它们像 [`archive_labels.md`](archive_labels.md) 一样作为一个共享文件
存在，因为有三处调用方需要——[`anime_edit_page.md`](anime_edit_page.md)（观看链接对话框的行）、
[`anime_detail_page.md`](anime_detail_page.md)（进度标签）以及测试——而同一个「第 1-12+OVA 集」无论出现在哪里
都必须读起来一致。季节名复用日历的 `seasonWinter`/`seasonSpring`/`seasonSummer`/`seasonFall` 键；站点自己的
后缀如 `+OVA` 不翻译。见
[`../../../../features/watch-url-lookup.md`](../../../../features/watch-url-lookup.md#集数文本)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`anime1EpisodesLabel`](#anime1episodeslabel) | 函数 | A | 把集数单元格本地化为标签或副标题用的文本。 |
| [`anime1SeasonLabel`](#anime1seasonlabel) | 函数 | A | 本地化年份/季节单元格，如「2022 秋」。 |
| [`anime1InfoLine`](#anime1infoline) | 函数 | A | 组合搜索结果下方的一行说明。 |
| [`watchProgressLabel`](#watchprogresslabel) | 函数 | A | 本地化一条已存的观看进度记录。 |

## 文档

### `String anime1EpisodesLabel(AppLocalizations l10n, Anime1EpisodeInfo info)` <a id="anime1episodeslabel"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/anime/views/anime1_labels.dart`（约第 12 行）
- **用途：** 把 anime1.me 的集数单元格本地化为标签或副标题用的文本。
- **返回：** `String`。
- **副作用：** 无。
- **算法：** ongoing → `anime1Ongoing(latest)`（没读出数字时用原文）；range → 单元格带 extras 时用原文，否则
  `first-last`（或单个数字），经 `anime1EpisodeRange`；movie → `anime1Movie`；special → `anime1Special`；
  other → 原文。
- **用法：**
  ```dart
  expect(anime1EpisodesLabel(en, Anime1Service.parseEpisodes('連載中(09)')), 'Updated to episode 9');
  ```
  （`test/anime1_service_test.dart`）
- **备注：** 原样保留 `+OVA` 是刻意的——那是站点自己的记法。

### `String? anime1SeasonLabel(AppLocalizations l10n, String? year, String? season)` <a id="anime1seasonlabel"></a>
- **种类：** 顶层函数
- **来源：** 约第 37 行
- **用途：** 本地化 anime1.me 的年份/季节单元格，如「2022 秋」。
- **返回：** `String?`——两部分都为空时为 `null`。
- **副作用：** 无。
- **备注：** 无法识别的季节值按站点写法原样显示。

### `String? anime1InfoLine(AppLocalizations l10n, Anime1Match match)` <a id="anime1infoline"></a>
- **种类：** 顶层函数
- **来源：** 约第 57 行
- **用途：** 组合搜索结果下方的一行说明：季节、集数与字幕组用间隔点连接，空的部分跳过。
- **返回：** `String?`——抓取回退的命中不带数据，为 `null`。
- **副作用：** 无。
- **用法：**
  ```dart
  final info = anime1InfoLine(l10n, r);
  ```
  （`anime_edit_page.dart`，`_WatchUrlSearchDialogState._buildBody`）
- **备注：** 无。

### `String? watchProgressLabel(AppLocalizations l10n, AnimeWatchProgress progress)` <a id="watchprogresslabel"></a>
- **种类：** 顶层函数
- **来源：** 约第 74 行
- **用途：** 本地化一条已存的观看进度记录。
- **返回：** `String?`——记录不含集数数据时为 `null`。
- **副作用：** 无。
- **算法：** 把已存的集数文本经 `Anime1Service.parseEpisodes` 重新解析后交给
  [`anime1EpisodesLabel`](#anime1episodeslabel)；没有文本时只用 `latestEpisode` 回退。
- **备注：** 重新解析已存文本，正是让已完结与连载中的作品在详情页上读起来与对话框里完全一致的原因。
