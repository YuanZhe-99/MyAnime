# lib/features/ai/services/ai_insight_cards_cache.dart

`ai_insight_cards.json` (1.9.1): the per-device cache of the Statistics insight cards, `{"version": 1, "insights": {<view>: <AiInsightEntry>}}`, written atomically through myapps_data's `AtomicWriteQueue` under `AnimeStorage.getAppDir()`. Not a registered data module: never synced, backed up or exported; an unreadable file reads as empty. A separate file from `ai_insights.json`, whose `AiInsights` keeps only AI categories and drops other keys on save.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `AiInsightCards` | declaration | B | Create a cache value. |
| `toJson` | declaration | B | Serialize the cache file. |
| `AiInsightCards.fromJson` | declaration | B | Parse the cache file. |
| `_` | private declaration | B | Prevent instantiation; the cache is static. |
| `file` | declaration | B | Resolve the cache file. |
| `load` | declaration | B | Read the cache. |
| `save` | declaration | B | Write the cache atomically. |
| `clear` | declaration | B | Delete the cache. |

`grep -c 'Purpose:' lib/features/ai/services/ai_insight_cards_cache.dart` reports 8, one row each.
