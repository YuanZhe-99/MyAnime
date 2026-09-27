# lib/features/anime/views/anime_native_player.dart

The platform boundary between the viewing route and media_kit. Events do not expose credentials to logs or storage. The concrete adapter owns native resources and releases a decoder if video-controller initialization fails.

Since 1.6.5 the boundary also carries duration, play state, rate, seeking and speed control, and `buildVideo` takes the app's controls builder: media_kit's stock controls are replaced, while its wakelock and pause-in-background defaults stay. `AnimeFullscreenHost` wraps media_kit's context-based fullscreen helpers, which on phones hide the system bars and lock landscape and on desktop use native fullscreen; a `Builder` supplies the context, so the same host works inside media_kit's fullscreen route.

## Declarations

| Declaration | Tier | Purpose |
|---|---|---|
| `AnimeFullscreenHost.isFullscreen` | B | Report whether the video fills the screen. |
| `AnimeFullscreenHost.toggle` | B | Enter or leave fullscreen. |
| `AnimeFullscreenHost.exit` | B | Leave fullscreen when in it. |
| `AnimeNativePlayer.errors` | B | Expose decoder failures without logging sensitive media addresses. |
| `AnimeNativePlayer.positions` | B | Expose playback progress. |
| `AnimeNativePlayer.durations` | B | Expose the media duration once known. |
| `AnimeNativePlayer.playing` | B | Expose play/pause changes. |
| `AnimeNativePlayer.rates` | B | Expose rate changes. |
| `AnimeNativePlayer.position` | B | Current position. |
| `AnimeNativePlayer.duration` | B | Current duration, zero while unknown. |
| `AnimeNativePlayer.isPlaying` | B | Whether playback runs. |
| `AnimeNativePlayer.rate` | B | Current rate. |
| `AnimeNativePlayer.seek` | B | Jump to a position. |
| `AnimeNativePlayer.play` | B | Start or resume. |
| `AnimeNativePlayer.pause` | B | Pause. |
| `AnimeNativePlayer.playOrPause` | B | Toggle. |
| `AnimeNativePlayer.setRate` | B | Change speed. |
| `AnimeNativePlayer.buildVideo` | B | Render the video with the app's own controls. |
| `AnimeNativePlayer.open` | B | Begin one temporary media source. |
| `AnimeNativePlayer.dispose` | B | Stop playback and release decoder resources. |
| `_ContextFullscreenHost` | B | Wrap the build context the controls are drawn in. |
| `_ContextFullscreenHost.isFullscreen` | B | Report fullscreen state. |
| `_ContextFullscreenHost.toggle` | B | Toggle fullscreen. |
| `_ContextFullscreenHost.exit` | B | Leave fullscreen. |
| `MediaKitAnimePlayer` | B | Initialize the supported native player on demand. |
| `MediaKitAnimePlayer.errors` | B | Forward decoder error events. |
| `MediaKitAnimePlayer.positions` | B | Forward playback progress. |
| `MediaKitAnimePlayer.durations` | B | Forward duration changes. |
| `MediaKitAnimePlayer.playing` | B | Forward play/pause changes. |
| `MediaKitAnimePlayer.rates` | B | Forward rate changes. |
| `MediaKitAnimePlayer.position` | B | Read the current position. |
| `MediaKitAnimePlayer.duration` | B | Read the current duration. |
| `MediaKitAnimePlayer.isPlaying` | B | Read whether playback runs. |
| `MediaKitAnimePlayer.rate` | B | Read the current rate. |
| `MediaKitAnimePlayer.seek` | B | Seek the decoder. |
| `MediaKitAnimePlayer.play` | B | Start playback. |
| `MediaKitAnimePlayer.pause` | B | Pause playback. |
| `MediaKitAnimePlayer.playOrPause` | B | Toggle playback. |
| `MediaKitAnimePlayer.setRate` | B | Change speed. |
| `MediaKitAnimePlayer.buildVideo` | B | Render the video with the app's controls. |
| `MediaKitAnimePlayer.open` | B | Open a session-only source with its request headers. |
| `MediaKitAnimePlayer.dispose` | B | Stop and free the player. |

`AnimePlayerControlsBuilder` is a typedef without a `/// Purpose:` comment.

## Contract

See [watch-URL behavior](../../../../features/watch-url-lookup.md) and the structured source comments for inputs, results and side effects. Network parsing uses injectable clients; mappings are deterministic. Player objects and temporary credentials are never serialized.
