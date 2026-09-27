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
