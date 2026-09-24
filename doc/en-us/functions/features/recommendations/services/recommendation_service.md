# lib/features/recommendations/services/recommendation_service.dart

The deterministic half of recommendations (1.6.0, M5): pure Dart, no model involved. It ranks the
library's own not-started and in-progress records and says why, as typed reasons the page turns into
chips. The weights are named constants in `RecommendationWeights`, in one place. The optional AI
reasons are layered on by [`ai_reason_service.md`](ai_reason_service.md). See
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
| `Recommendation.new` | constructor (`Recommendation`) | B | Create one ranked candidate: record, total score, at most three reasons. |
| [`preferenceOf`](#preferenceof) | top-level function | A | Read how much the user liked a record. |
| [`hasAiredUnwatched`](#hasairedunwatched) | top-level function | A | Report whether a record has aired episodes still unwatched. |
| [`isAiring`](#isairing) | top-level function | A | Report whether a record is currently airing. |
| `RecommendationService._` | constructor (`RecommendationService`) | B | Prevent instantiation; the service is static only. |
| [`RecommendationService.rank`](#recommendationservice-rank) | static method (`RecommendationService`) | A | Rank what to watch next. |
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

## Documentation

### `double preferenceOf(Anime anime)` <a id="preferenceof"></a>
- **Kind:** top-level function
- **Source:** `lib/features/recommendations/services/recommendation_service.dart` (approx. line 147)
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
- **Source:** `lib/features/recommendations/services/recommendation_service.dart` (approx. line 162)
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
- **Source:** `lib/features/recommendations/services/recommendation_service.dart` (approx. line 175)
- **Purpose:** Report whether a record is currently airing.
- **Inputs:** `anime`, `nowJst`.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** True when `externalMeta.status` is `RELEASING` (AniList) or `Currently Airing`
  (MyAnimeList). Otherwise true only when the premiere is not in the future and the last episode's
  air time is still to come.
- **Usage:** The airing contribution in `rank`.
- **Notes:** The airing bonus has no reason chip.

### `static List<Recommendation> rank(List<Anime> library, {AiInsights? insights, required DateTime nowJst, int limit = 30})` <a id="recommendationservice-rank"></a>
- **Kind:** static method of `RecommendationService`
- **Source:** `lib/features/recommendations/services/recommendation_service.dart` (approx. line 206)
- **Purpose:** Rank what to watch next.
- **Inputs:** `library`; `insights` — the AI categories and the hidden ids from
  `ai_insights.json`; `nowJst`; `limit`.
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

### `static bool _eligible(Anime anime, DateTime nowJst)` <a id="recommendationservice-_eligible"></a>
- **Kind:** static method of `RecommendationService` (private)
- **Source:** `lib/features/recommendations/services/recommendation_service.dart` (approx. line 371)
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
- **Source:** `lib/features/recommendations/services/recommendation_service.dart` (approx. line 383)
- **Purpose:** Pick the highest external score for a reason chip.
- **Inputs:** `anime`.
- **Returns:** `ExternalScoreReason?` — null when no source has a normalized score.
- **Side effects:** None.
- **Algorithm:** The rating in `externalMeta.ratings` with the highest `normalizedScore`.
- **Usage:** `rank`, the external-score contribution.
- **Notes:** The contribution uses the average of all sources; the chip shows the best single one.
