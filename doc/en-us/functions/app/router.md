# lib/app/router.dart

Defines `appRouter`, the app's single `go_router` `GoRouter` instance: a `ShellRoute` wrapping the
five bottom-navigation tabs (Home, Manage, Stats, Kana, Settings) plus standalone routes for anime
detail/edit and the duplicate-check page. See
[../../architecture.md](../../architecture.md#app-shell) for the full route table and how
`ShellScaffold` (`lib/shared/widgets/shell_scaffold.dart`) renders the bottom navigation bar around
`child`.

## Declarations

This file contains a single top-level declaration, `final appRouter = GoRouter(...)` (line 13). It
is a configuration value (a `GoRouter` instance built from a route list), not a function, method,
constructor, getter, or setter, so it falls outside the repo's Function Explanation Layer
convention described in `AGENTS.md` — consistent with that, the source carries no `/// Purpose:`
comment for it (`grep -c 'Purpose:' lib/app/router.dart` reports 0). There are therefore no rows to
list in this file's Declarations table.

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|

(No rows — zero declarations qualify under the Function Explanation Layer convention; see above.)

## Documentation

None — no Tier A declarations in this file. For reference, the route table itself is:

| Path | Page | Notes |
|---|---|---|
| `/home` | `HomePage` | Shell tab |
| `/manage` | `ManagementPage` | Shell tab |
| `/stats` | `StatisticsPage` | Shell tab |
| `/kana` | `KanaPage` | Shell tab |
| `/settings` | `SettingsPage` | Shell tab |
| `/anime/detail/:id` | `AnimeDetailPage` | Pushed on top of the shell; `id` is required |
| `/anime/edit` | `AnimeEditPage` | Create flow (no `animeId`) |
| `/anime/edit/:id` | `AnimeEditPage` | Edit flow (`animeId` from path) |
| `/duplicate-check` | `DuplicateCheckPage` | Pushed on top of the shell |

The shell routes are wrapped in a `ShellRoute` whose `builder` renders
`ShellScaffold(child: child)` (see
[`../shared/widgets/shell_scaffold.md`](../shared/widgets/shell_scaffold.md)), which supplies the
persistent bottom `NavigationBar`.
