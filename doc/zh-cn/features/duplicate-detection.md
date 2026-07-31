# 重复检测与合并

`duplicate_service.dart` 为动画记录提供重复检测和合并逻辑。它在两处复用：专门的"检查重复"设置页，以及 `.myanimeitem` 捆绑的导入冲突解决（见 [`share-and-import.md`](share-and-import.md)）。

## 分组算法

重复检测按以下任一条件分组记录：

- 相同 `id`。
- 相同的非空 `infoUrl` 或 `watchUrl`。
- 相同的规范化标题 + 季 + `firstAirDate`。

分组**传递性**地使用并查集结构形成：如果 A 匹配 B 且 B 匹配 C（即使 A 不直接匹配 C），三者都在同一组。每条动画至多出现在一组中。

## 合并优先级规则

把重复组合并为一条记录时：

- **主**记录的 `id` 被保留，主记录的字段赢得任何冲突。
- 主记录上缺失的字段从后备（非主）记录补全。
- 剧集状态逐集合并，优先级 **watched > skipped > unwatched**——即任何重复条目把某集标记为已看，合并结果就保持它已看，即使另一个重复条目把它标为未看。
- 主记录缺失值的地方，评分子分从后备记录补全（见 [`../data-formats.md`](../data-formats.md) 中的 `AnimeRating`）。
- 备注拼接（互相不去重）。
- 未知 JSON 字段通过 `extraJson` 模式保留（见 [`../data-formats.md`](../data-formats.md)），与应用中每个其他合并路径相同。

## UI 入口

- 设置有一个**"检查重复"**入口，打开一个列出每个重复组（带保留/合并/删除选项）的专门页面。
- 导入冲突解决复用同一检测来决定传入的 `.myanimeitem` 记录是否与既有本地记录冲突，并为每个冲突显示带保留本地/使用导入/合并选项的对话框——见 [`share-and-import.md`](share-and-import.md)。

注意：这是**本地、一次性**的合并操作，与 WebDAV 同步的逐记录三方合并不同（见 [`../algorithms/three-way-merge.md`](../algorithms/three-way-merge.md)）——重复合并把两个 ID 不同的*不同*记录合并为一个，而同步合并调和同一条记录的 `id` 跨两台设备的一致性。
