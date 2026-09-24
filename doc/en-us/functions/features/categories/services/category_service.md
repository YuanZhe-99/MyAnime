# lib/features/categories/services/category_service.dart

Automatic categories (1.6.0, M4): how a record's categories are resolved, what the on-device model
may see, how a classification request is fingerprinted, and `CategoryClassifier`, which fills the
gaps the genre mapping leaves. `CategoryOrigin` (`user`, `mapped`, `ai`) records which source
produced a record's `EffectiveCategories`. Results of the model go to
[`ai_insights.json`](../../ai/services/ai_insights_cache.md) only; the record itself is never
written here. See
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md)
and [`../../../../on-device-ai.md`](../../../../on-device-ai.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `EffectiveCategories.new` | constructor (`EffectiveCategories`) | B | Create the effective categories (`ids`, `origin`). |
| [`resolveCategories`](#resolvecategories) | top-level function | A | Resolve a record's categories. |
| [`classificationInputOf`](#classificationinputof) | top-level function | A | Collect what the model may know about a work. |
| [`modelIdentityOf`](#modelidentityof) | top-level function | A | Name the model that would answer, for fingerprints and the cache. |
| [`classificationFingerprint`](#classificationfingerprint) | top-level function | A | Fingerprint one classification request. |
| [`needsClassification`](#needsclassification) | top-level function | A | Say whether a record needs an AI classification. |
| `CategoryClassifier.new` | constructor (`CategoryClassifier`) | B | Create the classifier; the AI service, library loader and cache load/save are injectable for tests. |
| `CategoryClassifier.setInstanceForTest` | static method (`CategoryClassifier`), `@visibleForTesting` | B | Replace the singleton for a test. |
| [`CategoryClassifier.start`](#categoryclassifier-start) | method (`CategoryClassifier`) | A | Start the per-session trickle on each resume. |
| [`CategoryClassifier.trickle`](#categoryclassifier-trickle) | method (`CategoryClassifier`) | A | Classify a few records in the background. |
| [`CategoryClassifier.classifyAll`](#categoryclassifier-classifyall) | method (`CategoryClassifier`) | A | Classify every pending record now ("Categorise now"). |
| [`CategoryClassifier.refreshCounts`](#categoryclassifier-refreshcounts) | method (`CategoryClassifier`) | A | Refresh the pending counts without running the model. |
| [`CategoryClassifier._run`](#categoryclassifier-_run) | method (`CategoryClassifier`) | A | Run one classification pass. |
| `CategoryClassifier.dispose` | method (`CategoryClassifier`) | B | Release the lifecycle listener. |

`CategoryOrigin`, `EffectiveCategories.empty`, `CategoryClassifier.instance`, `sessionLimit` (20),
`enabled`, `pending`, `candidates` and the `running` getter carry no `/// Purpose:` comment and are
not rows.

## Documentation

### `EffectiveCategories resolveCategories(Anime anime, {AiInsights? insights})` <a id="resolvecategories"></a>
- **Kind:** top-level function
- **Source:** `lib/features/categories/services/category_service.dart` (approx. line 59)
- **Purpose:** Resolve a record's categories.
- **Inputs:** `anime`; `insights` — the AI cache, or `null` to ignore it.
- **Returns:** `EffectiveCategories` — ids plus the `CategoryOrigin`, or `EffectiveCategories.empty`.
- **Side effects:** None.
- **Algorithm:** The first source that gives something wins:
  1. **User** — `anime.categories` whenever it is non-null, *even empty*; unknown ids are dropped
     from the result (they stay on the record).
  2. **Mapped** — [`mapGenresToCategories`](../../anime/models/anime_category.md#mapgenrestocategories)
     of `externalMeta.genres`, when non-empty.
  3. **AI** — the cache entry for `anime.id` when its status is `ok`, reduced to known ids in
     taxonomy order.
- **Usage:** The detail page's `_load`, the management page's category filter.
- **Notes:** The AI step uses an entry only when its fingerprint still matches the current inputs
  (recomputed with the entry's own `model`), so a stale entry is hidden until the classifier
  replaces it. Callers pass `insights` only while on-device AI is on, so AI-suggested categories
  disappear with the switch.

### `ClassificationInput classificationInputOf(Anime anime)` <a id="classificationinputof"></a>
- **Kind:** top-level function
- **Source:** `lib/features/categories/services/category_service.dart` (approx. line 88)
- **Purpose:** Collect what the model may know about a work.
- **Inputs:** `anime`.
- **Returns:** [`ClassificationInput`](../../ai/services/prompt_templates.md).
- **Side effects:** None.
- **Algorithm:** Up to five titles from `seriesTitlesOf`, `externalMeta.format`, the year of
  `firstAirDate`, `effectiveType.name`, `totalEpisodes`, `externalMeta.studios` and
  `externalMeta.genres`.
- **Usage:** `needsClassification`, `CategoryClassifier._run`.
- **Notes:** Never notes, ratings or viewing progress — only facts that describe the work itself.

### `String modelIdentityOf(GenAiStatusReport report)` <a id="modelidentityof"></a>
- **Kind:** top-level function
- **Source:** `lib/features/categories/services/category_service.dart` (approx. line 107)
- **Purpose:** Name the model that would answer, for fingerprints and the cache.
- **Inputs:** `report` — the AI service's current status report.
- **Returns:** `String` — `variant · baseModelName` (e.g. `stable/full · nano-v3`), or `apple` when
  neither is known.
- **Side effects:** None.
- **Usage:** `refreshCounts`, `_run`.
- **Notes:** Models change with OS and AICore updates, so a new identity re-queues classification.

### `String classificationFingerprint(ClassificationInput input, String model)` <a id="classificationfingerprint"></a>
- **Kind:** top-level function
- **Source:** `lib/features/categories/services/category_service.dart` (approx. line 118)
- **Purpose:** Fingerprint one classification request.
- **Inputs:** `input`, `model`.
- **Returns:** `String` — hex SHA-256.
- **Side effects:** None.
- **Algorithm:** Hash `input.canonical()`, `taxonomy:<categoryTaxonomyVersion>`,
  `prompt:<classificationPromptVersion>` and `model:<model>`, joined by newlines.
- **Usage:** `needsClassification`, `_run`.
- **Notes:** A change to any of the four re-queues the record.

### `bool needsClassification(Anime anime, AiInsights insights, String model)` <a id="needsclassification"></a>
- **Kind:** top-level function
- **Source:** `lib/features/categories/services/category_service.dart` (approx. line 134)
- **Purpose:** Say whether a record needs an AI classification.
- **Inputs:** `anime`, `insights`, `model`.
- **Returns:** `bool` — true only when the user has no override, the genres map to nothing, and no
  cache entry carries the current fingerprint.
- **Side effects:** None.
- **Usage:** `refreshCounts`, `_run`.
- **Notes:** Any status counts as done, so a `skipped` or `none` entry with the current fingerprint
  is not retried.

### `void start()` <a id="categoryclassifier-start"></a>
- **Kind:** method of `CategoryClassifier`
- **Source:** `lib/features/categories/services/category_service.dart` (approx. line 211)
- **Purpose:** Start the per-session trickle on each resume.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Registers one `AppLifecycleListener`.
- **Algorithm:** On every `resumed` state, reset the session counter and start `trickle()`
  unawaited. Idempotent.
- **Usage:** `main()` (see [`../../../main.md`](../../../main.md)).
- **Notes:** The very first trickle at launch comes from `AppSettingsNotifier._loadPersisted`, not
  from a resume.

### `Future<int> trickle()` <a id="categoryclassifier-trickle"></a>
- **Kind:** method of `CategoryClassifier`
- **Source:** `lib/features/categories/services/category_service.dart` (approx. line 227)
- **Purpose:** Classify a few records in the background.
- **Inputs:** None.
- **Returns:** `Future<int>` — how many were classified.
- **Side effects:** Runs the model; writes `ai_insights.json`.
- **Algorithm:** `_run(sessionLimit - thisSession, countSession: true)`.
- **Usage:** `start`, `AppSettingsNotifier` (on load, on turning automatic categories on, after
  turning on-device AI on).
- **Notes:** At most `sessionLimit` (20) records per foreground session.

### `Future<int> classifyAll()` <a id="categoryclassifier-classifyall"></a>
- **Kind:** method of `CategoryClassifier`
- **Source:** `lib/features/categories/services/category_service.dart` (approx. line 236)
- **Purpose:** Classify every pending record now.
- **Inputs:** None.
- **Returns:** `Future<int>` — how many were classified.
- **Side effects:** Runs the model; writes `ai_insights.json`.
- **Usage:** [`CategorizeNowTile`](../widgets/categorize_now_tile.md) ("Categorise now").
- **Notes:** Not counted against the session trickle. Stops on the first failure that is not a
  per-record refusal.

### `Future<void> refreshCounts()` <a id="categoryclassifier-refreshcounts"></a>
- **Kind:** method of `CategoryClassifier`
- **Source:** `lib/features/categories/services/category_service.dart` (approx. line 243)
- **Purpose:** Refresh the pending counts without running the model.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Reads the library and the cache (pruned to the library's ids); notifies
  listeners.
- **Algorithm:** `candidates` counts records with no user override and no genre mapping; `pending`
  counts those among them for which `needsClassification` is true.
- **Usage:** `CategorizeNowTile` (on first build and after a pass) — the "N of M" count.
- **Notes:** None.

### `Future<int> _run(int budget, {required bool countSession})` <a id="categoryclassifier-_run"></a>
- **Kind:** method of `CategoryClassifier`
- **Source:** `lib/features/categories/services/category_service.dart` (approx. line 270)
- **Purpose:** Run one classification pass.
- **Inputs:** `budget` — the most records to classify; `countSession` — whether they count against
  the session limit.
- **Returns:** `Future<int>` — how many were classified.
- **Side effects:** Runs the model through `OnDeviceAiService.choose`; saves the cache after every
  record; notifies listeners at start and end.
- **Algorithm:**
  1. Return 0 unless `enabled`, the service `canGenerate`, no pass is running and `budget > 0`.
  2. Load the library and the cache (pruned), compute the model identity, and queue every record
     for which `needsClassification` is true. Prewarm the model when the queue is non-empty.
  3. For each queued record, while within budget and both switches stay on: `choose` among the ids
     plus `none` (at most three), with `classificationInstructions` and `classificationPrompt`.
     Keep known ids in taxonomy order, at most three; status `ok`, or `none` when nothing is left.
  4. A `GenAiException` of `guardrail` or `unsupportedLanguage` is stored as `skipped`; any other
     failure stops the pass and leaves the record for next time.
  5. Store the entry, save, count it.
- **Usage:** `trickle`, `classifyAll`.
- **Notes:** Batch size 1: one record per prompt. Records are never written; only the cache is.
