# lib/shared/services/tray_service.dart

`TrayService` is a desktop-only singleton that wires up the system tray icon/menu (via
`tray_manager`) and window show/hide/close behavior (via `window_manager`) for Windows, macOS, and
Linux. It reads and persists the `minimizeToTray`/`closeToTray` preferences through
`AnimeStorage`'s config file, and also toggles the macOS Dock icon through a small native
`MethodChannel`. See [`../../../platform-notes.md`](../../../platform-notes.md)'s "Desktop API
server, tray, and launch-at-startup" section for how this fits alongside `local_api_server.dart`
and `launch_at_startup`.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`TrayService._`](#trayservice-_) | constructor (`TrayService`) | B | Private constructor backing the `TrayService.instance` singleton. |
| `minimizeToTray` | getter (`TrayService`) | B | Current minimize-to-tray preference. |
| `closeToTray` | getter (`TrayService`) | B | Current close-to-tray preference. |
| [`init`](#init) | method (`TrayService`) | A | Initialize the tray icon/menu and window listeners on supported desktop platforms. |
| [`_setupTray`](#_setuptray) | method (`TrayService`) | A | Set the tray icon/tooltip and build the initial context menu. |
| `_rebuildMenu` | method (`TrayService`) | B | Rebuild the tray context menu using the current locale's labels. |
| [`setMinimizeToTray`](#setminimizetotray) | method (`TrayService`) | A | Persist and apply the minimize-to-tray preference. |
| [`setCloseToTray`](#setclosetotray) | method (`TrayService`) | A | Persist and apply the close-to-tray preference. |
| [`updateLocale`](#updatelocale) | method (`TrayService`) | A | Update the locale used for tray menu labels and rebuild the menu if already initialized. |
| `onTrayIconMouseDown` | method (`TrayService`) | B | Show the window when the tray icon is left-clicked. |
| `onTrayIconRightMouseDown` | method (`TrayService`) | B | Pop up the tray context menu on right-click. |
| [`onTrayMenuItemClick`](#ontraymenuitemclick) | method (`TrayService`) | A | Handle Show/Quit tray menu selections. |
| [`onWindowClose`](#onwindowclose) | method (`TrayService`) | A | Hide to tray or destroy the window when the OS close button is pressed. |
| [`onWindowMinimize`](#onwindowminimize) | method (`TrayService`) | A | Hide to tray when the window is minimized, if enabled. |
| `_showWindow` | method (`TrayService`) | B | Show, focus, and un-hide-from-Dock the main window. |
| `_setDockIconVisible` | method (`TrayService`) | B | Toggle macOS Dock icon visibility via a native channel call. |

## Documentation

### `TrayService._()` <a id="trayservice-_"></a>
- **Kind:** private named constructor of `TrayService`
- **Source:** `lib/shared/services/tray_service.dart` (approx. line 17)
- **Purpose:** Back the module-level singleton `TrayService.instance` and prevent external code
  from constructing another instance.
- **Inputs:** None.
- **Returns:** A new `TrayService` instance (only ever constructed once, for `instance`).
- **Side effects:** None.
- **Algorithm:** Empty body; `static final TrayService instance = TrayService._();` is the only
  call site.
- **Usage:** Not called directly — use `TrayService.instance`.
- **Notes:** None.

### `Future<void> init()` <a id="init"></a>
- **Kind:** method of `TrayService`
- **Source:** `lib/shared/services/tray_service.dart` (approx. line 46)
- **Purpose:** One-time setup: load the persisted tray preferences, hook window-close prevention,
  build the tray icon and menu, and register listeners.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Reads `AnimeStorage.readConfig()`; initializes `window_manager`; registers
  `this` as both a `WindowListener` and a `TrayListener`; sets the tray icon/tooltip/menu.
- **Algorithm:**
  1. Return immediately if already initialized, or if the platform is not Windows/macOS/Linux.
  2. Read `minimizeToTray`/`closeToTray` from the persisted config (defaulting to `false`).
  3. Initialize `windowManager`, register `this` as a listener, and call
     `setPreventClose(_closeToTray)` so the native close button can be intercepted.
  4. Build the tray icon/menu via [`_setupTray`](#_setuptray) and register `this` as the
     `TrayListener`.
  5. Mark initialized.
- **Usage:**
  ```dart
  await TrayService.instance.init();
  ```
  (from `lib/main.dart`, during startup on desktop platforms)
- **Notes:** Idempotent via the `_initialized` guard — safe to call more than once.

### `Future<void> _setupTray()` <a id="_setuptray"></a>
- **Kind:** private method of `TrayService`
- **Source:** `lib/shared/services/tray_service.dart` (approx. line 69)
- **Purpose:** Set the tray icon (platform-specific asset) and tooltip, then build the initial
  context menu.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Calls `trayManager.setIcon`/`setToolTip`; indirectly sets the context menu via
  [`_rebuildMenu`](#_rebuildmenu).
- **Algorithm:** Picks `assets/icon/app_icon.ico` on Windows and `assets/icon/app_icon.png`
  otherwise, sets it as the tray icon, sets the tooltip to `"MyAnime!!!!!"`, then rebuilds the menu.
- **Usage:** Called only from [`init`](#init).
- **Notes:** None.

### `Future<void> setMinimizeToTray(bool value)` <a id="setminimizetotray"></a>
- **Kind:** method of `TrayService`
- **Source:** `lib/shared/services/tray_service.dart` (approx. line 100)
- **Purpose:** Update the in-memory minimize-to-tray flag and persist it to config.
- **Inputs:** `value` — the new preference.
- **Returns:** `Future<void>`.
- **Side effects:** Writes `minimizeToTray` into the persisted config file via
  `AnimeStorage.writeConfig`.
- **Algorithm:** Set `_minimizeToTray = value`, read the current config, set the
  `minimizeToTray` key, write it back.
- **Usage:**
  ```dart
  TrayService.instance.setMinimizeToTray(v);
  ```
  (from `lib/features/settings/views/settings_page.dart`, the "Minimize to tray" settings toggle)
- **Notes:** Does not itself change window behavior at this instant — it only affects the next
  minimize event's handling in [`onWindowMinimize`](#onwindowminimize).

### `Future<void> setCloseToTray(bool value)` <a id="setclosetotray"></a>
- **Kind:** method of `TrayService`
- **Source:** `lib/shared/services/tray_service.dart` (approx. line 112)
- **Purpose:** Update the in-memory close-to-tray flag, persist it, and immediately re-arm/disarm
  the native close-prevention hook.
- **Inputs:** `value` — the new preference.
- **Returns:** `Future<void>`.
- **Side effects:** Writes `closeToTray` into the persisted config; calls
  `windowManager.setPreventClose(value)`.
- **Algorithm:** Set `_closeToTray = value`, persist it to config, then call
  `windowManager.setPreventClose(value)` so the OS close button is intercepted (or not)
  immediately, unlike `setMinimizeToTray` which only takes effect on the next event.
- **Usage:**
  ```dart
  TrayService.instance.setCloseToTray(v);
  ```
  (from `lib/features/settings/views/settings_page.dart`, the "Close to tray" settings toggle)
- **Notes:** Unlike [`setMinimizeToTray`](#setminimizetotray), this one has an immediate
  side effect on window-manager close interception, not just future minimize events.

### `Future<void> updateLocale(Locale locale)` <a id="updatelocale"></a>
- **Kind:** method of `TrayService`
- **Source:** `lib/shared/services/tray_service.dart` (approx. line 125)
- **Purpose:** Update the locale used to localize tray menu item labels, rebuilding the menu if the
  tray has already been initialized.
- **Inputs:** `locale` — the new app locale.
- **Returns:** `Future<void>`.
- **Side effects:** May rebuild the tray context menu (`trayManager.setContextMenu`).
- **Algorithm:** Store `locale`; if `_initialized`, call [`_rebuildMenu`](#_rebuildmenu) so the
  "Show"/"Quit" labels immediately reflect the new language.
- **Usage:** Called when the app's locale changes (app-wide locale provider listener), so the tray
  menu never shows a stale-language label after the user changes language in Settings.
- **Notes:** No-op on the menu rebuild until `init()` has run once (`_initialized` guard) — the
  locale is still remembered for when `init()` does run.

### `void onTrayMenuItemClick(MenuItem menuItem)` <a id="ontraymenuitemclick"></a>
- **Kind:** override method of `TrayService` (`TrayListener`)
- **Source:** `lib/shared/services/tray_service.dart` (approx. line 157)
- **Purpose:** Handle the user selecting "Show" or "Quit" from the tray context menu.
- **Inputs:** `menuItem` — the clicked menu item (`key` distinguishes `'show'` vs `'quit'`).
- **Returns:** None.
- **Side effects:** Shows/focuses the window, or disables close-prevention and closes the window.
- **Algorithm:** Switch on `menuItem.key`: `'show'` calls [`_showWindow`](#_showwindow); `'quit'`
  calls `windowManager.setPreventClose(false)` then `windowManager.close()` so quitting from the
  tray always actually exits, even when close-to-tray is enabled.
- **Usage:** Invoked by `tray_manager` when the user clicks a menu entry; not called directly from
  app code.
- **Notes:** The `'quit'` branch deliberately disables prevent-close first — otherwise the close
  request would just re-hide the window instead of exiting.

### `void onWindowClose()` <a id="onwindowclose"></a>
- **Kind:** override method of `TrayService` (`WindowListener`)
- **Source:** `lib/shared/services/tray_service.dart` (approx. line 178)
- **Purpose:** Decide whether the OS close button hides the window to the tray or actually
  destroys it.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Hides the window and dims the macOS Dock icon, or destroys the window/process.
- **Algorithm:** If `_closeToTray`, call `windowManager.hide()` then
  [`_setDockIconVisible(false)`](#_setdockiconvisible); otherwise call `windowManager.destroy()`.
- **Usage:** Invoked by `window_manager` when the native close button is pressed (only reachable
  because `init()` called `setPreventClose`); not called directly.
- **Notes:** Only fires at all when `windowManager.setPreventClose(true)` is active, i.e. when
  `closeToTray` was enabled at some point during this session.

### `void onWindowMinimize()` <a id="onwindowminimize"></a>
- **Kind:** override method of `TrayService` (`WindowListener`)
- **Source:** `lib/shared/services/tray_service.dart` (approx. line 193)
- **Purpose:** Hide the window to the tray when minimized, if the minimize-to-tray preference is
  enabled.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** May hide the window and dim the macOS Dock icon.
- **Algorithm:** If `_minimizeToTray`, call `windowManager.hide()` then
  `_setDockIconVisible(false)`; otherwise do nothing (normal OS minimize proceeds).
- **Usage:** Invoked by `window_manager` on a minimize event; not called directly.
- **Notes:** None.

