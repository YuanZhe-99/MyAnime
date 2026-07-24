# lib/app/app.dart

Defines the root widget, `MyAnimeApp`, which wraps `MaterialApp.router` with the app's theme,
locale, localization delegates, `go_router` configuration, and `DevicePreview` integration. It also
defines a small `ScrollBehavior` override so desktop mouse-wheel/trackpad scrolling works everywhere.
See [../../architecture.md](../../architecture.md) for how this fits into the overall app shell
(`main.dart` → `app.dart` → `router.dart`/`theme.dart`).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `_DesktopScrollBehavior.dragDevices` | getter (`_DesktopScrollBehavior`) | B | Enable touch, mouse, and trackpad drag input for scrolling. |
| `MyAnimeApp.new` | constructor (`MyAnimeApp`) | B | Create a `MyAnimeApp` instance. |
| `MyAnimeApp.build` | method (`MyAnimeApp`, widget build) | B | Build the root `MaterialApp.router` with theme/locale/router wiring. |

<Every declaration in this file is Tier B: `_DesktopScrollBehavior` is a one-line `ScrollBehavior`
override with no branching, `MyAnimeApp`'s constructor is a trivial forwarding `const` constructor,
and `build()` is pure widget composition (reading `appSettingsProvider` and forwarding its values
into `MaterialApp.router` parameters) with no logic of its own — see the tiering rule for `build()`
methods and simple forwarding constructors.>

## Documentation

None. All declarations in this file are Tier B (index row only, no full entry) per the tiering
rules — `build()` methods and simple forwarding constructors do not get full documentation
sections.
