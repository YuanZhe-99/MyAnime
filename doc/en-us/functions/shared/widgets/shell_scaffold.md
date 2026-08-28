# lib/shared/widgets/shell_scaffold.dart

`ShellScaffold` is the persistent shell widget rendered by `router.dart`'s `ShellRoute` — it wraps
the current tab (`child`) in a `Scaffold` whose navigation is either a bottom `NavigationBar` or a
side `NavigationRail`, for the five main tabs (Home, Manage, Stats, Kana, Settings). See
[../../../architecture.md](../../../architecture.md#app-shell) and
[../../app/router.md](../../app/router.md) for the route table this widget sits inside, and
[../../../adaptive-layout.md](../../../adaptive-layout.md) for the rule that picks between the two.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `ShellScaffold.new` | constructor (`ShellScaffold`) | B | Create a `ShellScaffold` instance. |
| [`ShellScaffold._currentIndex`](#shellscaffold_currentindex) | method (`ShellScaffold`) | A | Determine which navigation destination is selected for the current route. |
| [`ShellScaffold._destinations`](#shellscaffold_destinations) | method (`ShellScaffold`) | A | Describe the shell's five destinations once, icons and all. |
| [`ShellScaffold.build`](#shellscaffold_build) | method (`ShellScaffold`, widget build) | A | Build the `Scaffold` with a rail or a bottom bar around `child`. |
| `_ShellDestination.new` | constructor (`_ShellDestination`) | B | Create a `_ShellDestination` instance. |

## Documentation

### `int _currentIndex(BuildContext context)` <a id="shellscaffold_currentindex"></a>
- **Kind:** method of `ShellScaffold`
- **Source:** `lib/shared/widgets/shell_scaffold.dart` (approx. line 24)
- **Purpose:** Map the current `go_router` location to the index of the matching destination.
- **Inputs:** `context` — used to read `GoRouterState.of(context).uri.path`.
- **Returns:** `int` — the index into `_routes` (and therefore into whichever navigation widget is
  showing) whose path prefix matches the current location; `0` (Home) if none match.
- **Side effects:** None.
- **Algorithm:**
  1. Read the current path from `GoRouterState.of(context).uri.path`.
  2. Iterate `_routes` (`['/home', '/manage', '/stats', '/kana', '/settings']`) in order; return the
     first index `i` where the current path starts with `_routes[i]`.
  3. If no route matches, return `0`.
- **Usage:**
  ```dart
  final index = _currentIndex(context);
  ```
  (from `ShellScaffold.build`, same file, feeding whichever of the two navigation widgets is built)
- **Notes:** Uses `startsWith`, not exact equality, so nested/non-tab routes rendered inside the
  shell (if any were added under a tab path) would still highlight the corresponding tab. Since
  `router.dart` currently pushes anime detail/edit and duplicate-check as top-level routes outside
  the `ShellRoute`, this matching only actually needs to distinguish the five listed prefixes today.

### `List<_ShellDestination> _destinations(AppLocalizations l10n)` <a id="shellscaffold_destinations"></a>
- **Kind:** method of `ShellScaffold`
- **Source:** `lib/shared/widgets/shell_scaffold.dart` (approx. line 39)
- **Purpose:** Describe the shell's five destinations once, icons and all.
- **Inputs:** `l10n` — for the five `nav*` labels.
- **Returns:** `List<_ShellDestination>` in the same order as `_routes`.
- **Side effects:** None.
- **Algorithm:** Returns a fixed list of five records, each an outline icon, a filled selected
  icon, and a localized label.
- **Usage:**
  ```dart
  for (final d in destinations)
    NavigationRailDestination(
      icon: Icon(d.icon),
      selectedIcon: Icon(d.selectedIcon),
      label: Text(d.label),
    ),
  ```
  (from `ShellScaffold.build`, same file)
- **Notes:** Added in 1.5.4 with the navigation rail. Both the bottom bar and the rail read from
  this one list, so a destination cannot end up in one and not the other, or in a different order
  between them — which would silently break `_currentIndex`, since it indexes both by position.
  The private `_ShellDestination` record carries no logic and is not indexed separately.

### `Widget build(BuildContext context)` <a id="shellscaffold_build"></a>
- **Kind:** method of `ShellScaffold` (widget build)
- **Source:** `lib/shared/widgets/shell_scaffold.dart` (approx. line 74)
- **Purpose:** Build the `Scaffold` with a navigation rail or a bottom bar around `child`.
- **Inputs:** `context`.
- **Returns:** The shell's widget tree.
- **Side effects:** Navigating on a destination tap, via `context.go`.
- **Algorithm:**
  1. Build the destinations and the selected index.
  2. When `useNavigationRail(MediaQuery.sizeOf(context).width)` is false, return the original
     `Scaffold` with a bottom `NavigationBar`.
  3. Otherwise return a `Scaffold` whose body is a `Row` of the rail, a `VerticalDivider(width: 1)`
     and `Expanded(child: child)`.
- **Usage:**
  ```dart
  ShellRoute(
    builder: (context, state, child) => ShellScaffold(child: child),
    ...
  ```
  (from `appRouter` in `lib/app/router.dart`)
- **Notes:** Which navigation appears is `useNavigationRail`'s **width-only** decision, deliberately
  not the app-wide split rule — see
  [../utils/adaptive_layout.md](../utils/adaptive_layout.md#usenavigationrail). Nothing here is
  stateful, so folding a device swaps one for the other on the next frame with no route change and
  nothing to save or restore.

  The rail sets `groupAlignment: 0` to centre its destinations rather than taking the default top
  alignment: a rail top-aligns to sit under a leading menu button or FAB, and this one has neither,
  so five destinations pinned to the top of a 704 dp rail would leave its whole lower half empty.

  It is also wrapped in the standard `LayoutBuilder` → `SingleChildScrollView` →
  `ConstrainedBox(minHeight:)` → `IntrinsicHeight` recipe. Five destinations with labels run to
  roughly 370 logical pixels, which fits every window wide enough to earn a rail today — but a rail
  can appear at compact heights (a phone in landscape is 412), so it is allowed to scroll rather
  than overflow.
