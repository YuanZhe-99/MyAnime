# lib/features/anime/views/metadata_updates_page.dart

`MetadataUpdatesPage` 是后台更新器已下载但尚未应用的资料的审阅界面。它从管理页 AppBar 上的角标进入，
该角标只有在存在待确认项时、且只在完整版构建中才出现。

功能说明见
[`../../../../features/metadata-auto-update.md`](../../../../features/metadata-auto-update.md)，其背后的
服务见 [`../services/metadata_update_service.md`](../services/metadata_update_service.md)。

## 设计要点

- **差异在每次加载时重算**，绝不从缓存读取。建议生成后被编辑过的记录会显示准确的前后对照，而用户已经
  手动做完相应改动的记录会直接从列表中消失。
- **每个字段各有勾选框**，因此用户可以接受被纠正的集数、同时拒绝抓取到的简介。
- **「全部更新」会询问两次。** 这里刻意没有复用 `confirmDelete` 的「5 分钟内不再询问」抑制机制 —— 那会
  直接废掉第二道确认。
- **批量操作跳过 `needsManualPick` 条目。** 批量操作绝不能在服务自己都无法分辨的候选之间猜测；被跳过的
  条目数会显示在第一道确认中。

## 声明

| 声明 | 种类 | 层级 | 用途 |
|---|---|---|---|
| `_Proposal` | typedef | B | 单个可审阅项的记录、缓存条目与实时差异。 |
| `MetadataUpdatesPage` | 构造器 | B | 创建页面，接收管理页传入的作用域。 |
| `createState` | 方法 | B | Flutter 生命周期。 |
| `initState` | 方法 | B | 启动首次加载。 |
| `dispose` | 方法 | B | 注销服务回调。 |
| [`_onServiceChanged`](#_onservicechanged) | 方法 | A | 随服务发布建议而重建列表。 |
| [`_startScan`](#_startscan) | 方法 | A | 执行一次全库检查并报告结果。 |
| `_openManualSearch` | 方法 | B | 把未匹配的记录交给编辑页的搜索。 |
| [`_load`](#_load) | 方法 | A | 从存储与缓存重建建议列表。 |
| [`_batchable`](#_batchable) | 方法 | A | 列出批量操作可以应用的建议。 |
| `_apply` | 方法 | B | 应用一条已审阅的建议。 |
| `_dismiss` | 方法 | B | 拒绝一条建议。 |
| [`_applyBatch`](#_applybatch) | 方法 | A | 确认后应用某作用域内的建议。 |
| `_confirm` | 方法 | B | 显示是/否对话框。 |
| `_fieldLabel` | 方法 | B | 本地化可提议字段的名称。 |
| [`_formatValue`](#_formatvalue) | 方法 | A | 为前后对照列渲染一个值。 |
| `_weekdayLabel` | 方法 | B | 本地化星期。 |
| `build` | 方法 | B | 构建界面。 |
| `_buildEmpty` | 方法 | B | 渲染空状态。 |
| [`_buildProposalCard`](#_buildproposalcard) | 方法 | A | 渲染一条建议。 |
| `_buildChangeRow` | 方法 | B | 渲染单个字段的勾选框与取值。 |
| [`_buildThumbnail`](#_buildthumbnail) | 方法 | A | 渲染候选的封面。 |
| `_buildScanBanner` | 方法 | B | 显示正在运行的检索进行到哪一步。 |

## 文档

### `Future<void> _load()` <a id="_load"></a>
- **副作用：** 重新加载更新缓存并读取 `anime_data.json`。
- **算法：**
  1. 重新加载服务的缓存，使一次替换了番剧文件的同步能够被反映出来。
  2. 按 id 索引已存储的番剧。
  3. 对每条待确认条目，针对**已存储**的记录重新计算 `diffCandidate`。
  4. 丢弃差异现已为空的条目，`needsManualPick` 除外。
  5. 按显示标题排序，并默认全选所有字段。
- **备注：** 第 3 步是这个界面不可能显示陈旧值的原因，第 4 步是用户已手动满足的建议会自行消失的原因。

### `List<_Proposal> _batchable(List<String>)` <a id="_batchable"></a>
- **输入：** `scopeIds` —— 限制在这些番剧内，为空则表示整个资料库。
- **备注：** 只包含差异非空的 `proposed` 条目。`needsManualPick` 在构造上就被排除，这正是「全部更新」
  得以成立的性质。

### `Future<void> _applyBatch(List<String>, {required bool requireSecondConfirm})` <a id="_applybatch"></a>
- **副作用：** 显示一到两个确认对话框，然后写入每条已接受的记录。
- **备注：**「更新本页」确认一次；「全部更新」传入 `requireSecondConfirm: true`，因为一次误触绝不能改写
  整个资料库。第一个对话框还会报告被排除的 `needsManualPick` 条目数，使用户不会困惑于为何数量少于列表
  长度。

### `String _formatValue(MetadataField, Object?, AppLocalizations)` <a id="_formatvalue"></a>
- **备注：** 日期使用 `DateFormat.yMd()`，星期使用与设置页相同的名称，抓取到的简介截断到 120 字符，
  以免单个长值主导整张卡片。null 与空白渲染为本地化的「（空）」而不是什么都不显示，这样「填空白」类的
  建议读起来才像一次改动。

### `Widget _buildProposalCard(_Proposal, ThemeData, AppLocalizations)` <a id="_buildproposalcard"></a>
- **备注：** `needsManualPick` 条目渲染一段说明而不是字段列表，且只提供「忽略」—— 没有东西可应用，因为
  服务无法判定哪个候选是对的。

### `Widget _buildThumbnail(_Proposal)` <a id="_buildthumbnail"></a>
- **副作用：** 可能发起一次网络图片请求。
- **备注：** 开启封面预下载时使用预取的文件，否则直接从来源 URL 加载。正是这条回退路径，使得预下载可以
  **默认关闭**而不给这个界面带来任何损失。

### `void _onServiceChanged()` <a id="_onservicechanged"></a>
- **种类：** 方法
- **用途：** 当服务发布新的建议时重建列表。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 重新读取 `anime_data.json`。
- **注意：** 调用的是 `_load(reloadCache: false)` 而非普通的 `_load()`。
  `MetadataUpdateService.reload()` 会通知它的监听者，因此在监听器内部再要求它从磁盘重读缓存，
  会再次触发这个回调，如此往复、永不停止。此处内存中的存储本来就是最新的——服务刚刚写过它。

  在手动检索期间，正是这一点让建议随着被发现而逐条出现，而不是等检索结束后一次性涌出。

### `Future<void> _startScan()` <a id="_startscan"></a>
- **种类：** 方法
- **用途：** 应用户要求检查整个库，并报告结果。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 驱动 `MetadataUpdateService.startManualScan`，随后显示 snack bar。
- **算法：** 等待检索完成，再依据最终进度快照在几种消息中择一：离线（什么都没执行）、
  队列为空（已是最新）、提前停止、或完成并带上数量。
- **注意：** 被等待的 future 覆盖**整个**检索过程，可能长达数分钟。离开页面只意味着跳过 snack bar
  ——检索本身活在服务里，会继续跑完。

  队列为空时报告的是「所有资料都已是最新」而不是「未发现可用更新」：这是两个不同的结论，
  而当「没有检查任何东西」的原因是「没有东西需要检查」时，只有前者是真的。
