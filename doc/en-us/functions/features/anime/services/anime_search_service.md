# lib/features/anime/services/anime_search_service.dart

`AnimeSearchService` queries or scrapes five external anime databases (`bangumi.tv`, MyAnimeList via
Jikan v4, AniList, `acgsecrets.hk`, and `filmarks.com`) and returns normalized
`AnimeSearchResult`s; it also owns the title scorer (`similarityRaw`, `orderedSimilarity`,
`foldTitle`) and the alias harvest that [`anime1_service.md`](anime1_service.md) builds on — the
`anime1.me` watch-URL lookup moved there in 1.5.7. It is a plain shared utility available in **full builds only** — it does not
itself enforce that restriction; callers gate it (see
[`../../../../features/multi-source-search.md`](../../../../features/multi-source-search.md) for the
flavor-gating rule, the per-source field matrix, and the two-round language strategy). It depends on
[`../../../shared/utils/chinese_convert.md`](../../../shared/utils/chinese_convert.md) for
Simplified/Traditional Chinese query variants, and on
[`../models/anime.md`](../models/anime.md) for the `AnimeExternalMeta` record it produces. Its
results feed the "search online" flow in `anime_edit_page.dart`, the metadata refresh in
`anime_detail_page.dart`, and the desktop local API server.

`AnimeSearchResult` fields map onto `Anime` fields documented in
[`../../../../data-formats.md`](../../../../data-formats.md) (e.g. `sourceUrl` becomes `infoUrl`,
and the metadata block becomes `externalMeta`).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`AnimeSearchResult(...)`](#animesearchresult-new) | constructor (`AnimeSearchResult`) | A | Hold one normalized search hit from any source. |
| [`allTitles`](#alltitles) | getter (`AnimeSearchResult`) | A | Collect every title the result knows about, deduplicated. |
| `withRelations` | method (`AnimeSearchResult`) | B | Return a copy carrying `relations`; used by the bangumi.tv by-id fetch, whose relations arrive from a second request. |
| [`displayTitle`](#displaytitle) | getter (`AnimeSearchResult`) | B | Return the first known title, or `?`. |
| [`toJson`](#resulttojson) | method (`AnimeSearchResult`) | A | Serialize a fetched result so it can be cached on disk. |
| [`fromJson`](#resultfromjson) | factory (`AnimeSearchResult`) | A | Rebuild a cached result, defensively. |
| `AnimeSearchSource._()` | constructor (`AnimeSearchSource`) | B | Prevent instantiation of the source-name holder. |
| `AnimeSearchProgress(...)` | constructor (`AnimeSearchProgress`) | B | Hold one round's live search progress. |
| `done` | getter (`AnimeSearchProgress`) | B | How many sources have answered. |
| `total` | getter (`AnimeSearchProgress`) | B | How many sources this round queries. |
| [`fraction`](#searchprogressfraction) | getter (`AnimeSearchProgress`) | A | This round's completed fraction, or `null`. |
| `isPending` | method (`AnimeSearchProgress`) | B | Whether one source is still being waited on. |
| [`searchAll`](#searchall) | static method (`AnimeSearchService`) | A | Run the two-round cross-language search and return one ranked list, optionally handing out partial lists as sources answer. |
| [`_combine`](#combine) | static method (`AnimeSearchService`) | A | Merge per-source results into one deduplicated, ranked list. |
| [`queryVariants`](#queryvariants) | static method (`AnimeSearchService`) | A | Build the Simplified/Traditional variant set for a query. |
| [`relevance`](#relevance) | static method (`AnimeSearchService`) | A | Score a result against a query variant set, across all its titles. |
| [`_languageAffinity`](#languageaffinity) | static method (`AnimeSearchService`) | A | Report whether a result carries a title in the user's UI language. |
| [`toExternalMeta`](#toexternalmeta) | static method (`AnimeSearchService`) | A | Convert a search result into the persisted `AnimeExternalMeta` record. |
| [`fetchByUrl`](#fetchbyurl) | static method (`AnimeSearchService`) | A | Re-fetch one anime by id from the page URL it came from. |
| [`refreshAll`](#refreshall) | static method (`AnimeSearchService`) | A | Re-fetch several source pages in parallel, skipping failures. |
| [`_runRound`](#runround) | static method (`AnimeSearchService`) | A | Query the requested sources once, in parallel, tolerating failures. |
| [`_harvestBackfillTitles`](#harvestbackfilltitles) | static method (`AnimeSearchService`) | A | Pick cross-language titles from round one to search with in round two. |
| [`_searchBangumi`](#searchbangumi) | static method (`AnimeSearchService`) | A | Query bangumi.tv's v0 search API. |
| [`_fetchBangumiById`](#fetchbangumibyid) | static method (`AnimeSearchService`) | B | Fetch one bangumi.tv subject by numeric id, with its related subjects. |
| [`_fetchBangumiRelations`](#fetchbangumirelations) | static method (`AnimeSearchService`) | A | Fetch the works bangumi.tv lists as related to a subject; never throws. |
| [`mapBangumiSubject`](#mapbangumisubject) | static method (`AnimeSearchService`) | A | Map one bangumi.tv v0 subject object onto an `AnimeSearchResult`. |
| [`parseBangumiWeekday`](#parsebangumiweekday) | static method (`AnimeSearchService`) | A | Parse bangumi.tv's `放送星期` text onto Monday=1..Sunday=7. |
| [`_bangumiInfoboxText`](#bangumiinfoboxtext) | static method (`AnimeSearchService`) | B | Read one `infobox` entry as plain text. |
| [`_bangumiInfoboxList`](#bangumiinfoboxlist) | static method (`AnimeSearchService`) | B | Read one `infobox` entry as a list of strings. |
| [`_parseCjkDate`](#parsecjkdate) | static method (`AnimeSearchService`) | B | Parse a CJK-formatted date such as `2023年9月29日`. |
| [`_searchMAL`](#searchmal) | static method (`AnimeSearchService`) | A | Query MyAnimeList via the Jikan v4 API. |
| [`_fetchMalById`](#fetchmalbyid) | static method (`AnimeSearchService`) | B | Fetch one MyAnimeList entry by numeric id via Jikan's `/full`. |
| [`mapJikanAnime`](#mapjikananime) | static method (`AnimeSearchService`) | A | Map one Jikan anime object onto an `AnimeSearchResult`. |
| [`parseJikanDuration`](#parsejikanduration) | static method (`AnimeSearchService`) | A | Parse Jikan's prose duration string into minutes. |
| [`_namedList`](#namedlist) | static method (`AnimeSearchService`) | B | Read a Jikan `[{name: ...}]` array into a string list. |
| [`_searchAcgsecrets`](#searchacgsecrets) | static method (`AnimeSearchService`) | A | Fuzzy-match the query against recent acgsecrets.hk season pages. |
| [`_acgsecretsSeason`](#acgsecretsseason) | static method (`AnimeSearchService`) | A | Get one season page's entries, from the cache or the network. |
| `_fetchAcgsecretsSeason` | static method (`AnimeSearchService`) | B | Download and parse one acgsecrets.hk season page; `null` on a non-200 answer, a timeout or a network error, never throws. |
| [`parseAcgsecretsPage`](#parseacgsecretspage) | static method (`AnimeSearchService`), `@visibleForTesting` | A | Read every entry from an acgsecrets.hk season page's JSON-LD. |
| [`_acgsecretsItem`](#acgsecretsitem) | static method (`AnimeSearchService`) | A | Map one JSON-LD entry to a search result. |
| `_looseInt` | static method (`AnimeSearchService`) | B | Read an integer that may arrive as a number or a numeric string; `null` for anything else. |
| [`acgsecretsSeasons`](#acgsecretsseasons) | static method (`AnimeSearchService`), `@visibleForTesting` | A | List the acgsecrets.hk season pages worth searching. |
| [`_containsJapanese`](#containsjapanese) | static method (`AnimeSearchService`) | A | Check whether a string contains Hiragana/Katakana characters. |
| [`_isLatinScript`](#islatinscript) | static method (`AnimeSearchService`) | A | Check whether a string is written in Latin script. |
| [`_isLikelyChinese`](#islikelychinese) | static method (`AnimeSearchService`) | A | Check whether a string reads as Chinese rather than Japanese. |
| [`_searchFilmarks`](#searchfilmarks) | static method (`AnimeSearchService`) | A | Scrape filmarks.com's search results HTML. |
| [`_searchAniList`](#searchanilist) | static method (`AnimeSearchService`) | A | Query the AniList GraphQL API. |
| [`_fetchAniListById`](#fetchanilistbyid) | static method (`AnimeSearchService`) | B | Fetch one AniList media entry by numeric id. |
| [`_postAniList`](#postanilist) | static method (`AnimeSearchService`) | B | POST a GraphQL document to AniList and return its `data` object. |
| [`mapAniListMedia`](#mapanilistmedia) | static method (`AnimeSearchService`) | A | Map one AniList media object onto an `AnimeSearchResult`. |
| `_relation` | static method (`AnimeSearchService`) | B | Build one relation from a source's raw relation name; an unknown name becomes `other` with `rawType` kept. |
| [`mapAniListRelations`](#mapanilistrelations) | static method (`AnimeSearchService`), `@visibleForTesting` | A | Map AniList relation edges onto relations. |
| [`mapJikanRelations`](#mapjikanrelations) | static method (`AnimeSearchService`), `@visibleForTesting` | A | Map Jikan's `/full` relations onto relations. |
| [`mapBangumiRelations`](#mapbangumirelations) | static method (`AnimeSearchService`), `@visibleForTesting` | A | Map bangumi.tv's related-subjects list onto relations. |
| [`_aniListDate`](#anilistdate) | static method (`AnimeSearchService`) | B | Build a `DateTime` from an AniList `{year, month, day}` object. |
| [`_aniListFirstAiringAt`](#anilistfirstairingat) | static method (`AnimeSearchService`) | A | Pick the airing timestamp that best describes the broadcast slot. |
| [`_jstBroadcastSlot`](#jstbroadcastslot) | static method (`AnimeSearchService`) | A | Map a Japan-time airing moment onto the broadcast slot it is filed under. |
| [`_alignFirstAirDateToSlot`](#alignfirstairdatetoslot) | static method (`AnimeSearchService`) | A | Move a first-air date back onto the late-night slot's calendar day. |
| [`_toDouble`](#todouble) | static method (`AnimeSearchService`) | B | Coerce a JSON number into a `double`. |
| [`parseDayOfWeek`](#parsedayofweek) | static method (`AnimeSearchService`) | A | Parse an English weekday name prefix into `1..7` (Monday..Sunday). |
| [`harvestAliases`](#harvestaliases) | static method (`AnimeSearchService`) | A | Fetch alternate titles for a query from bangumi.tv, for the anime1.me lookup. |
| [`aliasCandidatesFrom`](#aliascandidatesfrom) | static method (`AnimeSearchService`), `@visibleForTesting` | A | Pick Chinese and Latin alias strings out of confident search hits. |
| [`bestSimilarity`](#bestsimilarity) | static method (`AnimeSearchService`) | A | Compute the best fuzzy-similarity score of a title against any of several query variants. |
| [`_similarity`](#similarity) | static method (`AnimeSearchService`) | A | Fuzzy similarity on the strings as given and on their folded, Simplified forms. |
| [`similarityRaw`](#similarityraw) | static method (`AnimeSearchService`) | A | The three-measure similarity core (LCS-Dice, character-set Dice, containment) with no normalization. |
| [`orderedSimilarity`](#orderedsimilarity) | static method (`AnimeSearchService`) | A | Order-aware similarity only — LCS-Dice or containment. |
| [`foldTitle`](#foldtitle) | static method (`AnimeSearchService`) | A | Normalize a title for matching: halfwidth, lowercase, no punctuation, Simplified. |
| [`_lcsLength`](#lcslength) | static method (`AnimeSearchService`) | A | Longest common subsequence length between two strings. |
| [`decodeHtmlEntities`](#decodehtmlentities) | static method (`AnimeSearchService`) | B | Decode the handful of HTML entities that appear in scraped titles. |
| `_BackfillTitles(...)` | constructor (`_BackfillTitles`) | B | Hold one harvested title per language family. |
| `hasAny` | getter (`_BackfillTitles`) | B | Report whether any usable title was harvested. |

Note on the verification count: the source file has 71 `/// Purpose:` doc comments as of 1.6.1
(65 in 1.6.0, 59 in 1.5.7; M2 added six for relation metadata). 1.6.1 added seven — `_combine` and
six acgsecrets.hk helpers — and removed one, `_recentSeasons`, which `acgsecretsSeasons` replaced.
The historical one-row surplus — `searchAnime1` carried a plain (non-`Purpose:`) doc comment — is
gone with that method, which moved to `anime1_service.dart` as `search` and gained a full block.

Twelve declarations (`mapBangumiSubject`, `parseBangumiWeekday`, `mapJikanAnime`,
`parseJikanDuration`, `mapAniListMedia`, `parseDayOfWeek`, `aliasCandidatesFrom`,
`mapAniListRelations`, `mapJikanRelations`, `mapBangumiRelations`, and, since 1.6.1,
`parseAcgsecretsPage` and `acgsecretsSeasons`) are marked `@visibleForTesting`. They are
public solely so `test/anime_search_test.dart`, `test/relations_test.dart` and
`test/search_aggregation_test.dart` can exercise the source-format parsing against
fixture JSON or HTML — the HTTP calls are static and take no injectable client, so the mappers are the only
practical seam. Do not call them from production code outside this file.

Five static fields carry a plain doc comment but no `Purpose:` block, so they have no row:

| Field | Meaning |
|---|---|
| `debugSourceOverrides` | `@visibleForTesting` (1.6.1). Test-only replacements for the per-source fetchers, keyed by source name, so [`_runRound`](#runround) can be exercised without the network. Always `null` in the app; `test/search_aggregation_test.dart` sets it. |
| `_acgsecretsPageTtl` | 30 minutes — how long a downloaded acgsecrets.hk season page is reused (1.6.1). |
| `_acgsecretsTimeout` | 15 seconds — the per-request timeout for one season page (1.6.1). |
| `_acgsecretsPages` | The in-memory page cache: season code → `(at, items)`, where `items` is the in-flight or completed `Future<List<AnimeSearchResult>?>`, so two searches started together share one download (1.6.1). |
| `_acgsecretsLdPattern` | The `<script type="application/ld+json">` regex, hoisted out of the per-page loop (1.6.1). |

## Documentation

### `const AnimeSearchResult({required source, sourceUrl, title, titleJa, titleRomaji, titleEn, synonyms, episodes, firstAirDate, airDayOfWeek, airTime, endDate, format, status, durationMinutes, genres, studios, score, scoreMax, scoreVotes, scoreRank, coverImageUrl, summary, relations})` <a id="animesearchresult-new"></a>
- **Kind:** constructor of `AnimeSearchResult`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (approx. line 72)
- **Purpose:** Hold one normalized search result, whatever the originating source, in a shape ready to prefill the anime edit form.
- **Inputs:** `source` required (the source's display name, e.g. `'bangumi.tv'`); everything else optional since no single source supplies every field. `synonyms`, `genres`, `studios`, and `relations` default to empty lists; `scoreMax` defaults to `10`. `relations` is filled only by the by-id fetches — search results never carry it.
- **Returns:** A new `AnimeSearchResult`.
- **Side effects:** None.
- **Algorithm:** Plain field assignment via `const` constructor.
- **Notes:** `sourceUrl` becomes `Anime.infoUrl` when a result is applied, and is also the key a later refresh re-queries. Every source's score is normalized onto a 10-point scale before it reaches `score`, so `scoreMax` is `10` in practice for all current sources. See the field matrix in [`../../../../features/multi-source-search.md`](../../../../features/multi-source-search.md) for which source fills which field.

### `List<String> get allTitles` <a id="alltitles"></a>
- **Kind:** getter of `AnimeSearchResult`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 100)
- **Purpose:** Collect every title this result knows about, in display order.
- **Returns:** `List<String>` — deduplicated, blank-filtered.
- **Side effects:** None.
- **Algorithm:** Walks `title`, `titleJa`, `titleRomaji`, `titleEn`, then each `synonym`; trims each, skips empties, and keeps first-seen order using a `Set<String>`.
- **Usage:**
  ```dart
  for (final title in r.allTitles) { /* one SelectableText per title */ }
  ```
  (`lib/features/anime/views/anime_search_dialog.dart`, `_showResultDetails`)
- **Notes:** Used for three things: relevance scoring, the long-press detail sheet, and harvesting cross-language backfill queries. Order matters — `title` first means the display fallback prefers the localized title.

### `String get displayTitle` <a id="displaytitle"></a>
- **Kind:** getter of `AnimeSearchResult`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 116)
- **Purpose:** Return the best title to show as the result's headline.
- **Returns:** `String` — the first entry of `allTitles`, or `'?'` when there are none.
- **Side effects:** None.
- **Notes:** Replaces the older inline `r.title ?? r.titleJa ?? '?'` in the dialog, which could not see romaji or English titles.

### `Map<String, dynamic> toJson()` <a id="resulttojson"></a>
- **Kind:** method of `AnimeSearchResult`
- **Purpose:** Serialize a fetched result so it can be cached on disk.
- **Returns:** `Map<String, dynamic>` holding only the non-null, non-empty fields.
- **Side effects:** None.
- **Notes:** Added in 1.5.0 to back the background update cache, which downloads a candidate once
  and then applies it without going back to the network. Null and empty fields are omitted so the
  cache file stays small and readable. Since 1.6.0 non-empty `relations` are written too, through
  `AnimeExternalRelation.toJson`, and `fromJson` reads them back.

  `firstAirDate` and `endDate` are **calendar days, not instants**: they are written as-is and read
  back without a UTC conversion, matching `_parseCalendarDate` in the anime model. Normalizing them
  to UTC would render the previous day in every timezone east of UTC — including Japan.

### `factory AnimeSearchResult.fromJson(Map<String, dynamic>)` <a id="resultfromjson"></a>
- **Kind:** factory constructor of `AnimeSearchResult`
- **Purpose:** Rebuild a cached result from its JSON form.
- **Side effects:** None.
- **Notes:** Every field is read defensively — a cache written by a newer build, or hand-edited,
  yields nulls rather than throwing. `source` falls back to an empty string so a malformed entry is
  still readable and can be discarded by the caller rather than taking the whole file down with it.

### `static Future<List<AnimeSearchResult>> searchAll(String query, {String? preferredLanguage, void Function(AnimeSearchProgress)? onProgress, void Function(List<AnimeSearchResult> soFar)? onResults})` <a id="searchall"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (approx. line 374)
- **Purpose:** Query every metadata source and return one deduplicated, relevance-ranked list.
- **Inputs:** `query`; `preferredLanguage` — the UI language tag (e.g. `zh_TW`, `ja`) passed by the caller; `onProgress` — per-round progress snapshots; `onResults` (1.6.1) — receives the combined, sorted list so far each time a source answers with results.
- **Returns:** `Future<List<AnimeSearchResult>>` — equal to the last list passed to `onResults`, or empty when nothing was found.
- **Side effects:** Issues HTTP requests to five external services concurrently, and to a subset of them a second time when cross-language backfill runs. Calls `onResults` once per source that answers with a non-empty list, in either round.
- **Algorithm:**
  1. Build `variants = queryVariants(query)` and an empty per-source map `combined`. A local `sourceDone(source, results)` ignores an empty list; otherwise it appends `results` to `combined[source]` and calls `onResults` with [`_combine`](#combine)`(combined, …)`.
  2. **Round one** via [`_runRound`](#runround), passing `sourceDone` as `onSourceDone`, with per-source language targeting: bangumi.tv gets the Simplified form, acgsecrets.hk the Traditional form, filmarks.com the raw query (with `Accept-Language: ja`), and MyAnimeList/AniList the raw query.
  3. Compute the set of sources that returned nothing. If it is empty, skip to step 6.
  4. Harvest up to three cross-language titles via [`_harvestBackfillTitles`](#harvestbackfilltitles). If nothing was harvested, skip to step 6.
  5. **Round two** via `_runRound`, again with `onSourceDone: sourceDone`, passing a query *only* for the empty sources, each in its own language. MyAnimeList and AniList fall back to the harvested Japanese title when no Latin one was found, since both index native titles too.
  6. Return `_combine(combined, variants, preferredLanguage)`.
- **Usage:**
  ```dart
  final results = await AnimeSearchService.searchAll(
    query,
    preferredLanguage: language,
    onProgress: (progress) {
      if (current()) setState(() => _progress = progress);
    },
    onResults: (soFar) {
      if (current()) setState(() => _results = soFar);
    },
  );
  ```
  (`lib/features/anime/views/anime_search_dialog.dart`, `_search`)
- **Notes:** Replaces the pre-1.4.0 single round, which sent every source the raw query and only special-cased bangumi.tv for Simplified/Traditional. There is exactly one extra round — no recursion — so the worst case roughly doubles latency, and each source still fails independently via `.catchError`. Before 1.6.1 nothing was returned until every source of both rounds had finished, so one slow source held back every result; `onResults` lets the dialog show results as they land. `anime1.me` is deliberately not part of `searchAll`; its lookup lives in [`anime1_service.md`](anime1_service.md).

### `static List<AnimeSearchResult> _combine(Map<String, List<AnimeSearchResult>> bySource, List<String> variants, String? preferredLanguage)` <a id="combine"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (approx. line 441)
- **Purpose:** Merge per-source results into one deduplicated, ranked list.
- **Inputs:** `bySource` — results keyed by source name; `variants` — from [`queryVariants`](#queryvariants); `preferredLanguage`.
- **Returns:** `List<AnimeSearchResult>` — deduplicated by `sourceUrl` (falling back to `title`, then `titleJa`), sorted by descending [`relevance`](#relevance), ties broken by source name.
- **Side effects:** None.
- **Algorithm:**
  1. Deduplicate, iterating sources in `AnimeSearchSource.all` order and keeping the first result per key, so the output is stable.
  2. Sort by descending `relevance(r, variants, preferredLanguage: …)`, breaking ties by source name.
- **Notes:** Added in 1.6.1, when the end of `searchAll` was split out so it can run after every source answers. Because it depends only on the results, never on which source happened to answer first, each intermediate list and the final one are ordered the same way.

### `static List<String> queryVariants(String query)` <a id="queryvariants"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 250)
- **Purpose:** Build the Simplified/Traditional query variants used everywhere.
- **Inputs:** `query`.
- **Returns:** `List<String>` — the trimmed raw query first, then any distinct variants; blanks dropped.
- **Side effects:** None.
- **Algorithm:** A `Set<String>` of `{trimmed, toSimplified(trimmed), toTraditional(trimmed)}`, filtered for non-empty. A query with no Han characters collapses to a single entry.
- **Notes:** Public so the search dialog can score results with exactly the variant set the service searched with, rather than re-deriving it and drifting.

### `static double relevance(AnimeSearchResult result, List<String> queries, {String? preferredLanguage})` <a id="relevance"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 270)
- **Purpose:** Score how well a result matches a set of query variants.
- **Inputs:** `result`, `queries` (normally from [`queryVariants`](#queryvariants)); `preferredLanguage` — the UI language tag whose titles should win a near-tie.
- **Returns:** `double` in `0.0..1.05`.
- **Side effects:** None.
- **Algorithm:** Runs [`bestSimilarity`](#bestsimilarity) over every entry of `result.allTitles`, keeps the maximum, then adds `_languageBonus` (0.05) when [`_languageAffinity`](#languageaffinity) says the result carries a title in `preferredLanguage`.
- **Usage:**
  ```dart
  double _relevance(AnimeSearchResult r) => AnimeSearchService.relevance(
    r, _queryVariants, preferredLanguage: _searchLanguage,
  );
  ```
  (`lib/features/anime/views/anime_search_dialog.dart`, `_relevance`)
- **Notes:** Scoring *every* title is what makes ranking language-neutral: a hit whose Japanese title matches a Japanese query ranks as highly as one whose Chinese title matches a Chinese query. The language bonus is deliberately far smaller than the spread between a good and a bad fuzzy match, so it reorders results that already match about equally well and can never lift a worse match above a better one. The dialog passes the same language it searched with, so re-sorting there reproduces the service's order exactly rather than drifting on ties.

### `static double _languageAffinity(AnimeSearchResult result, String? languageTag)` <a id="languageaffinity"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 290)
- **Purpose:** Report whether a result carries a title in the user's UI language.
- **Returns:** `double` — `1` when it does, `0` otherwise (including a null or empty tag).
- **Side effects:** None.
- **Algorithm:** A `ja` tag checks `titleJa` through [`_containsJapanese`](#containsjapanese); a `zh` tag checks `title` through [`_isLikelyChinese`](#islikelychinese); any other (Latin-script) tag checks for a non-null `titleEn` or `titleRomaji`.
- **Notes:** Matches on the tag's language prefix, so `zh`, `zh_CN`, and `zh_TW` behave identically — the Simplified/Traditional distinction is already handled by the query variants, not here.

### `static AnimeExternalMeta toExternalMeta(AnimeSearchResult result, {DateTime? fetchedAt})` <a id="toexternalmeta"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (approx. line 512)
- **Purpose:** Convert a search result into the persisted external-metadata record.
- **Inputs:** `result`; `fetchedAt` — override for the timestamp, used by tests.
- **Returns:** `AnimeExternalMeta`.
- **Side effects:** None.
- **Algorithm:** Copies the metadata fields straight across, then, when the source reported any of `score`/`scoreVotes`/`scoreRank`, appends a single `AnimeExternalRating` carrying `source`, `sourceUrl`, the score, `scoreMax`, votes, rank, and `fetchedAt` (UTC). `relations` are passed through unchanged. `refreshedAt` is set to the same timestamp.
- **Usage:**
  ```dart
  final fetched = AnimeSearchService.toExternalMeta(r);
  result['externalMeta'] = widget.currentExternalMeta?.mergedWith(fetched) ?? fetched;
  ```
  (`lib/features/anime/views/anime_search_dialog.dart`, `_apply`)
- **Notes:** The user's personal `AnimeRating` is never involved — external scores live only in `externalMeta.ratings`. Keeping `sourceUrl` on each rating entry is what makes [`refreshAll`](#refreshall) possible later; a source with no score contributes metadata but no rating entry, and therefore nothing to refresh from beyond `infoUrl`.

### `static Future<AnimeSearchResult?> fetchByUrl(String url)` <a id="fetchbyurl"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (approx. line 556)
- **Purpose:** Re-fetch one anime's metadata from the page URL it came from.
- **Inputs:** `url` — an AniList, MyAnimeList, or bangumi.tv subject page URL.
- **Returns:** `Future<AnimeSearchResult?>` — `null` when the host is not one of the three API-backed sources, or when the fetch fails. Since 1.6.0 the result carries the source's `relations`.
- **Side effects:** One HTTP request to the matching API; two for bangumi.tv (the subject, then its related subjects).
- **Algorithm:** Regex-matches the numeric id out of `anilist.co/anime/(\d+)`, `myanimelist.net/anime/(\d+)`, or `(?:bgm\.tv|bangumi\.tv|chii\.in)/subject/(\d+)`, in that order, and dispatches to the matching by-id fetch. Falls through to `null`.
- **Notes:** `acgsecrets.hk` and `filmarks.com` are scraped rather than queried by id, so they have no stable by-URL endpoint and are skipped. Each by-id fetch reuses the *same* mapper as its search path, so search and refresh cannot drift apart.

### `static Future<List<AnimeSearchResult>> refreshAll(Iterable<String> urls)` <a id="refreshall"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 382)
- **Purpose:** Re-fetch several source pages at once for a metadata refresh.
- **Inputs:** `urls`.
- **Returns:** `Future<List<AnimeSearchResult>>` — only the fetches that succeeded.
- **Side effects:** One HTTP request per recognized URL, issued in parallel.
- **Algorithm:** Drops blanks, deduplicates, runs `fetchByUrl` for each under `Future.wait` with a per-URL `.catchError((_) => null)`, then filters out the nulls with `whereType`.
- **Usage:**
  ```dart
  final results = await AnimeSearchService.refreshAll(urls);
  ```
  (`lib/features/anime/views/anime_detail_page.dart`, `_refreshExternalMeta`)
- **Notes:** A failing or unrecognized URL is skipped rather than failing the whole refresh, matching how `searchAll` tolerates a dead source.

### `static Future<Map<String, List<AnimeSearchResult>>> _runRound({required bangumiQuery, required acgsecretsQuery, required filmarksQuery, required globalQuery, malQuery, anilistQuery, round, onProgress, onSourceDone})` <a id="runround"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (approx. line 681)
- **Purpose:** Query the requested sources once, in parallel, tolerating failures.
- **Inputs:** one query per source; `globalQuery` is the default for MyAnimeList and AniList, overridden by `malQuery`/`anilistQuery` in the backfill round. `round` labels the emitted progress; `onProgress` receives one snapshot when the round starts and one more as each source answers; `onSourceDone` (1.6.1) receives each source's results as soon as that source answers successfully.
- **Returns:** `Future<Map<String, List<AnimeSearchResult>>>` keyed by source name.
- **Side effects:** One HTTP request per non-null, non-blank query, unless `debugSourceOverrides` replaces the fetcher.
- **Algorithm:** A local `run(source, query, fetch)` returns an immediately-completed empty list when the query is `null` or blank. Otherwise it picks `debugSourceOverrides?[source] ?? fetch`, calls it with `query.trim()`, and on success records the count, calls `onSourceDone(source, results)` and **then** emits progress; a failure is recorded in `failed` and becomes `[]`. All five futures are awaited together and zipped back onto their source names.
- **Notes:** A `null` or blank query means "skip this source in this round" — that is exactly how round two addresses only the sources that came back empty. Keeping the return keyed by source is what lets `searchAll` tell "returned nothing" from "was not asked". Results go out before the progress snapshot so a listener reacting to the snapshot already sees that source's results — it never sees a count without the results.

### `static _BackfillTitles _harvestBackfillTitles(Map<String, List<AnimeSearchResult>> round, List<String> queryVariants)` <a id="harvestbackfilltitles"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 442)
- **Purpose:** Pick cross-language titles from round one to search with in round two.
- **Inputs:** `round` — round one's per-source results; `queryVariants`.
- **Returns:** `_BackfillTitles` with at most one Japanese, one Latin-script, and one Chinese title.
- **Side effects:** None.
- **Algorithm:**
  1. Collect results scoring at least `_backfillMinRelevance` (0.45), stopping at `_maxBackfillTitles * 2` candidates.
  2. For the Japanese slot, take the first `titleJa`-or-synonym that passes [`_containsJapanese`](#containsjapanese); for the Latin slot, the first `titleRomaji`/`titleEn`/synonym that passes [`_isLatinScript`](#islatinscript); for the Chinese slot, the first `title`-or-synonym that passes [`_isLikelyChinese`](#islikelychinese).
  3. Stop as soon as all three slots are filled.
  4. Return the Chinese title in both Simplified and Traditional forms.
- **Notes:** The relevance floor is the whole safety mechanism — without it, one stray unrelated hit from a fuzzy-matching source would hijack the second round and pull in results for a different show entirely.

### `static Future<List<AnimeSearchResult>> _searchBangumi(String query)` <a id="searchbangumi"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 498)
- **Purpose:** Query bangumi.tv's **v0** subject-search API and map up to `_maxPerSource` hits.
- **Inputs:** `query` — in practice the Simplified variant, since bangumi.tv is a mainland-Chinese site.
- **Returns:** `Future<List<AnimeSearchResult>>` — `[]` on a non-200 response or a missing `data` field.
- **Side effects:** One HTTP POST (15s timeout) to `api.bgm.tv`.
- **Algorithm:** POSTs `{"keyword": query, "filter": {"type": [2]}}` to `https://api.bgm.tv/v0/search/subjects?limit=10`, then maps each item through [`mapBangumiSubject`](#mapbangumisubject).
- **Notes:** `filter.type: [2]` restricts results to the anime subject type. **This moved off the legacy endpoint in 1.4.0.** `GET /search/subject/<query>` — used from the first release through 1.3.3 — now answers `502 Bad gateway` from Cloudflare for every request, and because the method treats any non-200 as "no results", bangumi.tv had silently dropped out of search entirely with no error surfaced anywhere. The v0 API also returns strictly more: `infobox` carries the broadcast weekday, alternate titles, studio, and end date, none of which the legacy search response had.

### `static Future<AnimeSearchResult?> _fetchBangumiById(int id)` <a id="fetchbangumibyid"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (approx. line 842)
- **Purpose:** Fetch one bangumi.tv subject by its numeric id, with the works it lists as related.
- **Returns:** `Future<AnimeSearchResult?>` — `null` on a non-200 response or a body with no `id`.
- **Side effects:** Two HTTP GETs (10s timeout each) to `api.bgm.tv`: the subject, then [`_fetchBangumiRelations`](#fetchbangumirelations).
- **Notes:** The path is `/v0/subjects/{id}` — **plural**. The singular `/v0/subject/{id}` returns 404, and the legacy `/subject/{id}` is 502 like the rest of that API. The response has the same shape as v0 search, so one mapper serves both paths. Since 1.6.0 the relations are attached through `withRelations`; if the second request fails, the subject is returned without them.

### `static Future<List<AnimeExternalRelation>> _fetchBangumiRelations(int id)` <a id="fetchbangumirelations"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (approx. line 865)
- **Purpose:** Fetch the works bangumi.tv lists as related to a subject.
- **Inputs:** `id` — the subject id.
- **Returns:** `Future<List<AnimeExternalRelation>>` — empty on a non-200 response, a non-list body, a timeout or any other error.
- **Side effects:** One HTTP GET (10s timeout) to `https://api.bgm.tv/v0/subjects/{id}/subjects`, with the app's `User-Agent`.
- **Algorithm:** Decodes the body as UTF-8 JSON and, when it is a list, maps it through [`mapBangumiRelations`](#mapbangumirelations). The whole call sits in a `try`/`catch`.
- **Notes:** Never throws: relations are an extra, and a subject without them still refreshes. This is the one extra request M2 adds per bangumi.tv refresh; AniList and Jikan deliver relations in the request they already make.

### `static AnimeSearchResult mapBangumiSubject(Map<String, dynamic> m)` <a id="mapbangumisubject"></a>
- **Kind:** static method of `AnimeSearchService`, `@visibleForTesting`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 561)
- **Purpose:** Map one bangumi.tv v0 subject object onto an `AnimeSearchResult`.
- **Inputs:** `m` — a v0 subject map, from either search or the by-id endpoint.
- **Returns:** `AnimeSearchResult`.
- **Side effects:** None.
- **Algorithm:** Prefers `name_cn` for `title` (null when blank) and `name` for `titleJa`; reads `eps` (falling back to `total_episodes`), the ISO `date` field, `rating.score`/`rating.total`/`rating.rank`, `images.large`/`images.common`/`image`, and the five most-used `tags` as genres. The schedule and remaining titles come out of `infobox`: `别名` → `synonyms`, `动画制作` → `studios`, `放送星期` → `airDayOfWeek` via [`parseBangumiWeekday`](#parsebangumiweekday), `播放结束` → `endDate` via [`_parseCjkDate`](#parsecjkdate).
- **Notes:** `eps` wins over `total_episodes` because the latter counts specials — for *Frieren* they are 28 and 36 respectively, and 28 is the TV run the app schedules. bangumi.tv scores are already on a 10-point scale, so they are stored unscaled. Note `rank` moved: it is `rating.rank` in v0, not a top-level field as in the legacy shape.

### `static String? _bangumiInfoboxText(List<dynamic>? infobox, String key)` <a id="bangumiinfoboxtext"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 612)
- **Purpose:** Read one `infobox` entry as plain text.
- **Returns:** `String?` — `null` when the key is absent or its value is not a plain string.
- **Side effects:** None.
- **Notes:** bangumi's `infobox` is a list of `{key, value}` where `value` is *either* a string or a list of `{v: ...}` maps depending on the field; this reads only the string form, and [`_bangumiInfoboxList`](#bangumiinfoboxlist) handles the other.

### `static List<String> _bangumiInfoboxList(List<dynamic>? infobox, String key)` <a id="bangumiinfoboxlist"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 630)
- **Purpose:** Read one `infobox` entry as a list of strings.
- **Returns:** `List<String>` — empty when the key is absent.
- **Side effects:** None.
- **Algorithm:** A bare string value becomes a one-element list; a list value is flattened to its `{v: ...}` entries, blanks dropped.
- **Notes:** Accepting both shapes matters because the same key varies by entry — `动画制作` is usually a bare string while `别名` is usually a list, but editors are free to enter either.

### `static int? parseBangumiWeekday(String? value)` <a id="parsebangumiweekday"></a>
- **Kind:** static method of `AnimeSearchService`, `@visibleForTesting`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 663)
- **Purpose:** Parse bangumi.tv's `放送星期` text onto Monday=1..Sunday=7.
- **Inputs:** `value` — e.g. `星期五`, `週六`, `金曜日`.
- **Returns:** `int?` — `null` when nothing recognizable matches.
- **Side effects:** None.
- **Algorithm:** Walks Monday..Sunday, testing each day's Chinese numeral and Japanese stem against the `星期X` / `週X` / `周X` / `X曜` forms; Sunday additionally accepts `日` and `天`.
- **Notes:** The v0 API states the broadcast day as **free text**, not a number as the legacy `air_weekday` field did, and entries appear in Simplified, Traditional, or Japanese depending on who edited them. An unrecognized value (`不定期`, a blank) becomes "no data" rather than a guess, because a wrong weekday silently mis-schedules every episode.

### `static DateTime? _parseCjkDate(String? value)` <a id="parsecjkdate"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 693)
- **Purpose:** Parse a CJK-formatted date such as `2023年9月29日`.
- **Returns:** `DateTime?` — `null` when the text holds no such date.
- **Side effects:** None.
- **Notes:** Needed because `infobox` dates are prose, unlike the ISO `date` field on the subject itself.

### `static Future<List<AnimeSearchResult>> _searchMAL(String query)` <a id="searchmal"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 712)
- **Purpose:** Query MyAnimeList via the public Jikan v4 API and map up to `_maxPerSource` hits.
- **Returns:** `Future<List<AnimeSearchResult>>` — `[]` on a non-200 response or missing `data`.
- **Side effects:** One HTTP GET (10s timeout) to `api.jikan.moe`.
- **Algorithm:** GETs `https://api.jikan.moe/v4/anime?q=<urlencoded query>&limit=10`, then maps each item through [`mapJikanAnime`](#mapjikananime).
- **Notes:** Jikan indexes titles in every language, so it receives the raw query rather than a script-specific variant.

### `static Future<AnimeSearchResult?> _fetchMalById(int id)` <a id="fetchmalbyid"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (approx. line 1074)
- **Purpose:** Fetch one MyAnimeList entry by its numeric id via Jikan.
- **Returns:** `Future<AnimeSearchResult?>` — `null` on a non-200 response or a non-map `data`.
- **Side effects:** One HTTP GET (10s timeout) to `api.jikan.moe`.
- **Notes:** The `/full` variant returns the same object shape as search, plus the `relations` that [`mapJikanRelations`](#mapjikanrelations) reads since 1.6.0, so `mapJikanAnime` handles both.

### `static AnimeSearchResult mapJikanAnime(Map<String, dynamic> m)` <a id="mapjikananime"></a>
- **Kind:** static method of `AnimeSearchService`, `@visibleForTesting`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 764)
- **Purpose:** Map one Jikan anime object onto an `AnimeSearchResult`.
- **Returns:** `AnimeSearchResult`.
- **Side effects:** None.
- **Algorithm:**
  1. Read covers from `images.jpg`, and `aired.from`/`aired.to` via `DateTime.tryParse`.
  2. From `broadcast`, parse `day` through [`parseDayOfWeek`](#parsedayofweek); take `time` **only** when `timezone` is absent or `Asia/Tokyo`.
  3. Walk the `titles` array, routing `Default` → `titleRomaji`, `English` → `titleEn`, `Japanese` → `titleJa`, and everything else into `synonyms`; fall back to the flat `title`/`title_english`/`title_japanese` fields for any slot the array left empty.
  4. Read `episodes`, `type` → `format`, `status`, `duration` via [`parseJikanDuration`](#parsejikanduration), `studios`/`genres` via [`_namedList`](#namedlist), and `score`/`scored_by`/`rank`.
  5. Map `relations` through [`mapJikanRelations`](#mapjikanrelations) — empty for search results, which carry none.
- **Notes:** The timezone gate is the important part. Jikan reports `broadcast.time` in whatever timezone `broadcast.timezone` names; storing a non-Tokyo time as `Anime.airTime` would label it Japan time and shift every episode. Dropping it leaves the field empty, which the UI handles.

### `static int? parseJikanDuration(String? duration)` <a id="parsejikanduration"></a>
- **Kind:** static method of `AnimeSearchService`, `@visibleForTesting`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 867)
- **Purpose:** Parse Jikan's human-readable duration string into minutes.
- **Inputs:** `duration` — e.g. `"24 min per ep"`, `"1 hr 35 min"`, `"Unknown"`.
- **Returns:** `int?` — `null` when nothing parseable is present or the total is zero.
- **Side effects:** None.
- **Algorithm:** Independently matches `(\d+)\s*hr` and `(\d+)\s*min`, sums `h * 60 + m`, and returns `null` when neither matched.
- **Notes:** Jikan reports duration as prose, not a number, so hours and minutes have to be extracted separately rather than parsed as one value.

### `static List<String> _namedList(Object? value)` <a id="namedlist"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 883)
- **Purpose:** Read a Jikan `[{name: ...}]` array into a plain string list.
- **Returns:** `List<String>` — empty for a non-list or for entries with no string `name`.
- **Side effects:** None.
- **Notes:** Jikan wraps `studios` and `genres` identically, so one helper covers both.

### `static Future<List<AnimeSearchResult>> _searchAcgsecrets(String query)` <a id="searchacgsecrets"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (approx. line 1298)
- **Purpose:** Fuzzy-match the query against recent `acgsecrets.hk` season pages.
- **Inputs:** `query` — in practice the Traditional variant.
- **Returns:** `Future<List<AnimeSearchResult>>` — up to `_maxPerSource`, sorted by descending match score, then by season (current season first).
- **Side effects:** Up to four HTTP GETs to `acgsecrets.hk`, in parallel, 15 s timeout each; pages are cached in memory for 30 minutes.
- **Algorithm:**
  1. Get the season codes from [`acgsecretsSeasons`](#acgsecretsseasons)`(DateTime.now())` and load every page at once through [`_acgsecretsSeason`](#acgsecretsseason) under `Future.wait`.
  2. If every page came back `null`, throw — the source counts as failed.
  3. Build the query set `{query, toTraditional(query), toSimplified(query)}`.
  4. For every entry of every page, compute the best [`_similarity`](#similarity) of its `title`, `titleJa` and `synonyms` against the query set; skip entries below `0.3` and already-seen `sourceUrl`s; remember the page index.
  5. Sort by score descending, then by page index, and return the top `_maxPerSource`.
- **Notes:** The site has no search endpoint, so whole season pages are downloaded and matched locally. One page failing or timing out only loses that season. Through 1.6.0 the pages were fetched one after another, only the current and previous seasons were searched, the previous season was skipped once the current one matched, and one `try` wrapped a page's whole entry list — when the site began sending `numberOfEpisodes` as a string, every later entry on the page was lost. Keeping all alternate names (rather than only the Japanese one, as before 1.4.0) is what lets this source contribute cross-language backfill titles. See [`../../../../features/multi-source-search.md#acgsecretshk-season-pages`](../../../../features/multi-source-search.md#acgsecretshk-season-pages).

### `static Future<List<AnimeSearchResult>?> _acgsecretsSeason(String season)` <a id="acgsecretsseason"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (approx. line 1341)
- **Purpose:** Get one season page's entries, from the cache or the network.
- **Inputs:** `season` — `YYYYMM`.
- **Returns:** `Future<List<AnimeSearchResult>?>` — `null` when the page could not be loaded.
- **Side effects:** May issue one HTTP GET via `_fetchAcgsecretsSeason`; updates `_acgsecretsPages`.
- **Algorithm:** Returns the cached future when the entry is younger than `_acgsecretsPageTtl` (30 minutes). Otherwise starts `_fetchAcgsecretsSeason(season)`, stores `(at: now, items: future)` immediately, and, once the future completes with `null`, removes the entry — but only if it is still the same entry.
- **Notes:** Caching the in-flight future means round two, repeated searches and two searches started together share one download. A failed load is dropped so the next search tries again. The pages are about 2.6 MB and take the server 6–9 s to generate, which is why the cache exists.

### `static List<AnimeSearchResult> parseAcgsecretsPage(String html)` <a id="parseacgsecretspage"></a>
- **Kind:** static method of `AnimeSearchService`, `@visibleForTesting`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (approx. line 1391)
- **Purpose:** Read every entry from an acgsecrets.hk season page's JSON-LD.
- **Inputs:** `html` — the page.
- **Returns:** `List<AnimeSearchResult>` — one per `itemListElement` entry that has a name, in page order.
- **Side effects:** None.
- **Algorithm:** For each `_acgsecretsLdPattern` match, JSON-decode the block (skip it on failure), require a `Map` with a `List` `itemListElement`, and map each `Map` entry through [`_acgsecretsItem`](#acgsecretsitem) inside its own `try`, keeping the non-null results.
- **Usage:**
  ```dart
  final results = AnimeSearchService.parseAcgsecretsPage(html);
  ```
  (`test/search_aggregation_test.dart`)
- **Notes:** Each entry is read on its own, so one malformed entry never drops the rest of the page. Before 1.6.1 a single entry whose `numberOfEpisodes` was the string `"19"` silently discarded every entry after it.

### `static AnimeSearchResult? _acgsecretsItem(Map item)` <a id="acgsecretsitem"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (approx. line 1423)
- **Purpose:** Map one JSON-LD entry to a search result.
- **Inputs:** `item` — one `itemListElement` entry.
- **Returns:** `AnimeSearchResult?` — `null` when the entry has neither a `name` nor an `alternateName`.
- **Side effects:** None.
- **Algorithm:** Reads `name` (trimmed) and `alternateName` as a string or a list of strings, dropping blanks. `titleJa` is the first alternate name containing kana ([`_containsJapanese`](#containsjapanese)); every other alternate name becomes a synonym. `numberOfEpisodes` goes through `_looseInt`; `url`, `image` and `startDate` are used only when they are strings, the last via `DateTime.tryParse`.
- **Notes:** Every field is type-checked rather than cast, so an unexpected shape yields a missing field, not an exception.

### `static List<String> acgsecretsSeasons(DateTime now)` <a id="acgsecretsseasons"></a>
- **Kind:** static method of `AnimeSearchService`, `@visibleForTesting`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (approx. line 1469)
- **Purpose:** List the acgsecrets.hk season pages worth searching.
- **Inputs:** `now` — the local date.
- **Returns:** `List<String>` — four `YYYYMM` codes (month 01/04/07/10): the current season, the next one, then the two before the current one.
- **Side effects:** None.
- **Algorithm:** Finds the current season's start month as `((month - 1) ~/ 3) * 3 + 1`, then offsets it by 0, +1, −1 and −2 quarters through `DateTime`, which rolls the year over.
- **Usage:**
  ```dart
  final seasons = acgsecretsSeasons(DateTime.now());
  ```
  (`_searchAcgsecrets`, same file; `test/search_aggregation_test.dart` checks it)
- **Notes:** Replaced `_recentSeasons` (current and previous season only) in 1.6.1. The next season covers shows added before they air; the two earlier seasons cover a show the user catches up on late. The order is also the tie-break order for equally good matches.

### `static bool _containsJapanese(String s)` <a id="containsjapanese"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 1009)
- **Purpose:** Detect whether a string contains any Hiragana or Katakana character.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** Iterates `s.runes`, returning `true` on the first code point in `0x3040..0x309F` (Hiragana) or `0x30A0..0x30FF` (Katakana).
- **Notes:** Kanji-only strings are **not** detected as Japanese — Kanji alone can't distinguish a Japanese title from a Chinese one. That limitation is exactly why [`_isLikelyChinese`](#islikelychinese) exists as its complement.

### `static bool _isLatinScript(String s)` <a id="islatinscript"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 1026)
- **Purpose:** Check whether a string is written in Latin script.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** True when the string contains at least one ASCII letter and no Kana (`0x3040..0x30FF`) or CJK ideograph (`0x4E00..0x9FFF`).
- **Notes:** Needed because bangumi.tv has no romaji/English *field* — it files both under `别名`, so the Latin backfill title has to be recognized by script rather than by which field it arrived in. Without this, a Chinese query that only bangumi answered would harvest no Latin title and round two could not reach MyAnimeList or AniList.

### `static bool _isLikelyChinese(String s)` <a id="islikelychinese"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 1046)
- **Purpose:** Check whether a string reads as Chinese rather than Japanese.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** `false` if [`_containsJapanese`](#containsjapanese) is true; otherwise `true` if any rune falls in CJK Unified Ideographs (`0x4E00..0x9FFF`).
- **Notes:** The practical test for "this title is safe to send to a Chinese-language source". Kana presence is the only reliable negative signal, so the check is deliberately "has Han, has no Kana" rather than any attempt at real language detection.

### `static Future<List<AnimeSearchResult>> _searchFilmarks(String query)` <a id="searchfilmarks"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 1063)
- **Purpose:** Scrape `filmarks.com`'s anime search results page for title/cover/URL, with a looser fallback pattern if the primary one finds nothing.
- **Inputs:** `query` — in round two, the harvested Japanese title.
- **Returns:** `Future<List<AnimeSearchResult>>` — up to `_maxPerSource`.
- **Side effects:** One HTTP GET (10s timeout, `Accept-Language: ja`) to `filmarks.com`.
- **Algorithm:** GETs `https://filmarks.com/search/animes?q=<urlencoded query>`; matches each result "content cassette" by its escaped click handler — `onClickDetailLink($event, &#39;/animes/<series>/<season>&#39;)` — then takes the title and cover from the poster `<img alt="…" src="…">` within the following 3000 characters. Results are deduplicated by path. If that finds nothing, falls back to a plain `<a href="/animes/<series>/<season>">` anchor with a nearby poster `alt`.
- **Notes:** **The patterns were rewritten in 1.4.0.** filmarks moved its detail URLs from `/anime/<id>` to `/animes/<series>/<season>` and now renders results through a client-side component, so the old `/anime/` patterns — in place since v0.1.0 — matched nothing and this source had been contributing zero results with no error surfaced. The title now comes from the poster's `alt` attribute because the visible title is no longer in a `class="...title..."` element. Neither pattern captures episode count, air date, or schedule — filmarks results only ever populate `titleJa`/`sourceUrl`/`coverImageUrl`. Because it indexes Japanese titles only, this is the source that most benefits from round-two backfill: a Chinese or English query reaches it only after another source has supplied the Japanese title. HTML-structure scraping is inherently fragile to site markup changes, and this rewrite is the second time that has bitten — treat a sudden zero-result run from filmarks as a markup change rather than a genuine miss.

### `static Future<List<AnimeSearchResult>> _searchAniList(String query)` <a id="searchanilist"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 1155)
- **Purpose:** Query the AniList GraphQL API for up to `_maxPerSource` matching media entries.
- **Returns:** `Future<List<AnimeSearchResult>>` — `[]` on a non-200 response or missing `data.Page.media`.
- **Side effects:** One HTTP POST (10s timeout) to `graphql.anilist.co`.
- **Algorithm:** Interpolates `_aniListMediaFields` into a `Page(perPage: 10) { media(search:, type: ANIME, sort: SEARCH_MATCH) }` document, POSTs it via [`_postAniList`](#postanilist), and maps each entry through [`mapAniListMedia`](#mapanilistmedia).
- **Notes:** `_aniListMediaFields` is a single shared const field selection, so the search and by-id paths can never request different media fields. The by-id query alone appends `_aniListRelationFields` (1.6.0): search results never need relations, and they would multiply the search payload.

### `static Future<AnimeSearchResult?> _fetchAniListById(int id)` <a id="fetchanilistbyid"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (approx. line 1520)
- **Purpose:** Fetch one AniList media entry by its numeric id.
- **Returns:** `Future<AnimeSearchResult?>` — `null` when the id is unknown or the response is not a map.
- **Side effects:** One HTTP POST (10s timeout) to `graphql.anilist.co`.
- **Notes:** Its query is `_aniListMediaFields` plus `_aniListRelationFields` — `relations { edges { relationType(version: 2) node { id type format siteUrl title { romaji english native } } } }` — so relations cost no extra request.

### `static Future<Map<String, dynamic>?> _postAniList(String document, Map<String, dynamic> variables)` <a id="postanilist"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 1199)
- **Purpose:** POST a GraphQL document to AniList and return its `data` object.
- **Returns:** `Future<Map<String, dynamic>?>` — `null` on a non-200 response.
- **Side effects:** One HTTP POST (10s timeout) to `graphql.anilist.co`.
- **Notes:** Extracted so the search and by-id queries share transport, headers, and error handling.

### `static AnimeSearchResult mapAniListMedia(Map<String, dynamic> m)` <a id="mapanilistmedia"></a>
- **Kind:** static method of `AnimeSearchService`, `@visibleForTesting`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 1230)
- **Purpose:** Map one AniList media object onto an `AnimeSearchResult`.
- **Returns:** `AnimeSearchResult`.
- **Side effects:** None.
- **Algorithm:**
  1. Build `firstAirDate`/`endDate` via [`_aniListDate`](#anilistdate) (all three parts required).
  2. Get the broadcast timestamp from [`_aniListFirstAiringAt`](#anilistfirstairingat). When present, convert the Unix seconds to Japan time (`fromMillisecondsSinceEpoch(..., isUtc: true) + 9h`) and take its `.weekday` and zero-padded `HH:mm`. Only when absent does `airDayOfWeek` fall back to `firstAirDate.weekday`.
  3. Strip HTML from `description` (`<br>` → newline, remaining tags removed, `&amp;`/`&lt;`/`&gt;`/`&quot;`/`&#39;` unescaped).
  4. Flatten `studios.nodes[].name`; read `synonyms`, `episodes`, `duration`, `format`, `status`, `genres`, `popularity`, and `averageScore`.
  5. Prefer `title.english` then `title.romaji` for `title`; `title.native` for `titleJa`; keep romaji and English separately as well.
  6. Map `relations` through [`mapAniListRelations`](#mapanilistrelations) — empty for search results, whose query does not ask for them.
- **Notes:** Two decisions matter here. First, the schedule-derived weekday replaces the pre-1.4.0 behavior of always guessing from `startDate.weekday`, which was wrong whenever the premiere aired off the regular slot. Second, the JST moment is passed through [`_jstBroadcastSlot`](#jstbroadcastslot), so a late-night airing is filed under the previous day in `25:00` form and `firstAirDate` is shifted to match via [`_alignFirstAirDateToSlot`](#alignfirstairdatetoslot). Shifting the weekday without the date would leave the two disagreeing and `getEpisodeCalendarDate()`'s forward-snap would push episode 1 a week out. `averageScore` is 0–100 and is divided by 10 on the way in.

### `static List<AnimeExternalRelation> mapAniListRelations(Map<String, dynamic> m)` <a id="mapanilistrelations"></a>
- **Kind:** static method of `AnimeSearchService`, `@visibleForTesting`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (approx. line 1721)
- **Purpose:** Map AniList relation edges onto relations.
- **Inputs:** `m` — a media object from the by-id query.
- **Returns:** `List<AnimeExternalRelation>` — anime targets only; empty when the object carries no `relations` (search results).
- **Side effects:** None.
- **Algorithm:** Walks `relations.edges`, skipping any edge whose `node.type` is not `ANIME` or whose `relationType` is not a string. Each kept edge becomes a relation through `_relation` and the `_aniListRelationTypes` table: `PREQUEL`, `SEQUEL`, `PARENT`, `SIDE_STORY`, `SUMMARY` and `COMPILATION` (both → `summary`), `SPIN_OFF`, `ALTERNATIVE`; anything else becomes `other` with `rawType`. `targetUrl` is `node.siteUrl`, else `https://anilist.co/anime/<id>`; `title` is native, else romaji, else English; `format` is `node.format`.
- **Notes:** The table covers `relationType(version: 2)` values; `ADAPTATION`, `CHARACTER`, `SOURCE` and the like land in `other`.

### `static List<AnimeExternalRelation> mapJikanRelations(Map<String, dynamic> m)` <a id="mapjikanrelations"></a>
- **Kind:** static method of `AnimeSearchService`, `@visibleForTesting`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (approx. line 1759)
- **Purpose:** Map Jikan's `/full` relations onto relations.
- **Inputs:** `m` — an anime object from `/anime/{id}/full`.
- **Returns:** `List<AnimeExternalRelation>` — one per entry whose `type` is `anime`.
- **Side effects:** None.
- **Algorithm:** Walks the `relations` groups (`{relation, entry: [...]}`); each anime entry becomes a relation named by its group through the `_jikanRelationTypes` table: `Prequel`, `Sequel`, `Parent Story` and `Full Story` (→ `parent`), `Side Story`, `Summary`, `Spin-Off`, `Alternative Setting` and `Alternative Version` (→ `alternative`). `targetUrl` is `https://myanimelist.net/anime/<mal_id>`; `title` is the entry's `name`. Jikan gives no format.
- **Notes:** Search results carry no `relations`, so they map to an empty list.

### `static List<AnimeExternalRelation> mapBangumiRelations(List<dynamic> list)` <a id="mapbangumirelations"></a>
- **Kind:** static method of `AnimeSearchService`, `@visibleForTesting`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (approx. line 1790)
- **Purpose:** Map bangumi.tv's related-subjects list onto relations.
- **Inputs:** `list` — the body of `GET /v0/subjects/{id}/subjects`.
- **Returns:** `List<AnimeExternalRelation>` — anime targets (`type == 2`) only.
- **Side effects:** None.
- **Algorithm:** Each anime entry with a string `relation` becomes a relation through the `_bangumiRelationTypes` table: `前传`, `续集`, `主线故事` (→ `parent`), `番外篇` (→ `sideStory`), `总集篇` (→ `summary`), `衍生` (→ `spinOff`), `不同演绎` and `不同世界观` (→ `alternative`). `targetUrl` is `https://bgm.tv/subject/<id>`; `title` is `name_cn` when non-empty, else `name`. No format is read.
- **Notes:** The relation names were checked against the live endpoint on 2026-09-24. Books, music and games (`type` other than `2`) are skipped, so a light novel listed as the source never becomes a relation.

### `static DateTime? _aniListDate(Object? value)` <a id="anilistdate"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 1312)
- **Purpose:** Build a `DateTime` from an AniList `{year, month, day}` object.
- **Returns:** `DateTime?` — `null` unless all three parts are present `int`s.
- **Side effects:** None.
- **Notes:** AniList leaves parts null for unannounced dates, and a partial date cannot be scheduled, so a half-known date is treated as no date at all rather than being defaulted to January 1st.

### `static int? _aniListFirstAiringAt(Map<String, dynamic> m)` <a id="anilistfirstairingat"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 1328)
- **Purpose:** Pick the airing timestamp that best describes the broadcast slot.
- **Returns:** `int?` — a Unix timestamp in seconds, or `null` when unscheduled.
- **Side effects:** None.
- **Algorithm:** Prefers `nextAiringEpisode.airingAt`; otherwise returns the first `airingSchedule.nodes[]` entry with an `int` `airingAt`.
- **Notes:** `nextAiringEpisode` first means a currently-airing show reports its *live* slot, which is the one that matters for scheduling upcoming episodes. The `airingSchedule` fallback is queried **without** `notYetAired`, unlike the pre-1.4.0 document, so finished shows still yield a real slot instead of an empty node list.

### `static ({int weekday, String time, int dayShift}) _jstBroadcastSlot(int weekday, int hour, int minute)` <a id="jstbroadcastslot"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 1366)
- **Purpose:** Map a Japan-time airing moment onto the broadcast slot it is filed under.
- **Inputs:** `weekday` (1..7), `hour`, `minute` — all in Japan time.
- **Returns:** A record of the slot's `weekday`, its `time` (`HH:mm`, hour ≥ 24 for late-night), and `dayShift` — how many days earlier the slot's calendar date sits than the wall-clock date.
- **Side effects:** None.
- **Algorithm:** Below `_lateNightBoundaryHour` (04:00), steps the weekday back one (wrapping Monday to Sunday) and reports the hour as `hour + 24`. At or after 04:00, returns the values unchanged with `dayShift: 0`.
- **Notes:** Japanese scheduling files everything before 04:00 under the *previous* evening: a show at 01:00 Thursday is "Wednesday 25:00" and belongs on Wednesday's calendar row. This matters because [`Anime.getEpisodeCalendarDate`](../models/anime.md#getepisodecalendardate) **ignores `airTime` entirely** and places an episode purely from `firstAirDate` + `airDayOfWeek` — so reporting the raw wall-clock weekday would put every late-night episode one day later than the schedule it belongs to. Callers must pass `dayShift` to [`_alignFirstAirDateToSlot`](#alignfirstairdatetoslot) as well; shifting the weekday alone leaves the two fields disagreeing and the forward-snap pushes episode 1 a whole week out.

### `static DateTime? _alignFirstAirDateToSlot(DateTime? airDate, ({int weekday, String time, int dayShift}) slot, int clockWeekday)` <a id="alignfirstairdatetoslot"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 1393)
- **Purpose:** Move a first-air date back onto the late-night slot's calendar day.
- **Inputs:** `airDate`; `slot` from [`_jstBroadcastSlot`](#jstbroadcastslot); `clockWeekday` — the un-shifted wall-clock weekday.
- **Returns:** `DateTime?` — unchanged when there is no shift to apply.
- **Side effects:** None.
- **Algorithm:** Returns `airDate` untouched when it is null or `slot.dayShift` is zero, **or when `airDate.weekday` does not match `clockWeekday`**. Otherwise subtracts `dayShift` days.
- **Notes:** The weekday guard is what makes this safe to apply unconditionally. It only moves the date when the source's own first-air date sits on the wall-clock day — which is how both AniList (`startDate`) and MyAnimeList (`aired.from`) record it. A source that already reports the programming day has a weekday matching the *shifted* slot, so it is left alone and cannot be double-shifted.

### `static double? _toDouble(Object? value)` <a id="todouble"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 1409)
- **Purpose:** Coerce a JSON number into a `double`.
- **Returns:** `double?` — `null` for anything that is not a `num`.
- **Side effects:** None.
- **Notes:** Sources report scores as either integers or decimals depending on the endpoint.

### `static int? parseDayOfWeek(String day)` <a id="parsedayofweek"></a>
- **Kind:** static method of `AnimeSearchService`, `@visibleForTesting`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 1421)
- **Purpose:** Parse an English weekday name (as returned by Jikan's `broadcast.day`, e.g. `"Mondays"`) into `Anime.airDayOfWeek`'s `1..7` (Monday..Sunday) numbering.
- **Returns:** `int?` — `null` if no recognized weekday prefix matches.
- **Side effects:** None.
- **Algorithm:** Lowercases `day` and checks 3-letter prefixes in order (`mon`→1 … `sun`→7).
- **Notes:** Matches by `startsWith`, so it tolerates both `"Monday"` and `"Mondays"`.

### `static Future<List<String>> harvestAliases(String query)` <a id="harvestaliases"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (approx. line 549)
- **Purpose:** Fetch alternate titles for a query from bangumi.tv, for the anime1.me lookup.
- **Inputs:** `query` — any language; sent in Simplified form.
- **Returns:** `Future<List<String>>` — Chinese and Latin-script titles of the confident hits, deduplicated; empty when nothing matched.
- **Side effects:** One HTTP POST to `api.bgm.tv`.
- **Algorithm:** `_searchBangumi(toSimplified(query))`, then [`aliasCandidatesFrom`](#aliascandidatesfrom) with `queryVariants(query)`.
- **Usage:**
  ```dart
  aliases = await AnimeSearchService.harvestAliases(query);
  ```
  (`anime1_service.dart`, `search`, when no index row reaches the confident score)
- **Notes:** A mainland title and a Taiwanese one can share no characters at all (间谍过家家 / 間諜家家酒), and bangumi.tv's 别名 field usually lists both.

### `static List<String> aliasCandidatesFrom(List<AnimeSearchResult> hits, List<String> variants)` <a id="aliascandidatesfrom"></a>
- **Kind:** static method of `AnimeSearchService`, `@visibleForTesting`
- **Source:** approx. line 565
- **Purpose:** Pick alias strings out of search hits that match the query well.
- **Returns:** `List<String>`, at most six, in hit order.
- **Side effects:** None.
- **Algorithm:** For each hit with [`relevance`](#relevance) at least `_backfillMinRelevance` (0.45), keep every `allTitles` entry that is Chinese (Han, no kana) or Latin script, deduplicated.
- **Notes:** A Japanese title cannot match anime1's Chinese index; a romaji one can, because the site keeps Latin franchise names (`SPY×FAMILY`, `GRAND BLUE`).

### `static double bestSimilarity(String title, List<String> queries)` <a id="bestsimilarity"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** approx. line 1697
- **Purpose:** Compute the best fuzzy-similarity score of one candidate title against a list of query variants.
- **Returns:** `double` in `0.0..1.0`.
- **Side effects:** None.
- **Algorithm:** Runs [`_similarity`](#similarity) against each entry in `queries`, keeping the maximum.
- **Notes:** Behind the public [`relevance`](#relevance) and the anime1 scrape fallback; the anime1 index path scores pre-folded strings through [`similarityRaw`](#similarityraw) instead.

### `static double _similarity(String a, String b)` <a id="similarity"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** approx. line 1719
- **Purpose:** Fuzzy similarity of two titles, script- and punctuation-insensitive.
- **Returns:** `double` in `0.0..1.0`; `0` if either input is empty.
- **Side effects:** None.
- **Algorithm:** The better of [`similarityRaw`](#similarityraw) on the strings as given and on their [`foldTitle`](#foldtitle) forms.
- **Notes:** Through 1.5.6 the second pass normalized to Traditional, which is one-to-many (干 → 幹 or 乾) and therefore missed exactly the pairs it was meant to catch; Simplified is the many-to-one direction. Changing the pass can only raise scores, so `relevance`-based thresholds elsewhere are unaffected.

### `static double similarityRaw(String a, String b)` <a id="similarityraw"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** approx. line 1738
- **Purpose:** The three-measure similarity core on strings exactly as given.
- **Returns:** `double` in `0.0..1.0` — the best of LCS-Dice via [`_lcsLength`](#lcslength), order-independent character-set Dice over `.runes.toSet()`, and containment scoring `0.7 + 0.3 * (shorter / longer)`.
- **Side effects:** None.
- **Notes:** Public so `Anime1Service.rank` can score pre-folded strings without folding again per pair; every other caller wants [`_similarity`](#similarity).

### `static double orderedSimilarity(String a, String b)` <a id="orderedsimilarity"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** approx. line 1764
- **Purpose:** Order-aware similarity only — LCS-Dice or containment.
- **Returns:** `double` in `0.0..1.0`.
- **Side effects:** None.
- **Notes:** The character-set Dice term in [`similarityRaw`](#similarityraw) is blind to order, which on short Latin strings lets `bocchitherock` and `tomjerry` share half their letters. `Anime1Service.rank` requires this score to clear a floor as well, so such pairs are never offered.

### `static String foldTitle(String s)` <a id="foldtitle"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** approx. line 1791
- **Purpose:** Normalize a title for matching — never for display.
- **Returns:** `String` — fullwidth ASCII made halfwidth (U+FF01–FF5E, and U+3000 to a space), lowercased, whitespace and Unicode punctuation/symbols (`[\s\p{P}\p{S}]`) removed, then converted to Simplified.
- **Side effects:** None.
- **Notes:** Simplified is the canonical side because Traditional→Simplified is many-to-one (乾/幹 → 干, 髮/發 → 发). The conversion also folds Japanese kanji (滅 → 灭), so `鬼滅の刃` reaches `鬼滅之刃`. Symbols such as `×` in `SPY×FAMILY` are stripped on both sides, so they never decide a match.

### `static int _lcsLength(String a, String b)` <a id="lcslength"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** approx. line 1815
- **Purpose:** Compute the longest common subsequence length between two strings.
- **Returns:** `int`.
- **Side effects:** None.
- **Algorithm:** Standard O(n·m) dynamic programming using two rolling rows instead of a full 2D table.
- **Notes:** O(n·m) is acceptable specifically because both inputs are short anime titles, not arbitrary-length text.

### `static String decodeHtmlEntities(String text)` <a id="decodehtmlentities"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** approx. line 1845
- **Purpose:** Decode the small fixed set of HTML entities that show up in titles scraped from `filmarks.com` and `anime1.me`.
- **Returns:** `String`.
- **Side effects:** None.
- **Notes:** Only six entities are handled — a numeric character reference other than `&#39;` (e.g. `&#8217;`) passes through unescaped. Public since 1.5.7 because `anime1_service.dart` decodes index titles and scraped links with it.

### `double? AnimeSearchProgress.fraction` <a id="searchprogressfraction"></a>
- **Kind:** getter of `AnimeSearchProgress`
- **Purpose:** Report how much of the current search round has answered.
- **Inputs:** None.
- **Returns:** `double?` in 0..1, or `null` when no source is being queried.
- **Side effects:** None.
- **Notes:** Each round reports **its own denominator**. Round two re-queries only the sources that
  came back empty, so a single running total would grow mid-search and drive the bar backwards;
  instead the bar fills once for round one and again for the smaller round two, with the caption
  saying which pass is running.

  A failed source counts towards `done`, because it is no longer being waited on. Failure is still
  distinguishable — it is listed in `failed` — since "this source is broken" and "this source found
  nothing" are different answers to someone deciding whether to search again.

  This exists because a search can legitimately take about half a minute: every source has its own
  10–15 second timeout and there can be two rounds. Over that stretch a bare spinner is
  indistinguishable from a hang.
