# lib/shared/utils/chinese_convert.dart

仅含静态成员的 `ChineseConvert` 工具，提供逐字符的简体 ↔ 繁体中文转换，背后是两张按需从
[`chinese_convert_data.md`](chinese_convert_data.md) 中生成的配对字符串构建的码点→码点映射。
`lib/features/anime/services/anime_search_service.dart` 用它生成另一种字形的查询变体，并且——自 1.5.7 起——把
标题归一化到简体键上用于匹配（见
[`../../../features/watch-url-lookup.md`](../../../features/watch-url-lookup.md#在归一化的简体键上匹配)）；
`anime1_service.dart` 的抓取回退也用它。

1.5.6 之前这两张表是两段约 1,200 个字符的手打平行字符串，每个字符用线性 `indexOf` 查找，并且缺
干/乾/幹、髮、裏、臺、徵、迴 以及数百个其他字。现在它们由 OpenCC 的字符字典与那张旧表合并生成，以 O(1) 查找。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `ChineseConvert._` | 构造函数（`ChineseConvert`） | B | 阻止直接实例化，只暴露静态成员。 |
| [`ChineseConvert.toTraditional`](#chineseconvert-totraditional) | 方法（`ChineseConvert`） | A | 把简体中文字符转换为其繁体变体。 |
| [`ChineseConvert.toSimplified`](#chineseconvert-tosimplified) | 方法（`ChineseConvert`） | A | 把繁体中文字符转换为其简体变体。 |
| [`_table`](#chineseconvert-table) | 方法（`ChineseConvert`） | A | 从交错的配对字符串构建码点→码点映射。 |
| [`_convert`](#chineseconvert-convert) | 方法（`ChineseConvert`） | A | 把字符串的每个码点经表映射，其余原样透传。 |

两个 `static Map<int, int>?` 缓存字段没有 `/// Purpose:` 注释，不作为单独的行索引；它们保存构建好的表。

## 文档

### `static String toTraditional(String text)` <a id="chineseconvert-totraditional"></a>
- **种类：** `ChineseConvert` 的静态方法
- **来源：** `lib/shared/utils/chinese_convert.dart`（约第 29 行）
- **用途：** 把 `text` 中的每个简体中文字符转换为一个繁体变体，其余字符保持不变。
- **输入：** `text`——任意字符串，通常是搜索查询或标题片段。
- **返回：** 替换了匹配字符的 `String`。
- **副作用：** 首次使用时构建查找表。
- **算法：** 用简转繁表调用 [`_convert`](#chineseconvert-convert)，该表由 [`_table`](#chineseconvert-table) 首次
  使用时从 `kSimplifiedToTraditionalPairs` 构建。
- **用法：**
  ```dart
  final querySimp = ChineseConvert.toSimplified(query);
  final queryTrad = ChineseConvert.toTraditional(query);
  ```
  （来自 `lib/features/anime/services/anime_search_service.dart`，在查询中文来源之前生成搜索查询的两种字形
  变体）
- **备注：** 这个方向是一对多，因此结果是一个*合理的*繁体形式，而非有保证的地区写法：一对多的字在旧表有选择时
  沿用旧表（里→裡、着→著），否则取 OpenCC 的第一个候选（干→幹）。比较标题时绝不要在这一侧归一化——用
  `toSimplified`。

### `static String toSimplified(String text)` <a id="chineseconvert-tosimplified"></a>
- **种类：** `ChineseConvert` 的静态方法
- **来源：** `lib/shared/utils/chinese_convert.dart`（约第 39 行）
- **用途：** 把 `text` 中的每个繁体中文字符转换为其简体变体，其余字符保持不变。
- **输入：** `text`。
- **返回：** 替换了匹配字符的 `String`。
- **副作用：** 首次使用时构建查找表。
- **算法：** 用繁转简表调用 [`_convert`](#chineseconvert-convert)。
- **用法：**
  ```dart
  return ChineseConvert.toSimplified(stripped);
  ```
  （来自 `AnimeSearchService.foldTitle`，匹配键的最后一步）
- **备注：** 多对一（乾与幹都变成干；髮与發都变成发），这正是标题在这个方向归一化的原因。与日文共用的汉字同样
  会被折叠（滅 → 灭）。

### `static Map<int, int> _table(String pairs)` <a id="chineseconvert-table"></a>
- **种类：** `ChineseConvert` 的静态方法
- **来源：** 约第 49 行
- **用途：** 从交错的配对字符串构建码点→码点映射。
- **输入：** `pairs`——两个生成常量之一。
- **返回：** `Map<int, int>`。
- **副作用：** 无。
- **算法：** `pairs.runes.toList()`，然后每个偶数下标成为键、其后一个码点成为值；断言检查码点数为偶数。
- **备注：** 仅在本文件内部使用的辅助函数。遍历的是 `runes` 而不是码元——OpenCC 包含 CJK 扩展 B 的字符，它们在
  UTF-16 中是代理对。

### `static String _convert(String text, Map<int, int> table)` <a id="chineseconvert-convert"></a>
- **种类：** `ChineseConvert` 的静态方法
- **来源：** 约第 61 行
- **用途：** 把 `text` 的每个码点经 `table` 映射，未映射的码点原样透传。
- **返回：** `String`。
- **副作用：** 无。
- **算法：** 遍历 `text.runes`，把 `table[rune] ?? rune` `writeCharCode` 进 `StringBuffer`。
- **备注：** 仅在本文件内部使用的辅助函数。标点、假名、拉丁字母与不在表中的字符原样透传。
