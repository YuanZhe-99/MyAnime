# lib/features/recommendations/services/recommendation_merge.dart

`recommendations.json` 的三方合并（1.6.2）。它**从不产生冲突**：垃圾箱
是集合，对照基线快照就能区分「一侧移入垃圾箱」与「另一侧恢复」；而相关推荐列表是
可重新生成的缓存，较新的一方胜出。这就是为什么
[`../../../app/data_modules.md`](../../../app/data_modules.md) 中的模块总是返回完整结果，
冲突对话框永远不会看到这个文件。见
[`../../../../sync.md`](../../../../sync.md#推荐文件)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`encodeRecommendationData`](#encoderecommendationdata) | 顶层函数 | A | 按存储保存时的方式编码存储内容。 |
| [`mergeKeyedSet`](#mergekeyedset) | 顶层函数 | A | 对一个带键集合做三方合并。 |
| [`mergeRelatedSnapshot`](#mergerelatedsnapshot) | 顶层函数 | A | 对一条记录的相关推荐快照做三方合并。 |
| [`mergeRecommendations`](#mergerecommendations) | 顶层函数 | A | 合并本地、远端和基线的存储内容。 |
| [`mergeRecommendationJson`](#mergerecommendationjson) | 顶层函数 | A | 为同步引擎合并三方的原始 JSON。 |

## 文档

### `String encodeRecommendationData(RecommendationData data)` <a id="encoderecommendationdata"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/recommendations/services/recommendation_merge.dart`（约第 19 行）
- **用途：** 为写入磁盘和上传编码存储内容。
- **输入：** `data`。
- **返回：** 美化输出的 JSON（`JsonEncoder.withIndent('  ')`）。
- **副作用：** 无。
- **算法：** `_prettyJson.convert(data.toJson())`。
- **用法：** `RecommendationStore` 的保存以及 `mergeRecommendationJson`。
- **备注：** 两条路径对同一数据必须产生完全相同的字节，否则未变化的文件会在
  每次同步时重新上传。

### `Map<String, T> mergeKeyedSet<T>(Map<String, T> local, Map<String, T> remote, Map<String, T>? base, T Function(T, T) both)` <a id="mergekeyedset"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/recommendations/services/recommendation_merge.dart`（约第 30 行）
- **用途：** 合并一个垃圾箱。
- **输入：** `local`、`remote`；`base` — 首次同步时为 null；`both` — 合并两侧都有的
  条目。
- **返回：** `Map<String, T>`。
- **副作用：** 无。
- **算法：** 对任一侧出现的每个键：两侧都有时，`both(l, r)`；只有一侧有时，若基线没有它
  （说明是那一侧新增的）则保留，若基线有它（说明另一侧删除了它）则丢弃。没有基线时全部保留。
- **用法：** 全局垃圾箱、被移入垃圾箱的续作，以及每条记录自己的垃圾箱。

| 本地 | 远端 | 基线 | 结果 |
|---|---|---|---|
| 有 | 有 | 任意 | 保留，`both` |
| 有 | — | — | 保留：本地移入垃圾箱 |
| 有 | — | 有 | 丢弃：远端已恢复 |
| — | 有 | — | 保留：远端移入垃圾箱 |
| — | 有 | 有 | 丢弃：本地已恢复 |

- **备注：** 没有墓碑记录的集合无法区分所有历史。如果在同样两次同步之间，一台设备恢复了某个
  条目，而另一台设备恢复后又再次把它移入垃圾箱，则恢复胜出：只在一侧存在、而基线也有的条目
  会被视为已删除。再移入垃圾箱一次即可修正。

### `RelatedSnapshot? mergeRelatedSnapshot(RelatedSnapshot? local, RelatedSnapshot? remote, RelatedSnapshot? base)` <a id="mergerelatedsnapshot"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/recommendations/services/recommendation_merge.dart`（约第 56 行）
- **用途：** 合并一条记录的相关推荐列表及其垃圾箱。
- **输入：** `local`、`remote`、`base` — 都可能为 null。
- **返回：** `RelatedSnapshot?` — 快照被删除时为 null。
- **副作用：** 无。
- **算法：** 只有一侧有时，遵循集合规则（除非基线有它，否则保留）。两侧都有时：项目和
  `generatedAt` 取生成时间较晚的一侧（相同时保留本地），垃圾箱通过
  `mergeKeyedSet` 合并，未知键取并集，以本地为准。
- **用法：** `mergeRecommendations`。
- **备注：** 相关推荐列表是缓存，因此「较新者胜出」不会丢失任何无法重新生成的内容；而
  垃圾箱是用户的决定，永远不按时间戳裁决。

### `RecommendationData mergeRecommendations(RecommendationData local, RecommendationData remote, RecommendationData? base)` <a id="mergerecommendations"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/recommendations/services/recommendation_merge.dart`（约第 87 行）
- **用途：** 合并整个存储。
- **输入：** `local`、`remote`、`base`。
- **返回：** `RecommendationData`。
- **副作用：** 无。
- **算法：** 对 `hidden` 和 `hiddenSequels` 使用 `mergeKeyedSet`，对每个记录 id 使用 `mergeRelatedSnapshot`，
  取较高的 `version`，顶层未知键取并集，以本地为准。
- **用法：** `mergeRecommendationJson`。
- **备注：** 无。

### `String mergeRecommendationJson(String localJson, String remoteJson, String? baseJson)` <a id="mergerecommendationjson"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/recommendations/services/recommendation_merge.dart`（约第 126 行）
- **用途：** 为同步引擎合并原始文件。
- **输入：** `localJson`、`remoteJson`；`baseJson` — 首次同步时为 null。
- **返回：** 合并后的文件，美化输出。
- **副作用：** 无。
- **算法：** 解码三者；无法读取的基线视为不存在；合并；编码。
- **用法：** `data_modules.dart` 中的 `mergeRecommendationsModule`。
- **备注：** 无法读取的基线会保留所有条目，而不是丢弃任何条目。不是 JSON 对象的本地或远端文件
  会抛出异常，同步引擎会将其报告为该模块的合并失败。
