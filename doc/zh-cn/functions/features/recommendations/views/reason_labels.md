# lib/features/recommendations/views/reason_labels.dart

为推荐理由标签生成文字的唯一位置（1.6.2）。详情页的相关推荐卡片也开始显示理由标签后，它从
`RecommendationsPage._reasonLabel` 移到了这里。
见 [`recommendations_page.md`](recommendations_page.md) 和 [`related_card.md`](related_card.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`reasonLabel`](#reasonlabel) | 顶层函数 | A | 为一个推荐理由标签生成文字。 |

## 文档

### `String reasonLabel(RecommendationReason reason, AppLocalizations l10n)` <a id="reasonlabel"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/recommendations/views/reason_labels.dart`（约第 13 行）
- **用途：** 为一个理由标签生成文字。
- **输入：** `reason`、`l10n`。
- **返回：** `String`。
- **副作用：** 无。
- **算法：**

| 理由 | 标签 |
|---|---|
| `NextAfterReason` | `reasonNextAfter(title)` |
| `CategoryMatchReason` | 把 id 经 `categoryLabel` 转换后以逗号连接，交给 `reasonLikeCategories` |
| `SameStudioReason` | `reasonSameStudio(title)` |
| `ExternalScoreReason` | `<source> <保留一位小数的分数>`，不做本地化 |
| `CatchUpReason` | `reasonCatchUp` |
| `SharedCategoriesReason` | `reasonSharedCategories`（「同为恋爱、校园」） |
| `SharedStudioReason` | `reasonSharedStudio(studio)`（「同为 Madhouse 制作」） |
| `RelatedByDatabaseReason` | 衍生作品用 `seriesSuggestionSpinOff`，不同版本用 `seriesSuggestionAlternative`，其他用 `reasonRelatedByDatabase` |
| `SharedTitleReason` | `reasonSharedTitle`（「标题相近」） |

- **用法：** `RecommendationsPage._card`、`RelatedRecommendationsCard._row`。
- **备注：** 该 `switch` 对 sealed 类是穷尽的，因此新的理由类型不可能在没有标签的情况下发布。
