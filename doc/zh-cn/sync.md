# WebDAV 同步

同步位于 `lib/shared/services/webdav_service.dart`（客户端 id、加锁、上传/下载、重试、心跳、强制操作）和 `lib/shared/services/sync_merge.dart`（泛型逐记录三方合并引擎，详细说明见 [`algorithms/three-way-merge.md`](algorithms/three-way-merge.md)）。同步进度状态位于 `sync_progress.dart`，前台同步操作使用的唤醒锁位于 `sync_wake_lock.dart`。后台触发位于 `auto_sync_service.dart`。同步在磁盘上触碰的文件见 [`data-formats.md`](data-formats.md)，具体实例演练见 [`examples/sync-walkthrough.md`](examples/sync-walkthrough.md)。

WebDAV 同步是**逐记录三方合并，不是整文件替换。**

## 10 步流程

1. **在任何数据下载前获取远程 `.lock`**，使用稳定的本地客户端 id、一个上传令牌、UTC 时间戳和 **60 秒 TTL**。来自另一客户端的活动锁会阻止上传；过期锁被当作失败的上传处理，可以被替换。本地 `.sync_base/upload_lock.json` 文件让*下一次*应用启动能检测到中途被中断的上传，从而在再次上传前重新下载/重新合并，而不是盲目地静默重试。
2. **下载远程 `anime_data.json`**，使用判别式结果：**只有 HTTP 404** 算作"远程缺失"。任何其他失败（认证、服务器错误、网络错误）都会以可见错误中止同步，因此本地数据绝不会被上传覆盖一个客户端只是读取失败了的远程文件。
3. **加载本地 `anime_data.json` 和 `.sync_base/anime_data.json`**（上一次成功同步留下的基线快照）。
4. **使用 `modifiedAt` 逐动画合并**，经由 [`algorithms/three-way-merge.md`](algorithms/three-way-merge.md) 中的泛型引擎。两侧序列化内容相同的记录合并时不会产生冲突，即使两侧各自独立地提升了 `modifiedAt`（这可能在早前一次失败上传留下过期基线后发生）。
5. **只有一侧自基线快照以来变化时自动解决**——取变化侧的版本，无需用户输入。
6. **同一条动画两侧都变化时检测冲突**（即两侧 `modifiedAt` 都比基线新，且序列化内容不同）。
7. **重新读取本地文件**，捕获步骤 1–6 的网络 I/O *期间*发生的并发保存，如果它在这期间变化了就重新合并。
8. **如果没有记录冲突**，在 `.lock` 仍有效时强制上传完整的合并 JSON。数据 JSON 的 PUT **不使用** `If-Match`/`If-None-Match`——`.lock` 是数据上传唯一的并发守卫。
9. **如果有记录冲突**，把它们返回给用户而不是自动解决。用户解决后，`finalizePendingSync` 重新获取 `.lock` 并强制上传完整已解决 JSON。
10. **只在上传成功后保存新的基线快照**，然后清除匹配的远程/本地上传锁。

## 手动与自动同步的冲突处理

手动同步和后台自动同步都以 **`autoResolve: false`** 调用合并引擎。两者都不会对真正的双向冲突静默应用最后写入者胜出。

- **手动同步**（从 WebDAV 设置页触发）直接显示冲突对话框。
- **自动同步**同样保持 `autoResolve` 禁用：它把失败和真正的双向冲突记录为设置/WebDAV 中可见的状态，而不是静默解决。用户必须打开 WebDAV 页面手动解决冲突。
- **关闭任何冲突对话框**（如系统返回）会中止整个解决过程：不上传任何内容、冲突保持待定并可见于同步状态，也没有任何记录被静默解决为本地版本。
- `finalizePendingSync` 在 `.lock` 下应用或强制上传解决方案失败时返回 `false`，使 UI 能报告失败；基线快照保持不变，下一次同步从头重新合并。

## 唤醒锁

WebDAV 页面上的前台同步操作——手动同步、冲突最终化上传、强制上传、强制下载——通过 `shared/services/sync_wake_lock.dart`（基于 `wakelock_plus`）持有屏幕唤醒锁。规则：

- 引用计数（多个并发持有者不会在全部释放前释放锁）。
- 只在没有其他功能已持有时启用。
- 只在强制操作确认之后获取（即用户确认破坏性对话框之后，而不是之前）。
- 在 `finally` 块中于完成、失败、取消或异常时释放。
- **后台自动同步绝不用它**——只有前台、用户发起的操作持有它。

