# lib/features/recommendations/services/reason_prompt.dart

The versioned prompt for recommendation reasons (1.6.0, M5), in the style of
[`prompt_templates.md`](../../ai/services/prompt_templates.md): instructions in English, prose
requested in the UI language with Apple's exact locale phrase, and `reasonPromptVersion`. Unlike the
classification version, this one is part of no fingerprint, because reasons are never cached — they
live in memory for one visit to the page. See
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`reasonInstructions`](#reasoninstructions) | top-level function | A | Build the system instructions for writing recommendation reasons. |
| `ReasonCandidate.new` | constructor (`ReasonCandidate`) | B | Create one numbered candidate: title, categories, studios and short facts. |
| [`reasonPrompt`](#reasonprompt) | top-level function | A | Build the prompt for writing recommendation reasons. |
| [`relatedReasonInstructions`](#relatedreasoninstructions) | top-level function | A | Build the system instructions for explaining related records (1.6.2). |
| [`relatedReasonPrompt`](#relatedreasonprompt) | top-level function | A | Build the prompt for explaining related records (1.6.2). |

`reasonPromptVersion` (1), `relatedReasonPromptVersion` (1, since 1.6.2) and the `ReasonCandidate` fields (`number`, `title`, `categories`,
`studios`, `facts`) carry no `/// Purpose:` comment and are not rows.

## Documentation

### `String reasonInstructions(String localeTag, String languageName)` <a id="reasoninstructions"></a>
- **Kind:** top-level function
- **Source:** `lib/features/recommendations/services/reason_prompt.dart` (approx. line 17)
- **Purpose:** Build the system instructions for writing recommendation reasons.
- **Inputs:** `localeTag` — for example `zh_CN`, `zh_TW`, `ja_JP`, `en_US`; `languageName` — the
  language to write in, in English, for example `Japanese`.
- **Returns:** `String`.
- **Side effects:** None.
- **Algorithm:** Open with Apple's phrase "The person's locale is <tag>.", then ask the model to
  pick up to three of the numbered candidates from the person's own list, write one reason of under
  20 words in `languageName` for each, use only the facts given, and answer one `<number>: <reason>`
  line per pick with no other text.
- **Usage:** `writeAiReasons`, as the `instructions` of `OnDeviceAiService.generate`.
- **Notes:** The model picks by number only and is never asked to name a title.

### `String reasonPrompt({required List<ReasonCandidate> candidates, required List<String> topCategories, required List<String> topStudios, required List<(String, double?)> recent})` <a id="reasonprompt"></a>
- **Kind:** top-level function
- **Source:** `lib/features/recommendations/services/reason_prompt.dart` (approx. line 62)
- **Purpose:** Build the prompt for writing recommendation reasons.
- **Inputs:** `candidates` — at most eight; `topCategories`, `topStudios`; `recent` — recently
  completed titles with the user's rating, if any.
- **Returns:** `String`, trimmed.
- **Side effects:** None.
- **Algorithm:** `Taste:` with `- Likes:`, `- Studios they liked:` and one `- Finished: <title>
  (rated x.x/10)` line each, when present; then `Candidates:` with one
  `<n>. <title> — <categories>; studio <studios>; <facts>` line per candidate, omitting empty parts.
- **Usage:** `writeAiReasons`, as the `prompt` of `OnDeviceAiService.generate`.
- **Notes:** A compact profile only — never notes or episode-level history.

### `String relatedReasonInstructions(String localeTag, String languageName)` <a id="relatedreasoninstructions"></a>
- **Kind:** top-level function
- **Source:** `lib/features/recommendations/services/reason_prompt.dart` (approx. line 103)
- **Purpose:** Build the system instructions for explaining related records (1.6.2).
- **Inputs:** `localeTag`, `languageName` — as for `reasonInstructions`.
- **Returns:** `String`.
- **Side effects:** None.
- **Algorithm:** Apple's locale phrase, then: explain why anime in the person's own list are similar
  to the one they are looking at; pick up to three numbered candidates; one reason each in
  `languageName`, under 20 words, about what they have in common; facts given only; one
  `<number>: <reason>` line per pick.
- **Usage:** `writeRelatedAiReasons`.
- **Notes:** Same contract as `reasonInstructions`: the model picks by number and never names a
  title. Changing the wording means bumping `relatedReasonPromptVersion`. The reasons are persisted
  but not fingerprinted, so a new version affects only lists generated afterwards.

### `String relatedReasonPrompt({required ReasonCandidate subject, required List<ReasonCandidate> candidates})` <a id="relatedreasonprompt"></a>
- **Kind:** top-level function
- **Source:** `lib/features/recommendations/services/reason_prompt.dart` (approx. line 119)
- **Purpose:** Build the prompt for explaining related records (1.6.2).
- **Inputs:** `subject` — its `number` is ignored; `candidates` — at most five.
- **Returns:** `String`, trimmed.
- **Side effects:** None.
- **Algorithm:** `Looking at: <title> — <categories>; studio <studios>`, then `Candidates:` with one
  `<n>. <title> — <categories>; studio <studios>; <facts>` line each, omitting empty parts.
- **Usage:** `writeRelatedAiReasons`.
- **Notes:** Titles, categories, studios and deterministic facts only.
