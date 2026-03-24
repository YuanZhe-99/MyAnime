import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../shared/services/auto_sync_service.dart';
import '../models/anime.dart';

class AnimeStorage {
  static const _dataFileName = 'anime_data.json';
  static const _configFileName = 'storage_config.json';

  /// Data file names managed by the app (for storage migration).
  static const _dataFileNames = [_dataFileName];

  /// Custom storage directory path override.
  static String? _customPath;

  /// Whether config has been loaded from disk.
  static bool _configLoaded = false;

  static Future<Directory> _getDefaultAppDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final appDir = Directory(p.join(dir.path, 'MyAnime'));
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return appDir;
  }

  /// Config file always lives in the default location.
  static Future<File> _getConfigFile() async {
    final dir = await _getDefaultAppDir();
    return File(p.join(dir.path, _configFileName));
  }

  /// Load the storage path from config file (once).
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

  static Future<File> _getFile(String name) async {
    final appDir = await getAppDir();
    return File(p.join(appDir.path, name));
  }

  /// Get the data file for direct access (e.g. password verification).
  static Future<File> getDataFile() => _getFile(_dataFileName);

  /// Get the storage directory path for display.
  static Future<String> getStoragePath() async {
    final appDir = await getAppDir();
    return appDir.path;
  }

  /// Set a custom storage directory path.
  /// Pass null to reset to default.
  /// If the new path already has data files, uses those;
  /// otherwise moves existing data files to the new location.
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

      for (final name in _dataFileNames) {
        final oldFile = File(p.join(oldDir.path, name));
        final newFile = File(p.join(newDir.path, name));
        if (await newFile.exists()) continue;
        if (await oldFile.exists()) {
          await oldFile.copy(newFile.path);
          await oldFile.delete();
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Data persistence ──

  static Future<AnimeData> load() async {
    final file = await _getFile(_dataFileName);
    if (!await file.exists()) return const AnimeData();
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return const AnimeData();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return AnimeData.fromJson(json);
  }

  static Future<void> save(AnimeData data) async {
    final file = await _getFile(_dataFileName);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data.toJson());
    await file.writeAsString(jsonStr);
    AutoSyncService.instance.notifySaved();
  }

  // ── CRUD operations ──

  static Future<void> addOrUpdate(Anime anime) async {
    final data = await load();
    final list = List<Anime>.of(data.animes);
    final idx = list.indexWhere((a) => a.id == anime.id);
    if (idx >= 0) {
      list[idx] = anime;
    } else {
      list.add(anime);
    }
    await save(AnimeData(animes: list));
  }

  static Future<void> deleteAnime(String id) async {
    final data = await load();
    final list = data.animes.where((a) => a.id != id).toList();
    await save(AnimeData(animes: list));
  }

  // ── Config persistence ──

  static Future<Map<String, dynamic>> readConfig() async {
    final file = await _getConfigFile();
    if (!await file.exists()) return {};
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return {};
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> writeConfig(Map<String, dynamic> config) async {
    final file = await _getConfigFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(config),
    );
  }

  static Future<String?> getThemeMode() async {
    final config = await readConfig();
    return config['themeMode'] as String?;
  }

  static Future<void> setThemeMode(String? mode) async {
    final config = await readConfig();
    if (mode == null) {
      config.remove('themeMode');
    } else {
      config['themeMode'] = mode;
    }
    await writeConfig(config);
  }

  static Future<String?> getLocaleTag() async {
    final config = await readConfig();
    return config['locale'] as String?;
  }

  static Future<void> setLocaleTag(String? tag) async {
    final config = await readConfig();
    if (tag == null) {
      config.remove('locale');
    } else {
      config['locale'] = tag;
    }
    await writeConfig(config);
  }
}
