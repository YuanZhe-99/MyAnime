# lib/features/anime/services/anime_storage.dart

A static-only `AnimeStorage` class: the single point of disk access for `anime_data.json` (the
persisted `AnimeData` list) and `storage_config.json` (every device-local preference — theme,
locale, calendar week-start/layout/time-basis, storage path override, and more). It resolves the
active app data directory (default vs. custom path), performs atomic tmp-then-rename writes, and
notifies `AutoSyncService`/`ReminderService` after every save. See
[`../../../../data-formats.md`](../../../../data-formats.md) for the full field list persisted in
`storage_config.json` and the persisted-data inventory table, and
[`../../../../sync.md`](../../../../sync.md) for how `AutoSyncService` reacts to `save()`. The
`Anime`/`AnimeData` model this class loads and saves is documented in
[`../models/anime.md`](../models/anime.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`_getDefaultAppDir`](#getdefaultappdir) | static method (`AnimeStorage`) | A | Resolve (creating if needed) the default `Documents/MyAnime`-style app directory. |
| [`_getConfigFile`](#getconfigfile) | static method (`AnimeStorage`) | A | Return `storage_config.json`, always in the default location regardless of custom data path. |
| [`_loadConfig`](#loadconfig) | static method (`AnimeStorage`) | A | Load the custom storage path override from config, once per process. |
| [`getAppDir`](#getappdir) | static method (`AnimeStorage`) | A | Return the active app data directory (custom path if configured, else default). |
| [`_getFile`](#getfile) | static method (`AnimeStorage`) | A | Build a `File` for a given file name under the active app directory. |
| [`getDataFile`](#getdatafile) | static method (`AnimeStorage`) | A | Return the main `anime_data.json` file for direct low-level access. |
| [`getStoragePath`](#getstoragepath) | static method (`AnimeStorage`) | A | Return the active storage directory path, for UI display. |
| [`setStoragePath`](#setstoragepath) | static method (`AnimeStorage`) | A | Update the custom storage directory and migrate managed data files. |
| [`load`](#load) | static method (`AnimeStorage`) | A | Load `anime_data.json` into an `AnimeData`. |
| [`_atomicWrite`](#atomicwrite) | static method (`AnimeStorage`) | A | Write a file via a temp-file-then-rename step. |
| [`save`](#save) | static method (`AnimeStorage`) | A | Persist an `AnimeData`, then notify auto-sync and reminders. |
| [`addOrUpdate`](#addorupdate) | static method (`AnimeStorage`) | A | Insert or replace one anime record by `id` and save. |
| [`deleteAnime`](#deleteanime) | static method (`AnimeStorage`) | A | Remove one anime record by `id` and save. |
| [`readConfig`](#readconfig) | static method (`AnimeStorage`) | A | Read `storage_config.json` as a raw JSON map. |
| [`writeConfig`](#writeconfig) | static method (`AnimeStorage`) | A | Write `storage_config.json` atomically. |
| [`getThemeMode`](#getthememode) | static method (`AnimeStorage`) | A | Read the persisted theme mode string. |
| [`setThemeMode`](#setthememode) | static method (`AnimeStorage`) | A | Persist (or clear) the theme mode string. |
| [`getLocaleTag`](#getlocaletag) | static method (`AnimeStorage`) | A | Read the persisted locale tag. |
| [`setLocaleTag`](#setlocaletag) | static method (`AnimeStorage`) | A | Persist (or clear) the locale tag. |
| [`getWeekStartDay`](#getweekstartday) | static method (`AnimeStorage`) | A | Read the persisted global calendar week-start day. |
| [`setWeekStartDay`](#setweekstartday) | static method (`AnimeStorage`) | A | Persist the global calendar week-start day. |
| [`getHomeCalendarLayout`](#gethomecalendarlayout) | static method (`AnimeStorage`) | A | Read the persisted home calendar day-name layout preference. |
| [`setHomeCalendarLayout`](#sethomecalendarlayout) | static method (`AnimeStorage`) | A | Persist the home calendar day-name layout preference. |
| [`getHomeCalendarTimeBasis`](#gethomecalendartimebasis) | static method (`AnimeStorage`) | A | Read the persisted home calendar JST-vs-local time basis preference. |
| [`setHomeCalendarTimeBasis`](#sethomecalendartimebasis) | static method (`AnimeStorage`) | A | Persist the home calendar JST-vs-local time basis preference. |

## Documentation

### `static Future<Directory> _getDefaultAppDir()` <a id="getdefaultappdir"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (line 30)
- **Purpose:** Resolve the default app data directory (`<platform documents dir>/MyAnime`), creating it if missing.
- **Inputs:** None.
- **Returns:** `Future<Directory>`.
- **Side effects:** May create the `MyAnime` subdirectory under the platform documents directory.
- **Algorithm:** Resolves `getApplicationDocumentsDirectory()` (from `path_provider`), joins `'MyAnime'`, and creates it recursively if it doesn't already exist.
- **Usage:**
  ```dart
  return _getDefaultAppDir();
  ```
  (`AnimeStorage.getAppDir`, same file, when no custom path is configured)
- **Notes:** This is always where `storage_config.json` itself lives (see [`_getConfigFile`](#getconfigfile)), independent of any custom data-path override.

### `static Future<File> _getConfigFile()` <a id="getconfigfile"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (line 44)
- **Purpose:** Return the `storage_config.json` file, which always lives in the default app directory regardless of any custom storage path.
- **Inputs:** None.
- **Returns:** `Future<File>`.
- **Side effects:** None directly (delegates to `_getDefaultAppDir`, which may create the directory).
- **Algorithm:** `File(p.join((await _getDefaultAppDir()).path, _configFileName))`.
- **Usage:**
  ```dart
  static Future<Map<String, dynamic>> readConfig() async {
    final file = await _getConfigFile();
  ```
  (`AnimeStorage.readConfig`, same file)
- **Notes:** This is why moving the anime-data storage path (via `setStoragePath`) never moves `storage_config.json` itself — the config file (and the custom-path setting stored inside it) must remain discoverable at a fixed location.

### `static Future<void> _loadConfig()` <a id="loadconfig"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (line 54)
- **Purpose:** Load the custom storage path override from `storage_config.json` into the in-memory `_customPath`, exactly once per process.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Sets the static `_customPath` and `_configLoaded` fields; reads `storage_config.json` on the first call.
- **Algorithm:** No-ops if `_configLoaded` is already `true`. Otherwise reads the config file (if it exists) and sets `_customPath` from its `storagePath` key; any exception during the read/decode is silently swallowed. `_configLoaded` is set to `true` unconditionally afterward, even on failure.
- **Usage:**
  ```dart
  static Future<Directory> getAppDir() async {
    await _loadConfig();
  ```
  (`AnimeStorage.getAppDir`, same file)
- **Notes:** Because a failed load still marks `_configLoaded = true`, a transient read error on first launch permanently falls back to the default path for the rest of the process (until restart) rather than retrying on the next call.

### `static Future<Directory> getAppDir()` <a id="getappdir"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (line 72)
- **Purpose:** Return the directory the app should currently read/write anime data files in — the configured custom path if one is set and non-empty, otherwise the default `Documents/MyAnime` directory.
- **Inputs:** None.
- **Returns:** `Future<Directory>`.
- **Side effects:** May create the resolved directory (custom or default) if it doesn't exist; triggers `_loadConfig()`'s one-time config read.
- **Algorithm:**
  1. `await _loadConfig()`.
  2. If `_customPath` is set and non-empty, resolve/create that `Directory` and return it.
  3. Otherwise return `_getDefaultAppDir()`.
- **Usage:**
  ```dart
  final appDir = await AnimeStorage.getAppDir();
  if (Platform.isWindows) {
    await Process.run('explorer', [appDir.path]);
  ```
  (`lib/features/settings/views/settings_page.dart`, `_openDataFolder` — "open data folder" button)
- **Notes:** Every other file-resolution method in this class (`_getFile`, `getDataFile`, `load`, `save`, and every other service across the app that stores per-anime data or images) goes through this method, so a storage-path change takes effect for all of them the moment `_customPath` is updated.

### `static Future<File> _getFile(String name)` <a id="getfile"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (line 89)
- **Purpose:** Build a `File` handle for a given file name under the currently active app directory.
- **Inputs:** `name` — e.g. `'anime_data.json'`.
- **Returns:** `Future<File>`.
- **Side effects:** None directly (delegates to `getAppDir`, which may create the directory).
- **Algorithm:** `File(p.join((await getAppDir()).path, name))`.
- **Usage:**
  ```dart
  static Future<File> getDataFile() => _getFile(_dataFileName);
  ```
  (`AnimeStorage.getDataFile`, same file)
- **Notes:** None.

### `static Future<File> getDataFile()` <a id="getdatafile"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (line 99)
- **Purpose:** Return the `anime_data.json` `File` handle for callers that need the raw file/path rather than the parsed `AnimeData` model.
- **Inputs:** None.
- **Returns:** `Future<File>`.
- **Side effects:** None directly (via `_getFile`/`getAppDir`, may create the app directory).
- **Algorithm:** `_getFile(_dataFileName)`.
- **Usage:** Not called anywhere else in this repo at present — every other caller goes through [`load`](#load)/[`save`](#save) for the parsed model instead. Direct use would look like:
  ```dart
  final file = await AnimeStorage.getDataFile();
  ```
- **Notes:** Kept as a public low-level escape hatch (e.g. for a future feature needing the raw file, such as reading its raw bytes/size without a full JSON parse) even though nothing in the app currently uses it.

### `static Future<String> getStoragePath()` <a id="getstoragepath"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (line 106)
- **Purpose:** Return the active storage directory's path as a plain string, for display in settings.
- **Inputs:** None.
- **Returns:** `Future<String>`.
- **Side effects:** None directly (via `getAppDir`, may create the directory).
- **Algorithm:** `(await getAppDir()).path`.
- **Usage:**
  ```dart
  Future<void> _loadStoragePath() async {
    final path = await AnimeStorage.getStoragePath();
    if (mounted) setState(() => _storagePath = path);
  }
  ```
  (`lib/features/settings/views/settings_page.dart`)
- **Notes:** None.

### `static Future<bool> setStoragePath(String? newPath)` <a id="setstoragepath"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (line 116)
- **Purpose:** Change the custom storage directory (or reset to default when `null`) and migrate the managed data file(s) into the new location.
- **Inputs:** `newPath` — an absolute path, or `null` to reset to the default location.
- **Returns:** `Future<bool>` — `true` on success, `false` if any step throws.
- **Side effects:** Updates `_customPath`; reads/writes `storage_config.json`; may copy-then-delete `anime_data.json` from the old directory to the new one.
- **Algorithm:**
  1. Capture `oldDir` via `getAppDir()` (using the path in effect *before* this call).
  2. Set `_customPath = newPath`; update `storagePath` in the config map (set it, or `remove` it when `newPath` is `null`) and write the config back via [`writeConfig`](#writeconfig).
  3. Resolve `newDir` via `getAppDir()` again (now reflecting the new path); if it's the same path as `oldDir`, return `true` immediately (no migration needed).
  4. For each managed data file name in `_dataFileNames` (currently just `anime_data.json`): if the destination file already exists, leave it alone (destination wins); otherwise, if the source file exists, copy it to the destination and delete the source.
  5. Any exception anywhere in this sequence is caught and turned into a `false` return.
- **Usage:**
  ```dart
  final ok = await AnimeStorage.setStoragePath(pathToSet);
  if (ok) {
    await _loadStoragePath();
  ```
  (`lib/features/settings/views/settings_page.dart`, changing the storage path from settings)
- **Notes:** Existing data at the destination always wins over migrated data — if a file already exists at the new path (e.g. from a previous session using that location), the old directory's copy is silently left behind rather than overwriting it. Images and other non-`_dataFileNames` files are not migrated by this method.

### `static Future<AnimeData> load()` <a id="load"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (line 154)
- **Purpose:** Load and parse `anime_data.json` into an `AnimeData`.
- **Inputs:** None.
- **Returns:** `Future<AnimeData>` — `const AnimeData()` (empty) if the file is missing or blank.
- **Side effects:** Reads `anime_data.json` from the active app directory.
- **Algorithm:** Resolves the data file; returns an empty `AnimeData` if it doesn't exist or its trimmed contents are empty; otherwise `jsonDecode`s it and delegates to `AnimeData.fromJson` (see [`../models/anime.md`](../models/anime.md#animedata-fromjson)).
- **Usage:**
  ```dart
  final data = await AnimeStorage.load();
  if (mounted) setState(() => _allAnime = data.animeList);
  ```
  (`lib/features/anime/views/home_page.dart`)
- **Notes:** A malformed (non-empty but invalid) JSON file propagates the `jsonDecode`/`FormatException` to the caller rather than being caught here — every UI call site that calls `load()` directly does so inside its own `initState`/async-load flow without a surrounding try/catch specific to this failure mode.

### `static Future<void> _atomicWrite(File file, String content)` <a id="atomicwrite"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (line 169)
- **Purpose:** Write text to a file without ever leaving a truncated/corrupt file behind if the app is killed mid-write.
- **Inputs:** `file`, `content`.
- **Returns:** None.
- **Side effects:** Writes `<file>.tmp` then renames it over `file`.
- **Algorithm:** `tmp.writeAsString(content, flush: true)` to a sibling `.tmp` path, then `tmp.rename(file.path)` (atomic on the same filesystem).
- **Usage:**
  ```dart
  static Future<void> save(AnimeData data) async {
    final file = await _getFile(_dataFileName);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data.toJson());
    await _atomicWrite(file, jsonStr);
  ```
  (`AnimeStorage.save`, same file)
- **Notes:** Same tmp-then-rename shape as `WebDAVService._atomicWrite` (see
  [`../../../shared/services/webdav_service.md`](../../../shared/services/webdav_service.md#atomicwrite)),
  but this one does not uniquify the tmp file name — acceptable here since the app only ever has one
  process writing to a given data/config path at a time.

### `static Future<void> save(AnimeData data)` <a id="save"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (line 182)
- **Purpose:** Persist an `AnimeData` to `anime_data.json` and notify the systems that depend on data having changed.
- **Inputs:** `data`.
- **Returns:** None.
- **Side effects:** Atomically overwrites `anime_data.json`; calls `AutoSyncService.instance.notifySaved()` (see [`../../../../sync.md`](../../../../sync.md)) and `ReminderService.notifyDataChanged()` so scheduled notification bodies stay current.
- **Algorithm:** Resolves the data file, serializes `data.toJson()` with `JsonEncoder.withIndent('  ')` (see [`../../../../data-formats.md`](../../../../data-formats.md) on why indentation is load-bearing for sync's unchanged-file fast path), writes it via [`_atomicWrite`](#atomicwrite), then fires both notifications.
- **Usage:**
  ```dart
  await AnimeStorage.save(AnimeData(animes: list));
  ```
  (`lib/shared/services/file_open_service.dart`, after a bulk `.myanimeitem` import)
- **Notes:** Every mutation path in the app (`addOrUpdate`, `deleteAnime`, and every direct `save(AnimeData(...))` call across import/duplicate-merge/local-API code) funnels through this one method, so auto-sync and reminders never need to be triggered separately by callers.

### `static Future<void> addOrUpdate(Anime anime)` <a id="addorupdate"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (line 197)
- **Purpose:** Insert a new anime record or replace an existing one with the same `id`, then persist.
- **Inputs:** `anime`.
- **Returns:** None.
- **Side effects:** Full read-modify-write of `anime_data.json` via [`load`](#load)/[`save`](#save) (with `save`'s auto-sync/reminder notifications).
- **Algorithm:** Loads current data, finds the index of an existing record with matching `id` via `indexWhere`; replaces it there if found, otherwise appends; saves the resulting list.
- **Usage:**
  ```dart
  await AnimeStorage.addOrUpdate(updated);
  ```
  (`lib/features/anime/views/anime_edit_page.dart`, saving an edited anime)
- **Notes:** Not concurrency-safe against another simultaneous `addOrUpdate`/`deleteAnime` call (classic read-modify-write race) — acceptable given the app is single-user/single-process per data directory.

### `static Future<void> deleteAnime(String id)` <a id="deleteanime"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (line 214)
- **Purpose:** Remove one anime record by id and persist the result.
- **Inputs:** `id`.
- **Returns:** None.
- **Side effects:** Full read-modify-write of `anime_data.json` via `load`/`save`.
- **Algorithm:** Loads current data, filters out any record whose `id` matches, saves the filtered list.
- **Usage:**
  ```dart
  await AnimeStorage.deleteAnime(_anime!.id);
  ```
  (`lib/features/anime/views/anime_detail_page.dart`, deleting the currently viewed anime)
- **Notes:** A no-op (not an error) if `id` doesn't match any existing record.

### `static Future<Map<String, dynamic>> readConfig()` <a id="readconfig"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (line 227)
- **Purpose:** Read `storage_config.json` as a raw, untyped JSON map — the shared backing store for every device-local preference.
- **Inputs:** None.
- **Returns:** `Future<Map<String, dynamic>>` — `{}` if the file is missing or blank.
- **Side effects:** Reads `storage_config.json`.
- **Algorithm:** Existence and blank-content checks return `{}` early; otherwise `jsonDecode`s the file contents.
- **Usage:**
  ```dart
  final config = await AnimeStorage.readConfig();
  ```
  (`lib/shared/services/tray_service.dart`, reading tray/launch-at-startup preferences)
- **Notes:** Unlike `load()`, a malformed (non-empty, invalid JSON) config file also propagates a decode exception here — there's no defensive try/catch at this layer for a corrupt config file.

### `static Future<void> writeConfig(Map<String, dynamic> config)` <a id="writeconfig"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (line 240)
- **Purpose:** Persist the full `storage_config.json` map.
- **Inputs:** `config` — the complete map to write (every getter/setter pair in this file reads the whole map, mutates one key, and writes it all back).
- **Returns:** None.
- **Side effects:** Atomically overwrites `storage_config.json`.
- **Algorithm:** Serializes `config` with `JsonEncoder.withIndent('  ')` and writes it via [`_atomicWrite`](#atomicwrite).
- **Usage:**
  ```dart
  final config = await AnimeStorage.readConfig();
  config['themeMode'] = mode;
  await AnimeStorage.writeConfig(config);
  ```
  (pattern used by every `setXxx` method below, and directly by `lib/shared/services/tray_service.dart`)
- **Notes:** Because every setter does a full read-modify-write of the same file, two concurrent config writes from different code paths could race and drop one's change — not a practical issue in this single-process desktop/mobile app.

### `static Future<String?> getThemeMode()` <a id="getthememode"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (line 253)
- **Purpose:** Read the persisted theme mode preference.
- **Inputs:** None.
- **Returns:** `Future<String?>` — `'light'`, `'dark'`, or `null` (system default).
- **Side effects:** None (via `readConfig`, a read-only file access).
- **Algorithm:** `(await readConfig())['themeMode'] as String?`.
- **Usage:**
  ```dart
  final modeStr = await AnimeStorage.getThemeMode();
  ```
  (`lib/shared/providers/app_settings.dart`, `_loadPersisted`)
- **Notes:** None.

### `static Future<void> setThemeMode(String? mode)` <a id="setthememode"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (line 263)
- **Purpose:** Persist (or clear) the theme mode preference.
- **Inputs:** `mode` — `'light'`/`'dark'`, or `null` to remove the key (system default).
- **Returns:** None.
- **Side effects:** Writes `storage_config.json`.
- **Algorithm:** Reads the config, removes `themeMode` if `mode` is `null` else sets it, writes the config back.
- **Usage:**
  ```dart
  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    final str = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => null,
    };
    AnimeStorage.setThemeMode(str);
  }
  ```
  (`lib/shared/providers/app_settings.dart`)
- **Notes:** None.

### `static Future<String?> getLocaleTag()` <a id="getlocaletag"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (line 278)
- **Purpose:** Read the persisted locale tag (e.g. `'en'`, `'zh_TW'`).
- **Inputs:** None.
- **Returns:** `Future<String?>` — `null` means "use system locale."
- **Side effects:** None.
- **Algorithm:** `(await readConfig())['locale'] as String?`.
- **Usage:**
  ```dart
  final localeTag = await AnimeStorage.getLocaleTag();
  ```
  (`lib/shared/providers/app_settings.dart`, `_loadPersisted`)
- **Notes:** None.

### `static Future<void> setLocaleTag(String? tag)` <a id="setlocaletag"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (line 288)
- **Purpose:** Persist (or clear) the locale tag.
- **Inputs:** `tag` — `null` removes the key.
- **Returns:** None.
- **Side effects:** Writes `storage_config.json`.
- **Algorithm:** Read-modify-write, identical shape to `setThemeMode`.
- **Usage:**
  ```dart
  final tag = locale.countryCode != null
      ? '${locale.languageCode}_${locale.countryCode}'
      : locale.languageCode;
  AnimeStorage.setLocaleTag(tag);
  ```
  (`lib/shared/providers/app_settings.dart`, `setLocale`)
- **Notes:** None.

### `static Future<int> getWeekStartDay()` <a id="getweekstartday"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (line 303)
- **Purpose:** Read the persisted global calendar week-start day.
- **Inputs:** None.
- **Returns:** `Future<int>` — always a normalized weekday (Dart's Monday=1..Sunday=7), defaulting to Sunday.
- **Side effects:** None.
- **Algorithm:** Reads `weekStartDay` from config and passes it through `normalizeWeekStartDay` (in `lib/shared/utils/calendar_preferences.dart`), which substitutes `defaultWeekStartDay` (Sunday) for a missing/out-of-range value.
- **Usage:**
  ```dart
  final weekStartDay = await AnimeStorage.getWeekStartDay();
  ```
  (`lib/shared/providers/app_settings.dart`, `_loadPersisted`)
- **Notes:** This value is ignored while the Japanese home-calendar layout is active — see
  [`../../../../data-formats.md`](../../../../data-formats.md).

### `static Future<void> setWeekStartDay(int weekday)` <a id="setweekstartday"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (line 313)
- **Purpose:** Persist the global calendar week-start day.
- **Inputs:** `weekday`.
- **Returns:** None.
- **Side effects:** Writes `storage_config.json`.
- **Algorithm:** Normalizes `weekday` via `normalizeWeekStartDay`; if the normalized value equals the default (Sunday), removes the `weekStartDay` key instead of storing it explicitly; otherwise stores the normalized value.
- **Usage:**
  ```dart
  void setWeekStartDay(int weekday) {
    final normalized = normalizeWeekStartDay(weekday);
    state = state.copyWith(weekStartDay: normalized);
    AnimeStorage.setWeekStartDay(normalized);
  }
  ```
  (`lib/shared/providers/app_settings.dart`)
- **Notes:** Storing "no key" for the default value means a config file that has never had this preference changed stays byte-for-byte minimal rather than accumulating default values.

### `static Future<String?> getHomeCalendarLayout()` <a id="gethomecalendarlayout"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (line 329)
- **Purpose:** Read the persisted home-calendar day-name layout preference (local vs. Japanese).
- **Inputs:** None.
- **Returns:** `Future<String?>` — `null` means the default local layout.
- **Side effects:** None.
- **Algorithm:** `(await readConfig())['homeCalendarLayout'] as String?`.
- **Usage:**
  ```dart
  final homeCalendarLayout = _parseHomeCalendarLayout(
    await AnimeStorage.getHomeCalendarLayout(),
  );
  ```
  (`lib/shared/providers/app_settings.dart`, `_loadPersisted`)
- **Notes:** None.

### `static Future<void> setHomeCalendarLayout(String? layout)` <a id="sethomecalendarlayout"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (line 339)
- **Purpose:** Persist (or clear) the home-calendar day-name layout preference.
- **Inputs:** `layout` — `null` removes the key and restores the default local layout.
- **Returns:** None.
- **Side effects:** Writes `storage_config.json`.
- **Algorithm:** Read-modify-write, identical shape to `setThemeMode`.
- **Usage:**
  ```dart
  AnimeStorage.setHomeCalendarLayout(
    layout == HomeCalendarLayout.local ? null : layout.name,
  );
  ```
  (`lib/shared/providers/app_settings.dart`, `setHomeCalendarLayout`)
- **Notes:** None.

### `static Future<String?> getHomeCalendarTimeBasis()` <a id="gethomecalendartimebasis"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (line 354)
- **Purpose:** Read the persisted home-calendar time-basis preference (JST vs. local).
- **Inputs:** None.
- **Returns:** `Future<String?>` — `null` means the default JST basis.
- **Side effects:** None.
- **Algorithm:** `(await readConfig())['homeCalendarTimeBasis'] as String?`.
- **Usage:**
  ```dart
  final homeCalendarTimeBasis = _parseHomeCalendarTimeBasis(
    await AnimeStorage.getHomeCalendarTimeBasis(),
  );
  ```
  (`lib/shared/providers/app_settings.dart`, `_loadPersisted`)
- **Notes:** This preference affects only the home calendar's date grid — anime schedule timestamps
  themselves remain JST-based regardless (see
  [`../../../../data-formats.md`](../../../../data-formats.md)).

### `static Future<void> setHomeCalendarTimeBasis(String? basis)` <a id="sethomecalendartimebasis"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (line 364)
- **Purpose:** Persist (or clear) the home-calendar time-basis preference.
- **Inputs:** `basis` — `null` removes the key and restores the default JST basis.
- **Returns:** None.
- **Side effects:** Writes `storage_config.json`.
- **Algorithm:** Read-modify-write, identical shape to `setThemeMode`.
- **Usage:**
  ```dart
  AnimeStorage.setHomeCalendarTimeBasis(
    basis == HomeCalendarTimeBasis.jst ? null : basis.name,
  );
  ```
  (`lib/shared/providers/app_settings.dart`, `setHomeCalendarTimeBasis`)
- **Notes:** None.
