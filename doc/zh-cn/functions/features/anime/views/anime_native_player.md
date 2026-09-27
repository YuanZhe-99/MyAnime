# lib/features/anime/views/anime_native_player.dart

观看页与 media_kit 的平台边界。事件不会将凭据写入日志或存储。具体适配器拥有原生资源，并在视频控制器初始化失败时释放解码器。

自 1.6.5 起，该边界还提供时长、播放状态、速率、跳转与速度控制，`buildVideo` 接收应用的控件构建器：media_kit 自带的控件被取代，而其唤醒锁与后台暂停的默认行为保持不变。`AnimeFullscreenHost` 包装 media_kit 基于 context 的全屏辅助函数——在手机上隐藏系统栏并锁定横屏，在桌面上使用原生全屏；context 由一个 `Builder` 提供，因此同一个宿主在 media_kit 的全屏路由内同样可用。

## 声明

| 声明 | 层级 | 用途 |
|---|---|---|
| `AnimeFullscreenHost.isFullscreen` | B | 报告视频是否铺满屏幕 |
| `AnimeFullscreenHost.toggle` | B | 进入或退出全屏 |
| `AnimeFullscreenHost.exit` | B | 处于全屏时退出 |
| `AnimeNativePlayer.errors` | B | 提供解码失败事件，不输出原始错误内容 |
| `AnimeNativePlayer.positions` | B | 提供播放位置 |
| `AnimeNativePlayer.durations` | B | 得知媒体时长后提供该时长 |
| `AnimeNativePlayer.playing` | B | 提供播放/暂停变化 |
| `AnimeNativePlayer.rates` | B | 提供速率变化 |
| `AnimeNativePlayer.position` | B | 当前位置 |
| `AnimeNativePlayer.duration` | B | 当前时长，未知时为零 |
| `AnimeNativePlayer.isPlaying` | B | 是否正在播放 |
| `AnimeNativePlayer.rate` | B | 当前速率 |
| `AnimeNativePlayer.seek` | B | 跳转到某个位置 |
| `AnimeNativePlayer.play` | B | 开始或继续播放 |
| `AnimeNativePlayer.pause` | B | 暂停 |
| `AnimeNativePlayer.playOrPause` | B | 切换播放与暂停 |
| `AnimeNativePlayer.setRate` | B | 改变播放速度 |
| `AnimeNativePlayer.buildVideo` | B | 以应用自己的控件渲染视频 |
| `AnimeNativePlayer.open` | B | 打开临时媒体来源，不自动连播 |
| `AnimeNativePlayer.dispose` | B | 停止播放并释放资源 |
| `_ContextFullscreenHost` | B | 包装绘制控件所在的 build context |
| `_ContextFullscreenHost.isFullscreen` | B | 报告全屏状态 |
| `_ContextFullscreenHost.toggle` | B | 切换全屏 |
| `_ContextFullscreenHost.exit` | B | 退出全屏 |
| `MediaKitAnimePlayer` | B | 按需初始化 media_kit 与视频控制器 |
| `MediaKitAnimePlayer.errors` | B | 转发解码错误事件 |
| `MediaKitAnimePlayer.positions` | B | 转发播放位置 |
| `MediaKitAnimePlayer.durations` | B | 转发时长变化 |
| `MediaKitAnimePlayer.playing` | B | 转发播放/暂停变化 |
| `MediaKitAnimePlayer.rates` | B | 转发速率变化 |
| `MediaKitAnimePlayer.position` | B | 读取当前位置 |
| `MediaKitAnimePlayer.duration` | B | 读取当前时长 |
| `MediaKitAnimePlayer.isPlaying` | B | 读取是否正在播放 |
| `MediaKitAnimePlayer.rate` | B | 读取当前速率 |
| `MediaKitAnimePlayer.seek` | B | 让解码器跳转 |
| `MediaKitAnimePlayer.play` | B | 开始播放 |
| `MediaKitAnimePlayer.pause` | B | 暂停播放 |
| `MediaKitAnimePlayer.playOrPause` | B | 切换播放 |
| `MediaKitAnimePlayer.setRate` | B | 改变播放速度 |
| `MediaKitAnimePlayer.buildVideo` | B | 以应用的控件渲染视频 |
| `MediaKitAnimePlayer.open` | B | 携带临时请求头开始播放 |
| `MediaKitAnimePlayer.dispose` | B | 停止并释放原生播放器 |

`AnimePlayerControlsBuilder` 是一个没有 `/// Purpose:` 注释的 typedef。

## 契约

输入、结果及副作用参见[观看链接行为](../../../../features/watch-url-lookup.md)与源码结构化注释。网络解析支持注入客户端，映射为确定性计算。播放器对象和临时凭据不会被序列化。
