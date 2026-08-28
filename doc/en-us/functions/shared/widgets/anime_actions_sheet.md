# lib/shared/widgets/anime_actions_sheet.dart

The long-press action sheet shared by every anime list row in the app. It exists because the list
rows in all three data-browsing modules truncate the title to a single line
(`maxLines: 1, overflow: TextOverflow.ellipsis`), so a long name is unreadable in place and there
was no way to act on the entry without opening the detail page first.

One public entry point, `showAnimeActionsSheet`, plus a private action enum. Called from four tile
builders: `_buildEpisodeTile` in `home_page.dart`, `_buildAnimeTile` in `management_page.dart`, and
both `_buildRankingTile` and the grouped-list tiles in `statistics_page.dart` — each through a
one-line `_showActions` helper that reloads the page when the data changed.

Modelled on the existing precedent `_showResultDetails` in `anime_search_dialog.dart`, which shows
a search result's untruncated titles for the same reason.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`showAnimeActionsSheet`](#showanimeactionssheet) | top-level function | A | Show one anime's full name and its edit and delete actions. |

The private `_AnimeQuickAction` enum (`edit`, `delete`) carries the sheet's result back to the
caller and has no logic of its own, so it is described here rather than indexed as a row.

## Documentation

### `Future<bool> showAnimeActionsSheet(BuildContext context, Anime anime)` <a id="showanimeactionssheet"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/widgets/anime_actions_sheet.dart` (approx. line 24)
- **Purpose:** Show the anime's full name and offer edit and delete, then run the chosen action.
- **Inputs:** `context` — a page context that outlives the sheet; `anime`.
- **Returns:** `Future<bool>` — `true` when the anime was edited or deleted, so the caller should
  reload its list. `false` when the sheet was dismissed, or when a delete confirmation was
  declined.
- **Side effects:** Shows a modal bottom sheet. May navigate to `/anime/edit/{id}`, show a delete
  confirmation dialog, and delete the anime from storage.
- **Algorithm:**
  1. Collect the titles to show: `anime.title` when non-empty, then `anime.titleJa` when non-empty
     and different from `anime.title`.
  2. `showModalBottomSheet<_AnimeQuickAction>` with `showDragHandle: true`, rendering each title as
     a `SelectableText` with **no `maxLines`**, then a divider, then an edit row (`l10n.animeEdit`)
     and a delete row (`l10n.delete`, in the error colour).
  3. Return `false` when nothing was picked or the caller's context is gone.
  4. `edit` — `await context.push('/anime/edit/${anime.id}')`, return `true`.
  5. `delete` — `confirmDelete(context, anime.displayTitle)`; return `false` if declined, otherwise
     `AnimeStorage.deleteAnime(anime.id)` and return `true`.
- **Usage:**
  ```dart
  Future<void> _showActions(Anime anime) async {
    final changed = await showAnimeActionsSheet(context, anime);
    if (changed && mounted) await _load();
  }
  ```
  (from `_ManagementPageState`; the home and statistics pages carry the same helper)
- **Notes:** The sheet returns a choice and is dismissed **before** the chosen action runs, so the
  confirmation dialog and the edit route use the caller's still-mounted page context rather than
  the sheet's, which is gone by then. `context.mounted` is checked after the sheet closes.

  Delete goes through the shared `confirmDelete`
  ([delete_confirm.md](delete_confirm.md)), so this path inherits its global five-minute
  "don't ask again" suppression window for free and behaves identically to deleting from the detail
  page or by swiping a management row.

  The sheet is reached by long-press on touch and by **right-click** on desktop — the tile builders
  wrap in a `GestureDetector` with `onSecondaryTapUp`, or use `InkWell.onSecondaryTap` where the
  tile is already an `InkWell` — because pressing and holding a mouse button is not a natural
  gesture on Windows.
