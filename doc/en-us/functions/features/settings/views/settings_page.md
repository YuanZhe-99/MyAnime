# lib/features/settings/views/settings_page.dart

`SettingsPage` is the app's main Settings screen: theme/locale/calendar preferences (backed by
`shared/providers/app_settings.dart`), the reminder toggle, data actions (WebDAV sync entry point,
backup entry point, ZIP/Markdown export/import, duplicate check, storage location), desktop-only
tray/auto-start/local-API-server controls, and the About section (version, privacy policy,
licenses). It is a `ConsumerStatefulWidget` (Riverpod) that also listens to
`AutoSyncService.addOnStatusChanged` so the WebDAV row's error/conflict subtitle stays live without
navigating away. Unlike `license_page.dart`/`privacy_policy_page.dart`, most of its non-`build`
methods are real action handlers — reading/writing `AnimeStorage`'s JSON config, calling
`ImportExportService`, `LocalApiServer`, `ReminderService`, `TrayService`, and `launch_at_startup`
— so this page has a large Tier A surface despite being a "view" file. See
[`../../../platform-notes.md`](../../../../platform-notes.md) for the desktop-only API server/tray
behavior these handlers configure, and
[`../../../sync.md`](../../../../sync.md) /
[`../../../backup-restore.md`](../../../../backup-restore.md) for what the WebDAV/backup entry points
lead to (`../../../shared/views/webdav_config_page.md`, `backup_page.md` in this same directory).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `SettingsPage({super.key})` | constructor (`SettingsPage`) | B | Create a settings page instance. |
| `createState` | method (widget lifecycle) | B | Create the mutable state object for this widget. |
| `initState` | method (widget lifecycle) | B | Kick off version/storage-path/reminder loads and register the sync-status listener. |
| `dispose` | method (widget lifecycle) | B | Remove the sync-status listener. |
| `_refreshSyncStatus` | method (widget helper) | B | Rebuild the page when background sync status changes. |
| [`_loadVersion`](#loadversion) | method (`_SettingsPageState`) | A | Load and store the app's version/build-number string. |
| `_buildSection` | method (widget helper) | B | Render a titled settings section. |
| [`_calendarLayoutLabel`](#calendarlayoutlabel) | method (`_SettingsPageState`) | A | Map a `HomeCalendarLayout` value to its localized label. |
| [`_homeCalendarTimeBasisLabel`](#homecalendartimebasislabel) | method (`_SettingsPageState`) | A | Map a `HomeCalendarTimeBasis` value to its localized label. |
| [`_weekdayLabel`](#weekdaylabel) | method (`_SettingsPageState`) | A | Map a weekday number to its localized short label. |
| `_isDesktop` | getter (`_SettingsPageState`) | B | Report whether the app is running on a desktop platform. |
| [`_exportData`](#exportdata) | method (`_SettingsPageState`) | A | Export anime data as a ZIP or Markdown file to a user-chosen folder. |
| [`_importData`](#importdata) | method (`_SettingsPageState`) | A | Confirm and import a previously exported ZIP bundle. |
| [`_openDataFolder`](#opendatafolder) | method (`_SettingsPageState`) | A | Open the app's data folder in the OS file explorer. |
| [`_loadStoragePath`](#loadstoragepath) | method (`_SettingsPageState`) | A | Load and store the current data storage path. |
| [`_loadReminder`](#loadreminder) | method (`_SettingsPageState`) | A | Load and parse the persisted reminder enabled flag and time. |
| [`_loadTraySettings`](#loadtraysettings) | method (`_SettingsPageState`) | A | Load and store the persisted minimize/close-to-tray flags. |
| [`_loadAutoStartStatus`](#loadautostartstatus) | method (`_SettingsPageState`) | A | Query and store whether launch-at-startup is enabled. |
| [`_loadApiSettings`](#loadapisettings) | method (`_SettingsPageState`) | A | Load and store the persisted local API server settings. |
| [`_showApiSettingsDialog`](#showapisettingsdialog) | method (`_SettingsPageState`) | A | Edit, persist, and apply the local API server's address/port/credentials. |
| [`_setReminderEnabled`](#setreminderenabled) | method (`_SettingsPageState`) | A | Persist the reminder on/off flag and restart the periodic check. |
| [`_pickReminderTime`](#pickremindertime) | method (`_SettingsPageState`) | A | Let the user pick a new daily reminder time and persist it. |
| [`_showStoragePathDialog`](#showstoragepathdialog) | method (`_SettingsPageState`) | A | Edit and apply a custom (or reset-to-default) data storage path. |
| `build` | method (widget build) | B | Render the full settings list for the current state/platform. |

## Documentation

### `Future<void> _loadVersion()` <a id="loadversion"></a>
- **Kind:** method of `_SettingsPageState`
- **Source:** `lib/features/settings/views/settings_page.dart` (line 105)
- **Purpose:** Read the app's package version/build number and store it for display in the About
  section.
- **Inputs:** None.
- **Returns:** None (sets the `_version` field).
- **Side effects:** Calls `PackageInfo.fromPlatform()` (platform channel call).
- **Algorithm:** Await `PackageInfo.fromPlatform()`; if still `mounted`, `setState` the `_version`
  field to `'${info.version}+${info.buildNumber}'`.
- **Usage:**
  ```dart
  @override
  void initState() {
    super.initState();
    _loadVersion();
    ...
  }
  ```
- **Notes:** None.

### `String _calendarLayoutLabel(HomeCalendarLayout layout, AppLocalizations l10n)` <a id="calendarlayoutlabel"></a>
- **Kind:** method of `_SettingsPageState`
- **Source:** `lib/features/settings/views/settings_page.dart` (line 140)
- **Purpose:** Translate a `HomeCalendarLayout` enum value into its localized display label for the
  home-calendar-layout dropdown.
- **Inputs:** `layout` — `HomeCalendarLayout.local` or `.japanese`; `l10n` — the current
  `AppLocalizations`.
- **Returns:** The matching localized `String`.
- **Side effects:** None.
- **Algorithm:** `switch` expression: `local` -> `l10n.settingsHomeCalendarLayoutLocal`,
  `japanese` -> `l10n.settingsHomeCalendarLayoutJapanese`.
- **Usage:**
  ```dart
  for (final layout in HomeCalendarLayout.values)
    DropdownMenuItem(
      value: layout,
      child: Text(_calendarLayoutLabel(layout, l10n)),
    ),
  ```
- **Notes:** None.

### `String _homeCalendarTimeBasisLabel(HomeCalendarTimeBasis basis, AppLocalizations l10n)` <a id="homecalendartimebasislabel"></a>
- **Kind:** method of `_SettingsPageState`
- **Source:** `lib/features/settings/views/settings_page.dart` (line 155)
- **Purpose:** Translate a `HomeCalendarTimeBasis` enum value into its localized display label for
  the home-calendar-time-basis dropdown.
- **Inputs:** `basis` — `HomeCalendarTimeBasis.jst` or `.local`; `l10n` — the current
  `AppLocalizations`.
- **Returns:** The matching localized `String`.
- **Side effects:** None.
- **Algorithm:** `switch` expression: `jst` -> `l10n.settingsHomeCalendarTimeBasisJst`, `local` ->
  `l10n.settingsHomeCalendarTimeBasisLocal`.
- **Usage:**
  ```dart
  for (final basis in HomeCalendarTimeBasis.values)
    DropdownMenuItem(
      value: basis,
      child: Text(_homeCalendarTimeBasisLabel(basis, l10n)),
    ),
  ```
- **Notes:** None.

### `String _weekdayLabel(int weekday, AppLocalizations l10n)` <a id="weekdaylabel"></a>
- **Kind:** method of `_SettingsPageState`
- **Source:** `lib/features/settings/views/settings_page.dart` (line 170)
- **Purpose:** Translate a Dart weekday number into its localized short label for the
  week-start-day dropdown.
- **Inputs:** `weekday` — Dart's `1` (Monday) through `7` (Sunday); `l10n` — the current
  `AppLocalizations`.
- **Returns:** The matching localized short weekday name, or `''` if `weekday` is out of range
  after clamping still lands on the unused index 0 slot.
- **Side effects:** None.
- **Algorithm:**
  1. Build a fixed 8-entry list `['', dayMon, dayTue, dayWed, dayThu, dayFri, daySat, daySun]`
     (index 0 is an unused placeholder so indices `1..7` line up with Dart's Monday=1..Sunday=7).
  2. Return `days[weekday.clamp(1, 7)]`.
- **Usage:**
  ```dart
  for (final weekday in weekdaySequence(defaultWeekStartDay))
    DropdownMenuItem(
      value: weekday,
      child: Text(_weekdayLabel(weekday, l10n)),
    ),
  ```
  (`weekdaySequence`/`defaultWeekStartDay` come from
  [`../../../shared/utils/calendar_preferences.md`](../../../shared/utils/calendar_preferences.md).)
- **Notes:** The doc comment on this method explicitly calls out the Monday=1..Sunday=7 numbering
  convention; `clamp(1, 7)` guards against an out-of-range input reaching the placeholder index 0.

### `Future<void> _exportData()` <a id="exportdata"></a>
- **Kind:** method of `_SettingsPageState`
- **Source:** `lib/features/settings/views/settings_page.dart` (line 197)
- **Purpose:** Let the user export their anime data as either a ZIP bundle or a Markdown summary
  to a folder they choose.
- **Inputs:** None (reads `context`).
- **Returns:** None.
- **Side effects:** Opens a format-choice dialog and a directory picker; writes a new file to disk
  via `ImportExportService`; shows a success snackbar.
- **Algorithm:**
  1. Show a `SimpleDialog` offering `'zip'` or `'markdown'`; if dismissed, stop.
  2. Prompt for a destination directory via `FilePicker.platform.getDirectoryPath()`; if
     cancelled, stop.
  3. If the choice was `'markdown'`, call `ImportExportService.exportMarkdown(dir)`
     ([`../../../shared/services/import_export_service.md#exportmarkdown`](../../../shared/services/import_export_service.md#exportmarkdown));
     otherwise call `ImportExportService.exportZIP(dir)`
     ([`#exportzip`](../../../shared/services/import_export_service.md#exportzip)).
  4. If a non-null path came back, show the `exportSuccess` snackbar.
- **Usage:**
  ```dart
  ListTile(
    leading: const Icon(Icons.file_upload_outlined),
    title: Text(l10n.exportData),
    onTap: _exportData,
  ),
  ```
- **Notes:** A `null` returned path (export failure) is silently not reported — no failure
  snackbar branch exists here, unlike `_importData`.

### `Future<void> _importData()` <a id="importdata"></a>
- **Kind:** method of `_SettingsPageState`
- **Source:** `lib/features/settings/views/settings_page.dart` (line 257)
- **Purpose:** Let the user pick a previously exported ZIP bundle, confirm, and import it.
- **Inputs:** None (reads `context`).
- **Returns:** None.
- **Side effects:** Opens a file picker and a confirmation dialog; may overwrite local
  `anime_data.json`/images via `ImportExportService.importZIP`; shows a success/failure snackbar.
- **Algorithm:**
  1. `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['zip'])`; if no file
     was picked, stop.
  2. Show an `AlertDialog` confirmation; if not confirmed, stop.
  3. Call `ImportExportService.importZIP(path)`
     ([`../../../shared/services/import_export_service.md#importzip`](../../../shared/services/import_export_service.md#importzip)).
  4. Show `importSuccess` or `importFailed` depending on the returned `bool`.
- **Usage:**
  ```dart
  ListTile(
    leading: const Icon(Icons.file_download_outlined),
    title: Text(l10n.importData),
    onTap: _importData,
  ),
  ```
- **Notes:** Import enforces its own path-traversal protections inside
  `ImportExportService.importZIP` (see
  [`../../../backup-restore.md`](../../../../backup-restore.md)); this method just drives the picker
  and confirmation UI.

### `Future<void> _openDataFolder()` <a id="opendatafolder"></a>
- **Kind:** method of `_SettingsPageState`
- **Source:** `lib/features/settings/views/settings_page.dart` (line 298)
- **Purpose:** Open the app's data directory in the host OS's file explorer (desktop only).
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Spawns a native OS process (`explorer`, `open`, or `xdg-open`).
- **Algorithm:**
  1. Get the app directory via `AnimeStorage.getAppDir()`
     ([`../../../features/anime/services/anime_storage.md#getappdir`](../../../features/anime/services/anime_storage.md#getappdir)).
  2. Branch on platform: Windows -> `Process.run('explorer', [appDir.path])`; macOS ->
     `Process.run('open', [appDir.path])`; Linux -> convert the path to a `file:` URI and
     `Process.run('xdg-open', [uri.toFilePath()])`.
- **Usage:**
  ```dart
  if (_isDesktop)
    ListTile(
      leading: const Icon(Icons.folder_open_outlined),
      title: Text(l10n.dataMigration),
      subtitle: Text(l10n.dataMigrationDesc),
      onTap: _openDataFolder,
    ),
  ```
- **Notes:** No explicit handling if the platform is none of Windows/macOS/Linux (e.g. mobile) —
  the `ListTile` that calls this is itself only shown `if (_isDesktop)`, so that case is filtered
  out at the call site rather than inside this method.

### `Future<void> _loadStoragePath()` <a id="loadstoragepath"></a>
- **Kind:** method of `_SettingsPageState`
- **Source:** `lib/features/settings/views/settings_page.dart` (line 315)
- **Purpose:** Load and display the current data storage path (desktop-configurable).
- **Inputs:** None.
- **Returns:** None (sets `_storagePath`).
- **Side effects:** Reads the storage-path config via `AnimeStorage.getStoragePath()`.
- **Algorithm:** Await `AnimeStorage.getStoragePath()`
  ([`../../../features/anime/services/anime_storage.md#getstoragepath`](../../../features/anime/services/anime_storage.md#getstoragepath));
  if `mounted`, `setState` the path.
- **Usage:** Called from `initState` and again after `_showStoragePathDialog` successfully applies
  a new path.
- **Notes:** None.

### `Future<void> _loadReminder()` <a id="loadreminder"></a>
- **Kind:** method of `_SettingsPageState`
- **Source:** `lib/features/settings/views/settings_page.dart` (line 325)
- **Purpose:** Load the persisted reminder enabled flag and time, parsing the stored `"HH:MM"`
  string into a `TimeOfDay`.
- **Inputs:** None.
- **Returns:** None (sets `_reminderEnabled`/`_reminderTime`).
- **Side effects:** Reads the app config via `AnimeStorage.readConfig()`.
- **Algorithm:**
  1. Await `AnimeStorage.readConfig()`
     ([`../../../features/anime/services/anime_storage.md#readconfig`](../../../features/anime/services/anime_storage.md#readconfig)).
  2. Read `config['reminderEnabled']` as `bool?`, defaulting to `false`.
  3. If `config['reminderTime']` is a non-null string, split it on `':'` and `int.tryParse` each
     half, defaulting to hour `18`/minute `0` on parse failure, and build a `TimeOfDay`.
- **Usage:** Called from `initState`.
- **Notes:** A malformed `reminderTime` string with fewer than two `:`-separated parts would throw
  a `RangeError` on `p[1]` — the code assumes the persisted format is always well-formed, since it
  is only ever written by [`_pickReminderTime`](#pickremindertime) in the same `"HH:MM"` shape.

### `Future<void> _loadTraySettings()` <a id="loadtraysettings"></a>
- **Kind:** method of `_SettingsPageState`
- **Source:** `lib/features/settings/views/settings_page.dart` (line 346)
- **Purpose:** Load the persisted minimize-to-tray and close-to-tray flags (desktop only).
- **Inputs:** None.
- **Returns:** None (sets `_minimizeToTray`/`_closeToTray`).
- **Side effects:** Reads the app config via `AnimeStorage.readConfig()`.
- **Algorithm:** Await `AnimeStorage.readConfig()`; read `minimizeToTray`/`closeToTray` as
  `bool?`, defaulting both to `false`.
- **Usage:** Called from `initState`, guarded by `if (_isDesktop)`.
- **Notes:** None.

### `Future<void> _loadAutoStartStatus()` <a id="loadautostartstatus"></a>
- **Kind:** method of `_SettingsPageState`
- **Source:** `lib/features/settings/views/settings_page.dart` (line 360)
- **Purpose:** Query the OS-level launch-at-startup registration state (desktop only).
- **Inputs:** None.
- **Returns:** None (sets `_autoStart`).
- **Side effects:** Calls `launchAtStartup.isEnabled()` (the `launch_at_startup` package).
- **Algorithm:** Await `launchAtStartup.isEnabled()`; if `mounted`, `setState` `_autoStart`.
- **Usage:** Called from `initState`, guarded by `if (_isDesktop)`.
- **Notes:** See [`../../../platform-notes.md`](../../../../platform-notes.md) for how
  `launch_at_startup` handles desktop auto-start.

### `Future<void> _loadApiSettings()` <a id="loadapisettings"></a>
- **Kind:** method of `_SettingsPageState`
- **Source:** `lib/features/settings/views/settings_page.dart` (line 371)
- **Purpose:** Load the persisted local API server settings (enabled flag, port, listen address,
  username, password) (desktop only).
- **Inputs:** None.
- **Returns:** None (sets `_apiEnabled`/`_apiPort`/`_apiListenAddress`/`_apiUsername`/
  `_apiPassword`).
- **Side effects:** Reads the app config via `AnimeStorage.readConfig()`.
- **Algorithm:** Await `AnimeStorage.readConfig()`; read each of the five `api*` keys with
  defaults (`apiEnabled: false`, `apiPort: 7788`, `apiListenAddress: 'localhost'`,
  `apiUsername`/`apiPassword: ''`).
- **Usage:** Called from `initState`, guarded by `if (_isDesktop)`.
- **Notes:** The `7788` default and `'localhost'` default match the documented defaults in
  [`../../../platform-notes.md`](../../../../platform-notes.md).

### `Future<void> _showApiSettingsDialog()` <a id="showapisettingsdialog"></a>
- **Kind:** method of `_SettingsPageState`
- **Source:** `lib/features/settings/views/settings_page.dart` (line 388)
- **Purpose:** Let the user edit the local API server's listen address, port, username, and
  password, persist the change, and restart the server so it takes effect.
- **Inputs:** None (reads current `_api*` fields to prefill the dialog's `TextEditingController`s).
- **Returns:** None.
- **Side effects:** Writes four config keys via `AnimeStorage.writeConfig`; restarts the local API
  server via `LocalApiServer.restart()`; shows a snackbar with the resulting port.
- **Algorithm:**
  1. Show an `AlertDialog` with four `TextField`s pre-filled from the current settings.
  2. If not saved (dialog dismissed) or unmounted afterward, stop.
  3. Parse the port with `int.tryParse(...) ?? 7788`; trim the address, defaulting to `'localhost'`
     if empty after trimming; trim username/password.
  4. Read the current config, overwrite `apiPort`/`apiListenAddress`/`apiUsername`/`apiPassword`
     (empty username/password are stored as `null`, not `''`), and
     `AnimeStorage.writeConfig(config)`
     ([`../../../features/anime/services/anime_storage.md#writeconfig`](../../../features/anime/services/anime_storage.md#writeconfig)).
  5. `setState` the four local fields to the new values.
  6. Await `LocalApiServer.restart()`
     ([`../../../shared/services/local_api_server.md#restart`](../../../shared/services/local_api_server.md#restart))
     so the running server (if any) picks up the new address/port/credentials.
  7. If `mounted`, show `settingsApiRestarted(LocalApiServer.port)`.
- **Usage:**
  ```dart
  ListTile(
    leading: const Icon(Icons.settings_outlined),
    title: Text(l10n.settingsApiServer),
    trailing: const Icon(Icons.chevron_right),
    enabled: _apiEnabled,
    onTap: _apiEnabled ? _showApiSettingsDialog : null,
  ),
  ```
- **Notes:** Only reachable while `_apiEnabled` is true (the `ListTile`'s `onTap` is `null`
  otherwise). Per [`../../../platform-notes.md`](../../../../platform-notes.md), a non-loopback
  listen address without credentials is refused at the server level, not validated here — this
  dialog will happily save an unsafe combination and let `LocalApiServer.restart()`/`start()`
  reject it.

### `Future<void> _setReminderEnabled(bool v)` <a id="setreminderenabled"></a>
- **Kind:** method of `_SettingsPageState`
- **Source:** `lib/features/settings/views/settings_page.dart` (line 472)
- **Purpose:** Turn the daily watch reminder on or off and persist the change.
- **Inputs:** `v` — the new switch state.
- **Returns:** None.
- **Side effects:** Writes `reminderEnabled` to the app config; restarts
  `ReminderService`'s periodic check.
- **Algorithm:**
  1. `setState` to update `_reminderEnabled` immediately.
  2. Read the config, set `config['reminderEnabled'] = v`, `AnimeStorage.writeConfig(config)`.
  3. Call `ReminderService.startPeriodicCheck()`
     ([`../../../shared/services/reminder_service.md`](../../../shared/services/reminder_service.md))
     unconditionally (even when turning reminders off).
- **Usage:**
  ```dart
  SwitchListTile(
    secondary: const Icon(Icons.notifications_outlined),
    title: Text(l10n.settingsReminder),
    value: _reminderEnabled,
    onChanged: _setReminderEnabled,
  ),
  ```
- **Notes:** `ReminderService.startPeriodicCheck()` is called regardless of the new value; the
  service itself is presumably responsible for no-op'ing when reminders are disabled.

### `Future<void> _pickReminderTime()` <a id="pickremindertime"></a>
- **Kind:** method of `_SettingsPageState`
- **Source:** `lib/features/settings/views/settings_page.dart` (line 485)
- **Purpose:** Let the user pick a new daily reminder time and persist it, resetting the
  "already reminded today" tracking so the new time takes effect immediately.
- **Inputs:** None (uses the current `_reminderTime` as the picker's initial value).
- **Returns:** None.
- **Side effects:** Writes `reminderTime` (and removes `lastReminderDate`) to the app config;
  conditionally restarts `ReminderService`'s periodic check.
- **Algorithm:**
  1. `showTimePicker` seeded with `_reminderTime`; if cancelled, stop.
  2. `setState` the new `_reminderTime`.
  3. Read the config, format the picked time as zero-padded `"HH:MM"`, store it as
     `config['reminderTime']`, and `config.remove('lastReminderDate')` so today isn't treated as
     already handled under the old time.
  4. `AnimeStorage.writeConfig(config)`.
  5. If `_reminderEnabled`, call `ReminderService.startPeriodicCheck()`.
- **Usage:**
  ```dart
  ListTile(
    leading: const SizedBox(width: 24),
    title: Text(l10n.settingsReminderTime),
    trailing: TextButton(
      onPressed: _pickReminderTime,
      child: Text(_reminderTime.format(context)),
    ),
  ),
  ```
- **Notes:** Removing `lastReminderDate` (rather than leaving it) is what makes a same-day time
  change take effect right away instead of waiting until tomorrow.

### `Future<void> _showStoragePathDialog()` <a id="showstoragepathdialog"></a>
- **Kind:** method of `_SettingsPageState`
- **Source:** `lib/features/settings/views/settings_page.dart` (line 506)
- **Purpose:** Let the user set a custom data storage path, or reset to the default location
  (desktop only).
- **Inputs:** None (prefills the dialog's text field with the current `_storagePath`).
- **Returns:** None.
- **Side effects:** May move the app's data directory via `AnimeStorage.setStoragePath`; shows a
  result snackbar.
- **Algorithm:**
  1. Show an `AlertDialog` with a text field (prefilled with `_storagePath`) and three actions:
     cancel (`null`), "reset default" (empty string `''`), confirm (the trimmed text field value).
  2. If the dialog returned `null` (cancelled), stop.
  3. Treat an empty resulting string as `null` (reset to default) when calling
     `AnimeStorage.setStoragePath(pathToSet)`
     ([`../../../features/anime/services/anime_storage.md#setstoragepath`](../../../features/anime/services/anime_storage.md#setstoragepath)).
  4. If it returned `true`, call [`_loadStoragePath`](#loadstoragepath) to refresh the displayed
     path and show `settingsResetDefaultLocation` or `settingsStoragePathUpdated` depending on
     whether the path was reset or set.
- **Usage:**
  ```dart
  if (_isDesktop)
    ListTile(
      leading: const Icon(Icons.folder_outlined),
      title: Text(l10n.settingsStorageLocation),
      subtitle: Text(_storagePath, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: _showStoragePathDialog,
    ),
  ```
- **Notes:** If `AnimeStorage.setStoragePath` returns `false` (e.g. the new path is invalid or the
  move failed), this method shows no failure feedback at all — the dialog simply closes with the
  displayed path unchanged.
