# 多源搜索

`anime_search_service.dart` 搜索或抓取多个来源，**仅在完整版构建中可用** —— 见下方的 flavor 门禁一节，
以及 [`../architecture.md`](../architecture.md) 中的 `full`/`store` flavor 划分。

## 来源

- `bangumi.tv` —— v0 搜索 API（`POST /v0/search/subjects`）。
- MyAnimeList —— 通过 Jikan v4。
- AniList —— GraphQL API。
- `acgsecrets.hk` —— 季度页面的 JSON-LD。
- `filmarks.com` —— HTML 抓取。
- `anime1.me` —— 专门用于查找观看链接（不参与通用元数据搜索）。

每个来源最多查询 `_maxPerSource`（10）条结果。

### 1.4.0 之前有两个来源已经静默失效

两者都是在 1.4.0 验证期间实际调用真实 API 时发现的，而且从未报出过任何错误——因为每个来源方法都把失败
当作空结果处理，好让单个来源失效不至于拖垮整个搜索。这种容错本身是对的，但它同时意味着**某个来源可以
在无人察觉的情况下消失。**

- **bangumi.tv** 从首个版本到 1.3.3 一直使用旧版 `GET /search/subject/<query>` 端点。它现在对每个请求
  都返回 Cloudflare 的 `502 Bad gateway`——搜索与按 id 查询皆然。已迁移到仍然可用的 v0 API，且后者返回
  的内容严格更多（见下）。
- **filmarks.com** 把详情 URL 从 `/anime/<id>` 改成了 `/animes/<series>/<season>`，并改为客户端渲染
  结果。自 v0.1.0 未变的 `/anime/` 模式什么都匹配不到。已针对当前标记重写。

若某个来源开始返回空结果，先怀疑来源本身，而不是查询。

## 各来源提供哪些字段

只有 `sourceUrl` 和至少一个标题是有保证的，其余一切取决于来源：

| 字段 | bangumi.tv | MyAnimeList | AniList | acgsecrets.hk | filmarks.com |
|---|---|---|---|---|---|
| `title` / `titleJa` | ✅ | ✅ | ✅ | ✅ | 仅标题 |
| `titleRomaji` / `titleEn` | — | ✅ | ✅ | — | — |
| `synonyms` | ✅ (`infobox`) | ✅ | ✅ | ✅ | — |
| `episodes` | ✅ | ✅ | ✅ | 有则提供 | — |
| `firstAirDate` | ✅ | ✅ | ✅ | ✅ | — |
| `endDate` | ✅ (`infobox`) | ✅ | ✅ | — | — |
| `airDayOfWeek` | ✅（`infobox`） | ✅ | ✅ | — | — |
| `airTime` | — | ✅（仅限日本时间） | ✅ | — | — |
| `format` / `status` | — | ✅ | ✅ | — | — |
| `durationMinutes` | — | ✅ | ✅ | — | — |
| `genres` / `studios` | ✅ (tags + `infobox`) | ✅ | ✅ | — | — |
| `score` / `votes` / `rank` | ✅ | ✅ | ✅（无 rank） | — | — |
| `coverImageUrl` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `summary` | ✅ | ✅ | ✅ | — | — |

有三处排期细节值得特别说明，因为弄错会静默地把每一集的排期都算错：

- **AniList 的放送时间来自真实的放送排期表。** 优先使用 `nextAiringEpisode.airingAt`（正在放送的作品的
  实时时段），没有时回退到第一条 `airingSchedule` 节点，这样已完结作品也能拿到真实时段。Unix 时间戳会
  被转换为日本时间（UTC+9），再拆成星期与 `HH:mm`。只有当 AniList 完全没有排期表时，星期才回退到
  `startDate.weekday` —— 而 1.4.0 之前的代码一直只用这条回退路径。
- **深夜时段归入前一天，写成 `25:00` 形式。** 日本编成惯例把 **04:00** 之前的一切都算作前一晚的深夜档，
  而本应用的 `airTime` 本就支持超过午夜的小时数（见 [`../data-formats.md`](../data-formats.md) 中关于
  `airTime` 的说明）。因此周四 01:00 放送的作品存为周三 `25:00`，而不是周四 `01:00`。

  这一点之所以关键，是因为 **`getEpisodeCalendarDate()` 完全不读 `airTime`** —— 它只用
  `firstAirDate` + `airDayOfWeek` 来定位某一集。若报告原始的钟表星期，每一集深夜番都会比它所属的
  编成日晚一天。所以星期与首播日期必须**一起**平移：只挪星期会让两个字段互相矛盾，向前对齐反而会把
  第 1 集整整推迟一周。

  `_alignFirstAirDateToSlot` 只在来源自身的首播日期落在钟表日时才平移 —— AniList 与 MyAnimeList 都是
  这样记录的 —— 因此已经按编成日记录的来源会被原样保留，不会被二次平移。
- **Jikan 的 `broadcast.time` 只在 `broadcast.timezone` 为 `Asia/Tokyo` 时才被采信。** 其他时区一律丢弃，
  而不是当作日本时间存下来。

`bangumi.tv` 的 v0 API 把放送日表述为 `infobox.放送星期` 中的**自由文本**（`星期五`、`週六`、`金曜日` 等），因此
`parseBangumiWeekday` 同时接受简体、繁体与日文形式，其余一律返回 `null`（如 `不定期`），而不是据此排出错误的时间。

## 两阶段跨语言检索

`searchAll(query, {preferredLanguage})` 分**两轮**执行，两轮内部都对各来源完全并行。

