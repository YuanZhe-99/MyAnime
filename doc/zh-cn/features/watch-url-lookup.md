# 观看链接查找（anime1.me）

`anime1_service.dart` 为一条记录找到 anime1.me 的系列页面，并读取该站点已经更新到第几集。**仅在完整版构建中
可用** —— 见下方的 flavor 门禁一节，以及 [`../architecture.md`](../architecture.md) 中的 `full`/`store` flavor
划分。1.5.7 新增；1.5.6 之前它以 `searchAnime1` 的形式住在 `anime_search_service.dart` 里。

## 搜索端点是用错了工具

anime1.me 是一个 WordPress 站点。它的 `?s=` 搜索**只匹配繁体的精确子串**：简体标题（`孤独摇滚`）、日文标题
（`ぼっち・ざ・ろっく`）、英文标题，或者与台译不同的大陆译名（`间谍过家家` 对 `SPY×FAMILY間諜家家酒`），
统统一无所获。1.5.6 之前代码用最多六次串行、每次十秒超时的请求来弥补——原始查询加上每个标题的两种字形变体——
然后再用两字子串去猜。

这个站点同时把整个片库当作一个文件提供：`GET https://anime1.me/animelist.json`（约 135 KB）就是首页表格所
渲染的数组，按最近更新排在最前，每部作品一行：

```json
[1134, "孤獨搖滾！", "1-12", "2022", "秋", "動漫國"]
[1935, "GRAND BLUE 碧藍之海 第三季", "連載中(09)", "2026", "夏", ""]
[1644, "劇場總集篇 孤獨搖滾！Re:Re:", "劇場版", "2024", "夏", "千夏"]
```

各单元格依次是分类 id、标题、集数文本、年份、季节、字幕组。系列页面是 `https://anime1.me/?cat=<id>`，站点会
以 301 跳转到可读的 `/category/…` slug。有了这张索引，匹配就变成本地问题，而集数单元格顺带提供了「更新至第
N 集」。

## 索引优先的查找

`Anime1Service.search(query, altQueries:, firstAirDate:, seasonText:)` 依次跑三个阶段，在第一个产出结果的阶段
停下：

1. **索引。** `loadIndex()` 每 30 分钟最多拉取一次 `animelist.json`（并发调用共享同一个请求；刷新失败时继续
   提供旧副本，只有从未成功过时才抛错）。`rank()` 给每一行打分，保留达到 `minScore` 的行。
2. **别名补采。** 当没有任何行达到 `confidentScore`（0.9）、且替代查询里没有一个已经是中文时，
   `AnimeSearchService.harvestAliases` 把标题发给 bangumi.tv 一次，收集相关度达到补搜阈值（0.45）的命中里的
   中文与拉丁字母标题。bangumi.tv 的别名字段通常把台译和大陆译名并列。索引用并集重新排序——不会再向
   anime1.me 发请求——新出现或得分提高的行标记为 `viaAliases`，对话框据此显示一行说明。
3. **抓取。** 只有索引加载失败或一无所获时，才走旧的 `?s=` 路径（`_scrapeSearch`）：原始标题、其字形变体和
   替代查询，最多六次请求，然后是二字子串重试。抓取命中不带集数与季节数据。

替代查询是记录的日文标题，加上 `externalMeta` 知道的一切——`titleEn`、`titleRomaji` 与每一个别名——因为
站点即使中文部分完全不同，也会保留拉丁字母的系列名（`SPY×FAMILY`、`GRAND BLUE`）。

## 在归一化的简体键上匹配

`AnimeSearchService.foldTitle` 把全角 ASCII 变半角、转小写、去掉空白与所有 Unicode 标点和符号
（`！？・:：、「」【】《》～×`），再转成简体。查询与每个索引标题各归一化一次，现有评分器在归一化后的这一对
上运行。

**规范侧是简体，不是繁体。** 繁转简是多对一（乾与幹都变成干；髮与發都变成发），因此两种地区写法总能相遇。
另一个方向是一对多，而 1.5.7 之前的评分器恰恰按那个方向归一化——`toTraditional('弄干净')` 给出 `弄幹淨`，
永远等不上站点的 `弄乾淨`。归一化同样会映射日文汉字（滅 → 灭），所以 `鬼滅の刃` 能够到 `鬼滅之刃`。

转换表本身是问题的另一半：一份约 1,200 对的手打列表，缺 干/乾/幹、髮、裏、臺、徵、迴 以及数百个其他字。
它们现在由 OpenCC 的字符字典生成——见
[`../functions/shared/utils/chinese_convert.md`](../functions/shared/utils/chinese_convert.md)。

## 排序

一行的基础分是其归一化标题对每个归一化查询的最佳 `similarityRaw`（LCS-Dice、字符集 Dice、包含关系）。随后是
两道门槛和三项调整：

