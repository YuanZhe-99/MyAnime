# lib/shared/utils/playback_time.dart

播放器控件与分集页续播文字共用的一个格式化函数（1.6.5）。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `formatPlaybackClock` | 函数 | B | 不足一小时时把位置格式化为 `m:ss`，一小时起为 `h:mm:ss`；负数读作 `0:00`。 |
