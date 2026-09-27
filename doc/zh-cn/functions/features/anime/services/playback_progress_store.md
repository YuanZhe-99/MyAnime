# lib/features/anime/services/playback_progress_store.dart

`PlaybackProgressStore`（1.6.5）负责 `AnimeStorage.getAppDir()` 下的 `playback_progress.json`。它照搬推荐存储的模式：
读取-修改-写入队列、原子写入、字节未变时不写入、从不写出空文件，并在每次实际写入后调用
`AutoSyncService.notifySaved`。见 [`../../../app/data_modules.md`](../../../app/data_modules.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `PlaybackProgressStore._` | 构造函数 | B | 禁止实例化。 |
| `_file` | 静态方法 | B | 解析应用目录下的该文件。 |
| [`load`](#load) | 静态方法 | A | 加载存储；不存在或无法读取时为空。 |
| `update` | 静态方法 | B | 应用一个排队的更改并保存。 |
| `_apply` | 静态方法 | B | 执行一个排队的更新。 |
| `put` | 静态方法 | B | 保存或替换一个续播位置，保留旧条目的未知键。 |
| `remove` | 静态方法 | B | 删除一个续播位置。 |

`fileName`（`playback_progress.json`，有测试把它钉定为 `playbackProgressFileName`）和队列
`_tail` 没有 `/// Purpose:` 注释。

## load

- **备注：** 已不存在的记录的条目会被保留。在这里清理会被同步视为一次有意的删除，并可能删除另一台设备上
  本设备尚未收到的记录的条目。
