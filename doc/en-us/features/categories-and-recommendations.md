# Categories and Recommendations

Since 1.6.0 the app can sort every record into **categories** from its own fixed taxonomy.
Categories come from three places, in a fixed order: the user's own choice, the genres the anime
databases report, and — only where both give nothing — the on-device model. The feature is **off by
default** (Settings › *Categories & recommendations* › *Automatic categories*) and works on every
platform; only the AI step needs Android, iOS or macOS.

The code is [`functions/features/anime/models/anime_category.md`](../functions/features/anime/models/anime_category.md)
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
- **Pruned on load.** The classifier loads it with the library's ids and drops entries for deleted
  records; the next save writes that out.
- Writes are atomic (tmp then rename) and pretty-printed with sorted keys, so an unchanged cache
  writes identical bytes.
