# lib/shared/services/sync_merge.dart

**拆分文件。** 泛型三方记录合并——`mergeRecords<T>`、`RecordConflict<T>` 和 `RecordMergeResult<T>`——移入 `myapps_data` 包（`lib/src/merge/sync_merge.dart`）并在这里再导出，使每个既有导入继续编译。动画专用包装器保留。

包签名是 MyDevice 的超集：它多一个可选 `mergeUnknownFields` 回调。MyAnime 不传它——未知字段保留通过 `withPreservedUnknownJson` 内建在模型中——因此这里的行为与抽取前相同。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`AnimeMergeResult`](#animemergeresult) | 类 | A | 合并列表、冲突和保留的顶层未知 JSON。 |
| [`hasConflicts`](#animemergeresult) | getter | A | 是否需要手动解决。 |
| [`buildResolved(resolutions)`](#buildresolved) | 方法 | A | 应用用户选择并产出最终 `AnimeData`。 |
| [`mergeAnimeData(...)`](#mergeanimedata) | 函数 | A | 本地/远程/基线动画 JSON 的三方合并。 |
| `RecordConflict<T>` / `RecordMergeResult<T>` / `mergeRecords<T>` | 再导出 | A | 泛型引擎，来自该包。 |

## 文档

### `class AnimeMergeResult` <a id="animemergeresult"></a>
- **字段：** `merged`（`List<Anime>`）、`conflicts`（`List<RecordConflict<Anime>>`）、`extraJson`（跨合并保留的未知顶层字段）。
- **getter：** `hasConflicts` — 是否有任何记录需要手动解决。
- **备注：** 作为不透明 `state` 穿过同步引擎，这正是冲突对话框仍能收到真实 `Anime` 记录的方式。

### `buildResolved(resolutions)` <a id="buildresolved"></a>
- **输入：** `resolutions` 把动画 ID 映射到选中的 `Anime`。
- **返回：** `AnimeData`。
- **备注：** 缺失的选择回退本地记录。胜出记录与两侧经 `withPreservedUnknownJson` 重新合并，使未知字段在解决中存活。

### `mergeAnimeData(localJson, remoteJson, baseJson, {autoResolve})` <a id="mergeanimedata"></a>
- **返回：** `AnimeMergeResult`。
- **备注：** 把逐记录决策委托给共享的 `mergeRecords`，传 `serialize`，使序列化内容相同的两侧不产生冲突。删除语义、相同内容抑制和无基线最后写入者胜出规则现在都在包中，由它的测试套件覆盖。

## 泛型引擎文档的位置

`packages/myapps_data/doc/en-us/functions/src/merge/sync_merge.md`。
