# lib/features/recommendations/services/recommendation_service.dart

The deterministic half of recommendations (1.6.0, M5): pure Dart, no model involved. It ranks the
library's own not-started and in-progress records and says why, as typed reasons the page turns into
chips. The weights are named constants in `RecommendationWeights`, in one place. The optional AI
reasons are layered on by [`ai_reason_service.md`](ai_reason_service.md). Since 1.6.2 it also ranks
a record's **related** list for the detail page (`related`), encodes that list's reasons for
`recommendations.json`, and keys missing-sequel cards for the trash. See
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `RecommendationReason.new` | constructor (`RecommendationReason`, sealed) | B | Create a reason; subclasses carry the data and the UI localizes. |
| `NextAfterReason.new` | constructor (`NextAfterReason`) | B | "Next after <title>", carrying the completed member it follows. |
| `CategoryMatchReason.new` | constructor (`CategoryMatchReason`) | B | "Like titles you rated highly: …", carrying at most two shared category ids, strongest first. |
| `SameStudioReason.new` | constructor (`SameStudioReason`) | B | "Same studio as <title>", carrying the liked record and the studio. |
| `ExternalScoreReason.new` | constructor (`ExternalScoreReason`) | B | "AniList 8.9", carrying the database name and a 0–10 score. |
| `CatchUpReason.new` | constructor (`CatchUpReason`) | B | "New episodes to catch up on". |
| `SharedCategoriesReason.new` | constructor (`SharedCategoriesReason`) | B | Related list (1.6.2): "Also romance, school", carrying at most two categories both records have. |
| `SharedStudioReason.new` | constructor (`SharedStudioReason`) | B | Related list (1.6.2): "Also by <studio>". |
| `RelatedByDatabaseReason.new` | constructor (`RelatedByDatabaseReason`) | B | Related list (1.6.2): a database lists the two records as related, carrying the relation type. |
| `SharedTitleReason.new` | constructor (`SharedTitleReason`) | B | Related list (1.6.2): "Similar title" — a shared base title key. |
| [`encodeRelatedReason`](#encoderelatedreason) | top-level function | A | Encode a related-list reason for `recommendations.json` (1.6.2). |
| [`decodeRelatedReason`](#decoderelatedreason) | top-level function | A | Decode a persisted related-list reason (1.6.2). |
| [`sequelTrashKey`](#sequeltrashkey) | top-level function | A | Key a missing-sequel card for deduplication and the trash (1.6.2). |
| `Recommendation.new` | constructor (`Recommendation`) | B | Create one ranked candidate: record, total score, at most three reasons. |
| [`preferenceOf`](#preferenceof) | top-level function | A | Read how much the user liked a record. |
| [`hasAiredUnwatched`](#hasairedunwatched) | top-level function | A | Report whether a record has aired episodes still unwatched. |
| [`isAiring`](#isairing) | top-level function | A | Report whether a record is currently airing. |
| `RecommendationService._` | constructor (`RecommendationService`) | B | Prevent instantiation; the service is static only. |
| [`RecommendationService.rank`](#recommendationservice-rank) | static method (`RecommendationService`) | A | Rank what to watch next. |
| [`RecommendationService.related`](#recommendationservice-related) | static method (`RecommendationService`) | A | Rank the library records related to one record (1.6.2). |
| [`RecommendationService._eligible`](#recommendationservice-_eligible) | static method (`RecommendationService`) | A | Say whether a record can be recommended at all. |
| [`RecommendationService._bestExternal`](#recommendationservice-_bestexternal) | static method (`RecommendationService`) | A | Pick the highest external score for a reason chip. |

`RecommendationWeights` holds only `static const` values and the reason classes' fields carry no
`/// Purpose:` comment, so neither is a row. The weights:

| Constant | Value | Meaning |
|---|---|---|
| `nextInSeries` | 3.0 | The previous member of the candidate's series is completed |
| `nextInSeriesRatedHigh` | 1.0 | Added when that member was rated `highRating` or higher |
| `highRating` | 8.0 | A rating at or above this counts as "rated highly" |
| `categoryMatch` | 2.0 | Multiplies the cosine of the taste profile and the candidate's categories |
| `studioMatch` | 0.5 | Multiplies the best studio affinity, clamped to −1…1 |
| `externalScore` | 0.3 | Multiplies the external average minus `externalPivot`, clamped to ±2 |
| `externalPivot` | 7.0 | The external score treated as neutral |
| `catchUp` | 0.8 | Being watched with aired but unwatched episodes |
| `airing` | 0.4 | Currently airing |
| `globalBatch` | 10 | Cards per batch on the global page (1.6.2; 30 before) |
| `relatedBatch` | 5 | Items per batch in a record's related list (1.6.2) |
| `relatedCategory` | 2.0 | Related list: multiplies the category cosine of the two records |
| `relatedStudio` | 0.5 | Related list: the two records share a studio |
| `relatedRelation` | 3.0 | Related list: a database lists one as related to the other |
| `relatedBaseTitle` | 1.0 | Related list: the two records share a base title key |

## Documentation

### `String? encodeRelatedReason(RecommendationReason reason)` <a id="encoderelatedreason"></a>
- **Kind:** top-level function
- **Source:** `lib/features/recommendations/services/recommendation_service.dart` (approx. line 193)
- **Purpose:** Turn a related-list reason into a stored code.
- **Inputs:** `reason`.
- **Returns:** `categories:<id>,<id>`, `studio:<name>`, `relation:<type>` or `baseTitle`; null for a
  reason the related list does not produce.
- **Side effects:** None.
- **Algorithm:** A `switch` over the four related-list reason types.
- **Usage:** `RelatedRecommendationsCard._generate`.
- **Notes:** The codes are a persisted format in `recommendations.json`: add new ones, never rename.

### `RecommendationReason? decodeRelatedReason(String code)` <a id="decoderelatedreason"></a>
- **Kind:** top-level function
- **Source:** `lib/features/recommendations/services/recommendation_service.dart` (approx. line 208)
- **Purpose:** Turn a stored code back into a reason.
- **Inputs:** `code`.
- **Returns:** `RecommendationReason?` — null for a code this build does not know, including a
  relation type it does not know.
- **Side effects:** None.
- **Algorithm:** `baseTitle` is exact; otherwise split at the first `:` and match the prefix.
- **Usage:** `RelatedRecommendationsCard._row`.
- **Notes:** An unknown code stays on disk and is simply not shown, so a newer build's chips survive
  an older build.

### `String sequelTrashKey(AnimeExternalRelation sequel)` <a id="sequeltrashkey"></a>
- **Kind:** top-level function
- **Source:** `lib/features/recommendations/services/recommendation_service.dart` (approx. line 234)
- **Purpose:** Key a missing-sequel card.
- **Inputs:** `sequel`.
- **Returns:** `canonicalDatabaseKey(targetUrl)` (`anilist:1`, `mal:1`, `bgm:1`), else `targetUrl`,
  else `title`, else empty.
- **Side effects:** None.
- **Algorithm:** The first that exists.
- **Usage:** The recommendations page, to deduplicate the cards and as the `hiddenSequels` key.
- **Notes:** Through 1.6.1 the page deduplicated by raw URL, so the same sequel listed at `bgm.tv`
  and `bangumi.tv` could show twice.

### `double preferenceOf(Anime anime)` <a id="preferenceof"></a>
- **Kind:** top-level function
- **Source:** `lib/features/recommendations/services/recommendation_service.dart` (approx. line 267)
- **Purpose:** Read how much the user liked a record.
- **Inputs:** `anime`.
- **Returns:** `double` in −1…1.
- **Side effects:** None.
- **Algorithm:** With a rating, `(effectiveOverall − 6) / 4` clamped to −1…1. Without one:
  completed `+0.5`, dropped `−0.7`, anything else `0`.
- **Usage:** `RecommendationService.rank` (taste profile, studio affinity) and `writeAiReasons`
  (the compact profile).
- **Notes:** A rating always wins over the viewing status.

### `bool hasAiredUnwatched(Anime anime, DateTime nowJst)` <a id="hasairedunwatched"></a>
- **Kind:** top-level function
- **Source:** `lib/features/recommendations/services/recommendation_service.dart` (approx. line 282)
- **Purpose:** Report whether a record has aired episodes still unwatched.
- **Inputs:** `anime`, `nowJst`.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** Take `nextUnwatchedEpisode`; true when its computed air time
  (`getEpisodeAirDate`) exists and is not after `nowJst`.
- **Usage:** `_eligible` and the catch-up contribution in `rank`.
- **Notes:** A record without an air schedule never counts as having aired episodes.

### `bool isAiring(Anime anime, DateTime nowJst)` <a id="isairing"></a>
- **Kind:** top-level function
- **Source:** `lib/features/recommendations/services/recommendation_service.dart` (approx. line 295)
- **Purpose:** Report whether a record is currently airing.
- **Inputs:** `anime`, `nowJst`.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** True when `externalMeta.status` is `RELEASING` (AniList) or `Currently Airing`
  (MyAnimeList). Otherwise true only when the premiere is not in the future and the last episode's
  air time is still to come.
- **Usage:** The airing contribution in `rank`.
- **Notes:** The airing bonus has no reason chip.

### `static List<Recommendation> rank(List<Anime> library, {AiInsights? insights, Set<String> hidden = const {}, required DateTime nowJst, int limit = RecommendationWeights.globalBatch})` <a id="recommendationservice-rank"></a>
- **Kind:** static method of `RecommendationService`
- **Source:** `lib/features/recommendations/services/recommendation_service.dart` (approx. line 328)
- **Purpose:** Rank what to watch next.
- **Inputs:** `library`; `insights` — the AI categories from `ai_insights.json`; `hidden` — the ids in
  the global trash (`recommendations.json`, 1.6.2); `nowJst`; `limit` — the batch size, 10 (30
  through 1.6.1).
- **Returns:** `List<Recommendation>` — best first, at most `limit`.
- **Side effects:** None.
- **Algorithm:**
  1. Build a `SeriesIndex` and each record's effective categories (`resolveCategories`, with the AI
     categories from `insights`).
  2. **Taste profile:** for every record with a non-zero `preferenceOf`, add it to each of its
     categories; **studio affinity:** add it to each of its studios, remembering the best-liked
     record per studio. Normalise the profile by its Euclidean length.
  3. **Candidates:** skip hidden ids. For a series of two or more members, only its first member
     that is not completed is considered, once per series; if that member is hidden or not
     [`_eligible`](#recommendationservice-_eligible), the series offers nothing. A record outside
     such a series is a candidate when eligible.
  4. **Score** each candidate as the sum of its contributions: `nextInSeries` (+
     `nextInSeriesRatedHigh`) when the previous member is completed; `categoryMatch ×` the cosine of
     profile and categories; `studioMatch ×` the best studio affinity, clamped to −1…1;
     `externalScore × (averageNormalizedScore − 7)`, clamped to ±2; `catchUp` when being watched
     with aired unwatched episodes; `airing` when [`isAiring`](#isairing).
  5. **Reasons:** the contributions sorted largest first, keeping those that are positive and
     carry a reason, at most three. The category reason names up to two shared categories the
     profile likes; the studio reason is omitted when the liked record is the candidate itself.
  6. **Order:** with no rating and nothing completed anywhere (cold start), next-in-series first,
     then the external average, then the newest `createdAt`; otherwise by score. Ties fall back to
     the id, so the order is stable.
- **Usage:** `_RecommendationsPageState._load`; `test/recommendations_test.dart`.
- **Notes:** Season 3 is never offered before season 1 is finished. Missing sequels (not in the
  library) are not ranked here; the page appends them.

### `static List<Recommendation> related(Anime subject, List<Anime> library, {AiInsights? insights, Set<String> exclude = const {}, int limit = RecommendationWeights.relatedBatch})` <a id="recommendationservice-related"></a>
- **Kind:** static method of `RecommendationService`
- **Source:** `lib/features/recommendations/services/recommendation_service.dart` (approx. line 500)
- **Purpose:** Rank the library records related to one record (1.6.2).
- **Inputs:** `subject`; `library`; `insights` — AI categories; `exclude` — the subject's own related
  trash; `limit` — 5 by default.
- **Returns:** `List<Recommendation>` — best first, every score above zero.
- **Side effects:** None.
- **Algorithm:**
  1. Skip the subject, every member of its own series (`SeriesIndex.seriesOf`) and `exclude`.
  2. Contributions, from the weights below: a database relation between the two, in either direction
     — one's `externalMeta.relations` target matches the other's `databaseKeysOf`, any type —
     `relatedRelation`; the cosine of the two records' effective category sets,
     `|shared| / √(|a|·|b|)`, times `relatedCategory`; a shared studio, `relatedStudio`; a shared
     `seriesBaseKeys` key, `relatedBaseTitle`.
  3. A record with no contribution is dropped. Reasons are the contributions largest first, at most
     three.
  4. **One member per other series:** among members of the same series of two or more, keep the
     highest score; on a tie, the earlier member in series order.
  5. Sort by score, then id; cut to `limit`.
- **Usage:** `RelatedRecommendationsCard._generate`; `test/recommendations_test.dart`.
- **Notes:** Viewing status plays no part: the list answers "what is like this", not "what to watch
  next".

### `static bool _eligible(Anime anime, DateTime nowJst)` <a id="recommendationservice-_eligible"></a>
- **Kind:** static method of `RecommendationService` (private)
- **Source:** `lib/features/recommendations/services/recommendation_service.dart` (approx. line 604)
- **Purpose:** Say whether a record can be recommended at all.
- **Inputs:** `anime`, `nowJst`.
- **Returns:** `bool` — true for not started, or for being watched with aired unwatched episodes.
- **Side effects:** None.
- **Algorithm:** Switch on `viewingStatus`: `notStarted` → true; `watching` →
  [`hasAiredUnwatched`](#hasairedunwatched); anything else → false.
- **Usage:** `rank`, step 3.
- **Notes:** A watching record that is caught up is not a candidate.

### `static ExternalScoreReason? _bestExternal(Anime anime)` <a id="recommendationservice-_bestexternal"></a>
- **Kind:** static method of `RecommendationService` (private)
- **Source:** `lib/features/recommendations/services/recommendation_service.dart` (approx. line 616)
- **Purpose:** Pick the highest external score for a reason chip.
- **Inputs:** `anime`.
- **Returns:** `ExternalScoreReason?` — null when no source has a normalized score.
- **Side effects:** None.
- **Algorithm:** The rating in `externalMeta.ratings` with the highest `normalizedScore`.
- **Usage:** `rank`, the external-score contribution.
- **Notes:** The contribution uses the average of all sources; the chip shows the best single one.
