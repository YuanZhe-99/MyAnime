# lib/features/anime/services/anime_search_service.dart

`AnimeSearchService` queries or scrapes six external anime databases in parallel
(`bangumi.tv`, MyAnimeList via Jikan v4, AniList, `acgsecrets.hk`, `filmarks.com`, and `anime1.me`)
and returns normalized `AnimeSearchResult`s. It is a plain shared utility available in **full
builds only** — it does not itself enforce that restriction; callers gate it (see
[`../../../../features/multi-source-search.md`](../../../../features/multi-source-search.md) for the
flavor-gating rule and per-source notes). It depends on
[`../../../shared/utils/chinese_convert.md`](../../../shared/utils/chinese_convert.md) for
Simplified/Traditional Chinese query variants used against Chinese-language sources, and its results
feed the "search online" flow in `anime_edit_page.dart` and the desktop local API server. The
`AnimeSearchResult` fields map onto `Anime` fields documented in
[`../../../../data-formats.md`](../../../../data-formats.md) (e.g. `sourceUrl` becomes `infoUrl`).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`AnimeSearchResult(...)`](#animesearchresult-new) | constructor (`AnimeSearchResult`) | A | Hold one normalized search hit from any source. |
| [`searchAll`](#searchall) | static method (`AnimeSearchService`) | A | Query all metadata sources in parallel, deduplicate, return combined results. |
| [`_searchBangumi`](#searchbangumi) | static method (`AnimeSearchService`) | A | Query bangumi.tv's legacy search API. |
| [`_searchMAL`](#searchmal) | static method (`AnimeSearchService`) | A | Query MyAnimeList via the Jikan v4 API. |
| [`_searchAcgsecrets`](#searchacgsecrets) | static method (`AnimeSearchService`) | A | Scrape acgsecrets.hk seasonal-page JSON-LD data and fuzzy-match against the query. |
| [`_recentSeasons`](#recentseasons) | static method (`AnimeSearchService`) | A | Compute the current and previous season codes (`YYYYMM`) for `acgsecrets.hk` scraping. |
| [`_containsJapanese`](#containsjapanese) | static method (`AnimeSearchService`) | A | Check whether a string contains Hiragana/Katakana characters. |
| [`_searchFilmarks`](#searchfilmarks) | static method (`AnimeSearchService`) | A | Scrape filmarks.com's search results HTML. |
| [`_searchAniList`](#searchanilist) | static method (`AnimeSearchService`) | A | Query the AniList GraphQL API. |
| [`_parseDayOfWeek`](#parsedayofweek) | static method (`AnimeSearchService`) | A | Parse an English weekday name prefix into `1..7` (Monday..Sunday). |
| [`searchAnime1`](#searchanime1) | static method (`AnimeSearchService`) | A | Search anime1.me for a watch-page URL, with Chinese-variant and substring fallback and fuzzy ranking. |
| [`_bestSimilarity`](#bestsimilarity) | static method (`AnimeSearchService`) | A | Compute the best fuzzy-similarity score of a title against any of several query variants. |
| [`_similarity`](#similarity) | static method (`AnimeSearchService`) | A | Fuzzy similarity combining LCS, character-set Dice, and containment, S/T-normalized. |
| [`_lcsLength`](#lcslength) | static method (`AnimeSearchService`) | A | Longest common subsequence length between two strings. |
| [`_searchAnime1Single`](#searchanime1single) | static method (`AnimeSearchService`) | A | Run one anime1.me search query and extract series title/URL pairs from the HTML. |
| [`_decodeHtmlEntities`](#decodehtmlentities) | static method (`AnimeSearchService`) | A | Decode the handful of HTML entities that appear in scraped titles. |

Note on the verification count: the source file has 14 `/// Purpose:` doc comments, but this table
has 16 rows — `searchAnime1` (line 482) has only a plain (non-`Purpose:`) doc comment, and
`_searchAnime1Single` (line 620) has no doc comment at all. Both are still real, non-trivial
declarations and are indexed above as Tier A.

## Documentation

### `const AnimeSearchResult({required source, sourceUrl, title, titleJa, episodes, firstAirDate, airDayOfWeek, airTime, coverImageUrl, summary})` <a id="animesearchresult-new"></a>
- **Kind:** constructor of `AnimeSearchResult`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 25)
- **Purpose:** Hold one normalized search result, whatever the originating source, in a shape ready to prefill the anime edit form.
- **Inputs:** `source` required (the source's display name, e.g. `'bangumi.tv'`); everything else optional since no single source supplies every field.
- **Returns:** A new `AnimeSearchResult`.
- **Side effects:** None.
- **Algorithm:** Plain field assignment via `const` constructor.
- **Usage:**
  ```dart
  return AnimeSearchResult(
    source: 'bangumi.tv',
    sourceUrl: 'https://bgm.tv/subject/${m['id']}',
    title: (m['name_cn'] as String?)?.isNotEmpty == true ? m['name_cn'] as String : null,
    titleJa: m['name'] as String?,
    episodes: m['eps'] as int? ?? m['eps_count'] as int?,
    firstAirDate: airDate,
    coverImageUrl: images?['large'] as String? ?? images?['common'] as String?,
    summary: m['summary'] as String?,
  );
  ```
  (`AnimeSearchService._searchBangumi`, same file — each of the five metadata-source methods builds one of these per result)
- **Notes:** `sourceUrl` is what later becomes `Anime.infoUrl` when a result is applied to the edit form — see
  [`../../../../features/multi-source-search.md`](../../../../features/multi-source-search.md).

### `static Future<List<AnimeSearchResult>> searchAll(String query)` <a id="searchall"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 47)
- **Purpose:** Query bangumi.tv, MyAnimeList, AniList, acgsecrets.hk, and filmarks.com in parallel and return one deduplicated result list.
- **Inputs:** `query`.
- **Returns:** `Future<List<AnimeSearchResult>>`.
- **Side effects:** Issues HTTP requests to five (or six, see below) external services concurrently.
- **Algorithm:**
  1. Compute `simplified = ChineseConvert.toSimplified(query)`.
  2. Kick off `_searchBangumi`, `_searchMAL`, `_searchAcgsecrets`, `_searchFilmarks`, `_searchAniList` concurrently, each wrapped in `.catchError((_) => [])` so one source's failure doesn't fail the whole call.
  3. If `simplified != query` (the query had Traditional characters), add a *second* `_searchBangumi(simplified)` call, since bangumi.tv is a mainland-Chinese (Simplified) site.
  4. `Future.wait` all of them, flatten, and deduplicate by `sourceUrl` (falling back to `title` when `sourceUrl` is null) using a `Set<String>` of seen keys, preserving first-seen order.
- **Usage:**
  ```dart
  final results = await AnimeSearchService.searchAll(query);
  ```
  (`lib/features/anime/views/anime_search_dialog.dart`, `_search`)
- **Notes:** `anime1.me` (via [`searchAnime1`](#searchanime1)) is deliberately **not** part of `searchAll` — it returns watch-page title/URL pairs, not full metadata, and is queried separately by the edit page's "find watch URL" flow. See
  [`../../../../features/multi-source-search.md`](../../../../features/multi-source-search.md).

### `static Future<List<AnimeSearchResult>> _searchBangumi(String query)` <a id="searchbangumi"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 82)
- **Purpose:** Query bangumi.tv's legacy subject-search API and map up to 5 hits to `AnimeSearchResult`.
- **Inputs:** `query`.
- **Returns:** `Future<List<AnimeSearchResult>>` — `[]` on a non-200 response or a missing `list` field.
- **Side effects:** One HTTP GET (10s timeout) to `api.bgm.tv`.
- **Algorithm:**
  1. GET `https://api.bgm.tv/search/subject/<urlencoded query>?type=2&responseGroup=large&max_results=5`.
  2. Return `[]` if the status isn't 200 or `json['list']` is absent.
  3. Map each of the first 5 items: prefer `name_cn` for `title` (falling back to `null` if empty), `name` for `titleJa`, `eps` or `eps_count` for episode count, `air_date` parsed via `DateTime.tryParse`, and `images['large']`/`images['common']` for the cover.
- **Usage:**
  ```dart
  _searchBangumi(query).catchError((_) => <AnimeSearchResult>[]),
  ```
  (`AnimeSearchService.searchAll`, same file)
- **Notes:** `type=2` restricts results to the anime subject type on bangumi.tv's API.

### `static Future<List<AnimeSearchResult>> _searchMAL(String query)` <a id="searchmal"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 127)
- **Purpose:** Query MyAnimeList via the public Jikan v4 API and map up to 5 hits to `AnimeSearchResult`.
- **Inputs:** `query`.
- **Returns:** `Future<List<AnimeSearchResult>>` — `[]` on a non-200 response or missing `data`.
- **Side effects:** One HTTP GET (10s timeout) to `api.jikan.moe`.
- **Algorithm:**
  1. GET `https://api.jikan.moe/v4/anime?q=<urlencoded query>&limit=5`.
  2. For each item: read `images.jpg.large_image_url`/`image_url` for the cover; parse `aired.from` via `DateTime.tryParse`; if `broadcast` is present, parse its `day` string (e.g. `"Mondays"`) via [`_parseDayOfWeek`](#parsedayofweek) and take `broadcast.time` as `airTime` directly.
  3. Build an `AnimeSearchResult` with `source: 'MyAnimeList'`, `title` from `title`, `titleJa` from `title_japanese`, `episodes`, and `summary` from `synopsis`.
- **Usage:**
  ```dart
  _searchMAL(query).catchError((_) => <AnimeSearchResult>[]),
  ```
  (`AnimeSearchService.searchAll`, same file)
- **Notes:** Jikan's `broadcast.time` is already in `HH:MM` Japan-time form, so it's passed straight through as `Anime.airTime` without reformatting.

### `static Future<List<AnimeSearchResult>> _searchAcgsecrets(String query)` <a id="searchacgsecrets"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 183)
- **Purpose:** Scrape `acgsecrets.hk`'s per-season anime list (embedded as `application/ld+json` script blocks) and fuzzy-match entries against the query, trying the current season and falling back to the previous one.
- **Inputs:** `query`.
- **Returns:** `Future<List<AnimeSearchResult>>` — up to 5, sorted by descending fuzzy-match score.
- **Side effects:** Up to two HTTP GETs (15s timeout each) to `acgsecrets.hk`, one per season tried.
- **Algorithm:**
  1. Get `[currentSeason, previousSeason]` from [`_recentSeasons`](#recentseasons); compute Traditional and Simplified variants of `query`.
  2. For each season in order: GET the season page; skip on non-200. Extract every `<script type="application/ld+json">` block via regex and JSON-decode it; for each `itemListElement` entry, compute the best [`_similarity`](#similarity) score of the item's `name`/`alternateName`s against `query`/`queryTrad`/`querySimp`; skip items scoring below `0.3`; skip duplicate `url`s already seen.
  3. For a surviving item, pick a Japanese `titleJa` from `alternateName` via [`_containsJapanese`](#containsjapanese) (first Kana-containing alt name), and build an `AnimeSearchResult` with `startDate` parsed via `DateTime.tryParse`.
  4. If the current season already produced any results, stop before trying the previous season (`break`).
  5. Sort all collected `(result, score)` pairs by score descending and return the top 5 results.
- **Usage:**
  ```dart
  _searchAcgsecrets(query).catchError((_) => <AnimeSearchResult>[]),
  ```
  (`AnimeSearchService.searchAll`, same file)
- **Notes:** A JSON-decode failure on any individual `<script>` block is caught per-block (`catch (_) {}`) so one malformed block doesn't abort the whole season's parse.

### `static List<String> _recentSeasons()` <a id="recentseasons"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 267)
- **Purpose:** Compute the `acgsecrets.hk` season codes (`YYYYMM`) for "this season" and "the previous season", newest first.
- **Inputs:** None (uses `DateTime.now()`).
- **Returns:** `List<String>` of exactly 2 season codes.
- **Side effects:** None.
- **Algorithm:** Finds the current season-start month from `[1, 4, 7, 10].lastWhere((s) => m >= s)`; formats `'$year$month'` (zero-padded); computes the previous season by subtracting 3 months, wrapping to `year - 1, 10` when the current season is January.
- **Usage:**
  ```dart
  final seasons = _recentSeasons();
  ```
  (`AnimeSearchService._searchAcgsecrets`, same file)
- **Notes:** None.

### `static bool _containsJapanese(String s)` <a id="containsjapanese"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 288)
- **Purpose:** Detect whether a string contains any Hiragana or Katakana character, used to pick out a Japanese-script alternate title.
- **Inputs:** `s`.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** Iterates `s.runes`, returning `true` on the first code point in `0x3040..0x309F` (Hiragana) or `0x30A0..0x30FF` (Katakana); `false` if none match.
- **Usage:**
  ```dart
  for (final n in altNames) {
    if (_containsJapanese(n)) {
      titleJa = n;
      break;
    }
  }
  ```
  (`AnimeSearchService._searchAcgsecrets`, same file)
- **Notes:** Kanji-only alternate names (which overlap with Chinese characters) are not detected as Japanese by this check — only Kana presence counts, since Kanji alone can't distinguish a Japanese title from a Chinese one.

### `static Future<List<AnimeSearchResult>> _searchFilmarks(String query)` <a id="searchfilmarks"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 303)
- **Purpose:** Scrape `filmarks.com`'s anime search results page for title/cover/URL, with a looser fallback pattern if the primary one finds nothing.
- **Inputs:** `query`.
- **Returns:** `Future<List<AnimeSearchResult>>` — up to 5.
- **Side effects:** One HTTP GET (10s timeout, `Accept-Language: ja`) to `filmarks.com`.
- **Algorithm:**
  1. GET `https://filmarks.com/search/animes?q=<urlencoded query>`; return `[]` on non-200.
  2. Primary pattern: match `<a href="/anime/...">` blocks containing an optional `<img>` and a `class="...title..."` element; take up to 5, decoding HTML entities in the title via [`_decodeHtmlEntities`](#decodehtmlentities).
  3. If the primary pattern found nothing, fall back to a looser pattern matching any `<a href="/anime/<digits>...">` with visible text longer than 1 character.
- **Usage:**
  ```dart
  _searchFilmarks(query).catchError((_) => <AnimeSearchResult>[]),
  ```
  (`AnimeSearchService.searchAll`, same file)
- **Notes:** Neither pattern captures episode count, air date, or day-of-week/air-time — `filmarks.com` results only ever populate `title`/`titleJa`(as scraped)/`sourceUrl`/`coverImageUrl`. HTML-structure scraping like this is inherently fragile to site markup changes.

### `static Future<List<AnimeSearchResult>> _searchAniList(String query)` <a id="searchanilist"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 367)
- **Purpose:** Query the AniList GraphQL API for up to 5 matching media entries.
- **Inputs:** `query`.
- **Returns:** `Future<List<AnimeSearchResult>>` — `[]` on a non-200 response or missing `data.Page.media`.
- **Side effects:** One HTTP POST (10s timeout) to `graphql.anilist.co`.
- **Algorithm:**
  1. POST a fixed GraphQL query (requesting `title`, `episodes`, `startDate`, `airingSchedule`, `coverImage`, `description`, `siteUrl`) with `variables: {search: query}`.
  2. For each `media` item: build `firstAirDate` from `startDate.{year,month,day}` only when all three are present; derive `airDayOfWeek` from that date's `.weekday` (so it reflects the *first* episode's weekday, not a separately-reported broadcast schedule); strip HTML from `description` (replacing `<br>` variants with `\n`, stripping remaining tags, and unescaping `&amp;`/`&lt;`/`&gt;`/`&quot;`/`&#39;`) to build `summary`.
  3. Prefer `title.english`, falling back to `title.romaji`, for `title`; use `title.native` for `titleJa`.
- **Usage:**
  ```dart
  _searchAniList(query).catchError((_) => <AnimeSearchResult>[]),
  ```
  (`AnimeSearchService.searchAll`, same file)
- **Notes:** The GraphQL query also requests `airingSchedule(notYetAired: true, perPage: 1)` but the parsing code below does not currently read that field — `airDayOfWeek` is derived purely from `startDate.weekday` instead.

### `static int? _parseDayOfWeek(String day)` <a id="parsedayofweek"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 466)
- **Purpose:** Parse an English weekday name (as returned by Jikan's `broadcast.day`, e.g. `"Mondays"`) into `Anime.airDayOfWeek`'s `1..7` (Monday..Sunday) numbering.
- **Inputs:** `day`.
- **Returns:** `int?` — `null` if no recognized weekday prefix matches.
- **Side effects:** None.
- **Algorithm:** Lowercases `day` and checks 3-letter prefixes in order (`mon`→1, `tue`→2, `wed`→3, `thu`→4, `fri`→5, `sat`→6, `sun`→7).
- **Usage:**
  ```dart
  if (dayStr != null) airDayOfWeek = _parseDayOfWeek(dayStr);
  ```
  (`AnimeSearchService._searchMAL`, same file)
- **Notes:** Matches by prefix (`startsWith`), so it tolerates both `"Monday"` and `"Mondays"` forms.

### `static Future<List<({String title, String url})>> searchAnime1(String query, {List<String> altQueries = const []})` <a id="searchanime1"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 482)
- **Purpose:** Find candidate `anime1.me` category/watch-page URLs for a title, trying Simplified/Traditional variants and optional alternate queries, with a bigram-substring fallback when nothing matches, ranked by fuzzy similarity.
- **Inputs:** `query`; `altQueries` — additional title variants to also try (e.g. a secondary title from a search result).
- **Returns:** `Future<List<({String title, String url})>>` — up to 10, best match first.
- **Side effects:** One or more HTTP GETs to `anime1.me` (via [`_searchAnime1Single`](#searchanime1single)), one per query variant tried.
- **Algorithm:**
  1. Build a `Set<String>` of query variants: `query`, its Traditional and Simplified forms, plus each non-blank `altQueries` entry and *its* Traditional/Simplified forms.
  2. Run [`_searchAnime1Single`](#searchanime1single) for every variant, merging results and deduplicating by `url`.
  3. If nothing matched, derive a Traditional, letters/numbers-only form of `query`; if it's at least 4 characters, try up to 3 trailing bigrams (2-character substrings, scanning from the end backward) via `_searchAnime1Single`, stopping as soon as one substring yields results — this catches cases like a Traditional query sharing a short substring with the actual series title even though the full titles differ.
  4. Sort all collected results by [`_bestSimilarity`](#bestsimilarity) of each result's `title` against every query variant, descending.
  5. Return the top 10.
- **Usage:**
  ```dart
  final results = await AnimeSearchService.searchAnime1(
    q,
    altQueries: widget.altQueries,
  );
  ```
  (`lib/features/anime/views/anime_edit_page.dart`, `_search` in the "find watch URL" dialog)
- **Notes:** This method (unlike `searchAll`) is not part of the general metadata search — it exists specifically to find a series' `anime1.me` watch-page URL for `Anime.watchUrl`; see
  [`../../../../features/multi-source-search.md`](../../../../features/multi-source-search.md).

### `static double _bestSimilarity(String title, List<String> queries)` <a id="bestsimilarity"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 551)
- **Purpose:** Compute the best fuzzy-similarity score of one candidate title against a list of query variants.
- **Inputs:** `title`, `queries`.
- **Returns:** `double` in `0.0..1.0`.
- **Side effects:** None.
- **Algorithm:** Runs [`_similarity`](#similarity) against each entry in `queries`, keeping the maximum.
- **Usage:**
  ```dart
  allResults.sort((a, b) {
    final sa = _bestSimilarity(a.title, queryVariants);
    final sb = _bestSimilarity(b.title, queryVariants);
    return sb.compareTo(sa); // descending
  });
  ```
  (`AnimeSearchService.searchAnime1`, same file)
- **Notes:** None.

### `static double _similarity(String a, String b)` <a id="similarity"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 565)
- **Purpose:** Score how similar two strings are, combining three measures and taking the best, so both a re-ordered title and a Simplified/Traditional variant of the same title score highly.
- **Inputs:** `a`, `b`.
- **Returns:** `double` in `0.0..1.0`; `0` if either input is empty.
- **Side effects:** None.
- **Algorithm:**
  1. Compute Traditional-normalized forms of both `a` and `b` (`aNorm`, `bNorm`).
  2. For each of `(a, b)` and `(aNorm, bNorm)`:
     - LCS-based Dice: `2 * lcsLength / (len(s1) + len(s2))` via [`_lcsLength`](#lcslength).
     - Character-set Dice (order-independent): `2 * |set1 ∩ set2| / (|set1| + |set2|)` over `.runes.toSet()`.
     - Containment: if one string contains the other, score `0.7 + 0.3 * (shorter.length / longer.length)` (guaranteeing at least `0.7`).
  3. Return the maximum score seen across both normalization passes and all three measures.
- **Usage:**
  ```dart
  final s = _similarity(n, q);
  if (s > bestScore) bestScore = s;
  ```
  (`AnimeSearchService._searchAcgsecrets`, same file — also used by `_bestSimilarity` for `anime1.me` ranking)
- **Notes:** Comparing both the raw and Traditional-normalized forms means a Simplified query can still score well against a Traditional-only title (and vice versa) without either string needing pre-normalization by the caller.

### `static int _lcsLength(String a, String b)` <a id="lcslength"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 599)
- **Purpose:** Compute the longest common subsequence (LCS) length between two strings, the core primitive behind `_similarity`'s LCS-Dice score.
- **Inputs:** `a`, `b`.
- **Returns:** `int`.
- **Side effects:** None.
- **Algorithm:** Standard O(n·m) dynamic-programming LCS using two rolling rows (`prev`/`curr`) instead of a full 2D table to save memory; for matching characters, `curr[j] = prev[j-1] + 1`, else `curr[j] = max(prev[j], curr[j-1])`; swaps and clears the rows after each outer iteration.
- **Usage:**
  ```dart
  final lcs = 2.0 * _lcsLength(s1, s2) / (s1.length + s2.length);
  ```
  (`AnimeSearchService._similarity`, same file)
- **Notes:** O(n·m) is acceptable here specifically because both inputs are short anime titles, not arbitrary-length text, per the source comment.

### `static Future<List<({String title, String url})>> _searchAnime1Single(String query)` <a id="searchanime1single"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 620)
- **Purpose:** Run a single `anime1.me` search query and extract series (not episode) title/URL pairs from the result HTML, trying three fallback regex patterns in priority order.
- **Inputs:** `query`.
- **Returns:** `Future<List<({String title, String url})>>` — `[]` on a non-200 response.
- **Side effects:** One HTTP GET (10s timeout) to `anime1.me`.
- **Algorithm:**
  1. GET `https://anime1.me/?s=<urlencoded query>`; return `[]` on non-200.
  2. Priority 1: match `<a href="https://anime1.me/category/...">` links tagged `rel="...category..."` — these are the series/collection pages.
  3. Priority 2 (only if priority 1 found nothing): match `<a href="https://anime1.me/?cat=<id>">` links.
  4. Priority 3 (only if both above found nothing): match `<h2 class="...entry-title...">` episode-post links, stripping a trailing `" [<episode number>]"` suffix from the title so repeated episodes of the same series collapse to one entry.
  5. Every pattern deduplicates by title (`Set<String> seen`) and decodes HTML entities via [`_decodeHtmlEntities`](#decodehtmlentities).
- **Usage:**
  ```dart
  final partial = await _searchAnime1Single(q);
  for (final r in partial) {
    if (seenUrls.add(r.url)) {
      allResults.add(r);
    }
  }
  ```
  (`AnimeSearchService.searchAnime1`, same file — called once per query variant)
- **Notes:** The three priority tiers exist because `anime1.me`'s search results page mixes category links (clean series-level results) with individual episode-post links (priority 3's fallback) — falling through only when the cleaner patterns yield nothing avoids surfacing dozens of duplicate per-episode entries when a category link was available.

### `static String _decodeHtmlEntities(String text)` <a id="decodehtmlentities"></a>
- **Kind:** static method of `AnimeSearchService`
- **Source:** `lib/features/anime/services/anime_search_service.dart` (line 695)
- **Purpose:** Decode the small fixed set of HTML entities that show up in titles scraped from `filmarks.com` and `anime1.me`.
- **Inputs:** `text`.
- **Returns:** `String`.
- **Side effects:** None.
- **Algorithm:** Chained `replaceAll` for `&amp;`, `&lt;`, `&gt;`, `&quot;`, `&#39;`, `&apos;`, in that fixed order.
- **Usage:**
  ```dart
  titleJa: _decodeHtmlEntities(title),
  ```
  (`AnimeSearchService._searchFilmarks`, same file)
- **Notes:** Only these seven entities are handled — a numeric character reference other than `&#39;` (e.g. `&#8217;`) or a named entity outside this list passes through unescaped.
