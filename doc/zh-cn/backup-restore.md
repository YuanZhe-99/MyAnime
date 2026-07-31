# 备份、恢复、导出和导入

备份逻辑位于 `lib/shared/services/backup_service.dart`；安全关键的恢复/自动同步交互由调用方在 `lib/features/settings/views/backup_page.dart` 中编排。ZIP 和 Markdown 导出/导入位于 `lib/shared/services/import_export_service.dart`。备份在持久化数据清单中的位置见 [`data-formats.md`](data-formats.md)，包含 WebDAV 交互的具体实例演练见 [`examples/backup-restore-walkthrough.md`](examples/backup-restore-walkthrough.md)。

## 备份格式 v2

每个 `backups/backup_*.json` 捆绑存储数据模块 JSON 字符串，外加一个 `_imageRefs` 映射，指向 `backups/blobs/<sha256><ext>` 下的内容寻址图像 blob。

- **去重：** 相同图像只存储一次（按内容哈希），并被每个引用它的备份共享。
- **引用计数 GC：** 一个 blob 只在没有剩余备份引用它时才会被物理删除。GC 在创建/删除/保留清理之后运行，遇到任何剩余捆绑不可解析时整体中止（使损坏捆绑不可能造成错误的"未引用"删除），并且绝不删除比 **10 分钟宽限窗口**（`backup_service.dart` 中的 `_blobGcGrace = Duration(minutes: 10)`）更年轻的 blob——这保护正在被并发备份写入的 blob，防止它被从脚下回收。
- **保留：** 可按天配置，备份设置 UI 中选项为 `[0, 3, 7, 14, 30, 60, 90]`（`0` = 永久保留）。包括一个专门为想要紧凑本地保留的用户准备的 3 天选项。
- **带内联 base64 `_images` 的旧 v1 捆绑**仍可恢复——恢复先检查 `_imageRefs`（v2），缺失时回退到旧 `_images` 映射（v1）。

## 原子写入

捆绑写入是原子的（tmp-重命名，`_atomicWriteString`/`_atomicWriteBytes`），因此写入中途崩溃不会留下写了一半的捆绑或恢复文件。

## 损坏捆绑处理

- JSON 无法解析的捆绑在备份历史中被标记为 `corrupt`。
- 损坏捆绑**禁用**恢复。
- 损坏捆绑**不计入**"今天已备份"——`runAutoBackupIfNeeded()` 在判断今天的自动备份是否已运行时显式排除 `corrupt` 捆绑（`if (b.corrupt) return false;`），因此被中断/损坏的自动备份尝试会在下一次触发时重试，而不是在当天剩余时间里被静默跳过。
- `runAutoBackupIfNeeded()` 有可重入守卫。
- 自动备份触发：应用启动、应用恢复，以及自动同步 15 分钟周期计时器（最后一条专门覆盖跨过午夜持续运行、没有新的启动/恢复事件的桌面实例）。

## 恢复校验与安全

- `restoreBackup()` 在写入任何内容**之前**通过 `AnimeData.fromJson` 校验每个被选模块的负载——坏负载在任何文件被触碰之前中止。
- 图像名被净化成平铺的 `images/<name>` 形态；路径穿越和绝对路径被拒绝（`_safeImageRelativePath`）。
- 每个文件都原子写入。

### 关键安全规则：恢复前后的 WebDAV 自动同步

当 WebDAV 自动同步启用时，**恢复备份会在第一个文件被写入之前在 `webdav_config.json` 中禁用自动同步**——并且那次禁用没有 `mounted` 门——因此恢复中途崩溃或页面销毁绝不会把恢复出的旧数据留在磁盘上而自动同步仍然开着。（如果真的发生，下一次同步会把恢复出的旧数据当作新的本地编辑/删除，并传播到远程和每台其他设备。）

`BackupService.restoreBackup()` 返回 `RestoreResult`：

```dart
class RestoreResult {
  final bool ok;
  final bool wroteAnything;
  final int missingImages;
}
```

- `ok` — 恢复是否成功完成。
- `wroteAnything` — 是否有任何文件真的被写入。这是承载负载的标志：调用方只在恢复**失败***且* `wroteAnything == false`——即本地数据可证明未被触碰——时重新启用自动同步。如果写入了任何东西而恢复仍在半途失败，自动同步保持关闭，直到用户手动解决，而不是冒险在半恢复状态之上重新启用同步。
- `missingImages` — v2 图像引用中 blob 不在 `backups/blobs/` 下的计数（如没有带 blob 存储一起复制的捆绑）。通过本地化的 `backupRestoreMissingImages` 警告浮出给用户，而不是被静默丢弃。

成功恢复后，调用方（`backup_page.dart`）：

1. 通过 `AutoSyncService.notifyLocalDataChangedNow()` 重载打开的页面。
2. 通过 `ReminderService.notifyDataChanged()` 刷新提醒。
3. 如果有 `missingImages` 则发出警告。
4. 如果 WebDAV 同步**已**配置，询问是否要强制上传恢复出的数据（持有同步唤醒锁——见 [`sync.md`](sync.md)），通过 `WebDAVService.forceUpload()` 执行，并把结果记录到同步状态。跳过这一步会让自动同步保持关闭，直到用户手动重新启用或强制上传；否则让自动同步按原样合并一个旧的恢复快照，会把过期的记录和删除传播到远程和其他设备。

## ZIP 导出/导入

`import_export_service.dart` 导出一个包含 `anime_data.json` 和 `images/` 的 ZIP。

- 导入强制路径穿越保护：只解压**允许列表中的条目**——`anime_data.json` 和 `images/` 下直接平铺的文件——并且解析后的输出路径必须留在应用目录内。这专门防止构造的 ZIP 通过 `../` 路径覆盖 `webdav_config.json` 之类的配置文件。

## Markdown 导出

Markdown 导出对 LLM 友好：条目**按 `firstAirDate` 排序，null 排最后**，每个条目包括标题、类型、播出日程、集数范围、派生的观看状态、已看/总数、URL 和备注。它旨在给 LLM 关于用户观看历史的足够结构化上下文，而不暴露超出导出已包含内容之外的任何东西。
