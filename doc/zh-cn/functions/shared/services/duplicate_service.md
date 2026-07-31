# lib/shared/services/duplicate_service.dart

`DuplicateService` 实现应用的重复动画检测和合并逻辑：把可能是同一部动画的记录分组（按 id、URL 或规范化标题/季/播出日期），并用文档化的字段优先级策略把一组合并为一条记录。它同时支撑专门的"检查重复"设置页（`lib/shared/widgets/duplicate_check_page.dart`）和 `.myanimeitem` 导入冲突解决（`lib/shared/widgets/import_bundle_dialog.dart`，见 [`file_open_service.md`](file_open_service.md)）。完整分组/合并算法说明，以及它如何区别于 WebDAV 同步的逐记录三方合并（[`../../../algorithms/three-way-merge.md`](../../../algorithms/three-way-merge.md)），见 [`../../../features/duplicate-detection.md`](../../../features/duplicate-detection.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`DuplicateGroup.new`](#duplicategroup-new) | 构造函数（`DuplicateGroup`） | A | 创建重复组实例。 |
| `label` | 方法（`DuplicateGroup`） | B | 返回本组重复原因的本地化标签。 |
| [`DuplicateResult.new`](#duplicateresult-new) | 构造函数（`DuplicateResult`） | A | 创建重复扫描结果实例。 |
| `hasDuplicates` | getter（`DuplicateResult`） | B | 是否找到任何重复组。 |
| `totalDuplicates` | getter（`DuplicateResult`） | B | 涉及重复的动画总数。 |
| [`ImportBundle.new`](#importbundle-new) | 构造函数（`ImportBundle`） | A | 创建已解析导入捆绑实例。 |
| `hasConflicts` | getter（`ImportBundle`） | B | 捆绑是否有任何冲突记录。 |
| [`_normalizeTitle`](#_normalizetitle) | 方法（`DuplicateService`） | A | 为重复比较规范化标题。 |
| [`_titlesMatch`](#_titlesmatch) | 方法（`DuplicateService`） | A | 返回两部动画的标题（主或日文，交叉匹配）规范化后是否相等。 |
| [`_datesMatch`](#_datesmatch) | 方法（`DuplicateService`） | A | 返回两部动画的首播日期是否匹配，null 视为弱匹配。 |
| [`_seasonsMatch`](#_seasonsmatch) | 方法（`DuplicateService`） | A | 返回两部动画的季标签是否匹配，空视为弱匹配。 |
| [`_urlsMatch`](#_urlsmatch) | 方法（`DuplicateService`） | A | 返回两部动画是否共享非空 info 或 watch URL。 |
| [`_duplicateReason`](#_duplicatereason) | 方法（`DuplicateService`） | A | 返回一对的最强重复原因，不是重复则为 null。 |
| [`detect`](#detect) | 方法（`DuplicateService`） | A | 扫描动画列表并返回传递分组的重复组。 |
| [`findConflict`](#findconflict) | 方法（`DuplicateService`） | A | 找与候选冲突的第一条本地动画（导入使用）。 |
| `_firstNonNull` | 方法（`DuplicateService`） | B | 从可迭代返回第一个非 null 值。 |
| [`merge`](#merge) | 方法（`DuplicateService`） | A | 用字段优先级规则把主动画与后备记录合并。 |

## 文档

### `const DuplicateGroup({required this.animes, required this.reason})` <a id="duplicategroup-new"></a>
- **种类：** `DuplicateGroup` 的构造函数
- **来源：** `lib/shared/services/duplicate_service.dart`（约第 26 行）
- **用途：** 保存一组被视为互相同的动画记录，外加最强匹配原因。
- **输入：** `animes` — 组成员；`reason` — 组内任意一对中找到的最强 `DuplicateReason`。
- **返回：** 新的 `DuplicateGroup`。
- **副作用：** 无。
- **算法：** 直接字段赋值。
- **用法：**
  ```dart
  DuplicateGroup(animes: members, reason: strongest)
  ```
  （来自 [`detect`](#detect)，构建结果列表）
- **备注：** 无。

### `const DuplicateResult({required this.groups})` <a id="duplicateresult-new"></a>
- **种类：** `DuplicateResult` 的构造函数
- **来源：** `lib/shared/services/duplicate_service.dart`（约第 51 行）
- **用途：** 包装一次扫描找到的完整重复组列表。
- **输入：** `groups` — 检测到的 `DuplicateGroup` 列表。
- **返回：** 新的 `DuplicateResult`。
- **副作用：** 无。
- **算法：** 直接字段赋值。
- **用法：** 由 [`detect`](#detect) 返回。
- **备注：** 无。

### `const ImportBundle({required this.animes, required this.conflictIndices, required this.localVersions})` <a id="importbundle-new"></a>
- **种类：** `ImportBundle` 的构造函数
- **来源：** `lib/shared/services/duplicate_service.dart`（约第 85 行）
- **用途：** 保存 `.myanimeitem` 捆绑在应用到存储之前被解析的结果。
- **输入：** `animes` — 已解析记录（已给新 UUID）；`conflictIndices` — `animes` 中与既有本地记录冲突的索引；`localVersions` — 每个此类索引对应的冲突本地记录。
- **返回：** 新的 `ImportBundle`。
- **副作用：** 无。
- **算法：** 直接字段赋值。
- **用法：** 由 [`file_open_service.md`](file_open_service.md) 的 `parseBundle` 构造；由 `lib/shared/widgets/import_bundle_dialog.dart` 的冲突解决流程消费。
- **备注：** 无。

### `static String _normalizeTitle(String text)` <a id="_normalizetitle"></a>
- **种类：** `DuplicateService` 的静态方法
- **来源：** `lib/shared/services/duplicate_service.dart`（约第 107 行）
- **用途：** 规范化标题字符串，使细微格式差异（空格、标点、全角字符）不阻止重复检测。
- **输入：** `text` — 原始标题（主或日文）。
- **返回：** `String` — 小写化、修剪，剥离常见 ASCII/CJK 标点和空白（含全角空格 `　` 和间隔点 `·`）。
- **副作用：** 无。
- **算法：** 小写化文本，然后 `replaceAll` 一个覆盖空白、`·`、连字符、下划线、全/半角冒号、`!`/`！`、`?`/`？`、`.`/`。`、`,`/`，`、括号（ASCII 和全角）、方括号 `[]`/`【】` 和日式引号 `「」`/`『』` 的字符类；修剪结果。
- **用法：** 从 [`_titlesMatch`](#_titlesmatch) 内部调用。
- **备注：** 纯文本规范化——不碰罗马字化或翻译，因此跨来源翻译不同的标题即使规范化后也不会匹配。

### `static bool _titlesMatch(Anime a, Anime b)` <a id="_titlesmatch"></a>
- **种类：** `DuplicateService` 的静态方法
- **来源：** `lib/shared/services/duplicate_service.dart`（约第 120 行）
- **用途：** 决定两部动画的标题是否应视为同一部动画。
- **输入：** `a`、`b` — 被比较的两部动画。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** 经 [`_normalizeTitle`](#_normalizetitle) 规范化两部动画的 `displayTitle` 和 `titleJa`。匹配条件：规范化主标题相等且非空；或规范化日文标题相等且非空；或一侧的主标题等于另一侧的日文标题（交叉匹配，任一方向）——最后一种情况捕获一个来源把日文标题存为"主"标题、另一个存为 `titleJa` 的记录。
- **用法：** 从 [`_duplicateReason`](#_duplicatereason) 内部调用。
- **备注：** 空的规范化标题单独绝不构成匹配（防止两部无标题动画被分到一组）。

### `static bool _datesMatch(Anime a, Anime b)` <a id="_datesmatch"></a>
- **种类：** `DuplicateService` 的静态方法
- **来源：** `lib/shared/services/duplicate_service.dart`（约第 141 行）
- **用途：** 决定两部动画的首播日期是否兼容用于重复分组。
- **输入：** `a`、`b`。
- **返回：** `bool` — 任一日期为 null（弱/未知匹配）为 `true`，或年/月/日全部一致为 `true`。
- **副作用：** 无。
- **算法：** 任一 `firstAirDate` 为 null 时返回 `true`（无日期动画仍可仅按标题+季分组）；否则比较年、月、日分量。
- **用法：** 从 [`_duplicateReason`](#_duplicatereason) 内部调用，作为标题+季+日期匹配的一部分。
- **备注：** 把 null 视为匹配是刻意的——它是 [`_duplicateReason`](#_duplicatereason) 中 AND 在一起的三个条件之一，因此它只弱化日期检查，不弱化整个匹配（标题和季仍须一致）。

### `static bool _seasonsMatch(Anime a, Anime b)` <a id="_seasonsmatch"></a>
- **种类：** `DuplicateService` 的静态方法
- **来源：** `lib/shared/services/duplicate_service.dart`（约第 153 行）
- **用途：** 决定两部动画的季标签是否兼容用于重复分组。
- **输入：** `a`、`b`。
- **返回：** `bool` — 任一季字符串为空（弱匹配）为 `true`，或小写化、修剪后的值相等为 `true`。
- **副作用：** 无。
- **算法：** 小写化/修剪两个 `season` 字段；任一为空则返回 `true`，否则比较相等性。
- **用法：** 从 [`_duplicateReason`](#_duplicatereason) 内部调用。
- **备注：** 无。

### `static bool _urlsMatch(Anime a, Anime b)` <a id="_urlsmatch"></a>
- **种类：** `DuplicateService` 的静态方法
- **来源：** `lib/shared/services/duplicate_service.dart`（约第 166 行）
- **用途：** 决定两部动画是否共享相同的非空 info URL 或 watch URL。
- **输入：** `a`、`b`。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** 两个 `infoUrl` 值都非空且相等时返回 `true`，或两个 `watchUrl` 值都非空且相等时返回 `true`；否则 `false`。
- **用法：** 从 [`_duplicateReason`](#_duplicatereason) 内部调用。
- **备注：** 无。

### `static DuplicateReason? _duplicateReason(Anime a, Anime b)` <a id="_duplicatereason"></a>
- **种类：** `DuplicateService` 的静态方法
- **来源：** `lib/shared/services/duplicate_service.dart`（约第 186 行）
- **用途：** 返回两条动画记录应被视为重复的最强原因，或完全不重复时为 `null`。
- **输入：** `a`、`b`。
- **返回：** `DuplicateReason?` — 按此优先级 `sameId` > `sameUrl` > `sameTitleSeason`，或 `null`。
- **副作用：** 无。
- **算法：**
  1. `a.id == b.id` 时返回 `DuplicateReason.sameId`。
  2. 否则 [`_urlsMatch`](#_urlsmatch) 时返回 `DuplicateReason.sameUrl`。
  3. 否则 [`_titlesMatch`](#_titlesmatch) AND [`_seasonsMatch`](#_seasonsmatch) AND [`_datesMatch`](#_datesmatch) 全部成立时返回 `DuplicateReason.sameTitleSeason`。
  4. 否则返回 `null`。
- **用法：** 从 [`detect`](#detect) 和 [`findConflict`](#findconflict) 内部调用；这是"这两条记录是否是同一部动画"的唯一事实来源。
- **备注：** 无。

### `static DuplicateResult detect(List<Anime> animes)` <a id="detect"></a>
- **种类：** `DuplicateService` 的静态方法
- **来源：** `lib/shared/services/duplicate_service.dart`（约第 203 行）
- **用途：** 扫描动画列表并传递性地把互为重复的记录分组。
- **输入：** `animes` — 要扫描的完整列表（通常是所有本地存储的动画）。
- **返回：** `DuplicateResult` — 两个或更多成员的组，按第一个成员的 `displayTitle` 排序；每部动画至多出现在一组中。
- **副作用：** 无（纯计算）。
- **算法：** 对列表索引做并查集：
  1. 为每个索引初始化 `parent[i] = i`。
  2. 对每个 `i < j` 的 `(i, j)` 对，[`_duplicateReason`](#_duplicatereason) 非 null 时合并它们的集合（路径压缩 `find`）。
  3. 按根 parent 分组索引；丢弃单例组（大小 1）。
  4. 对每个存活组，重新计算组内所有对中的最强原因（`sameId` > `sameUrl` > `sameTitleSeason`）供显示。
  5. 按第一个成员的 `displayTitle` 排序组，保证稳定的 UI 顺序。
- **用法：**
  ```dart
  _result = DuplicateService.detect(_allAnime);
  ```
  （来自 `lib/shared/widgets/duplicate_check_page.dart`，填充"检查重复"页）
- **备注：** O(n²) 逐对比较——对典型的个人动画列表规模可接受，但非常大的资料库需要重新审视。传递分组的理由（A~B、B~C ⇒ 一组，即使 A 不直接匹配 C）见 [`../../../features/duplicate-detection.md`](../../../features/duplicate-detection.md)。

### `static Anime? findConflict(List<Anime> local, Anime candidate)` <a id="findconflict"></a>
- **种类：** `DuplicateService` 的静态方法
- **来源：** `lib/shared/services/duplicate_service.dart`（约第 270 行）
- **用途：** 找与传入候选记录重复的第一条既有本地动画，供导入冲突检测。
- **输入：** `local` — 当前本地动画列表；`candidate` — 传入（即将导入）的记录。
- **返回：** `Anime?` — 第一条冲突本地记录，无冲突为 `null`。
- **副作用：** 无。
- **算法：** 线性扫描 `local`，返回 [`_duplicateReason`](#_duplicatereason) 对 `candidate` 非 null 的第一条。
- **用法：**
  ```dart
  final match = DuplicateService.findConflict(localList, parsed[i]);
  ```
  （来自 [`file_open_service.md`](file_open_service.md) 的 `parseBundle`，导入前标记与既有本地记录冲突的捆绑条目）
- **备注：** 只返回*第一*条冲突——候选匹配多条本地记录时，其余不被报告。

### `static Anime merge(Anime primary, List<Anime> others)` <a id="merge"></a>
- **种类：** `DuplicateService` 的静态方法
- **来源：** `lib/shared/services/duplicate_service.dart`（约第 297 行）
- **用途：** 把重复组合并为一条记录，`primary` 赢得字段冲突、`others` 填补空缺。
- **输入：** `primary` — 其 `id` 和字段值优先的记录；`others` — 要并入的其余重复记录。
- **返回：** `Anime` — 从 `primary.copyWith(...)` 构建的新记录，保留 `primary.id`。
- **副作用：** 无（纯；调用方负责持久化结果并删除被并入的记录）。
- **算法：**
  1. **剧集状态：** 从 `primary` 的状态开始；对每条其他记录的逐集状态，保留 primary 的既有值，除非传入值是 `watched`（总是胜出），或传入值是 `skippedThisWeek` 且当前值不是 `watched`——即优先级 watched > skipped > unwatched。
  2. **周偏移：** primary 胜出；缺失键按顺序从 `others` 填补。
  3. **评分：** 逐字段构建（`overall`、`visual`、`story`、`character`、`music`、`enjoyment`）——每字段 primary 值胜出，回退到 `primary` + `others` 中第一个非 null 值；primary 完全没有评分时，第一个有任何数据的后备评分被整体采用。每个来源的未知评分 JSON（`extraJson`）经 `withExtraJson` 求并集。
  4. **备注：** `primary` 和 `others` 中每个非空、不同（按修剪文本）的备注，按顺序用换行连接（拼接，不按措辞不同的备注去重）。
  5. **封面图像：** primary 胜出；回退到 `others` 中第一个非 null 封面。
  6. 对 `endEpisode`、`manualType`、`airDayOfWeek`、`airTime`、`firstAirDate`（primary 胜出-否则-第一个非 null 模式）、`episodeStatuses`、`episodeWeekOffsets`、`coverImage`、`infoUrl`、`watchUrl`、`notes`、`rating` 和新 UTC `modifiedAt` 经 `primary.copyWith(...)` 构建最终 `Anime`；然后调用 `withPreservedUnknownJson([primary, ...others])`，使未知顶层 JSON 字段在合并中存活（`extraJson` 模式——见 [`../../../data-formats.md`](../../../data-formats.md)）。
- **用法：**
  ```dart
  final merged = DuplicateService.merge(local, [imported]);
  ```
  （来自 `lib/shared/widgets/import_bundle_dialog.dart`，解决用户选择合并的导入冲突；`lib/shared/widgets/duplicate_check_page.dart` 的 `_resolveGroup` 的"检查重复"合并操作也使用）
- **备注：** 这是**本地、一次性**的合并，区别于 WebDAV 同步的逐记录三方合并——两者有何不同（合并两条不同记录的 ID vs 跨设备调和一条记录的 ID）见 [`../../../features/duplicate-detection.md`](../../../features/duplicate-detection.md)。
