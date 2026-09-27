# lib/features/anime/views/anime_native_player.dart

The platform boundary between the viewing route and media_kit. Events do not expose credentials to logs or watch-history storage. The concrete adapter owns native resources and adaptive controls, and releases a decoder if video-controller initialization fails.

## Declarations

| Declaration | Tier | Purpose |
|---|---|---|
| `AnimeNativePlayer.errors` | B | Expose decoder failures without logging sensitive media addresses. |
| `AnimeNativePlayer.positions` | B | Expose playback progress for startup timeout cancellation. |
| `AnimeNativePlayer.buildVideo` | B | Render the platform player's controls and video. |
| `AnimeNativePlayer.open` | B | Begin one temporary media source. |
| `AnimeNativePlayer.dispose` | B | Stop playback and release decoder resources. |
| `MediaKitAnimePlayer` | B | Initialize the supported native player on demand. |
| `MediaKitAnimePlayer.errors` | B | Forward decoder error events. |
| `MediaKitAnimePlayer.positions` | B | Forward playback progress. |
| `MediaKitAnimePlayer.buildVideo` | B | Render adaptive video controls. |
| `MediaKitAnimePlayer.open` | B | Open a session-only source with its request headers. |
| `MediaKitAnimePlayer.dispose` | B | Stop and free the player. |

## Contract

See [watch-URL behavior](../../../../features/watch-url-lookup.md) and the structured source comments for inputs, results and side effects. Network parsing uses injectable clients; mappings are deterministic. Player objects and temporary credentials are never serialized.
