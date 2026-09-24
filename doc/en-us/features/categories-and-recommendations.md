# Categories and Recommendations

Since 1.6.0 the app can sort every record into **categories** from its own fixed taxonomy.
Categories come from three places, in a fixed order: the user's own choice, the genres the anime
databases report, and — only where both give nothing — the on-device model. The feature is **off by
default** (Settings › *Categories & recommendations* › *Automatic categories*) and works on every
platform; only the AI step needs Android, iOS or macOS.

**Recommendations** (also since 1.6.0) answer "what should I watch next **from my library**". They
are a separate switch (Settings › *Categories & recommendations* › *Recommendations*), also **off
by default** and available on every platform; only the optional generated reasons need a model. See
[Recommendations](#recommendations) below.

The code for categories is [`functions/features/anime/models/anime_category.md`](../functions/features/anime/models/anime_category.md)
(the taxonomy and genre mapping),
[`functions/features/categories/services/category_service.md`](../functions/features/categories/services/category_service.md)
(resolution and the classifier),
[`functions/features/ai/services/prompt_templates.md`](../functions/features/ai/services/prompt_templates.md),
[`functions/features/ai/services/ai_insights_cache.md`](../functions/features/ai/services/ai_insights_cache.md)
and [`functions/features/anime/views/category_widgets.md`](../functions/features/anime/views/category_widgets.md).
The platform side of the model is in [`../on-device-ai.md`](../on-device-ai.md).

## Categories

### The taxonomy

`animeCategories` in `anime_category.dart`, version 1 (`categoryTaxonomyVersion = 1`). Ids are
stable: once shipped they are never renamed or removed. The descriptions are English and are used
only in model prompts; the UI shows the localized labels from the ARB files.

| Id | Description (prompt only) |
|---|---|
| `action` | fights, battles and physical conflict |
| `adventure` | journeys, quests and exploration |
| `comedy` | played mainly for laughs |
| `drama` | serious, emotional character stories |
| `romance` | love stories and relationships |
| `slice_of_life` | everyday life with little overarching plot |
| `fantasy` | magic, mythical creatures, invented worlds |
| `isekai` | a character transported or reborn into another world |
| `sci_fi` | science fiction: technology, space, the future |
| `mecha` | giant robots or piloted machines |
| `mystery` | solving crimes, puzzles or secrets |
| `suspense` | thrillers built on tension |
| `horror` | meant to frighten |
| `psychological` | the inner workings of the mind |
| `supernatural` | ghosts, spirits, youkai or special powers |
| `sports` | athletes, teams and competition |
| `music` | musicians, bands and idols |
| `school` | set mainly at a school |
| `historical` | set in a real historical period |
| `military` | armies, soldiers and war |
| `gourmet` | cooking and food |
| `healing` | iyashikei: calm, soothing and gentle |
| `magical_girl` | girls who transform to fight with magic |

**There is no adult or fan-service category.** Apple's acceptable-use rules for Foundation Models
prohibit generating such content, and the models' guardrails refuse it; a category the model may
never assign would be one only some records could ever reach. Genre tags such as `Ecchi` therefore
map to nothing.

Adding an id bumps `categoryTaxonomyVersion`. The version is part of every AI fingerprint, so a new
taxonomy re-queues classification.

### Resolution, per record

`resolveCategories` returns the ids and which source produced them (`CategoryOrigin`):

1. **User** — the record's `categories` field, whenever it is present, **even empty**.
2. **Mapped** — `externalMeta.genres` through a synonym table covering AniList's genres,
   MyAnimeList's genres and themes, and common bangumi.tv tags (恋爱 → `romance`, 校园 → `school`,
   日常 → `slice_of_life`, 异世界 → `isekai`, 机战 → `mecha`, 治愈 → `healing`, 美食 → `gourmet`, …). Tags
   are folded before lookup (lowercase, no spaces or punctuation, Traditional to Simplified), and
   unknown tags are ignored. This step reads only the record, so it works on Windows and in store
   builds that received `externalMeta` through sync.
3. **AI** — a cached classification with status `ok`, only for records where the first two give
   nothing.

AI-suggested chips carry a sparkle icon and the tooltip "Generated on this device — may be wrong".

### The `categories` field

`Anime.categories` is a JSON list of id strings in `anime_data.json`:

| Stored value | Meaning |
|---|---|
| key absent | Automatic: mapped, else AI |
| `["romance", "school"]` | The user's own classification; it wins |
| `[]` | The user decided the record has **no** categories; it wins too |

