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
| `_dataQueue` | static field (`AnimeStorage`) | B | The shared `AtomicWriteQueue` that serializes every read-modify-write of `anime_data.json` (1.6.7). |
| `_configQueue` | static field (`AnimeStorage`) | B | The shared `AtomicWriteQueue` for `storage_config.json` (1.6.7). |
| [`_writeData`](#writedata) | static method (`AnimeStorage`) | A | The unqueued library write: unique-temp atomic write, then auto-sync and reminder notifications. |
| `_exclusiveData` | static method (`AnimeStorage`) | B | Run a read-modify-write on the library inside `_dataQueue` and return its result. |
| [`updateRecord`](#updaterecord) | static method (`AnimeStorage`) | A | Replace one record computed from the freshly stored copy; no write for a missing id or a `null` result. |
| [`updateLibrary`](#updatelibrary) | static method (`AnimeStorage`) | A | Rewrite the library from a freshly re-read copy, keeping unknown top-level fields. |
| [`save`](#save) | static method (`AnimeStorage`) | A | Persist an `AnimeData` through the write queue, then notify auto-sync and reminders. |
| [`patchExternalMeta`](#patchexternalmeta) | static method (`AnimeStorage`) | A | Refresh cached external metadata **without** marking records edited. |
| [`patchSeasonLabels`](#patchseasonlabels) | static method (`AnimeStorage`) | A | Replace default season labels with title-derived ones **without** marking records edited. |
| [`loadFixingSeasonLabels`](#loadfixingseasonlabels) | static method (`AnimeStorage`) | A | Load the library after correcting default season labels. |
| [`addOrUpdate`](#addorupdate) | static method (`AnimeStorage`) | A | Insert or replace one anime record by `id` and save. |
| [`addOrUpdateAll`](#addorupdateall) | static method (`AnimeStorage`) | A | Insert or replace several anime records in one load and one save. |
| [`deleteAnime`](#deleteanime) | static method (`AnimeStorage`) | A | Remove one anime record by `id` and save. |
| [`readConfig`](#readconfig) | static method (`AnimeStorage`) | A | Read `storage_config.json` as a raw JSON map. |
| `_writeConfig` | static method (`AnimeStorage`) | B | The unqueued config write (unique-temp atomic write) used inside `_configQueue`. |
| [`writeConfig`](#writeconfig) | static method (`AnimeStorage`) | A | Replace `storage_config.json` through the config queue. |
| [`updateConfig`](#updateconfig) | static method (`AnimeStorage`) | A | Queued read-modify-write of a few config keys; every setter uses it. |
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
| [`getHomeCalendarFormat`](#gethomecalendarformat) | static method (`AnimeStorage`) | A | Read the persisted home calendar view format preference. |
| [`setHomeCalendarFormat`](#sethomecalendarformat) | static method (`AnimeStorage`) | A | Persist the home calendar view format preference. |
| `getManageViewMode` | static method (`AnimeStorage`) | B | Read `manageViewMode` (1.6.2): `series`, or null for the default quarter view. |
| `setManageViewMode` | static method (`AnimeStorage`) | B | Persist `manageViewMode`; null removes the key, so only the series view is stored. |
| `getManageSeriesSort` | static method (`AnimeStorage`) | B | Read `manageSeriesSort` (1.6.2): `title` or `modified`, or null for the default. |
| `setManageSeriesSort` | static method (`AnimeStorage`) | B | Persist `manageSeriesSort`; null removes the key. |
| [`getMetadataUpdatePolicy`](#getmetadataupdatepolicy) | static method (`AnimeStorage`) | A | Read the persisted background metadata-update policy. |
| [`setMetadataUpdatePolicy`](#setmetadataupdatepolicy) | static method (`AnimeStorage`) | A | Persist the background metadata-update policy. |
| [`getMetadataPrefetchCovers`](#getmetadataprefetchcovers) | static method (`AnimeStorage`) | A | Read whether candidate covers are prefetched. |
| [`setMetadataPrefetchCovers`](#setmetadataprefetchcovers) | static method (`AnimeStorage`) | A | Persist whether candidate covers are prefetched. |
| [`getKanaTabEnabled`](#getkanatabenabled) | static method (`AnimeStorage`) | A | Read whether the Kana quick-reference tab is shown. |
| [`setKanaTabEnabled`](#setkanatabenabled) | static method (`AnimeStorage`) | A | Persist whether the Kana quick-reference tab is shown. |
| [`getFloatingNavBar`](#getfloatingnavbar) | static method (`AnimeStorage`) | A | Read whether the bottom navigation bar floats as an island (1.7.0). |
| [`setFloatingNavBar`](#setfloatingnavbar) | static method (`AnimeStorage`) | A | Persist whether the bottom navigation bar floats as an island (1.7.0). |
| [`getOnDeviceAiEnabled`](#getondeviceaienabled) | static method (`AnimeStorage`) | A | Read whether on-device AI is turned on. |
| [`setOnDeviceAiEnabled`](#setondeviceaienabled) | static method (`AnimeStorage`) | A | Persist whether on-device AI is turned on. |
| [`getAutoCategoriesEnabled`](#getautocategoriesenabled) | static method (`AnimeStorage`) | A | Read whether automatic categories are turned on. |
| [`setAutoCategoriesEnabled`](#setautocategoriesenabled) | static method (`AnimeStorage`) | A | Persist whether automatic categories are turned on. |
| [`getRecommendationsEnabled`](#getrecommendationsenabled) | static method (`AnimeStorage`) | A | Read whether recommendations are turned on. |
| [`setRecommendationsEnabled`](#setrecommendationsenabled) | static method (`AnimeStorage`) | A | Persist whether recommendations are turned on. |
| [`getOnDeviceAiPreferFast`](#getondeviceaipreferfast) | static method (`AnimeStorage`) | A | Read whether the faster on-device model is preferred. |
| [`setOnDeviceAiPreferFast`](#setondeviceaipreferfast) | static method (`AnimeStorage`) | A | Persist whether the faster on-device model is preferred. |
| `_getListColumns` | static method (`AnimeStorage`) | B | Read a stored list column preference. |
| `_setListColumns` | static method (`AnimeStorage`) | B | Persist a list column preference for one module. |
| `getHomeListColumns` | static method (`AnimeStorage`) | B | Read the home module's list column preference. |
| `setHomeListColumns` | static method (`AnimeStorage`) | B | Persist the home module's list column preference. |
| `getManageListColumns` | static method (`AnimeStorage`) | B | Read the management module's list column preference. |
| `setManageListColumns` | static method (`AnimeStorage`) | B | Persist the management module's list column preference. |
| `getStatsListColumns` | static method (`AnimeStorage`) | B | Read the statistics module's list column preference. |
| `setStatsListColumns` | static method (`AnimeStorage`) | B | Persist the statistics module's list column preference. |

## Documentation

### `static Future<bool> patchExternalMeta(Map<String, AnimeExternalMeta> updates)` <a id="patchexternalmeta"></a>
- **Kind:** static method of `AnimeStorage`
- **Purpose:** Write refreshed external metadata for several anime at once.
- **Inputs:** `updates` — external metadata keyed by anime id.
- **Returns:** `Future<bool>` — whether anything was actually written.
- **Side effects:** Rewrites `anime_data.json` when at least one id matched, which also notifies
  auto-sync and reminders through [`save`](#save).
- **Algorithm:**
  1. Return false immediately for an empty batch.
  2. Re-read the current data.
  3. For each matching record, replace `externalMeta` **and pass the record's existing
     `modifiedAt` back in**.
  4. Save when at least one record matched.
- **Usage:** The only write path for cached metadata — used by the background updater and by the
  detail page's manual "refresh database info" button.
- **Notes:** **Deliberately leaves `modifiedAt` untouched.** `mergeRecords` decides whether a record
  changed purely by comparing `modifiedAt` against the sync base, never by comparing content, so
  bumping it here would (a) resurrect records another device deleted, because a locally "modified"
  record survives a remote deletion, and (b) raise conflict dialogs for edits the user never made.
  Leaving it alone keeps `localChanged` false, which makes both impossible.

  The refreshed data still propagates: when the remote did not touch the record the merge keeps the
  local copy, and the upload decision is made by raw file comparison. When the remote *did* change
  it, the remote wins and this cache update is dropped — correct for a cache, since the updater
  re-fetches it.

  Step 3's explicit pass-through is required, not cosmetic: `Anime.copyWith` stamps `modifiedAt`
  with the current time whenever the argument is omitted. See
  [`../../../../sync.md`](../../../../sync.md) and
  [`../../../../features/metadata-auto-update.md`](../../../../features/metadata-auto-update.md).

  Re-reads immediately before writing so a long background sweep cannot write a stale snapshot over
  a concurrent user edit.

### `static Future<bool> patchSeasonLabels(Map<String, String> labels)` <a id="patchseasonlabels"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (approx. line 292)
- **Purpose:** Replace default season labels with ones derived from titles, without marking the
  records edited.
- **Inputs:** `labels` — new label keyed by anime id, from `seasonLabelFixups`
  ([`series_service.md`](series_service.md#seasonlabelfixups)).
- **Returns:** `Future<bool>` — whether anything was actually written.
- **Side effects:** Rewrites `anime_data.json` when at least one record still had a default label,
  which also notifies auto-sync and reminders through [`save`](#save).
- **Algorithm:**
  1. Return false immediately for an empty map.
  2. Re-read the current data.
  3. For each record with an entry in `labels` whose `season` still passes
     `isDefaultSeasonLabel`, set `season` **and pass the record's existing `modifiedAt` back in**.
  4. Save (keeping `extraJson`) when at least one record changed.
- **Notes:** Added in 1.6.1. Keeps `modifiedAt` for the reasons given on
  [`patchExternalMeta`](#patchexternalmeta): every device running 1.6.1 or later derives the same
  label, so the fix needs no conflict, and a newer remote edit simply wins and is fixed again on the
  next load. The re-read plus the default-label check means a label the user just typed is never
  overwritten. See
  [`../../../../features/series-linking.md`](../../../../features/series-linking.md).

### `static Future<AnimeData> loadFixingSeasonLabels(Map<String, String> Function(List<Anime> records) fixups)` <a id="loadfixingseasonlabels"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (approx. line 317)
- **Purpose:** Load the library after correcting default season labels.
- **Inputs:** `fixups` — computes the labels to write from the loaded records; pass
  `seasonLabelFixups`.
- **Returns:** `Future<AnimeData>` — the library, re-read if anything changed.
- **Side effects:** May call [`patchSeasonLabels`](#patchseasonlabels).
- **Algorithm:** [`load`](#load); run `fixups` over the records; when the map is empty or
  `patchSeasonLabels` wrote nothing, return the first load, otherwise `load()` again.
- **Usage:**
  ```dart
  final data = await AnimeStorage.loadFixingSeasonLabels(seasonLabelFixups);
  ```
  (`_load` in `home_page.dart`, `management_page.dart` and `anime_detail_page.dart`)
- **Notes:** Added in 1.6.1. The derivation lives in `series_service.dart`, which this file does
  not import, hence the parameter. Used by the pages that show season labels (Home, Manage, detail)
  so records synced from older builds are corrected the next time they are shown.

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
  2. Set `_customPath = newPath`; update `storagePath` in the config map (set it, or `remove` it when `newPath` is `null`) and write the config back through [`updateConfig`](#updateconfig).
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

### `static Future<void> save(AnimeData data)` <a id="save"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (line 182)
- **Purpose:** Persist an `AnimeData` to `anime_data.json` and notify the systems that depend on data having changed.
- **Inputs:** `data`.
- **Returns:** None.
- **Side effects:** Atomically overwrites `anime_data.json`; calls `AutoSyncService.instance.notifySaved()` (see [`../../../../sync.md`](../../../../sync.md)) and `ReminderService.notifyDataChanged()` so scheduled notification bodies stay current.
- **Algorithm:** Enqueues [`_writeData`](#writedata) on `_dataQueue`. `_writeData` resolves the data file, serializes `data.toJson()` with `JsonEncoder.withIndent('  ')` (see [`../../../../data-formats.md`](../../../../data-formats.md) on why indentation is load-bearing for sync's unchanged-file fast path), writes it with `atomicWriteString` from `myapps_data` (a uniquely named temp file, then rename), then fires both notifications.
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

### `static Future<void> addOrUpdateAll(Iterable<Anime> animes)` <a id="addorupdateall"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (line 224)
- **Purpose:** Add or replace several anime records in one write (1.6.0).
- **Inputs:** `animes` — records keyed by `id`; a later duplicate id wins.
- **Returns:** None.
- **Side effects:** One [`load`](#load) and one [`save`](#save) of `anime_data.json`, so one auto-sync
  notification. Does nothing for an empty input.
- **Algorithm:** Builds an id-keyed map of the updates; walks the loaded list replacing each matching
  record in place (removing it from the map), then appends whatever is left as new records.
- **Usage:**
  ```dart
  await AnimeStorage.addOrUpdateAll(editor.removeFromSeries(anime));
  ```
  (`lib/features/anime/views/anime_detail_page.dart`, `_runSeriesAction`; also the series manage
  sheet and the create page's `_saveNew`)
- **Notes:** Used by series curation, which may rewrite every member of a series at once — see
  [`series_service.md`](series_service.md). Unlike [`patchExternalMeta`](#patchexternalmeta) it
  writes the records exactly as given: callers stamp `modifiedAt` themselves (`SeriesEditor` does),
  so each write is an ordinary user edit to sync.

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
- **Algorithm:** Enqueues `_writeConfig` on `_configQueue`; that serializes `config` with `JsonEncoder.withIndent('  ')` and writes it with `atomicWriteString`.
- **Usage:**
  ```dart
  final config = await AnimeStorage.readConfig();
  config['themeMode'] = mode;
  await AnimeStorage.writeConfig(config);
  ```
  (pattern used by every `setXxx` method below, and directly by `lib/shared/services/tray_service.dart`)
- **Notes:** Overwrites every key it is not given. Since 1.6.7 a change to a few keys goes through [`updateConfig`](#updateconfig), which re-reads inside the queue; the settings page fires several writes at once, and the earlier unserialized read-modify-write let a later write restore an earlier stale value.

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

### `static Future<String?> getHomeCalendarFormat()` <a id="gethomecalendarformat"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (line 385)
- **Purpose:** Read the persisted home-calendar view format (month, two weeks, or week).
- **Inputs:** None.
- **Returns:** `Future<String?>` — `null` means the default full-month view.
- **Side effects:** None.
- **Algorithm:** `(await readConfig())['homeCalendarFormat'] as String?`.
- **Usage:**
  ```dart
  final homeCalendarFormat = _parseHomeCalendarFormat(
    await AnimeStorage.getHomeCalendarFormat(),
  );
  ```
  (`lib/shared/providers/app_settings.dart`, `_loadPersisted`)
- **Notes:** The stored strings are `table_calendar`'s `CalendarFormat` enum names, so only
  `'twoWeeks'` and `'week'` are ever written.

### `static Future<void> setHomeCalendarFormat(String? format)` <a id="sethomecalendarformat"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart` (line 395)
- **Purpose:** Persist (or clear) the home-calendar view format preference.
- **Inputs:** `format` — `null` removes the key and restores the default full-month view.
- **Returns:** None.
- **Side effects:** Writes `storage_config.json`.
- **Algorithm:** Read-modify-write, identical shape to `setThemeMode`.
- **Usage:**
  ```dart
  AnimeStorage.setHomeCalendarFormat(
    format == CalendarFormat.month ? null : format.name,
  );
  ```
  (`lib/shared/providers/app_settings.dart`, `setHomeCalendarFormat`)
- **Notes:** None.

### `static Future<String?> getMetadataUpdatePolicy()` <a id="getmetadataupdatepolicy"></a>
- **Kind:** static method of `AnimeStorage`
- **Purpose:** Read the raw `metadataAutoUpdate` string.
- **Returns:** `Future<String?>` — `null` when nothing is stored.
- **Notes:** `null` means the platform default (`noCellular` on mobile, `always` on desktop), which
  is resolved by `MetadataUpdateService.effectivePolicy` via `parseMetadataUpdatePolicy`. This
  method deliberately returns the raw string rather than the enum, matching how
  `getHomeCalendarLayout` leaves parsing to its caller.

### `static Future<void> setMetadataUpdatePolicy(String? policy)` <a id="setmetadataupdatepolicy"></a>
- **Kind:** static method of `AnimeStorage`
- **Inputs:** `policy` — a `MetadataUpdatePolicy` name; `null` removes the key.
- **Side effects:** Writes `storage_config.json`.
- **Notes:** Read-modify-write, identical shape to `setThemeMode`.

### `static Future<bool> getMetadataPrefetchCovers()` <a id="getmetadataprefetchcovers"></a>
- **Kind:** static method of `AnimeStorage`
- **Returns:** `Future<bool>` — defaults to false.
- **Notes:** Off by default because covers are the only large data the background update cache
  holds; everything else it stores is plain text.

### `static Future<void> setMetadataPrefetchCovers(bool enabled)` <a id="setmetadataprefetchcovers"></a>
- **Kind:** static method of `AnimeStorage`
- **Side effects:** Writes `storage_config.json`.
- **Notes:** The default `false` is removed from config rather than stored, matching how
  `setWeekStartDay` handles its own default.

### `static Future<bool> getKanaTabEnabled()` <a id="getkanatabenabled"></a>
- **Kind:** static method of `AnimeStorage`
- **Returns:** `Future<bool>` — `true` only when `storage_config.json` holds `kanaTabEnabled: true`.
- **Side effects:** Reads `storage_config.json`.
- **Notes:** Added in 1.6.0. Off by default for existing installs too, because kana practice now
  lives in the separate MyNihongo!!!!! app. Read by `AppSettingsNotifier._loadPersisted`.

### `static Future<void> setKanaTabEnabled(bool enabled)` <a id="setkanatabenabled"></a>
- **Kind:** static method of `AnimeStorage`
- **Side effects:** Writes `storage_config.json`.
- **Notes:** Writes `kanaTabEnabled: true` when on and removes the key when off, the same shape as
  `setMetadataPrefetchCovers`.

### `static Future<bool> getFloatingNavBar()` <a id="getfloatingnavbar"></a>
- **Kind:** static method of `AnimeStorage`
- **Returns:** `Future<bool>` — `config['classicNavBar'] != true`, so it defaults to `true`.
- **Side effects:** Reads `storage_config.json`.
- **Notes:** Added in 1.7.0. Stored inverted as `classicNavBar` so the default (floating) needs no key and
  existing installs get the floating bar too. Device-local, never synced. Read by
  `AppSettingsNotifier._loadPersisted`.

### `static Future<void> setFloatingNavBar(bool floating)` <a id="setfloatingnavbar"></a>
- **Kind:** static method of `AnimeStorage`
- **Inputs:** `floating`.
- **Side effects:** Writes `storage_config.json`.
- **Notes:** Removes the key when floating and writes `classicNavBar: true` when classic, so only the
  non-default choice is stored.

### `static Future<bool> getOnDeviceAiEnabled()` <a id="getondeviceaienabled"></a>
- **Kind:** static method of `AnimeStorage`
- **Returns:** `Future<bool>` — `true` only when `storage_config.json` holds `onDeviceAiEnabled: true`.
- **Side effects:** Reads `storage_config.json`.
- **Notes:** Added in 1.6.0 (M3). Off by default; while off, the on-device model is never asked
  anything. Read by `AppSettingsNotifier._loadPersisted`, which passes the value to
  `OnDeviceAiService.setEnabled`. See [`../../../../on-device-ai.md`](../../../../on-device-ai.md).

### `static Future<void> setOnDeviceAiEnabled(bool enabled)` <a id="setondeviceaienabled"></a>
- **Kind:** static method of `AnimeStorage`
- **Side effects:** Writes `storage_config.json`.
- **Notes:** Writes `onDeviceAiEnabled: true` when on and removes the key when off, the same shape as
  `setKanaTabEnabled`.

### `static Future<bool> getAutoCategoriesEnabled()` <a id="getautocategoriesenabled"></a>
- **Kind:** static method of `AnimeStorage`
- **Returns:** `Future<bool>` — `true` only when `storage_config.json` holds
  `autoCategoriesEnabled: true`.
- **Side effects:** Reads `storage_config.json`.
- **Notes:** Added in 1.6.0 (M4). Off by default and device-local. Read by
  `AppSettingsNotifier._loadPersisted`, which hands it to `CategoryClassifier.instance.enabled`, and
  by the detail page before it shows category chips. See
  [`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md).

### `static Future<void> setAutoCategoriesEnabled(bool enabled)` <a id="setautocategoriesenabled"></a>
- **Kind:** static method of `AnimeStorage`
- **Side effects:** Writes `storage_config.json`.
- **Notes:** Writes `autoCategoriesEnabled: true` when on and removes the key when off, the same
  shape as `setOnDeviceAiEnabled`.

### `static Future<bool> getRecommendationsEnabled()` <a id="getrecommendationsenabled"></a>
- **Kind:** static method of `AnimeStorage`
- **Returns:** `Future<bool>` — `true` only when `storage_config.json` holds
  `recommendationsEnabled: true`.
- **Side effects:** Reads `storage_config.json`.
- **Notes:** Added in 1.6.0 (M5). Off by default and device-local. Read by
  `AppSettingsNotifier._loadPersisted`; while it is on, Home shows the recommendations action. See
  [`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md).

### `static Future<void> setRecommendationsEnabled(bool enabled)` <a id="setrecommendationsenabled"></a>
- **Kind:** static method of `AnimeStorage`
- **Side effects:** Writes `storage_config.json`.
- **Notes:** Writes `recommendationsEnabled: true` when on and removes the key when off, the same
  shape as `setAutoCategoriesEnabled`.

### `static Future<bool> getOnDeviceAiPreferFast()` <a id="getondeviceaipreferfast"></a>
- **Kind:** static method of `AnimeStorage`
- **Returns:** `Future<bool>` — `true` only when `storage_config.json` holds
  `onDeviceAiPreferFast: true`.
- **Side effects:** Reads `storage_config.json`.
- **Notes:** Added in 1.6.0 (M3). Android only, and only meaningful where AICore serves both model
  sizes.

### `static Future<void> setOnDeviceAiPreferFast(bool enabled)` <a id="setondeviceaipreferfast"></a>
- **Kind:** static method of `AnimeStorage`
- **Side effects:** Writes `storage_config.json`.
- **Notes:** Writes `onDeviceAiPreferFast: true` when on and removes the key when off.


## Changes in 1.6.4

patchExternalMeta accepts optional expectedWatchUrls keyed by record id. Guarded patches merge into current metadata and reject changed sources, older snapshots and incomplete replacements. Other metadata updates retain an existing directory. Manual mappings remain untouched.

### `static Future<void> _writeData(AnimeData data)` <a id="writedata"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart`
- **Purpose:** Write the library to `anime_data.json` and notify auto-sync and the reminder service, without touching the queue.
- **Inputs:** `data`.
- **Returns:** None.
- **Side effects:** Atomically rewrites `anime_data.json`; calls `AutoSyncService.instance.notifySaved()` and `ReminderService.notifyDataChanged()`.
- **Notes:** Code already running inside `_dataQueue` must call this, never the public `save`, which enqueues behind the running operation and deadlocks. Replaces the old `_atomicWrite` helper (fixed `.tmp` name).

### `static Future<bool> updateRecord(String id, Anime? Function(Anime current) update)` <a id="updaterecord"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart`
- **Purpose:** Replace one record with a value computed from the record as currently stored.
- **Inputs:** `id`; `update` — receives the stored record and returns the replacement, or `null` to write nothing.
- **Returns:** `Future<bool>` — whether a record was written.
- **Side effects:** One queued load and, when written, one `_writeData`.
- **Notes:** Because the read happens inside the queue, a page that applies only the fields the user changed (the edit form, the detail page's episode toggles, `PlaybackProgressService.markWatched`) cannot overwrite episode statuses or external metadata changed since it opened. A missing id writes nothing; `extraJson` is carried through.

### `static Future<bool> updateLibrary(List<Anime>? Function(List<Anime> current) update)` <a id="updatelibrary"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart`
- **Purpose:** Rewrite the whole library from a freshly re-read copy, inside the write queue.
- **Inputs:** `update` — receives a mutable copy of the stored records and returns the new list, or `null` to write nothing.
- **Returns:** `Future<bool>` — whether the library was written.
- **Side effects:** One queued load and, when written, one `_writeData`.
- **Notes:** Carries `AnimeData.extraJson` through. `addOrUpdate`, `addOrUpdateAll`, `patchExternalMeta`, `patchSeasonLabels`, `deleteAnime` and `FileOpenService.applyBundle` / `replaceAnime` / `deleteAnimeByIds` are built on it, so none of them can drop a record saved meanwhile or the unknown top-level fields a newer build wrote (the bundle operations used to write `AnimeData(animes: list)` without them). `loadFixingSeasonLabels` stays outside the queue and calls `patchSeasonLabels`.

### `static Future<void> updateConfig(void Function(Map<String, dynamic> config) change)` <a id="updateconfig"></a>
- **Kind:** static method of `AnimeStorage`
- **Source:** `lib/features/anime/services/anime_storage.dart`
- **Purpose:** Change some `storage_config.json` keys without losing concurrent changes.
- **Inputs:** `change` — a synchronous callback that mutates the freshly read config map in place.
- **Returns:** None.
- **Side effects:** Queued read-modify-write of `storage_config.json`.
- **Notes:** Every setter in this file, `setStoragePath`, the settings page's API and reminder writes, `TrayService` and `ReminderService` use it. Call `_writeConfig`, never `writeConfig`, from inside it.

## Changes in 1.6.7

`anime_data.json` and `storage_config.json` writes are serialized by two static `AtomicWriteQueue`s, and the temporary file name is now unique (`atomicWriteString`), so two overlapping writers no longer share `<file>.tmp`. `test/anime_storage_test.dart` covers 20 parallel `addOrUpdate` calls, parallel setters, `extraJson` through bundle operations, `updateRecord` with a missing id, and no leftover temp file.
