# Categories and Recommendations

Since 1.6.0 the app can sort every record into **categories** from its own fixed taxonomy.
Categories come from three places, in a fixed order: the user's own choice, the genres the anime
databases report, and — only where both give nothing — the on-device model. The feature is **off by
default** (Settings › *Categories & recommendations* › *Automatic categories*) and works on every
platform; only the AI step needs Android, iOS or macOS.

**Recommendations** (also since 1.6.0) answer "what should I watch next **from my library**". They
are a separate switch (Settings › *Categories & recommendations* › *Recommendations*), also **off
by default** and available on every platform; only the optional generated reasons need a model. See
[Recommendations](#recommendations) below. Since 1.6.2 passed-over recommendations go to a
**synced trash** that can be reviewed and restored, and each detail page has its own persisted
**Related** list with its own trash — see [The trash](#the-trash) and
[Related recommendations on the detail page](#related-recommendations-on-the-detail-page). Since
1.6.3 any card can be **pinned** so a refresh keeps it ([Pinning](#pinning)), and missing-sequel
cards carry a small cover and a synopsis ([Missing-sequel cards](#missing-sequel-cards)).

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

While automatic categories are on, the detail page shows the chips under the action row, ending in an
*Edit categories* icon button (a labelled chip through 1.6.2). It opens a sheet of `FilterChip`s — a dialog instead where the window can
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
- `hiddenRecommendations` was the *Not interested* list in 1.6.0 and 1.6.1, when hiding was per
  device. Since 1.6.2 the trash lives in the synced `recommendations.json`
  ([The trash](#the-trash)); the first time the recommendations or trash page opens, the ids here
  move there and this list is emptied. The key is still read and written, empty, so the file's shape
  does not change.

## Recommendations

The code is
[`functions/features/recommendations/services/recommendation_service.md`](../functions/features/recommendations/services/recommendation_service.md)
(ranking),
[`functions/features/recommendations/services/recommendation_store.md`](../functions/features/recommendations/services/recommendation_store.md),
[`functions/features/recommendations/models/recommendation_data.md`](../functions/features/recommendations/models/recommendation_data.md)
and
[`functions/features/recommendations/services/recommendation_merge.md`](../functions/features/recommendations/services/recommendation_merge.md)
(the trash and related lists, 1.6.2),
[`functions/features/recommendations/services/reason_prompt.md`](../functions/features/recommendations/services/reason_prompt.md),
[`functions/features/recommendations/services/ai_reason_service.md`](../functions/features/recommendations/services/ai_reason_service.md)
(AI reasons),
[`functions/features/recommendations/services/sequel_info_service.md`](../functions/features/recommendations/services/sequel_info_service.md)
(missing-sequel cover and synopsis, 1.6.3),
[`functions/features/recommendations/views/recommendations_page.md`](../functions/features/recommendations/views/recommendations_page.md),
[`functions/features/recommendations/views/recommendation_trash_page.md`](../functions/features/recommendations/views/recommendation_trash_page.md)
and
[`functions/features/recommendations/views/related_card.md`](../functions/features/recommendations/views/related_card.md).

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
- **Candidates:** not started, or watching with aired unwatched episodes, and not in the trash. **Within a
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
- **Batch:** at most **10** ranked cards (30 through 1.6.1), then the missing-sequel cards.
- ***Not interested*** moves a card to the [trash](#the-trash). Through 1.6.1 it wrote the per-device
  `ai_insights.json` and could not be undone; since 1.6.2 it syncs and can be restored.
- **Pin** (1.6.3, beside *Not interested*) keeps a card through refreshes; see [Pinning](#pinning).
- **Refresh** (app bar): the whole batch on screen — ranked cards and missing-sequel cards — goes to
  the trash in one write, and the next batch is shown. A snack bar "Moved N to the trash" offers
  **Undo**, which restores exactly that batch. The meaning is deliberate: a batch the user looked at
  and passed over is "not interested". Since 1.6.3 pinned cards are left out of the batch, and the
  button is disabled when every card on screen is pinned.
- **Trash** (app bar) opens the global trash page.
- **Missing sequels:** after the ranked cards, one card per sequel the databases list but the
  library lacks — for each completed record that is the last of its series — marked **"Not in
  your library yet"**. A tap opens the create page prefilled from the relation (the search runs
  only in full builds). Since 1.6.2 each has *Not interested* too, and cards are deduplicated by the
  sequel's canonical database key (`anilist:<id>`, `mal:<id>`, `bgm:<id>`), so one sequel listed at
  two bangumi hosts is one card. These come from relation data fetched by full builds, so a store
  build shows them only for records that received it through sync. Since 1.6.3 they show a cover
  thumbnail and synopsis; see [Missing-sequel cards](#missing-sequel-cards).
- The page reloads when a sync changes local data, so a trash change made on another device shows up
  without leaving the page.

### Pinning

Since 1.6.3 every card on "What to watch next" — library and missing-sequel alike — and every row
of a detail page's Related card has a pin toggle (`push_pin`). Pinning answers "keep this one while I
look at others":

- **A pinned card survives refresh.** Refresh trashes only the unpinned cards; the pinned ones stay,
  at the top. On the global page pinned library cards come first in ranked order and count toward
  the batch of 10; pinned missing-sequel cards come first among the sequel cards.
- **Pin and trash exclude each other.** Pinning a trashed card restores it; *Not interested* (or ✕)
  on a pinned card unpins it. Unpinning leaves the card where it is until the next refresh.
- **A pin is not a promise to show.** A pinned library record that stops being a candidate —
  finished, dropped, or no longer the earliest unfinished member of its series — is not shown, and
  its pin stays in the file, harmless like a trash entry for a deleted record.
- **Pins sync.** They live in `recommendations.json` next to the trash: global pins, pinned sequel
  keys, and each record's own Related pins. When one device pins a card while another refreshes it
  away between two syncs, **the pin wins**.

### Missing-sequel cards

Through 1.6.2 a "Not in your library yet" card showed only "Next: <title> (<source>)". Since 1.6.3 it
is laid out like a library card: a **thumbnail** of the sequel's cover, the title, the "Not in your
library yet" label, and up to three lines of **synopsis**. The detail page's missing-sequel hint shows
the same thumbnail and synopsis.

- **Where it comes from.** Full builds fetch the sequel's page by id from its database — AniList,
  MyAnimeList or bangumi.tv, through the same by-URL refresh the detail page uses — and download its
  cover. One card at a time, once per card; a failed fetch is retried on the next launch. Store builds
  never fetch; they show what a full build fetched, because the result syncs.
- **Small on purpose.** The cover is shrunk to a 112 px wide JPEG (a few kilobytes, capped at 24 KB)
  and stored base64 inside `recommendations.json`; the synopsis is cleaned and capped at 600
  characters. The synopsis is in whatever language the database wrote it.
- **Trashing deletes it.** *Not interested* or Refresh on a sequel card deletes its thumbnail and
  synopsis; the trash keeps only the title, the database and the record it follows. The same happens
  to info for a sequel that is no longer missing (it was added to the library) or no longer listed.
- **Why not `images/`.** Cover files sync additively and are never deleted remotely, so a thumbnail
  file would outlive its trashed card on every device. A field in the JSON file disappears
  everywhere with the next sync.

## The trash

Since 1.6.2 there are two kinds of recommendation trash, both in the synced `recommendations.json`:

| Bin | What goes in | What it hides | Where it is reviewed |
|---|---|---|---|
| **Global** | Library cards and missing-sequel cards passed over on "What to watch next" | Those cards on "What to watch next" | Trash button on that page (`/recommendations/trash`) |
| **Per record** | Items passed over in one record's Related card | Those items in **that record's** Related card only | *Trash* in that card's menu (`/recommendations/trash?anime=<id>`) |

The two are independent: trashing a record from one anime's Related list does not hide it from
"What to watch next" or from any other record's list, and the reverse.

**The trash page** lists trashed records newest first — cover, title, "Trashed <date>" and
**Restore** — and, for the global bin, a "Sequels not in your library" section with each trashed
sequel's title, database and the record it follows. A trashed sequel has no thumbnail or synopsis
any more (1.6.3); a restored one fetches them again in full builds. *Restore all* restores everything shown.
**Restoring removes the entry from the trash, so it can be recommended again** — it is what "delete
from the trash" means here. A restored related item is not put back into the stored list; it can
come back on that card's next refresh.

**Entries for deleted records** stay in the file and are simply not shown. Pruning them would reach
sync as a restore and could remove another device's entries for a record this device has not
received yet; anime ids are UUIDs and never reused, so a leftover entry is harmless.

**Migration.** The first time the recommendations or trash page opens on 1.6.2, the ids in
`ai_insights.json`'s `hiddenRecommendations` move into the global trash (stamped with that moment,
since the old list kept no dates) and the old list is emptied. Each device migrates its own list,
and the merge unions them.

### The file: `recommendations.json`

Owned by `RecommendationStore`, under `AnimeStorage.getAppDir()`, registered as the second module in
`lib/app/data_modules.dart` (module id `recommendations`):

```json
{
  "version": 1,
  "hidden": [
    { "id": "<animeId>", "hiddenAt": "2026-09-24T03:00:00.000Z" }
  ],
  "hiddenSequels": [
    {
      "key": "anilist:182255",
      "sourceId": "<animeId>",
      "title": "葬送のフリーレン 第2期",
      "source": "AniList",
      "hiddenAt": "2026-09-24T03:00:00.000Z"
    }
  ],
  "related": {
    "<animeId>": {
      "generatedAt": "2026-09-24T03:00:00.000Z",
      "items": [
        {
          "id": "<animeId>",
          "reasons": ["categories:romance,school", "studio:Madhouse"],
          "aiReason": "Both follow a slow-burn school romance."
        }
      ],
      "hidden": [{ "id": "<animeId>", "hiddenAt": "2026-09-24T03:00:00.000Z" }],
      "pinned": [{ "id": "<animeId>", "pinnedAt": "2026-09-25T03:00:00.000Z" }]
    }
  },
  "pinned": [
    { "id": "<animeId>", "pinnedAt": "2026-09-25T03:00:00.000Z" }
  ],
  "pinnedSequels": [
    { "key": "anilist:182255", "pinnedAt": "2026-09-25T03:00:00.000Z" }
  ],
  "sequelInfo": {
    "anilist:182255": {
      "synopsis": "Following the First-Class Mage Exam, the trio…",
      "coverUrl": "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/…",
      "coverThumb": "<base64 JPEG, 112 px wide>",
      "fetchedAt": "2026-09-25T03:00:00.000Z"
    }
  }
}
```

The three top-level keys and each record's `pinned` are 1.6.3 additions, **written only when
non-empty**, so a file that never used them keeps the bytes 1.6.2 wrote. A 1.6.2 build keeps them
through `extraJson` and simply does not act on them.

- **Synced and backed up.** It rides WebDAV sync, backups and ZIP export like `anime_data.json`.
  A save notifies auto-sync. It is **not** part of `.myanimeitem` share files.
- **Not created until needed.** A library that never trashed anything and never opened a Related
  card has no file, and sync only issues a GET that finds nothing.
- **Unknown keys survive** at every level (`extraJson`), so an older build keeps a newer build's
  additions. Reason codes this build does not know are kept and not shown.
- **Sorted and pretty-printed**, so an unchanged store writes identical bytes and sync takes its
  raw-equality fast path.
- **The merge never conflicts** — see [`../sync.md`](../sync.md#the-recommendations-file).

## Related recommendations on the detail page

Since 1.6.2, while recommendations are on, every detail page has a **Related** card after the notes
(in the right pane of the two-pane layout): up to **5** records **from the library** that are like
this one. The code is
[`RecommendationService.related`](../functions/features/recommendations/services/recommendation_service.md#recommendationservice-related)
and [`related_card.md`](../functions/features/recommendations/views/related_card.md).

### Ranking

Pure Dart. The subject, the members of its own series and that record's own trash are never offered.

| Contribution | Weight |
|---|---|
| A database lists one as related to the other, either direction, any relation type | `3.0` |
| Cosine of the two records' effective category sets, `shared / √(a·b)` | `× 2.0` |
| They share a studio | `0.5` |
| They share a base title key (the same keys series linking uses) | `1.0` |

A record with no contribution is not offered. **Each other series offers at most its best member**
(on a tie, the earlier one in series order), so the list is never three seasons of one show.
Viewing status plays no part: the card answers "what is like this", not "what to watch next".
Chips: "Also romance, school", "Also by Madhouse", "Spin-off" / "Alternative version" / "Related in
the databases", "Similar title" — at most three, largest first.

### Persisted, until refreshed

- **The first time** a record's card appears, the list is generated and written to
  `recommendations.json`, with a UTC `generatedAt`. From then on the card shows the **stored** list,
  on this device and — through sync — on every other, until the user refreshes it. A new record added
  to the library does not change an existing list by itself.
- **AI reasons** (only with on-device AI on and a model that can generate) are requested right after
  generation with the same privacy rules as the global page — titles, categories, studios and
  relation facts; never notes, ratings or history — through `relatedReasonPrompt`
  (`relatedReasonPromptVersion = 1`). The model picks up to three of the numbered candidates. Unlike
  the global page's reasons they are **saved with the list**, under the same "Generated on this
  device — may be wrong" label.
- **Refresh** (the card's refresh button, or *Show others* in its menu) puts every item on screen into
  **this record's trash**, then generates the next five. With nothing on screen it trashes nothing and
  simply regenerates, which is how newly added records get in. Since 1.6.3 pinned rows are not
  trashed: they stay at the top with their stored reasons, and only the remaining slots are ranked.
- **✕** on a row trashes that one item (and unpins it); the list shrinks until the next refresh.
- **Pin** (1.6.3) on a row keeps it through refreshes; see [Pinning](#pinning).
- **Trash** in the menu opens this record's own bin.
- A record deleted from the library drops out of every list without a write.
- If two devices generate the same record's list between syncs, the newer `generatedAt` wins; the
  trash bins merge as sets, so no passed-over item comes back.
