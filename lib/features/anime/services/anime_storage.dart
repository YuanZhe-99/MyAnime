import 'dart:convert';
import 'dart:io';

import 'package:myapps_data/myapps_data.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../shared/services/auto_sync_service.dart';
import '../../../shared/services/reminder_service.dart';
import '../../../shared/utils/adaptive_layout.dart';
import '../../../shared/utils/calendar_preferences.dart';
import '../../../shared/utils/season_label.dart';
import '../models/anime.dart';

class AnimeStorage {
  static const _dataFileName = 'anime_data.json';
  static const _configFileName = 'storage_config.json';

  /// Custom storage directory path override.
  static String? _customPath;

  /// Whether config has been loaded from disk.
  static bool _configLoaded = false;

  /// Purpose: Serialize every read-modify-write of `anime_data.json`.
  /// Inputs: None.
  /// Returns: The shared write queue for the library file.
  /// Side effects: None.
  /// Notes: Static on purpose: all callers in the process share one queue, so
  /// two overlapping load-modify-save sequences can no longer drop each
  /// other's change. Code already running inside this queue must call
  /// [_writeData], never the public [save], which would enqueue behind itself
  /// and deadlock.
  static final AtomicWriteQueue _dataQueue = AtomicWriteQueue();

  /// Purpose: Serialize every read-modify-write of `storage_config.json`.
  /// Inputs: None.
  /// Returns: The shared write queue for the config file.
  /// Side effects: None.
  /// Notes: Independent of [_dataQueue] because the two files never depend on
  /// each other. Code already inside this queue must call [_writeConfig].
  static final AtomicWriteQueue _configQueue = AtomicWriteQueue();

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
      await updateConfig((config) {
        if (newPath != null) {
          config['storagePath'] = newPath;
        } else {
          config.remove('storagePath');
        }
      });

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

