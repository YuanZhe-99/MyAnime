# 分类与推荐

自 1.6.0 起，应用可以按自己固定的分类表为每条记录**分类**。分类按固定顺序来自三处：用户自己的选择、番剧资料库给出的
类型标签，以及——只有前两者都没有结果时——端侧模型。该功能**默认关闭**（设置 › *分类与推荐* › *自动分类*），在所有平台上
都能工作；只有 AI 这一步需要 Android、iOS 或 macOS。

代码见 [`functions/features/anime/models/anime_category.md`](../functions/features/anime/models/anime_category.md)
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
- **加载时修剪。** 分类器用片库的 id 加载它，丢弃已删除记录的条目；下一次保存时写出。
- 写入是原子的（先写 tmp 再重命名），格式化且键已排序，因此未改变的缓存会写出相同的字节。
