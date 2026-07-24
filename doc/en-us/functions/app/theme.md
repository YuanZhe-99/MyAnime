# lib/app/theme.dart

Defines `AppTheme`, a static-only class exposing the app's light and dark `ThemeData` built with
`flex_color_scheme`'s `FlexThemeData`. Consumed by `MyAnimeApp.build()` in
[`../app/app.md`](app.md) as `theme:`/`darkTheme:`. See
[../../architecture.md](../../architecture.md#app-shell) for where the visual system sits in the
app shell.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `AppTheme._` | constructor (`AppTheme`) | B | Prevent direct instantiation and expose only static members. |
| [`AppTheme.light`](#apptheme-light) | getter (`AppTheme`) | A | Return the light Material theme used by the app. |
| [`AppTheme.dark`](#apptheme-dark) | getter (`AppTheme`) | A | Return the dark Material theme used by the app. |

## Documentation

### `static ThemeData get light` <a id="apptheme-light"></a>
- **Kind:** static getter of `AppTheme`
- **Source:** `lib/app/theme.dart` (approx. line 17)
- **Purpose:** Build and return the light-mode `ThemeData` for the whole app.
- **Inputs:** None.
- **Returns:** `ThemeData`, built by `FlexThemeData.light(...)`.
- **Side effects:** None (pure construction; `flex_color_scheme` does no I/O here).
- **Algorithm:**
  1. Call `FlexThemeData.light` with `scheme: FlexScheme.deepPurple` (the app's color scheme seed).
  2. Set `surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold` and `blendLevel: 7` to control how
     much of the primary color tints surfaces vs. the scaffold background.
  3. Pass `FlexSubThemesData` with `blendOnLevel: 10`, `useMaterial3Typography: true`,
     `useM2StyleDividerInM3: true`, `inputDecoratorBorderType: FlexInputBorderType.outline`, and
     `navigationBarLabelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected` (only the
     selected bottom-nav label is shown, matching the five-tab shell in `router.dart`).
  4. Set `useMaterial3: true` and return the resulting `ThemeData`.
- **Usage:**
  ```dart
  MaterialApp.router(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: settings.themeMode,
    ...
  )
  ```
  (from `lib/app/app.dart`, `MyAnimeApp.build`)
- **Notes:** The blend/level constants (`blendLevel: 7`, `blendOnLevel: 10`) are lower than the dark
  theme's (`13`/`20`), which is a deliberate `flex_color_scheme` convention — dark surfaces
  typically need a stronger tint to read correctly against a dark background.

### `static ThemeData get dark` <a id="apptheme-dark"></a>
- **Kind:** static getter of `AppTheme`
- **Source:** `lib/app/theme.dart` (approx. line 37)
- **Purpose:** Build and return the dark-mode `ThemeData` for the whole app.
- **Inputs:** None.
- **Returns:** `ThemeData`, built by `FlexThemeData.dark(...)`.
- **Side effects:** None.
- **Algorithm:** Identical shape to `AppTheme.light` (same `FlexScheme.deepPurple` scheme,
  `FlexSurfaceMode.levelSurfacesLowScaffold`, and `FlexSubThemesData` options), except
  `blendLevel: 13` and `blendOnLevel: 20` — both higher than the light theme's `7`/`10` to give dark
  surfaces a visible primary-color tint.
- **Usage:** See `AppTheme.light` above; both getters are read together in `MyAnimeApp.build`.
- **Notes:** Keep `light` and `dark` in sync when changing shared options (typography, divider
  style, input border, nav label behavior) — only the surface/blend levels are intentionally
  different between the two.
