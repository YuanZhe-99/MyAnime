# lib/features/ai/services/insight_service.dart

The Statistics insight cards' store (1.9.1, ported from MyDevice!!!!!): `AiInsightRequest` (facts, language, time, optional title-free `fallbackFacts`), `insightFingerprint` (view, prompt version, language, date, model, canonical facts), and `AiInsightStore`, a thin wrapper over MyApps-AI's `AiInsightCoordinator` that caches in [`ai_insight_cards.json`](ai_insight_cards_cache.md). The model identity comes from `modelIdentityOf` in [`category_service.dart`](../../categories/services/category_service.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `AiInsightRequest` | declaration | B | Create a request. |
| `insightFingerprint` | declaration | B | Fingerprint one card request. |
| `AiInsightStore` | declaration | B | Create the store. |
| `setInstanceForTest` | declaration | B | Replace the app-wide store. |
| `_ai` | private declaration | B | Resolve the model service. |
| `stateOf` | declaration | B | Read shared state. |
| `ensure` | declaration | B | Ensure current insight. |
| `_generateParsed` | private declaration | B | Run the model once for one facts value and parse the reply. |
| `_answer` | private declaration | B | Answer a request, trying its fallback facts once if needed. |
| `clearAll` | declaration | B | Clear cache. |
| `dispose` | declaration | B | Release listeners. |

`grep -c 'Purpose:' lib/features/ai/services/insight_service.dart` reports 11, one row each.
