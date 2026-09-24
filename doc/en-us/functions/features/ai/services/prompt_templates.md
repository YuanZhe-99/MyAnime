# lib/features/ai/services/prompt_templates.dart

Versioned prompt templates for the on-device model (1.6.0, M4): the classification instructions and
prompt, `classificationPromptVersion`, and `ClassificationInput`, the facts about one work that
classification may use. Instructions are in English on every platform: the small models follow
English instructions most reliably, and the answer is a list of ids rather than prose.

Changing a template's wording means bumping `classificationPromptVersion`. The version is part of
every cached result's fingerprint
([`classificationFingerprint`](../../categories/services/category_service.md#classificationfingerprint)),
so old results are re-queued. See
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`classificationInstructions`](#classificationinstructions) | top-level function | A | Build the system instructions for classifying one work. |
| `ClassificationInput.new` | constructor (`ClassificationInput`) | B | Create the classification input. |
| [`ClassificationInput.canonical`](#classificationinput-canonical) | method (`ClassificationInput`) | A | Serialize the input for fingerprinting. |
| [`classificationPrompt`](#classificationprompt) | top-level function | A | Build the prompt for classifying one work. |

`classificationPromptVersion` and the `ClassificationInput` fields (`titles`, `format`, `year`,
`type`, `episodes`, `studios`, `genres`) carry no `/// Purpose:` comment and are not rows.

## Documentation

### `String classificationInstructions()` <a id="classificationinstructions"></a>
- **Kind:** top-level function
- **Source:** `lib/features/ai/services/prompt_templates.dart` (approx. line 25)
- **Purpose:** Build the system instructions for classifying one work.
- **Inputs:** None.
- **Returns:** `String`.
- **Side effects:** None.
- **Algorithm:** List every category as `- <id>: <description>`, then ask for at most three ids that
  clearly describe the work, using only the facts given, as one comma-separated line, and `NONE`
  when unsure.
- **Usage:** `CategoryClassifier._run`, as the `instructions` of `OnDeviceAiService.choose`.
- **Notes:** On Apple the answer is also constrained by the `choose` schema (the ids plus `none`);
  on Android the line parser enforces it. Either way Dart keeps only known ids.

### `String canonical()` <a id="classificationinput-canonical"></a>
- **Kind:** method of `ClassificationInput`
- **Source:** `lib/features/ai/services/prompt_templates.dart` (approx. line 80)
- **Purpose:** Serialize the input for fingerprinting.
- **Inputs:** None.
- **Returns:** `String` — stable across runs.
- **Side effects:** None.
- **Algorithm:** Join, in a fixed order, `titles` (with `|`), `format`, `year`, `type`, `episodes`,
  `studios` and `genres` (each list with `|`), one per line; a missing value is an empty line.
- **Usage:** `classificationFingerprint`.
- **Notes:** The field and item order is fixed, so an unchanged record always fingerprints the same.

### `String classificationPrompt(ClassificationInput input)` <a id="classificationprompt"></a>
- **Kind:** top-level function
- **Source:** `lib/features/ai/services/prompt_templates.dart` (approx. line 97)
- **Purpose:** Build the prompt for classifying one work.
- **Inputs:** `input`.
- **Returns:** `String`.
- **Side effects:** None.
- **Algorithm:** `Anime:` then one `- Label: value` line per known fact — Titles (joined with ` / `),
  Format, Year, Length (the `AnimeType` name), Episodes, Studios, Tags — and a closing
  `Category ids:`.
- **Usage:** `CategoryClassifier._run`, as the `prompt` of `OnDeviceAiService.choose`.
- **Notes:** One work per prompt (batch size 1) until latency has been measured on a device. The
  input never includes notes, ratings or viewing progress; see
  [`classificationInputOf`](../../categories/services/category_service.md#classificationinputof).
