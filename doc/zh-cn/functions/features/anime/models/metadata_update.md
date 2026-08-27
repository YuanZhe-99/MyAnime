# lib/features/anime/models/metadata_update.dart

后台资料更新器的纯模型代码：设备本地缓存文档（`metadata_updates.json`）、存放在 `storage_config.json` 中
的网络策略，以及后台服务与审阅界面共用的纯差异计算与应用辅助函数。

这里的一切都不涉及 Flutter、网络或磁盘 —— 这正是那些真正要紧的决定（什么算不一致、什么可以被提议、什么
可以被覆盖）能够被直接单元测试的原因。行为说明见
[`../../../../features/metadata-auto-update.md`](../../../../features/metadata-auto-update.md)，驱动它的
服务见 [`../services/metadata_update_service.md`](../services/metadata_update_service.md)。

这份数据刻意**不同步**也**不备份**：它是设备本地的簿记加上一份可重建的下载缓存。见
[`../../../../data-formats.md`](../../../../data-formats.md)。

## 类型

| 类型 | 种类 | 用途 |
|---|---|---|
| `MetadataUpdatePolicy` | enum | 后台工作何时可以使用网络：`off`、`noCellular`、`always`。 |
| `MetadataUpdateStatus` | enum | 一部番剧所处的阶段：`proposed`、`needsManualPick`、`dismissed`、`noMatch`、`upToDate`。 |
| `MetadataField` | enum | 流水线可以提议修改的核心 `Anime` 字段。 |
| `MetadataFieldChange` | class | 单个字段的当前值与提议值，用于展示。 |
| `MetadataUpdateEntry` | class | 单部番剧的缓存条目：状态、候选、尝试与退避状态。 |
| `MetadataUpdateStore` | class | 整个 `metadata_updates.json` 文档。 |
| `MetadataScanPhase` | enum | 用户触发的检索所处的阶段：`idle`、`scanning`、`done`、`cancelled`。 |
| `MetadataScanProgress` | class | 一次手动检索的不可变快照，通过 `ValueNotifier` 发布。 |

## 声明

