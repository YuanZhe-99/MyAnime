# lib/features/anime/services/anime_episode_service.dart

Pure season resolution and bounded paginated collection fetching. The stored directory and corrections are inputs; missing episodes never shift later links.

## Declarations

| Declaration | Tier | Purpose |
|---|---|---|
| `AnimeEpisodeResolution` | B | Return one season's mapping together with its uncertainty. |
| `ensure` | B | Refresh a due public directory once for concurrent UI callers. |
| `_refresh` | B | Fetch a snapshot and guard its write against a changed viewing URL. |
| `isPageUrl` | B | Restrict fetched pages to the configured Anime1 website. |
| `catalogFor` | B | Read a cached directory only for the current viewing source. |
| `getPage` | B | Fetch one complete public page with a bounded request time. |
| `parsePage` | B | Parse article links without reading sidebar recommendations as episodes. |
| `fetch` | B | Traverse an Anime1 collection, retaining partial results on page failure. |
| `_sameTitle` | B | Compare season-bearing titles across script and punctuation variations. |
| `resolve` | B | Select the current season and map its real numbers without closing gaps. |

## Contract

See [watch-URL behavior](../../../../features/watch-url-lookup.md) and the structured source comments for inputs, results and side effects. Network parsing uses injectable clients; mappings are deterministic. Player objects and temporary credentials are never serialized.

Callers of `ensure`: the detail page on entry (unforced, so the 6 h / 168 h window applies) and, since 1.6.6, the detail page's progress-line re-check with `force: true`, because a mapped label comes from this directory. Since 1.6.6 `resolve` also matches groups against the collection's own Anime1 names (`catalog.indexTitle`, `catalog.title`) besides the local aliases; the season-number, unmarked-sequel and exactly-one-candidate guards are unchanged, and a different-season record on the same URL shares those names, so it keeps an unmarked group ambiguous. See [watch-url-lookup.md](../../../../features/watch-url-lookup.md#season-aware-episode-playback-164) and `test/anime_episode_test.dart`.
