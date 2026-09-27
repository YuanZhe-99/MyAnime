# lib/features/anime/views/anime_player_page.dart

Native-first playback with generation-guarded asynchronous work, bounded resolution/startup, immediate decoder disposal, and one-way website fallback. Cleanup errors cannot block fallback. Public dependency injection supports deterministic lifecycle tests. Website errors expose browser access instead of retry loops.

Since 1.6.5 native playback draws [`anime_player_controls.dart`](anime_player_controls.md) over the video and records a synced resume point through `PlaybackProgressService`: on every five seconds of media moved, on pause, and in `_release` before the decoder is disposed — which covers leaving, switching episodes and falling back to the website. Past 95% the entry is deleted and a numbered episode is marked watched, once per session. When the duration first becomes known, a stored resume point is applied once and a snackbar offers to start over. A speed picked from the menu carries to the next episode of the session. The website player records nothing, and nothing is recorded without `animeId`.

## Declarations

| Declaration | Tier | Purpose |
|---|---|---|
| `AnimePlaylistEntry` | B | Pair an episode page with its local number (1.6.5). |
| `AnimePlayerPage` | B | Open one episode with native-first playback and website fallback. |
| `createState` | B | Create playback lifecycle state. |
| `initState` | B | Begin the explicitly requested episode. |
| `_trackKey` | B | Progress key of the episode the current decoder plays (1.6.5). |
| `_flush` | B | Record the tracked episode's last known position (1.6.5). |
| `_release` | B | Save progress, then release the native player before replacing it. |
| `_start` | B | Try bounded native playback for the current episode. |
| `_applyResume` | B | Seek once to the stored resume point (1.6.5). |
| `_fallback` | B | Move once from native playback to the same episode's website. |
| `dispose` | B | Stop playback when the route leaves the widget tree. |
| `build` | B | Render native controls or the website plus explicit escape actions. |

## Contract

See [watch-URL behavior](../../../../features/watch-url-lookup.md) and the structured source comments for inputs, results and side effects. Network parsing uses injectable clients; mappings are deterministic. Player objects and temporary credentials are never serialized.
