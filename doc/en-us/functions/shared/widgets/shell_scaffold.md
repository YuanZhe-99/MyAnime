# lib/shared/widgets/shell_scaffold.dart

`ShellScaffold` is the persistent shell widget rendered by `router.dart`'s `ShellRoute` — it wraps
the current tab (`child`) in a `Scaffold` with a bottom `NavigationBar` for the five main tabs
(Home, Manage, Stats, Kana, Settings). See
[../../../architecture.md](../../../architecture.md#app-shell) and
[../../app/router.md](../../app/router.md) for the route table this widget sits inside.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `ShellScaffold.new` | constructor (`ShellScaffold`) | B | Create a `ShellScaffold` instance. |
| [`ShellScaffold._currentIndex`](#shellscaffold_currentindex) | method (`ShellScaffold`) | A | Determine which bottom-nav tab is selected for the current route. |
| `ShellScaffold.build` | method (`ShellScaffold`, widget build) | B | Build the `Scaffold` with bottom `NavigationBar` around `child`. |

## Documentation

### `int _currentIndex(BuildContext context)` <a id="shellscaffold_currentindex"></a>
- **Kind:** method of `ShellScaffold`
- **Source:** `lib/shared/widgets/shell_scaffold.dart` (approx. line 23)
- **Purpose:** Map the current `go_router` location to the index of the matching bottom-nav
  destination.
- **Inputs:** `context` — used to read `GoRouterState.of(context).uri.path`.
- **Returns:** `int` — the index into `_routes` (and therefore `NavigationBar.destinations`) whose
  path prefix matches the current location; `0` (Home) if none match.
- **Side effects:** None.
- **Algorithm:**
  1. Read the current path from `GoRouterState.of(context).uri.path`.
  2. Iterate `_routes` (`['/home', '/manage', '/stats', '/kana', '/settings']`) in order; return the
     first index `i` where the current path starts with `_routes[i]`.
  3. If no route matches, return `0`.
- **Usage:**
  ```dart
  bottomNavigationBar: NavigationBar(
    selectedIndex: _currentIndex(context),
    ...
  ```
  (from `ShellScaffold.build`, same file)
- **Notes:** Uses `startsWith`, not exact equality, so nested/non-tab routes rendered inside the
  shell (if any were added under a tab path) would still highlight the corresponding tab. Since
  `router.dart` currently pushes anime detail/edit and duplicate-check as top-level routes outside
  the `ShellRoute`, this matching only actually needs to distinguish the five listed prefixes today.
