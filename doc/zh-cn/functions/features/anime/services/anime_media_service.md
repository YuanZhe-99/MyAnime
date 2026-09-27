# lib/features/anime/services/anime_media_service.dart

仅用于会话的原生媒体解析器。读取公开视频 data-apireq，并作为表单数据原样发送到网站使用的 API。API Cookie 限定于匹配的 HTTPS 视频主机，所有失败返回 null 以回退网页。

## 声明

| 声明 | 层级 | 用途 |
|---|---|---|
| `AnimeMediaSource` | B | 仅在内存携带临时媒体来源及请求凭据 |
| `parseSource` | B | 校验 API 媒体来源，并按视频主机限定 Cookie |
| `resolve` | B | 按网站公开播放流程解析媒体；失败返回 null |

## 契约

输入、结果及副作用参见[观看链接行为](../../../../features/watch-url-lookup.md)与源码结构化注释。网络解析支持注入客户端，映射为确定性计算。播放器对象和临时凭据不会被序列化。
