# lib/features/profile/services/profile_merge.dart

`profile.json`（1.7.0）的合并。它从不产生冲突：名称和头像各自独立合并，都保留时间戳较晚的一侧，也不需要基线。见 [`../../../../sync.md`](../../../../sync.md#个人资料文件) 和 [`../../../app/data_modules.md`](../../../app/data_modules.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`encodeProfile`](#encodeprofile) | 函数 | A | 按 `ProfileStore` 写入的方式编码个人资料（两空格缩进的美化 JSON）。 |
| `_remoteWins` | 函数 | B | 某个字段的远程一侧是否严格更新。 |
| [`mergeProfile`](#mergeprofile) | 函数 | A | 合并本地与远程个人资料，按字段后写者胜。 |
| `mergeProfileJson` | 函数 | B | 为同步引擎合并原始 JSON；任一侧不是 JSON 对象时抛出。 |

## encodeProfile

- **返回：** `ProfileData.toJson()` 经 `JsonEncoder.withIndent('  ')` 的输出。
- **备注：** 对相同数据，合并输出与本地保存必须字节一致，否则未变化的文件会错过原始相等快速路径，每次同步都重新上传。

## mergeProfile

- **算法：** 仅当远程时间戳严格更晚时 `_remoteWins(local, remote)` 才为真；相同时保留本地，从未设置该字段（时间戳为 null）的一侧总是输给设置过的一侧。名称（`displayName` + `displayNameUpdatedAt`）和头像（`avatar` + `avatarUpdatedAt`）独立判定，因此一台设备改了名称、另一台设备改了头像，两者都会保留。顶层未知键取并集，本地优先；保留较高的 `version`。
- **备注：** 不需要基线：移除是带时间戳的显式 `null`，而不是缺失的键，因此“这里移除了”与“这里从未设置”不会混淆。`mergeProfileJson` 就是 `buildProfileModule` 交给引擎的那个函数；`baseJson` 和 `autoResolve` 被忽略。
