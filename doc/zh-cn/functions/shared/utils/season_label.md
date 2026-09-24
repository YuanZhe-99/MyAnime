# lib/shared/utils/season_label.dart

季标签与标题的纯字符串辅助函数，由 anime1.me 查找（[`../../features/anime/services/anime1_service.md`](../../features/anime/services/anime1_service.md)）与系列分组（[`../../features/anime/services/series_service.md`](../../features/anime/services/series_service.md)）共用。它们从标题或 `season` 标签中读出季数序数、去除季标记使同一作品的两季归一化为同一基础标题，并生成下一季的标签。1.6.0 新增：`seasonOrdinal` 及其数字解析器从 `Anime1Service` 移到这里，后者的排序仍在使用它们。本模块不导入任何东西，因此每个辅助函数都可单元测试（`test/anime1_service_test.dart`、`test/series_service_test.dart`）。系列分组如何使用它们见 [`../../../features/series-linking.md`](../../../features/series-linking.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`halfWidthAscii`](#halfwidthascii) | 顶层函数 | A | 把全角 ASCII 字母、数字和空格转为半角。 |
| [`seasonOrdinal`](#seasonordinal) | 顶层函数 | A | 从标题或标签中读出 第N季 / Season N 序数。 |
| [`parseCjkNumber`](#parsecjknumber) | 顶层函数 | A | 解析小的中文或阿拉伯数字。 |
| `toCjkNumber` | 顶层函数 | B | 把 1 到 99 的数字写成中文数字（`parseCjkNumber` 的逆运算）。 |
| [`titleSeasonOrdinal`](#titleseasonordinal) | 顶层函数 | A | 读出标题所暗示的季数序数，比 `seasonOrdinal` 更宽松。 |
| [`stripSeasonMarkers`](#stripseasonmarkers) | 顶层函数 | A | 去除标题中的季标记，留下作品的基础标题。 |
| [`nextSeasonLabel`](#nextseasonlabel) | 顶层函数 | A | 以相同的数字风格生成给定季标签的下一个标签。 |
| `_englishSuffix` | 顶层函数 | B | 返回数字的英文序数后缀（`st`/`nd`/`rd`/`th`）。 |

`finalSeasonOrdinal` 常量（`99`）没有 `/// Purpose:` 注释，不作为单独的行索引。没有编号的"最终季"标记（`The Final Season`、最终季、完結編）读作这个序数，因此这样的一季排在同一作品每个有编号的季之后。

## 文档

### `String halfWidthAscii(String text)` <a id="halfwidthascii"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/utils/season_label.dart`（第 67 行）
- **用途：** 把全角 ASCII 字母、数字和空格转为半角。
- **输入：** `text`。
- **返回：** `String` — 同一文本，U+FF01–U+FF5E 移到 ASCII，U+3000 变为空格。
- **副作用：** 无。
- **备注：** `ゆるキャン△ SEASON２` 这样的标题混用全半角。`titleSeasonOrdinal` 与 `stripSeasonMarkers` 先做规范化，因此一个模式就能覆盖两种宽度；`seriesOrdinalOf` 读取 `season` 标签前也这样做。

### `int? seasonOrdinal(String text)` <a id="seasonordinal"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/utils/season_label.dart`（第 87 行）
- **用途：** 从标题或季标签中读出季数序数——`第二季`、`第2期`、`Season 2`、`2nd Season`、`S2`、`Part 2`。
- **返回：** `int?` — 没有序数时为 `null`。
- **副作用：** 无。
- **算法：** 先试 `第N季` / `第N期` 形式，经 [`parseCjkNumber`](#parsecjknumber) 解析；然后依次试 `Season N`、`Nth Season`、`SN` 与 `Part N`。
- **用法：** `Anime1Service.search` 和 `rank` 用它读取记录的序数（见 [`../../features/anime/services/anime1_service.md`](../../features/anime/services/anime1_service.md#rank)）；`seriesOrdinalOf` 用它回退读取 `season` 标签；`NextSeasonPrefill.after` 用它与标题序数比较。
- **备注：** 1.6.0 从 `Anime1Service` 原样移到这里。`Anime.season` 是自由文本标签（"Season 1"），这正是它既读标签也读标题的原因。它刻意不读裸 `N期`、英文单词或最终季标记——[`titleSeasonOrdinal`](#titleseasonordinal) 为系列分组补上这些，而不改变 anime1.me 排序看到的结果。

### `int? parseCjkNumber(String s)` <a id="parsecjknumber"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/utils/season_label.dart`（第 103 行）
- **用途：** 解析小的中文或阿拉伯数字。
- **输入：** `s` — `2`、`二`、`十`、`十二`、`二十`、`二十三`。
- **返回：** `int?` — 其他情况为 `null`。
- **副作用：** 无。
- **备注：** 覆盖 1–99，即标题会带的所有季数。1.6.0 之前它是私有的 `Anime1Service._parseCjkNumber`；这次移动还让它认识了三字形式 `二十三`，旧辅助函数对此返回 `null`。

### `int? titleSeasonOrdinal(String title)` <a id="titleseasonordinal"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/utils/season_label.dart`（第 150 行）
- **用途：** 读出标题所暗示的季数序数，比 [`seasonOrdinal`](#seasonordinal) 更宽松。
- **输入：** `title`。
- **返回：** `int?` — 序数；没有编号的最终季标记返回 `finalSeasonOrdinal`（99）；标题不带季标记时为 `null`。
- **副作用：** 无。
- **算法：** 经 [`halfWidthAscii`](#halfwidthascii) 后依次尝试：`seasonOrdinal`；前面不是"第"或数字的裸 `N期`；`Second Season` … `Sixth Season`；最终季标记（`Final Season`、最终季 / 最終季、完结篇 / 完結編及其变体）；结尾的罗马数字 II–IV。
- **用法：** [`series_service.md`](../../features/anime/services/series_service.md#seriesordinalof) 中的 `seriesOrdinalOf` 先用它读每个标题，再回退到标签。

### `String stripSeasonMarkers(String title)` <a id="stripseasonmarkers"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/utils/season_label.dart`（第 173 行）
- **用途：** 去除标题中的季标记，留下作品的基础标题。
- **输入：** `title`。
- **返回：** `String` — 去除标记并修剪后的结果。
- **副作用：** 无。
- **算法：**
  1. [`halfWidthAscii`](#halfwidthascii)。
  2. 替换为空格：第N季 / 第N期 / 第N部 / 第Nクール（N 为中文或阿拉伯数字）、裸 `N期`、`(The) Final Season`、`Season N`、`Nth Season`、`Second Season` 式单词、`SN`、`Part N`、`Cour N`、最终季 / 最終季 / 完结篇 / 完結編，以及 続編 / 续篇 / 續篇。
  3. 去掉结尾的罗马数字 II–IV，再去掉因删除而变空的括号（`()`、`（）`、`[]`、`【】`、`「」`、`『』`、`〔〕`）。
  4. 合并空白并去掉结尾的分隔符（`:`、`-`、`~`、`・`、`|`、`/` 及其全角形式）。
- **用法：** `seriesBaseKeys` 用 `AnimeSearchService.foldTitle` 把结果归一化，构建同一作品两季共享的基础键。
- **备注：** 仅用于匹配——结果在比较前会被归一化，从不显示。`【我推的孩子】第二季` 与 `【我推的孩子】` 化为同一基础标题；`進撃の巨人 The Final Season` 化为 `進撃の巨人`。

### `String? nextSeasonLabel(String label)` <a id="nextseasonlabel"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/utils/season_label.dart`（第 192 行）
- **用途：** 生成 `label` 之后的季标签。
- **输入：** `label` — 如 `Season 1`、`第一季`、`第1期`、`2nd Season`。
- **返回：** `String?` — 同一标签，数字以相同风格递增（`Season 2`、`第二季`、`第2期`、`3rd Season`）；读不出序数时为 `null`。
- **副作用：** 无。
- **算法：** `第N季` / `第N期` 形式中阿拉伯数字保持阿拉伯数字、中文数字保持中文数字（经 `toCjkNumber`）；`Nth Season` 经 `_englishSuffix` 重新计算英文后缀；否则 `Season N`、`SN` 与 `Part N` 原位递增。只替换第一处匹配，因此标签其余部分保留不变。
- **用法：** [`series_service.md`](../../features/anime/services/series_service.md#nextseasonprefill) 中的 `NextSeasonPrefill.after`，为"添加下一季"预填。
