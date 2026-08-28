import 'dart:convert';
import 'dart:io';

import 'package:myapps_data/myapps_data.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../shared/services/auto_sync_service.dart';
import '../../../shared/services/reminder_service.dart';
import '../../../shared/utils/adaptive_layout.dart';
import '../../../shared/utils/calendar_preferences.dart';
import '../models/anime.dart';

class AnimeStorage {
  static const _dataFileName = 'anime_data.json';
  static const _configFileName = 'storage_config.json';

  /// Custom storage directory path override.
  static String? _customPath;

  /// Whether config has been loaded from disk.
  static bool _configLoaded = false;

  /// Purpose: Provide the internal get default app dir helper for this file.
  /// Inputs: None.
  /// Returns: `Future<Directory>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static Future<Directory> _getDefaultAppDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final appDir = Directory(p.join(dir.path, 'MyAnime'));
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return appDir;
  }

  /// Purpose: Config file always lives in the default location.
  /// Inputs: None.
  /// Returns: `Future<File>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Config file always lives in the default location.
  static Future<File> _getConfigFile() async {
    final dir = await _getDefaultAppDir();
    return File(p.join(dir.path, _configFileName));
  }

  /// Purpose: Load the storage path from config file (once).
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only. Load the storage path from config file (once).
  static Future<void> _loadConfig() async {
    if (_configLoaded) return;
    try {
      final file = await _getConfigFile();
      if (await file.exists()) {
        final json =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        _customPath = json['storagePath'] as String?;
      }
    } catch (_) {}
    _configLoaded = true;
  }

  /// Purpose: Return the current app dir value.
  /// Inputs: None.
  /// Returns: `Future<Directory>`.
  /// Side effects: None.
  /// Notes: None.
  static Future<Directory> getAppDir() async {
    await _loadConfig();
    if (_customPath != null && _customPath!.isNotEmpty) {
      final dir = Directory(_customPath!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    return _getDefaultAppDir();
  }

  /// Purpose: Provide the internal get file helper for this file.
  /// Inputs: `name`.
  /// Returns: `Future<File>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static Future<File> _getFile(String name) async {
    final appDir = await getAppDir();
    return File(p.join(appDir.path, name));
  }

  /// Purpose: Return the main anime data file for direct low-level access.
  /// Inputs: None.
  /// Returns: `Future<File>`.
  /// Side effects: None.
  /// Notes: Useful for flows that need the file path instead of serialized model data.
  static Future<File> getDataFile() => _getFile(_dataFileName);

  /// Purpose: Return the active storage directory path for UI display.
  /// Inputs: None.
  /// Returns: `Future<String>`.
  /// Side effects: None.
  /// Notes: Respects the configured custom storage path when one is set.
  static Future<String> getStoragePath() async {
    final appDir = await getAppDir();
    return appDir.path;
  }

  /// Purpose: Update the custom storage directory and migrate the app's data to it.
  /// Inputs: `newPath`; pass `null` to reset to the default location.
  /// Returns: `Future<bool>` — false only when the path could not be recorded.
  /// Side effects: Rewrites `storage_config.json` and moves the old storage
  /// folder's contents to the new location.
  /// Notes: Migrates **everything** in the folder — data files, `images/`,
  /// `.sync_base/`, `backups/` (blobs included), and `webdav_config.json` — not
  /// an enumerated list, so a data file added later moves automatically.
  /// `storage_config.json` deliberately stays put: it lives in the platform
  /// default directory and holds the custom path itself.
  ///
  /// Leaving `.sync_base/` behind used to be the dangerous case: without a base
  /// snapshot the next sync treats records other devices deleted as new local
  /// records and re-uploads them, silently resurrecting deletions everywhere.
  ///
  /// Existing destination files win and their source copies are left in place,
  /// so nothing is discarded on a guess about which copy is newer.
  static Future<bool> setStoragePath(String? newPath) async {
    try {
      final oldDir = await getAppDir();

      _customPath = newPath;
      final config = await readConfig();
      if (newPath != null) {
        config['storagePath'] = newPath;
      } else {
        config.remove('storagePath');
      }
      await writeConfig(config);

      final newDir = await getAppDir();
      if (oldDir.path == newDir.path) return true;

      // Per-entry failures are reported rather than thrown; the path change
      // itself has already been persisted, so the move is best-effort and any
      // unmoved file remains readable at the old location.
      await migrateStorageContents(from: oldDir, to: newDir);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Data persistence ──

  /// Purpose: Implement the load behavior for this file.
  /// Inputs: None.
  /// Returns: `Future<AnimeData>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<AnimeData> load() async {
    final file = await _getFile(_dataFileName);
    if (!await file.exists()) return const AnimeData();
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return const AnimeData();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return AnimeData.fromJson(json);
  }

  /// Purpose: Write a file atomically through a temporary file and rename step.
  /// Inputs: `file`, `content`.
  /// Returns: None.
  /// Side effects: Writes a temp file and renames it over the target path.
  /// Notes: Internal helper used within this file only; protects the data
  /// file against corruption when the app is killed mid-write.
  static Future<void> _atomicWrite(File file, String content) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(content, flush: true);
    await tmp.rename(file.path);
  }

  /// Purpose: Implement the save behavior for this file.
  /// Inputs: `data`.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Writes atomically (tmp-then-rename), then notifies auto-sync and
  /// refreshes mobile reminder schedules so scheduled notification bodies
  /// track the latest data.
  static Future<void> save(AnimeData data) async {
    final file = await _getFile(_dataFileName);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data.toJson());
    await _atomicWrite(file, jsonStr);
    AutoSyncService.instance.notifySaved();
    ReminderService.notifyDataChanged();
  }

  // ── CRUD operations ──

  /// Purpose: Implement the add or update behavior for this file.
  /// Inputs: `anime`.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Carries `AnimeData.extraJson` through, so unknown top-level fields
  /// written by a newer build survive an edit made by an older one.
  static Future<void> addOrUpdate(Anime anime) async {
    final data = await load();
    final list = List<Anime>.of(data.animes);
    final idx = list.indexWhere((a) => a.id == anime.id);
    if (idx >= 0) {
      list[idx] = anime;
    } else {
      list.add(anime);
    }
    await save(AnimeData(animes: list, extraJson: data.extraJson));
  }

  /// Purpose: Refresh cached external metadata without marking records edited.
  /// Inputs: `updates` — external metadata keyed by anime id.
  /// Returns: `Future<bool>` — whether anything was actually written.
  /// Side effects: Rewrites `anime_data.json` when at least one id matched.
  /// Notes: **Deliberately leaves `modifiedAt` untouched.** `mergeRecords`
  /// decides whether a record changed purely by comparing `modifiedAt` against
  /// the sync base, never by comparing content, so bumping it here would do two
  /// harmful things: a record another device deleted would be resurrected
  /// ("modified locally after remote deleted -> keep"), and a conflict dialog
  /// would appear for an edit the user never made. Leaving it alone keeps
  /// `localChanged` false, which makes both impossible.
  ///
  /// The refreshed data still propagates: when the remote did not touch the
  /// record the merge keeps the local copy, and the upload decision is made by
  /// raw file comparison. When the remote *did* change it, the remote record
  /// wins and this cache update is dropped — which is fine, because it is a
  /// cache and the background service will fetch it again.
  ///
  /// Re-reads immediately before writing so a long-running background sweep
  /// cannot write back a stale snapshot over a concurrent user edit.
  static Future<bool> patchExternalMeta(
    Map<String, AnimeExternalMeta> updates,
  ) async {
    if (updates.isEmpty) return false;
    final data = await load();
    final list = List<Anime>.of(data.animes);
    var touched = false;
    for (var i = 0; i < list.length; i++) {
      final meta = updates[list[i].id];
      if (meta == null) continue;
      // `copyWith` defaults `modifiedAt` to now when it is omitted, so the
      // existing value has to be passed back in explicitly. Everything in the
      // Notes above depends on this line.
      list[i] = list[i].copyWith(
        externalMeta: meta,
        modifiedAt: list[i].modifiedAt,
      );
      touched = true;
    }
    if (!touched) return false;
    await save(AnimeData(animes: list, extraJson: data.extraJson));
    return true;
  }

  /// Purpose: Delete anime from the relevant storage or state.
  /// Inputs: `id`.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Carries `AnimeData.extraJson` through for the same reason
  /// [addOrUpdate] does.
  static Future<void> deleteAnime(String id) async {
    final data = await load();
    final list = data.animes.where((a) => a.id != id).toList();
    await save(AnimeData(animes: list, extraJson: data.extraJson));
  }

  // ── Config persistence ──

  /// Purpose: Implement the read config behavior for this file.
  /// Inputs: None.
  /// Returns: `Future<Map<String, dynamic>>`.
  /// Side effects: None.
  /// Notes: None.
  static Future<Map<String, dynamic>> readConfig() async {
    final file = await _getConfigFile();
    if (!await file.exists()) return {};
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return {};
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// Purpose: Implement the write config behavior for this file.
  /// Inputs: `config`.
  /// Returns: None.
  /// Side effects: Writes the config file atomically (tmp-then-rename).
  /// Notes: None.
  static Future<void> writeConfig(Map<String, dynamic> config) async {
    final file = await _getConfigFile();
    await _atomicWrite(
      file,
      const JsonEncoder.withIndent('  ').convert(config),
    );
  }

  /// Purpose: Return the current theme mode value.
  /// Inputs: None.
  /// Returns: `Future<String?>`.
  /// Side effects: None.
  /// Notes: None.
  static Future<String?> getThemeMode() async {
    final config = await readConfig();
    return config['themeMode'] as String?;
  }

  /// Purpose: Update theme mode with the provided value.
  /// Inputs: `mode`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: None.
  static Future<void> setThemeMode(String? mode) async {
    final config = await readConfig();
    if (mode == null) {
      config.remove('themeMode');
    } else {
      config['themeMode'] = mode;
    }
    await writeConfig(config);
  }

  /// Purpose: Return the current locale tag value.
  /// Inputs: None.
  /// Returns: `Future<String?>`.
  /// Side effects: None.
  /// Notes: None.
  static Future<String?> getLocaleTag() async {
    final config = await readConfig();
    return config['locale'] as String?;
  }

  /// Purpose: Update locale tag with the provided value.
  /// Inputs: `tag`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: None.
  static Future<void> setLocaleTag(String? tag) async {
    final config = await readConfig();
    if (tag == null) {
      config.remove('locale');
    } else {
      config['locale'] = tag;
    }
    await writeConfig(config);
  }

  /// Purpose: Return the persisted global calendar week start day.
  /// Inputs: None.
  /// Returns: `Future<int>`.
  /// Side effects: None.
  /// Notes: Weekday values use Dart's Monday=1 through Sunday=7 numbering and default to Sunday.
  static Future<int> getWeekStartDay() async {
    final config = await readConfig();
    return normalizeWeekStartDay(config['weekStartDay'] as int?);
  }

  /// Purpose: Persist the global calendar week start day.
  /// Inputs: `weekday`.
  /// Returns: None.
  /// Side effects: Writes `storage_config.json`.
  /// Notes: The default Sunday value is removed from config instead of stored.
  static Future<void> setWeekStartDay(int weekday) async {
    final normalized = normalizeWeekStartDay(weekday);
    final config = await readConfig();
    if (normalized == defaultWeekStartDay) {
      config.remove('weekStartDay');
    } else {
      config['weekStartDay'] = normalized;
    }
    await writeConfig(config);
  }

  /// Purpose: Return the persisted home calendar layout value.
  /// Inputs: None.
  /// Returns: `Future<String?>`.
  /// Side effects: None.
  /// Notes: `null` means the default local calendar layout.
  static Future<String?> getHomeCalendarLayout() async {
    final config = await readConfig();
    return config['homeCalendarLayout'] as String?;
  }

  /// Purpose: Persist the home calendar layout value.
  /// Inputs: `layout`.
  /// Returns: None.
  /// Side effects: Writes `storage_config.json`.
  /// Notes: Passing `null` removes the value and restores the default local layout.
  static Future<void> setHomeCalendarLayout(String? layout) async {
    final config = await readConfig();
    if (layout == null) {
      config.remove('homeCalendarLayout');
    } else {
      config['homeCalendarLayout'] = layout;
    }
    await writeConfig(config);
  }

  /// Purpose: Return the persisted home calendar time basis value.
  /// Inputs: None.
  /// Returns: `Future<String?>`.
  /// Side effects: None.
  /// Notes: `null` means the default Japan Standard Time calendar basis.
  static Future<String?> getHomeCalendarTimeBasis() async {
    final config = await readConfig();
    return config['homeCalendarTimeBasis'] as String?;
  }

  /// Purpose: Persist the home calendar time basis value.
  /// Inputs: `basis`.
  /// Returns: None.
  /// Side effects: Writes `storage_config.json`.
  /// Notes: Passing `null` removes the value and restores the default JST basis.
  static Future<void> setHomeCalendarTimeBasis(String? basis) async {
    final config = await readConfig();
    if (basis == null) {
      config.remove('homeCalendarTimeBasis');
    } else {
      config['homeCalendarTimeBasis'] = basis;
    }
    await writeConfig(config);
  }

  /// Purpose: Return the persisted home calendar view format value.
  /// Inputs: None.
  /// Returns: `Future<String?>`.
  /// Side effects: None.
  /// Notes: `null` means the default full-month view.
  static Future<String?> getHomeCalendarFormat() async {
    final config = await readConfig();
    return config['homeCalendarFormat'] as String?;
  }

  /// Purpose: Persist the home calendar view format value.
  /// Inputs: `format`.
  /// Returns: None.
  /// Side effects: Writes `storage_config.json`.
  /// Notes: Passing `null` removes the value and restores the default full-month view.
  static Future<void> setHomeCalendarFormat(String? format) async {
    final config = await readConfig();
    if (format == null) {
      config.remove('homeCalendarFormat');
    } else {
      config['homeCalendarFormat'] = format;
    }
    await writeConfig(config);
  }

  /// Purpose: Return the persisted background metadata-update policy name.
  /// Inputs: None.
  /// Returns: `Future<String?>`.
  /// Side effects: None.
  /// Notes: `null` means the platform default — `noCellular` on mobile,
  /// `always` on desktop. Parsed by `parseMetadataUpdatePolicy`.
  static Future<String?> getMetadataUpdatePolicy() async {
    final config = await readConfig();
    return config['metadataAutoUpdate'] as String?;
  }

  /// Purpose: Persist the background metadata-update policy.
  /// Inputs: `policy` — a `MetadataUpdatePolicy` name.
  /// Returns: None.
  /// Side effects: Writes `storage_config.json`.
  /// Notes: Passing `null` removes the value and restores the platform default.
  static Future<void> setMetadataUpdatePolicy(String? policy) async {
    final config = await readConfig();
    if (policy == null) {
      config.remove('metadataAutoUpdate');
    } else {
      config['metadataAutoUpdate'] = policy;
    }
    await writeConfig(config);
  }

  /// Purpose: Return whether candidate covers are prefetched in the background.
  /// Inputs: None.
  /// Returns: `Future<bool>` — defaults to false.
  /// Side effects: None.
  /// Notes: Off by default because covers are the only large data in the
  /// background update cache; everything else it stores is plain text.
  static Future<bool> getMetadataPrefetchCovers() async {
    final config = await readConfig();
    return config['metadataPrefetchCovers'] == true;
  }

  /// Purpose: Persist whether candidate covers are prefetched.
  /// Inputs: `enabled`.
  /// Returns: None.
  /// Side effects: Writes `storage_config.json`.
  /// Notes: The default `false` is removed from config rather than stored,
  /// matching how `setWeekStartDay` handles its default.
  static Future<void> setMetadataPrefetchCovers(bool enabled) async {
    final config = await readConfig();
    if (enabled) {
      config['metadataPrefetchCovers'] = true;
    } else {
      config.remove('metadataPrefetchCovers');
    }
    await writeConfig(config);
  }

  /// Purpose: Read a stored list column preference.
  /// Inputs: `key` — the `storage_config.json` key for one module.
  /// Returns: `Future<int>` — `listColumnsAuto` when unset or malformed.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: Internal helper shared by the three per-module accessors; the
  /// preference is clamped again at render time against what the width fits.
  static Future<int> _getListColumns(String key) async {
    final config = await readConfig();
    final value = config[key];
    if (value is! int || value < 1 || value > listMaxColumns) {
      return listColumnsAuto;
    }
    return value;
  }

  /// Purpose: Persist a list column preference for one module.
  /// Inputs: `key`, `columns`.
  /// Returns: None.
  /// Side effects: Writes `storage_config.json`.
  /// Notes: The default `listColumnsAuto` is removed from config rather than
  /// stored, matching how `setWeekStartDay` handles its default.
  static Future<void> _setListColumns(String key, int columns) async {
    final config = await readConfig();
    if (columns >= 1 && columns <= listMaxColumns) {
      config[key] = columns;
    } else {
      config.remove(key);
    }
    await writeConfig(config);
  }

  /// Purpose: Read the home module's list column preference.
  /// Inputs: None.
  /// Returns: `Future<int>` — defaults to `listColumnsAuto`.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: None.
  static Future<int> getHomeListColumns() => _getListColumns('homeListColumns');

  /// Purpose: Persist the home module's list column preference.
  /// Inputs: `columns`.
  /// Returns: None.
  /// Side effects: Writes `storage_config.json`.
  /// Notes: None.
  static Future<void> setHomeListColumns(int columns) =>
      _setListColumns('homeListColumns', columns);

  /// Purpose: Read the management module's list column preference.
  /// Inputs: None.
  /// Returns: `Future<int>` — defaults to `listColumnsAuto`.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: None.
  static Future<int> getManageListColumns() =>
      _getListColumns('manageListColumns');

  /// Purpose: Persist the management module's list column preference.
  /// Inputs: `columns`.
  /// Returns: None.
  /// Side effects: Writes `storage_config.json`.
  /// Notes: None.
  static Future<void> setManageListColumns(int columns) =>
      _setListColumns('manageListColumns', columns);

  /// Purpose: Read the statistics module's list column preference.
  /// Inputs: None.
  /// Returns: `Future<int>` — defaults to `listColumnsAuto`.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: None.
  static Future<int> getStatsListColumns() =>
      _getListColumns('statsListColumns');

  /// Purpose: Persist the statistics module's list column preference.
  /// Inputs: `columns`.
  /// Returns: None.
  /// Side effects: Writes `storage_config.json`.
  /// Notes: None.
  static Future<void> setStatsListColumns(int columns) =>
      _setListColumns('statsListColumns', columns);
}
