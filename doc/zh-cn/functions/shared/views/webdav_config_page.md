# lib/shared/views/webdav_config_page.dart

`WebDAVConfigPage` 是设置 -> WebDAV 同步屏：它编辑 `WebDAVConfig`（`lib/shared/services/webdav_service.dart`，[`../services/webdav_service.md`](../services/webdav_service.md)）、测试连接、运行手动同步、强制上传/强制下载，并且——文件中最重要的逻辑——通过私有 `_ConflictDialog` 组件引导用户逐个解决逐记录同步冲突。本页是 [`../../sync.md`](../../../sync.md) 文档化的十步同步流程、冲突处理、唤醒锁和强制操作规则的 UI 半边，具体冲突演练场景见 [`../../examples/sync-walkthrough.md`](../../../examples/sync-walkthrough.md)。这里几乎每个非 `build` 方法都做真实工作（忙碌标志和屏幕唤醒锁下的服务调用，或实际冲突解决分支），而不是纯组件组合，符合本文件预期的"真实状态/冲突解决逻辑"。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `WebDAVConfigPage({super.key})` | 构造函数（`WebDAVConfigPage`） | B | 创建 WebDAV 配置页实例。 |
| `createState` | 方法（组件生命周期） | B | 为此组件创建可变状态对象。 |
| `initState` | 方法（组件生命周期） | B | 注册同步状态监听器并启动配置加载。 |
| `_refreshSyncStatus` | 方法（组件辅助） | B | 后台同步状态变化时重建页面。 |
| [`_loadConfig`](#loadconfig) | 方法（`_WebDAVConfigPageState`） | A | 把持久化的 WebDAV 配置加载进文本控制器和标志。 |
| `dispose` | 方法（组件生命周期） | B | 释放同步状态监听器和文本控制器。 |
| [`_currentConfig`](#currentconfig) | getter（`_WebDAVConfigPageState`） | A | 从当前表单字段值构建 `WebDAVConfig`。 |
| [`_saveConfig`](#saveconfig) | 方法（`_WebDAVConfigPageState`） | A | 把当前表单持久化为 WebDAV 配置，适用时请求同步。 |
| [`_testConnection`](#testconnection) | 方法（`_WebDAVConfigPageState`） | A | 测试到配置的 WebDAV 服务器的连通性。 |
| [`_syncNow`](#syncnow) | 方法（`_WebDAVConfigPageState`） | A | 在唤醒锁下运行手动同步并把冲突路由到解决。 |
| [`_showSyncResult`](#showsyncresult) | 方法（`_WebDAVConfigPageState`） | A | 把非冲突同步/强制结果呈现为对话框或 snackbar。 |
| [`_forceUpload`](#forceupload) | 方法（`_WebDAVConfigPageState`） | A | 确认并运行破坏性强制上传（本地覆盖远程）。 |
| [`_forceDownload`](#forcedownload) | 方法（`_WebDAVConfigPageState`） | A | 确认并运行破坏性强制下载（远程覆盖本地）。 |
| `_confirmForceAction` | 方法（组件辅助） | B | 为破坏性强制操作显示共享的是/否确认对话框。 |
| [`_progressText`](#progresstext) | 方法（`_WebDAVConfigPageState`） | A | 把 `SyncProgress` 快照映射为本地化状态行。 |
| [`_resolveConflicts`](#resolveconflicts) | 方法（`_WebDAVConfigPageState`） | A | 让用户解决每个待定同步冲突，然后上传结果。 |
| [`_disconnect`](#disconnect) | 方法（`_WebDAVConfigPageState`） | A | 删除 WebDAV 配置并重置表单。 |
| `_fillNextcloud` | 方法（组件辅助） | B | 用占位 Nextcloud URL/路径预填表单。 |
| [`_syncStatusText`](#syncstatustext) | 方法（`_WebDAVConfigPageState`） | A | 构建短同步健康摘要行供显示。 |
| `build` | 方法（组件构建） | B | 渲染 WebDAV 配置表单和同步/状态控件。 |
| `_ConflictDialog({required conflict})` | 构造函数（`_ConflictDialog`） | B | 创建冲突对话框实例。 |
| `build` | 方法（组件构建） | B | 为一条冲突记录渲染本地-vs-远程比较。 |

## 文档

### `Future<void> _loadConfig()` <a id="loadconfig"></a>
- **种类：** `_WebDAVConfigPageState` 的方法
- **来源：** `lib/shared/views/webdav_config_page.dart`（第 65 行）
- **用途：** 从持久化的 `WebDAVConfig` 填充表单的文本控制器和标志（如存在）。
- **输入：** 无。
- **返回：** 无（修改四个 `TextEditingController` 和 `_isConfigured`/`_autoSync`）。
- **副作用：** 经 `WebDAVService.loadConfig()` 读取 `webdav_config.json`。
- **算法：**
  1. Await `WebDAVService.loadConfig()`（[`../services/webdav_service.md#loadconfig`](../services/webdav_service.md#loadconfig)）。
  2. 找到配置时，把 `serverUrl`/`username`/`password`/`remotePath` 复制进匹配控制器，并从它设置 `_isConfigured`/`_autoSync`。
  3. 仍 `mounted` 时，`setState` 清除 `_loading`。
- **用法：**
  ```dart
  @override
  void initState() {
    super.initState();
    AutoSyncService.instance.addOnStatusChanged(_refreshSyncStatus);
    _loadConfig();
  }
  ```
- **备注：** 尚不存在配置时，控制器保持构造函数默认值（空 URL/用户/密码，`/MyAnime` 作远程路径）。

### `WebDAVConfig get _currentConfig` <a id="currentconfig"></a>
- **种类：** `_WebDAVConfigPageState` 的 getter
- **来源：** `lib/shared/views/webdav_config_page.dart`（第 98 行）
- **用途：** 从表单当前字段值（修剪周边空白）构建 `WebDAVConfig` 快照。
- **输入：** 无（读取四个 `TextEditingController` 和 `_autoSync`）。
- **返回：** 新的 `WebDAVConfig`（[`../services/webdav_service.md#webdavconfig-new`](../services/webdav_service.md#webdavconfig-new)）。
- **副作用：** 无。
- **算法：** 构建 `WebDAVConfig(serverUrl: ..., username: ..., password: ..., remotePath: ..., autoSync: _autoSync)`，对四个文本值各调用 `.trim()`。
- **用法：** 每个需要用户当前已输入的配置的操作读取——
  ```dart
  Future<void> _saveConfig() async {
    final config = _currentConfig;
    await WebDAVService.saveConfig(config);
    ...
  }
  ```
  [`_testConnection`](#testconnection)、[`_syncNow`](#syncnow)、[`_forceUpload`](#forceupload)、[`_forceDownload`](#forcedownload) 和 [`_resolveConflicts`](#resolveconflicts) 也类似。
- **备注：** 因为这是 getter（不是缓存值），每次调用都重新读取控制器，因此即使页面加载后、保存前用户输入了东西，它也总是反映最新的屏幕编辑。

### `Future<void> _saveConfig()` <a id="saveconfig"></a>
- **种类：** `_WebDAVConfigPageState` 的方法
- **来源：** `lib/shared/views/webdav_config_page.dart`（第 111 行）
- **用途：** 把当前表单持久化为 WebDAV 配置，保存的配置既已配置又开了自动同步时立即请求一次同步。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 经 `WebDAVService.saveConfig` 写 `webdav_config.json`；可能经 `AutoSyncService.requestSyncNow()` 触发立即后台同步；显示 snackbar。
- **算法：**
  1. 读取 [`_currentConfig`](#currentconfig) 并 `await WebDAVService.saveConfig(config)`（[`../services/webdav_service.md#saveconfig`](../services/webdav_service.md#saveconfig)）。
  2. `config.isConfigured && config.autoSync` 时调用 `AutoSyncService.instance.requestSyncNow()`（[`../services/auto_sync_service.md#requestsyncnow`](../services/auto_sync_service.md#requestsyncnow)）——按 [`../../sync.md`](../../../sync.md)，这是"启用/保存自动同步配置后立即同步"触发。
  3. `setState` 刷新 `_isConfigured`。
  4. `mounted` 时显示 `settingsWebDAVConfigSaved` snackbar。
- **用法：**
  ```dart
  Expanded(
    child: FilledButton(
      onPressed: _saveConfig,
      child: Text(l10n.save),
    ),
  ),
  ```
  也从自动同步 `SwitchListTile` 的 `onChanged` 直接调用，因此切换自动同步无需单独点"保存"就立即保存。
- **备注：** 无。

### `Future<void> _testConnection()` <a id="testconnection"></a>
- **种类：** `_WebDAVConfigPageState` 的方法
- **来源：** `lib/shared/views/webdav_config_page.dart`（第 134 行）
- **用途：** 验证当前输入的 WebDAV 凭据/URL 是否真能到达服务器，不保存任何东西。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 经 `WebDAVService.testConnection` 执行网络请求；显示成功/失败 snackbar；切换 `_testing`（驱动按钮的转圈）。
- **算法：**
  1. `setState(() => _testing = true)`。
  2. Await `WebDAVService.testConnection(_currentConfig)`（[`../services/webdav_service.md#testconnection`](../services/webdav_service.md#testconnection)）。
  3. `mounted` 时，`setState(() => _testing = false)` 并按结果显示 `settingsWebDAVConnectionSuccess`/`settingsWebDAVConnectionFailed`。
- **用法：**
  ```dart
  Expanded(
    child: OutlinedButton(
      onPressed: _testing ? null : _testConnection,
      child: _testing
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Text(l10n.settingsWebDAVTestConnection),
    ),
  ),
  ```
- **备注：** 用未保存的 [`_currentConfig`](#currentconfig)，因此用户可以在用 `_saveConfig` 提交凭据前测试。

### `Future<void> _syncNow()` <a id="syncnow"></a>
- **种类：** `_WebDAVConfigPageState` 的方法
- **来源：** `lib/shared/views/webdav_config_page.dart`（第 160 行）
- **用途：** 在屏幕唤醒锁下运行完整手动同步周期（[`../../sync.md`](../../../sync.md) 的十步流程），然后把任何冲突路由到解决或显示普通结果。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 期间持有同步唤醒锁；可能经 `WebDAVService.sync` 写本地数据/图像文件并上传到 WebDAV 远程；用 `AutoSyncService` 记录结果；可能触发本地数据变更通知；显示对话框或 snackbar。
- **算法：**
  1. `setState(() => _syncing = true)`。
  2. `await SyncWakeLock.acquire()`（[`../services/sync_wake_lock.md#acquire`](../services/sync_wake_lock.md#acquire)）。
  3. 在 `try`/`finally` 中：运行 `WebDAVService.sync(_currentConfig)`（本仓库用默认 `autoResolve: false` 调用 `WebDAVService.sync`，匹配 [`../../sync.md`](../../../sync.md) 的"手动同步绝不静默解决冲突"规则）；`finally` 无论成功/失败/异常总是释放唤醒锁并重置 `_syncing`。
  4. `await` 后已卸载时返回。
  5. `AutoSyncService.instance.recordSyncResult(result)`（[`../services/auto_sync_service.md#recordsyncresult`](../services/auto_sync_service.md#recordsyncresult)）和 `.notifyLocalDataChangedIfNeeded()`（[`#notifylocaldatachangedifneeded`](../services/auto_sync_service.md#notifylocaldatachangedifneeded)）。
  6. `result.hasConflicts` 时把其余流程委托给 [`_resolveConflicts(result)`](#resolveconflicts) 并返回。
  7. 否则经 [`_showSyncResult(result)`](#showsyncresult) 显示普通结果。
- **用法：**
  ```dart
  FilledButton.icon(
    onPressed: _syncing ? null : () => _syncNow(),
    icon: _syncing
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : const Icon(Icons.sync),
    label: Text(_syncing ? l10n.settingsWebDAVSyncing : l10n.settingsWebDAVSyncNow),
  ),
  ```
- **备注：** 唤醒锁和 `_syncing` 标志在 `finally` 中重置，因此 `WebDAVService.sync` 抛出的异常仍让 UI 处于干净、可重新触发的状态（匹配 [`../../sync.md`](../../../sync.md) 的"在完成、失败、取消或异常时的 `finally` 块中释放"规则）。

### `Future<void> _showSyncResult(SyncResult result)` <a id="showsyncresult"></a>
- **种类：** `_WebDAVConfigPageState` 的方法
- **来源：** `lib/shared/views/webdav_config_page.dart`（第 187 行）
- **用途：** 呈现没有待定冲突的同步/强制操作结果，在失败对话框、警告对话框或普通成功 snackbar 之间选择。
- **输入：** `result` — 要显示的 `SyncResult`（调用方假设 `hasConflicts` 为 false）。
- **返回：** 无。
- **副作用：** 显示 `AlertDialog`（失败或警告时）或 `SnackBar`（纯成功时）。
- **算法：**
  1. `!result.success` 时，显示带 `result.error`（或 `'-'`）于 `SelectableText` 的 `AlertDialog` 并返回。
  2. 否则 `result.warnings.isNotEmpty` 时，显示列出警告计数和每条警告字符串的 `AlertDialog` 并返回——这是 [`../../sync.md`](../../../sync.md) 描述的图像同步警告的 UI 表面（"远程图像目录列表在任何失败时返回 `null`……跳过图像阶段并给出可见警告"）。
  3. 否则显示普通 `settingsWebDAVSyncSuccess` snackbar。
- **用法：** 从 [`_syncNow`](#syncnow)（非冲突路径）、[`_forceUpload`](#forceupload) 和 [`_forceDownload`](#forcedownload) 调用——总是作为记录结果后的最后一步。
- **备注：** 按 [`../../sync.md`](../../../sync.md)，"同步错误和图像传输警告显示在对话框中，而不只是 snackbar，因为它们需要保持可见"——本方法正是该规则实现的地方；只有完全干净的情形落入瞬态 snackbar。

### `Future<void> _forceUpload()` <a id="forceupload"></a>
- **种类：** `_WebDAVConfigPageState` 的方法
- **来源：** `lib/shared/views/webdav_config_page.dart`（第 257 行）
- **用途：** 用户显式确认后，用本地副本覆盖远程数据/图像，完全绕过合并。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 显示破坏性确认对话框；持有同步唤醒锁；经 `WebDAVService.forceUpload` 覆盖 WebDAV 远程；记录结果；显示结果。
- **算法：**
  1. `await _confirmForceAction(...)`，带强制上传确认文案；未确认（或已卸载）时停止。
  2. `setState(() => _syncing = true)`、`await SyncWakeLock.acquire()`。
  3. 在 `try`/`finally` 中：`WebDAVService.forceUpload(_currentConfig)`（[`../services/webdav_service.md#forceupload`](../services/webdav_service.md#forceupload)）；`finally` 释放唤醒锁并重置 `_syncing`。
  4. 已卸载则返回；否则 `recordSyncResult`、`notifyLocalDataChangedIfNeeded` 和 [`_showSyncResult(result)`](#showsyncresult)。
- **用法：**
  ```dart
  Expanded(
    child: OutlinedButton.icon(
      onPressed: _syncing ? null : _forceUpload,
      icon: const Icon(Icons.upload, size: 18),
      label: Text(l10n.settingsWebDAVForceUpload),
    ),
  ),
  ```
  恢复后也（经 `WebDAVService.forceUpload` 直接调用，不经此方法）从 `backup_page.dart` 调用——见 [`../../../features/settings/views/backup_page.md#handlepostrestoresync`](../../features/settings/views/backup_page.md#handlepostrestoresync)。
- **备注：** 与 [`_forceDownload`](#forcedownload) 几乎完全镜像，只差调用哪个确认文案和哪个 `WebDAVService` 方法。唤醒锁只在确认后获取，按 [`../../sync.md`](../../../sync.md) 的规则。

### `Future<void> _forceDownload()` <a id="forcedownload"></a>
- **种类：** `_WebDAVConfigPageState` 的方法
- **来源：** `lib/shared/views/webdav_config_page.dart`（第 288 行）
- **用途：** 用户显式确认后，用远程副本覆盖本地数据/图像，完全绕过合并。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 显示破坏性确认对话框；持有同步唤醒锁；经 `WebDAVService.forceDownload` 覆盖本地文件；记录结果；显示结果。
- **算法：** 与 [`_forceUpload`](#forceupload) 形态相同，改为调用 `WebDAVService.forceDownload(_currentConfig)`（[`../services/webdav_service.md#forcedownload`](../services/webdav_service.md#forcedownload)）。
- **用法：**
  ```dart
  Expanded(
    child: OutlinedButton.icon(
      onPressed: _syncing ? null : _forceDownload,
      icon: const Icon(Icons.download, size: 18),
      label: Text(l10n.settingsWebDAVForceDownload),
    ),
  ),
  ```
- **备注：** 按 [`../../sync.md`](../../../sync.md)，`forceDownload` **不取**远程锁（不同于在 `.lock` 下上传的 `forceUpload`）；本方法本身不区分那个——它只是 await 回来的任何 `SyncResult`。

### `String _progressText(AppLocalizations l10n, SyncProgress progress)` <a id="progresstext"></a>
- **种类：** `_WebDAVConfigPageState` 的方法
- **来源：** `lib/shared/views/webdav_config_page.dart`（第 349 行）
- **用途：** 把一个 `SyncProgress` 阶段快照翻译为同步/强制操作运行时进度条下方显示的本地化状态行。
- **输入：** `l10n` — 当前 `AppLocalizations`；`progress` — 来自 `WebDAVService.progress`（`ValueNotifier<SyncProgress>`，[`../../sync.md`](../../../sync.md#syncprogress-phases)）的 `SyncProgress` 值。
- **返回：** 本地化 `String`，`idle`/`done`/`error` 阶段为 `''`（那些阶段进度条下方没有可显示的东西）。
- **副作用：** 无。
- **算法：** `switch (progress.phase)`：`connecting` -> 普通标签；`downloadingData`/`uploadingData`/`merging` -> 用 `progress.detail`（文件名）参数化的标签，`downloadingData` 还带 `current`/`total`；`uploadingImages`/`downloadingImages` -> 用 `current`/`total` 参数化的标签；`idle`/`done`/`error` -> `''`。
- **用法：**
  ```dart
  ValueListenableBuilder<SyncProgress>(
    valueListenable: WebDAVService.progress,
    builder: (context, progress, _) {
      if (!progress.isRunning) return const SizedBox.shrink();
      return Column(
        children: [
          LinearProgressIndicator(value: progress.fraction),
          Text(_progressText(l10n, progress), style: theme.textTheme.bodySmall),
        ],
      );
    },
  ),
  ```
- **备注：** `switch` 对 `SyncPhase` 穷尽（无 `default` 分支）——向枚举添加新阶段值而不更新此 `switch` 会编译失败，这是这个纯展示映射刻意的安全网。

### `Future<void> _resolveConflicts(SyncResult result)` <a id="resolveconflicts"></a>
- **种类：** `_WebDAVConfigPageState` 的方法
- **来源：** `lib/shared/views/webdav_config_page.dart`（第 387 行）
- **用途：** 引导用户逐个解决每个待定的逐记录同步冲突，然后在重新获取的锁下上传完全解决的数据。
- **输入：** `result` — `result.pending` 非 null（即 `hasConflicts` 为 true）的 `SyncResult`。
- **返回：** 无。
- **副作用：** 每个冲突显示一个不可关闭的 `_ConflictDialog`；最终化期间持有同步唤醒锁；经 `WebDAVService.finalizePendingSync` 强制上传解决的数据；记录结果；显示 snackbar。
- **算法：**（匹配 [`../../sync.md`](../../../sync.md) 十步流程的冲突分支，具体演练于 [`../../examples/sync-walkthrough.md`](../../../examples/sync-walkthrough.md) 场景 2）
  1. 对 `result.pending!.allConflicts` 中的每个 `conflict`：已卸载则停止；显示 `_ConflictDialog(conflict: conflict)`（`barrierDismissible: false`）并 await 用户选中的 `Anime` 记录（`local` 或 `remote`）。
  2. **用户关闭对话框时**（返回 `null`，如系统返回）：经 `AutoSyncService.recordSyncResult` 记录原始 `result`（让冲突保持待定），显示 `settingsWebDAVSyncFailed` snackbar，立即返回——不上传任何东西，剩余冲突甚至不再显示。
  3. 否则存储 `resolutions[conflict.id] = chosen` 并继续下一个冲突。
  4. 每个冲突都有解决方案后：`await SyncWakeLock.acquire()`，然后在 `try`/`finally` 中调用 `WebDAVService.finalizePendingSync(_currentConfig, pending, resolutions)`（[`../services/webdav_service.md#finalizependingsync`](../services/webdav_service.md#finalizependingsync)）——`finally` 总是释放唤醒锁。
  5. `AutoSyncService.instance.recordFinalizeResult(ok)`（[`../services/auto_sync_service.md#recordfinalizeresult`](../services/auto_sync_service.md#recordfinalizeresult)）。
  6. 仍 `mounted` 时，按 `ok` 显示 `settingsWebDAVSyncSuccess` 或 `settingsWebDAVSyncFailed`。
- **用法：**
  ```dart
  if (result.hasConflicts) {
    await _resolveConflicts(result);
    return;
  }
  ```
  （来自 [`_syncNow`](#syncnow)，唯一调用方）。
- **备注：** 此方法在成功最终化后自己绝不通知 `AutoSyncService.notifyLocalDataChangedIfNeeded()`——那个通知在调用此方法之前就已经在 `_syncNow` 中为初始（冲突）同步尝试发生过了。`finalizePendingSync` 调用会重新读取新鲜的 `_currentConfig`，以防用户在解决冲突时编辑了表单。

### `Future<void> _disconnect()` <a id="disconnect"></a>
- **种类：** `_WebDAVConfigPageState` 的方法
- **来源：** `lib/shared/views/webdav_config_page.dart`（第 446 行）
- **用途：** 完全移除持久化的 WebDAV 配置并把表单重置为其未配置默认值。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 经 `WebDAVService.deleteConfig()` 删除 `webdav_config.json`；清除表单控制器；显示 snackbar。
- **算法：**
  1. `await WebDAVService.deleteConfig()`（[`../services/webdav_service.md#deleteconfig`](../services/webdav_service.md#deleteconfig)）。
  2. 清除 URL/用户/密码控制器并把路径控制器重置为 `/MyAnime`。
  3. `setState` 清除 `_isConfigured` 和 `_autoSync`。
  4. `mounted` 时显示 `settingsWebDAVConfigRemoved`。
- **用法：**
  ```dart
  OutlinedButton.icon(
    onPressed: _disconnect,
    icon: const Icon(Icons.link_off),
    label: Text(l10n.settingsWebDAVDisconnect),
    style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
  ),
  ```
- **备注：** 没有确认对话框守卫这个操作——与 `_forceUpload`/`_forceDownload` 不同，断开连接在运行前没有 `_confirmForceAction` 步骤。

### `String? _syncStatusText(AppLocalizations l10n)` <a id="syncstatustext"></a>
- **种类：** `_WebDAVConfigPageState` 的方法
- **来源：** `lib/shared/views/webdav_config_page.dart`（第 484 行）
- **用途：** 构建进度指示器上方显示的短同步健康行，反映 `AutoSyncService` 最后记录的结果。
- **输入：** `l10n` — 当前 `AppLocalizations`。
- **返回：** 本地化状态字符串，既无错误也无已记录的成功时间戳时为 `null`。
- **副作用：** 无（纯读 `AutoSyncService.instance` 状态）。
- **算法：**
  1. `AutoSyncService.instance.lastError != null` 时：按 `hasPendingConflicts` 返回冲突风味或失败风味消息（`settingsWebDAVAutoSyncConflict`/`settingsWebDAVAutoSyncFailed`），后跟原始错误字符串。
  2. 否则 `lastSuccessAt != null` 时：返回 `settingsWebDAVLastSuccess` 后跟本地化时间戳（`.toLocal()`）。
  3. 否则返回 `null`。
- **用法：**
  ```dart
  @override
  Widget build(BuildContext context) {
    final syncStatus = _syncStatusText(l10n);
    ...
  ```
- **备注：** 这与主设置页 WebDAV 行（`functions/features/settings/views/settings_page.md`）也浮出的相同状态文本和错误-vs-冲突分支相同，那里直接从 `AutoSyncService.instance.lastError`/`hasPendingConflicts` 读取而不是经此辅助——两个页面独立格式化同一底层状态。
