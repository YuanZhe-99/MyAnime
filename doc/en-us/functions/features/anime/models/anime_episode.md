# lib/features/anime/models/anime_episode.dart

Public episode-directory snapshots and user-owned, source-bound corrections. JSON keeps unknown fields and preserves fractional labels.

## Declarations

| Declaration | Tier | Purpose |
|---|---|---|
| `episodeJsonMap` | B | Decode an optional object without losing unrecognized keys. |
| `AnimeEpisodePage` | B | Describe one real episode page without coercing special labels. |
| `number` | B | Distinguish numbered regular episodes from extras. |
| `AnimeEpisodePage.toJson` | B | Serialize a public episode page, preserving unknown fields. |
| `AnimeEpisodePage.fromJson` | B | Read a cached episode page. |
| `AnimeEpisodeCatalog` | B | Hold a public directory snapshot independently of user choices. |
| `AnimeEpisodeCatalog.preservingUnknownFrom` | B | Retain unknown directory and matching-page fields during same-source refresh. |
| `AnimeEpisodeCatalog.toJson` | B | Serialize the directory for external metadata storage. |
| `AnimeEpisodeCatalog.fromJson` | B | Read a directory snapshot from stored metadata. |
| `AnimeEpisodeMapping` | B | Store user-confirmed season boundaries and individual choices. |
| `AnimeEpisodeMapping.toJson` | B | Serialize user choices for ordinary record sync. |
| `AnimeEpisodeMapping.fromJson` | B | Read saved user choices. |

## Contract

See [watch-URL behavior](../../../../features/watch-url-lookup.md) and the structured source comments for inputs, results and side effects. Network parsing uses injectable clients; mappings are deterministic. Player objects and temporary credentials are never serialized.
