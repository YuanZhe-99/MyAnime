# lib/features/anime/services/metadata_update_service.dart

`MetadataUpdateService` 是在应用打开期间保持番剧元数据最新的单例。它运行两条队列 —— 对已经知道来源的
记录静默**刷新**缓存的 `externalMeta`，以及对资料不全的记录进行**探索**搜索，后者产出建议而不是直接写入。

行为、调参理由与置信度规则见
[`../../../../features/metadata-auto-update.md`](../../../../features/metadata-auto-update.md)。本页
覆盖各项声明。

## 一切依赖的那条规则

后台写入走 `AnimeStorage.patchExternalMeta`，它**不碰 `modifiedAt`**。`mergeRecords` 判断「是否变化」
只看 `modifiedAt` 与同步基线的先后，因此在这里更新它会让在另一台设备上删除的记录复活，并为用户从未做过
的编辑引发冲突。见 [`../../../../sync.md`](../../../../sync.md)。

应用一条**建议**则是相反的情况，它确实会更新它 —— 那是用户的编辑。

## 调参常量

| 常量 | 取值 | 原因 |
|---|---|---|
| `_refreshGap` | 5 秒 | 一次刷新最多 3 个并发请求；Jikan 允许每秒 3 次、每分钟 60 次。 |
| `_discoverGap` | 15 秒 | 一次 `searchAll` 是五个来源、最多两轮。 |
| `_idleGap` | 3 分钟 | 空闲或被门禁挡住时的轮询间隔。 |
| `_airingFreshness` | 24 小时 | 放送中作品的评分与集数仍在变动。 |
| `_finishedFreshness` | 14 天 | 已完结作品的不再变动。 |
| `_rediscoverAfter` | 30 天 | 重新搜索一条未找到可用匹配的记录之前的间隔。 |
| `_backoff` | 1 时 / 6 时 / 1 天 / 7 天 | 连续失败，在最后一档封顶。 |
| `_minConfidence` | 0.75 | 提议一个候选所需的最低相关度。 |
| `_confidenceMargin` | 0.08 | 冠军需要领先**其他作品**多少。 |
| `_flushEvery` | 10 | 两次写入 `anime_data.json` 之间处理的番剧数。 |
| `_manualRefreshGap` | 2 秒 | 手动检索；一次刷新对单一站点最多 1 次请求，即 ≤30 次/分钟/站。 |
| `_manualDiscoverGap` | 6 秒 | 手动检索；一次 `searchAll` 对单一站点最多 2 次请求，即 ≤20 次/分钟/站。 |

## 声明

