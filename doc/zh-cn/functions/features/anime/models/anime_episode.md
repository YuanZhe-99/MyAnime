# lib/features/anime/models/anime_episode.dart

公开分集目录快照与用户拥有、绑定来源的校正。JSON 保留未知字段和小数标签。

## 声明

| 声明 | 层级 | 用途 |
|---|---|---|
| `episodeJsonMap` | B | 将可选 JSON 对象转换为字符串键映射；无效容器视为缺失 |
| `AnimeEpisodePage` | B | 保存真实分集页面，保留特别篇标签 |
| `number` | B | 仅将正整数标签解释为正片集数 |
| `AnimeEpisodePage.toJson` | B | 序列化页面并保留未知字段 |
| `AnimeEpisodePage.fromJson` | B | 读取目录中的单集页面 |
| `AnimeEpisodeCatalog` | B | 保存公开目录快照，分页完整不等于没有缺集 |
| `AnimeEpisodeCatalog.preservingUnknownFrom` | B | 同来源刷新时保留目录及相同页面的未知字段 |
| `AnimeEpisodeCatalog.toJson` | B | 序列化目录及 UTC 时间戳 |
| `AnimeEpisodeCatalog.fromJson` | B | 读取目录快照，缺少时间戳立即过期 |
| `AnimeEpisodeMapping` | B | 保存用户确认的季范围、起点及逐集覆盖 |
| `AnimeEpisodeMapping.toJson` | B | 序列化用户校正，空覆盖值表示明确不对应 |
| `AnimeEpisodeMapping.fromJson` | B | 读取校正并保留未知外层字段 |

## 契约

输入、结果及副作用参见[观看链接行为](../../../../features/watch-url-lookup.md)与源码结构化注释。网络解析支持注入客户端，映射为确定性计算。播放器对象和临时凭据不会被序列化。
