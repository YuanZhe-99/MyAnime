# lib/features/ai/services/ai_insights_cache.dart

`AiInsightsCache` 拥有 `ai_insights.json`，即端侧模型生成结果的本设备缓存（1.6.0，M4）。该文件保存 `AiInsights`：
按动画 id 索引的已缓存分类（`AiCategoryEntry`，带一个 `AiCategoryStatus`），以及一个已经在 schema 中的
`hiddenRecommendations` id 列表：1.6.0–1.6.1 中它是本设备的「不感兴趣」列表；自 1.6.2 起只在迁移时读取，把这些 id
移入同步的 `recommendations.json`，之后保持为空（见
[`../../recommendations/services/recommendation_store.md`](../../recommendations/services/recommendation_store.md#migratefrominsights)）。
它是唯一读写该缓存的文件。schema 见
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md)，
它在持久化数据清单中的位置见 [`../../../../data-formats.md`](../../../../data-formats.md)。

## 这个文件为什么不同步

它仿照 [`MetadataCache`](../../anime/services/metadata_cache.md)：容错加载、原子的格式化写入、不调用
`AutoSyncService.notifySaved`，也不注册进 [`../../../app/data_modules.md`](../../../app/data_modules.md)——因此同步和
备份都看不到它。它仍然位于 `AnimeStorage.getAppDir()` 之下，因此更改存储路径时会一起迁移。其中的一切都可以重新
生成，而产生它的模型属于本设备。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `AiCategoryEntry.new` | 构造函数（`AiCategoryEntry`） | B | 创建一个缓存条目。 |
| `AiCategoryEntry.toJson` | 方法（`AiCategoryEntry`） | B | 序列化条目；`model` 仅在已知时写出，`generatedAt` 用 UTC。 |
| [`AiCategoryEntry.fromJson`](#aicategoryentry-fromjson) | 静态方法（`AiCategoryEntry`） | A | 容错地读取一个条目。 |
| `AiInsights.new` | 构造函数（`AiInsights`） | B | 创建洞察存储，默认为空。 |
| [`AiInsights.toJson`](#aiinsights-tojson) | 方法（`AiInsights`） | A | 序列化存储。 |
| `AiInsights.fromJson` | 工厂构造函数（`AiInsights`） | B | 容错地读取存储，丢弃格式错误的部分。 |
| `AiInsightsCache._` | 构造函数（`AiInsightsCache`） | B | 阻止实例化。 |
| `AiInsightsCache._file` | 静态方法（`AiInsightsCache`） | B | 解析应用目录下的缓存文件。 |
| [`AiInsightsCache.load`](#aiinsightscache-load) | 静态方法（`AiInsightsCache`） | A | 加载缓存，修剪已删除记录的条目。 |
| [`AiInsightsCache.save`](#aiinsightscache-save) | 静态方法（`AiInsightsCache`） | A | 保存缓存。 |

`AiCategoryStatus` 枚举（`ok`、`none`、`skipped`）、条目与存储的字段，以及 `AiInsightsCache.fileName` 没有
`/// Purpose:` 注释，不作为行。

## 文档

### `static AiCategoryEntry? fromJson(Object? json)` <a id="aicategoryentry-fromjson"></a>
- **种类：** `AiCategoryEntry` 的静态方法
- **来源：** `lib/features/ai/services/ai_insights_cache.dart`（约第 70 行）
- **用途：** 容错地读取一个条目。
- **输入：** `json` — `categories` 映射中的一个值。
- **返回：** `AiCategoryEntry?` — 不可用时为 `null`。
- **副作用：** 无。
- **算法：** 要求是一个映射，带字符串 `fingerprint`、已知的 `status` 名称和可解析的 `generatedAt`；否则返回 `null`。
  `ids` 只保留字符串项；`model` 可选。
- **用法：** `AiInsights.fromJson`，每个条目一次。
- **备注：** 与 `anime_data.json` 不同，格式错误的内容不会被保留：缓存可以重建，丢掉一个条目只意味着该记录会被重新分类。

### `Map<String, dynamic> toJson()`（`AiInsights`） <a id="aiinsights-tojson"></a>
- **种类：** `AiInsights` 的方法
- **来源：** `lib/features/ai/services/ai_insights_cache.dart`（约第 118 行）
- **用途：** 序列化存储。
- **输入：** 无。
- **返回：** `Map<String, dynamic>` — `version: 1`、`categories`、`hiddenRecommendations`。
- **副作用：** 无。
- **算法：** `categories` 的键按排序写出，`hiddenRecommendations` 也排序。
- **用法：** `AiInsightsCache.save`。
- **备注：** 排序意味着未改变的存储会写出相同的字节。

### `static Future<AiInsights> load({Set<String>? liveIds})` <a id="aiinsightscache-load"></a>
- **种类：** `AiInsightsCache` 的静态方法
- **来源：** `lib/features/ai/services/ai_insights_cache.dart`（约第 186 行）
- **用途：** 加载缓存，修剪已删除记录的条目。
- **输入：** `liveIds` — 仍然存在的记录的 id，为 `null` 时跳过修剪。
- **返回：** `Future<AiInsights>` — 文件不存在或无法读取时为空。
- **副作用：** 读取 `ai_insights.json`。
- **算法：** 经 `AiInsights.fromJson` 解码；给出 `liveIds` 时，移除不在其中的每个 `categories` 条目和
  `hiddenRecommendations` id。任何异常都得到空存储。
- **用法：** `CategoryClassifier` 用片库的 id 加载；详情页和管理页不修剪地加载，只用于解析分类。
- **备注：** 修剪在内存中进行；下一次 `save` 才写出。

### `static Future<void> save(AiInsights insights)` <a id="aiinsightscache-save"></a>
- **种类：** `AiInsightsCache` 的静态方法
- **来源：** `lib/features/ai/services/ai_insights_cache.dart`（约第 210 行）
- **用途：** 保存缓存。
- **输入：** `insights`。
- **返回：** 无。
- **副作用：** 用 `JsonEncoder.withIndent('  ')` 写入 `ai_insights.json.tmp`，再重命名覆盖该文件。
- **用法：** `CategoryClassifier._run`，每分类一条记录之后。
- **备注：** 从不调用 `AutoSyncService.notifySaved`——该文件从不同步。
