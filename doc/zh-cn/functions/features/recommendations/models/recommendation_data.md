# lib/features/recommendations/models/recommendation_data.dart

`recommendations.json` 的模型（1.6.2）：全局推荐垃圾箱、被移入垃圾箱的
缺失续作卡片，以及每条记录持久保存的相关推荐列表及其自己的垃圾箱。该文件是一个
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
| `RelatedItem.new` | 构造函数（`RelatedItem`） | B | 创建一个相关推荐项：一个动画 id、理由代码，以及可选的 AI 理由。 |
| `RelatedItem.fromJson` | 静态方法（`RelatedItem`） | B | 读取一个项；没有字符串 `id` 时为 null。 |
| `RelatedItem.toJson` | 方法（`RelatedItem`） | B | 序列化；空的 `reasons` 省略。 |
| `RelatedItem.withAiReason` | 方法（`RelatedItem`） | B | 复制该项并带上生成的理由。 |
| `RelatedSnapshot.new` | 构造函数（`RelatedSnapshot`） | B | 创建一个快照：`generatedAt`、项目、垃圾箱。 |
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
- **来源：** `lib/features/recommendations/models/recommendation_data.dart`（约第 107 行）
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
- **来源：** `lib/features/recommendations/models/recommendation_data.dart`（约第 193 行）
- **用途：** 把一个被移入垃圾箱的缺失续作条目的两侧合二为一。
- **输入：** `other` — 远端侧。
- **返回：** `HiddenSequelEntry`。
- **副作用：** 无。
- **算法：** `sourceId`、`title` 和 `source` 取本侧，否则取另一侧；取较早的
  `hiddenAt`；未知键取并集，以本侧为准。
- **用法：** `mergeRecommendations`。
- **备注：** 这些标签的存在，是为了在对应关系消失后垃圾箱仍能说出该条目的名称。

### `Map<String, dynamic> toJson()` <a id="relatedsnapshot-tojson"></a>
- **种类：** `RelatedSnapshot` 的方法
- **来源：** `lib/features/recommendations/models/recommendation_data.dart`（约第 345 行）
- **用途：** 序列化一条记录的相关推荐列表及其垃圾箱。
- **输入：** 无。
- **返回：** `Map<String, dynamic>`。
- **副作用：** 无。
- **算法：** 先写未知键，然后在已设置时写 `generatedAt`，有项目时按排名顺序写 `items`，
  有垃圾箱条目时写按 id 排序的 `hidden`。
- **用法：** `RecommendationData.toJson`。
- **备注：** 项目保持原有顺序，因为那就是排名；垃圾箱排序，这样未变化的数据
  写出的字节完全相同。

### `factory RecommendationData.fromJson(Object? json)` <a id="recommendationdata-fromjson"></a>
- **种类：** `RecommendationData` 的工厂构造函数
- **来源：** `lib/features/recommendations/models/recommendation_data.dart`（约第 399 行）
- **用途：** 读取 `recommendations.json`。
- **输入：** `json` — 解码后的文件。
- **返回：** `RecommendationData`。
- **副作用：** 无。
- **算法：** 除非 `json` 是 `Map`，否则抛出 `FormatException`。读取 `version`（默认 1），
  通过 `_indexed` 读取 `hidden` 和 `hiddenSequels`，把 `related` 读为快照映射，丢弃任何
  不是对象的值。其余内容都放入 `extraJson`。
- **用法：** `RecommendationStore.load`、合并，以及 `validateRecommendationsJson`。
- **备注：** 这唯一的拒绝是有意为之：同步校验必须拒绝不属于我们的文件。

### `Map<String, dynamic> toJson()` <a id="recommendationdata-tojson"></a>
- **种类：** `RecommendationData` 的方法
- **来源：** `lib/features/recommendations/models/recommendation_data.dart`（约第 435 行）
- **用途：** 序列化整个文件。
- **输入：** 无。
- **返回：** `Map<String, dynamic>`。
- **副作用：** 无。
- **算法：** 先写未知键，然后写 `version`、按 id 排序的 `hidden`、按键排序的 `hiddenSequels`，
  以及按动画 id 排序并丢弃空快照的 `related`。
- **用法：** `encodeRecommendationData`。
- **备注：** 正是排序让未变化的文件能走同步的原始相等快速路径。
