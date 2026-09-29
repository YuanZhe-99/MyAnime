# lib/features/anime/views/anime_episode_page.dart

Shared full-build viewing entry and correction screen. Reads the latest record, refreshes the directory, previews source-bound manual choices, and opens only explicit page links. The preview and chooser show page addresses so duplicate titles can be distinguished. Saving rereads storage and rejects a changed source.

Since 1.6.5 the page follows the app-wide split rule: where `useDetailTwoPane` allows, the mapping form sits in a left pane of `detailLeftPaneWidth` and the episodes and extras fill the right pane in columns of at least `episodeTileMinWidth`; otherwise it is one scrolling column. The page is pushed outside the shell and measures the whole window. Each episode row shows its synced resume point (a bar and "Resume at m:ss"), the player receives the record id and the local episode number, and the automatic first playback continues the most recently stopped unwatched episode before falling back to the first unwatched one. See [adaptive layout](../../../../adaptive-layout.md).

## Declarations

| Declaration | Tier | Purpose |
|---|---|---|
| `openAnimeWatch` | B | Open a mapped episode or the shared correction screen. |
| `AnimeEpisodeLinksPage` | B | Present a source-bound episode directory and season corrections. |
| `createState` | B | Create directory state. |
| `initState` | B | Load directory and attempt the requested mapped episode. |
| `dispose` | B | Release form controllers. |
| `_choices` | B | Materialize the unsaved correction preview. |
| `_load` | B | Load or refresh a directory and the playback progress without overwriting user fields. |
| `_firstUnwatched` | B | Choose the first eligible local episode without skipping missing links. |
| `_continueTarget` | B | Choose the mapped, unwatched episode whose playback stopped most recently (1.6.5). |
| `_save` | B | Save only the user's corrections against the latest record. |
| `_choose` | B | Let the user assign any real page to one local episode. |
| `_play` | B | Open one real episode in the player with its record id and local number, then reload progress. |
| `_buildStatusChildren` | B | Source-changed and directory-failed lines (1.6.5). |
| `_buildMappingChildren` | B | The season-mapping form (1.6.5). |
| `_buildResume` | B | Resume bar and text for one stored position (1.6.5). |
| `_buildEpisodeTile` | B | One local episode's tile, with its resume point (1.6.5). |
| `_buildSpecialTile` | B | One extra page's tile, with its resume point (1.6.5). |
| `_buildEpisodeChildren` | B | Episodes and extras laid out in columns (1.6.5). |
| `build` | B | One column, or two panes where the window may split. |

## Contract

See [watch-URL behavior](../../../../features/watch-url-lookup.md) and the structured source comments for inputs, results and side effects. Network parsing uses injectable clients; mappings are deterministic. Player objects and temporary credentials are never serialized.

## Changes in 1.6.7

`_play` now also re-reads the stored record and library after the player closes (the player may have marked an episode watched), so the next play resolves against the current record instead of the copy loaded before playback.
