# lib/shared/services/auto_sync_service.dart

**共享调度器上的门面。** 生命周期观察者、30 秒保存防抖、15 分钟周期计时器、进行中守卫和状态记账移入 `myapps_data` 包（`lib/src/sync/auto_sync_scheduler.dart`）。本应用的额外内容作为钩子留在这里。

## 本应用提供的钩子

| 钩子 | 值 |
|---|---|
| `isAutoSyncActive` | 配置存在、已配置且启用了 `autoSync`。 |
| `runSync` | `WebDAVService.sync(config)` — 绝不用 `autoResolve`。 |
| `consumeLocalDataChanged` | `WebDAVService.consumeLocalDataChanged`。 |
| `onPeriodicTick` | `BackupService.runAutoBackupIfNeeded`，使跨过午夜持续运行的桌面实例仍能完成每日备份。 |
| `onResume` | 每日备份**和** `ReminderService.notifyDataChanged()`。 |

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `instance` | 静态字段 | A | 单例。 |
| `lastSuccessAt` / `lastFailureAt` / `lastError` / `hasPendingConflicts` | getter | A | 供设置 UI 的内存同步状态。 |
| `addOnLocalDataChanged` / `removeOnLocalDataChanged` | 方法 | A | 注册和移除 UI 重载回调。 |
| `addOnStatusChanged` / `removeOnStatusChanged` | 方法 | A | 注册和移除状态变更回调。 |
| `recordSyncResult(result)` | 方法 | A | 把手动触发的同步记入同一状态路径。 |
| `recordFinalizeResult(ok)` | 方法 | A | 记录一次冲突最终化。 |
| `notifyLocalDataChangedIfNeeded()` | 方法 | A | **如果**引擎标志被设置则触发重载回调。 |
| `notifyLocalDataChangedNow()` | 方法 | A | 无条件触发重载回调（恢复、ZIP 导入）。 |
| `start()` / `stop()` | 方法 | A | 开始和结束观察生命周期并运行计时器。 |
| `notifySaved()` | 方法 | A | 存储钩子：重启 30 秒防抖。 |
| `requestSyncNow()` | 方法 | A | 取消任何挂起防抖并立即同步。 |

## 备注

- 状态只在内存中，绝不持久化。
- 自动同步保持 `autoResolve` 禁用：真正的双向冲突记录为可见待定状态，而不是静默应用最后写入者胜出。
- 重叠触发被进行中守卫静默跳过，因此后台滴答绝不会浮出虚假的"同步已在进行中"横幅。
- `notifySaved()` 在 `start()` 之前被忽略，因此服务尚未观察生命周期时，早期存储写入不可能安排同步。
- 启动、恢复和周期滴答都会在同步前取消挂起的防抖。

## 调度器文档的位置

`packages/myapps_data/doc/en-us/functions/src/sync/auto_sync_scheduler.md`。
