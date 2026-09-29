# lib/features/anime/services/playback_progress_service.dart

`PlaybackProgressService`（1.6.5）执行播放进度的规则。见
[`../../../../features/watch-url-lookup.md`](../../../../features/watch-url-lookup.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `PlaybackProgressService._` | 构造函数 | B | 禁止实例化。 |
| `keyFor` | 静态方法 | B | 带编号集的键；`episode` 为 null 时为特典页面的键。 |
| [`report`](#report) | 静态方法 | A | 记录一个播放位置。 |
| `_tryStore` | 静态方法 | B | 执行一次续播点写入并吞掉其失败，使播放和 `markWatched` 继续进行（1.6.7）。 |
| [`markWatched`](#markwatched) | 静态方法 | A | 把一个本地集标记为已看。 |
| `resumePoint` | 静态方法 | B | 返回某个键已存的条目。 |

## report

- **算法：** `classifyPlayback`。`ignore` 不改动存储，因此在一集开头附近短暂重新打开它，绝不会抹掉原来停止的位置。
  `save` 以当前时间（UTC）作为 `updatedAt` 写入条目。`complete` 删除条目，对带编号的集还会调用 `markWatched`。
- **返回：** 所采用的规则。

## markWatched

- **副作用：** 重写 `anime_data.json`，设置 `episodeStatuses[episode] = watched` 并写入新的 `modifiedAt`，
  与首页已看开关的写入相同——这是一次可见的状态变更，不同于经 `patchExternalMeta` 的缓存写入。
- **备注：** 记录已不存在或该集已看时不执行任何操作，返回 false。

## 1.6.7 变更

`markWatched` 现在在 `AnimeStorage.updateRecord` 内、依据刚读出的存储记录做决定，因此不会再覆盖播放器打开期间所做的编辑；集数已看过或记录不存在时仍不写入。`report` 把对 `PlaybackProgressStore` 的调用包进 `_tryStore`：`playback_progress.json` 无法读取时存储会拒绝写入，而看完的集数仍会被标为已看。