| 声明 | 种类 | 层级 | 用途 |
|---|---|---|---|
| [`parseMetadataUpdatePolicy`](#parsemetadataupdatepolicy) | 函数 | A | 解析持久化的网络策略，失败时回退而非抛出。 |
| `MetadataFieldChange` | 构造器 | B | 创建字段变更记录。 |
| `MetadataUpdateEntry` | 构造器 | B | 创建缓存条目。 |
| [`MetadataUpdateEntry.isPending`](#ispending) | getter | A | 该条目是否正在等待用户。 |
| [`MetadataUpdateEntry.isDue`](#isdue) | 方法 | A | 退避闸门当前是否允许再次尝试。 |
| [`MetadataUpdateEntry.copyWith`](#entrycopywith) | 方法 | A | 创建修改后的副本，带显式清除标志。 |
| `MetadataUpdateEntry.toJson` | 方法 | B | 序列化，未知字段优先写入。 |
| [`MetadataUpdateEntry.fromJson`](#entryfromjson) | 静态方法 | A | 防御式解析，保留无法解析的值。 |
| `MetadataUpdateStore` | 构造器 | B | 创建存储。 |
| `MetadataUpdateStore.entryFor` | 方法 | B | 查找单部番剧的条目。 |
| `MetadataUpdateStore.withEntry` | 方法 | B | 替换或插入一条条目。 |
| [`MetadataUpdateStore.prunedTo`](#prunedto) | 方法 | A | 清理番剧已不存在的条目。 |
| `MetadataUpdateStore.toJson` | 方法 | B | 序列化整个文档。 |
| [`MetadataUpdateStore.fromJson`](#storefromjson) | 工厂 | A | 解析，逐条跳过格式错误的条目。 |
| [`hasEpisodeCountMismatch`](#hasepisodecountmismatch) | 函数 | A | 集数是否与来源真正不一致。 |
| [`needsMetadataDiscovery`](#needsmetadatadiscovery) | 函数 | A | 记录是否残缺到值得搜索。 |
| [`diffCandidate`](#diffcandidate) | 函数 | A | 算出候选会改动哪些核心字段。 |
| [`applyMetadataChanges`](#applymetadatachanges) | 函数 | A | 把已接受的字段写入番剧记录。 |
| `MetadataScanProgress` | 构造器 | B | 创建检索进度快照。 |
| [`MetadataScanProgress.fraction`](#scanfraction) | getter | A | 完成比例，无可度量内容时为 `null`。 |
| `MetadataScanProgress.isRunning` | getter | B | 是否有检索正在进行。 |

## 文档

### `MetadataUpdatePolicy parseMetadataUpdatePolicy(String?, MetadataUpdatePolicy)` <a id="parsemetadataupdatepolicy"></a>
- **种类：** 顶层函数
- **用途：** 把 `storage_config.json` 中原始的 `metadataAutoUpdate` 字符串转换成策略。
- **输入：** `value` —— 存储的字符串，可能为 `null`；`fallback` —— 平台默认值。
- **返回：** `MetadataUpdatePolicy`。
- **副作用：** 无。
- **备注：** 未知字符串走回退而不是抛出，因此由更新版本写入的配置绝不会让旧版本崩溃。回退值由调用方
  提供，因为它与平台相关：Android 与 iOS 为 `noCellular`，桌面为 `always`。

### `bool get isPending` <a id="ispending"></a>
- **种类：** `MetadataUpdateEntry` 的 getter
- **用途：** 报告该条目是否正在等待用户决定。
- **返回：** `bool` —— `proposed` 与 `needsManualPick` 为真。
- **备注：** 驱动管理页的角标计数。`needsManualPick` 也计入，因为用户仍然有事可做，尽管批量操作会跳过它。

### `bool isDue(DateTime now)` <a id="isdue"></a>
- **种类：** `MetadataUpdateEntry` 的方法
- **用途：** 报告退避闸门当前是否允许再次尝试。
- **输入：** `now`，UTC。
- **返回：** `bool`。
- **备注：** 从未尝试过的条目（`nextAttemptAt == null`）永远是到期的。

### `MetadataUpdateEntry copyWith({...})` <a id="entrycopywith"></a>
- **种类：** `MetadataUpdateEntry` 的方法
- **用途：** 产出修改后的副本。
- **输入：** 各字段，外加 `clearCandidate`、`clearNextAttemptAt` 与 `clearCoverCachePath`。
- **返回：** `MetadataUpdateEntry`。
- **备注：** 这些显式清除标志之所以存在，是因为传 `null` 意味着「保持不变」。一条被处理完的建议必须主动
  丢弃它的候选，一次成功的尝试必须主动丢弃它的退避截止时间；两者都无法通过传 `null` 表达。

### `static MetadataUpdateEntry? fromJson(Map<String, dynamic>)` <a id="entryfromjson"></a>
- **种类：** `MetadataUpdateEntry` 的静态方法
- **用途：** 解析单条条目。
- **返回：** `MetadataUpdateEntry?` —— 没有可用 `animeId` 时返回 `null`，因为无法关联到番剧的条目毫无用处。
- **备注：** 遵循 `AnimeLocalArchive.fromJson` 的模式：解析失败的值原样保留在 `extraJson` 中而不是丢弃，
  因此由更新版本写入的数据能在旧版本重写该文件后存活。无法识别的 `status` 会得到 `upToDate`，**同时**
  把原始值收进 `extraJson`。

### `MetadataUpdateStore prunedTo(Set<String>)` <a id="prunedto"></a>
- **种类：** `MetadataUpdateStore` 的方法
- **用途：** 清理番剧已不存在的条目。
- **输入：** `liveIds` —— `anime_data.json` 中当前的全部 id。
- **备注：** 没有这一步，缓存会随着番剧被删除而无限增长。服务把它与 `MetadataCache.pruneCovers` 配对，
  以便孤立的预取封面也一并清除。

### `factory MetadataUpdateStore.fromJson(Map<String, dynamic>)` <a id="storefromjson"></a>
- **种类：** 工厂构造器
- **用途：** 解析整个文档。
- **备注：** 格式错误的条目**逐条**跳过，而不是让整个文件解析失败。这是一份可重建的缓存，因此部分恢复
  优于丢弃全部、再通过网络重新抓取整个资料库。

### `bool hasEpisodeCountMismatch(Anime, AnimeSearchResult)` <a id="hasepisodecountmismatch"></a>
- **种类：** 顶层函数
- **用途：** 报告某部番剧的集数是否与来源真正不一致。
- **返回：** `bool`。
- **算法：**
  1. 来源未报告正的集数时返回 false。
  2. **`startEpisode != 1` 时返回 false。**
  3. `totalEpisodes` 为 null（开放式）时返回 false。
  4. 否则比较 `totalEpisodes` 与来源的集数。
- **备注：** 第 2 步是关键。把 24 集番的后半季记成 `startEpisode: 13, endEpisode: 24` 会得到
  `totalEpisodes == 12`，而来源报 24 —— 而这正是*正确*的记录方式。少了这条守卫，本功能会专挑用户最用心
  整理的那些记录刷假警报。第 3 步把开放式记录导向「字段缺失」路径，那条路径会提议一个值，而不是报告冲突。

### `bool needsMetadataDiscovery(Anime)` <a id="needsmetadatadiscovery"></a>
- **种类：** 顶层函数
- **用途：** 报告某条记录是否残缺到值得进行一次完整的多源搜索。
- **备注：** 既没有 `infoUrl` 也没有任何 `externalMeta` 的记录总是符合条件，因为根本没有可供*刷新*的来源。
  否则，缺少首播日期、放送星期、结束集数或封面时符合条件。

### `List<MetadataFieldChange> diffCandidate(Anime, AnimeSearchResult)` <a id="diffcandidate"></a>
- **种类：** 顶层函数
- **用途：** 算出某个候选会改动哪些核心字段。
- **返回：** `List<MetadataFieldChange>` —— 无改动时为空。
- **备注：** **绝不建议覆盖非空的用户值**，只有一个刻意的例外：当 `hasEpisodeCountMismatch` 判定集数确实
  不一致时的 `endEpisode`。这条规则正是批量「全部更新」得以成立的依据 —— 它只能填空白、以及纠正可证实的
  不一致。

  它按需重算而非持久化，因此始终反映记录的当前状态。一条其改动已被用户手动做完的建议会产出空差异，
  从而直接从审阅列表中消失。

### `Anime applyMetadataChanges(Anime, {...})` <a id="applymetadatachanges"></a>
- **种类：** 顶层函数
- **用途：** 把已接受的字段写入番剧记录。
- **输入：** `changes`、`selected` —— 用户接受的字段；`coverImagePath` —— 封面被接受时已下载完成的相对路径。
- **返回：** `Anime`。
- **备注：** 返回前会还原原始的 `modifiedAt`，因此由**调用方**决定这是否算作一次用户编辑。这个还原是必需
  的，不是装饰性的：`Anime.copyWith` 在省略该参数时会把 `modifiedAt` 填成当前时间，因此循环中每一次
  `copyWith` 都会更新它。这个区别为何要紧，见 [`../../../../sync.md`](../../../../sync.md)。

  封面字段较为特殊：它的提议值是一个远程 URL，因此调用方先下载，再把得到的 `images/...` 路径传回来。

### `double? MetadataScanProgress.fraction` <a id="scanfraction"></a>
- **种类：** getter
- **用途：** 报告用户触发的检索进行到哪一步。
- **输入：** 无。
- **返回：** 0..1 之间的 `double?`；`total` 为零时返回 `null`。
- **副作用：** 无。
- **注意：** 刻意与 `myapps_data` 中的 `SyncProgress.fraction` 保持同构，因此两处进度 UI 的绑定方式完全一致，
  而 `null` 的含义是「不要画确定进度条」，而不是「画一个空的」。

  `total` 为零是一个真实结论，而非失败：所有能检查的记录最近都检查过，再问一遍不会有任何变化。
  审阅页会把它呈现为「所有资料都已是最新」，而不是一根永远不动的进度条。

  分母在检索开始时就已固定——队列是一份快照——所以进度条只会前进。
