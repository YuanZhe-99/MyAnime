# lib/features/ai/services/output_validation.dart

Shared parsing and checking of on-device model output, added in 1.6.0 (M3). Everything a model says
passes through here before it is shown or cached, on both platforms: a small model ignores formats,
wraps answers in Markdown, and sometimes answers in the wrong script. Nothing here trusts the reply;
anything that does not fit is dropped rather than repaired. All functions are pure. On `master` the
only caller is `MethodChannelGenAiBackend.choose` on Android; the rest are ready for the M4 and M5
features. See [`../../../../on-device-ai.md`](../../../../on-device-ai.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`stripMarkdown`](#stripmarkdown) | top-level function | A | Remove code fences and Markdown decoration from a reply. |
| `ChoiceParse.new` | constructor (`ChoiceParse`) | B | Create a choice parse result (`ids`, `none`, `valid`). |
| [`parseChoiceReply`](#parsechoicereply) | top-level function | A | Read a model's pick of ids from a list of options. |
| `_normalizeId` | top-level function (private) | B | Lowercase and trim a token, strip surrounding quotes and full stops, turn spaces and hyphens into underscores. |
| [`matchesScript`](#matchesscript) | top-level function | A | Check that generated prose is in the script the UI language uses. |
| [`cleanSentence`](#cleansentence) | top-level function | A | Clean one generated sentence for display. |

`ChoiceParse`'s fields and `ChoiceParse.invalid`, and the private regular expressions, carry no
`/// Purpose:` comment and are not rows.

## Documentation

### `String stripMarkdown(String text)` <a id="stripmarkdown"></a>
- **Kind:** top-level function
- **Source:** `lib/features/ai/services/output_validation.dart` (approx. line 23)
- **Purpose:** Remove code fences and Markdown decoration from a reply.
- **Inputs:** `text`.
- **Returns:** `String` — trimmed plain text.
- **Side effects:** None.
- **Algorithm:** Remove code fences (with any language tag), then bold and italic markers, inline
  code ticks, heading marks, bullets and list numbers at line starts; trim.
- **Usage:** `parseChoiceReply` and `cleanSentence`.
- **Notes:** Line breaks are kept, because the choice parser reads one id per line.

### `ChoiceParse parseChoiceReply(String reply, List<String> options, {int maxItems = 3})` <a id="parsechoicereply"></a>
- **Kind:** top-level function
- **Source:** `lib/features/ai/services/output_validation.dart` (approx. line 58)
- **Purpose:** Read a model's pick of ids from a list of options.
- **Inputs:** `reply` — the raw text; `options` — the allowed ids; `maxItems`.
- **Returns:** `ChoiceParse` — known ids in reply order, deduplicated and capped; `none: true` for an
  explicit `NONE`; `ChoiceParse.invalid` when the reply ignored the format.
- **Side effects:** None.
- **Algorithm:**
  1. Build a map from each option's normalized form to the option.
  2. Strip Markdown; an empty result is invalid.
  3. For each line, drop a leading `<label>:` (ASCII or full-width colon, up to 40 characters),
     then split on commas, semicolons, slashes, pipes and the CJK list marks.
  4. Normalize each token; note `none`; keep known ids not seen before.
  5. No ids: valid-and-empty if `NONE` was seen, otherwise invalid. Otherwise cap at `maxItems`.
- **Usage:** `MethodChannelGenAiBackend.choose` on Android.
- **Notes:** Matching is case-insensitive and treats spaces and hyphens like underscores, so
  `slice of life` reads as `slice_of_life`. Unknown ids are dropped silently.

### `bool matchesScript(String text, String languageCode)` <a id="matchesscript"></a>
- **Kind:** top-level function
- **Source:** `lib/features/ai/services/output_validation.dart` (approx. line 115)
- **Purpose:** Check that generated prose is in the script the UI language uses.
- **Inputs:** `text`; `languageCode` — `en`, `ja` or `zh` (either Chinese variant).
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** Count Han, kana and Latin letters. With no letters, false. `zh`: Han plus kana at
  least 60% of letters, and some Han. `ja`: the same 60%, and at least one kana. Any other language:
  Latin at least 60%.
- **Usage:** No caller on `master` yet; M5's recommendation reasons.
- **Notes:** A proportion rather than an absolute rule, because a reason may quote a title in
  another script. It cannot tell Simplified from Traditional Chinese.

### `String? cleanSentence(String text, {int maxLength = 140})` <a id="cleansentence"></a>
- **Kind:** top-level function
- **Source:** `lib/features/ai/services/output_validation.dart` (approx. line 138)
- **Purpose:** Clean one generated sentence for display.
- **Inputs:** `text`; `maxLength` — the longest acceptable result, in runes.
- **Returns:** `String?` — a single-line, Markdown-free sentence, or null when it is empty or too
  long.
- **Side effects:** None.
- **Algorithm:** Strip Markdown, collapse all whitespace to single spaces, trim, then check the
  length.
- **Usage:** No caller on `master` yet; M5's recommendation reasons.
- **Notes:** Over-long output is dropped rather than truncated, because a cut sentence reads as a
  wrong one.
