# lib/features/anime/models/anime_category.dart

本应用自己的分类表（1.6.0，M4）：`categoryTaxonomyVersion`、`AnimeCategory` 类、const 的 `animeCategories` 列表
（v1，23 个 id，每个带一行只用于模型提示词的英文描述）、`animeCategoryIds` 集合，以及 `mapGenresToCategories`
背后的类型标签同义词表。本地化名称在 ARB 文件中，通过 [`categoryLabel`](../views/category_widgets.md#categorylabel)
读取。见
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md)。

id 是稳定的：一旦发布就永不改名或删除，因为它们存储在 `Anime.categories` 和 `ai_insights.json` 中。新增 id 会提升
`categoryTaxonomyVersion`，它是每次 AI 分类指纹的一部分，因此会让分类重新排队。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `AnimeCategory.new` | 构造函数（`AnimeCategory`） | B | 创建一个分类；只有 `animeCategories` 会构造它们。 |
| [`mapGenresToCategories`](#mapgenrestocategories) | 顶层函数 | A | 把来源的类型标签映射为分类 id。 |

`categoryTaxonomyVersion`、`animeCategories`、`animeCategoryIds`、`_genreSynonyms` 和 `_foldedSynonyms` 是没有
`/// Purpose:` 注释的常量或值，不作为行。

## 文档

### `List<String> mapGenresToCategories(Iterable<String> genres)` <a id="mapgenrestocategories"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/anime/models/anime_category.dart`（约第 153 行）
- **用途：** 把来源的类型标签映射为分类 id。
- **输入：** `genres` — 存储中的 `externalMeta.genres`。
- **返回：** `List<String>` — 按分类表顺序排列、去重的分类 id；没有可映射的时为空。
- **副作用：** 无。
- **算法：** 用 `AnimeSearchService.foldTitle` 归一化每个标签（小写、去空格和标点、繁体转简体），在
  `_foldedSynonyms`（以同样方式建键、只构建一次的同义词表）中查找。把命中收集进集合，再按 `animeCategories`
  的顺序返回。
- **用法：** [`resolveCategories`](../../categories/services/category_service.md#resolvecategories)（「映射」一步）、
  `needsClassification` 和 `CategoryClassifier.refreshCounts`。
- **备注：** 该表覆盖 AniList 的类型、MyAnimeList 的类型与主题，以及常见的 bangumi.tv 标签（恋爱 → `romance`、
  校园 → `school`、异世界 → `isekai`、治愈 → `healing`……）。没有合适分类的标签（例如 `Ecchi`）不在表中，因此被忽略。
  它只读取记录上已有的数据，因此在所有平台（包括 Windows）上都能工作，在通过同步收到 `externalMeta` 的商店版中也能工作。
