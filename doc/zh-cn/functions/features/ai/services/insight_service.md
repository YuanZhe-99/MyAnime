# lib/features/ai/services/insight_service.dart

统计页洞察卡片的存储（1.9.1，移植自 MyDevice!!!!!）：`AiInsightRequest`（事实、语言、时间、可选的不含标题的 `fallbackFacts`）、`insightFingerprint`（视图、提示词版本、语言、日期、模型、规范化事实），以及 `AiInsightStore`——基于 MyApps-AI `AiInsightCoordinator` 的薄封装，缓存在 [`ai_insight_cards.json`](ai_insight_cards_cache.md) 中。模型标识来自 [`category_service.dart`](../../categories/services/category_service.md) 的 `modelIdentityOf`。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `AiInsightRequest` | 声明 | B | 创建一个请求。 |
| `insightFingerprint` | 声明 | B | 为一张卡片的请求计算指纹。 |
| `AiInsightStore` | 声明 | B | 创建存储。 |
| `setInstanceForTest` | 声明 | B | 替换应用级存储（仅测试）。 |
| `_ai` | 私有声明 | B | 解析模型服务。 |
| `stateOf` | 声明 | B | 读取共享状态。 |
| `ensure` | 声明 | B | 确保洞察是最新的。 |
| `_generateParsed` | 私有声明 | B | 针对一份事实运行一次模型并解析回复。 |
| `_answer` | 私有声明 | B | 回答一个请求，必要时尝试一次回退事实。 |
| `clearAll` | 声明 | B | 清除缓存。 |
| `dispose` | 声明 | B | 释放监听器。 |

`grep -c 'Purpose:' lib/features/ai/services/insight_service.dart` 报告 11，每个一行。