This is the one field whose empty value is meaningful, so it is **the exception to
omit-when-empty**: `[]` is written and synced, because dropping it would silently turn "none" back
into automatic on every device. Ids this build does not know are kept and written back, but not
shown. A value that is not a list of strings is preserved in `extraJson` untouched. The field is
not personal data: it syncs, it is backed up, and it stays in share files. See
[`../data-formats.md`](../data-formats.md).

### Editing

While automatic categories are on, the detail page shows the chips under the header chips, with an
*Edit categories* chip. It opens a sheet of `FilterChip`s — a dialog instead where the window can
split ([`../adaptive-layout.md`](../adaptive-layout.md)). The editor starts from the effective ids,
so saving writes them as the user's own list. **Saving is a user edit**: `modifiedAt` is stamped in
UTC and the record syncs through the normal whole-record merge. *Reset to automatic* (shown only
when the record has its own list) removes the key. Ids this build does not know survive a save.

### Filtering on Manage

While automatic categories are on, the Manage tab's app bar gains a category filter beside the
local-archive filter. It behaves the same way: **view state only**, never persisted, applied to the
quarter pages, "Other" and search results, and matched against each record's effective categories
(own, mapped or AI). See [`home-management-statistics.md`](home-management-statistics.md).

### AI classification

Only for records with no user list and no mapped category, and only while automatic categories and
on-device AI are both on and a model can generate.

- **Input:** the work only — up to five known titles, format, year, the length type (`AnimeType`),
  episode count, studios and raw genres. **Never notes, never ratings**, never viewing progress.
- **Prompt:** a versioned template in `prompt_templates.dart` (`classificationPromptVersion = 1`),
  instructions in English: choose at most three ids from the list, use only the facts given,
  answer `NONE` when unsure. Changing the wording means bumping the version.
- **Output:** Dart keeps only known ids, deduplicated, in taxonomy order, at most three.
- **Batch size 1:** one record per prompt, until latency has been measured on a device.
- **When:** a trickle of at most **20 records per foreground session**, started when the app loads
  its settings, on every resume, when automatic categories are turned on and after on-device AI is
  turned on; plus *Categorise now* in Settings, which classifies everything pending and shows an
  "N of M still to categorise" count.
- **Fingerprint:** SHA-256 of the inputs, the taxonomy version, the prompt version and the model
  identity (for example `stable/full · nano-v3`, or `apple`). A record is queued again whenever the
  fingerprint changes — new genres or titles, a new taxonomy or prompt, or a model update.
- **Status:** `ok` (ids chosen), `none` (the model answered NONE) or `skipped` (a guardrail or an
  unsupported language refused it). None of the three is retried until the fingerprint changes.
  Any other failure stops the pass and leaves the record for next time.

Results go to the cache only; the record is never written by the classifier.

### The cache: `ai_insights.json`

Owned by `AiInsightsCache`, under `AnimeStorage.getAppDir()`:

```json
{
  "version": 1,
  "categories": {
    "<animeId>": {
      "fingerprint": "<sha256 of the inputs, taxonomy version, prompt version and model identity>",
      "ids": ["romance", "school"],
      "status": "ok",
      "model": "stable/full · nano-v3",
      "generatedAt": "2026-10-01T12:00:00.000Z"
    }
  },
  "hiddenRecommendations": []
}
```

- **Per device.** It is not registered in `lib/app/data_modules.dart`, so it is **neither
  synced nor backed up**, and writes never notify auto-sync. It still moves with a storage-path
  change.
- **Rebuildable.** Load is tolerant: a malformed entry is dropped, an unreadable file reads as empty.
- **Pruned on load.** The classifier and the recommendations page load it with the library's ids and
  drop entries — categories and hidden ids — for deleted records; the next save writes that out.
- Writes are atomic (tmp then rename) and pretty-printed with sorted keys, so an unchanged cache
  writes identical bytes.
