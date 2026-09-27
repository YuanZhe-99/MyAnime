# lib/features/anime/models/playback_progress.dart

`playback_progress.json`（1.6.5）的内容：应用内播放过的每一集一个续播位置，带编号的集以
`<animeId>/<localEpisode>` 为键，特典页面以 `<animeId>/extra/<pageUrl>` 为键。每个类都把未知 JSON 键保留在
`extraJson` 中。该文件是一个独立的同步模块——见
[`../../../app/data_modules.md`](../../../app/data_modules.md) 和
[`../../../../data-formats.md`](../../../../data-formats.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `playbackProgressKey` | 函数 | B | 构建带编号本地集的键。 |
| `playbackProgressExtraKey` | 函数 | B | 构建没有本地编号的特典页面的键。 |
| [`classifyPlayback`](#classifyplayback) | 函数 | A | 按 5% / 95% 阈值对一个位置分类。 |
| `_unknown` | 函数 | B | 收集本构建不认识的 JSON 键。 |
| `PlaybackProgressEntry` | 构造函数 | B | 创建一个续播位置；`updatedAt` 归一化为 UTC。 |
| [`PlaybackProgressEntry.fromJson`](#playbackprogressentryfromjson) | 静态方法 | A | 宽容地读取一个条目。 |
| `PlaybackProgressEntry.toJson` | 方法 | B | 序列化一个条目；省略为 null 的字段。 |
| `PlaybackProgressEntry.position` | getter | B | 以 `Duration` 表示的位置。 |
| `PlaybackProgressEntry.duration` | getter | B | 以 `Duration` 表示的时长。 |
| `PlaybackProgressEntry.fraction` | getter | B | 在本集中播放到的比例，限制在 0–1。 |
| `PlaybackProgressEntry.newerOf` | 方法 | B | 从同一个键的两条记录中选出较晚的一条；相同时保留本地。 |
| `PlaybackProgressData` | 构造函数 | B | 创建存储内容。 |
| [`PlaybackProgressData.fromJson`](#playbackprogressdatafromjson) | 工厂构造函数 | A | 宽容地读取文件；拒绝非对象。 |
| `PlaybackProgressData.toJson` | 方法 | B | 序列化，条目按键排序。 |
| `PlaybackProgressData.latestFor` | 方法 | B | 某条记录最近更新的条目。 |

`playbackMinFraction`（0.05）、`playbackDoneFraction`（0.95）和 `PlaybackProgressRule` 枚举
（`ignore`、`save`、`complete`）没有 `/// Purpose:` 注释。

## classifyPlayback

- **返回：** 时长未知（零或负数）或位置低于 5% 时为 `ignore`；严格超过 95% 时为 `complete`；否则为 `save`。
  恰好 5% 和恰好 95% 都会保存。
- **用法：** 播放器页面与 `PlaybackProgressService.report` 共同采用的唯一规则。

## PlaybackProgressEntry.fromJson

- **返回：** 除非 `positionMs` 和 `durationMs` 都是整数、`durationMs` 为正且 `updatedAt` 可解析，否则返回 null。
  负数位置读作 0。`animeId` 缺失时回退为键中第一个 `/` 之前的部分。

## PlaybackProgressData.fromJson

- **备注：** 输入不是 JSON 对象时抛出 `FormatException`，同步模块的 `validate` 正依赖于此；其中格式错误的条目会被丢弃。
  较新的 `version` 会被保留。
