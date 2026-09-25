# lib/features/recommendations/services/ai_reason_service.dart

The optional AI half of recommendations (1.6.0, M5): it offers the top candidates to the on-device
model, validates the `<number>: <reason>` reply, and returns up to three short reasons keyed by anime
id. Nothing is cached; any failure yields an empty map and the page keeps the deterministic chips.
See [`recommendation_service.md`](recommendation_service.md), [`reason_prompt.md`](reason_prompt.md),
[`../../ai/services/output_validation.md`](../../ai/services/output_validation.md) and
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`parseReasonReply`](#parsereasonreply) | top-level function | A | Read the model's `<number>: <reason>` lines. |
| `ReasonLanguage.new` | constructor (`ReasonLanguage`) | B | Create a request language: locale tag, English name, script code and Chinese conversion flags. |
| [`ReasonLanguage.forLocale`](#reasonlanguage-forlocale) | static method (`ReasonLanguage`) | A | Pick the request language for the UI locale. |
| `ReasonLanguage.finish` | method (`ReasonLanguage`) | B | Post-process a validated reason: convert to the UI's Chinese variant with `ChineseConvert`, else return it unchanged. |
| [`writeAiReasons`](#writeaireasons) | top-level function | A | Ask the on-device model for up to three short reasons. |
| [`writeRelatedAiReasons`](#writerelatedaireasons) | top-level function | A | Ask the on-device model why up to three related records are like the subject (1.6.2). |

`aiReasonCandidates` (8), `aiReasonMaxLength` (140), the private `_answerLine` pattern and the
`ReasonLanguage` fields (`localeTag`, `name`, `code`, `toTraditional`, `toSimplified`) carry no
`/// Purpose:` comment and are not rows.

## Documentation

### `Map<int, String> parseReasonReply(String reply, int count, String languageCode)` <a id="parsereasonreply"></a>
- **Kind:** top-level function
- **Source:** `lib/features/recommendations/services/ai_reason_service.dart` (approx. line 27)
- **Purpose:** Read the model's `<number>: <reason>` lines.
- **Inputs:** `reply`; `count` — how many candidates were offered; `languageCode` — `en`, `ja` or
  `zh`.
- **Returns:** `Map<int, String>` — 1-based candidate number to reason, at most three.
- **Side effects:** None.
- **Algorithm:** Strip Markdown ([`stripMarkdown`](../../ai/services/output_validation.md#stripmarkdown)),
  then per line match a number followed by `:`, `：`, `.`, `)` or `、`. Drop numbers outside
  1…`count` and repeats; clean the text with
  [`cleanSentence`](../../ai/services/output_validation.md#cleansentence) at `aiReasonMaxLength`
  (null when empty or too long); drop it unless
  [`matchesScript`](../../ai/services/output_validation.md#matchesscript) agrees. Stop at three.
- **Usage:** `writeAiReasons`; `test/recommendations_test.dart`.
- **Notes:** The script check accepts either Chinese variant; the variant is fixed afterwards by
  `ReasonLanguage.finish`.

### `static ReasonLanguage? forLocale(Locale locale, {bool? localeSupported})` <a id="reasonlanguage-forlocale"></a>
- **Kind:** static method of `ReasonLanguage`
- **Source:** `lib/features/recommendations/services/ai_reason_service.dart` (approx. line 85)
- **Purpose:** Pick the request language for the UI locale.
- **Inputs:** `locale`; `localeSupported` — Apple's `supportsLocale` answer for the UI locale, null
  when unknown (always on Android).
- **Returns:** `ReasonLanguage?` — null when AI reasons should be skipped.
- **Side effects:** None.
- **Algorithm:**

  | UI locale | `localeSupported` | Request | Post-process |
  |---|---|---|---|
  | `zh_TW` / `zh_HK` | `false` | `zh_CN`, Simplified Chinese | to Traditional |
  | `zh_TW` / `zh_HK` | `true` or null | `zh_TW`, Traditional Chinese | to Traditional |
  | other `zh` | not `false` | `zh_CN`, Simplified Chinese | to Simplified |
  | `ja` | not `false` | `ja_JP`, Japanese | — |
  | anything else | not `false` | `en_US`, English | — |
  | not Traditional Chinese | `false` | — (null: skip) | — |

- **Usage:** `_RecommendationsPageState._requestAiReasons`; `test/recommendations_test.dart`.
- **Notes:** Chinese output is always converted to the UI's variant, so a reply in the other variant
  is fixed rather than discarded.

### `Future<Map<String, String>> writeAiReasons(OnDeviceAiService ai, {required List<Recommendation> ranked, required List<Anime> library, required ReasonLanguage language})` <a id="writeaireasons"></a>
- **Kind:** top-level function
- **Source:** `lib/features/recommendations/services/ai_reason_service.dart` (approx. line 134)
- **Purpose:** Ask the on-device model for up to three short reasons.
- **Inputs:** `ai`; `ranked` — the deterministic list; `library`; `language`; `insights` — the AI
  cache, so AI-derived categories count here as they do in the ranking.
- **Returns:** `Future<Map<String, String>>` — anime id to reason; empty when the model cannot
  generate, the list is empty, or anything fails.
- **Side effects:** Runs the model once through
  [`OnDeviceAiService.generate`](../../ai/services/on_device_ai_service.md#ondeviceaiservice-generate)
  with `AiPriority.interactive` and `maxOutputTokens: 256`.
- **Algorithm:**
  1. Take the top `aiReasonCandidates` (8) as numbered `ReasonCandidate`s with title, effective categories
     (`resolveCategories` with `insights`), studios and a `next after <title>` fact for each `NextAfterReason`.
  2. Build the compact profile from records with a positive `preferenceOf`: the top three
     categories (again with `insights`) and top three studios by summed preference, and the three completed records with
     the latest `modifiedAt`, with their rating.
  3. Generate with [`reasonInstructions`](reason_prompt.md#reasoninstructions) and
     [`reasonPrompt`](reason_prompt.md#reasonprompt), parse with
     [`parseReasonReply`](#parsereasonreply), map numbers back to ids and apply
     `language.finish`.
- **Usage:** `_RecommendationsPageState._requestAiReasons`; exercised through the page by `test/recommendations_page_ui_test.dart`.
- **Notes:** Never throws. The page renders the deterministic list first; these reasons fill in
  when they arrive and live in memory only.

### `Future<Map<String, String>> writeRelatedAiReasons(OnDeviceAiService ai, {required Anime subject, required List<Recommendation> related, required ReasonLanguage language, AiInsights? insights})` <a id="writerelatedaireasons"></a>
- **Kind:** top-level function
- **Source:** `lib/features/recommendations/services/ai_reason_service.dart` (approx. line 214)
- **Purpose:** Explain, for the detail page's related list (1.6.2), what up to three related records
  have in common with the record being viewed.
- **Inputs:** `ai`; `subject`; `related` — the deterministic related list, at most five; `language`;
  `insights` — AI categories.
- **Returns:** `Future<Map<String, String>>` — anime id to reason; empty on any failure.
- **Side effects:** Runs the model once, as an interactive request.
- **Algorithm:** Describe the subject and each candidate as a `ReasonCandidate` (title, effective
  categories, studios; a candidate's facts add `listed as <relation type>` for a database relation),
  send [`relatedReasonInstructions`](reason_prompt.md#relatedreasoninstructions) and
  [`relatedReasonPrompt`](reason_prompt.md#relatedreasonprompt), then validate with
  [`parseReasonReply`](#parsereasonreply) and `language.finish` exactly as `writeAiReasons` does.
- **Usage:** `RelatedRecommendationsCard._aiReasons`.
- **Notes:** Never throws. Unlike the global page's reasons, the caller **persists** these with the
  list in `recommendations.json`, so they sync. No rating, note or viewing history reaches the model.
