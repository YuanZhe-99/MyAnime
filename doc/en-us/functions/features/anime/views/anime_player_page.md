# lib/features/anime/views/anime_player_page.dart

Native-first playback with generation-guarded asynchronous work, bounded resolution/startup, immediate decoder disposal, and one-way website fallback. Cleanup errors cannot block fallback. Public dependency injection supports deterministic lifecycle tests. Website errors expose browser access instead of retry loops.

## Declarations

| Declaration | Tier | Purpose |
|---|---|---|
| `AnimePlayerPage` | B | Open one episode with native-first playback and website fallback. |
| `createState` | B | Create playback lifecycle state. |
| `initState` | B | Begin the explicitly requested episode. |
| `_release` | B | Release the native player before replacing it. |
| `_start` | B | Try bounded native playback for the current episode. |
| `_fallback` | B | Move once from native playback to the same episode's website. |
| `dispose` | B | Stop playback when the route leaves the widget tree. |
| `build` | B | Render native controls or the website plus explicit escape actions. |

## Contract

See [watch-URL behavior](../../../../features/watch-url-lookup.md) and the structured source comments for inputs, results and side effects. Network parsing uses injectable clients; mappings are deterministic. Player objects and temporary credentials are never serialized.
