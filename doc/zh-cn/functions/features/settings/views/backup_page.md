# lib/features/settings/views/backup_page.dart

`BackupPage` 是设置 -> 备份子页：它列出 `BackupService`（`lib/shared/services/backup_service.dart`，[`../../../shared/services/backup_service.md`](../../../shared/services/backup_service.md)）产生的本地备份捆绑，让用户按需创建备份、切换每日自动备份、选择保留窗口，以及恢复或删除单个捆绑。与本批大多数视图文件不同，它的几个回调携带真实编排逻辑而不是纯组件组合——最值得注意的是 `_restoreBackup`，它实现安全关键的"在第一个恢复字节被写入前禁用 WebDAV 自动同步"规则，以及 `_handlePostRestoreSync`，它在同步唤醒锁之下提供恢复后强制上传。两者都是 [`../../../backup-restore.md`](../../../../backup-restore.md) 完整文档化流程的 `backup_page.dart` 半边（见"关键安全规则：恢复前后的 WebDAV 自动同步"），并具体走查于 [`../../../examples/backup-restore-walkthrough.md`](../../../../examples/backup-restore-walkthrough.md)。嵌套的私有 `_RestoreModuleDialog` 组件让用户在 `_restoreBackup` 中的确认对话框运行前选择恢复哪些备份模块（目前只有 `anime`）。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `BackupPage({super.key})` | 构造函数（`BackupPage`） | B | 创建备份页实例。 |
| `createState` | 方法（组件生命周期） | B | 为此组件创建可变状态对象。 |
| `initState` | 方法（组件生命周期） | B | 启动初始备份列表/设置加载。 |
| [`_load`](#load) | 方法（`_BackupPageState`） | A | 从 `BackupService` 加载备份设置和当前备份列表。 |
| [`_createBackup`](#createbackup) | 方法（`_BackupPageState`） | A | 创建新备份捆绑并刷新列表。 |
| [`_restoreBackup`](#restorebackup) | 方法（`_BackupPageState`） | A | 确认、需要时禁用自动同步，并恢复备份捆绑。 |
| [`_handlePostRestoreSync`](#handlepostrestoresync) | 方法（`_BackupPageState`） | A | 恢复后提议向 WebDAV 强制上传。 |
| [`_deleteBackup`](#deletebackup) | 方法（`_BackupPageState`） | A | 确认并删除备份捆绑。 |
| [`_toggleAutoBackup`](#toggleautobackup) | 方法（`_BackupPageState`） | A | 持久化自动备份开/关设置。 |
| [`_setRetention`](#setretention) | 方法（`_BackupPageState`） | A | 持久化备份保留天数设置。 |
| `_buildSection` | 方法（组件辅助） | B | 渲染一个带标题的设置小节。 |
| `build` | 方法（组件构建） | B | 渲染当前备份设置/历史 UI 状态。 |
| `_RestoreModuleDialog({required availableModules})` | 构造函数（`_RestoreModuleDialog`） | B | 创建恢复模块对话框实例。 |
| `createState` | 方法（组件生命周期） | B | 为此对话框组件创建可变状态对象。 |
| `initState` | 方法（组件生命周期） | B | 从所有可用模块播种所选模块集合。 |
| `build` | 方法（组件构建） | B | 渲染模块清单对话框。 |

## 文档

### `Future<void> _load()` <a id="load"></a>
- **种类：** `_BackupPageState` 的方法
- **来源：** `lib/features/settings/views/backup_page.dart`（第 52 行）
- **用途：** 加载持久化的备份设置和当前备份捆绑列表，然后填充页面状态。
- **输入：** 无。
- **返回：** 无（经 `setState` 更新 `State` 字段）。
- **副作用：** 读取备份设置并经 `BackupService` 重新枚举磁盘上的 `backups/`；触发重建。
- **算法：**
  1. Await `BackupService.loadSettings()` 填充服务的静态 `autoBackupEnabled`/`retentionDays` 字段（[`../../../shared/services/backup_service.md#loadsettings`](../../../shared/services/backup_service.md#loadsettings)）。
  2. Await `BackupService.listBackups()`（[`../../../shared/services/backup_service.md#listbackups`](../../../shared/services/backup_service.md#listbackups)）取当前 `List<BackupInfo>`。
  3. 仍 `mounted` 时，`setState` 存储列表和设置并清除 `_loading`。
- **用法：**
  ```dart
  @override
  void initState() {
    super.initState();
    _load();
  }
  ```
  也在 `_createBackup` 成功后和 `_deleteBackup` 完成后重新调用，使列表在任何变更后反映磁盘状态。
- **备注：** 因为它在 `await` 之后运行且页面可能已被释放，所以用 `mounted` 守卫每个状态写入。

### `Future<void> _createBackup()` <a id="createbackup"></a>
- **种类：** `_BackupPageState` 的方法
- **来源：** `lib/features/settings/views/backup_page.dart`（第 71 行）
- **用途：** 按需创建新备份捆绑并报告成功或失败。
- **输入：** 无（读取 `context` 供本地化/snackbar）。
- **返回：** 无。
- **副作用：** 经 `BackupService.createBackup()` 写入新 `backups/backup_*.json` 捆绑（和任何新内容寻址 blob）；显示 snackbar；成功时重载列表。
- **算法：**
  1. Await `BackupService.createBackup()`（[`../../../shared/services/backup_service.md#createbackup`](../../../shared/services/backup_service.md#createbackup)）。
  2. 返回非 null `File` 时，显示 `backupCreated` snackbar 并调用 [`_load`](#load) 刷新显示的历史。
  3. 否则显示 `backupFailed` snackbar。
- **用法：**
  ```dart
  ListTile(
    leading: const Icon(Icons.backup),
    title: Text(l10n.backupCreate),
    trailing: const Icon(Icons.chevron_right),
    onTap: _createBackup,
  ),
  ```
- **备注：** 备份创建期间不禁用按钮，因此快速双击可能启动两个重叠的 `createBackup()` 调用；本方法中没有东西防这个。

### `Future<void> _restoreBackup(BackupInfo backup)` <a id="restorebackup"></a>
- **种类：** `_BackupPageState` 的方法
- **来源：** `lib/features/settings/views/backup_page.dart`（第 98 行）
- **用途：** 引导用户选择模块并确认恢复，然后在写入任何文件前应用 WebDAV 自动同步安全规则执行恢复。
- **输入：** `backup` — 用户选择的 `BackupInfo` 条目（其 `.file` 直通给 `BackupService`）。
- **返回：** 无。
- **副作用：** 可能禁用 `webdav_config.json` 中的 WebDAV 自动同步、经 `BackupService.restoreBackup` 覆盖本地数据/图像文件、在空操作失败时重新启用自动同步、通知 `AutoSyncService`/`ReminderService` 监听器，并显示对话框/snackbar。
- **算法：**
  1. 取 `BackupService.getBackupModules(backup.file)`（[`../../../shared/services/backup_service.md#getbackupmodules`](../../../shared/services/backup_service.md#getbackupmodules)）；为空时显示 `backupRestoreFailed` 并停止。
  2. 显示 `_RestoreModuleDialog` 让用户选择恢复哪些模块；用户取消或什么都没选时停止。
  3. 显示确认 `AlertDialog`；未确认时停止。
  4. **在写入任何内容之前：** 加载当前 `WebDAVService.loadConfig()`（[`../../../shared/services/webdav_service.md#loadconfig`](../../../shared/services/webdav_service.md#loadconfig)）。已配置且 `autoSync` 当前开启时，立即 `WebDAVService.saveConfig(config.copyWith(autoSync: false))`——这个特定调用**不带** `mounted` 门，因此这行之后立即崩溃或页面销毁仍会在恢复继续前让自动同步保持关闭。
  5. 调用 `BackupService.restoreBackup(backup.file, moduleKeys: selected)`（[`../../../shared/services/backup_service.md#restorebackup`](../../../shared/services/backup_service.md#restorebackup)）。
  6. `result.ok` 为 `false` 时：只在它之前**开过**且 `result.wroteAnything` 为 `false`（即本地数据可证明未被触碰）时重新启用自动同步；无论哪种情况都显示 `backupRestoreFailed` 并停止。
  7. 成功时：调用 `AutoSyncService.instance.notifyLocalDataChangedNow()` 和 `ReminderService.notifyDataChanged()`，使打开的页面/提醒拾取恢复的数据。
  8. `result.missingImages > 0` 时，显示 `backupRestoreMissingImages(n)` snackbar。
  9. 用恢复前的配置（WebDAV 未配置时为 `null`）调用 [`_handlePostRestoreSync`](#handlepostrestoresync)。
- **用法：**
  ```dart
  IconButton(
    icon: const Icon(Icons.restore),
    tooltip: l10n.backupRestore,
    onPressed: b.corrupt ? null : () => _restoreBackup(b),
  ),
  ```
- **备注：** 第 4 步没有 `mounted` 门是刻意的（见文件自己的文档注释和 [`../../../backup-restore.md`](../../../../backup-restore.md)）——把它门控在 `mounted` 上会冒在 `await` 与检查之间页面被释放时跳过禁用的风险，这正是这段代码存在要防止的失败模式。第 6 步的重新启用分支是自动同步被自动重新打开的唯一地方；部分写入的失败恢复（`wroteAnything == true`）让自动同步保持关闭，直到用户手动解决。

### `Future<void> _handlePostRestoreSync(WebDAVConfig? config)` <a id="handlepostrestoresync"></a>
- **种类：** `_BackupPageState` 的方法
- **来源：** `lib/features/settings/views/backup_page.dart`（第 194 行）
- **用途：** 成功恢复后，提议把恢复出的（现在更旧的）数据强制上传到已配置的 WebDAV 远程，使它处处成为新的事实来源，因为自动同步在恢复前已经被关闭。
- **输入：** `config` — 恢复运行*之前*捕获的 WebDAV 配置，WebDAV 同步未配置时为 `null`。
- **返回：** 无。
- **副作用：** 可能在同一同步唤醒锁下把本地数据/图像强制上传到 WebDAV 远程、用 `AutoSyncService` 记录结果，并显示对话框/snackbar。
- **算法：**
  1. `config == null`（WebDAV 未配置）时，只显示 `backupRestored` snackbar 并返回——没有可提议同步的东西。
  2. 否则显示不可关闭（`barrierDismissible: false`）的 `AlertDialog`，解释同步现已禁用，提供"强制上传"或"跳过"。
  3. 用户未选择强制上传（关闭、选跳过或页面已卸载）时，不触碰远程地返回——自动同步保持关闭，直到用户手动重新启用。
  4. 否则：`SyncWakeLock.acquire()`（[`../../../shared/services/sync_wake_lock.md#acquire`](../../../shared/services/sync_wake_lock.md#acquire)），在总是释放唤醒锁的 `try`/`finally` 内调用 `WebDAVService.forceUpload(config)`（[`../../../shared/services/webdav_service.md#forceupload`](../../../shared/services/webdav_service.md#forceupload)）（[`#release`](../../../shared/services/sync_wake_lock.md#release)），然后经 `AutoSyncService.instance.recordSyncResult(result)` 记录结果并显示成功/失败 snackbar。
- **用法：**
  ```dart
  // Tail of _restoreBackup, after a successful restore:
  if (!mounted) return;
  await _handlePostRestoreSync(webDavConfigured ? config : null);
  ```
- **备注：** 此方法自己绝不重新启用 `autoSync`——按 [`../../../backup-restore.md`](../../../../backup-restore.md)，让自动同步恢复并把刚恢复的（更旧的）快照与实时远程合并，可能向外传播过期记录/删除，因此用户必须稍后从 WebDAV 设置页显式重新启用。

### `Future<void> _deleteBackup(BackupInfo backup)` <a id="deletebackup"></a>
- **种类：** `_BackupPageState` 的方法
- **来源：** `lib/features/settings/views/backup_page.dart`（第 252 行）
- **用途：** 与用户确认，然后永久删除一个备份捆绑。
- **输入：** `backup` — 要删除的 `BackupInfo` 条目。
- **返回：** 无。
- **副作用：** 删除捆绑文件（并在 `BackupService` 内运行引用计数 blob GC）；重载备份列表。
- **算法：**
  1. 显示确认 `AlertDialog`；未确认（或页面期间已卸载）时返回。
  2. Await `BackupService.deleteBackup(backup.file)`（[`../../../shared/services/backup_service.md#deletebackup`](../../../shared/services/backup_service.md#deletebackup)）。
  3. 调用 [`_load`](#load) 刷新显示的历史。
- **用法：**
  ```dart
  IconButton(
    icon: const Icon(Icons.delete_outline),
    tooltip: l10n.delete,
    onPressed: () => _deleteBackup(b),
  ),
  ```
- **备注：** 即使对 `corrupt` 捆绑也可用（与恢复按钮不同，后者对它们禁用），因为损坏捆绑删除起来仍然安全。

### `Future<void> _toggleAutoBackup(bool value)` <a id="toggleautobackup"></a>
- **种类：** `_BackupPageState` 的方法
- **来源：** `lib/features/settings/views/backup_page.dart`（第 282 行）
- **用途：** 持久化用户的自动备份开/关选择。
- **输入：** `value` — 新的开关状态。
- **返回：** 无。
- **副作用：** 更新 `BackupService.autoBackupEnabled` 并经 `BackupService.saveSettings()` 写入磁盘。
- **算法：**
  1. `setState` 立即更新本地 `_autoBackup` 字段（乐观 UI 更新）。
  2. 设置静态 `BackupService.autoBackupEnabled` 字段。
  3. Await `BackupService.saveSettings()`（[`../../../shared/services/backup_service.md#savesettings`](../../../shared/services/backup_service.md#savesettings)）持久化它。
- **用法：**
  ```dart
  SwitchListTile(
    secondary: const Icon(Icons.schedule_outlined),
    title: Text(l10n.backupAutoBackup),
    subtitle: Text(l10n.backupAutoBackupDesc),
    value: _autoBackup,
    onChanged: _toggleAutoBackup,
  ),
  ```
- **备注：** 无。

### `Future<void> _setRetention(int days)` <a id="setretention"></a>
- **种类：** `_BackupPageState` 的方法
- **来源：** `lib/features/settings/views/backup_page.dart`（第 293 行）
- **用途：** 持久化用户选择的备份保留窗口。
- **输入：** `days` — 固定 `_retentionOptions` 值之一（`0, 3, 7, 14, 30, 60, 90`；`0` 表示永久保留）。
- **返回：** 无。
- **副作用：** 更新 `BackupService.retentionDays` 并经 `BackupService.saveSettings()` 写入磁盘。
- **算法：** 与 [`_toggleAutoBackup`](#toggleautobackup) 相同的三步形态：乐观 `setState`、更新静态服务字段，然后 `await BackupService.saveSettings()`。
- **用法：**
  ```dart
  DropdownButton<int>(
    value: _retentionDays,
    items: _retentionOptions.map((d) {
      final label = d == 0 ? l10n.backupKeepForever : l10n.backupKeepDays(d);
      return DropdownMenuItem(value: d, child: Text(label));
    }).toList(),
    onChanged: (v) {
      if (v != null) _setRetention(v);
    },
  ),
  ```
- **备注：** 本页只设置值；实际保留清理（删除比 `retentionDays` 更旧的捆绑）在 `BackupService` 内运行，不在这里——见 [`../../../backup-restore.md`](../../../../backup-restore.md)。
