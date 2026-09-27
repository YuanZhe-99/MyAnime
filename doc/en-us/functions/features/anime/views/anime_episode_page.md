# lib/features/anime/views/anime_episode_page.dart

Shared full-build viewing entry and correction screen. Reads the latest record, refreshes the directory, previews source-bound manual choices, and opens only explicit page links. The preview and chooser show page addresses so duplicate titles can be distinguished. Saving rereads storage and rejects a changed source.

## Declarations

| Declaration | Tier | Purpose |
|---|---|---|
| `openAnimeWatch` | B | Open a mapped episode or the shared correction screen. |
| `AnimeEpisodeLinksPage` | B | Present a source-bound episode directory and season corrections. |
| `createState` | B | Create directory state. |
| `initState` | B | Load directory and attempt the requested mapped episode. |
| `dispose` | B | Release form controllers. |
| `_choices` | B | Materialize the unsaved correction preview. |
| `_load` | B | Load or refresh a directory without overwriting user fields. |
| `_firstUnwatched` | B | Choose the first eligible local episode without skipping missing links. |
| `_save` | B | Save only the user's corrections against the latest record. |
| `_choose` | B | Let the user assign any real page to one local episode. |
| `_play` | B | Open the selected real episode without changing watch history. |
| `build` | B | Preview season evidence, corrections, missing links and extras. |

## Contract

See [watch-URL behavior](../../../../features/watch-url-lookup.md) and the structured source comments for inputs, results and side effects. Network parsing uses injectable clients; mappings are deterministic. Player objects and temporary credentials are never serialized.
