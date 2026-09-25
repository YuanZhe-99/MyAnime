# 分类与推荐

自 1.6.0 起，应用可以按自己固定的分类表为每条记录**分类**。分类按固定顺序来自三处：用户自己的选择、番剧资料库给出的
类型标签，以及——只有前两者都没有结果时——端侧模型。该功能**默认关闭**（设置 › *分类与推荐* › *自动分类*），在所有平台上
都能工作；只有 AI 这一步需要 Android、iOS 或 macOS。

**推荐**（同样自 1.6.0 起）回答「**从我的片库里**接下来看什么」。它是一个独立的开关（设置 › *分类与推荐* › *推荐*），同样
**默认关闭**，在所有平台上都可用；只有可选的生成理由需要模型。见下方的[推荐](#推荐)。自 1.6.2 起，略过的推荐会进入
**可同步的垃圾箱**，可以查看和恢复；每个详情页还有自己持久保存的**相关推荐**列表，并有自己的垃圾箱——见[垃圾箱](#垃圾箱)和
[详情页的相关推荐](#详情页的相关推荐)。自 1.6.3 起，任何卡片都可以**钉选**，换一批时会保留它（[钉选](#钉选)）；缺失续作卡片
带有小封面和简介（[缺失续作卡片](#缺失续作卡片)）。

分类的代码见 [`functions/features/anime/models/anime_category.md`](../functions/features/anime/models/anime_category.md)
（分类表与类型标签映射）、
[`functions/features/categories/services/category_service.md`](../functions/features/categories/services/category_service.md)
（解析与分类器）、
[`functions/features/ai/services/prompt_templates.md`](../functions/features/ai/services/prompt_templates.md)、
[`functions/features/ai/services/ai_insights_cache.md`](../functions/features/ai/services/ai_insights_cache.md)
和 [`functions/features/anime/views/category_widgets.md`](../functions/features/anime/views/category_widgets.md)。
模型的平台部分见 [`../on-device-ai.md`](../on-device-ai.md)。

## 分类

### 分类表

`anime_category.dart` 中的 `animeCategories`，版本 1（`categoryTaxonomyVersion = 1`）。id 是稳定的：一旦发布就永不
改名或删除。描述为英文，只用于模型提示词；界面显示 ARB 文件中的本地化名称。

| Id | 描述（仅用于提示词） |
|---|---|
| `action` | fights, battles and physical conflict |
| `adventure` | journeys, quests and exploration |
| `comedy` | played mainly for laughs |
| `drama` | serious, emotional character stories |
| `romance` | love stories and relationships |
| `slice_of_life` | everyday life with little overarching plot |
| `fantasy` | magic, mythical creatures, invented worlds |
| `isekai` | a character transported or reborn into another world |
| `sci_fi` | science fiction: technology, space, the future |
| `mecha` | giant robots or piloted machines |
| `mystery` | solving crimes, puzzles or secrets |
| `suspense` | thrillers built on tension |
| `horror` | meant to frighten |
| `psychological` | the inner workings of the mind |
| `supernatural` | ghosts, spirits, youkai or special powers |
| `sports` | athletes, teams and competition |
| `music` | musicians, bands and idols |
| `school` | set mainly at a school |
| `historical` | set in a real historical period |
| `military` | armies, soldiers and war |
| `gourmet` | cooking and food |
| `healing` | iyashikei: calm, soothing and gentle |
| `magical_girl` | girls who transform to fight with magic |

**没有成人或卖肉向分类。** Apple 对 Foundation Models 的可接受使用规则禁止生成此类内容，模型的护栏也会拒绝；
一个模型永远不能分配的分类，只有部分记录才可能拥有。因此 `Ecchi` 这类类型标签不映射到任何分类。

新增 id 会提升 `categoryTaxonomyVersion`。该版本是每个 AI 指纹的一部分，因此新的分类表会让分类重新排队。

### 逐条记录的解析

`resolveCategories` 返回 id 以及产生它们的来源（`CategoryOrigin`）：

1. **用户** — 记录的 `categories` 字段，只要它存在，**即使为空**。
2. **映射** — `externalMeta.genres` 经过一张同义词表，覆盖 AniList 的类型、MyAnimeList 的类型与主题，以及常见的
   bangumi.tv 标签（恋爱 → `romance`、校园 → `school`、日常 → `slice_of_life`、异世界 → `isekai`、机战 → `mecha`、
   治愈 → `healing`、美食 → `gourmet`……）。查找前先归一化标签（小写、去空格和标点、繁体转简体），未知标签被忽略。
   这一步只读取记录本身，因此在 Windows 上、在通过同步收到 `externalMeta` 的商店版中都能工作。
3. **AI** — 状态为 `ok` 的缓存分类结果，只用于前两者都没有结果的记录。

AI 建议的分类标签带一个闪光图标和提示「在本设备上生成——可能有误」。

### `categories` 字段

`Anime.categories` 是 `anime_data.json` 中的一个 id 字符串 JSON 列表：

| 存储值 | 含义 |
|---|---|
| 没有该键 | 自动：映射，否则 AI |
| `["romance", "school"]` | 用户自己的分类；它胜出 |
| `[]` | 用户认定该记录**没有**分类；同样胜出 |

这是唯一一个空值有意义的字段，因此它是**「为空即省略」的例外**：`[]` 会被写出并同步，因为丢掉它会在每台设备上
悄悄把「无」变回自动。本构建不认识的 id 会被保留并写回，但不显示。不是字符串列表的值原样保留在 `extraJson` 中。
该字段不是个人数据：它会同步、会备份，也保留在分享文件中。见 [`../data-formats.md`](../data-formats.md)。

### 编辑

自动分类开启时，详情页在操作行下方显示分类标签，末尾是一个*编辑分类*图标按钮（1.6.2 及之前是带文字的标签）。它打开一个由 `FilterChip` 组成的面板——
在窗口可以分栏时改为对话框（[`../adaptive-layout.md`](../adaptive-layout.md)）。编辑器从当前生效的 id 开始，因此保存
会把它们写成用户自己的列表。**保存是一次用户编辑**：以 UTC 写入 `modifiedAt`，记录经普通的整条记录合并同步。
*恢复自动*（仅当记录有自己的列表时显示）会移除该键。本构建不认识的 id 在保存后仍然保留。

### 在管理页筛选

自动分类开启时，管理标签的应用栏在本地存档筛选旁多出一个分类筛选。它的行为相同：**仅是视图状态**，从不持久化，
作用于季度页、「其他」和搜索结果，并与每条记录生效的分类（自己的、映射的或 AI 的）比对。见
[`home-management-statistics.md`](home-management-statistics.md)。

### AI 分类

只针对没有用户列表、也没有映射分类的记录，并且只在自动分类和端侧 AI 都开启、且模型可以生成时进行。

- **输入：** 只有作品本身——至多五个已知标题、形式、年份、长度类型（`AnimeType`）、集数、制作公司和原始类型标签。
  **从不包含备注、从不包含评分**，也从不包含观看进度。
- **提示词：** `prompt_templates.dart` 中带版本的模板（`classificationPromptVersion = 1`），指令为英文：从列表中至多选
  三个 id，只使用给出的事实，不确定时回答 `NONE`。修改措辞就要提升版本。
- **输出：** Dart 只保留已知 id，去重、按分类表顺序、至多三个。
- **批大小 1：** 每个提示词一条记录，直到在设备上测得延迟。
- **时机：** 每次前台会话**至多 20 条记录**的细流，在应用加载设置时、每次回到前台时、开启自动分类时以及开启端侧 AI
  之后启动；另有设置中的*立即分类*，它为所有待分类记录分类，并显示「还有 N / M 部待分类」计数。
- **指纹：** 输入、分类表版本、提示词版本和模型身份（例如 `stable/full · nano-v3`，或 `apple`）的 SHA-256。
  只要指纹变化——新的类型标签或标题、新的分类表或提示词、模型更新——记录就会重新排队。
- **状态：** `ok`（选出了 id）、`none`（模型回答 NONE）或 `skipped`（护栏或不支持的语言拒绝了请求）。三者在指纹
  变化之前都不会重试。其他任何失败都会停止这一轮，把该记录留到下次。

结果只写入缓存；分类器从不写记录。

### 缓存：`ai_insights.json`

由 `AiInsightsCache` 拥有，位于 `AnimeStorage.getAppDir()` 之下：

```json
{
  "version": 1,
  "categories": {
    "<animeId>": {
      "fingerprint": "<sha256 of the inputs, taxonomy version, prompt version and model identity>",
      "ids": ["romance", "school"],
      "status": "ok",
      "model": "stable/full · nano-v3",
      "generatedAt": "2026-10-01T12:00:00.000Z"
    }
  },
  "hiddenRecommendations": []
}
```

- **仅限本设备。** 它没有注册进 `lib/app/data_modules.dart`，因此**既不同步也不备份**，写入也从不通知自动同步。
  更改存储路径时它仍会一起迁移。
- **可重建。** 加载是容错的：格式错误的条目被丢弃，无法读取的文件读作空。
- **加载时修剪。** 分类器和推荐页用片库的 id 加载它，丢弃已删除记录的条目——分类和隐藏 id 都是；下一次保存时写出。
- 写入是原子的（先写 tmp 再重命名），格式化且键已排序，因此未改变的缓存会写出相同的字节。
- `hiddenRecommendations` 在 1.6.0 和 1.6.1 中是*不感兴趣*列表，当时隐藏仅限本设备。自 1.6.2 起垃圾箱存放在可同步的
  `recommendations.json` 中（[垃圾箱](#垃圾箱)）；推荐页或垃圾箱页第一次打开时，这里的 id 会移到那里，并清空此列表。
  该键仍会被读取和写入（为空），因此文件的结构不变。

## 推荐

代码见
[`functions/features/recommendations/services/recommendation_service.md`](../functions/features/recommendations/services/recommendation_service.md)
（排序）、
[`functions/features/recommendations/services/recommendation_store.md`](../functions/features/recommendations/services/recommendation_store.md)、
[`functions/features/recommendations/models/recommendation_data.md`](../functions/features/recommendations/models/recommendation_data.md)
和
[`functions/features/recommendations/services/recommendation_merge.md`](../functions/features/recommendations/services/recommendation_merge.md)
（垃圾箱与相关推荐列表，1.6.2）、
[`functions/features/recommendations/services/reason_prompt.md`](../functions/features/recommendations/services/reason_prompt.md)、
[`functions/features/recommendations/services/ai_reason_service.md`](../functions/features/recommendations/services/ai_reason_service.md)
（AI 理由）、
[`functions/features/recommendations/services/sequel_info_service.md`](../functions/features/recommendations/services/sequel_info_service.md)
（缺失续作的封面与简介，1.6.3）、
[`functions/features/recommendations/views/recommendations_page.md`](../functions/features/recommendations/views/recommendations_page.md)、
[`functions/features/recommendations/views/recommendation_trash_page.md`](../functions/features/recommendations/views/recommendation_trash_page.md)
和
[`functions/features/recommendations/views/related_card.md`](../functions/features/recommendations/views/related_card.md)。

### 范围

只限片库。候选是用户自己未开始、或观看中且有已播出未看集数的记录。**从不要求模型说出作品名**：小型端侧模型并不可靠地
知道有哪些作品，它编出来的任何东西都会是死胡同。两个与片库相邻的来源是事实而非猜测，因此在范围内：系列的下一个成员
（[`series-linking.md`](series-linking.md)），以及来自资料库关联关系的缺失续作。

### 确定性排序

纯 Dart，不涉及模型。无论*自动分类*是否开启，排序都使用每条记录的有效分类（用户自己的、映射的或缓存的 AI 分类）。

- **偏好**（每条记录）：有评分时为 `(effectiveOverall − 6) / 4`，钳制到 −1…1；没有评分时，已看完 `+0.5`，弃坑 `−0.7`，
  其他 `0`。
- **口味画像：** 以偏好加权的分类向量之和，再归一化。**制作公司亲和度：** 每个制作公司的偏好之和。
- **候选：** 未开始，或观看中且有已播出未看的集，并且不在垃圾箱中。**一个系列只有最早的未看完成员才是候选**——没看完第 1 季
  的人绝不会被推荐第 3 季。如果该成员不满足条件（弃坑，或观看中但已追平），该系列就不提供候选。
- **得分：** 各项贡献之和，权重来自 `RecommendationWeights`：

| 贡献 | 权重 |
|---|---|
| 系列的上一个成员已看完 | `3.0`，其评分为 8 或更高时 `+1.0` |
| 口味画像与候选分类的余弦 | `× 2.0` |
| 最高的制作公司亲和度，钳制到 −1…1 | `× 0.5` |
| 外部平均分减 7，钳制到 ±2 | `× 0.3` |
| 观看中且有已播出未看的集 | `0.8` |
| 正在播出 | `0.4` |

- **冷启动**（全库既无评分也无已看完记录）：先是系列接续，再按外部评分，再按最近添加。
- **推荐理由标签：** 取最大的正向贡献，至多三个——「《…》的下一部」、「与你评分高的作品相似：恋爱、校园」（至多两个
  分类）、「与《…》同一制作公司」、「AniList 8.9」（单个最高的来源）以及「有新的集数待补」。正在播出只加分，没有标签。

### AI 理由（可选）

只在端侧 AI 开启且模型能够生成时。没有任何东西等待模型：确定性列表和标签立即渲染，应用栏下显示一条细进度条，理由
到达时再填入。

- **输入：** 排名前 **8** 的候选，带编号，含标题、分类、制作公司和「下一部」事实，以及一份**精简画像**——按偏好排名前三的分类和
  制作公司，以及最近修改的三部已看完作品及其评分。从不包含备注，从不包含逐集记录。
- **提示词：** `reason_prompt.dart`（`reasonPromptVersion = 1`），指令用英文，要求以界面语言写作。模型**按编号至多挑三个**，
  为每个写一句不超过 20 个词的理由，写成 `<number>: <reason>` 行。它作为交互式请求运行，排在任何后台分类之前。
- **校验：** 去掉 Markdown；只接受已知编号，不重复；至多 **140** 个字符；文字系统检查（`zh`、`zh_TW` 和 `ja` 以 CJK 为主，
  `ja` 还需含假名；`en` 以拉丁字母为主）。任何无效内容都被丢弃，卡片保留其标签。
- **中文变体：** 文字系统正确但属于另一种中文变体的回复会用 `chinese_convert.dart` 转换，而不是丢弃。
- **Apple：** 当 `supportsLocale` 拒绝繁体中文时，改为请求简体再转换；当它拒绝其他任何界面语言时，跳过 AI 理由。若尚不知道界面语言区域的答复（本次会话还没打开过设置），推荐页会先带上该语言区域向系统询问一次，再作判断。
- **仅在内存中：** 理由只保存于一次访问该页面期间，从不写入磁盘。

每条 AI 理由都位于「在本设备上生成——可能有误」标签之下。

### 页面

- **入口：** 首页应用栏上、列数按钮旁的一个操作，只在推荐开启时显示。它压栈 `/recommendations`
  （[`home-management-statistics.md`](home-management-statistics.md)）。
- **布局：** 一列卡片——封面、标题、推荐理由标签、有 AI 理由时附带标注的理由——用 `listColumnCount` 按**首页的列数偏好**
  排布；本页没有自己的列数按钮（[`../adaptive-layout.md`](../adaptive-layout.md)）。点击打开详情页。
- **一批：** 至多 **10** 张排好的卡片（1.6.1 及之前为 30 张），之后是缺失续作卡片。
- ***不感兴趣***把一张卡片移入[垃圾箱](#垃圾箱)。1.6.1 及之前它写入仅限本设备的 `ai_insights.json`，且无法撤销；自 1.6.2
  起它会同步，并且可以恢复。
- **钉选**（1.6.3，位于*不感兴趣*旁）让卡片在换一批时保留；见[钉选](#钉选)。
- **换一批**（应用栏）：屏幕上的整批卡片——排好的卡片和缺失续作卡片——一次写入全部移入垃圾箱，然后显示下一批。提示条
  「已将 N 项移入垃圾箱」提供**撤销**，恰好恢复这一批。这一含义是有意的：用户看过并略过的一批就是「不感兴趣」。自 1.6.3 起，钉选的卡片不计入这一批；
  屏幕上的每张卡片都已钉选时，该按钮禁用。
- **垃圾箱**（应用栏）打开全局垃圾箱页。
- **缺失续作：** 在排好的卡片之后，对资料库列出但片库中没有的每部续作显示一张卡片——针对每条已看完且是所在系列最后一部的
  记录——标注为**「番剧库里还没有」**。点击打开以该关联关系预填的创建页（搜索只在完整版中运行）。自 1.6.2 起每张也有
  *不感兴趣*，并且卡片按续作的规范键（`anilist:<id>`、`mal:<id>`、`bgm:<id>`）去重，因此在两个 bangumi 域名下列出的同一部
  续作只显示一张卡片。这些来自完整版抓取的关联数据，因此商店版只对通过同步收到这些数据的记录显示它们。自 1.6.3 起它们显示封面缩略图和简介；
  见[缺失续作卡片](#缺失续作卡片)。
- 同步改变本地数据时页面会重新加载，因此另一台设备上对垃圾箱的改动无需离开页面即可显示。

### 钉选

自 1.6.3 起，「接下来看什么」上的每张卡片——片库卡片和缺失续作卡片都一样——以及详情页相关推荐卡片中的每一行都有一个
钉选开关（`push_pin`）。钉选回答的是「看别的时先把这个留着」：

- **钉选的卡片在换一批后保留。** 换一批只把未钉选的卡片移入垃圾箱；钉选的卡片留下，排在最前。在全局页面上，钉选的片库卡片
  按排序顺序排在最前，并计入 10 张一批的数量；钉选的缺失续作卡片排在续作卡片的最前。
- **钉选与垃圾箱互斥。** 钉选一张已移入垃圾箱的卡片会恢复它；对钉选的卡片点*不感兴趣*（或 ✕）会取消钉选。取消钉选后，
  卡片留在原处，直到下一次换一批。
- **钉选不保证显示。** 钉选的片库记录一旦不再是候选——已看完、弃坑，或不再是所在系列最早的未看完成员——就不显示，而它的
  钉选留在文件中，像已删除记录的垃圾箱条目一样无害。
- **钉选会同步。** 它们与垃圾箱一起存放在 `recommendations.json` 中：全局钉选、钉选的续作键，以及每条记录自己的相关推荐
  钉选。当一台设备在两次同步之间钉选了一张卡片，而另一台设备换一批把它移走时，**钉选胜出**。

### 缺失续作卡片

1.6.2 及之前，「番剧库里还没有」卡片只显示「下一部：<标题>（<来源>）」。自 1.6.3 起，它的布局与片库卡片相同：续作封面的
**缩略图**、标题、「番剧库里还没有」标签，以及至多三行**简介**。详情页的缺失续作提示显示同样的缩略图和简介。

- **来源。** 完整版按 id 从续作所在的资料库——AniList、MyAnimeList 或 bangumi.tv，经详情页所用的同一按 URL 刷新——抓取
  续作页面，并下载其封面。一次一张卡片，每张卡片一次；抓取失败会在下次启动时重试。商店版从不抓取；它显示完整版抓取的内容，
  因为结果会同步。
- **有意做小。** 封面缩小为 112 px 宽的 JPEG（几 KB，上限 24 KB），以 base64 存放在 `recommendations.json` 中；简介经过
  清理，上限 600 个字符。简介使用资料库撰写时的语言。
- **移入垃圾箱即删除。** 对续作卡片点*不感兴趣*或换一批，会删除其缩略图和简介；垃圾箱只保留标题、资料库和它所接续的记录。
  续作不再缺失（已加入片库）或不再被列出时，其资料同样会被删除。
- **为什么不用 `images/`。** 封面文件按增量同步，从不在远端删除，因此缩略图文件会在每台设备上比它已移入垃圾箱的卡片存留更久。
  JSON 文件中的字段则会随下一次同步在各处消失。

## 垃圾箱

自 1.6.2 起有两种推荐垃圾箱，都存放在可同步的 `recommendations.json` 中：

| 垃圾箱 | 放入什么 | 隐藏什么 | 在哪里查看 |
|---|---|---|---|
| **全局** | 在「接下来看什么」上略过的片库卡片和缺失续作卡片 | 「接下来看什么」上的这些卡片 | 该页上的垃圾箱按钮（`/recommendations/trash`） |
| **每部作品** | 在某条记录的相关推荐卡片中略过的条目 | 只在**该记录的**相关推荐卡片中隐藏这些条目 | 该卡片菜单中的*垃圾箱*（`/recommendations/trash?anime=<id>`） |

两者相互独立：从一部番剧的相关推荐列表中移入垃圾箱的记录，不会在「接下来看什么」或其他任何记录的列表中被隐藏，反之亦然。

**垃圾箱页**按时间从新到旧列出移入垃圾箱的记录——封面、标题、「<日期> 移入」和**恢复**——对于全局垃圾箱，还有一个
「番剧库里还没有的续作」分区，列出每部移入垃圾箱的续作的标题、资料库以及它所接续的记录。移入垃圾箱的续作不再有缩略图
或简介（1.6.3）；恢复后，完整版会重新抓取它们。*全部恢复*恢复所显示的全部内容。
**恢复会把条目从垃圾箱中移除，因此它可以再次被推荐**——这就是这里「从垃圾箱删除」的含义。恢复的相关推荐条目不会被放回
已保存的列表；它可能在该卡片下一次换一批时回来。

**已删除记录的条目**留在文件中，只是不显示。修剪它们会以恢复的形式进入同步，并可能移除另一台设备上针对本设备尚未收到的
记录的条目；番剧 id 是 UUID，从不复用，因此残留的条目无害。

**迁移。** 在 1.6.2 上第一次打开推荐页或垃圾箱页时，`ai_insights.json` 中 `hiddenRecommendations` 的 id 会移入全局垃圾箱
（时间戳记为该时刻，因为旧列表没有保存日期），并清空旧列表。每台设备迁移自己的列表，合并时取并集。

### 文件：`recommendations.json`

由 `RecommendationStore` 拥有，位于 `AnimeStorage.getAppDir()` 之下，作为第二个模块注册在
`lib/app/data_modules.dart` 中（模块 id `recommendations`）：

```json
{
  "version": 1,
  "hidden": [
    { "id": "<animeId>", "hiddenAt": "2026-09-24T03:00:00.000Z" }
  ],
  "hiddenSequels": [
    {
      "key": "anilist:182255",
      "sourceId": "<animeId>",
      "title": "葬送のフリーレン 第2期",
      "source": "AniList",
      "hiddenAt": "2026-09-24T03:00:00.000Z"
    }
  ],
  "related": {
    "<animeId>": {
      "generatedAt": "2026-09-24T03:00:00.000Z",
      "items": [
        {
          "id": "<animeId>",
          "reasons": ["categories:romance,school", "studio:Madhouse"],
          "aiReason": "Both follow a slow-burn school romance."
        }
      ],
      "hidden": [{ "id": "<animeId>", "hiddenAt": "2026-09-24T03:00:00.000Z" }],
      "pinned": [{ "id": "<animeId>", "pinnedAt": "2026-09-25T03:00:00.000Z" }]
    }
  },
  "pinned": [
    { "id": "<animeId>", "pinnedAt": "2026-09-25T03:00:00.000Z" }
  ],
  "pinnedSequels": [
    { "key": "anilist:182255", "pinnedAt": "2026-09-25T03:00:00.000Z" }
  ],
  "sequelInfo": {
    "anilist:182255": {
      "synopsis": "Following the First-Class Mage Exam, the trio…",
      "coverUrl": "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/…",
      "coverThumb": "<base64 JPEG, 112 px wide>",
      "fetchedAt": "2026-09-25T03:00:00.000Z"
    }
  }
}
```

三个顶层键和每条记录的 `pinned` 是 1.6.3 新增的，**只在非空时写出**，因此从未用过它们的文件保持 1.6.2 写出的字节。
1.6.2 构建通过 `extraJson` 保留它们，只是不据此行事。

- **同步并备份。** 它和 `anime_data.json` 一样随 WebDAV 同步、备份和 ZIP 导出传输。保存会通知自动同步。它**不**属于
  `.myanimeitem` 分享文件。
- **需要时才创建。** 从未把任何东西移入垃圾箱、也从未打开过相关推荐卡片的片库没有该文件，同步只发出一次什么也找不到的 GET。
- **未知键在每一层都保留**（`extraJson`），因此旧构建会保留新构建新增的内容。本构建不认识的理由代码会被保留但不显示。
- **排序并格式化**，因此未改变的存储会写出相同的字节，同步走原始相等的快速路径。
- **合并从不冲突**——见 [`../sync.md`](../sync.md#推荐文件)。

## 详情页的相关推荐

自 1.6.2 起，推荐开启时，每个详情页在备注之后都有一张**相关推荐**卡片（双栏布局中位于右栏）：至多 **5** 条与该记录相似、
**来自片库**的记录。代码见
[`RecommendationService.related`](../functions/features/recommendations/services/recommendation_service.md#recommendationservice-related)
和 [`related_card.md`](../functions/features/recommendations/views/related_card.md)。

### 排序

纯 Dart。主体记录、它自己所在系列的成员以及该记录自己的垃圾箱中的条目从不提供。

| 贡献 | 权重 |
|---|---|
| 资料库把其中一条列为另一条的关联作品，任一方向，任何关联类型 | `3.0` |
| 两条记录有效分类集合的余弦，`shared / √(a·b)` | `× 2.0` |
| 两者有相同的制作公司 | `0.5` |
| 两者有相同的基础标题键（与系列关联使用的键相同） | `1.0` |

没有任何贡献的记录不提供。**其他每个系列至多提供其最佳成员**（得分相同时取系列顺序中较早的一个），因此列表永远不会是同一
部作品的三季。观看状态不起作用：该卡片回答「什么与它相似」，而不是「接下来看什么」。推荐理由标签：「同为恋爱、校园」、
「同为 Madhouse 制作」、「衍生作品」/「不同版本」/「数据库中的关联作品」、「标题相近」——至多三个，从大到小。

### 持久保存，直到换一批

- **第一次**显示某条记录的卡片时，生成列表并写入 `recommendations.json`，附带 UTC `generatedAt`。此后卡片显示**已保存的**
  列表——在本设备上，并通过同步在其他每台设备上——直到用户换一批。片库中新增的记录本身不会改变已有的列表。
- **AI 理由**（只在端侧 AI 开启且模型能够生成时）在生成之后立即请求，隐私规则与全局页面相同——标题、分类、制作公司和
  关联关系事实；从不包含备注、评分或观看历史——通过 `relatedReasonPrompt`（`relatedReasonPromptVersion = 1`）。模型从编号的
  候选中至多挑三个。与全局页面的理由不同，它们**随列表一起保存**，位于同样的「在本设备上生成——可能有误」标签之下。
- **换一批**（卡片的换一批按钮，或其菜单中的*换一批*）把屏幕上的每个条目放入**该记录的垃圾箱**，然后生成接下来的五条。
  屏幕上没有条目时不移入任何东西，只是重新生成——新增的记录就是这样进入列表的。自 1.6.3 起，钉选的行不会移入垃圾箱：
  它们带着已保存的理由留在最前，只有剩下的位置参与排序。
- 某一行上的 **✕** 把该条目移入垃圾箱（并取消钉选）；列表会缩短，直到下一次换一批。
- 某一行上的**钉选**（1.6.3）让它在换一批时保留；见[钉选](#钉选)。
- 菜单中的**垃圾箱**打开该记录自己的垃圾箱。
- 从片库中删除的记录会从每个列表中消失，无需写入。
- 如果两台设备在两次同步之间生成了同一记录的列表，较新的 `generatedAt` 胜出；垃圾箱按集合合并，因此略过的条目不会回来。
