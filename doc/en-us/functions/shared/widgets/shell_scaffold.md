# lib/shared/widgets/shell_scaffold.dart

`ShellScaffold` is the persistent shell widget rendered by `router.dart`'s `ShellRoute` — it wraps
the current tab (`child`) in a `Scaffold` whose navigation is either a bottom bar (the compact floating bar
of the Expressive interface style, the default since 1.7.1 and redesigned in 1.7.2, or the classic
full-width `NavigationBar` of the Material 3 style) or a side `NavigationRail` (on the left or, since 1.7.2, the right), for the main tabs: Home, Manage, Stats and Settings, with Kana between Stats
and Settings while the Kana tab is turned on. It is a `ConsumerWidget` so that it can watch that
preference and the bottom-bar style. See [../../../architecture.md](../../../architecture.md#app-shell) and
[../../app/router.md](../../app/router.md) for the route table this widget sits inside, and
[../../../adaptive-layout.md](../../../adaptive-layout.md) for the rule that picks between the two.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `ShellScaffold.new` | constructor (`ShellScaffold`) | B | Create a `ShellScaffold` instance. |
| [`ShellScaffold._currentIndex`](#shellscaffold_currentindex) | method (`ShellScaffold`) | A | Determine which navigation destination is selected for the current route. |
| [`ShellScaffold._destinations`](#shellscaffold_destinations) | method (`ShellScaffold`) | A | Describe the shell's visible destinations once, paths and icons included. |
| [`ShellScaffold.build`](#shellscaffold_build) | method (`ShellScaffold`, widget build) | A | Build the `Scaffold` with a rail or a bottom bar around `child`. |
| [`_ExpressiveNavBar`](#expressivenavbar) | class (private) | A | The Expressive bottom bar: a compact floating pill that hugs its items (1.7.2; replaces `_FloatingNavBar`). |
| `_ExpressiveNavBar.new` | constructor (`_ExpressiveNavBar`) | B | Create a `_ExpressiveNavBar` instance. |
| `_ExpressiveNavBar.build` | method (`_ExpressiveNavBar`, widget build) | B | Build the island and its items. |
| [`_ExpressiveNavItem`](#expressivenavitem) | class (private) | A | One destination of the bar: icon, plus the label while selected (1.7.2). |
| `_ExpressiveNavItem.new` | constructor (`_ExpressiveNavItem`) | B | Create a `_ExpressiveNavItem` instance. |
| `_ExpressiveNavItem.build` | method (`_ExpressiveNavItem`, widget build) | B | Build the animated pill, tooltip and semantics. |
| `_ShellDestination.new` | constructor (`_ShellDestination`) | B | Create a `_ShellDestination` instance. |

## Documentation

### `int _currentIndex(BuildContext context, List<_ShellDestination> destinations)` <a id="shellscaffold_currentindex"></a>
- **Kind:** method of `ShellScaffold`
- **Source:** `lib/shared/widgets/shell_scaffold.dart` (approx. line 27)
- **Purpose:** Map the current `go_router` location to the index of the matching destination.
- **Inputs:** `context` — used to read `GoRouterState.of(context).uri.path`; `destinations` — the
  visible destinations from [`_destinations`](#shellscaffold_destinations).
- **Returns:** `int` — the index into `destinations` (and therefore into whichever navigation widget
  is showing) whose path prefixes the current location; `0` (Home) if none match.
- **Side effects:** None.
- **Algorithm:**
  1. Read the current path from `GoRouterState.of(context).uri.path`.
  2. Iterate `destinations` in order; return the first index `i` where the current path starts with
     `destinations[i].path`.
  3. If no destination matches, return `0`.
- **Usage:**
  ```dart
  final index = _currentIndex(context, destinations);
  ```
  (from `ShellScaffold.build`, same file, feeding whichever of the two navigation widgets is built)
- **Notes:** Uses `startsWith`, not exact equality, so nested/non-tab routes rendered inside the
  shell (if any were added under a tab path) would still highlight the corresponding tab. Since
  `router.dart` currently pushes anime detail/edit, the metadata-update review and duplicate-check
  as top-level routes outside the `ShellRoute`, this matching only needs to distinguish the tab
  prefixes today. The index is derived from the location on every build and never remembered, so
  hiding the Kana tab cannot leave a stale index behind — Settings moves from index 4 to index 3 and
  is still found by its path.

### `List<_ShellDestination> _destinations(AppLocalizations l10n, {required bool kanaTabEnabled})` <a id="shellscaffold_destinations"></a>
- **Kind:** method of `ShellScaffold`
- **Source:** `lib/shared/widgets/shell_scaffold.dart` (approx. line 48)
- **Purpose:** Describe the shell's visible destinations once, paths and icons included.
- **Inputs:** `l10n` — for the `nav*` labels; `kanaTabEnabled` — `AppSettings.kanaTabEnabled`.
- **Returns:** `List<_ShellDestination>` — `/home`, `/manage`, `/stats`, then `/kana` when
  `kanaTabEnabled`, then `/settings`.
- **Side effects:** None.
- **Algorithm:** Returns a list of four or five records, each a route path, an outline icon, a
  filled selected icon, and a localized label.
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
- **Notes:** Added in 1.5.4 with the navigation rail; since 1.6.0 each record also carries its route
  path, replacing the parallel `_routes` list. Both the bottom bar and the rail read from this one
  list, so a destination cannot end up in one and not the other, in a different order between them,
  or pointing at the wrong route once Kana is filtered out — which would silently break
  `_currentIndex` and `select`, since both index by position. The private `_ShellDestination`
  record carries no logic and is not indexed separately.

### `Widget build(BuildContext context, WidgetRef ref)` <a id="shellscaffold_build"></a>
- **Kind:** method of `ShellScaffold` (widget build)
- **Source:** `lib/shared/widgets/shell_scaffold.dart` (approx. line 93)
- **Purpose:** Build the `Scaffold` with a navigation rail or a bottom bar around `child`.
- **Inputs:** `context`, `ref`.
- **Returns:** The shell's widget tree.
- **Side effects:** Navigating on a destination tap, via `context.go(destinations[i].path)`.
- **Algorithm:**
  1. Watch `kanaTabEnabled`, `uiStyle == AppUiStyle.expressive`, `navPlacement` and `navRailOnRight` from
     `appSettingsProvider` (each through `select`), then build the destinations and the selected index.
  2. Compute `showRail = switch (placement) { NavPlacement.bottom => false, NavPlacement.sideOnWide =>
     useNavigationRail(MediaQuery.sizeOf(context).width), NavPlacement.side => true }` (1.7.2, both styles).
     The default, `bottom`, keeps the bottom bar on every window; before 1.7.2 a wide window always got the rail.
  3. When `showRail` is false and the style is Expressive, return `Scaffold(extendBody: true)` whose
     `bottomNavigationBar` is `_ExpressiveNavBar` and whose body wraps `child` in a `MediaQuery` that raises
     `viewPadding.bottom` to `max(viewPadding.bottom, padding.bottom)`. `extendBody` lets pages draw behind
     the bar and reports its height as `padding.bottom` (read by `navBarAwarePadding`); a page `Scaffold`
     places its FAB from `viewPadding`, so without the raise the FAB sat behind the bar (fixed in 1.7.2).
     For `AppUiStyle.material3` return the plain `Scaffold` with the stock `NavigationBar` (classic; content
     stays above it), on wide windows too while the placement is `bottom`.
  4. Otherwise return a `Scaffold` whose body is a `Row` of the rail and a `VerticalDivider(width: 1)` with
     `Expanded(child: child)`: `[rail, divider, Expanded]` by default, `[Expanded, divider, rail]` when
     `navRailOnRight` is set.
- **Usage:**
  ```dart
  ShellRoute(
    builder: (context, state, child) => ShellScaffold(child: child),
    ...
  ```
  (from `appRouter` in `lib/app/router.dart`)
- **Notes:** Which navigation appears follows `navPlacement`; for `sideOnWide` it is `useNavigationRail`'s **width-only** decision, deliberately
  not the app-wide split rule — see
  [../utils/adaptive_layout.md](../utils/adaptive_layout.md#usenavigationrail). Nothing here is
  stateful, so folding a device swaps one for the other on the next frame with no route change and
  nothing to save or restore. Turning the Kana tab on or off in Settings rebuilds the shell with
  five or four destinations on the next frame.

  Known approximation: width helpers such as `shellContentWidth` still follow `useNavigationRail(width)` rather
  than the placement, so with the bottom bar on a wide window they under-estimate the content width by about 81 dp
  (safe), and with the rail on a phone (`side`) they over-estimate it by the rail width.

  The rail sets `groupAlignment: 0` to centre its destinations rather than taking the default top
  alignment: a rail top-aligns to sit under a leading menu button or FAB, and this one has neither,
  so destinations pinned to the top of a 704 dp rail would leave its whole lower half empty.

  It is also wrapped in the standard `LayoutBuilder` → `SingleChildScrollView` →
  `ConstrainedBox(minHeight:)` → `IntrinsicHeight` recipe. Five destinations (the most there can be)
  with labels run to roughly 370 logical pixels, which fits every window wide enough to earn a rail
  today — but a rail can appear at compact heights (a phone in landscape is 412), so it is allowed
  to scroll rather than overflow.

### `class _ExpressiveNavBar` <a id="expressivenavbar"></a>
- **Kind:** private `StatelessWidget` in `lib/shared/widgets/shell_scaffold.dart` (1.7.2; replaces the 1.7.0 `_FloatingNavBar`)
- **Source:** `lib/shared/widgets/shell_scaffold.dart`
- **Purpose:** Draw the Expressive bottom navigation bar as a compact floating pill that hugs its items,
  modelled on Material 3 Expressive's floating navigation.
- **Inputs:** `destinations`, `selectedIndex`, `onSelected`. `static const islandKey =
  ValueKey('floatingNavBarIsland')` (unchanged from 1.7.0) is the key on the island surface so tests can tell
  it from the classic bar.
- **Returns:** The floating bar, centred above the system inset.
- **Side effects:** None.
- **Algorithm:** `SafeArea(top: false, minimum: EdgeInsets.fromLTRB(16, 0, 16, 12))` → `Padding(top: 8)` →
  `Center(heightFactor: 1)` → `FittedBox(fit: scaleDown)` → `Material(key: islandKey, color:
  surfaceContainer, surfaceTintColor: transparent, elevation: 3, shape: StadiumBorder, clipBehavior:
  antiAlias)` → `Padding(8)` → `Row(mainAxisSize: min)` of `_ExpressiveNavItem`s with a 4 dp gap.
- **Notes:** Unlike the 1.7.0 island (a 480 dp-capped `NavigationBar` in an elevated pill), the bar is as
  wide as its items and no longer a `NavigationBar`; the `FittedBox` scales it down on very narrow screens
  instead of overflowing. It floats over the page: the shell sets `extendBody`, so pages scroll behind it and
  must leave room for it with `navBarAwarePadding` (see
  [../utils/adaptive_layout.md](../utils/adaptive_layout.md#navbarawarepadding)). Used only when the
  Expressive style is active and the bottom bar (not the rail) is showing. The private constructor and `build`
  are Tier B and not documented separately.

### `class _ExpressiveNavItem` <a id="expressivenavitem"></a>
- **Kind:** private `StatelessWidget` in `lib/shared/widgets/shell_scaffold.dart` (1.7.2)
- **Source:** `lib/shared/widgets/shell_scaffold.dart`
- **Purpose:** Draw one destination of the Expressive bar: its icon, plus its label while selected.
- **Inputs:** `destination`, `selected`, `onTap`.
- **Returns:** A tappable pill.
- **Side effects:** Calls `onTap` when tapped.
- **Algorithm:** An `InkWell` (stadium border) around an `AnimatedContainer` (250 ms, `easeOutCubic`, height 48,
  horizontal padding 20 when selected and 16 otherwise, `secondaryContainer` fill when selected) holding the
  icon (filled when selected, outlined otherwise) and, in an `AnimatedSize`, the label in `labelLarge` with an
  8 dp left gap. Unselected items are wrapped in a `Tooltip` with the label; every item is wrapped in
  `Semantics(button: true, selected: ...)` with the label as semantic text for unselected items.
- **Notes:** The selected item shows icon and label side by side in a 48 dp high tonal pill; the others show an
  outlined icon only, so their text is exposed only through the tooltip and the semantic label. The pill's width
  and colour animate when the selection moves.
