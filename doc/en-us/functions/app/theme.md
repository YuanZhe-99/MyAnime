# lib/app/theme.dart

Defines `AppUiStyle` (the two interface styles) and `AppTheme`, a static-only class that builds the app's
`ThemeData` from a single seed color. Since 1.7.0 the visual system is plain Flutter Material 3
(`ThemeData` + `ColorScheme.fromSeed`); `flex_color_scheme` is gone. Since 1.7.1 the theme comes in two
styles over the same colors: stock **Material 3**, and **Expressive** (the default), a theme-level
approximation of Material 3 Expressive layered on top of it. Platform dynamic color (Material You) is **not**
read here — the caller decides whether to pass a dynamic scheme in. Consumed by
`MyAnimeApp.build()` in [`../app/app.md`](app.md) as `theme:`/`darkTheme:`; `ShareService` also
derives its share-image palette from `AppTheme.seedColor`. See
[../../architecture.md](../../architecture.md#app-shell) for where the visual system sits in the
app shell.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`AppUiStyle`](#appuistyle) | enum | A | The two interface styles the user can choose between: `material3` and `expressive` (1.7.1). |
| `AppTheme._` | constructor (`AppTheme`) | B | Prevent direct instantiation and expose only static members. |
| [`AppTheme.seedColor`](#apptheme-seedcolor) | static constant (`AppTheme`) | A | The app's brand color and the only per-app knob of the visual system. |
| [`AppTheme._morphDuration`](#apptheme-morphduration) | static constant (`AppTheme`, private) | A | How long Expressive buttons take to morph between resting and pressed shapes (1.7.1). |
| [`AppTheme.scheme`](#apptheme-scheme) | static method (`AppTheme`) | A | Resolve the `ColorScheme` for one brightness: the dynamic scheme if given, else the seed scheme. |
| [`AppTheme.build`](#apptheme-build) | static method (`AppTheme`) | A | Build the `ThemeData` for one brightness and interface style. |
| [`AppTheme._morphingButtonStyle`](#apptheme-morphingbuttonstyle) | static method (`AppTheme`, private) | A | Return a button style whose shape morphs from a pill to a rounded square while pressed (1.7.1). |
| [`AppTheme._emphasized`](#apptheme-emphasized) | static method (`AppTheme`, private) | A | Make display, headline and title text styles heavier (1.7.1). |
| [`AppTheme._expressive`](#apptheme-expressive) | static method (`AppTheme`, private) | A | Layer the theme-level Material 3 Expressive approximation onto a stock Material 3 theme (1.7.1). |
| [`AppTheme.light`](#apptheme-light) | static method (`AppTheme`) | A | Return the light Material theme used by the app. |
| [`AppTheme.dark`](#apptheme-dark) | static method (`AppTheme`) | A | Return the dark Material theme used by the app. |

## Documentation

### `enum AppUiStyle` <a id="appuistyle"></a>
- **Kind:** top-level enum
- **Source:** `lib/app/theme.dart` (approx. line 10)
- **Purpose:** Name the two interface styles the user can choose between in Settings › General ›
  Interface style: `material3` and `expressive`.
- **Inputs:** None.
- **Returns:** Enum values `AppUiStyle.material3` and `AppUiStyle.expressive`.
- **Side effects:** None.
- **Notes:** Added in 1.7.1; carries a doc comment but no `Purpose:` line, so it is not counted in
  [INDEX.md](../INDEX.md). `expressive` is the default. It approximates Material 3 Expressive **at the
  theme level** (Flutter ships no Expressive components) and gives narrow windows the floating island
  navigation bar. `material3` is stock Material 3 with the classic full-width bottom bar. The style is
  persisted by `AnimeStorage.setUiStyle` (as the string `'material3'`, or no key for Expressive), held in
  `AppSettings.uiStyle` and passed to `AppTheme.light`/`dark` by `MyAnimeApp.build`; `ShellScaffold`
  reads it to choose the bottom bar. Both styles share the same colors.

### `static const Color seedColor` <a id="apptheme-seedcolor"></a>
- **Kind:** static constant of `AppTheme`
- **Source:** `lib/app/theme.dart` (approx. line 32)
- **Purpose:** Hold the app's brand color, `Color(0xFF673AB7)` (deep purple), the only per-app knob of
  the visual system.
- **Inputs:** None.
- **Returns:** `Color`.
- **Side effects:** None.
- **Notes:** Every role of the Material 3 tonal palette is generated from it whenever the platform
  supplies no dynamic scheme. Each app in the series has its own seed so they are told apart at a
  glance. `ShareService` also derives its (always light, never dynamic) share-image palette from it.
  `ShareService` is unaffected by the interface style.

### `static ColorScheme scheme(Brightness brightness, [ColorScheme? dynamicScheme])` <a id="apptheme-scheme"></a>
- **Kind:** static method of `AppTheme`
- **Source:** `lib/app/theme.dart` (approx. line 47)
- **Purpose:** Resolve the `ColorScheme` for one brightness.
- **Inputs:** `brightness`; `dynamicScheme` — the platform's wallpaper-derived scheme for that
  brightness, or `null`.
- **Returns:** `ColorScheme` — `dynamicScheme` when given, otherwise
  `ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness)`.
- **Side effects:** None.
- **Algorithm:** `dynamicScheme ?? ColorScheme.fromSeed(...)`.
- **Notes:** Which platforms may pass a dynamic scheme is decided by the **caller**:
  `MyAnimeApp.build` allows Android only (see [app.md](app.md) and
  [platform-notes.md](../../platform-notes.md)). Both interface styles share these colors, so switching style never changes the palette.

### `static ThemeData build(Brightness brightness, [ColorScheme? dynamicScheme, AppUiStyle style = AppUiStyle.expressive])` <a id="apptheme-build"></a>
- **Kind:** static method of `AppTheme`
- **Source:** `lib/app/theme.dart` (approx. line 63)
- **Purpose:** Build the theme for one brightness and interface style.
- **Inputs:** `brightness`; `dynamicScheme` — optional platform scheme; `style` — the interface style,
  defaulting to `AppUiStyle.expressive` (new in 1.7.1).
- **Returns:** `ThemeData`.
- **Side effects:** None (pure construction).
- **Algorithm:** Build `base = ThemeData(useMaterial3: true, colorScheme: scheme(brightness,
  dynamicScheme), inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()))` —
  exactly the 1.7.0 theme — then return `_expressive(base)` when `style == AppUiStyle.expressive`, else
  `base`.
- **Notes:** The Material 3 style is deliberately close to Flutter's Material 3 defaults. The only
  component override is **outlined text fields**, which the Material 3 spec allows and which keep every
  form looking as it did before 1.7.0. Everything else is stock: no tinted/blended surfaces, Material 3
  dividers, and the bottom `NavigationBar` always shows all labels (before 1.7.0 only the selected label
  was shown). Expressive layers [`_expressive`](#apptheme-expressive) on top of exactly that theme, so
  the two styles differ only in shape, type weight and component details, never in layout or color.

### `static const Duration _morphDuration` <a id="apptheme-morphduration"></a>
- **Kind:** private static constant of `AppTheme`
- **Source:** `lib/app/theme.dart` (approx. line 36)
- **Purpose:** Hold how long Expressive buttons take to morph between their resting and pressed shapes.
- **Inputs:** None.
- **Returns:** `Duration` — 200 ms.
- **Side effects:** None.
- **Notes:** Added in 1.7.1; carries a doc comment but no `Purpose:` line, so it is not counted in
  [INDEX.md](../INDEX.md). Used as `animationDuration` by `_morphingButtonStyle` and by the
  `SegmentedButton` theme in `_expressive`.

### `static ButtonStyle _morphingButtonStyle()` <a id="apptheme-morphingbuttonstyle"></a>
- **Kind:** private static method of `AppTheme`
- **Source:** `lib/app/theme.dart` (approx. line 86)
- **Purpose:** Return a button style whose shape morphs when pressed.
- **Inputs:** None.
- **Returns:** `ButtonStyle` — pill at rest, rounded square while pressed.
- **Side effects:** None.
- **Algorithm:** A `ButtonStyle` with `animationDuration: _morphDuration` and a `shape` that resolves
  per state: `RoundedRectangleBorder(borderRadius: 12)` while `WidgetState.pressed`, otherwise
  `StadiumBorder()`. `Material` animates between the two shapes.
- **Notes:** Internal helper used within this file only. Approximates the Expressive shape-morph without
  a custom widget. Size and padding are untouched, so no layout moves.

### `static TextTheme _emphasized(TextTheme text)` <a id="apptheme-emphasized"></a>
- **Kind:** private static method of `AppTheme`
- **Source:** `lib/app/theme.dart` (approx. line 102)
- **Purpose:** Make display, headline and title styles heavier.
- **Inputs:** `text` — the base theme's text theme.
- **Returns:** `TextTheme` with emphasized weights.
- **Side effects:** None.
- **Algorithm:** `copyWith` the nine styles: `display*` to `FontWeight.w500`; `headline*` and `title*`
  to `FontWeight.w600`.
- **Notes:** Internal helper used within this file only. Approximates the Expressive "emphasized" type
  scale by weight only; sizes and line heights stay stock, so no text reflows. Body and label styles are
  unchanged.

### `static ThemeData _expressive(ThemeData base)` <a id="apptheme-expressive"></a>
- **Kind:** private static method of `AppTheme`
- **Source:** `lib/app/theme.dart` (approx. line 127)
- **Purpose:** Layer the Material 3 Expressive approximation onto a stock Material 3 theme.
- **Inputs:** `base` — the stock Material 3 theme built by `build`.
- **Returns:** `ThemeData` — `base.copyWith(...)`.
- **Side effects:** None.
- **Algorithm:** `copyWith` the following, all at the theme level:
  - **Text:** `_emphasized(base.textTheme)`.
  - **Buttons:** the `_morphingButtonStyle()` for the Filled, Elevated, Outlined, Text and Icon button
    themes; the `SegmentedButton` theme only gets `animationDuration: _morphDuration`.
  - **Corner radii:** floating action button 20; card 20 (stock 12); dialog 32 (stock 28); bottom sheet
    top corners 32; popup menu and menu 16; chip 12.
  - **Snack bar:** floating behavior with radius 16.
  - **Text fields:** outlined with radius 12 in every border state — outline color at rest, enabled
    and disabled (`onSurface` at 12% alpha); primary color, 2 px, when focused; error color (2 px when
    focused) on error.
  - **Progress indicator and slider:** `ProgressIndicatorThemeData(year2023: false)` and
    `SliderThemeData(year2023: false)`, the 2024 designs. `year2023` is deprecated only because `false`
    will become the default, but it is the sole opt-in, so both lines carry an `ignore:
    deprecated_member_use`.
  - **Page transitions:** `FadeForwardsPageTransitionsBuilder` on Android, Fuchsia, Linux and Windows;
    `CupertinoPageTransitionsBuilder` on iOS and macOS (hence the `package:flutter/cupertino.dart`
    import).
- **Notes:** Internal helper used within this file only. Colors, layout and sizes are untouched. **Not
  imitated** (Flutter has no equivalent): spring motion, wavy progress indicators, button groups, split
  buttons, the FAB menu and floating toolbars. The floating navigation bar that goes with Expressive is
  not part of the theme; `ShellScaffold` shows it when `AppSettings.uiStyle` is
  `AppUiStyle.expressive` (see [shell_scaffold.md](../shared/widgets/shell_scaffold.md)).

### `static ThemeData light([ColorScheme? dynamicScheme, AppUiStyle style = AppUiStyle.expressive])` <a id="apptheme-light"></a>
- **Kind:** static method of `AppTheme` (a getter before 1.7.0)
- **Source:** `lib/app/theme.dart` (approx. line 198)
- **Purpose:** Return the light theme used by the app.
- **Inputs:** `dynamicScheme` — optional light platform scheme; `style` — optional interface style
  (new in 1.7.1, default Expressive).
- **Returns:** `ThemeData` — `build(Brightness.light, dynamicScheme, style)`.
- **Side effects:** None.
- **Usage:**
  ```dart
  MaterialApp.router(
    theme: AppTheme.light(allowDynamic ? lightDynamic : null, settings.uiStyle),
    darkTheme: AppTheme.dark(allowDynamic ? darkDynamic : null, settings.uiStyle),
    themeMode: settings.themeMode,
    ...
  )
  ```
  (from `lib/app/app.dart`, `MyAnimeApp.build`)
- **Notes:** Now a method, so call it as `AppTheme.light()`; it is no longer a getter.

### `static ThemeData dark([ColorScheme? dynamicScheme, AppUiStyle style = AppUiStyle.expressive])` <a id="apptheme-dark"></a>
- **Kind:** static method of `AppTheme` (a getter before 1.7.0)
- **Source:** `lib/app/theme.dart` (approx. line 208)
- **Purpose:** Return the dark theme used by the app.
- **Inputs:** `dynamicScheme` — optional dark platform scheme; `style` — optional interface style
  (new in 1.7.1, default Expressive).
- **Returns:** `ThemeData` — `build(Brightness.dark, dynamicScheme, style)`.
- **Side effects:** None.
- **Usage:** See `AppTheme.light` above; both are called together in `MyAnimeApp.build`.
- **Notes:** Light and dark differ only in the brightness passed to `scheme`.
