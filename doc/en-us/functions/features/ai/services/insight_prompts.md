# lib/features/ai/services/insight_prompts.dart

The vocabulary and wording of the Statistics insight cards (1.9.1), ported from MyDevice!!!!!: `InsightModule` (`statsSummary`, `statsRanking`; the name is the key in `ai_insight_cards.json`), `InsightSlot`, `InsightFacts` with quoted terms, the versioned instructions (`insightPromptVersion` 1) and prompt, the `<number>: <sentence>` reply parser — which removes reasoning blocks with MyApps-AI's `stripThinking` before reading lines — and the fact formatting helpers. See [On-device AI — Statistics insight cards](../../../../on-device-ai.md#statistics-insight-cards).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `InsightSlot` | declaration | B | Create a slot. |
| `InsightFacts` | declaration | B | Create a facts value. |
| `canonical` | declaration | B | Serialize the facts for fingerprinting. |
| `insightInstructions` | declaration | B | Build the system instructions for one card. |
| `insightPrompt` | declaration | B | Build the prompt for one card. |
| `parseInsightReply` | declaration | B | Read the model's `<number>: <sentence>` lines. |
| `_normalize` | private declaration | B | Fold a line for the echoed-question comparison. |
| `clipTitle` | declaration | B | Shorten a user-typed title for a fact line. |
| `factNumber` | declaration | B | Format a number for a fact line. |
| `factDate` | declaration | B | Format a date as `yyyy-MM-dd` for a fact line. |

`grep -c 'Purpose:' lib/features/ai/services/insight_prompts.dart` reports 10, one row each.