## 重试策略

数据 GET/PUT、字节（图像）GET/PUT 和 PROPFIND 列目录上的瞬态网络失败——socket/超时/客户端错误和 HTTP 5xx——最多重试 **2 次额外尝试**，尝试之间分别有 **1 秒**和 **2 秒**退避（`attemptIndex` 为 1 和 2 时 `Future.delayed(Duration(seconds: attemptIndex))`）。

- `.lock` 写入**绝不重试**，因此重试的 create-only PUT 不可能把锁争用误报成另一个客户端持有锁。
- HTTP 4xx 响应**绝不重试。**

## 心跳

当数据或图像 PUT 在途时，持有的 `.lock` 每 **20 秒**心跳刷新一次（`_withLockHeartbeat`、`_lockHeartbeatInterval`）。这让比 60 秒锁 TTL 更慢的传输绝不会让另一个客户端把锁当作过期并并发上传。心跳失败被吞掉，绝不中止在途传输。

## 图像同步

- 图像**添加式**同步，并且只针对本地或远程动画记录实际**引用**的封面图。
- 引用集是本地与远程动画数据中 `coverImage` 基名的**并集**。
- 孤儿图像（任一侧都不再引用）**不**上传或下载，但也**不会自动删除。**
- 远程图像目录列表在任何失败时返回 `null`；`_syncImages` 随后跳过图像阶段并给出可见警告，而不是把未知的远程状态当作"空"——这以前曾在瞬态 PROPFIND 失败后导致每个被引用图像都被重新上传。
- 下载的图像设置本地数据变更标志，使 UI 页面即使数据 JSON 本身没变也会重载。

## `SyncProgress` 阶段

`WebDAVService.progress` 是一个发布 `connecting` / `downloading` / `merging` / `uploading` 阶段（带逐文件、逐图像计数）的 `ValueNotifier<SyncProgress>`（`sync_progress.dart`）。服务只发出原始阶段和文件名——WebDAV 设置页负责把阶段映射为本地化文本并渲染 `LinearProgressIndicator`。

## 强制操作

- `WebDAVService.forceUpload()` 在远程 `.lock` 之下、**不做任何合并或冲突检查**地覆盖远程数据文件并上传被引用图像，然后保存基线快照。
- `WebDAVService.forceDownload()` 替换本地数据文件（先 JSON 校验、原子写入）并下载被引用图像，不合并，保存基线快照，并设置本地数据变更标志。它只下载、**不取**远程锁。
- 两者共享 `_syncing` 守卫，并需要在 WebDAV 页面确认破坏性操作对话框。
- 备份恢复后提议 `forceUpload()` 的具体场景见 [`examples/backup-restore-walkthrough.md`](examples/backup-restore-walkthrough.md)。

## 自动同步触发

- 应用启动。
- 应用恢复。
- 存储保存后的 **30 秒防抖**。
- 启用/保存自动同步配置后立即同步。
- 应用进程存活期间的 **15 分钟计时器**（同一计时器也运行每日自动备份检查——见 [`backup-restore.md`](backup-restore.md)）。

主页、管理和统计页在 `initState`/`dispose` 中注册 `AutoSyncService.addOnLocalDataChanged` 重载回调，因此后台同步合并、下载的图像和备份恢复能刷新打开的页面，无需重新导航。移动端系统挂起可能把计时器推迟到恢复时。存储层的 `save()` 方法应通知自动同步，使非 UI 写入被覆盖。自动同步在内存中记录最近的成功、失败和待定冲突状态，使设置页和 WebDAV 页面能浮出同步健康度。

手动同步或强制操作后，WebDAV 页面调用 `AutoSyncService.notifyLocalDataChangedIfNeeded()`，使打开的页面无需等待下一个后台同步周期就能重载。

## 其他重要约束

- `anime_data.json` 按 `id` 和 `modifiedAt` 合并 `Anime` 记录。
- 未知的顶层和逐动画 JSON 字段必须在解析、编辑、导入、导出和同步合并中存活（见 [`data-formats.md`](data-formats.md) 中的 `extraJson` 模式）。
- `_syncing` 防止并发同步运行。
- `_atomicWrite()` 使用 tmp-重命名，使写入中途崩溃绝不会损坏本地文件。
- 网络 I/O 后重新读取本地文件，专门用于检测同步期间发生的并发用户编辑（上面第 7 步）。
- 同步错误和图像传输警告显示在对话框中，而不只是 snackbar，因为它们需要保持可见。
