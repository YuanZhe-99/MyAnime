# lib/shared/widgets/import_bundle_dialog.dart

驱动 `.myanimeitem` 捆绑导入 UI 流程：经 `FileOpenService.pickAndParseBundle()` 选择并解析捆绑，对与既有本地动画冲突的记录显示逐冲突解决对话框（`_ImportConflictDialog`），并应用结果。`AGENTS.md` 的"分享与文件导入"一节和 [../../../data-formats.md](../../../data-formats.md) 描述 `.myanimeitem` v1/v2 捆绑格式。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`showImportBundleFlow`](#showimportbundleflow) | 顶层函数 | A | 运行带冲突解决的完整导入捆绑流程。 |
| [`ImportBundleResult.new`](#importbundleresult-new) | 构造函数（`ImportBundleResult`） | A | 创建导入捆绑结果实例。 |
| `_ImportConflictDialog` | 类（`StatelessWidget`） | B | 显示单个导入冲突解决对话框。 |
| `_ImportConflictDialog.new` | 构造函数（`_ImportConflictDialog`） | B | 创建导入冲突对话框实例。 |
| `_ImportConflictDialog.build` | 方法（`_ImportConflictDialog`，组件构建） | B | 构建冲突对话框的标题/正文/操作。 |
| `_ImportConflictDialog._buildSummary` | 方法（组件辅助） | B | 为冲突的一侧渲染紧凑摘要（标题、日期、进度、URL）。 |

私有 `_ConflictResolution` 枚举没有 `/// Purpose:` 注释，不作为单独行索引。

## 文档

### `Future<ImportBundleResult?> showImportBundleFlow(BuildContext context)` <a id="showimportbundleflow"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/widgets/import_bundle_dialog.dart`（约第 18 行）
- **用途：** 驱动端到端 `.myanimeitem` 捆绑导入：选择文件、交互式解决与既有本地记录的任何冲突，然后应用结果。
- **输入：** `context` — 用于文件选择器、冲突对话框和 snackbar。
- **返回：** `Future<ImportBundleResult?>` — 用户取消文件选择器为 `null`，否则带导入/合并动画 ID 和总数（每个冲突都解决为"保留本地"时可能为 `0`）的 `ImportBundleResult`。
- **副作用：** 显示文件选择器（经 `FileOpenService.pickAndParseBundle`）、每个冲突记录可能显示一个模态冲突对话框、写入动画存储（经 `FileOpenService.applyBundle` 和 `FileOpenService.replaceAnime`），并显示成功 `SnackBar`。
- **算法：**
  1. 调用 `FileOpenService.pickAndParseBundle()`；用户取消（结果为 `null`）或 `context` 不再 mounted 时立即返回 `null`。
  2. `bundle.hasConflicts` 时，遍历 `bundle.conflictIndices`：对每个冲突索引，显示模态、不可关闭的 `_ImportConflictDialog` 比较本地和导入版本，并 await 一个 `_ConflictResolution`（`keepLocal`、`useImported` 或 `merge`）。
     - `null`（对话框关闭）或 `keepLocal` → 把索引加进 `skipIndices`。
     - `useImported` → 不动该索引（它将带其新 UUID 原样导入）。
     - `merge` → 把索引加进 `mergeIndices`。
     没有冲突时显示"无冲突"snackbar 代替。
  3. 调用 `FileOpenService.applyBundle(bundle, skipIndices: {...skipIndices, ...mergeIndices})` 导入既未跳过也未被合并的每条记录；把计数捕获为 `added`。
  4. 对 `mergeIndices` 中每个索引，计算 `DuplicateService.merge(local, [imported])` 并经 `FileOpenService.replaceAnime(local.id, merged)` 写回，递增 `mergedCount`。
  5. `context` mounted 且 `added + mergedCount > 0` 时，显示带总数的成功 `SnackBar`。
  6. 构建 `importedIds`：对不在 `skipIndices` 中的每个捆绑索引，被合并时用*本地*记录的 ID（本地记录存活、已更新），否则用*导入*记录的（新）ID。
  7. 返回 `ImportBundleResult(importedIds: importedIds, count: added + mergedCount)`。
- **用法：**
  ```dart
  final result = await showImportBundleFlow(context);
  ```
  （来自 `lib/features/anime/views/home_page.dart` 和 `lib/features/anime/views/management_page.dart`，两者都从"导入"菜单操作调用）
- **备注：** 关闭冲突对话框（如系统返回）与显式选择那条记录的"保留本地"同等对待——它*不*中止整个导入流程，与 `AGENTS.md` 描述的 WebDAV 同步冲突对话框不同。每个冲突在循环中独立解决；被关闭的对话框只跳过那一条记录。

### `const ImportBundleResult({required this.importedIds, required this.count})` <a id="importbundleresult-new"></a>
- **种类：** `ImportBundleResult` 的构造函数
- **来源：** `lib/shared/widgets/import_bundle_dialog.dart`（约第 112 行）
- **用途：** 构造 `showImportBundleFlow` 返回的不可变结果值。
- **输入：** `importedIds` — 新增或经合并更新的动画 ID；`count` — 导入或合并的记录总数。
- **返回：** 新的 `ImportBundleResult`。
- **副作用：** 无。
- **算法：** 平凡 `const` 字段赋值；无逻辑。
- **用法：**
  ```dart
  return ImportBundleResult(
    importedIds: importedIds,
    count: totalImported,
  );
  ```
  （来自 `showImportBundleFlow`，同一文件）
- **备注：** `count` 在每种可设想的调用方中未必等于 `importedIds.length`——本文件中它们总是保持同步（`totalImported = added + mergedCount`，`importedIds` 从同一未跳过集合构建），但类本身不强制该不变量。