  /// Purpose: Persist the library and notify auto-sync and reminders.
  /// Inputs: `data`.
  /// Returns: None.
  /// Side effects: Atomically rewrites `anime_data.json` through a uniquely
  /// named temporary file, then notifies auto-sync and the reminder service.
  /// Notes: Internal helper used within this file only. It is the write that
  /// code already running inside [_dataQueue] must use; it never enqueues.
  static Future<void> _writeData(AnimeData data) async {
    final file = await _getFile(_dataFileName);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data.toJson());
    await atomicWriteString(file, jsonStr);
    AutoSyncService.instance.notifySaved();
    ReminderService.notifyDataChanged();
  }

  /// Purpose: Run a read-modify-write operation on the library exclusively.
  /// Inputs: `operation` — runs inside [_dataQueue]; it must call
  /// [_writeData], never [save].
  /// Returns: `Future<T>` — whatever `operation` returned.
  /// Side effects: Whatever `operation` does; queued behind earlier writes.
  /// Notes: Internal helper used within this file only.
  static Future<T> _exclusiveData<T>(Future<T> Function() operation) async {
    late T result;
    await _dataQueue.enqueue(() async {
      result = await operation();
    });
    return result;
  }

  /// Purpose: Persist the whole library.
  /// Inputs: `data`.
  /// Returns: None.
  /// Side effects: Queued behind every other library write, then atomically
  /// rewrites `anime_data.json`, notifies auto-sync and refreshes mobile
  /// reminder schedules so scheduled notification bodies track the latest data.
  /// Notes: Prefer [updateRecord] / [updateLibrary] when the new value depends
  /// on what is stored: `save` writes exactly the snapshot it is given.
  static Future<void> save(AnimeData data) =>
      _dataQueue.enqueue(() => _writeData(data));

  /// Purpose: Replace one record computed from the freshly stored copy.
  /// Inputs: `id`; `update` receives the stored record and returns the
  /// replacement, or `null` to leave the file untouched.
  /// Returns: `Future<bool>` — whether a record was written.
  /// Side effects: One queued load and, when written, one save of
  /// `anime_data.json`.
  /// Notes: Re-reads inside the queue, so a form applying only the fields the
  /// user edited cannot overwrite a background change (episode statuses,
  /// external metadata) made since the form opened. A missing id writes
  /// nothing. `AnimeData.extraJson` is carried through.
  static Future<bool> updateRecord(
    String id,
    Anime? Function(Anime current) update,
  ) => _exclusiveData(() async {
    final data = await load();
    final idx = data.animes.indexWhere((a) => a.id == id);
    if (idx < 0) return false;
    final replaced = update(data.animes[idx]);
    if (replaced == null) return false;
    final list = List<Anime>.of(data.animes);
    list[idx] = replaced;
    await _writeData(AnimeData(animes: list, extraJson: data.extraJson));
    return true;
  });

  /// Purpose: Rewrite the library from a freshly re-read copy.
  /// Inputs: `update` receives the stored records and returns the new list, or
  /// `null` to leave the file untouched.
  /// Returns: `Future<bool>` — whether the library was written.
  /// Side effects: One queued load and, when written, one save.
  /// Notes: Carries `AnimeData.extraJson` through, so unknown top-level fields
  /// written by a newer build survive bundle import, replace and delete flows.
  static Future<bool> updateLibrary(
    List<Anime>? Function(List<Anime> current) update,
  ) => _exclusiveData(() async {
    final data = await load();
    final next = update(List<Anime>.of(data.animes));
    if (next == null) return false;
    await _writeData(AnimeData(animes: next, extraJson: data.extraJson));
    return true;
  });

  // ── CRUD operations ──

  /// Purpose: Implement the add or update behavior for this file.
  /// Inputs: `anime`.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Carries `AnimeData.extraJson` through, so unknown top-level fields
  /// written by a newer build survive an edit made by an older one.
  static Future<void> addOrUpdate(Anime anime) => updateLibrary((list) {
    final idx = list.indexWhere((a) => a.id == anime.id);
    if (idx >= 0) {
      list[idx] = anime;
    } else {
      list.add(anime);
    }
    return list;
  });

  /// Purpose: Add or replace several anime records in one write.
  /// Inputs: `animes` — records keyed by `id`; a later duplicate id wins.
  /// Returns: None.
  /// Side effects: One load and one save of `anime_data.json`, so one
  /// auto-sync notification. Does nothing for an empty input.
  /// Notes: Used by series curation, which may rewrite every member of a
  /// series at once. Callers stamp `modifiedAt` themselves; this method writes
  /// the records exactly as given.
  static Future<void> addOrUpdateAll(Iterable<Anime> animes) async {
    final incoming = {for (final a in animes) a.id: a};
    if (incoming.isEmpty) return;
    await updateLibrary((current) {
      final updates = Map<String, Anime>.of(incoming);
      return [
        for (final a in current) updates.remove(a.id) ?? a,
        ...updates.values,
      ];
    });
  }

  /// Purpose: Refresh cached external metadata without marking records edited.
  /// Inputs: `updates` keyed by id; optional `expectedWatchUrls` guards delayed directory results.
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
    Map<String, AnimeExternalMeta> updates, {
    Map<String, String>? expectedWatchUrls,
  }) async {
    if (updates.isEmpty) return false;
    return updateLibrary((list) {
      var touched = false;
      for (var i = 0; i < list.length; i++) {
        final meta = updates[list[i].id];
        if (meta == null) continue;
        final expected = expectedWatchUrls?[list[i].id];
        if (expected != null && list[i].watchUrl?.trim() != expected) continue;
        final existing = list[i].externalMeta ?? const AnimeExternalMeta();
        final incoming = meta.episodeCatalog;
        final previous = existing.episodeCatalog;
        if (expected != null &&
            incoming != null &&
            previous != null &&
            previous.sourceUrl == incoming.sourceUrl &&
            (previous.checkedAt.isAfter(incoming.checkedAt) ||
                (previous.complete && !incoming.complete))) {
          continue;
        }
        // `copyWith` defaults `modifiedAt` to now when it is omitted, so the
        // existing value has to be passed back in explicitly. Everything in the
        // Notes above depends on this line.
        list[i] = list[i].copyWith(
          externalMeta: expected != null
              ? existing.mergedWith(meta)
              : (meta.episodeCatalog == null && previous != null
                    ? meta.mergedWith(
                        AnimeExternalMeta(episodeCatalog: previous),
                      )
                    : meta),
          modifiedAt: list[i].modifiedAt,
        );
        touched = true;
      }
      return touched ? list : null;
    });
  }

  /// Purpose: Replace default season labels with ones derived from titles,
  /// without marking the records edited.
  /// Inputs: `labels` — new label keyed by anime id, from
  /// `seasonLabelFixups`.
  /// Returns: `Future<bool>` — whether anything was actually written.
  /// Side effects: Rewrites `anime_data.json` when at least one record still
  /// had a default label.
  /// Notes: Keeps `modifiedAt` for the reasons given on [patchExternalMeta]:
  /// every device running 1.6.1 or later derives the same label, so the fix
  /// needs no conflict, and a newer remote edit simply wins and is fixed again
  /// on the next load. Re-reads first and skips any record whose label is no
  /// longer the default, so a label the user just typed is never overwritten.
  static Future<bool> patchSeasonLabels(Map<String, String> labels) async {
    if (labels.isEmpty) return false;
    return updateLibrary((list) {
      var touched = false;
      for (var i = 0; i < list.length; i++) {
        final label = labels[list[i].id];
        if (label == null || !isDefaultSeasonLabel(list[i].season)) continue;
        list[i] = list[i].copyWith(
          season: label,
          modifiedAt: list[i].modifiedAt,
        );
        touched = true;
      }
      return touched ? list : null;
    });
  }

  /// Purpose: Load the library after correcting default season labels.
  /// Inputs: `fixups` — computes the labels to write from the loaded records;
  /// pass `seasonLabelFixups`.
  /// Returns: `Future<AnimeData>` — the library, re-read if anything changed.
  /// Side effects: May call [patchSeasonLabels].
  /// Notes: The derivation lives in `series_service.dart`, which this file
  /// does not import, hence the parameter. Used by the pages that show season
  /// labels (Home, Manage, detail) so records synced from older builds are
  /// corrected the next time they are shown.
  static Future<AnimeData> loadFixingSeasonLabels(
    Map<String, String> Function(List<Anime> records) fixups,
  ) async {
    final data = await load();
    final labels = fixups(data.animes);
    if (labels.isEmpty || !await patchSeasonLabels(labels)) return data;
    return load();
  }

  /// Purpose: Delete anime from the relevant storage or state.
  /// Inputs: `id`.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Carries `AnimeData.extraJson` through for the same reason
  /// [addOrUpdate] does.
  static Future<void> deleteAnime(String id) =>
      updateLibrary((list) => list.where((a) => a.id != id).toList());

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

  /// Purpose: Write the config file atomically.
  /// Inputs: `config`.
  /// Returns: None.
  /// Side effects: Atomically rewrites `storage_config.json` through a
  /// uniquely named temporary file.
  /// Notes: Internal helper used within this file only; the write that code
  /// already inside [_configQueue] must use.
  static Future<void> _writeConfig(Map<String, dynamic> config) async {
    final file = await _getConfigFile();
    await atomicWriteString(
      file,
      const JsonEncoder.withIndent('  ').convert(config),
    );
  }

  /// Purpose: Replace the whole config file.
  /// Inputs: `config`.
  /// Returns: None.
  /// Side effects: Queued behind other config writes, then atomically rewrites
  /// `storage_config.json`.
  /// Notes: Prefer [updateConfig] for a change to a few keys; this overwrites
  /// every key it is not given.
  static Future<void> writeConfig(Map<String, dynamic> config) =>
      _configQueue.enqueue(() => _writeConfig(config));

  /// Purpose: Change some config keys without losing concurrent changes.
  /// Inputs: `change` mutates the freshly read config map in place.
  /// Returns: None.
  /// Side effects: Queued read-modify-write of `storage_config.json`.
  /// Notes: Every setter goes through here, so two settings saved at once (the
  /// settings page fires several) both persist instead of the later write
  /// restoring the earlier stale value. `change` must be synchronous.
  static Future<void> updateConfig(
    void Function(Map<String, dynamic> config) change,
  ) => _configQueue.enqueue(() async {
    final config = await readConfig();
    change(config);
    await _writeConfig(config);
  });

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
    await updateConfig((config) {
      if (mode == null) {
        config.remove('themeMode');
      } else {
        config['themeMode'] = mode;
      }
    });
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
    await updateConfig((config) {
      if (tag == null) {
        config.remove('locale');
      } else {
        config['locale'] = tag;
      }
    });
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
    await updateConfig((config) {
      if (normalized == defaultWeekStartDay) {
        config.remove('weekStartDay');
      } else {
        config['weekStartDay'] = normalized;
      }
    });
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
    await updateConfig((config) {
      if (layout == null) {
        config.remove('homeCalendarLayout');
      } else {
        config['homeCalendarLayout'] = layout;
      }
    });
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
    await updateConfig((config) {
      if (basis == null) {
        config.remove('homeCalendarTimeBasis');
      } else {
        config['homeCalendarTimeBasis'] = basis;
      }
    });
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
    await updateConfig((config) {
      if (format == null) {
        config.remove('homeCalendarFormat');
      } else {
        config['homeCalendarFormat'] = format;
      }
    });
  }

  /// Purpose: Return the persisted Manage view mode (1.6.2).
  /// Inputs: None.
  /// Returns: `Future<String?>` — `series`, or `null` for the default
  /// quarter view.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: Device-local, never synced.
  static Future<String?> getManageViewMode() async {
    final config = await readConfig();
    return config['manageViewMode'] as String?;
  }

  /// Purpose: Persist the Manage view mode (1.6.2).
  /// Inputs: `mode` — `null` for the default quarter view.
  /// Returns: None.
  /// Side effects: Writes `storage_config.json`.
  /// Notes: Passing `null` removes the key, so only a non-default is stored.
  static Future<void> setManageViewMode(String? mode) async {
    await updateConfig((config) {
      if (mode == null) {
        config.remove('manageViewMode');
      } else {
        config['manageViewMode'] = mode;
      }
    });
  }

  /// Purpose: Return the persisted Manage series-view sort (1.6.2).
  /// Inputs: None.
  /// Returns: `Future<String?>` — `title` or `modified`, or `null` for the
  /// default (newest premiere first).
  /// Side effects: Reads `storage_config.json`.
  /// Notes: Device-local, never synced.
  static Future<String?> getManageSeriesSort() async {
    final config = await readConfig();
    return config['manageSeriesSort'] as String?;
  }

  /// Purpose: Persist the Manage series-view sort (1.6.2).
  /// Inputs: `sort` — `null` for the default.
  /// Returns: None.
  /// Side effects: Writes `storage_config.json`.
  /// Notes: Passing `null` removes the key, so only a non-default is stored.
  static Future<void> setManageSeriesSort(String? sort) async {
    await updateConfig((config) {
      if (sort == null) {
        config.remove('manageSeriesSort');
      } else {
        config['manageSeriesSort'] = sort;
      }
    });
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
    await updateConfig((config) {
      if (policy == null) {
        config.remove('metadataAutoUpdate');
      } else {
        config['metadataAutoUpdate'] = policy;
      }
    });
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
    await updateConfig((config) {
      if (enabled) {
        config['metadataPrefetchCovers'] = true;
      } else {
        config.remove('metadataPrefetchCovers');
      }
    });
  }

  /// Purpose: Return whether the Kana quick-reference tab is shown.
  /// Inputs: None.
  /// Returns: `Future<bool>` — defaults to false.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: Off by default since 1.6.0, for existing installs too, because
  /// kana practice now lives in the separate MyNihongo!!!!! app.
  static Future<bool> getKanaTabEnabled() async {
    final config = await readConfig();
    return config['kanaTabEnabled'] == true;
  }

  /// Purpose: Persist whether the Kana quick-reference tab is shown.
  /// Inputs: `enabled`.
  /// Returns: None.
  /// Side effects: Writes `storage_config.json`.
  /// Notes: The default `false` is removed from config rather than stored.
  static Future<void> setKanaTabEnabled(bool enabled) async {
    await updateConfig((config) {
      if (enabled) {
        config['kanaTabEnabled'] = true;
      } else {
        config.remove('kanaTabEnabled');
      }
    });
  }

  /// Purpose: Return whether the bottom navigation bar floats as an island.
  /// Inputs: None.
  /// Returns: `Future<bool>` — defaults to true.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: Stored inverted as `classicNavBar` so the default (floating, since
  /// 1.7.0) needs no key and existing installs get it too.
  static Future<bool> getFloatingNavBar() async {
    final config = await readConfig();
    return config['classicNavBar'] != true;
  }

  /// Purpose: Persist whether the bottom navigation bar floats as an island.
  /// Inputs: `floating`.
  /// Returns: None.
  /// Side effects: Writes `storage_config.json`.
  /// Notes: Only the non-default classic bar is stored, as
  /// `classicNavBar: true`; choosing floating removes the key.
  static Future<void> setFloatingNavBar(bool floating) async {
    await updateConfig((config) {
      if (floating) {
        config.remove('classicNavBar');
      } else {
        config['classicNavBar'] = true;
      }
    });
  }

  /// Purpose: Return whether on-device AI is turned on.
  /// Inputs: None.
  /// Returns: `Future<bool>` — defaults to false.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: Off by default; while off, the on-device model is never asked
  /// anything. See `doc/en-us/on-device-ai.md`.
  static Future<bool> getOnDeviceAiEnabled() async {
    final config = await readConfig();
    return config['onDeviceAiEnabled'] == true;
  }

  /// Purpose: Persist whether on-device AI is turned on.
  /// Inputs: `enabled`.
  /// Returns: None.
  /// Side effects: Writes `storage_config.json`.
  /// Notes: The default `false` is removed from config rather than stored.
  static Future<void> setOnDeviceAiEnabled(bool enabled) async {
    await updateConfig((config) {
      if (enabled) {
        config['onDeviceAiEnabled'] = true;
      } else {
        config.remove('onDeviceAiEnabled');
      }
    });
  }

  /// Purpose: Return whether automatic categories are turned on.
  /// Inputs: None.
  /// Returns: `Future<bool>` — defaults to false.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: Off by default. Device-local, like every key in this file.
  static Future<bool> getAutoCategoriesEnabled() async {
    final config = await readConfig();
    return config['autoCategoriesEnabled'] == true;
  }

  /// Purpose: Persist whether automatic categories are turned on.
  /// Inputs: `enabled`.
  /// Returns: None.
  /// Side effects: Writes `storage_config.json`.
  /// Notes: The default `false` is removed from config rather than stored.
  static Future<void> setAutoCategoriesEnabled(bool enabled) async {
    await updateConfig((config) {
      if (enabled) {
        config['autoCategoriesEnabled'] = true;
      } else {
        config.remove('autoCategoriesEnabled');
      }
    });
  }

  /// Purpose: Return whether recommendations are turned on.
  /// Inputs: None.
  /// Returns: `Future<bool>` — defaults to false.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: Off by default. Device-local.
  static Future<bool> getRecommendationsEnabled() async {
    final config = await readConfig();
    return config['recommendationsEnabled'] == true;
  }

  /// Purpose: Persist whether recommendations are turned on.
  /// Inputs: `enabled`.
  /// Returns: None.
  /// Side effects: Writes `storage_config.json`.
  /// Notes: The default `false` is removed from config rather than stored.
  static Future<void> setRecommendationsEnabled(bool enabled) async {
    await updateConfig((config) {
      if (enabled) {
        config['recommendationsEnabled'] = true;
      } else {
        config.remove('recommendationsEnabled');
      }
    });
  }

  /// Purpose: Return whether the faster on-device model is preferred.
  /// Inputs: None.
  /// Returns: `Future<bool>` — defaults to false.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: Android only, and only meaningful where AICore serves both sizes.
  static Future<bool> getOnDeviceAiPreferFast() async {
    final config = await readConfig();
    return config['onDeviceAiPreferFast'] == true;
  }

  /// Purpose: Persist whether the faster on-device model is preferred.
  /// Inputs: `enabled`.
  /// Returns: None.
  /// Side effects: Writes `storage_config.json`.
  /// Notes: The default `false` is removed from config rather than stored.
  static Future<void> setOnDeviceAiPreferFast(bool enabled) async {
    await updateConfig((config) {
      if (enabled) {
        config['onDeviceAiPreferFast'] = true;
      } else {
        config.remove('onDeviceAiPreferFast');
      }
    });
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
    await updateConfig((config) {
      if (columns >= 1 && columns <= listMaxColumns) {
        config[key] = columns;
      } else {
        config.remove(key);
      }
    });
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
