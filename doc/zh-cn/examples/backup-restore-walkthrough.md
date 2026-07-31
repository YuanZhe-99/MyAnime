# 实例演练：备份、损坏和恢复

本页用 [`../backup-restore.md`](../backup-restore.md) 描述的机制走查一个具体场景：创建备份、一个损坏捆绑，以及在 WebDAV 自动同步启用时恢复一个更早的备份。

## 1. 创建备份

用户启用了 7 天保留的自动备份。一周内，应用写入：

```text
backups/backup_2026-07-16.json
backups/backup_2026-07-17.json
backups/backup_2026-07-18.json
backups/backup_2026-07-19.json
backups/backup_2026-07-20.json
backups/backup_2026-07-21.json
backups/backup_2026-07-22.json
backups/blobs/
  3f2a9c...e1.jpg   <- shared by several backups' cover images
  7b8d10...c4.png
```

每个 `backup_*.json` 捆绑大致为：

```json
{
  "anime_data.json": "{\"animes\": [ ... ]}",
  "_imageRefs": {
    "images/cover_a1b2c3.jpg": "3f2a9c...e1.jpg"
  }
}
```

因为 `a1b2c3` 的封面图一周没变，每个捆绑的 `_imageRefs` 都指向*同一个* blob 文件 `3f2a9c...e1.jpg`——按 [`../backup-restore.md`](../backup-restore.md) 的内容寻址去重规则，图像在磁盘上只存一次，被全部七个备份共享。

## 2. 一个损坏捆绑

假设 `backup_2026-07-21.json` 在写入中途因磁盘写满被截断。首先有两件事防止这种情况真的发生（捆绑写入是原子的、tmp-重命名），但假设它还是通过其他损坏路径发生了（如坏扇区，或文件被手动编辑弄坏）：

- 备份历史 UI 把 `backup_2026-07-21.json` 标记为 **`corrupt`**——它的 JSON 无法解析。
- 该条目**禁用恢复**。
- 关键的是，`runAutoBackupIfNeeded()` **不**把损坏的 `2026-07-21` 捆绑计入"今天已备份"（`if (b.corrupt) return false;`）。因此下一次自动备份触发（应用启动、恢复或 15 分钟计时器）会为那天重试备份，而不是跳过它——用户最终得到一个新鲜的、有效的等价 `backup_2026-07-21b.json`，而不是卡在一个永久损坏的日子。
- **Blob GC** 在任何一个捆绑不可解析时整体中止——因此即使 `backup_2026-07-21.json` 损坏且无法确认它自己的 `_imageRefs`，GC 趟也不会把那个当作"该捆绑不引用任何东西"，也不会冒险删除损坏文件在最终被修复或移除后仍需要的 blob。

## 3. 在 WebDAV 自动同步启用时恢复一个更早的备份

用户的 WebDAV 自动同步开着。他们决定 `backup_2026-07-18.json` 里有他们想要回来的数据（回滚一周的意外删除）。

流程（`backup_page.dart._restoreBackup`，来自 [`../backup-restore.md`](../backup-restore.md)）：

1. 用户选择 `backup_2026-07-18.json` 并勾选要恢复的模块，确认恢复对话框。
2. **在写入任何文件之前**，应用加载当前 WebDAV 配置，看到 `config.autoSync == true`，立即把 `config.copyWith(autoSync: false)` 保存到 `webdav_config.json`。这一步没有 `mounted` 门——即使页面片刻之后被销毁，自动同步也已经关闭。
3. `BackupService.restoreBackup(file, moduleKeys: selected)` 运行：
   - 先用 `AnimeData.fromJson` 校验每个被选模块的 JSON——如果 `backup_2026-07-18.json` 的 `anime_data.json` 负载本身不可解析，就什么都不写，`wroteAnything` 保持 `false`。
   - 它解析正常，因此原子写入恢复出的 `anime_data.json`，然后从 blob `3f2a9c...e1.jpg` 恢复 `images/cover_a1b2c3.jpg`（仍在——因为更新的备份一直引用它，它从未被 GC）。
   - 返回 `RestoreResult(ok: true, wroteAnything: true, missingImages: 0)`。
4. 由于 `result.ok` 为 true，失败/重新启用分支被完全跳过——自动同步保持**关闭**（这是刻意的：成功恢复只是用一周前的快照替换了本地数据；现在让后台同步把那个快照与*当前*远程状态合并，会把"缺失"的一周变更当作删除，并可能向外传播）。
5. 打开的页面重载（`AutoSyncService.notifyLocalDataChangedNow()`），提醒刷新（`ReminderService.notifyDataChanged()`）。
6. `missingImages == 0`，所以不显示警告。
7. 因为 WebDAV **确实**已配置，`_handlePostRestoreSync(config)` 运行：它显示一个对话框，说明同步现已禁用，并询问是否强制上传恢复出的（更旧的）数据。
   - 如果用户选择**强制上传**：持有 `SyncWakeLock.acquire()`（见 [`../sync.md`](../sync.md)），然后 `WebDAVService.forceUpload(config)` 在 `.lock` 之下、不做合并步骤地把恢复出的旧数据覆盖远程 `anime_data.json` 和被引用图像——这是让恢复出的状态在处处成为新事实来源的显式、经用户确认的方式。无论结果如何，唤醒锁都在 `finally` 中释放。
   - 如果用户选择**跳过**：远程保持原样，自动同步**保持禁用**，直到用户在 WebDAV 设置中手动重新启用——这是刻意的，让应用不会在之后静默地把过期的本地快照与实时远程合并。

### 对照：如果恢复本身失败了呢？

如果第 3 步改为在写入任何内容之前失败（如捆绑内被选的 `anime_data.json` 负载校验不过），`RestoreResult` 会以 `RestoreResult(ok: false, wroteAnything: false, missingImages: 0)` 返回。因为 `wroteAnything` 是 `false`——本地数据可证明未被触碰——调用方立即重新启用自动同步（`config.copyWith(autoSync: true)`），因为没有恢复出任何可能与恢复的同步冲突的东西。这正是 [`../backup-restore.md`](../backup-restore.md) 描述的安全规则：自动同步只在恢复失败*且*未写入任何内容时才会被自动重新启用。
