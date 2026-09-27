# lib/features/anime/views/anime_native_player.dart

观看页与 media_kit 的平台边界。事件不会将凭据写入日志或观看历史。具体适配器拥有原生资源及自适应控制界面，并在视频控制器初始化失败时释放解码器。

## 声明

| 声明 | 层级 | 用途 |
|---|---|---|
| `AnimeNativePlayer.errors` | B | 提供解码失败事件，不输出原始错误内容 |
| `AnimeNativePlayer.positions` | B | 提供播放位置以取消启动超时 |
| `AnimeNativePlayer.buildVideo` | B | 渲染视频与控制界面 |
| `AnimeNativePlayer.open` | B | 打开临时媒体来源，不自动连播 |
| `AnimeNativePlayer.dispose` | B | 停止播放并释放资源 |
| `MediaKitAnimePlayer` | B | 按需初始化 media_kit 与视频控制器 |
| `MediaKitAnimePlayer.errors` | B | 转发解码错误事件 |
| `MediaKitAnimePlayer.positions` | B | 转发播放位置 |
| `MediaKitAnimePlayer.buildVideo` | B | 渲染拖动、音量、倍速和全屏控制 |
| `MediaKitAnimePlayer.open` | B | 携带临时请求头开始播放 |
| `MediaKitAnimePlayer.dispose` | B | 停止并释放原生播放器 |

## 契约

输入、结果及副作用参见[观看链接行为](../../../../features/watch-url-lookup.md)与源码结构化注释。网络解析支持注入客户端，映射为确定性计算。播放器对象和临时凭据不会被序列化。
