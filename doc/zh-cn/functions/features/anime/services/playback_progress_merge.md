# lib/features/anime/services/playback_progress_merge.dart

`playback_progress.json`（1.6.5）的三方合并。它从不产生冲突。条目通过 `mergeKeyedSet` 按键合并，该函数引自
[`../../recommendations/services/recommendation_merge.md`](../../recommendations/services/recommendation_merge.md)。
见 [`../../../../sync.md`](../../../../sync.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `encodePlaybackProgress` | 函数 | B | 按保存时的方式编码存储内容（两空格缩进的美化 JSON）。 |
| [`mergePlaybackProgress`](#mergeplaybackprogress) | 函数 | A | 合并本地、远程和基线内容。 |
| `mergePlaybackProgressJson` | 函数 | B | 为同步引擎合并原始 JSON；无法读取的基线视为不存在。 |

## mergePlaybackProgress

- **算法：** 两侧都存在的条目保留 `updatedAt` 较晚的一条（相同时保留本地）。只在一侧存在的条目，若基线中没有则保留，
  若基线中有则丢弃：另一台设备已看完或清除了该集，因此看完优先于较晚的部分更新。顶层未知键取并集，本地优先；
  保留较高的 `version`。
