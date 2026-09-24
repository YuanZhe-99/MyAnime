# lib/features/anime/models/anime_category.dart

The app's own category taxonomy (1.6.0, M4): `categoryTaxonomyVersion`, the `AnimeCategory` class,
the const `animeCategories` list (v1, 23 ids, each with a one-line English description used only in
model prompts), the `animeCategoryIds` set, and the genre synonym table behind
`mapGenresToCategories`. Localized labels live in the ARB files and are read through
[`categoryLabel`](../views/category_widgets.md#categorylabel). See
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md).

Ids are stable: once shipped they are never renamed or removed, because they are stored in
`Anime.categories` and in `ai_insights.json`. Adding an id bumps `categoryTaxonomyVersion`, which is
part of every AI classification's fingerprint and so re-queues classification.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `AnimeCategory.new` | constructor (`AnimeCategory`) | B | Create a category; only `animeCategories` constructs these. |
| [`mapGenresToCategories`](#mapgenrestocategories) | top-level function | A | Map source genres and tags onto category ids. |

`categoryTaxonomyVersion`, `animeCategories`, `animeCategoryIds`, `_genreSynonyms` and
`_foldedSynonyms` are constants or values without a `/// Purpose:` comment and are not rows.

## Documentation

### `List<String> mapGenresToCategories(Iterable<String> genres)` <a id="mapgenrestocategories"></a>
- **Kind:** top-level function
- **Source:** `lib/features/anime/models/anime_category.dart` (approx. line 153)
- **Purpose:** Map source genres and tags onto category ids.
- **Inputs:** `genres` — `externalMeta.genres` as stored.
- **Returns:** `List<String>` — category ids in taxonomy order, deduplicated; empty when nothing maps.
- **Side effects:** None.
- **Algorithm:** Fold each tag with `AnimeSearchService.foldTitle` (lowercase, no spaces or
  punctuation, Traditional folded to Simplified) and look it up in `_foldedSynonyms` — the synonym
  table keyed the same way, built once. Collect the hits into a set, then return them in
  `animeCategories` order.
- **Usage:** [`resolveCategories`](../../categories/services/category_service.md#resolvecategories)
  (the "mapped" step), `needsClassification` and `CategoryClassifier.refreshCounts`.
- **Notes:** The table covers AniList's genres, MyAnimeList's genres and themes, and common
  bangumi.tv tags (恋爱 → `romance`, 校园 → `school`, 异世界 → `isekai`, 治愈 → `healing`, …). Tags with
  no fitting category — `Ecchi`, for example — are absent, so they are ignored. It reads only data
  already on the record, so it works on every platform, including Windows, and in store builds that
  received `externalMeta` through sync.
