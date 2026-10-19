# lib/features/ai/services/insight_prompts.dart

统计页洞察卡片（1.9.1）的词汇和措辞，移植自 MyDevice!!!!!：`InsightModule`（`statsSummary`、`statsRanking`；名称即 `ai_insight_cards.json` 中的键）、`InsightSlot`、带引用词的 `InsightFacts`、带版本的指令（`insightPromptVersion` 1）和提示词、`<number>: <sentence>` 回复解析器——读取各行之前先用 MyApps-AI 的 `stripThinking` 去掉推理块——以及事实格式化辅助函数。参见[端侧 AI — 统计页洞察卡片](../../../../on-device-ai.md#statistics-insight-cards)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `InsightSlot` | 声明 | B | 创建一个槽位。 |
| `InsightFacts` | 声明 | B | 创建一个事实值。 |
| `canonical` | 声明 | B | 序列化事实以计算指纹。 |
| `insightInstructions` | 声明 | B | 构建一张卡片的系统指令。 |
| `insightPrompt` | 声明 | B | 构建一张卡片的提示词。 |
| `parseInsightReply` | 声明 | B | 读取模型的 `<number>: <sentence>` 行（先去掉推理块）。 |
| `_normalize` | 私有声明 | B | 归一化一行，用于判断是否复述了问题。 |
| `clipTitle` | 声明 | B | 为事实行截短用户输入的标题。 |
| `factNumber` | 声明 | B | 为事实行格式化数字。 |
| `factDate` | 声明 | B | 为事实行把日期格式化为 `yyyy-MM-dd`。 |

`grep -c 'Purpose:' lib/features/ai/services/insight_prompts.dart` 报告 10，每个一行。
