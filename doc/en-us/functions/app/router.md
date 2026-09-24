# lib/app/router.dart

Defines `appRouter`, the app's single `go_router` `GoRouter` instance: a `ShellRoute` wrapping the
main navigation tabs (Home, Manage, Stats, Settings, plus Kana while the Kana tab is turned on) and
standalone routes for anime detail/edit, the metadata-update review and the duplicate-check page. See
[../../architecture.md](../../architecture.md#app-shell) for the full route table and how
`ShellScaffold` (`lib/shared/widgets/shell_scaffold.dart`) renders the navigation around `child`.

## Declarations

`final appRouter = GoRouter(...)` is a configuration value (a `GoRouter` instance built from a route
list), not a function, method, constructor, getter, or setter, so it falls outside the repo's
Function Explanation Layer convention described in `AGENTS.md` and has no row below. The one
function in the file is `kanaRouteRedirect`, added in 1.6.0.

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`kanaRouteRedirect`](#kanarouteredirect) | top-level function | A | Keep `/kana` unreachable while the Kana tab is hidden. |

## Documentation

### `String? kanaRouteRedirect(BuildContext context, GoRouterState state)` <a id="kanarouteredirect"></a>
- **Kind:** top-level function
- **Source:** `lib/app/router.dart` (approx. line 23)
- **Purpose:** Keep `/kana` unreachable while the Kana tab is hidden.
- **Inputs:** `context` — must sit below the app's `ProviderScope`; `state` (unused).
- **Returns:** `String?` — `null` to allow the route, or `'/home'`.
- **Side effects:** None; reads `appSettingsProvider` through
  `ProviderScope.containerOf(context, listen: false)`.
- **Algorithm:** Return `null` when `AppSettings.kanaTabEnabled` is true, otherwise `'/home'`.
- **Usage:**
  ```dart
  GoRoute(
    path: '/kana',
    redirect: kanaRouteRedirect,
    builder: (context, state) => const KanaPage(),
  ),
  ```
  (from `appRouter`, same file; `test/shell_nav_ui_test.dart` uses it on its stub route too)
- **Notes:** The Kana tab is off by default since 1.6.0 (see
  [../../features/kana-reference.md](../../features/kana-reference.md)). Settings load
  asynchronously, so the first frames see `kanaTabEnabled == false`; that bounces nothing real,
  because the initial location is `/home` and the only way into `/kana` is the tab itself.

For reference, the route table is:

| Path | Page | Notes |
|---|---|---|
| `/home` | `HomePage` | Shell tab |
| `/manage` | `ManagementPage` | Shell tab |
| `/stats` | `StatisticsPage` | Shell tab |
| `/kana` | `KanaPage` | Shell tab, only while the Kana tab is on; otherwise redirects to `/home` |
| `/settings` | `SettingsPage` | Shell tab |
| `/anime/detail/:id` | `AnimeDetailPage` | Pushed on top of the shell; `id` is required |
| `/anime/edit` | `AnimeEditPage` | Create flow (no `animeId`); `extra` may carry a `NextSeasonPrefill` from "Add next season" (1.6.0, see [`../features/anime/services/series_service.md`](../features/anime/services/series_service.md#nextseasonprefill)); any other `extra` is ignored |
| `/anime/edit/:id` | `AnimeEditPage` | Edit flow (`animeId` from path); `extra: true` opens the online search on load |
| `/metadata-updates` | `MetadataUpdatesPage` | Pushed on top of the shell; `extra` may carry the current page's anime ids |
| `/recommendations` | `RecommendationsPage` | Pushed on top of the shell from Home's app-bar action (1.6.0, M5) |
| `/duplicate-check` | `DuplicateCheckPage` | Pushed on top of the shell |

`/recommendations` has no redirect: unlike `/kana` it is not a shell tab, and its only entry point,
the Home app-bar action, is shown only while `AppSettings.recommendationsEnabled` is on. See
[`../features/recommendations/views/recommendations_page.md`](../features/recommendations/views/recommendations_page.md).

The shell routes are wrapped in a `ShellRoute` whose `builder` renders
`ShellScaffold(child: child)` (see
[`../shared/widgets/shell_scaffold.md`](../shared/widgets/shell_scaffold.md)), which supplies the
persistent bottom bar or side rail.
