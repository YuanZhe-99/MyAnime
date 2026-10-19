# lib/features/ai/services/ai_insight_cards_cache.dart

`ai_insight_cards.json`（1.9.1）：统计页洞察卡片的本设备缓存，`{"version": 1, "insights": {<视图>: <AiInsightEntry>}}`，通过 myapps_data 的 `AtomicWriteQueue` 原子地写入 `AnimeStorage.getAppDir()` 下。它不是已注册的数据模块：从不同步、备份或导出；不可读的文件按空处理。它与 `ai_insights.json` 分开，因为后者的 `AiInsights` 只保留 AI 分类，保存时会丢弃其他键。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `AiInsightCards` | 声明 | B | 创建一个缓存值。 |
| `toJson` | 声明 | B | 序列化缓存文件。 |
| `AiInsightCards.fromJson` | 声明 | B | 解析缓存文件。 |
| `_` | 私有声明 | B | 防止实例化；缓存是静态的。 |
| `file` | 声明 | B | 解析缓存文件路径。 |
| `load` | 声明 | B | 读取缓存。 |
| `save` | 声明 | B | 原子地写入缓存。 |
| `clear` | 声明 | B | 删除缓存。 |

`grep -c 'Purpose:' lib/features/ai/services/ai_insight_cards_cache.dart` 报告 8，每个一行。
