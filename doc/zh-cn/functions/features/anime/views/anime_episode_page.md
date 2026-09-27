# lib/features/anime/views/anime_episode_page.dart

完整版共用观看入口与校正页。读取最新记录、刷新目录、预览绑定来源的手动选择，并仅打开明确的页面链接。预览与选择器显示页面地址，以区分同标题的候选页面。保存前重读存储并拒绝已变更的来源。

自 1.6.5 起本页遵循全应用的分栏规则：在 `useDetailTwoPane` 允许时，对应表单位于宽度为 `detailLeftPaneWidth` 的左栏，正片与特典在右栏按至少 `episodeTileMinWidth` 的列宽分列；否则为单列滚动。本页被推到外壳之外，量的是整个窗口。每一集显示其同步的续播位置（一条进度条和「续播 m:ss」），播放器接收记录 id 与本地集数，自动首次播放会先续播最近停止的未看集，再退而选择第一个未看集。见[自适应布局](../../../../adaptive-layout.md)。

## 声明

| 声明 | 层级 | 用途 |
|---|---|---|
| `openAnimeWatch` | B | 共用观看入口；其他来源和 store 沿用外部打开 |
| `AnimeEpisodeLinksPage` | B | 创建分集对应页 |
| `createState` | B | 创建界面状态 |
| `initState` | B | 完整版初始化目录并尝试播放目标集 |
| `dispose` | B | 释放编辑控制器 |
| `_choices` | B | 构造尚未保存的手动对应预览 |
| `_load` | B | 刷新目录与播放进度、核对来源并重读最新存储，不覆盖用户字段 |
| `_firstUnwatched` | B | 选择首个未看未跳过的本地集，不跨过缺失链接 |
| `_continueTarget` | B | 选择播放停止时间最近、已对应且未看的一集（1.6.5） |
| `_save` | B | 对最新记录保存校正，来源变化则拒绝 |
| `_choose` | B | 选择某本地集的明确页面或清除覆盖 |
| `_play` | B | 携带记录 id 与本地集数在播放器中打开一集，返回后重新加载进度 |
| `_buildStatusChildren` | B | 来源已变更与目录加载失败的提示行（1.6.5） |
| `_buildMappingChildren` | B | 季数对应表单（1.6.5） |
| `_buildResume` | B | 一个已存位置的续播进度条与文字（1.6.5） |
| `_buildEpisodeTile` | B | 一个本地集的卡片，含其续播位置（1.6.5） |
| `_buildSpecialTile` | B | 一个特典页面的卡片，含其续播位置（1.6.5） |
| `_buildEpisodeChildren` | B | 按列排布的正片与特典（1.6.5） |
| `build` | B | 单列，或在窗口允许分栏时显示双栏 |

## 契约

输入、结果及副作用参见[观看链接行为](../../../../features/watch-url-lookup.md)与源码结构化注释。网络解析支持注入客户端，映射为确定性计算。播放器对象和临时凭据不会被序列化。
