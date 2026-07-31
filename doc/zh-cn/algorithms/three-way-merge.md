# 三方合并引擎

这是对 `lib/shared/services/sync_merge.dart`（共 221 行）中泛型合并引擎的深入探讨。它是 [`../sync.md`](../sync.md) 描述的 WebDAV 同步流程第 4 步背后的算法，同一文件也合并重复检测分组（见 [`../features/duplicate-detection.md`](../features/duplicate-detection.md)）——不过那条路径在 `duplicate_service.dart` 中使用一个不同的、非泛型的合并例程，不是这个引擎。

## 类型

```dart
class RecordConflict<T> {
  final String id;
  final T localRecord;
  final T remoteRecord;
  final String displayName;
}

class RecordMergeResult<T> {
  final List<T> merged;
  final List<RecordConflict<T>> conflicts;
}
```

`RecordConflict<T>` 表示一个双方自基线快照以来都变化、且无法自动解决的记录 ID。`RecordMergeResult<T>` 是整体结果：干净合并的记录列表，外加任何未解决的冲突。

## `mergeRecords<T>()`

```dart
RecordMergeResult<T> mergeRecords<T>({
  required List<T> local,
  required List<T> remote,
  required List<T>? base,
  required String Function(T) getId,
  required DateTime Function(T) getModifiedAt,
  required String Function(T) getDisplayName,
  bool autoResolve = false,
  String Function(T)? serialize,
})
```

这是一个**泛型**引擎——它对 `Anime` 一无所知。它由访问器函数（`getId`、`getModifiedAt`、`getDisplayName`）和一个只用于相同内容检测的可选 `serialize` 函数参数化。

### 算法

1. 为 `local`、`remote` 和 `base` 构建 `id -> record` 映射（base 可能缺失，如首次同步时）。
2. 把 `allIds` 计算为三张映射中任何一张出现的每个 ID 的并集。
3. 对每个 ID，查找 `l`（本地）、`r`（远程）、`b`（基线）并分支：

   - **两侧都存在（`l != null && r != null`）：**
     - **有基线记录（`b != null`，三方情形）：**
       - 计算 `localChanged = getModifiedAt(l).isAfter(getModifiedAt(b))`，`remoteChanged` 同理。
       - **两侧都变化：**
         - **相同内容冲突抑制：** 如果提供了 `serialize` 且 `serialize(l) == serialize(r)`，即使两侧独立提升了 `modifiedAt`，也不当作真正的冲突——本地副本原样保留。这专门处理过期基线（如早前一次失败上传留下）使两侧看起来分歧、而实际记录内容相同的情形。
         - 否则，如果 `autoResolve` 为 true，取 `modifiedAt` 较晚的那条记录（逐记录最后写入者胜出）。
         - 否则，发出一个 `RecordConflict` 让调用方解决。
       - **只有本地变化：** 保留本地。
       - **只有远程变化：** 保留远程。
       - **都没变化：** 保留本地（任意但稳定，因为内容应当相同）。
     - **没有基线记录（`b == null`）：** 这是首次同步，或两侧独立新增了同 ID 的记录。没有"谁变了"的问题可问，引擎只取 `modifiedAt` 较晚者。
   - **只有本地存在（`l != null && r == null`）：**
     - **有基线**且记录曾存在：它被远程删除。如果 `l` 自基线以来变化，本地编辑被当作有意为之并保留（编辑胜过并发的远程删除）。如果本地没变，尊重远程删除，丢弃该记录。
     - **没有基线：** 该记录本地新增，无条件保留。
   - **只有远程存在（`l == null && r != null`）：** 与上面对称——基线记录本地缺失意味着"本地删除"；只有远程侧自基线以来变化才保留，否则丢弃、以本地删除为准。没有基线时，它远程新增，保留。
   - **都不存在（两侧 null，但曾在基线中）：** 该记录两侧都被删除——直接从合并结果中排除。

4. 返回 `RecordMergeResult(merged: merged, conflicts: conflicts)`。

### 删除语义

这个引擎中没有显式的"墓碑"概念——删除纯粹从**相对基线快照的缺席**推断：

- 基线中存在、但一侧缺失的记录，就是该侧的删除。
- 如果*另一*侧在基线快照之后也动过该记录，编辑优先于删除（没有东西会静默丢失给删除竞争）。
- 如果两侧都没有再动它，删除得到尊重。
- 完全不在基线中的记录（即不属于上次同步）总是添加式的——任一侧有它，它都是新的并被纳入，绝不会被当作"已删除"。

## `mergeAnimeData()`——动画专用包装器

```dart
AnimeMergeResult mergeAnimeData(
  String localJson,
  String remoteJson,
  String? baseJson, {
  bool autoResolve = false,
})
```

这是 `sync.md` 第 4 步实际调用的函数。它：

1. 通过 `AnimeData.fromJson` 把 `localJson`/`remoteJson`/`baseJson` 解析成 `AnimeData`。
2. 用以下参数调用上面的泛型 `mergeRecords<Anime>()`：
   - `getId: (a) => a.id`
   - `getModifiedAt: (a) => a.modifiedAt`
   - `getDisplayName: (a) => a.displayTitle`
   - `serialize: (a) => jsonEncode(a.toJson())` — 这正是为动画记录专门驱动相同内容冲突抑制的东西。
3. 让每条合并记录经过 `withPreservedUnknownJson([localCopy, remoteCopy])`，使本应用版本不认识的 `extraJson` 字段在合并中存活（见 [`../data-formats.md`](../data-formats.md)）。
4. 用同样的方式合并本地和远程 `AnimeData` 的顶层 `extraJson`。
5. 把结果包装进 `AnimeMergeResult { merged, conflicts, extraJson }`，它暴露 `hasConflicts` 和一个 `buildResolved(Map<String, Anime> resolutions)` 辅助：调用方解决完每个冲突（把冲突 ID 映射到选中的 `Anime`）后，`buildResolved` 把已解决记录——每一条也都对照本地和远程冲突副本经过 `withPreservedUnknownJson`——追加到干净合并的列表上，产出要强制上传的最终 `AnimeData`（`sync.md` 第 8–9 步）。

这条完整流水线用具体 JSON 走查见 [`../examples/sync-walkthrough.md`](../examples/sync-walkthrough.md)。