| 声明 | 种类 | 层级 | 用途 |
|---|---|---|---|
| `MetadataUpdateService._` | 构造器 | B | 阻止实例化。 |
| [`pendingCount`](#pendingcount) | getter | A | 有多少记录在等待用户决定。 |
| `store` | getter | B | 缓存的只读快照。 |
| `addListener` / `removeListener` | 方法 | B | 订阅待确认集合的变化。 |
| `_notify` | 方法 | B | 在防御性副本上触发监听器。 |
| [`start`](#start) | 方法 | A | 启动后台循环。 |
| [`stop`](#stop) | 方法 | A | 停止循环并落盘缓冲的元数据。 |
| [`_schedule`](#_schedule) | 方法 | A | 安排下一次 tick。 |
| `_ensureStoreLoaded` | 方法 | B | 每个会话加载一次缓存。 |
| [`_networkGate`](#_networkgate) | 方法 | A | 判断当前链路是否符合策略。 |
| [`effectivePolicy`](#effectivepolicy) | 静态方法 | A | 读取策略，带平台默认值。 |
| [`refreshableUrls`](#refreshableurls) | 静态方法 | A | 列出一条记录可刷新的来源页面。 |
| [`_tick`](#_tick) | 方法 | A | 执行一个工作单元；总是重新排程。 |
| [`_runOnce`](#_runonce) | 方法 | A | 门禁、清理，并执行一个队列项。 |
| [`selectRefreshTarget`](#selectrefreshtarget) | 方法 | A | 刷新队列排序的测试接缝。 |
| `selectDiscoveryTarget` | 方法 | B | 探索队列选择的测试接缝。 |
| [`backoffFor`](#backofffor) | 静态方法 | A | 给定失败次数对应的退避时长。 |
| [`_nextRefreshTarget`](#_nextrefreshtarget) | 方法 | A | 挑选下一条要刷新的记录。 |
| [`_nextDiscoveryTarget`](#_nextdiscoverytarget) | 方法 | A | 挑选下一条要搜索的记录。 |
| [`_refreshOne`](#_refreshone) | 方法 | A | 刷新一条记录的缓存元数据。 |
| [`_discoverOne`](#_discoverone) | 方法 | A | 为一条记录搜索匹配。 |
| [`_isUnambiguous`](#_isunambiguous) | 方法 | A | 冠军是否明确胜过每个对手**作品**。 |
| `_bestOf` | 方法 | B | 在刷新结果中挑出与记录最匹配的一个。 |
| [`_recordFailure`](#_recordfailure) | 方法 | A | 推进退避阶梯。 |
| [`_flushPendingMeta`](#_flushpendingmeta) | 方法 | A | 把缓冲的元数据写入磁盘。 |
| `reload` | 方法 | B | 外部变更后重读缓存。 |
| [`applyProposal`](#applyproposal) | 方法 | A | 应用一条已接受的建议。 |
| `_resolveCoverPath` | 方法 | B | 把已接受的封面转换为 `images/` 路径。 |
| [`_promotePrefetchedCover`](#_promoteprefetchedcover) | 方法 | A | 把预取封面复制进 `images/`。 |
| [`dismissProposal`](#dismissproposal) | 方法 | A | 拒绝一条建议。 |
| `isScanning` | getter | B | 是否有手动检索正在运行。 |
| [`buildScanQueue`](#buildscanqueue) | 方法 | A | 为手动检索构造固定的工作清单。 |
| [`startManualScan`](#startmanualscan) | 方法 | A | 立即执行一次用户触发的全库检查。 |
| [`cancelManualScan`](#cancelmanualscan) | 方法 | A | 请求正在运行的检索停止。 |
| `clearScanProgress` | 方法 | B | 把进度通知器恢复到静止状态。 |
| [`_links`](#_links) | 方法 | A | 读取当前链路类型，不可用时返回 `null`。 |
| `_hasNoLink` | 静态方法 | B | 判断链路列表是否意味着「没有连接」。 |
| [`_isOffline`](#_isoffline) | 方法 | A | 是否完全没有连接。 |
| [`isMetaStale`](#ismetastale) | 静态方法 | A | 缓存的资料是否已过新鲜期。 |

## 文档

### `int get pendingCount` <a id="pendingcount"></a>
- **用途：** 统计等待用户决定的记录数。
- **备注：** 驱动管理页角标，为零时角标完全隐藏，因此这个操作绝不会在背后没有内容时出现。

### `Future<void> start()` <a id="start"></a>
- **副作用：** 加载本地缓存、通知监听器、在 20 秒后安排第一次 tick。
- **备注：** 幂等。**不**检查 flavor —— 由调用方门禁 `AppFlavor.isFull`，与 `AnimeSearchService` 遵循
  同一约定。20 秒延迟让这个循环避开应用启动阶段。

### `Future<void> stop()` <a id="stop"></a>
- **副作用：** 取消定时器并落盘缓冲的元数据。
- **备注：** 停止时落盘很重要：缓冲的 `externalMeta` 已经用网络请求换来了，丢弃它意味着要再抓一次。

### `void _schedule(Duration)` <a id="_schedule"></a>
- **备注：** 循环用每次 tick 各自决定的延迟自我重排，而不是按固定周期运行，因此空闲轮询保持廉价、而
  活跃工作被限速。服务已停止时直接返回，不再排程。

### `Future<_NetworkGate> _networkGate(MetadataUpdatePolicy)` <a id="_networkgate"></a>
- **返回：** `allowed`、`blocked` 或 `offline`。
- **副作用：** 查询 `connectivity_plus`。
- **备注：** 这个三态结果之所以存在，是为了让**离线可以与被策略挡住区分开**，这正是在根本没有网络时
  阻止 `_recordFailure` 触发的关键 —— 否则一趟地铁就能把整个资料库推进七天退避。

  在 `noCellular` 下，Wi-Fi、有线与 VPN 链路放行。这是链路类型启发式，不是计费与否的保证 —— 手机热点
  同样报告 Wi-Fi。插件失败按 `allowed` 处理，而不是在一个无法回答的平台上把功能整个封死。见
  [`../../../../platform-notes.md`](../../../../platform-notes.md)。

### `static Future<MetadataUpdatePolicy> effectivePolicy()` <a id="effectivepolicy"></a>
- **备注：** 缺省配置在 Android 与 iOS 上表示 `noCellular`，使手机绝不会在未经询问时消耗蜂窝数据；
  桌面上表示 `always`。

### `static List<String> refreshableUrls(Anime)` <a id="refreshableurls"></a>
- **用途：** 把 `infoUrl` 与每条已存外部评分记住的 URL 合并起来。
- **备注：** 与详情页的手动刷新 chip 共用，因此两者对「可刷新」的定义一致。由多个来源构建的记录会刷新
  全部来源。

### `Future<void> _tick()` <a id="_tick"></a>
- **备注：** 每一条退出路径都会重新排程，包括失败路径，因此一个意外异常不会静默地把循环在本次会话余下
  时间里彻底杀死。`_busy` 标志防止重入。

### `Future<Duration> _runOnce()` <a id="_runonce"></a>
- **返回：** 下一次 tick 之前应等待多久。
- **算法：**
  1. 应用不处于 `resumed` 时，落盘并转入空闲。
  2. 策略或当前链路不允许工作时，落盘并转入空闲。
  3. 加载缓存与番剧列表；清理已删除番剧的条目。
  4. 有到期的刷新则刷新一条，否则探索一条，否则落盘并转入空闲。
- **备注：** 刷新排在探索之前是刻意的：它便宜得多，而且它在不询问用户任何事情的前提下静默改善数据。

  **已知且可接受的竞态：** 同步引擎直接写模块文件而不经过 `AnimeStorage`，因此后台写入与同步写入原则上
  可能互相覆盖。tmp-重命名保证文件绝不会损坏；最坏结果是丢失一次缓存更新，下一轮扫描会重做。服务同时
  会在写入前立即重读。

### `Anime? selectRefreshTarget(List<Anime>, DateTime, {MetadataUpdateStore})` <a id="selectrefreshtarget"></a>
- **种类：** `@visibleForTesting` 方法
- **备注：** 选择规则才是值得锁定的部分；围绕它的网络路径无法做单元测试，因为 `AnimeSearchService` 的
  HTTP 调用是静态的、无法注入 client。`store` 用于预置退避与忽略状态。

### `static Duration backoffFor(int)` <a id="backofffor"></a>
- **种类：** `@visibleForTesting` 静态方法
- **备注：** 在最后一档封顶，而不是无限增长。

### `Anime? _nextRefreshTarget(List<Anime>, DateTime)` <a id="_nextrefreshtarget"></a>
- **备注：** 有来源 URL 但完全没有缓存元数据的记录直接胜出 ——「优先更新没有的」—— 其余按 `refreshedAt`
  从旧到新。放送中新鲜期 24 小时，已完结 14 天。处于退避窗口内的条目会被跳过。

### `Anime? _nextDiscoveryTarget(List<Anime>, DateTime)` <a id="_nextdiscoverytarget"></a>
- **备注：** 跳过用户已忽略的记录、已在等待决定的记录、处于退避窗口内的记录、最近 30 天内已搜索过的
  记录，以及没有标题可供搜索的记录。

### `Future<void> _refreshOne(Anime, DateTime)` <a id="_refreshone"></a>
- **副作用：** HTTP 请求；缓冲合并后的元数据；写入本地缓存。
- **备注：** 先缓冲而非立即写入 —— 见 [`_flushPendingMeta`](#_flushpendingmeta)。当刷新发现某个**核心**
  字段发生了变化时，它不会写入；该差异会变成一条建议，进入探索所用的同一条队列。

### `Future<void> _discoverOne(Anime, DateTime)` <a id="_discoverone"></a>
- **副作用：** 一次完整的多源搜索，可能还有一次封面预取，以及一次缓存写入。
- **备注：** 只有明确最佳的匹配才会成为 `proposed` 条目；任何模棱两可的都归档为 `needsManualPick` 并被
  排除在所有批量操作之外。一个可信匹配若其差异为空，会记为 `upToDate`，而不是显示成一条空建议。

### `bool _isUnambiguous(List<({AnimeSearchResult result, double score})>)` <a id="_isunambiguous"></a>
- **备注：** 同一部番剧本来就会每个来源各出现一次 —— `searchAll` 刻意不跨源合并。因此只有当亚军与冠军
  **不共享任何标题**时，接近的分数才算作竞争；那是另一部作品在竞争，而不是同一部被看到了两次。没有这个
  区分，边际检查会拒绝掉几乎每一个正确匹配。

### `Future<void> _recordFailure(String, DateTime)` <a id="_recordfailure"></a>
- **备注：** 只有在网络可用而请求仍然失败时才会走到这里。离线的 tick 在尝试任何工作之前就返回了，因此
  离线绝不会推进退避阶梯。

### `Future<void> _flushPendingMeta()` <a id="_flushpendingmeta"></a>
- **副作用：** 缓冲非空时重写 `anime_data.json`。
- **备注：** 每 10 部批量落盘。每部都写会导致每几秒重写一遍整个文件，并不断重置自动同步的 30 秒保存
  防抖，从而让一次长时间扫描把同步无限期推后。

### `Future<bool> applyProposal(Anime, Set<MetadataField>)` <a id="applyproposal"></a>
- **输入：** `anime` —— **当前已存储**的记录；`fields` —— 用户接受的字段。
- **副作用：** 封面被接受时下载它、写入记录、清除缓存条目。
- **备注：** 针对传入的记录重新计算差异，而不是信任建议生成时存下的那份，因此建议生成后被编辑过的番剧
  绝不会被陈旧的值覆盖。**会更新 `modifiedAt`** —— 这是用户自己的编辑，必须在合并中获胜。

### `Future<String?> _promotePrefetchedCover(String)` <a id="_promoteprefetchedcover"></a>
- **备注：** 预取目录不同步，因此被接受的封面必须复制进同步的 `images/`，才能到达用户的其他设备。

### `Future<void> dismissProposal(String)` <a id="dismissproposal"></a>
- **备注：** 持久化这次拒绝，并删除预取的封面。该记录只有在用户编辑它、或 30 天重新探索窗口到期后才会
  被重新审视。

### `({List<Anime> refresh, List<Anime> discover}) buildScanQueue(List<Anime>, MetadataUpdateStore, DateTime)` <a id="buildscanqueue"></a>
- **种类：** 方法（`@visibleForTesting`）
- **用途：** 构造用户触发的检索将要走完的固定工作清单。
- **输入：** `animes`、`store`、`now`。
- **返回：** 一个记录，包含待刷新的番剧与待搜索的番剧。
- **副作用：** 无——它是纯函数，这也正是手动检索中被单元测试覆盖的部分。
- **算法：** 依次遍历每部番剧：若它有可刷新的 URL **且**缓存已过期，则进入 `refresh`，该记录处理完毕。
  否则，若它资料残缺、有标题，且既未被忽略也没有待确认的建议，则进入 `discover`。
- **注意：** 它**无视**什么、**尊重**什么，就是整个设计：

  | 闸门 | 手动检索 | 原因 |
  |---|---|---|
  | 失败退避（`nextAttemptAt`） | 无视 | 「立刻重试」正是这个按钮的含义；退避只是「别太快重试」的启发式。 |
  | 30 天重新探索窗口 | 无视 | 同上。 |
  | 用户的忽略 | 尊重 | 重新提议用户已经拒绝过的内容，会让「忽略」失去意义。 |
  | 缓存新鲜度 | 尊重 | 对 200 条的库重新抓取仍新鲜的资料要花上几分钟、上千次请求，却什么都不会改变。 |

  对同一条记录，刷新优先于探索，与 [`_runOnce`](#_runonce) 排空两条队列的顺序一致。
  因此每部番剧**最多出现一次**，总数就是记录条数，进度条的分母永远不会变动。

### `Future<bool> startManualScan()` <a id="startmanualscan"></a>
- **种类：** 方法
- **用途：** 应用户的明确要求，立即检查整个库。
- **输入：** 无。
- **返回：** `Future<bool>`——设备离线、什么都没执行时为 `false`。
- **副作用：** 取消后台定时器、发起 HTTP 请求、写入 `metadata_updates.json` 与 `anime_data.json`，
  并向 `scanProgress` 发布进度。
- **算法：** 从 [`buildScanQueue`](#buildscanqueue) 取一份快照队列，先处理刷新项、再处理探索项，
  每项前后各发布一次进度，并在两项之间检查取消标志。结束时落盘缓冲的资料并恢复后台循环。
- **注意：** 刻意**不**受 `metadataAutoUpdate` 限制。该设置管的是**无人值守**的后台流量；
  而这是用户可以看着、可以随时停止的一次明确点击，并且当策略为 `off` 时，这个按钮是唯一的检查途径。

  离线时仍然拒绝执行，因为那样每一项都会失败，白白把整个库推进退避。这也正是
  [`_isOffline`](#_isoffline) 要独立于 [`_networkGate`](#_networkgate) 存在的原因——后者一旦策略为
  `off` 就会短路返回 `blocked`，而那恰恰是手动按钮必须能工作的场景。

  执行期间后台定时器会被取消：两个 worker 同时打同一批 API，会让请求速率变成
  `_manualRefreshGap` 与 `_manualDiscoverGap` 所设定值的两倍。

### `void cancelManualScan()` <a id="cancelmanualscan"></a>
- **种类：** 方法
- **用途：** 请求正在运行的检索停止。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 设置在队列项之间被读取的标志。
- **注意：** 已经发出的那次请求会被允许完成，因此不会白白丢弃一个已经付出网络往返代价的响应。
  已找到的结果全部保留——取消的含义是「停在这里」，而不是「撤销」。

### `Future<List<ConnectivityResult>?> _links()` <a id="_links"></a>
- **种类：** 方法
- **用途：** 读取当前的链路类型。
- **输入：** 无。
- **返回：** `Future<List<ConnectivityResult>?>`——插件无法回答时为 `null`。
- **副作用：** 查询 `connectivity_plus`。
- **注意：** 由策略闸门与离线判断共用，使插件只有一条调用路径。

### `Future<bool> _isOffline()` <a id="_isoffline"></a>
- **种类：** 方法
- **用途：** 报告当前是否完全没有连接。
- **输入：** 无。
- **返回：** `Future<bool>`。
- **副作用：** 查询 `connectivity_plus`。
- **注意：** 插件无法回答时按在线处理，让请求本身去失败，而不是在一个无法报告链路状态的平台上
  直接拒绝整个功能。

### `static bool isMetaStale(Anime, DateTime)` <a id="ismetastale"></a>
- **种类：** 静态方法
- **用途：** 报告一部番剧缓存的资料是否已过新鲜期。
- **输入：** `anime`、`now`。
- **返回：** `bool`——从未抓取过时为 `true`。
- **副作用：** 无。
- **注意：** 由 [`_nextRefreshTarget`](#_nextrefreshtarget) 与 [`buildScanQueue`](#buildscanqueue)
  共用，使后台循环与手动检索对「过期」的定义不会各自漂移。已完结作品适用 `_finishedFreshness`
  （14 天），放送中作品适用 `_airingFreshness`（24 小时）——因为完结之后评分与集数就不再变动了。
