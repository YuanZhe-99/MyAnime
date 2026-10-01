# lib/app/theme.dart

Defines `AppTheme`, a static-only class that builds the app's stock Material 3 `ThemeData` from a
single seed color. Since 1.7.0 the visual system is plain Flutter Material 3 (`ThemeData` +
`ColorScheme.fromSeed`); `flex_color_scheme` is gone. Platform dynamic color (Material You) is **not**
read here — the caller decides whether to pass a dynamic scheme in. Consumed by
`MyAnimeApp.build()` in [`../app/app.md`](app.md) as `theme:`/`darkTheme:`; `ShareService` also
derives its share-image palette from `AppTheme.seedColor`. See
[../../architecture.md](../../architecture.md#app-shell) for where the visual system sits in the
app shell.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `AppTheme._` | constructor (`AppTheme`) | B | Prevent direct instantiation and expose only static members. |
| [`AppTheme.seedColor`](#apptheme-seedcolor) | static constant (`AppTheme`) | A | The app's brand color and the only per-app knob of the visual system. |
| [`AppTheme.scheme`](#apptheme-scheme) | static method (`AppTheme`) | A | Resolve the `ColorScheme` for one brightness: the dynamic scheme if given, else the seed scheme. |
| [`AppTheme.build`](#apptheme-build) | static method (`AppTheme`) | A | Build a stock Material 3 `ThemeData` for one brightness. |
| [`AppTheme.light`](#apptheme-light) | static method (`AppTheme`) | A | Return the light Material theme used by the app. |
| [`AppTheme.dark`](#apptheme-dark) | static method (`AppTheme`) | A | Return the dark Material theme used by the app. |

## Documentation

### `static const Color seedColor` <a id="apptheme-seedcolor"></a>
- **Kind:** static constant of `AppTheme`
- **Source:** `lib/app/theme.dart` (approx. line 16)
- **Purpose:** Hold the app's brand color, `Color(0xFF673AB7)` (deep purple), the only per-app knob of
  the visual system.
- **Inputs:** None.
- **Returns:** `Color`.
- **Side effects:** None.
- **Notes:** Every role of the Material 3 tonal palette is generated from it whenever the platform
  supplies no dynamic scheme. Each app in the series has its own seed so they are told apart at a
  glance. `ShareService` also derives its (always light, never dynamic) share-image palette from it.

### `static ColorScheme scheme(Brightness brightness, [ColorScheme? dynamicScheme])` <a id="apptheme-scheme"></a>
- **Kind:** static method of `AppTheme`
- **Source:** `lib/app/theme.dart` (approx. line 26)
- **Purpose:** Resolve the `ColorScheme` for one brightness.
- **Inputs:** `brightness`; `dynamicScheme` — the platform's wallpaper-derived scheme for that
  brightness, or `null`.
- **Returns:** `ColorScheme` — `dynamicScheme` when given, otherwise
  `ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness)`.
- **Side effects:** None.
- **Algorithm:** `dynamicScheme ?? ColorScheme.fromSeed(...)`.
- **Notes:** Which platforms may pass a dynamic scheme is decided by the **caller**:
  `MyAnimeApp.build` allows Android only (see [app.md](app.md) and
  [platform-notes.md](../../platform-notes.md)).

### `static ThemeData build(Brightness brightness, [ColorScheme? dynamicScheme])` <a id="apptheme-build"></a>
- **Kind:** static method of `AppTheme`
- **Source:** `lib/app/theme.dart` (approx. line 40)
- **Purpose:** Build a stock Material 3 theme for one brightness.
- **Inputs:** `brightness`; `dynamicScheme` — optional platform scheme.
- **Returns:** `ThemeData`.
- **Side effects:** None (pure construction).
- **Algorithm:** Return `ThemeData(useMaterial3: true, colorScheme: scheme(brightness, dynamicScheme),
  inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()))`.
- **Notes:** Deliberately close to Flutter's Material 3 defaults. The only component override is
  **outlined text fields**, which the Material 3 spec allows and which keep every form looking as it
  did before 1.7.0. Everything else is stock: no tinted/blended surfaces, Material 3 dividers, and the
  bottom `NavigationBar` always shows all labels (before 1.7.0 only the selected label was shown).

### `static ThemeData light([ColorScheme? dynamicScheme])` <a id="apptheme-light"></a>
- **Kind:** static method of `AppTheme` (a getter before 1.7.0)
- **Source:** `lib/app/theme.dart` (approx. line 54)
- **Purpose:** Return the light theme used by the app.
- **Inputs:** `dynamicScheme` — optional light platform scheme.
- **Returns:** `ThemeData` — `build(Brightness.light, dynamicScheme)`.
- **Side effects:** None.
- **Usage:**
  ```dart
  MaterialApp.router(
    theme: AppTheme.light(allowDynamic ? lightDynamic : null),
    darkTheme: AppTheme.dark(allowDynamic ? darkDynamic : null),
    themeMode: settings.themeMode,
    ...
  )
  ```
  (from `lib/app/app.dart`, `MyAnimeApp.build`)
- **Notes:** Now a method, so call it as `AppTheme.light()`; it is no longer a getter.

### `static ThemeData dark([ColorScheme? dynamicScheme])` <a id="apptheme-dark"></a>
- **Kind:** static method of `AppTheme` (a getter before 1.7.0)
- **Source:** `lib/app/theme.dart` (approx. line 62)
- **Purpose:** Return the dark theme used by the app.
- **Inputs:** `dynamicScheme` — optional dark platform scheme.
- **Returns:** `ThemeData` — `build(Brightness.dark, dynamicScheme)`.
- **Side effects:** None.
- **Usage:** See `AppTheme.light` above; both are called together in `MyAnimeApp.build`.
- **Notes:** Light and dark differ only in the brightness passed to `scheme`.
