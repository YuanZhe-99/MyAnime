# lib/shared/utils/chinese_convert.dart

纯静态 `ChineseConvert` 工具，提供逐字符的简体 ↔ 繁体中文转换，由两个平行的硬编码字符数组表（`_simplified` 和 `_traditional`，1:1 索引）支撑。唯一使用方是 `lib/features/anime/services/anime_search_service.dart`，在搜索中文动画来源时生成换用字体的查询变体（见 `AGENTS.md` 的"多源搜索"一节）。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `ChineseConvert._` | 构造函数（`ChineseConvert`） | B | 阻止直接实例化，只暴露静态成员。 |
| [`ChineseConvert.toTraditional`](#chineseconvert-totraditional) | 方法（`ChineseConvert`） | A | 把简体中文字符转换为其繁体变体。 |
| [`ChineseConvert.toSimplified`](#chineseconvert-tosimplified) | 方法（`ChineseConvert`） | A | 把繁体中文字符转换为其简体变体。 |

`_simplified` 和 `_traditional` 静态 const 字符数组字段没有 `/// Purpose:` 注释，不作为单独行索引；它们是两个方法查找的数据表。

## 文档

### `static String toTraditional(String text)` <a id="chineseconvert-totraditional"></a>
- **种类：** `ChineseConvert` 的静态方法
- **来源：** `lib/shared/utils/chinese_convert.dart`（约第 15 行）
- **用途：** 把 `text` 中的每个简体中文字符转换为其繁体中文变体，其他所有字符保持不变。
- **输入：** `text` — 任意字符串，通常是搜索查询或标题片段。
- **返回：** 匹配字符被替换后的 `String`。
- **副作用：** 无。
- **算法：**
  1. 遍历 `text.runes`（因此多字节/代理对字符被正确处理，而不是直接遍历 UTF-16 代码单元）。
  2. 对每个 rune，转回单字符 `String`，经 `String.indexOf` 在 `_simplified` 表中查其索引。
  3. 找到（`i >= 0`）时写 `_traditional` 中同索引的字符；否则原样写原字符。
  4. 返回累积的 `StringBuffer` 内容。
- **用法：**
  ```dart
  final querySimp = ChineseConvert.toSimplified(query);
  final queryTrad = ChineseConvert.toTraditional(query);
  ```
  （来自 `lib/features/anime/services/anime_search_service.dart`，在查询中文来源前生成搜索查询的两种字体变体）
- **备注：** 查找是每个字符对几百条目表的线性 `String.indexOf` 扫描，对输入中的每个字符运行一次——对搜索查询长度的字符串没问题，但无意用于转换大文档。表中不存在的字符（如标点、非中文字体、不在简体表中的已繁体字符）原样通过。

### `static String toSimplified(String text)` <a id="chineseconvert-tosimplified"></a>
- **种类：** `ChineseConvert` 的静态方法
- **来源：** `lib/shared/utils/chinese_convert.dart`（约第 30 行）
- **用途：** 把 `text` 中的每个繁体中文字符转换为其简体中文变体，其他所有字符保持不变。
- **输入：** `text` — 任意字符串，通常是搜索查询或标题片段。
- **返回：** 匹配字符被替换后的 `String`。
- **副作用：** 无。
- **算法：** `toTraditional` 的镜像：遍历 `text.runes`，经 `indexOf` 在 `_traditional` 中查每个字符，找到时替换为 `_simplified` 中同索引的字符；否则保留原字符。
- **用法：**
  ```dart
  final simplified = ChineseConvert.toSimplified(query);
  ```
  （来自 `lib/features/anime/services/anime_search_service.dart`，如构建模糊匹配规范化候选时）
- **备注：** 与 `toTraditional` 相同的线性扫描成本特征，以及未映射字符的透传行为。
