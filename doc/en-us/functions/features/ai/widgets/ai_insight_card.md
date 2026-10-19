# lib/features/ai/widgets/ai_insight_card.dart

`AiInsightCard` (1.9.1, ported from MyDevice!!!!!): the AI card on the Statistics page's summary and ranking views, rendered by MyApps-AI's `MyAppsAiInsightCard`. It renders nothing while AI is off and, unlike MyDevice's card, does not require an on-device model: the selected source (system AI, local or online) is used, and the generated label comes from `aiGeneratedLabelFor`, so an online result names its provider. It rebuilds its request when the page rebuilds and at local midnight, and asks [`AiInsightStore`](../services/insight_service.md) to make itself current.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `AiInsightCard` | declaration | B | Create an insight card. |
| `createState` | declaration | B | Create the state object. |
| `dispose` | declaration | B | Stop timers and listeners. |
| `_onServiceChanged` | private declaration | B | Rebuild when the model becomes usable. |
| `_listenTo` | private declaration | B | Follow the right `OnDeviceAiService` instance. |
| `_armBoundaryTimer` | private declaration | B | Rebuild at the next moment the facts change by time alone. |
| `_scheduleEnsure` | private declaration | B | Ask the store to make this card current after the frame. |
| `_statusLabel` | private declaration | B | Word a model status that stops the card from generating. |
| `build` | declaration | A | Build the card. |
| `_notice` | private declaration | B | Build a one-line notice in place of the card. |
| `_card` | private declaration | B | Build the insight card proper. |

`grep -c 'Purpose:' lib/features/ai/widgets/ai_insight_card.dart` reports 11, one row each.
