# 分类与推荐

自 1.6.0 起，应用可以按自己固定的分类表为每条记录**分类**。分类按固定顺序来自三处：用户自己的选择、番剧资料库给出的
类型标签，以及——只有前两者都没有结果时——端侧模型。该功能**默认关闭**（设置 › *分类与推荐* › *自动分类*），在所有平台上
都能工作；只有 AI 这一步需要 Android、iOS 或 macOS。

**推荐**（同样自 1.6.0 起）回答「**从我的片库里**接下来看什么」。它是一个独立的开关（设置 › *分类与推荐* › *推荐*），同样
**默认关闭**，在所有平台上都可用；只有可选的生成理由需要模型。见下方的[推荐](#推荐)。

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

自动分类开启时，详情页在头部标签下方显示分类标签，并带一个*编辑分类*标签。它打开一个由 `FilterChip` 组成的面板——
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
- `hiddenRecommendations` 是*不感兴趣*列表（见[推荐](#推荐)）。由于该文件仅限本设备，在一台设备上隐藏的推荐不会在另一台
  设备上隐藏。

## 推荐

代码见
[`functions/features/recommendations/services/recommendation_service.md`](../functions/features/recommendations/services/recommendation_service.md)
（排序）、
[`functions/features/recommendations/services/reason_prompt.md`](../functions/features/recommendations/services/reason_prompt.md)、
[`functions/features/recommendations/services/ai_reason_service.md`](../functions/features/recommendations/services/ai_reason_service.md)
（AI 理由）和
[`functions/features/recommendations/views/recommendations_page.md`](../functions/features/recommendations/views/recommendations_page.md)。

### 范围

只限片库。候选是用户自己未开始、或观看中且有已播出未看集数的记录。**从不要求模型说出作品名**：小型端侧模型并不可靠地
知道有哪些作品，它编出来的任何东西都会是死胡同。两个与片库相邻的来源是事实而非猜测，因此在范围内：系列的下一个成员
（[`series-linking.md`](series-linking.md)），以及来自资料库关联关系的缺失续作。

### 确定性排序

纯 Dart，不涉及模型。无论*自动分类*是否开启，排序都使用每条记录的有效分类（用户自己的、映射的或缓存的 AI 分类）。

- **偏好**（每条记录）：有评分时为 `(effectiveOverall − 6) / 4`，钳制到 −1…1；没有评分时，已看完 `+0.5`，弃坑 `−0.7`，
  其他 `0`。
- **口味画像：** 以偏好加权的分类向量之和，再归一化。**制作公司亲和度：** 每个制作公司的偏好之和。
- **候选：** 未开始，或观看中且有已播出未看的集，并且未被隐藏。**一个系列只有最早的未看完成员才是候选**——没看完第 1 季
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
- ***不感兴趣***隐藏一个候选。其 id 写入 `ai_insights.json` 的 `hiddenRecommendations`，因此**隐藏仅限本设备**：既不同步
  也不备份，除了删除该记录之外没有撤销的界面。
- **缺失续作：** 在排好的卡片之后，对资料库列出但片库中没有的每部续作显示一张卡片——针对每条已看完且是所在系列最后一部的
  记录——标注为**「番剧库里还没有」**。点击打开以该关联关系预填的创建页（搜索只在完整版中运行）。这些来自完整版抓取的关联
  数据，因此商店版只对通过同步收到这些数据的记录显示它们。