| 规则 | 值 | 原因 |
|---|---|---|
| `minScore` | 0.5 | 包含关系把任何「同一系列 ± 副标题」的组合托底在 0.7；0.5 高于 0.45 的补搜阈值，因为 1,900 个候选让误命中在十行列表里一目了然。 |
| `minOrderedScore` | 0.4 | 基于集合的 Dice 项对顺序视而不见，在短拉丁串上 `bocchitherock` 与 `tomjerry` 有一半字母相同。顺序敏感的分数（LCS-Dice 或包含关系）也必须过这道线。 |
| `seasonBoost` | +0.10 | 同系列的兄弟行（`X`、`X 第二季`、`X 第三季`）在包含关系上至多差 ~0.04，因此按记录首播季度加分能分出它们，又不会把部分命中抬到精确命中之上。 |
| `adjacentSeasonBoost` | +0.03 | 给首播日期差几周、或站点把作品归到相邻一季的情形兜底。 |
| `ordinalBoost` / `ordinalMismatchPenalty` | +0.10 / −0.05 | 从记录标题或季度标签里读出的 第N季 / Season N / Nth Season / S2 / Part 2 序数，与行的序数一致——或不一致。没有序数的行就是第一季，因此要找续作的记录不能与标题精确相同的基础行打平。 |

平分保持文件顺序，即最近更新在前。结果最多十条。

**首播季度会向前贴靠。** `Anime.season` 是自由文本的序列标签，从来不是放送季度，因此加分以 `firstAirDate` 为
准。anime1 把 9 月 29 日首播的作品归入秋季，而日历上它属于第三季度；`quarterIndexFor` 因此把落在一个季度最后
一个月 21 日及之后的首播移到下一季度，12 月 21 日及之后则进入下一年的冬季。

## 集数文本

`parseEpisodes` 把站点的单元格读成种类加数字，先命中的规则优先：

| 单元格 | 种类 | 读作 |
|---|---|---|
| `連載中(09)`、`連載中(3 EP4)` | ongoing | `latest` = 开头的整数；其余保留为 `extras` |
| `1-12`、`13-24`、`1-12.5` | range | `first`、`last`、`latest = last`；`.5` 丢弃 |
| `1-12+OVA`、`1-13+SP1-2`、`1-12+劇場版` | range | 同上，后缀原样保存在 `extras` 中 |
| `1` | range | 只有一集 |
| `劇場版` | movie | |
| `特別編` | special | |
| `OVA`、`SP`、`ONA` 及其他 | other | 原样显示 |

`anime1_labels.dart` 把它们变成「更新至第 9 集」「第 1-12+OVA 集」「剧场版」等；年份与季节复用日历的季节名。

## 持久化的进度

选择一条结果保存的不只是 URL。`Anime1Match.toProgress` 变成 `AnimeExternalMeta.watchProgress`——一条
`AnimeWatchProgress` 记录，保存它所读取的 URL、分类 id、最新一集、原始集数文本、连载中标志与 UTC 的
`checkedAt`——见 [`../data-formats.md`](../data-formats.md)。它住在 `externalMeta` 里，因为它正是那一类数据：
别人的公开信息的缓存，经 `AnimeStorage.patchExternalMeta` 写入，因此**绝不修改 `modifiedAt`**
（[`metadata-auto-update.md`](metadata-auto-update.md) 里承重的那条规则）。

`Anime.validWatchProgress` 只在记录的 `sourceUrl` 等于当前 `watchUrl` 时返回它。手工改了 URL 会把过期的集数
隐藏到下一次检查为止，而不是给一个 URL 已不再指向的作品显示第 9 集。

显示位置：

- **详情页**的标签读作 `anime1：更新至第 9 集`（没有有效存储时读作「查看 anime1 更新」）；点按它会重新读取站
  点并经 `patchExternalMeta` 写回。标签在每个 flavor 下都渲染已存数据；只有点按是完整版动作；
- **首页**在站点已列出该集时把该集所在行的观看按钮变成主色，并把进度作为提示；
- **管理页**在行的副标题后追加 `更新至 9`；
- 桌面端**本地 API** 报告 `watchLatestEpisode` 与 `watchProgressCheckedAt`。

## 后台刷新

`MetadataUpdateService` 在刷新与探索之间多了第三步。一次索引下载覆盖库中每一个 anime1.me 的 URL，因此整个到
期集合在一个 tick 内处理完：

| | 窗口 |
|---|---|
| 从未读取，或为另一个 URL 读取 | 立即到期 |
| 站点显示仍在更新（`連載中`） | 6 小时 |
| 站点显示已完结 | 7 天 |
| 记录已全部看完且站点显示已完结 | 永不——没有什么可以再学到 |

`?cat=` URL 从索引解析，不发请求。1.5.7 之前的 `/category/…` 链接需要抓取页面（body class 里带
`category-<id>`，此后优先用索引行）；这类抓取每个 tick 最多三次，间隔两秒。单集帖子的 URL
（`https://anime1.me/19159`）会顺着它的分类链接跟进一次。失败会设置一小时的**内存中**重试间隔，刻意与条目退避
分开，这样观看站点一次抖动永远不会拖延该作品的元数据刷新。手动「检查更新」先跑同一批处理，不计入进度条所
统计的队列。两条路径都天然处于现有的生命周期、网络策略与离线门禁之后。

## Flavor 门禁

`Anime1Service` 自身不检查 flavor，与 `AnimeSearchService` 一致。编辑页的搜索图标与详情页标签的点按都以
`AppFlavor.isFull` 门禁；显示已存记录则不受门禁，理由与外部元数据卡片相同。后台调用方只在 `AppFlavor.isFull`
下由 `main.dart` 启动。

保持 [`../../../PRIVACY_POLICY.md`](../data-formats.md) 与应用内隐私政策同步：自 1.5.7 起后台更新也会访问
anime1.me，发送的只有已保存的页面地址。
