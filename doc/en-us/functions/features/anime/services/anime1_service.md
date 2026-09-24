# lib/features/anime/services/anime1_service.dart

`Anime1Service` finds the `anime1.me` series page for a record and reads the site's update
progress for a saved watch URL. It is index-first: the site publishes its whole catalogue as
`animelist.json`, so every row is scored locally on a folded, Simplified key
([`anime_search_service.md`](anime_search_service.md) supplies `foldTitle`, `similarityRaw`,
`orderedSimilarity`, `bestSimilarity`, `harvestAliases`, `userAgent` and `decodeHtmlEntities`); the
WordPress `?s=` search that was the whole mechanism through 1.5.6 is kept only as the last resort.
The persisted result is `AnimeWatchProgress` from [`../models/anime.md`](../models/anime.md). Full
builds only — callers gate; see
[`../../../../features/watch-url-lookup.md`](../../../../features/watch-url-lookup.md) for the
stages, the ranking constants and the background refresh. The season-ordinal reader `rank` and
`search` use, `seasonOrdinal` (with its `_parseCjkNumber` helper), moved unchanged to the shared
[`../../../shared/utils/season_label.md`](../../../shared/utils/season_label.md) in 1.6.0, where the
series index uses it too.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `Anime1EpisodeInfo(...)` | constructor (`Anime1EpisodeInfo`) | B | Hold the parsed form of one episode cell. |
| `isOngoing` | getter (`Anime1EpisodeInfo`) | B | Whether the site marks the series as still updating. |
| `Anime1IndexEntry(...)` | constructor (`Anime1IndexEntry`) | B | Hold one `animelist.json` row. |
| `url` | getter (`Anime1IndexEntry`) | B | The `?cat=<id>` series page URL. |
| `episodes` | getter (`Anime1IndexEntry`) | B | Parse this row's episode cell. |
| `Anime1Match(...)` | constructor (`Anime1Match`) | B | Hold one ranked candidate. |
| `Anime1Match.fromIndex` | factory (`Anime1Match`) | B | Build a match from an index row; blank cells become `null`. |
| `Anime1Match.fromScrape` | factory (`Anime1Match`) | B | Build a match from a scraped link, with no episode data. |
| [`toProgress`](#toprogress) | method (`Anime1Match`) | A | Convert a match into the persisted watch-progress record. |
| `markedViaAliases` | method (`Anime1Match`) | B | Copy flagged as found through harvested aliases. |
| `Anime1Service._()` | constructor (`Anime1Service`) | B | Prevent instantiation. |
| [`loadIndex`](#loadindex) | static method (`Anime1Service`) | A | Return the series index, fetching it at most once per TTL. |
| `resetIndexCache` | static method (`Anime1Service`), `@visibleForTesting` | B | Drop the cached index. |
| [`_fetchIndex`](#_fetchindex) | static method (`Anime1Service`) | A | Download and parse `animelist.json`. |
| [`parseIndex`](#parseindex) | static method (`Anime1Service`), `@visibleForTesting` | A | Parse the index JSON into entries, skipping malformed rows. |
| [`parseEpisodes`](#parseepisodes) | static method (`Anime1Service`) | A | Parse an episode cell such as `1-12+OVA` or `連載中(09)`. |
| [`seasonIndex`](#seasonindex) | static method (`Anime1Service`), `@visibleForTesting` | A | Place a row's year/season on a continuous quarter timeline. |
| [`quarterIndexFor`](#quarterindexfor) | static method (`Anime1Service`), `@visibleForTesting` | A | Place a premiere date on the same timeline, snapping late premieres forward. |
| [`querySet`](#queryset) | static method (`Anime1Service`), `@visibleForTesting` | A | Build the folded, deduplicated query set for one lookup. |
| [`rank`](#rank) | static method (`Anime1Service`), `@visibleForTesting` | A | Score and order index rows against folded queries. |
| [`search`](#search) | static method (`Anime1Service`) | A | Find series pages for a record: index, then aliases, then scrape. |
| [`_mergeMatches`](#_mergematches) | static method (`Anime1Service`) | A | Merge an alias-assisted ranking into the base ranking. |
| `_isLikelyChinese` | static method (`Anime1Service`) | B | Whether a string is Han with no kana. |
| [`isAnime1Url`](#isanime1url) | static method (`Anime1Service`) | A | Whether a URL points at anime1.me. |
| [`catIdFromUrl`](#catidfromurl) | static method (`Anime1Service`) | A | Read the category id out of a `?cat=` URL. |
| [`parseCategoryPage`](#parsecategorypage) | static method (`Anime1Service`), `@visibleForTesting` | A | Extract id, title, newest episode and category link from a page. |
| [`fetchProgress`](#fetchprogress) | static method (`Anime1Service`) | A | Read what the site currently lists for a saved watch URL. |
| `_progressFromEntry` | static method (`Anime1Service`) | B | Build a progress record from an index row. |
| `_getPage` | static method (`Anime1Service`) | B | GET one page as text (15 s timeout). |
| [`_scrapeSearch`](#_scrapesearch) | static method (`Anime1Service`) | A | Search the site's own `?s=` endpoint, the pre-1.5.7 method. |
| [`_scrapeOne`](#_scrapeone) | static method (`Anime1Service`) | A | Run one `?s=` query and extract series title/URL pairs. |

Six declarations are `@visibleForTesting`; they are public so `test/anime1_service_test.dart` can
drive the parsers and the ranking against fixture rows — the HTTP calls are static and take no
injectable client. `parseEpisodes` and `catIdFromUrl` are plainly public because
`anime1_labels.dart` and `metadata_update_service.dart` call them.

## Documentation

### `AnimeWatchProgress toProgress(DateTime now)` <a id="toprogress"></a>
- **Kind:** method of `Anime1Match`
- **Source:** `lib/features/anime/services/anime1_service.dart` (approx. line 176)
- **Purpose:** Convert this match into the persisted watch-progress record keyed to its URL.
- **Inputs:** `now`.
- **Returns:** `AnimeWatchProgress` with `sourceUrl = url`, the category id, `latestEpisode`, the raw episode text, the ongoing flag and `checkedAt = now.toUtc()`.
- **Side effects:** None.
- **Usage:**
  ```dart
  final progress = selected.toProgress(DateTime.now());
  _externalMeta = (_externalMeta ?? const AnimeExternalMeta()).mergedWith(
    AnimeExternalMeta(watchProgress: progress),
  );
  ```
  (`anime_edit_page.dart`, `_searchWatchUrl`)
- **Notes:** A scrape hit yields a record with no episode data but a `checkedAt`, so the background refresher still schedules it normally.

### `static Future<List<Anime1IndexEntry>> loadIndex({bool forceRefresh = false})` <a id="loadindex"></a>
- **Kind:** static method of `Anime1Service`
- **Source:** approx. line 258
- **Purpose:** Return the series index, fetching it at most once per 30-minute TTL.
- **Returns:** `Future<List<Anime1IndexEntry>>`.
- **Side effects:** At most one HTTP GET; updates the static cache.
- **Algorithm:**
  1. Return the cached list when it is younger than `_indexTtl` and no refresh is forced.
  2. If a fetch is already in flight, return that same future so concurrent callers share one request.
  3. Otherwise run [`_fetchIndex`](#_fetchindex); on success replace the cache and stamp the time.
  4. On failure return the stale copy when there is one; rethrow only when there is nothing to serve.
- **Notes:** Stale-while-error is deliberate: the catalogue rarely changes within an hour, and the dialog and the background loop both prefer an hour-old list to an error.

### `static Future<List<Anime1IndexEntry>> _fetchIndex()` <a id="_fetchindex"></a>
- **Kind:** static method of `Anime1Service`
- **Source:** approx. line 300
- **Purpose:** Download and parse `animelist.json`.
- **Returns:** `Future<List<Anime1IndexEntry>>`.
- **Side effects:** One HTTP GET (15 s timeout) with the shared `userAgent`.
- **Notes:** Internal helper used within this file only. A non-200 response or an empty parse throws, so a broken deploy can never replace a good cache.

### `static List<Anime1IndexEntry> parseIndex(String jsonText)` <a id="parseindex"></a>
- **Kind:** static method of `Anime1Service`, `@visibleForTesting`
- **Source:** approx. line 325
- **Purpose:** Parse the index JSON into entries in file order (newest-updated first).
- **Inputs:** `jsonText` — a bare array of rows, or an object whose `data` holds one.
- **Returns:** `List<Anime1IndexEntry>`.
- **Side effects:** None.
- **Algorithm:** For each row that is a list of at least three cells: read cell 0 as an `int` (or parse it); skip when absent. Read cell 1 through `decodeHtmlEntities`; skip when blank. Cells 2–5 read as trimmed strings, missing ones as empty. Fold the title once with `foldTitle` and store it beside the display title.
- **Notes:** Rows are `[catId, title, episodesText, year, season, fansub]`; the fold is computed at parse time so ranking never folds per pair.

### `static Anime1EpisodeInfo parseEpisodes(String text)` <a id="parseepisodes"></a>
- **Kind:** static method of `Anime1Service`
- **Source:** approx. line 366
- **Purpose:** Parse an episode cell such as `1-12+OVA` or `連載中(09)`.
- **Returns:** `Anime1EpisodeInfo`; `raw` always holds the trimmed input.
- **Side effects:** None.
- **Algorithm:** Rules in priority order — `^連載中\s*\((\d+)([^)]*)\)` → ongoing with `latest` = the leading integer and the remainder as `extras`; `^(\d+)\s*-\s*(\d+)(?:\.\d+)?(.*)$` → range with `first`, `last`, `latest = last`, any suffix as `extras`; a bare integer → one-episode range; text containing 劇場版 → movie, 特別編 → special; anything else → other.
- **Notes:** Only the leading integer of an ongoing cell is trusted (`連載中(3 EP4)` reads as 3). Every shape observed in the live index in 1.5.7 is pinned by `test/anime1_service_test.dart`.

### `static int? seasonIndex(String year, String season)` <a id="seasonindex"></a>
- **Kind:** static method of `Anime1Service`, `@visibleForTesting`
- **Source:** approx. line 410
- **Purpose:** Place a row's year/season on a continuous quarter timeline: `year * 4 + (冬 0, 春 1, 夏 2, 秋 3)`.
- **Returns:** `int?` — `null` when the year is not an integer or no season character is recognized.
- **Side effects:** None.
- **Notes:** A combined cell such as `春/秋` uses its first season.

### `static int? quarterIndexFor(DateTime? firstAirDate)` <a id="quarterindexfor"></a>
- **Kind:** static method of `Anime1Service`, `@visibleForTesting`
- **Source:** approx. line 428
- **Purpose:** Place a premiere date on the same timeline as [`seasonIndex`](#seasonindex).
- **Returns:** `int?` — `null` for a null date.
- **Side effects:** None.
- **Algorithm:** `year * 4 + (month - 1) ~/ 3`, plus one when the date is on or after the 21st of a quarter's last month.
- **Notes:** anime1 files a 29 September premiere under 秋 while the calendar says Q3, so late premieres snap forward; 21 December or later lands in the next year's 冬 through the arithmetic alone.

### `static List<String> querySet(String query, List<String> altQueries)` <a id="queryset"></a>
- **Kind:** static method of `Anime1Service`, `@visibleForTesting`
- **Source:** approx. line 449
- **Purpose:** Build the folded query set for one lookup — folded, deduplicated, at most twelve entries.
- **Returns:** `List<String>`.
- **Side effects:** None.
- **Notes:** Queries shorter than two runes are dropped; a single character matches half the catalogue.

### `static List<Anime1Match> rank(List<Anime1IndexEntry> entries, List<String> foldedQueries, {int? quarterIndex, int? ordinal, double minScore = minScore, int limit = 10})` <a id="rank"></a>
- **Kind:** static method of `Anime1Service`, `@visibleForTesting`
- **Source:** approx. line 473
- **Purpose:** Score and order index rows against folded queries.
- **Inputs:** `entries`, `foldedQueries`; `quarterIndex` from [`quarterIndexFor`](#quarterindexfor); `ordinal` — the record's season ordinal; `minScore`; `limit`.
- **Returns:** `List<Anime1Match>` best first.
- **Side effects:** None.
- **Algorithm:**
  1. For each row, take the best `similarityRaw` and the best `orderedSimilarity` of its folded title over the queries; skip when either is below its floor (`minScore` 0.5, `minOrderedScore` 0.4).
  2. Add `seasonBoost` (0.10) when the row's [`seasonIndex`](#seasonindex) equals `quarterIndex`, or `adjacentSeasonBoost` (0.03) when one apart.
  3. When the record has an ordinal: add `ordinalBoost` (0.10) if the row's ordinal equals it; subtract `ordinalMismatchPenalty` (0.05) if the row names a different one, or names none while the record asks for a sequel.
  4. Sort by score descending, then file order; take `limit`.
- **Notes:** The order-aware floor exists because the set-based Dice term scores `bocchitherock` against `tomjerry` at exactly 0.5. The constants are explained in [`../../../../features/watch-url-lookup.md`](../../../../features/watch-url-lookup.md#ranking).

### `static Future<List<Anime1Match>> search(String query, {List<String> altQueries = const [], DateTime? firstAirDate, String? seasonText, bool harvestAliases = true})` <a id="search"></a>
- **Kind:** static method of `Anime1Service`
- **Source:** approx. line 543
- **Purpose:** Find anime1.me series pages for a record, index-first.
- **Inputs:** `query` — the display title; `altQueries` — Japanese, English, romaji titles and stored synonyms; `firstAirDate` — enables the season boost; `seasonText` — read for an ordinal; `harvestAliases` — allow one bangumi.tv query.
- **Returns:** `Future<List<Anime1Match>>`, best first, at most ten.
- **Side effects:** At most one index GET per 30 minutes, at most one bangumi.tv POST, and the `?s=` scrape only when the index is unreachable or matched nothing.
- **Algorithm:**
  1. `querySet`; return `[]` when empty. Load the index, tolerating failure.
  2. `rank` with the premiere quarter and the ordinal from the title or the season label.
  3. When allowed, the index loaded, no row reached `confidentScore` (0.9), and no alternate query is already Chinese: `AnimeSearchService.harvestAliases(query)`, then re-rank with the union and [`_mergeMatches`](#_mergematches).
  4. Return the matches when any; otherwise [`_scrapeSearch`](#_scrapesearch).
- **Usage:**
  ```dart
  final results = await Anime1Service.search(
    q,
    altQueries: widget.altQueries,
    firstAirDate: widget.firstAirDate,
    seasonText: widget.seasonText,
  );
  ```
  (`anime_edit_page.dart`, the watch-URL dialog)
- **Notes:** Retyping the query in the dialog costs one ranking pass over the cached index, not another download.

### `static List<Anime1Match> _mergeMatches(List<Anime1Match> base, List<Anime1Match> again)` <a id="_mergematches"></a>
- **Kind:** static method of `Anime1Service`
- **Source:** approx. line 599
- **Purpose:** Merge an alias-assisted ranking into the base ranking.
- **Returns:** `List<Anime1Match>` best first, at most ten.
- **Side effects:** None.
- **Notes:** Internal helper used within this file only. Rows are keyed by URL; the higher score wins, and a row that is new or improved is flagged `viaAliases` so the dialog can say where it came from.

### `static bool isAnime1Url(String? url)` <a id="isanime1url"></a>
- **Kind:** static method of `Anime1Service`
- **Source:** approx. line 635
- **Purpose:** Report whether a URL points at anime1.me (the bare host or any subdomain).
- **Returns:** `bool`; `false` for `null` or blank.
- **Side effects:** None.
- **Notes:** The gate every progress feature runs through — the detail chip, the list hints, and `MetadataUpdateService.isWatchProgressStale`.

### `static int? catIdFromUrl(String url)` <a id="catidfromurl"></a>
- **Kind:** static method of `Anime1Service`
- **Source:** approx. line 649
- **Purpose:** Read the category id out of a `?cat=` URL.
- **Returns:** `int?` — `null` for `/category/…` slugs and anything else.
- **Side effects:** None.
- **Notes:** `MetadataUpdateService` uses it to tell the free (index) resolutions from the ones that cost a page request.

### `static ({int? catId, String? title, int? latestEpisode, String? categoryUrl}) parseCategoryPage(String html)` <a id="parsecategorypage"></a>
- **Kind:** static method of `Anime1Service`, `@visibleForTesting`
- **Source:** approx. line 665
- **Purpose:** Extract the category id, title, newest episode and category link from a series or episode page.
- **Returns:** A record; each field `null` when absent.
- **Side effects:** None.
- **Algorithm:** `catId` from the body's `category-<n>` class; `title` from `<h1 class="page-title">`, tags stripped and entities decoded; `latestEpisode` as the largest integer `[N]` suffix among `entry-title` posts (`[OVA]` and `[SP1]` are ignored, `[12.5]` reads as 12); `categoryUrl` as the first `rel="category tag"` link.
- **Notes:** The category link is how an episode post points back at its series, which is what lets an old per-episode watch URL still resolve.

### `static Future<AnimeWatchProgress?> fetchProgress(String watchUrl, {List<Anime1IndexEntry>? index})` <a id="fetchprogress"></a>
- **Kind:** static method of `Anime1Service`
- **Source:** approx. line 711
- **Purpose:** Read what anime1.me currently lists for a saved watch URL.
- **Inputs:** `watchUrl`; `index` — a pre-loaded index to reuse (the background loop passes one).
- **Returns:** `Future<AnimeWatchProgress?>` — `null` when the URL is not anime1.me or nothing could be read.
- **Side effects:** Possibly one index GET and up to two page GETs.
- **Algorithm:**
  1. Not anime1.me → `null` with no network.
  2. `catIdFromUrl` → look up the index row → `_progressFromEntry`.
  3. Otherwise GET the page and [`parseCategoryPage`](#parsecategorypage); if it is an episode post (no id, no episodes, a category link), follow the link once.
  4. Prefer the index row for the parsed id; else build a record from the page's newest episode; `null` when the page yields neither a title nor an episode.
- **Usage:**
  ```dart
  final progress = await Anime1Service.fetchProgress(url);
  ```
  (`anime_detail_page.dart`, `_checkWatchProgress`)
- **Notes:** The index row is preferred whenever its id becomes known, because only the index says whether the run is still updating; a page-built record is marked not ongoing.

### `static Future<List<Anime1Match>> _scrapeSearch(String query, List<String> altQueries)` <a id="_scrapesearch"></a>
- **Kind:** static method of `Anime1Service`
- **Source:** approx. line 799
- **Purpose:** Search the site's own `?s=` endpoint — the pre-1.5.7 method, kept as the last resort.
- **Returns:** `Future<List<Anime1Match>>` ranked by `bestSimilarity`, at most ten.
- **Side effects:** Up to six sequential HTTP GETs, plus up to three bigram retries when nothing matched.
- **Algorithm:** Build the variant set (each query plus its Traditional and Simplified forms, capped at six); run [`_scrapeOne`](#_scrapeone) for each, deduplicating by URL; if empty, retry with trailing two-character substrings of the Traditional query; score and sort.
- **Notes:** Internal helper used within this file only. The site search matches exact Traditional substrings only, hence the fan-out.

### `static Future<List<({String title, String url})>> _scrapeOne(String query)` <a id="_scrapeone"></a>
- **Kind:** static method of `Anime1Service`
- **Source:** approx. line 858
- **Purpose:** Run one `?s=` query and extract series (not episode) title/URL pairs from the HTML.
- **Returns:** `Future<List<({String title, String url})>>` — empty on a non-200 response.
- **Side effects:** One HTTP GET (10 s timeout).
- **Algorithm:** Three patterns in priority order — `rel="category tag"` links, then `?cat=<id>` links, then `entry-title` posts with the trailing ` [N]` stripped. Later tiers run only when earlier ones found nothing; every tier deduplicates by title and decodes entities.
- **Notes:** Internal helper used within this file only. This is the 1.5.6 `_searchAnime1Single` body, moved here unchanged.
