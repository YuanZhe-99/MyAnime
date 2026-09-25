# lib/features/recommendations/models/recommendation_data.dart

`recommendations.json` 的模型（1.6.2）：全局推荐垃圾箱、被移入垃圾箱的
缺失续作卡片，以及每条记录持久保存的相关推荐列表及其自己的垃圾箱。自 1.6.3 起它还保存钉选的卡片（`PinnedEntry`，全局的
以及每个相关推荐列表的）和每部缺失续作抓取到的简介与缩略图（`SequelInfo`）。该文件是一个
同步的数据模块（见 [`../../../app/data_modules.md`](../../../app/data_modules.md)），因此每个
类都把未知 JSON 键保存在 `extraJson` 中并原样写回。解析是宽容的——格式错误的
条目会被丢弃——唯一的例外是不是 JSON 对象的文件会被拒绝，这样同步校验就会
拒绝不属于我们的文件。结构定义见
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md#文件recommendationsjson)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `_unknown` | 顶层函数 | B | 收集某个类不认识的键，放入 `extraJson`。 |
| `_time` | 顶层函数 | B | 宽容地读取一个 UTC 时间戳。 |
| `_indexed` | 顶层函数 | B | 把 JSON 列表解析为以每个条目的键为键的映射；后出现的重复项胜出。 |
| `_earlier` | 顶层函数 | B | 取两个可选时间戳中较早的一个。 |
| `HiddenEntry.new` | 构造函数（`HiddenEntry`） | B | 创建一个垃圾箱条目：一个动画 id 及其移入垃圾箱的时间。 |
| `HiddenEntry.fromJson` | 静态方法（`HiddenEntry`） | B | 读取一个条目；没有字符串 `id` 时为 null。 |
| `HiddenEntry.toJson` | 方法（`HiddenEntry`） | B | 序列化，未知键在前。 |
| [`HiddenEntry.mergedWith`](#hiddenentry-mergedwith) | 方法（`HiddenEntry`） | A | 合并时把一个条目的两侧合二为一。 |
| `HiddenSequelEntry.new` | 构造函数（`HiddenSequelEntry`） | B | 创建一个带标签的、被移入垃圾箱的缺失续作条目。 |
| `HiddenSequelEntry.fromJson` | 静态方法（`HiddenSequelEntry`） | B | 读取一个条目；没有字符串 `key` 时为 null。 |
| `HiddenSequelEntry.toJson` | 方法（`HiddenSequelEntry`） | B | 序列化。 |
| [`HiddenSequelEntry.mergedWith`](#hiddensequelentry-mergedwith) | 方法（`HiddenSequelEntry`） | A | 合并时把一个条目的两侧合二为一。 |
| `PinnedEntry.new` | 构造函数（`PinnedEntry`） | B | 创建一个钉选：一个动画 id 或续作键，及其钉选时间（1.6.3）。 |
| `PinnedEntry.fromJson` | 静态方法（`PinnedEntry`） | B | 读取一个钉选；片库钉选的 `idKey` 为 `id`，续作钉选为 `key`。 |
| `PinnedEntry.toJson` | 方法（`PinnedEntry`） | B | 以同一个 `idKey` 序列化。 |
| `PinnedEntry.mergedWith` | 方法（`PinnedEntry`） | B | 把一个钉选的两侧合二为一：取较早的 `pinnedAt`，未知键取并集。 |
| `SequelInfo.new` | 构造函数（`SequelInfo`） | B | 创建一部缺失续作抓取到的资料：简介、封面 URL、base64 缩略图、`fetchedAt`（1.6.3）。 |
| `SequelInfo.fromJson` | 静态方法（`SequelInfo`） | B | 读取资料；不是对象时为 null。 |
| `SequelInfo.toJson` | 方法（`SequelInfo`） | B | 序列化；缺失的字段省略。 |
| [`SequelInfo.mergedWith`](#sequelinfo-mergedwith) | 方法（`SequelInfo`） | A | 把两侧合二为一：较晚的抓取胜出。 |
| `RelatedItem.new` | 构造函数（`RelatedItem`） | B | 创建一个相关推荐项：一个动画 id、理由代码，以及可选的 AI 理由。 |
| `RelatedItem.fromJson` | 静态方法（`RelatedItem`） | B | 读取一个项；没有字符串 `id` 时为 null。 |
| `RelatedItem.toJson` | 方法（`RelatedItem`） | B | 序列化；空的 `reasons` 省略。 |
| `RelatedItem.withAiReason` | 方法（`RelatedItem`） | B | 复制该项并带上生成的理由。 |
| `RelatedSnapshot.new` | 构造函数（`RelatedSnapshot`） | B | 创建一个快照：`generatedAt`、项目、垃圾箱、钉选（1.6.3）。 |
| `RelatedSnapshot.isGenerated` | getter（`RelatedSnapshot`） | B | 是否曾生成过列表（`generatedAt` 已设置）。 |
| `RelatedSnapshot.isEmpty` | getter（`RelatedSnapshot`） | B | 是否没有值得写入的内容；空快照会被丢弃。 |
| `RelatedSnapshot.fromJson` | 静态方法（`RelatedSnapshot`） | B | 读取一个快照；不是对象时为 null。 |
| [`RelatedSnapshot.toJson`](#relatedsnapshot-tojson) | 方法（`RelatedSnapshot`） | A | 序列化，垃圾箱排序后输出。 |
| `RecommendationData.new` | 构造函数（`RecommendationData`） | B | 用可变集合创建存储内容。 |
| [`RecommendationData.fromJson`](#recommendationdata-fromjson) | 工厂构造函数（`RecommendationData`） | A | 宽容地读取该文件。 |
| [`RecommendationData.toJson`](#recommendationdata-tojson) | 方法（`RecommendationData`） | A | 序列化该文件，每个集合都排序。 |
| `RecommendationData.relatedFor` | 方法（`RecommendationData`） | B | 读取一条记录的快照，不存在时创建一个空快照。 |

`RecommendationData.currentVersion`（1）和各字段没有 `/// Purpose:` 注释，不作为
行。

## 文档

### `HiddenEntry mergedWith(HiddenEntry other)` <a id="hiddenentry-mergedwith"></a>
- **种类：** `HiddenEntry` 的方法
- **来源：** `lib/features/recommendations/models/recommendation_data.dart`（约第 108 行）
- **用途：** 把两台设备都移入垃圾箱的条目的本地侧与远端侧合二为一。
- **输入：** `other` — 远端侧。
- **返回：** `HiddenEntry`，取较早的 `hiddenAt`，并包含两侧的未知键，同一个键上
  以本侧为准。
- **副作用：** 无。
- **算法：** `_earlier(hiddenAt, other.hiddenAt)`；`{...other.extraJson, ...extraJson}`。
- **用法：** [`../services/recommendation_merge.md`](../services/recommendation_merge.md) 中的 `mergeKeyedSet`。
- **备注：** 两侧都认为该记录已移入垃圾箱，因此不可能冲突。

### `HiddenSequelEntry mergedWith(HiddenSequelEntry other)` <a id="hiddensequelentry-mergedwith"></a>
- **种类：** `HiddenSequelEntry` 的方法
- **来源：** `lib/features/recommendations/models/recommendation_data.dart`（约第 194 行）
- **用途：** 把一个被移入垃圾箱的缺失续作条目的两侧合二为一。
- **输入：** `other` — 远端侧。
- **返回：** `HiddenSequelEntry`。
- **副作用：** 无。
- **算法：** `sourceId`、`title` 和 `source` 取本侧，否则取另一侧；取较早的
  `hiddenAt`；未知键取并集，以本侧为准。
- **用法：** `mergeRecommendations`。
- **备注：** 这些标签的存在，是为了在对应关系消失后垃圾箱仍能说出该条目的名称。

### `SequelInfo mergedWith(SequelInfo other)` <a id="sequelinfo-mergedwith"></a>
- **种类：** `SequelInfo` 的方法
- **来源：** `lib/features/recommendations/models/recommendation_data.dart`（约第 338 行）
- **用途：** 把一部续作抓取到的资料的两侧合二为一。
- **输入：** `other` — 远端侧。
- **返回：** `SequelInfo`。
- **副作用：** 无。
- **算法：** 简介、封面 URL、缩略图和 `fetchedAt` 全部取自 `fetchedAt` 较晚的一侧（相同，或另一侧没有时间戳时保留
  本侧）；未知键取并集，以本侧为准。
- **用法：** `mergeRecommendations` 中针对 `sequelInfo` 的 `mergeKeyedSet`。
- **备注：** 这些资料是公开数据的缓存，因此较新的一侧整体胜出；字段不会在不同次抓取之间混合。

### `Map<String, dynamic> toJson()` <a id="relatedsnapshot-tojson"></a>
- **种类：** `RelatedSnapshot` 的方法
- **来源：** `lib/features/recommendations/models/recommendation_data.dart`（约第 511 行）
- **用途：** 序列化一条记录的相关推荐列表及其垃圾箱。
- **输入：** 无。
- **返回：** `Map<String, dynamic>`。
- **副作用：** 无。
- **算法：** 先写未知键，然后在已设置时写 `generatedAt`，有项目时按排名顺序写 `items`，
  有垃圾箱条目时写按 id 排序的 `hidden`，有钉选时写按 id 排序的 `pinned`（1.6.3）。
- **用法：** `RecommendationData.toJson`。
- **备注：** 项目保持原有顺序，因为那就是排名；垃圾箱排序，这样未变化的数据
  写出的字节完全相同。

### `factory RecommendationData.fromJson(Object? json)` <a id="recommendationdata-fromjson"></a>
- **种类：** `RecommendationData` 的工厂构造函数
- **来源：** `lib/features/recommendations/models/recommendation_data.dart`（约第 585 行）
- **用途：** 读取 `recommendations.json`。
- **输入：** `json` — 解码后的文件。
- **返回：** `RecommendationData`。
- **副作用：** 无。
- **算法：** 除非 `json` 是 `Map`，否则抛出 `FormatException`。读取 `version`（默认 1），
  通过 `_indexed` 读取 `hidden` 和 `hiddenSequels`，把 `related` 读为快照映射，丢弃任何
  不是对象的值。自 1.6.3 起还通过 `_indexed` 读取 `pinned` 和 `pinnedSequels`（分别以 `id` 和 `key`
  为键），并把 `sequelInfo` 读为 `SequelInfo` 映射。其余内容都放入 `extraJson`。
- **用法：** `RecommendationStore.load`、合并，以及 `validateRecommendationsJson`。
- **备注：** 这唯一的拒绝是有意为之：同步校验必须拒绝不属于我们的文件。

### `Map<String, dynamic> toJson()` <a id="recommendationdata-tojson"></a>
- **种类：** `RecommendationData` 的方法
- **来源：** `lib/features/recommendations/models/recommendation_data.dart`（约第 639 行）
- **用途：** 序列化整个文件。
- **输入：** 无。
- **返回：** `Map<String, dynamic>`。
- **副作用：** 无。
- **算法：** 先写未知键，然后写 `version`、按 id 排序的 `hidden`、按键排序的 `hiddenSequels`，
  以及按动画 id 排序并丢弃空快照的 `related`。然后，**只在非空时**
  （1.6.3）：按 id 排序的 `pinned`、按键排序的 `pinnedSequels`，以及按键排序的对象 `sequelInfo`。
- **用法：** `encodeRecommendationData`。
- **备注：** 正是排序让未变化的文件能走同步的原始相等快速路径。省略空的 1.6.3 键，使从未用过它们的文件与 1.6.2
  写出的字节完全相同。
