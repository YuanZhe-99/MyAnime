# lib/shared/services/webdav_service.dart

**共享引擎上的门面。** WebDAV 传输、上传锁生命周期、合并流水线、`.sync_base` 快照和引用图像同步移入 `myapps_data` 包（`lib/src/webdav/sync_engine.dart` 及同族）。本文件保留它拥有的每个公共名称和签名，使调用点、冲突对话框和既有测试不变。

应用的数据文件在 [`../../app/data_modules.md`](../../app/data_modules.md) 中描述一次；硬编码 `_dataFileNames` 列表已消失。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`SyncResult`](#syncresult) | 类 | A | 成功标志、错误文本、待定冲突、非致命警告。 |
| [`PendingSync`](#pendingsync) | 类 | A | 未解决冲突加最终化所需的引擎状态。 |
| [`WebDAVService.progress`](#progress) | 静态 getter | A | 进度条的实时 `ValueNotifier<SyncProgress>`。 |
| [`consumeLocalDataChanged()`](#consumelocaldatachanged) | 静态方法 | A | 读取并清除"同步写了本地数据"信号。 |
| [`loadConfig()`](#loadconfig) | 静态方法 | A | 读取 `webdav_config.json`。 |
| [`saveConfig(config)`](#saveconfig) | 静态方法 | A | 原子写入 `webdav_config.json`。 |
| [`deleteConfig()`](#deleteconfig) | 静态方法 | A | 移除 `webdav_config.json`。 |
| [`testConnection(config)`](#testconnection) | 静态方法 | A | 一次 PROPFIND；207 或 404 表示可达。 |
| [`sync(config, {autoResolve})`](#sync) | 静态方法 | A | 在远程 `.lock` 下完整双向同步。 |
| [`finalizePendingSync(...)`](#finalizependingsync) | 静态方法 | A | 上传用户的冲突解决方案。 |
| [`forceUpload(config)`](#forceupload) | 静态方法 | A | 用本地覆盖远程，不合并。 |
| [`forceDownload(config)`](#forcedownload) | 静态方法 | A | 用远程覆盖本地，不合并。 |

从包中以原名再导出，使每个调用点看到相同类型：`WebDAVConfig`、`WebDAVUploadLock`、`RemoteFile`、`RemoteFileStatus`。

## 文档

### `class SyncResult` <a id="syncresult"></a>
- **用途：** 同步、强制上传或强制下载的结果。
- **字段：** `success`、`error`、`pending`（`PendingSync?`）、`warnings`（非致命，如单个图像传输失败）。
- **getter：** `hasConflicts` — `pending != null` 时为 true。
- **备注：** 形态与抽取前不变。由私有适配器从引擎的 `EngineSyncResult` 构建。

### `class PendingSync` <a id="pendingsync"></a>
- **用途：** 把未解决冲突带给对话框并带回来。
- **字段：** `animeMerge`（`AnimeMergeResult?`，应用类型化的合并状态）和 `enginePending`（`finalizePendingSync` 使用的不透明引擎状态）。
- **getter：** `allConflicts` — 供对话框的 `List<RecordConflict<Anime>>`。
- **备注：** 引擎绝不检查应用的合并结果；它作为不透明 `state` 携带，这正是对话框仍能收到真实 `Anime` 记录的原因。

### `progress` <a id="progress"></a>
- **种类：** 静态 getter → `ValueNotifier<SyncProgress>`
- **用途：** 引擎的实时进度通知器，为设置页暴露。

### `consumeLocalDataChanged()` <a id="consumelocaldatachanged"></a>
- **返回：** `bool` — 自上次调用以来同步是否写了本地数据或下载了图像。
- **副作用：** 重置该标志。

### `loadConfig()` <a id="loadconfig"></a>
- **返回：** `Future<WebDAVConfig?>`；缺失、格式错误或不可读时为 null。
- **备注：** 缺失或 null 的 `remotePath` 仍默认为 `/MyAnime`。显式空字符串保持为空——它可以指 WebDAV 账户根。

### `saveConfig(config)` <a id="saveconfig"></a>
- **副作用：** 对 `webdav_config.json` 原子 tmp-重命名写入，紧凑 JSON。
- **备注：** 凭据保持明文；不变且超出范围。

### `deleteConfig()` <a id="deleteconfig"></a>
- **副作用：** 存在时删除配置。基线快照和客户端 ID 保持不动。

### `testConnection(config)` <a id="testconnection"></a>
- **返回：** `Future<bool>` — HTTP 207 或 404 为 true。
- **备注：** 404 算作可达，因为集合可能尚不存在。

### `sync(config, {autoResolve = false})` <a id="sync"></a>
- **返回：** `Future<SyncResult>`。
- **副作用：** 获取远程 `.lock`、下载、合并、上传、保存基线快照、同步引用图像、更新 `progress`。
- **备注：** `autoResolve` 在每个生产调用点都是 false——冲突绝不静默自动解决。

### `finalizePendingSync(config, pending, resolutions)` <a id="finalizependingsync"></a>
- **输入：** `resolutions` 把动画 ID 映射到选中的 `Anime`。
- **返回：** `Future<bool>` — 应用或上传失败时为 false。
- **副作用：** 重新获取锁、**重新下载远程数据文件**、写本地、上传、保存基线。
- **备注：** 重新下载在抽取期间从 MyDay/MyDevice 采纳。它不重新合并已知字段；它防止把解决方案上传覆盖一个已变得不可读的远程。基线只在成功上传后保存。

### `forceUpload(config)` <a id="forceupload"></a>
- **副作用：** 覆盖远程数据并在 `.lock` 下上传缺失的引用图像。
- **备注：** 上次同步以来的远程变更丢失。

### `forceDownload(config)` <a id="forcedownload"></a>
- **副作用：** 替换本地数据文件和基线快照；下载缺失图像。不加锁。
- **备注：** 上次同步以来的本地变更丢失。远程负载只做语法校验。

## 引擎文档的位置

`packages/myapps_data/doc/en-us/functions/src/webdav/` — `sync_engine.md`、`webdav_client.md`、`webdav_config.md`、`upload_lock.md`。
