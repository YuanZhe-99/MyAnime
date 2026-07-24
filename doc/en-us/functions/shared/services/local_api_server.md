# lib/shared/services/local_api_server.dart

`LocalApiServer` is the desktop-only local HTTP API described in
[../../platform-notes.md](../../../platform-notes.md) and [../../features/multi-source-search.md](../../../features/multi-source-search.md).
It is a `shelf`-based server, disabled by default, that exposes read/search access to the local
anime library over loopback (or LAN, with credentials). It has no network client role — it is a
server the app runs for other local/LAN tools to call, e.g. the desktop web dashboard or scripts.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`_RankingQuery` constructor](#rankingquery-new) | constructor (private value class) | A | Hold parsed `/anime/ranking` query options. |
| [`port`](#port) | static getter | B | Configured API server port. |
| [`listenAddress`](#listenaddress) | static getter | B | Configured API server listen address. |
| [`enabled`](#enabled) | static getter | B | Whether the API server is enabled in saved settings. |
| [`isRunning`](#isrunning) | static getter | B | Whether the server is currently bound. |
| [`lastError`](#lasterror) | static getter | B | Last startup/runtime error code, if any. |
| [`loadConfig`](#loadconfig) | static method | A | Load API server settings from `storage_config.json`. |
| [`start`](#start) | static method | A | Bind and serve the API server per current config. |
| [`stop`](#stop) | static method | A | Force-close the running server, if any. |
| [`restart`](#restart) | static method | A | Reload config and restart the server. |
| `_handlePing` | static method (route handler) | B | `GET /ping` liveness check. |
| [`_handleSearch`](#handlesearch) | static method (route handler) | A | `POST /anime/search`: proxy a query to `AnimeSearchService`. |
| [`_handleAdd`](#handleadd) | static method (route handler) | A | `POST /anime/add`: create and persist a new anime. |
| [`_handleList`](#handlelist) | static method (route handler) | A | `GET /anime/list`: season-filtered anime listing. |
| [`_handleUnwatched`](#handleunwatched) | static method (route handler) | A | `GET /anime/unwatched`: earliest unwatched aired episode per anime. |
| [`_handleHistory`](#handlehistory) | static method (route handler) | A | `GET /anime/history`: season-filtered anime listing (same shape as list). |
| [`_handleRanking`](#handleranking) | static method (route handler) | A | `GET /anime/ranking`: delegate to `buildRankingSnapshotForQuery`. |
| [`buildRankingSnapshotForQuery`](#buildrankingsnapshotforquery) | static method | A | Pure ranking computation, shared with tests. |
| [`_filterBySeason`](#filterbyseason) | static method | A | Parse `?season=` and filter/sample the anime list. |
| [`_parseRankingQuery`](#parserankingquery) | static method | A | Parse all `/anime/ranking` query parameters into `_RankingQuery`. |
| [`_parseQuarterId`](#parsequarterid) | static method | A | Parse a `YYYYQn` identifier (or `current`). |
| [`_parseAnimeTypeParam`](#parseanimetypeparam) | static method | A | Parse the `type` filter parameter. |
| [`_parseRatingFieldParam`](#parseratingfieldparam) | static method | A | Parse the `field` (rating dimension) parameter. |
| [`_matchesRankingQuery`](#matchesrankingquery) | static method | A | Test one anime against parsed ranking filters. |
| [`_rankingFiltersToJson`](#rankingfilterstojson) | static method | A | Serialize parsed filters back into the response JSON. |
| [`_quarterIndex`](#quarterindex) | static method | A | Encode (year, quarter) as one sortable integer. |
| [`_quarterFromIndex`](#quarterfromindex) | static method | A | Decode a sortable integer back to (year, quarter). |
| [`_quarterId`](#quarterid) | static method | A | Format (year, quarter) as `"YYYYQn"`. |
| [`_animeToJson`](#animetojson) | static method | A | Serialize one `Anime` for API responses. |
| [`_episodeStatusCount`](#episodestatuscount) | static method | A | Count episodes with a given `EpisodeStatus`. |
| [`_episodeScanEnd`](#episodescanend) | static method | A | Determine the last episode number worth scanning. |
| [`_airedEpisodeCount`](#airedepisodecount) | static method | A | Count aired episodes (JST-aware). |
| [`_airedUnwatchedEpisodeCount`](#airedunwatchedepisodecount) | static method | A | Count aired-but-unwatched episodes (JST-aware). |
| [`_ratingToJson`](#ratingtojson) | static method | A | Serialize an `AnimeRating` for API responses. |
| [`_computeCounts`](#computecounts) | static method | A | Derive per-status counts, with legacy key aliases. |
| `_json` | static method | B | Wrap a value as a `200 application/json` `Response`. |
| [`_jstToUtcString`](#jsttoutcstring) | static method | A | Convert a JST-naive `DateTime` to a UTC ISO string. |
| `_error` | static method | B | Build a JSON error `Response` for a given status. |
| [`_parseBody`](#parsebody) | static method | A | Parse the request body as JSON, tolerating malformed input. |
| [`_corsMiddleware`](#corsmiddleware) | static method | A | Permissive CORS middleware for every response. |
| [`_authMiddleware`](#authmiddleware) | static method | A | Enforce Basic Auth / loopback-only access rules. |
| [`_validateBasicAuth`](#validatebasicauth) | static method | A | Validate an `Authorization: Basic` header against configured credentials. |
| [`_errorMiddleware`](#errormiddleware) | static method | A | Catch unhandled handler exceptions as a `500` JSON error. |

## Documentation

### `const _RankingQuery({...})` <a id="rankingquery-new"></a>
- **Kind:** constructor of the private value class `_RankingQuery`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 34).
- **Purpose:** Hold the fully-parsed, typed form of `/anime/ranking`'s query string (time scope,
  optional year/quarter or year/quarter range, type filter, sort field, sort order, result limit).
- **Inputs:** `time` (required `_ApiRankingTime`), optional `year`/`quarter`/`startYear`/
  `startQuarter`/`endYear`/`endQuarter`, optional `type` (`AnimeType?`), required `field`
  (`AnimeRatingField`), required `descending` (`bool`), required `limit` (`int`).
- **Returns:** A new immutable `_RankingQuery`.
- **Side effects:** None.
- **Algorithm:** Plain field assignment; all validation happens in `_parseRankingQuery` before
  construction.
- **Usage:** Built exclusively inside `_parseRankingQuery` after all query parameters have been
  validated; consumed by `_matchesRankingQuery`, `_rankingFiltersToJson`, and
  `buildRankingSnapshotForQuery`.
- **Notes:** Private to this file — it is the internal parsed-request type for the ranking
  endpoint only, not a public model.

### `static Future<void> loadConfig()` <a id="loadconfig"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 98).
- **Purpose:** Read the API server's persisted settings (`apiPort`, `apiListenAddress`,
  `apiEnabled`, `apiUsername`, `apiPassword`) from `storage_config.json` into the class's static
  fields.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Reads `storage_config.json` via `AnimeStorage.readConfig()`; mutates the
  static `_port`/`_listenAddress`/`_enabled`/`_username`/`_password` fields.
- **Algorithm:** Read the config map; apply defaults `apiPort ?? 7788`,
  `apiListenAddress ?? 'localhost'`, `apiEnabled ?? false` when the keys are absent.
- **Usage:** Called by `start()` and `restart()` before (re)binding, and by the settings UI when
  displaying current server config.
- **Notes:** Credentials are read as-is (plaintext in `storage_config.json`, per the app's
  documented security posture); this method performs no validation of their strength.

### `static Future<void> start()` <a id="start"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 112).
- **Purpose:** Bind and start the local API HTTP server according to current settings, or do
  nothing if the feature is disabled.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Network: binds a listening socket (loopback, `0.0.0.0`, or a specific address)
  on the configured port; sets `_server` and `_lastError`; logs to stdout.
- **Algorithm:**
  1. `loadConfig()`, then `stop()` any previously running instance, clear `_lastError`.
  2. If `!_enabled`, return without binding anything.
  3. Determine `isNonLoopback` (listen address is `0.0.0.0`, or neither `localhost` nor
     `127.0.0.1`) and `hasCredentials` (both username and password non-empty). If non-loopback
     and no credentials are configured, set `_lastError = 'credentials_required'` and refuse to
     start — this is the safety rule described in
     [../../platform-notes.md](../../../platform-notes.md): unsafe non-localhost startup without
     credentials is refused outright.
  4. Build a `shelf_router.Router` with routes `GET /ping`, `POST /anime/search`,
     `POST /anime/add`, `GET /anime/list`, `GET /anime/unwatched`, `GET /anime/history`,
     `GET /anime/ranking`.
  5. Wrap the router in a `Pipeline` with, in order, `_corsMiddleware()`, `_authMiddleware()`,
     `_errorMiddleware()`.
  6. Resolve the bind address (`InternetAddress.anyIPv4` for `0.0.0.0`,
     `InternetAddress.loopbackIPv4` for `localhost`/`127.0.0.1`, otherwise a literal
     `InternetAddress`) and call `shelf_io.serve`.
  7. On any bind failure, capture `e.toString()` into `_lastError` instead of throwing.
- **Usage:** Called from the desktop settings UI when the user enables the API server or changes
  its configuration, and during app startup if the server was left enabled.
- **Notes:** Middleware order matters: CORS headers must apply even to auth-rejected responses, so
  `_corsMiddleware` wraps outside `_authMiddleware`.

### `static Future<void> stop()` <a id="stop"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 175).
- **Purpose:** Forcibly close the running server, if one exists.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Closes the bound socket (`force: true`, dropping in-flight connections); sets
  `_server` to `null`.
- **Algorithm:** `await _server?.close(force: true); _server = null;` — a no-op when nothing is
  running.
- **Usage:** Called at the start of `start()` (to avoid double-binding) and by the settings UI when
  the user disables the API server.
- **Notes:** `force: true` means in-flight requests are dropped rather than drained; there is no
  graceful-shutdown path.

### `static Future<void> restart()` <a id="restart"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 185).
- **Purpose:** Reload settings and rebind the server, e.g. after the user changes port/address/
  credentials.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Same as `loadConfig()` + `start()` combined.
- **Algorithm:** `await loadConfig(); await start();` (and `start()` itself calls `stop()` first).
- **Usage:** Called by the settings UI's "Save" action for the API server section.
- **Notes:** None.

### `static Future<Response> _handleSearch(Request request)` <a id="handlesearch"></a>
- **Kind:** static method (route handler) of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 206).
- **Purpose:** Implement `POST /anime/search`: run a query through the multi-source search engine
  and return up to 5 results.
- **Inputs:** `request` — JSON body must contain a non-empty `query` string.
- **Returns:** `Future<Response>` — `400` if the body is missing/invalid or `query` is empty/blank;
  otherwise `200` with a JSON array of result objects.
- **Side effects:** Performs outbound HTTP requests via `AnimeSearchService.searchAll()` (see
  [../../features/multi-source-search.md](../../../features/multi-source-search.md)).
- **Algorithm:** Parse and validate the body, call `AnimeSearchService.searchAll(query.trim())`,
  take the first 5 results, and map each to a flat JSON object (`source`, `sourceUrl`, `title`,
  `titleJa`, `episodes`, `firstAirDate`, `airDayOfWeek`, `airTime`, `coverImageUrl`, `summary`).
- **Usage:** Called by any local/LAN HTTP client hitting `POST /anime/search`; this is the desktop
  API surface's only search entry point (distinct from the in-app search dialog, which calls
  `AnimeSearchService` directly).
- **Notes:** Since `AnimeSearchService` itself performs no flavor gating, this being a desktop-only
  service means store-flavor restrictions on online search do not apply here — the API server is
  a `full`-flavor desktop feature, per this repo's `AGENTS.md`.

### `static Future<Response> _handleAdd(Request request)` <a id="handleadd"></a>
- **Kind:** static method (route handler) of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 239).
- **Purpose:** Implement `POST /anime/add`: create a new anime record from a minimal JSON payload
  and persist it.
- **Inputs:** `request` — JSON body with `title` and/or `titleJa` (at least one required),
  optional `episodes`, `firstAirDate` (ISO string), `airDayOfWeek`, `airTime`, `sourceUrl`.
- **Returns:** `Future<Response>` — `400` on invalid body or missing title; otherwise `200` with
  `{success: true, id, title}`.
- **Side effects:** Persists the new anime via `AnimeStorage.addOrUpdate()`.
- **Algorithm:** Parse the body; require at least one of `title`/`titleJa`; parse `firstAirDate`
  with `DateTime.tryParse`; construct via `Anime.create(...)` (mapping `episodes` to
  `endEpisode` and `sourceUrl` to `infoUrl`); save; respond with the new anime's id and display
  title.
- **Usage:** Called by external tools that want to add an anime programmatically (e.g. a script
  reacting to an RSS feed or a companion app), bypassing the in-app add/search UI.
- **Notes:** This is the only mutating endpoint in the API; every other route is read-only.

### `static Future<Response> _handleList(Request request)` <a id="handlelist"></a>
- **Kind:** static method (route handler) of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 275).
- **Purpose:** Implement `GET /anime/list`: return season-filtered anime with total/status counts.
- **Inputs:** `request` — optional `?season=` query parameter (see `_filterBySeason`).
- **Returns:** `Future<Response>` — `200` with `{total, counts, data}`, where `data` may be a random
  40-item sample when `season=all`.
- **Side effects:** Reads anime storage via `AnimeStorage.load()`.
- **Algorithm:** Load all anime; compute `allFiltered` (unsampled) for accurate `total`/`counts`;
  compute `sampled` (possibly capped to 40 under `season=all`) for the `data` array; serialize each
  with `_animeToJson`.
- **Usage:** Called by any local/LAN client that wants the full or seasonal anime catalog, e.g. a
  companion dashboard.
- **Notes:** `total`/`counts` always reflect the complete filtered set even when `data` is sampled,
  so counts never lie about the underlying library size.

### `static Future<Response> _handleUnwatched(Request request)` <a id="handleunwatched"></a>
- **Kind:** static method (route handler) of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 291).
- **Purpose:** Implement `GET /anime/unwatched`: list, per anime, the single earliest unwatched
  episode that has already aired (JST), sorted soonest-first.
- **Inputs:** `request` (no query parameters consumed).
- **Returns:** `Future<Response>` — `200` with a JSON array; each entry is `_animeToJson(anime)`
  plus `nextUnwatchedEpisode` and `episodeAirDate` (UTC string).
- **Side effects:** Reads anime storage; calls `JstTime.now()`.
- **Algorithm:** For each anime, scan episodes from `startEpisode` to `_episodeScanEnd(anime)`;
  stop at the first `unwatched` episode whose air date is not after now, record it, and `break`
  (only the earliest unwatched episode per anime is reported, not every unwatched episode). Sort
  the result list by `episodeAirDate` ascending, with null dates sorted last.
- **Usage:** Called by external tools wanting a "what should I watch next" feed without opening the
  app.
- **Notes:** An anime contributes at most one row even if it has many aired-unwatched episodes.

### `static Future<Response> _handleHistory(Request request)` <a id="handlehistory"></a>
- **Kind:** static method (route handler) of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 327).
- **Purpose:** Implement `GET /anime/history`: season-filtered anime listing, same response shape
  as `/anime/list`.
- **Inputs:** `request` — optional `?season=` query parameter.
- **Returns:** `Future<Response>` — `200` with `{total, counts, data}`.
- **Side effects:** Reads anime storage.
- **Algorithm:** Identical implementation to `_handleList` (load, filter by season twice —
  unsampled for counts, sampled for data — serialize). It exists as a distinct route/name for API
  consumers that want a semantically named "history" endpoint separate from "list", even though
  the current implementation body is the same season-filter/serialize pipeline.
- **Usage:** Same as `_handleList`; kept as a separate documented endpoint for API stability.
- **Notes:** If `/anime/list` and `/anime/history` are ever meant to diverge (e.g. history
  defaulting to `season=all`), that divergence is not present in the current implementation —
  both currently default to `season=current` via `_filterBySeason`.

### `static Future<Response> _handleRanking(Request request)` <a id="handleranking"></a>
- **Kind:** static method (route handler) of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 343).
- **Purpose:** Implement `GET /anime/ranking`: thin HTTP adapter over
  `buildRankingSnapshotForQuery`.
- **Inputs:** `request` — see `_parseRankingQuery` for all supported query parameters.
- **Returns:** `Future<Response>` — `400` with the parse/validation error message, or `200` with
  the ranking JSON.
- **Side effects:** Reads anime storage.
- **Algorithm:** Load anime data, call `buildRankingSnapshotForQuery(data.animes,
  request.url.queryParameters)`, and translate its `(data, error)` record into an HTTP response.
- **Usage:** Called by any local/LAN client wanting the rated-anime ranking view over HTTP.
- **Notes:** All actual ranking logic lives in `buildRankingSnapshotForQuery` so it can be unit
  tested without a live HTTP server.

### `static ({Map<String, dynamic>? data, String? error}) buildRankingSnapshotForQuery(List<Anime> animes, Map<String, String> queryParameters)` <a id="buildrankingsnapshotforquery"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 361).
- **Purpose:** Pure computation of the `/anime/ranking` response body from an in-memory anime list
  and raw query parameters, factored out of the HTTP handler so it is directly testable.
- **Inputs:** `animes` — the full in-memory anime list; `queryParameters` — the raw HTTP query
  string map.
- **Returns:** A record `(data: Map<String, dynamic>?, error: String?)` — exactly one of the two is
  non-null.
- **Side effects:** None (pure function over its inputs).
- **Algorithm:**
  1. `_parseRankingQuery(queryParameters)`; propagate any parse error immediately.
  2. Filter `animes` to those matching `_matchesRankingQuery` **and** having a non-null score for
     the requested `field` (unrated anime are excluded from ranking entirely).
  3. Sort by score (descending or ascending per `query.descending`), breaking ties by
     `displayTitle` for a stable order.
  4. Take the first `query.limit` entries; build each row as `{rank, score, ...anime JSON}`
     (1-based rank, `_animeToJson` spread in).
  5. Assemble the final map: `total` (post-filter, pre-limit count), `filters`
     (`_rankingFiltersToJson`), `sort` (`{field, order}`), `limit`, `data` (the ranked rows).
- **Usage:** Called by `_handleRanking`; also intended to be called directly from unit tests
  (per its own doc comment: "Shared by the route handler and tests so ranking semantics stay
  verifiable").
- **Notes:** `total` reflects the number of anime that matched the filter and had a score — it is
  not the count after applying `limit`.

### `static List<Anime> _filterBySeason(List<Anime> animes, Request request, {bool sample = true})` <a id="filterbyseason"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 416).
- **Purpose:** Parse the `?season=` query parameter and filter (and optionally sample) the anime
  list accordingly.
- **Inputs:** `animes`; `request` (reads `request.url.queryParameters['season']`); `sample` —
  whether `season=all` may return a random subset (`true` by default).
- **Returns:** `List<Anime>`.
- **Side effects:** None (reads `JstTime.now()` for the `current` case, no mutation).
- **Algorithm:** `season` defaults to `'current'` when absent.
  - `'all'`: return everything unless `sample` is true and there are more than 40 anime, in which
    case shuffle and take 40 (`List<Anime>.from(animes)..shuffle(Random())`).
  - `'unassigned'`: anime with `firstAirDate == null`.
  - `'current'`: compute the current JST year/quarter from `JstTime.now()` and filter by
    `airsInQuarter`.
  - `'YYYYQn'` (regex `^(\d{4})Q([1-4])$`): filter by that explicit quarter.
  - Any other value: treated as invalid and **all** anime are returned unfiltered (fails open, not
    closed).
- **Usage:** Called by `_handleList` and `_handleHistory` (with `sample: false` for count
  computation and the default `sample: true` for the returned `data` array).
- **Notes:** The `all` sampling behavior means two calls with `season=all` on a library over 40
  anime can return different `data` arrays for the same underlying data — callers should treat
  `data` as a preview, not a stable full dump, in that case. Malformed `season` values silently
  fall back to "all", not an error.

### `static ({_RankingQuery? query, String? error}) _parseRankingQuery(Map<String, String> queryParameters)` <a id="parserankingquery"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 456).
- **Purpose:** Parse and validate every `/anime/ranking` query parameter into a typed
  `_RankingQuery`, or return a descriptive error.
- **Inputs:** `queryParameters` — the raw HTTP query string map. Recognized keys include `time`
  (`all`/`quarter`/`year`/`range`), `season` (for `time=quarter`), `year` (for `time=year`),
  `start`/`end` (for `time=range`, as `YYYYQn`), `type`, `field`, `order`, `limit`.
- **Returns:** A record `(query: _RankingQuery?, error: String?)`.
- **Side effects:** None.
- **Algorithm:** Validate `time` against the four allowed literal values (empty defaults to
  `all`); for `quarter`, parse `season` (default `current`) via `_parseQuarterId`; for `year`,
  parse a bare year string; for `range`, parse `start`/`end` via `_parseQuarterId`; delegate `type`
  to `_parseAnimeTypeParam` and `field` to `_parseRatingFieldParam`; parse `order` (`desc`/`asc`,
  default desc) and `limit` (positive integer, with a default and presumably a cap — see the
  source for the exact default/cap constants). Any parse failure short-circuits with a descriptive
  `error` string and a null `query`.
- **Usage:** Called by both `_parseRankingQuery`'s callers: `_handleRanking` (via
  `buildRankingSnapshotForQuery`) and directly by any test exercising ranking query parsing.
- **Notes:** Every error string returned here is what `_handleRanking` surfaces verbatim as the
  `400` response body, so its wording is part of the API's stable error contract.

### `static (int, int)? _parseQuarterId(String? value, {bool allowCurrent})` <a id="parsequarterid"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 557).
- **Purpose:** Parse a `YYYYQn` season identifier (optionally accepting the literal `current`)
  into a `(year, quarter)` pair.
- **Inputs:** `value`; `allowCurrent` — whether the literal string `current` should resolve to
  today's JST quarter.
- **Returns:** `(int, int)?` — `null` on any parse failure.
- **Side effects:** Reads `JstTime.now()` when resolving `current`.
- **Algorithm:** If `allowCurrent` and `value == 'current'`, derive year/quarter from
  `JstTime.now()` the same way `_filterBySeason` does; otherwise match against
  `^(\d{4})Q([1-4])$` and parse the two capture groups.
- **Usage:** Called by `_parseRankingQuery` for both the `quarter` time scope (`season=`) and the
  `range` time scope (`start=`/`end=`).
- **Notes:** Shares its quarter-identifier format and current-quarter derivation with
  `_filterBySeason`, but is a separate implementation local to the ranking endpoint.

### `static ({AnimeType? value, String? error}) _parseAnimeTypeParam(String? value)` <a id="parseanimetypeparam"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 577).
- **Purpose:** Parse the `type` query parameter into an optional `AnimeType` filter.
- **Inputs:** `value` — a raw query string, expected to match an `AnimeType` enum name, or `all`/
  empty for "no filter".
- **Returns:** A record `(value: AnimeType?, error: String?)`.
- **Side effects:** None.
- **Algorithm:** Empty or `all` (case handling per source) maps to `(value: null, error: null)`
  (no type filter); any other value is matched against the `AnimeType` enum names, returning an
  error for unrecognized values.
- **Usage:** Called by `_parseRankingQuery` to populate `_RankingQuery.type`.
- **Notes:** None.

### `static ({AnimeRatingField? value, String? error}) _parseRatingFieldParam(String? value)` <a id="parseratingfieldparam"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 595).
- **Purpose:** Parse the `field` query parameter (which rating dimension to sort/rank by) into an
  `AnimeRatingField`.
- **Inputs:** `value` — raw query string; empty defaults to the overall score field.
- **Returns:** A record `(value: AnimeRatingField?, error: String?)`.
- **Side effects:** None.
- **Algorithm:** Empty value defaults to the "overall" field; otherwise matched against the
  `AnimeRatingField` enum names (visual/story/character/music/enjoyment/overall), returning an
  error for unrecognized values.
- **Usage:** Called by `_parseRankingQuery` to populate `_RankingQuery.field`.
- **Notes:** None.

### `static bool _matchesRankingQuery(Anime anime, _RankingQuery query)` <a id="matchesrankingquery"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 611).
- **Purpose:** Decide whether one anime satisfies the parsed ranking filters (type + time scope),
  independent of whether it has a score.
- **Inputs:** `anime`; `query`.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** If `query.type` is set and doesn't match `anime.effectiveType`, fail immediately.
  Then branch on `query.time`: `all` always passes; `quarter` checks `airsInQuarter(year,
  quarter)`; `year` checks all 4 quarters of that year via `airsInQuarter`; `range` walks every
  quarter index between `_quarterIndex(start)` and `_quarterIndex(end)` (swapping if the range was
  given backwards) via `_quarterFromIndex`, checking `airsInQuarter` for each.
- **Usage:** Called from `buildRankingSnapshotForQuery`'s filter step, and from within itself
  transitively via the `range` branch's per-quarter checks.
- **Notes:** The score-presence check (`anime.rating?.scoreFor(query.field) != null`) is **not**
  part of this function — it is applied separately by the caller, so this function alone answers
  "does this anime belong to the requested time/type scope," not "is it rankable."

### `static Map<String, dynamic> _rankingFiltersToJson(_RankingQuery query)` <a id="rankingfilterstojson"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 645).
- **Purpose:** Serialize the parsed ranking filters back into the `filters` object returned in the
  API response, so clients can see exactly how their query was interpreted.
- **Inputs:** `query`.
- **Returns:** `Map<String, dynamic>` with `time`, optionally `season`/`year`/`start`/`end`
  (only the keys relevant to the selected `time` scope are included), and `type` (`'all'` when
  unset).
- **Side effects:** None.
- **Algorithm:** Conditionally includes `season` (via `_quarterId`) when both `year` and `quarter`
  are set, `year` only when `time == year`, `start`/`end` when the corresponding pairs are set.
- **Usage:** Called from `buildRankingSnapshotForQuery` to build the `filters` field of the
  response.
- **Notes:** None.

### `static int _quarterIndex(int year, int quarter)` <a id="quarterindex"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 664).
- **Purpose:** Encode a (year, quarter) pair as a single monotonically increasing integer, so
  quarter ranges can be compared/iterated with plain integer arithmetic.
- **Inputs:** `year`, `quarter` (1–4).
- **Returns:** `int` (`year * 4 + quarter`).
- **Side effects:** None.
- **Algorithm:** `year * 4 + quarter`.
- **Usage:** Called by `_matchesRankingQuery`'s `range` branch to compute start/end indices.
- **Notes:** Paired with `_quarterFromIndex`, which is its exact inverse.

### `static (int, int) _quarterFromIndex(int index)` <a id="quarterfromindex"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 671).
- **Purpose:** Decode a `_quarterIndex`-encoded integer back into a (year, quarter) pair.
- **Inputs:** `index`.
- **Returns:** `(int year, int quarter)`.
- **Side effects:** None.
- **Algorithm:** `year = (index - 1) ~/ 4; quarter = ((index - 1) % 4) + 1`.
- **Usage:** Called by `_matchesRankingQuery`'s `range` branch when iterating every quarter between
  the start and end index.
- **Notes:** Exact inverse of `_quarterIndex`.

### `static String _quarterId(int year, int quarter)` <a id="quarterid"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 682).
- **Purpose:** Format a (year, quarter) pair as the API's `"YYYYQn"` string form.
- **Inputs:** `year`, `quarter`.
- **Returns:** `String`, e.g. `"2026Q2"`.
- **Side effects:** None.
- **Algorithm:** `'${year}Q$quarter'`.
- **Usage:** Called by `_rankingFiltersToJson` to render `season`/`start`/`end`.
- **Notes:** This is the same string format `_parseQuarterId` parses, and the same format used
  elsewhere in the app for season identifiers (see [../../features/anime-tracking.md](../../../features/anime-tracking.md)).

### `static Map<String, dynamic> _animeToJson(Anime a)` <a id="animetojson"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 689).
- **Purpose:** Serialize one `Anime` into the flat JSON shape used by every API response
  (`/anime/list`, `/anime/unwatched`, `/anime/history`, `/anime/ranking`).
- **Inputs:** `a` — the `Anime` to serialize.
- **Returns:** `Map<String, dynamic>` with identity/URL/schedule fields plus derived fields:
  `status` (`viewingStatus.name`), `nextUnwatchedEpisode`/`nextEpisodeAirDate` (UTC string via
  `_jstToUtcString`), `type`/`manualType`, `watchedEpisodes`/`skippedEpisodes`
  (`_episodeStatusCount`), `airedEpisodes`/`airedUnwatchedEpisodes`, `rating`
  (`_ratingToJson`), and `createdAt`/`modifiedAt` as ISO 8601 strings.
- **Side effects:** None (reads only).
- **Algorithm:** Direct field mapping plus calls to the small helper functions listed above for
  every derived field; see this repo's `AGENTS.md` "Desktop API" section for the documented field
  list.
- **Usage:** Called by every route handler that returns anime rows: `_handleList`,
  `_handleUnwatched`, `_handleHistory`, and (via `buildRankingSnapshotForQuery`) `_handleRanking`.
- **Notes:** Per its own doc comment, "existing keys are preserved and newer keys are additive" —
  this is the API's forward-compatibility contract: new fields may be added but existing ones are
  not renamed or removed without a version bump elsewhere in the release process.

### `static int _episodeStatusCount(Anime anime, EpisodeStatus status)` <a id="episodestatuscount"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 729).
- **Purpose:** Count how many recorded episode statuses equal a given `EpisodeStatus`.
- **Inputs:** `anime`, `status`.
- **Returns:** `int`.
- **Side effects:** None.
- **Algorithm:** Filter `anime.episodeStatuses.values` by equality to `status` and count.
- **Usage:** Called by `_animeToJson` for `watchedEpisodes` (status `watched`) and
  `skippedEpisodes` (status `skippedThisWeek`).
- **Notes:** Only counts episodes that have an explicit status recorded; it does not scan a
  range.

### `static int _episodeScanEnd(Anime anime)` <a id="episodescanend"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 740).
- **Purpose:** Determine the last episode number worth scanning for progress/air-date
  calculations when `anime.endEpisode` is unknown (ongoing series).
- **Inputs:** `anime`.
- **Returns:** `int`.
- **Side effects:** None.
- **Algorithm:** If `endEpisode` is set, return it directly. Otherwise take the highest episode
  number present in `episodeStatuses`, extend it further if `nextUnwatchedEpisode` is higher
  still, and floor the result at `startEpisode`.
- **Usage:** Called by `_handleUnwatched`, `_airedEpisodeCount`, and
  `_airedUnwatchedEpisodeCount` to bound their scans for unknown-length series.
- **Notes:** This is a heuristic bound for ongoing/unknown-length anime, not a guarantee that no
  later episode exists — it only scans through episodes the app already has some record of.

### `static int? _airedEpisodeCount(Anime anime)` <a id="airedepisodecount"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 756).
- **Purpose:** Count how many episodes have aired as of now, JST-aware.
- **Inputs:** `anime`.
- **Returns:** `int?` — `null` when schedule data is incomplete (an episode air date could not be
  computed within the scan range).
- **Side effects:** Reads `JstTime.now()`.
- **Algorithm:** Scan episodes `startEpisode..._episodeScanEnd(anime)`; for each, get its air date
  via `anime.getEpisodeAirDate(episode)` — if any air date is null, abort and return `null`
  immediately (incomplete schedule); stop counting (without erroring) at the first future episode;
  otherwise increment the count.
- **Usage:** Called by `_animeToJson` for the `airedEpisodes` field.
- **Notes:** A single missing air date anywhere in the scan range makes the whole count `null`,
  not just that episode — this is a conservative "don't report a partial number" choice.

### `static int? _airedUnwatchedEpisodeCount(Anime anime)` <a id="airedunwatchedepisodecount"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 774).
- **Purpose:** Count aired episodes that are still unwatched, JST-aware.
- **Inputs:** `anime`.
- **Returns:** `int?` — `null` under the same incomplete-schedule condition as
  `_airedEpisodeCount`.
- **Side effects:** Reads `JstTime.now()`.
- **Algorithm:** Same scan as `_airedEpisodeCount`, but only increments the count when the
  episode's status is `unwatched` (explicit or default).
- **Usage:** Called by `_animeToJson` for the `airedUnwatchedEpisodes` field.
- **Notes:** Shares its null-propagation and scan-bound behavior with `_airedEpisodeCount`;
  the two are separate scans over the same range rather than one combined pass.

### `static Map<String, dynamic>? _ratingToJson(AnimeRating? rating)` <a id="ratingtojson"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 793).
- **Purpose:** Serialize an anime's rating for API responses, or omit it entirely if there is
  nothing to report.
- **Inputs:** `rating` — nullable `AnimeRating`.
- **Returns:** `Map<String, dynamic>?` — `null` if `rating` is null or has no score at all
  (`!rating.hasAnyScore`); otherwise `{overall, effectiveOverall, hasManualOverall, visual, story,
  character, music, enjoyment}`.
- **Side effects:** None.
- **Algorithm:** Null/empty check, then direct field mapping.
- **Usage:** Called by `_animeToJson` for the `rating` field.
- **Notes:** Per its own doc comment, "unknown future rating fields are intentionally not exposed
  through the API" — this is a fixed, curated field set, not a passthrough of the full rating
  model (unlike `_animeToJson`'s "additive" contract for top-level anime fields).

### `static Map<String, int> _computeCounts(List<Anime> animes)` <a id="computecounts"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 812).
- **Purpose:** Derive per-derived-status counts (completed/watching/dropped/not-started) for a
  list of anime, including legacy key aliases for existing API consumers.
- **Inputs:** `animes`.
- **Returns:** `Map<String, int>` with keys `completed`, `watching`, `inProgress` (alias of
  `watching`), `dropped`, `abandoned` (alias of `dropped`), `notStarted`.
- **Side effects:** None.
- **Algorithm:** Single pass over `animes`, switching on each anime's `viewingStatus` (an enum with
  exactly four cases) and incrementing the matching counter; the two alias keys are populated from
  the same counters, not recomputed.
- **Usage:** Called by `_handleList` and `_handleHistory` for the `counts` field.
- **Notes:** The `inProgress`/`abandoned` aliases exist purely for API backward compatibility —
  per its own doc comment, they are "legacy... aliases for existing API consumers" of an earlier
  terminology.

### `static String? _jstToUtcString(DateTime? jst)` <a id="jsttoutcstring"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 854).
- **Purpose:** Convert a JST-naive `DateTime` (as produced by the anime schedule model) into a
  UTC ISO-8601 string with a trailing `Z`, for API serialization.
- **Inputs:** `jst` — nullable JST-based `DateTime`.
- **Returns:** `String?` — `null` if `jst` is null.
- **Side effects:** None.
- **Algorithm:** Null check, then a UTC conversion producing an ISO string ending in `Z` (per this
  repo's `AGENTS.md`: "API date serialization converts JST-derived episode dates to UTC strings
  with `Z`").
- **Usage:** Called by `_handleUnwatched` (for `episodeAirDate`) and `_animeToJson` (for
  `nextEpisodeAirDate`).
- **Notes:** This keeps the API's timestamps machine-parseable in a single, unambiguous timezone
  even though the app's internal scheduling math is JST-based.

### `static Future<Map<String, dynamic>?> _parseBody(Request request)` <a id="parsebody"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 883).
- **Purpose:** Read and JSON-decode a request body, tolerating malformed or non-JSON input.
- **Inputs:** `request`.
- **Returns:** `Future<Map<String, dynamic>?>` — `null` if the body is missing, not valid JSON, or
  not a JSON object.
- **Side effects:** Reads the request body stream.
- **Algorithm:** Wrap `jsonDecode(await request.readAsString())` in a try/catch, returning `null`
  on any decode failure instead of letting an exception propagate to the error middleware.
- **Usage:** Called by `_handleSearch` and `_handleAdd`, both of which turn a `null` result into a
  `400 invalid JSON body` response.
- **Notes:** This is why malformed JSON produces a clean `400` instead of surfacing as a generic
  `500` from `_errorMiddleware`.

### `static Middleware _corsMiddleware()` <a id="corsmiddleware"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 900).
- **Purpose:** Attach permissive CORS headers to every response so browser-based local tools can
  call the API cross-origin.
- **Inputs:** None.
- **Returns:** `Middleware` (a `shelf` middleware factory).
- **Side effects:** None beyond wrapping the handler.
- **Algorithm:** Returns a middleware that adds permissive CORS response headers (allow-origin
  `*` and related headers) around every response the inner handler produces.
- **Usage:** First middleware applied in `start()`'s `Pipeline`, so CORS headers are present even
  on responses `_authMiddleware` rejects.
- **Notes:** "CORS is permissive" is an explicit, documented tradeoff in this repo's `AGENTS.md` —
  it is why `_authMiddleware`'s Basic Auth enforcement (even on loopback, once credentials are
  configured) exists: permissive CORS alone would let any local web page read the API.

### `static Middleware _authMiddleware()` <a id="authmiddleware"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 926).
- **Purpose:** Enforce the API's access-control rule: loopback is trusted by default, but once
  credentials are configured, every request (including loopback) must present valid HTTP Basic
  Auth.
- **Inputs:** None.
- **Returns:** `Middleware`.
- **Side effects:** None beyond wrapping the handler; reads the incoming connection's remote
  address from `request.context['shelf.io.connection_info']`.
- **Algorithm:**
  1. Determine `isLoopback` from the connection's remote address (treating a missing connection
     info as loopback).
  2. If the request is non-loopback and no credentials are configured, reject with `403
     authentication required for non-localhost access`.
  3. If credentials **are** configured, require a valid `Authorization: Basic` header (via
     `_validateBasicAuth`) regardless of loopback status; on failure, respond `401` with a
     `WWW-Authenticate: Basic realm="MyAnime API"` header.
  4. Otherwise (loopback, no credentials configured), pass through to the inner handler.
- **Usage:** Second middleware in `start()`'s `Pipeline`, applied to every route.
- **Notes:** The doc comment is explicit about the reasoning, quoted here because it is the
  security-critical invariant of the whole server: "When credentials are configured, Basic Auth
  is required for every request including loopback, because permissive CORS would otherwise let
  any local web page read the API. Without credentials only loopback requests are allowed."

### `static bool _validateBasicAuth(String header)` <a id="validatebasicauth"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 968).
- **Purpose:** Validate an `Authorization: Basic <base64>` header against the configured
  `_username`/`_password`.
- **Inputs:** `header` — the raw `Authorization` header value.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** Reject anything not starting with `"Basic "`; base64-decode the remainder,
  split on the first `:` into username/password, and compare against the configured credentials.
- **Usage:** Called by `_authMiddleware` when credentials are configured.
- **Notes:** This is a plain equality check against credentials stored in plaintext in
  `storage_config.json`/settings, consistent with this app's documented (and explicitly
  out-of-scope-for-change) security posture around local credential storage.

### `static Middleware _errorMiddleware()` <a id="errormiddleware"></a>
- **Kind:** static method of `LocalApiServer`.
- **Source:** `lib/shared/services/local_api_server.dart` (line 985).
- **Purpose:** Catch any unhandled exception thrown by a route handler and turn it into a clean
  JSON `500` response instead of an unhandled-error crash or a bare stack trace leaking to the
  client.
- **Inputs:** None.
- **Returns:** `Middleware`.
- **Side effects:** None beyond wrapping the handler.
- **Algorithm:** Wrap the inner handler call in a try/catch; on any exception, build a JSON error
  response (via `_error`) rather than propagating.
- **Usage:** Innermost middleware in `start()`'s `Pipeline`, immediately around the router itself.
- **Notes:** This is the last line of defense — routes are expected to return their own `400`/
  `401`/`403` responses for expected failure modes; this middleware only catches truly unexpected
  exceptions.
