# lib/features/anime/services/anime_search_service.dart

`AnimeSearchService` queries or scrapes six external anime databases (`bangumi.tv`, MyAnimeList via
Jikan v4, AniList, `acgsecrets.hk`, `filmarks.com`, and `anime1.me`) and returns normalized
`AnimeSearchResult`s. It is a plain shared utility available in **full builds only** — it does not
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
| [`displayTitle`](#displaytitle) | getter (`AnimeSearchResult`) | B | Return the first known title, or `?`. |
| `AnimeSearchSource._()` | constructor (`AnimeSearchSource`) | B | Prevent instantiation of the source-name holder. |
| [`searchAll`](#searchall) | static method (`AnimeSearchService`) | A | Run the two-round cross-language search and return one ranked list. |
| [`queryVariants`](#queryvariants) | static method (`AnimeSearchService`) | A | Build the Simplified/Traditional variant set for a query. |
| [`relevance`](#relevance) | static method (`AnimeSearchService`) | A | Score a result against a query variant set, across all its titles. |
| [`_languageAffinity`](#languageaffinity) | static method (`AnimeSearchService`) | A | Report whether a result carries a title in the user's UI language. |
| [`toExternalMeta`](#toexternalmeta) | static method (`AnimeSearchService`) | A | Convert a search result into the persisted `AnimeExternalMeta` record. |
| [`fetchByUrl`](#fetchbyurl) | static method (`AnimeSearchService`) | A | Re-fetch one anime by id from the page URL it came from. |
| [`refreshAll`](#refreshall) | static method (`AnimeSearchService`) | A | Re-fetch several source pages in parallel, skipping failures. |
| [`_runRound`](#runround) | static method (`AnimeSearchService`) | A | Query the requested sources once, in parallel, tolerating failures. |
| [`_harvestBackfillTitles`](#harvestbackfilltitles) | static method (`AnimeSearchService`) | A | Pick cross-language titles from round one to search with in round two. |
| [`_searchBangumi`](#searchbangumi) | static method (`AnimeSearchService`) | A | Query bangumi.tv's v0 search API. |
| [`_fetchBangumiById`](#fetchbangumibyid) | static method (`AnimeSearchService`) | B | Fetch one bangumi.tv subject by numeric id. |
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
| [`_searchAcgsecrets`](#searchacgsecrets) | static method (`AnimeSearchService`) | A | Scrape acgsecrets.hk seasonal-page JSON-LD and fuzzy-match against the query. |
| [`_recentSeasons`](#recentseasons) | static method (`AnimeSearchService`) | B | Compute the current and previous season codes (`YYYYMM`). |
| [`_containsJapanese`](#containsjapanese) | static method (`AnimeSearchService`) | A | Check whether a string contains Hiragana/Katakana characters. |
| [`_isLatinScript`](#islatinscript) | static method (`AnimeSearchService`) | A | Check whether a string is written in Latin script. |
| [`_isLikelyChinese`](#islikelychinese) | static method (`AnimeSearchService`) | A | Check whether a string reads as Chinese rather than Japanese. |
| [`_searchFilmarks`](#searchfilmarks) | static method (`AnimeSearchService`) | A | Scrape filmarks.com's search results HTML. |
| [`_searchAniList`](#searchanilist) | static method (`AnimeSearchService`) | A | Query the AniList GraphQL API. |
| [`_fetchAniListById`](#fetchanilistbyid) | static method (`AnimeSearchService`) | B | Fetch one AniList media entry by numeric id. |
| [`_postAniList`](#postanilist) | static method (`AnimeSearchService`) | B | POST a GraphQL document to AniList and return its `data` object. |
| [`mapAniListMedia`](#mapanilistmedia) | static method (`AnimeSearchService`) | A | Map one AniList media object onto an `AnimeSearchResult`. |
| [`_aniListDate`](#anilistdate) | static method (`AnimeSearchService`) | B | Build a `DateTime` from an AniList `{year, month, day}` object. |
| [`_aniListFirstAiringAt`](#anilistfirstairingat) | static method (`AnimeSearchService`) | A | Pick the airing timestamp that best describes the broadcast slot. |
| [`_jstBroadcastSlot`](#jstbroadcastslot) | static method (`AnimeSearchService`) | A | Map a Japan-time airing moment onto the broadcast slot it is filed under. |
| [`_alignFirstAirDateToSlot`](#alignfirstairdatetoslot) | static method (`AnimeSearchService`) | A | Move a first-air date back onto the late-night slot's calendar day. |
| [`_toDouble`](#todouble) | static method (`AnimeSearchService`) | B | Coerce a JSON number into a `double`. |
| [`parseDayOfWeek`](#parsedayofweek) | static method (`AnimeSearchService`) | A | Parse an English weekday name prefix into `1..7` (Monday..Sunday). |
| [`searchAnime1`](#searchanime1) | static method (`AnimeSearchService`) | A | Search anime1.me for a watch-page URL, with Chinese-variant and substring fallback and fuzzy ranking. |
| [`_bestSimilarity`](#bestsimilarity) | static method (`AnimeSearchService`) | A | Compute the best fuzzy-similarity score of a title against any of several query variants. |
| [`_similarity`](#similarity) | static method (`AnimeSearchService`) | A | Fuzzy similarity combining LCS, character-set Dice, and containment, S/T-normalized. |
| [`_lcsLength`](#lcslength) | static method (`AnimeSearchService`) | A | Longest common subsequence length between two strings. |
| [`_searchAnime1Single`](#searchanime1single) | static method (`AnimeSearchService`) | A | Run one anime1.me search query and extract series title/URL pairs from the HTML. |
| [`_decodeHtmlEntities`](#decodehtmlentities) | static method (`AnimeSearchService`) | B | Decode the handful of HTML entities that appear in scraped titles. |
| `_BackfillTitles(...)` | constructor (`_BackfillTitles`) | B | Hold one harvested title per language family. |
| `hasAny` | getter (`_BackfillTitles`) | B | Report whether any usable title was harvested. |

Note on the verification count: the source file has 48 `/// Purpose:` doc comments, but this table
has 49 rows — `searchAnime1` carries a plain (non-`Purpose:`) doc comment. It is still a real,
non-trivial declaration and is indexed above as Tier A.

Six declarations (`mapBangumiSubject`, `parseBangumiWeekday`, `mapJikanAnime`,
`parseJikanDuration`, `mapAniListMedia`, `parseDayOfWeek`) are marked `@visibleForTesting`. They are
public solely so `test/anime_search_test.dart` can exercise the source-format parsing against
fixture JSON — the HTTP calls are static and take no injectable client, so the mappers are the only
practical seam. Do not call them from production code outside this file.

## Documentation

### `const AnimeSearchResult({required source, sourceUrl, title, titleJa, titleRomaji, titleEn, synonyms, episodes, firstAirDate, airDayOfWeek, airTime, endDate, format, status, durationMinutes, genres, studios, score, scoreMax, scoreVotes, scoreRank, coverImageUrl, summary})` <a id="animesearchresult-new"></a>
- **Kind:** constructor of `AnimeSearchResult`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 68)
- **Purpose:** Hold one normalized search result, whatever the originating source, in a shape ready to prefill the anime edit form.
- **Inputs:** `source` required (the source's display name, e.g. `'bangumi.tv'`); everything else optional since no single source supplies every field. `synonyms`, `genres`, and `studios` default to empty lists; `scoreMax` defaults to `10`.
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

### `static Future<List<AnimeSearchResult>> searchAll(String query, {String? preferredLanguage})` <a id="searchall"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 173)
- **Purpose:** Query every metadata source and return one deduplicated, relevance-ranked list.
- **Inputs:** `query`; `preferredLanguage` — the UI language tag (e.g. `zh_TW`, `ja`) passed by the caller.
- **Returns:** `Future<List<AnimeSearchResult>>`.
- **Side effects:** Issues HTTP requests to five external services concurrently, and to a subset of them a second time when cross-language backfill runs.
- **Algorithm:**
  1. Build `variants = queryVariants(query)`.
  2. **Round one** via [`_runRound`](#runround), with per-source language targeting: bangumi.tv gets the Simplified form, acgsecrets.hk the Traditional form, filmarks.com the raw query (with `Accept-Language: ja`), and MyAnimeList/AniList the raw query.
  3. Compute the set of sources that returned nothing. If it is empty, skip to step 6.
  4. Harvest up to three cross-language titles via [`_harvestBackfillTitles`](#harvestbackfilltitles). If nothing was harvested, skip to step 6.
  5. **Round two** via `_runRound`, passing a query *only* for the empty sources, each in its own language. MyAnimeList and AniList fall back to the harvested Japanese title when no Latin one was found, since both index native titles too.
  6. Deduplicate by `sourceUrl` (falling back to `title`, then `titleJa`), iterating sources in `AnimeSearchSource.all` order so the output is stable.
  7. Sort by descending [`relevance`](#relevance), breaking ties by source name.
- **Usage:**
  ```dart
  final results = await AnimeSearchService.searchAll(query, preferredLanguage: language);
  ```
  (`lib/features/anime/views/anime_search_dialog.dart`, `_search`)
- **Notes:** Replaces the pre-1.4.0 single round, which sent every source the raw query and only special-cased bangumi.tv for Simplified/Traditional. There is exactly one extra round — no recursion — so the worst case roughly doubles latency, and each source still fails independently via `.catchError`. `anime1.me` is deliberately not part of `searchAll`; see [`searchAnime1`](#searchanime1).

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
- **Algorithm:** Runs [`_bestSimilarity`](#bestsimilarity) over every entry of `result.allTitles`, keeps the maximum, then adds `_languageBonus` (0.05) when [`_languageAffinity`](#languageaffinity) says the result carries a title in `preferredLanguage`.
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
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 314)
- **Purpose:** Convert a search result into the persisted external-metadata record.
- **Inputs:** `result`; `fetchedAt` — override for the timestamp, used by tests.
- **Returns:** `AnimeExternalMeta`.
- **Side effects:** None.
- **Algorithm:** Copies the metadata fields straight across, then, when the source reported any of `score`/`scoreVotes`/`scoreRank`, appends a single `AnimeExternalRating` carrying `source`, `sourceUrl`, the score, `scoreMax`, votes, rank, and `fetchedAt` (UTC). `refreshedAt` is set to the same timestamp.
- **Usage:**
  ```dart
  final fetched = AnimeSearchService.toExternalMeta(r);
  result['externalMeta'] = widget.currentExternalMeta?.mergedWith(fetched) ?? fetched;
  ```
  (`lib/features/anime/views/anime_search_dialog.dart`, `_apply`)
- **Notes:** The user's personal `AnimeRating` is never involved — external scores live only in `externalMeta.ratings`. Keeping `sourceUrl` on each rating entry is what makes [`refreshAll`](#refreshall) possible later; a source with no score contributes metadata but no rating entry, and therefore nothing to refresh from beyond `infoUrl`.

### `static Future<AnimeSearchResult?> fetchByUrl(String url)` <a id="fetchbyurl"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 357)
- **Purpose:** Re-fetch one anime's metadata from the page URL it came from.
- **Inputs:** `url` — an AniList, MyAnimeList, or bangumi.tv subject page URL.
- **Returns:** `Future<AnimeSearchResult?>` — `null` when the host is not one of the three API-backed sources, or when the fetch fails.
- **Side effects:** One HTTP request to the matching API.
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

### `static Future<Map<String, List<AnimeSearchResult>>> _runRound({required bangumiQuery, required acgsecretsQuery, required filmarksQuery, required globalQuery, malQuery, anilistQuery})` <a id="runround"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 404)
- **Purpose:** Query the requested sources once, in parallel, tolerating failures.
- **Inputs:** one query per source; `globalQuery` is the default for MyAnimeList and AniList, overridden by `malQuery`/`anilistQuery` in the backfill round.
- **Returns:** `Future<Map<String, List<AnimeSearchResult>>>` keyed by source name.
- **Side effects:** One HTTP request per non-null, non-blank query.
- **Algorithm:** A local `run(query, fetch)` returns an immediately-completed empty list when the query is `null` or blank, and otherwise calls `fetch(query.trim()).catchError((_) => [])`. All five futures are awaited together and zipped back onto their source names.
- **Notes:** A `null` or blank query means "skip this source in this round" — that is exactly how round two addresses only the sources that came back empty. Keeping the return keyed by source is what lets `searchAll` tell "returned nothing" from "was not asked".

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
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 538)
- **Purpose:** Fetch one bangumi.tv subject by its numeric id.
- **Returns:** `Future<AnimeSearchResult?>` — `null` on a non-200 response or a body with no `id`.
- **Side effects:** One HTTP GET (10s timeout) to `api.bgm.tv`.
- **Notes:** The path is `/v0/subjects/{id}` — **plural**. The singular `/v0/subject/{id}` returns 404, and the legacy `/subject/{id}` is 502 like the rest of that API. The response has the same shape as v0 search, so one mapper serves both paths.

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
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 741)
- **Purpose:** Fetch one MyAnimeList entry by its numeric id via Jikan.
- **Returns:** `Future<AnimeSearchResult?>` — `null` on a non-200 response or a non-map `data`.
- **Side effects:** One HTTP GET (10s timeout) to `api.jikan.moe`.
- **Notes:** The `/full` variant returns the same object shape as search, plus relations this app ignores, so `mapJikanAnime` handles both unchanged.

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
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 901)
- **Purpose:** Scrape `acgsecrets.hk`'s per-season anime list (embedded as `application/ld+json` script blocks) and fuzzy-match entries against the query, trying the current season and falling back to the previous one.
- **Inputs:** `query` — in practice the Traditional variant.
- **Returns:** `Future<List<AnimeSearchResult>>` — up to `_maxPerSource`, sorted by descending fuzzy-match score.
- **Side effects:** Up to two HTTP GETs (15s timeout each) to `acgsecrets.hk`.
- **Algorithm:**
  1. Get `[currentSeason, previousSeason]` from [`_recentSeasons`](#recentseasons); compute Traditional and Simplified variants.
  2. For each season: GET the season page; skip on non-200. Extract every `<script type="application/ld+json">` block, JSON-decode it, and for each `itemListElement` compute the best [`_similarity`](#similarity) of the item's `name`/`alternateName`s against the query variants; skip items below `0.3`; skip already-seen `url`s.
  3. Build a result with `startDate` parsed via `DateTime.tryParse`, `numberOfEpisodes` when present, the first Kana-containing `alternateName` as `titleJa`, and **every remaining alternate name as `synonyms`**.
  4. Stop before the previous season if the current one produced anything.
  5. Sort by score descending and return the top `_maxPerSource`.
- **Notes:** A JSON-decode failure on any individual `<script>` block is caught per-block so one malformed block doesn't abort the season's parse. Keeping all alternate names (rather than only the Japanese one, as before 1.4.0) is what lets this source contribute cross-language backfill titles.

### `static List<String> _recentSeasons()` <a id="recentseasons"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 987)
- **Purpose:** Compute the `acgsecrets.hk` season codes (`YYYYMM`) for "this season" and "the previous season", newest first.
- **Returns:** `List<String>` of exactly 2 season codes.
- **Side effects:** None.
- **Algorithm:** Finds the current season-start month from `[1, 4, 7, 10].lastWhere((s) => m >= s)`; computes the previous season by subtracting 3 months, wrapping to `year - 1, 10` in January.

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
- **Notes:** `_aniListMediaFields` is a single shared const field selection, so the search and by-id paths can never request different fields.

### `static Future<AnimeSearchResult?> _fetchAniListById(int id)` <a id="fetchanilistbyid"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 1180)
- **Purpose:** Fetch one AniList media entry by its numeric id.
- **Returns:** `Future<AnimeSearchResult?>` — `null` when the id is unknown or the response is not a map.
- **Side effects:** One HTTP POST (10s timeout) to `graphql.anilist.co`.

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
- **Notes:** Two decisions matter here. First, the schedule-derived weekday replaces the pre-1.4.0 behavior of always guessing from `startDate.weekday`, which was wrong whenever the premiere aired off the regular slot. Second, the JST moment is passed through [`_jstBroadcastSlot`](#jstbroadcastslot), so a late-night airing is filed under the previous day in `25:00` form and `firstAirDate` is shifted to match via [`_alignFirstAirDateToSlot`](#alignfirstairdatetoslot). Shifting the weekday without the date would leave the two disagreeing and `getEpisodeCalendarDate()`'s forward-snap would push episode 1 a week out. `averageScore` is 0–100 and is divided by 10 on the way in.

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

### `static Future<List<({String title, String url})>> searchAnime1(String query, {List<String> altQueries = const []})` <a id="searchanime1"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 1437)
- **Purpose:** Find candidate `anime1.me` category/watch-page URLs for a title, trying Simplified/Traditional variants and optional alternate queries, with a bigram-substring fallback when nothing matches, ranked by fuzzy similarity.
- **Inputs:** `query`; `altQueries` — additional title variants to also try.
- **Returns:** `Future<List<({String title, String url})>>` — up to 10, best match first.
- **Side effects:** One or more HTTP GETs to `anime1.me`, one per query variant tried.
- **Algorithm:**
  1. Build a `Set<String>` of variants: `query` plus its Traditional and Simplified forms, and the same three for each non-blank `altQueries` entry.
  2. Run [`_searchAnime1Single`](#searchanime1single) for every variant, merging and deduplicating by `url`.
  3. If nothing matched, derive a Traditional letters/numbers-only form; if it is at least 4 characters, try up to 3 trailing bigrams, stopping as soon as one yields results.
  4. Sort by [`_bestSimilarity`](#bestsimilarity) descending and return the top 10.
- **Usage:**
  ```dart
  final results = await AnimeSearchService.searchAnime1(q, altQueries: widget.altQueries);
  ```
  (`lib/features/anime/views/anime_edit_page.dart`, the "find watch URL" dialog)
- **Notes:** Unlike `searchAll`, this is not part of the general metadata search — it exists specifically to find a series' `anime1.me` watch-page URL for `Anime.watchUrl`, and returns title/URL pairs rather than metadata.

### `static double _bestSimilarity(String title, List<String> queries)` <a id="bestsimilarity"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 1506)
- **Purpose:** Compute the best fuzzy-similarity score of one candidate title against a list of query variants.
- **Returns:** `double` in `0.0..1.0`.
- **Side effects:** None.
- **Algorithm:** Runs [`_similarity`](#similarity) against each entry in `queries`, keeping the maximum.
- **Notes:** The single primitive behind both `anime1.me` ranking and the public [`relevance`](#relevance).

### `static double _similarity(String a, String b)` <a id="similarity"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 1520)
- **Purpose:** Score how similar two strings are, combining three measures and taking the best, so both a re-ordered title and a Simplified/Traditional variant of the same title score highly.
- **Returns:** `double` in `0.0..1.0`; `0` if either input is empty.
- **Side effects:** None.
- **Algorithm:**
  1. Compute Traditional-normalized forms of both inputs.
  2. For each of `(a, b)` and `(aNorm, bNorm)`: LCS-based Dice via [`_lcsLength`](#lcslength); order-independent character-set Dice over `.runes.toSet()`; and containment scoring `0.7 + 0.3 * (shorter / longer)`.
  3. Return the maximum across both passes and all three measures.
- **Notes:** Comparing both raw and Traditional-normalized forms means a Simplified query still scores well against a Traditional-only title without either side needing pre-normalization.

### `static int _lcsLength(String a, String b)` <a id="lcslength"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 1554)
- **Purpose:** Compute the longest common subsequence length between two strings.
- **Returns:** `int`.
- **Side effects:** None.
- **Algorithm:** Standard O(n·m) dynamic programming using two rolling rows instead of a full 2D table.
- **Notes:** O(n·m) is acceptable specifically because both inputs are short anime titles, not arbitrary-length text.

### `static Future<List<({String title, String url})>> _searchAnime1Single(String query)` <a id="searchanime1single"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 1581)
- **Purpose:** Run a single `anime1.me` search query and extract series (not episode) title/URL pairs from the result HTML.
- **Returns:** `Future<List<({String title, String url})>>` — `[]` on a non-200 response.
- **Side effects:** One HTTP GET (10s timeout) to `anime1.me`.
- **Algorithm:** Three patterns in priority order — category links tagged `rel="...category..."`; then `?cat=<id>` links; then `<h2 class="...entry-title...">` episode-post links with a trailing `" [<n>]"` suffix stripped. Later tiers run only when earlier ones found nothing; every tier deduplicates by title and decodes HTML entities.
- **Notes:** The tiers exist because the search page mixes clean series-level category links with individual episode posts; falling through only on an empty result avoids surfacing dozens of per-episode duplicates.

### `static String _decodeHtmlEntities(String text)` <a id="decodehtmlentities"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 1656)
- **Purpose:** Decode the small fixed set of HTML entities that show up in titles scraped from `filmarks.com` and `anime1.me`.
- **Returns:** `String`.
- **Side effects:** None.
- **Notes:** Only six entities are handled — a numeric character reference other than `&#39;` (e.g. `&#8217;`) passes through unescaped.
