# lib/features/anime/services/anime_episode_service.dart

纯季识别计算与有界分页抓取。存储目录和校正是输入，缺集不使后续链接前移。

## 声明

| 声明 | 层级 | 用途 |
|---|---|---|
| `AnimeEpisodeResolution` | B | 返回本季对应结果及不确定状态 |
| `ensure` | B | 合并并发目录请求，按刷新窗口或人工请求更新 |
| `_refresh` | B | 抓取目录并校验来源后更新缓存 |
| `isPageUrl` | B | 仅接受 Anime1 的 HTTPS 页面地址 |
| `catalogFor` | B | 仅返回绑定当前观看来源的目录 |
| `getPage` | B | 有界获取页面并拒绝离开站点的重定向 |
| `parsePage` | B | 解析文章链接、分类和旧页导航，排除侧栏 |
| `fetch` | B | 遍历合集，失败、循环或预算耗尽时保留不完整状态 |
| `_sameTitle` | B | 折叠文字与标点比较完整标题，不移除季编号 |
| `resolve` | B | 先确定本季和真实起点，再对应各集并保留缺口 |

## 契约

输入、结果及副作用参见[观看链接行为](../../../../features/watch-url-lookup.md)与源码结构化注释。网络解析支持注入客户端，映射为确定性计算。播放器对象和临时凭据不会被序列化。

`ensure` 的调用方：详情页进入时（不强制，因此适用 6 小时／168 小时窗口），以及自 1.6.6 起详情页站点进度行的重新检查（`force: true`），因为对应后的文案来自这份目录。自 1.6.6 起，`resolve` 除本地别名外，也用合集在 Anime1 上自己的名称（`catalog.indexTitle`、`catalog.title`）匹配分组；季序号、未标季不能当续作、必须恰好一个候选这几道防护不变，同一链接上另一条不同季的记录共享这些名称，因此会让未标季的分组保持待确认。见 [watch-url-lookup.md](../../../../features/watch-url-lookup.md) 与 `test/anime_episode_test.dart`。
