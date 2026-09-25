# lib/features/recommendations/services/recommendation_store.dart

`RecommendationStore`（1.6.2）负责 `AnimeStorage.getAppDir()` 下的 `recommendations.json`。与
`ai_insights.json` 不同，它注册在 [`../../../app/data_modules.md`](../../../app/data_modules.md) 中，
因此会同步、会被备份，每次保存都会调用 `AutoSyncService.notifySaved`。自 1.6.3 起
它还负责钉选和取消钉选卡片，并保存每部缺失续作抓取到的资料；它的任何一次写入之后，同一张卡片的钉选和垃圾箱条目
都不会同时存在。每次写入都是通过 `update`
进行的读取-修改-写入，并在进程内排队，因此与一次*不感兴趣*点击同时发生的相关推荐列表保存
不会丢掉任何一方的更改。见
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `RecommendationStore._` | 构造函数（`RecommendationStore`） | B | 禁止实例化。 |
| `_file` | 静态方法 | B | 解析应用目录下的 `recommendations.json`。 |
| [`load`](#load) | 静态方法 | A | 加载存储；不存在或无法读取时为空。 |
| [`update`](#update) | 静态方法 | A | 应用一个排队的更改并保存。 |
| [`_apply`](#_apply) | 静态方法 | A | 执行一个排队的更新。 |
| `hide` | 静态方法 | B | 把记录放入全局垃圾箱；已在其中的 id 保留原有的 `hiddenAt`；并取消钉选（1.6.3）。 |
| `pin` | 静态方法 | B | 在「接下来看什么」上钉选片库卡片，并把它们移出全局垃圾箱（1.6.3）。 |
| `unpin` | 静态方法 | B | 取消钉选片库卡片（1.6.3）。 |
| `pinSequels` | 静态方法 | B | 钉选缺失续作卡片，并把它们移出垃圾箱（1.6.3）。 |
| `unpinSequels` | 静态方法 | B | 取消钉选缺失续作卡片（1.6.3）。 |
| [`putSequelInfo`](#putsequelinfo) | 静态方法 | A | 保存一部缺失续作抓取到的简介和缩略图（1.6.3）。 |
| `removeSequelInfo` | 静态方法 | B | 丢弃已不在任何地方显示的续作的抓取资料（1.6.3）。 |
| `restore` | 静态方法 | B | 把记录从全局垃圾箱中移出。 |
| `hideSequels` | 静态方法 | B | 把缺失续作卡片放入全局垃圾箱；自 1.6.3 起还取消其钉选并删除其抓取的资料。 |
| `restoreSequels` | 静态方法 | B | 把缺失续作卡片从全局垃圾箱中移出。 |
| [`hideBatch`](#hidebatch) | 静态方法 | A | 一次写入把全局页面当前这一批移入垃圾箱。 |
| [`hideRelated`](#hiderelated) | 静态方法 | A | 把记录放入某条记录自己的相关推荐垃圾箱。 |
| `pinRelated` | 静态方法 | B | 钉选某条记录相关推荐列表中的条目，并把它们移出其垃圾箱（1.6.3）。 |
| `unpinRelated` | 静态方法 | B | 取消钉选某条记录相关推荐列表中的条目（1.6.3）。 |
| `restoreRelated` | 静态方法 | B | 把记录从某条记录的相关推荐垃圾箱中移出。 |
| [`putRelated`](#putrelated) | 静态方法 | A | 持久保存某条记录生成的相关推荐列表。 |
| [`migrateFromInsights`](#migratefrominsights) | 静态方法 | A | 把 1.6.2 之前按设备保存的隐藏列表一次性移入同步的垃圾箱。 |

`fileName`（`recommendations.json`）和私有队列 `_tail` 没有 `/// Purpose:` 注释。

## 文档

### `static Future<RecommendationData> load()` <a id="load"></a>
- **种类：** `RecommendationStore` 的静态方法
- **来源：** `lib/features/recommendations/services/recommendation_store.dart`（约第 55 行）
- **用途：** 读取存储。
- **输入：** 无。
- **返回：** `Future<RecommendationData>` — 文件不存在或无法读取时为空。
- **副作用：** 读取文件。
- **算法：** 通过 `RecommendationData.fromJson` 解码；任何错误都视为空。
- **用法：** 推荐页、垃圾箱页面和相关推荐卡片。
- **备注：** **已删除记录的条目不会被清理。** 读取方会跳过它们。在磁盘上清理
  会被同步视为一次有意的恢复，并可能删除另一台设备上本设备尚未收到的记录的条目。
  动画 id 是 UUID，永不复用，因此悬空条目是
  无害的。

### `static Future<RecommendationData> update(void Function(RecommendationData) mutate)` <a id="update"></a>
- **种类：** `RecommendationStore` 的静态方法
- **来源：** `lib/features/recommendations/services/recommendation_store.dart`（约第 72 行）
- **用途：** 应用一个更改并保存。
- **输入：** `mutate` — 就地编辑已加载的数据。
- **返回：** `Future<RecommendationData>` — 更改后的数据。
- **副作用：** 见 `_apply`。
- **算法：** 把更改串接到 `_tail` 上，并用其结果或错误完成一个 `Completer`。
- **用法：** 下面的每个辅助方法。
- **备注：** 队列是按进程的；不预期有另一个进程写该文件（同步引擎在
  同一进程中）。

### `static Future<RecommendationData> _apply(void Function(RecommendationData) mutate)` <a id="_apply"></a>
- **种类：** `RecommendationStore` 的静态方法
- **来源：** `lib/features/recommendations/services/recommendation_store.dart`（约第 91 行）
- **用途：** 执行一次排队的读取-修改-写入。
- **输入：** `mutate`。
- **返回：** `Future<RecommendationData>`。
- **副作用：** 仅在字节发生变化时，原子写入文件（先写 tmp 再重命名）并调用
  `AutoSyncService.notifySaved`。
- **算法：** 读取当前字节（无法读取的文件从空开始），修改，用
  `encodeRecommendationData` 编码。字节未变化时，或文件不存在且结果为空存储时，
  不写入直接返回。
- **用法：** `update`。
- **备注：** 空存储不创建文件，使从未用过垃圾箱的片库不会有这个文件，
  同步也就不会为它上传任何新内容。

### `static Future<RecommendationData> hideBatch(Iterable<String> ids, Iterable<HiddenSequelEntry> sequels)` <a id="hidebatch"></a>
- **种类：** `RecommendationStore` 的静态方法
- **来源：** `lib/features/recommendations/services/recommendation_store.dart`（约第 254 行）
- **用途：** 把全局页面当前这一批移入垃圾箱。
- **输入：** `ids` — 显示中的片库卡片；`sequels` — 显示中的缺失续作卡片。
- **返回：** `Future<RecommendationData>`。
- **副作用：** 一次写入，一次自动同步通知。
- **算法：** 用同一个共享的 `hiddenAt` 添加每个 id 和每个续作键，保留
  已经存在的条目。自 1.6.3 起还会取消每个 id 和键的钉选，并删除每部移入垃圾箱的续作的 `sequelInfo`。
- **用法：** 推荐页的换一批操作。
- **备注：** 页面不把钉选的卡片放进 `ids` 和 `sequels`（1.6.3），因此换一批从不会把钉选的卡片移入垃圾箱；这里的取消钉选
  只对仍然传入钉选卡片的调用方有意义。

### `static Future<RecommendationData> putSequelInfo(String key, SequelInfo info)` <a id="putsequelinfo"></a>
- **种类：** `RecommendationStore` 的静态方法
- **来源：** `lib/features/recommendations/services/recommendation_store.dart`（约第 188 行）
- **用途：** 保存关于一部缺失续作抓取到的内容（1.6.3）。
- **输入：** `key` — 来自 `sequelTrashKey` 的去重键；`info`。
- **返回：** `Future<RecommendationData>`。
- **副作用：** 除非卡片已在垃圾箱中，否则写入文件。
- **算法：** 在一次 `update` 中：`hiddenSequels` 含有 `key` 时直接返回；否则设置
  `sequelInfo[key] = info`。
- **用法：** 抓取之后由 `SequelInfoService` 调用。
- **备注：** 正是这项垃圾箱检查，使在用户把卡片移入垃圾箱之后才完成的抓取无法把缩略图放回去。移入垃圾箱的卡片只保留
  其标签。

### `static Future<RecommendationData> hideRelated(String animeId, Iterable<String> ids)` <a id="hiderelated"></a>
- **种类：** `RecommendationStore` 的静态方法
- **来源：** `lib/features/recommendations/services/recommendation_store.dart`（约第 287 行）
- **用途：** 把记录放入某条记录自己的相关推荐垃圾箱。
- **输入：** `animeId` — 哪条记录的列表；`ids` — 相关的记录。
- **返回：** `Future<RecommendationData>`。
- **副作用：** 写入文件。
- **算法：** 把每个 id 加入 `related[animeId].hidden`，并将其从该记录的 `pinned` 中移除（1.6.3），然后从其
  `items` 中移除这些 id。
- **用法：** 相关推荐卡片的换一批和*不感兴趣*。
- **备注：** 每条记录的垃圾箱与全局垃圾箱相互独立：在这里移入垃圾箱永远不会让一条记录
  从「接下来看什么」中隐藏。

### `static Future<RecommendationData> putRelated(String animeId, List<RelatedItem> items, {DateTime? generatedAt})` <a id="putrelated"></a>
- **种类：** `RecommendationStore` 的静态方法
- **来源：** `lib/features/recommendations/services/recommendation_store.dart`（约第 353 行）
- **用途：** 持久保存某条记录生成的相关推荐列表。
- **输入：** `animeId`；`items`；`generatedAt` — 默认为当前时间（UTC）。
- **返回：** `Future<RecommendationData>`。
- **副作用：** 写入文件。
- **算法：** 用 `items` 和 `generatedAt` 的快照替换 `related[animeId]`，保留
  现有的垃圾箱、钉选（1.6.3）和未知键。
- **用法：** 相关推荐卡片：列表生成时调用一次，AI 理由到达时以相同的
  `generatedAt` 再调用一次。
- **备注：** 调用方把钉选的条目放在 `items` 的最前面；存储不重新排序。

### `static Future<bool> migrateFromInsights()` <a id="migratefrominsights"></a>
- **种类：** `RecommendationStore` 的静态方法
- **来源：** `lib/features/recommendations/services/recommendation_store.dart`（约第 379 行）
- **用途：** 把 1.6.0–1.6.1 的*不感兴趣*列表移入同步的全局垃圾箱。
- **输入：** 无。
- **返回：** `Future<bool>` — 是否移动了任何内容。
- **副作用：** 可能写入 `recommendations.json` 和 `ai_insights.json`。
- **算法：** 加载 `AiInsightsCache`；若 `hiddenRecommendations` 为空则返回 false；对这些
  id 调用 `hide`；清空该集合；保存缓存。
- **用法：** `RecommendationsPage._load` 和 `RecommendationTrashPage._load`。
- **备注：** 只有在存储保存了这些 id 之后，它们才会离开 `ai_insights.json`。`hiddenAt` 是
  迁移时间，因为旧列表没有保存日期。