- `hiddenRecommendations` is the *Not interested* list (see [Recommendations](#recommendations)).
  Because the file is per device, hiding a recommendation on one device does not hide it on another.

## Recommendations

The code is
[`functions/features/recommendations/services/recommendation_service.md`](../functions/features/recommendations/services/recommendation_service.md)
(ranking),
[`functions/features/recommendations/services/reason_prompt.md`](../functions/features/recommendations/services/reason_prompt.md),
[`functions/features/recommendations/services/ai_reason_service.md`](../functions/features/recommendations/services/ai_reason_service.md)
(AI reasons) and
[`functions/features/recommendations/views/recommendations_page.md`](../functions/features/recommendations/views/recommendations_page.md).

### Scope

Only the library. The candidates are the user's own records that are not started, or being watched
with aired but unwatched episodes. **The model is never asked to name titles**: a small on-device
model does not reliably know what exists, and anything it invented would be a dead end. Two
library-adjacent sources are facts rather than guesses and are in scope: the next member of a series
([`series-linking.md`](series-linking.md)) and a missing sequel from the databases' relation data.

### Deterministic ranking

Pure Dart, no model. Ranking uses each record's effective categories (own, mapped or cached AI)
whether or not *Automatic categories* is on.

- **Preference** per record: with a rating, `(effectiveOverall − 6) / 4`, clamped to −1…1; without
  one, completed `+0.5`, dropped `−0.7`, anything else `0`.
- **Taste profile:** the preference-weighted sum of the category vectors, normalised. **Studio
  affinity:** the preference sum per studio.
- **Candidates:** not started, or watching with aired unwatched episodes, and not hidden. **Within a
  series only its earliest member that is not completed is a candidate** — season 3 is never
  offered to someone who has not finished season 1. If that member is not eligible (dropped, or
  watching but caught up), the series offers nothing.
- **Score:** the sum of the contributions, with the weights from `RecommendationWeights`:

| Contribution | Weight |
|---|---|
| Previous member of the series is completed | `3.0`, `+1.0` when it was rated 8 or higher |
| Cosine of taste profile and the candidate's categories | `× 2.0` |
| Best studio affinity, clamped to −1…1 | `× 0.5` |
| External average score minus 7, clamped to ±2 | `× 0.3` |
| Being watched with aired unwatched episodes | `0.8` |
| Currently airing | `0.4` |

- **Cold start** (no rating and nothing completed anywhere): series continuation first, then the
  external score, then the most recently added.
- **Reason chips:** from the largest positive contributions, at most three — "Next after <title>",
  "Like titles you rated highly: romance, school" (at most two categories), "Same studio as
  <title>", "AniList 8.9" (the best single source), and "New episodes to catch up on". Airing adds
  score but no chip.

### AI reasons (optional)

Only with on-device AI on and a model that can generate. Nothing waits on the model: the
deterministic list and chips render at once, a thin progress bar shows under the app bar, and the
reasons fill in when they arrive.

- **Input:** the top **8** candidates, numbered, with their title, categories, studios and "next after" facts,
  and a **compact profile** — the top three categories and studios by preference, and the three
  most recently modified completed titles with their ratings. Never notes, never episode history.
- **Prompt:** `reason_prompt.dart` (`reasonPromptVersion = 1`), instructions in English with the
  prose requested in the UI language. The model **picks up to three by number** and writes one
  reason of under 20 words for each, as `<number>: <reason>` lines. It runs as an interactive
  request, ahead of any background classification.
- **Validation:** Markdown stripped; only known numbers, no duplicates; at most **140** characters;
  a script check (mostly CJK for `zh`, `zh_TW` and `ja`, with some kana for `ja`; mostly Latin for
  `en`).
  Anything invalid is dropped and the card keeps its chips.
- **Chinese variants:** a reply in the right script but the other Chinese variant is converted with
  `chinese_convert.dart` rather than discarded.
- **Apple:** when `supportsLocale` rejects Traditional Chinese, Simplified is requested and
  converted; when it rejects any other UI language, AI reasons are skipped. If the answer for the UI
  locale is not known yet (Settings has not been opened this session), the page asks the system once
  with the locale before deciding.
- **Memory only:** reasons are kept for one visit to the page, never written to disk.

Each AI reason sits under the "Generated on this device — may be wrong" label.

### The page

- **Entry:** an app-bar action on Home, beside the list-columns button, shown only while
  recommendations are on. It pushes `/recommendations`
  ([`home-management-statistics.md`](home-management-statistics.md)).
- **Layout:** a list of cards — cover, title, reason chips, the labelled AI reason when there is
  one — laid out with `listColumnCount` using **Home's column preference**; the page has no column
  button of its own ([`../adaptive-layout.md`](../adaptive-layout.md)). A tap opens the detail page.
- ***Not interested*** hides a candidate. The id goes to `hiddenRecommendations` in
  `ai_insights.json`, so **hiding is per device**: it is neither synced nor backed up, and there is
  no UI to undo it short of deleting the record.
- **Missing sequels:** after the ranked cards, one card per sequel the databases list but the
  library lacks — for each completed record that is the last of its series — marked **"Not in
  your library yet"**. A tap opens the create page prefilled from the relation (the search runs
  only in full builds). These come from relation data fetched by full builds, so a store build shows
  them only for records that received it through sync.
