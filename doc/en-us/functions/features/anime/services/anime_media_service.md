# lib/features/anime/services/anime_media_service.dart

Session-only native media resolver. Reads the public video data-apireq and posts it unchanged as form data to the same API used by the website. API cookies are scoped to an HTTPS video host; all failures return null for website fallback.

## Declarations

| Declaration | Tier | Purpose |
|---|---|---|
| `AnimeMediaSource` | B | Carry a temporary playable URL and request credentials in memory only. |
| `parseSource` | B | Validate a media source returned by Anime1's own player API. |
| `resolve` | B | Resolve the same short-lived source requested by the website player. |

## Contract

See [watch-URL behavior](../../../../features/watch-url-lookup.md) and the structured source comments for inputs, results and side effects. Network parsing uses injectable clients; mappings are deterministic. Player objects and temporary credentials are never serialized.
