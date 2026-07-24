# Multi-Source Search

`anime_search_service.dart` searches or scrapes multiple sources, available in **full builds
only** — see the flavor gating section below and [`../architecture.md`](../architecture.md) for
the `full`/`store` flavor split.

## Sources

- `bangumi.tv` — legacy search API.
- MyAnimeList — via Jikan v4.
- AniList — GraphQL API.
- `acgsecrets.hk` — seasonal page JSON-LD.
- `filmarks.com` — HTML scraping.
- `anime1.me` — used for watch URL lookup specifically (not general metadata search).

## Features

- Result deduplication.
- Simplified/Traditional Chinese variants for Chinese-language sources.
- Fuzzy matching.
- Cover image extraction.
- Saving search result source URLs into `infoUrl` (see [`../data-formats.md`](../data-formats.md)).

Keep public data-source behavior reflected in `PRIVACY_POLICY.md` when sources change.

## Flavor gating

`AnimeSearchService` itself does **not** enforce flavor gating — it is a shared utility. Every
store-reachable caller must gate access explicitly:

- `anime_edit_page.dart` gates its search actions behind `AppFlavor.isFull`, so online anime search
  stays hidden from store-facing UI (`store` flavor: Google Play / App Store builds).
- The desktop local API server (`local_api_server.dart`, see
  [`../platform-notes.md`](../platform-notes.md)) can call `AnimeSearchService.searchAll()`
  directly, because it is a desktop-only feature and desktop builds ship as the `full` flavor, not
  a store/mobile surface.
