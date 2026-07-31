# lib/shared/widgets/delete_confirm.dart

一个共享辅助 `confirmDelete`，显示带可选"5 分钟内不再询问"复选框的主题化删除确认对话框，由模块级抑制时间戳支撑。动画管理/详情页在破坏性删除操作前使用它。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`confirmDelete`](#confirmdelete) | 顶层函数 | A | 询问用户确认删除，可选短暂抑制提示。 |

模块级 `_suppressUntil` 变量是普通私有字段（普通文档注释，不是 `/// Purpose:` 块），不作为单独行索引；它是 `confirmDelete` 的私有状态。

## 文档

### `Future<bool> confirmDelete(BuildContext context, String itemLabel)` <a id="confirmdelete"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/widgets/delete_confirm.dart`（约第 13 行）
- **用途：** 为 `itemLabel` 显示删除确认 `AlertDialog`，可选让用户抑制对话框 5 分钟。
- **输入：** `context` — 用于显示对话框和读取本地化；`itemLabel` — 被删除项目的人类可读名称，插入确认消息。
- **返回：** `Future<bool>` — 应继续删除为 `true`，取消为 `false`。
- **副作用：** 可能经 `showDialog` 显示 `AlertDialog`；可能设置模块级 `_suppressUntil` 时间戳，影响应用会话剩余时间的未来调用。
- **算法：**
  1. `_suppressUntil` 非 null 且仍在未来时，不显示任何对话框立即返回 `true`（用户最近选择了"不再询问"）。
  2. 否则，显示带项目名、"5 分钟内不再询问"`Checkbox` 和取消/删除操作的 `AlertDialog`（经 `StatefulBuilder`，使复选框能更新自己的状态）。取消弹出 `false`；删除弹出 `true`。
  3. 对话框结果为 `true` 且复选框被勾选时，设 `_suppressUntil = DateTime.now().add(const Duration(minutes: 5))`。
  4. 返回对话框结果，对话框未按按钮被关闭时为 `false`（`result ?? false`）。
- **用法：**
  ```dart
  final ok = await confirmDelete(context, anime.displayTitle);
  ```
  （来自 `lib/features/anime/views/management_page.dart`；`lib/features/anime/views/anime_detail_page.dart` 也使用）
- **备注：** `_suppressUntil` 是单个全局（不是按项目类型）抑制窗口，由应用每个调用点共享——勾选一次"不再询问"会在 5 分钟内抑制应用内任何后续 `confirmDelete` 调用的确认。本地化查找返回 `null` 时回退到硬编码英文串（`'Confirm Delete'`、`'Delete $itemLabel?'` 等）。