**第一轮 —— 按源做语言定向。** 每个来源收到的是它索引得最好的那个查询变体，而不是原始字符串：

| 来源 | 收到 |
|---|---|
| bangumi.tv | 简体变体 |
| acgsecrets.hk | 繁体变体 |
| filmarks.com | 原始查询，带 `Accept-Language: ja` |
| MyAnimeList、AniList | 原始查询（两者都索引全部语言） |

这取代了旧版中「查询含繁体字时额外再查一次 bangumi.tv」的特判。

**第二轮 —— 跨语言补搜。** 从第一轮中相关度不低于 `_backfillMinRelevance`（0.45）的命中里，服务最多收集
三个标题：一个含假名的日文标题、一个罗马音/英文标题，以及一个中文标题（含汉字、不含假名）。随后它
**只对零结果的来源**重新发起查询，每个来源收到对应语言的那个标题。这正是让中文查询能够触达只索引日文
标题的 `filmarks.com` 的机制。

护栏：当每个来源在第一轮都已有结果，或没有任何标题达到相关度阈值时，第二轮被整段跳过。它绝不递归 ——
额外的轮次恰好只有一轮，因此最坏情况下延迟约翻倍。

结果随后按 `sourceUrl`（缺失时回退到标题）去重，并按相关度降序排序。

**不跨源合并同一部作品。** 同一部番剧同时以 AniList 和 bangumi.tv 的身份各出现一次是刻意为之：用户需要
自己选择从哪个来源取元数据，合并会剥夺这个选择。

## 相关度评分

`relevance(result, queryVariants)` 会把一条结果已知的每个标题 —— `title`、`titleJa`、`titleRomaji`、
`titleEn` 以及每个 `synonym` —— 与每个查询变体逐一比对，取最高分。它复用了给 `anime1.me` 观看链接命中
排序的那套模糊评分器（`_similarity`：LCS-Dice、字符集 Dice、包含关系，且每项都在原始形式与繁体归一化
形式上各算一遍），因此简体查询对纯繁体标题依然能得高分。

`queryVariants(query)` 是公开的，这样搜索对话框可以用与服务实际检索时完全相同的变体集合来评分，而不必
自己再推导一遍。

## 结果界面

搜索对话框（`anime_search_dialog.dart`）为合并后的列表提供：

- **排序** —— 相关度（默认）、首播日期、集数或来源。缺少排序依据值的结果一律沉到底部，而不是按 0 参与排序。
- **过滤** —— 底部面板中提供多选来源 chip，以及「仅显示有封面的结果」「仅显示有播出日期的结果」两个开关。
  只有实际返回了结果的来源才会出现。
- **按来源分组** —— 在平铺列表与每个来源一个可折叠分区之间切换。
- **长按查看完整信息** —— 列表行的标题被截断为一行；长按会打开一个面板，其中每个已知名称都是可选中、可
  复制的文本，并附上全部已抓取的元数据。桌面端还额外提供列出各名称的悬停提示。

应用结果时会写入用户勾选的每个字段。外部元数据（制作公司、类型标签、作品形式、播出状态、时长、别名以及
该来源的评分）由单个复选框控制，产生一条 `AnimeExternalMeta` 记录，并折叠进此前其他来源已贡献的内容。

## 刷新已保存的元数据

`fetchByUrl(url)` 按 id 从来源页面 URL 重新抓取一部番剧：

| URL | 端点 |
|---|---|
| `anilist.co/anime/<id>` | GraphQL `Media(id:)`，字段选择集与搜索相同 |
| `myanimelist.net/anime/<id>` | `api.jikan.moe/v4/anime/<id>/full` |
| `bgm.tv` / `bangumi.tv` / `chii.in` 的 `/subject/<id>` | `api.bgm.tv/v0/subjects/<id>`（复数路径） |

其余一律返回 `null`。`acgsecrets.hk` 与 `filmarks.com` 是抓取而非按 id 查询，没有稳定的按 URL 端点，因此
被跳过。每个 API 的响应都走**与搜索路径完全相同**的映射函数，因此搜索与刷新绝不会产生偏差。

`refreshAll(urls)` 并行抓取多个 URL，单个失败会被跳过而不是让整批失败。

详情页（`anime_detail_page.dart`）以「刷新资料库信息」动作 chip 暴露该能力。它收集 `infoUrl` 加上每一条
`externalMeta.ratings[].sourceUrl`，通过 `AnimeExternalMeta.mergedWith` 把每条抓取结果合并进已有记录后
保存。**只有外部元数据会被改动** —— 用户自己的评分、观看进度与手动编辑保持原样。

## Flavor 门禁

`AnimeSearchService` 自身**不**执行 flavor 门禁 —— 它是共享工具类。每个能被 store 构建触达的调用点都必须
显式门禁：

- `anime_edit_page.dart` 把搜索动作放在 `AppFlavor.isFull` 之后，因此在线番剧搜索对面向商店的界面
  （`store` flavor：Google Play / App Store 构建）保持隐藏。
- `anime_detail_page.dart` 出于同样原因把「刷新资料库信息」chip 放在 `AppFlavor.isFull` 之后。外部元数据
  *卡片*本身不做门禁 —— 展示已经同步过来的数据不属于网络功能。
- 桌面本地 API 服务器（`local_api_server.dart`，见
  [`../platform-notes.md`](../platform-notes.md)）可以直接调用 `AnimeSearchService.searchAll()`，因为它是
  仅限桌面的功能，而桌面构建以 `full` flavor 发布，不属于商店/移动端场景。

来源发生变化时，请让 `PRIVACY_POLICY.md` 中的公开数据源行为保持同步。
