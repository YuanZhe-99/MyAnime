import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../features/anime/services/anime_storage.dart';

/// Manages local backups with manual/auto creation and retention policies.
class BackupService {
  static const _backupDir = 'backups';

  static bool autoBackupEnabled = false;
  static int retentionDays = 0; // 0 = keep forever
  static DateTime? _lastAutoBackup;

  /// Data module identifiers used for per-module restore.
  static const modules = <String, String>{'anime_data.json': 'anime'};

  /// Purpose: Provide the internal get backup dir helper for this file.
  /// Inputs: None.
  /// Returns: `Future<Directory>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static Future<Directory> _getBackupDir() async {
    final appDir = await AnimeStorage.getAppDir();
    final dir = Directory(p.join(appDir.path, _backupDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Purpose: Load backup settings from config.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Load backup settings from config.
  static Future<void> loadSettings() async {
    final config = await AnimeStorage.readConfig();
    autoBackupEnabled = config['autoBackupEnabled'] as bool? ?? false;
    retentionDays = config['backupRetentionDays'] as int? ?? 0;
  }

  /// Purpose: Save backup settings to config.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Save backup settings to config.
  static Future<void> saveSettings() async {
    final config = await AnimeStorage.readConfig();
    config['autoBackupEnabled'] = autoBackupEnabled;
    config['backupRetentionDays'] = retentionDays;
    await AnimeStorage.writeConfig(config);
  }

  /// Purpose: Create a backup now. Returns the backup file, or null on failure.
  /// Inputs: None.
  /// Returns: `Future<File?>`.
  /// Side effects: None.
  /// Notes: Create a backup now. Returns the backup file, or null on failure.
  static Future<File?> createBackup() async {
    try {
      final appDir = await AnimeStorage.getAppDir();
      final backupDir = await _getBackupDir();
      final bundle = <String, dynamic>{};

      for (final name in modules.keys) {
        final file = File(p.join(appDir.path, name));
        if (await file.exists()) {
          bundle[name] = await file.readAsString();
        }
      }

      // Include images
      final imgDir = Directory(p.join(appDir.path, 'images'));
      if (await imgDir.exists()) {
        final images = <String, String>{};
        await for (final entity in imgDir.list()) {
          if (entity is File) {
            final bytes = await entity.readAsBytes();
            images['images/${p.basename(entity.path)}'] = base64Encode(bytes);
          }
        }
        if (images.isNotEmpty) bundle['_images'] = images;
      }

      final content = jsonEncode(bundle);

      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File(p.join(backupDir.path, 'backup_$stamp.json'));
      await file.writeAsString(content);

      await _cleanOldBackups();
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Purpose: Run auto-backup if enabled and not yet done today.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Run auto-backup if enabled and not yet done today.
  static Future<void> runAutoBackupIfNeeded() async {
    await loadSettings();
    if (!autoBackupEnabled) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_lastAutoBackup != null) {
      final lastDay = DateTime(
        _lastAutoBackup!.year,
        _lastAutoBackup!.month,
        _lastAutoBackup!.day,
      );
      if (!lastDay.isBefore(today)) return;
    }

    final existing = await listBackups();
    final alreadyToday = existing.any((b) {
      final d = b.date;
      return d.year == today.year &&
          d.month == today.month &&
          d.day == today.day;
    });
    if (alreadyToday) {
      _lastAutoBackup = now;
      return;
    }

    await createBackup();
    _lastAutoBackup = now;
  }

  /// Purpose: List all backups sorted by date descending.
  /// Inputs: None.
  /// Returns: `Future<List<BackupInfo>>`.
  /// Side effects: None.
  /// Notes: List all backups sorted by date descending.
  static Future<List<BackupInfo>> listBackups() async {
    final backupDir = await _getBackupDir();
    if (!await backupDir.exists()) return [];

    final files = <BackupInfo>[];
    await for (final entity in backupDir.list()) {
      if (entity is File &&
          p.basename(entity.path).startsWith('backup_') &&
          entity.path.endsWith('.json')) {
        final stat = await entity.stat();
        final name = p.basenameWithoutExtension(entity.path);
        DateTime? date;
        try {
          final parts = name.replaceFirst('backup_', '');
          date = DateFormat('yyyyMMdd_HHmmss').parse(parts);
        } catch (_) {
          date = stat.modified;
        }
        files.add(BackupInfo(file: entity, date: date, sizeBytes: stat.size));
      }
    }
    files.sort((a, b) => b.date.compareTo(a.date));
    return files;
  }

  /// Purpose: Read a backup's content and return module names it contains.
  /// Inputs: `file`.
  /// Returns: `Future<List<String>>`.
  /// Side effects: None.
  /// Notes: Read a backup's content and return module names it contains.
  static Future<List<String>> getBackupModules(File file) async {
    try {
      final raw = await file.readAsString();
      final bundle = jsonDecode(raw) as Map<String, dynamic>;
      return modules.entries
          .where((e) => bundle.containsKey(e.key))
          .map((e) => e.value)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Purpose: Restore from a backup file, optionally only specific modules.
  /// Inputs: `file`, `moduleKeys`.
  /// Returns: `Future<bool>`.
  /// Side effects: None.
  /// Notes: Restore from a backup file, optionally only specific modules.
  static Future<bool> restoreBackup(
    File file, {
    Set<String>? moduleKeys,
  }) async {
    try {
      final raw = await file.readAsString();

      final bundle = jsonDecode(raw) as Map<String, dynamic>;
      final appDir = await AnimeStorage.getAppDir();

      for (final entry in modules.entries) {
        final fileName = entry.key;
        final moduleId = entry.value;
        if (moduleKeys != null && !moduleKeys.contains(moduleId)) continue;
        if (!bundle.containsKey(fileName)) continue;
        final outFile = File(p.join(appDir.path, fileName));
        await outFile.writeAsString(bundle[fileName] as String);
      }

      // Restore images
      if (bundle.containsKey('_images')) {
        final imagesMap = bundle['_images'] as Map<String, dynamic>;
        final imgDir = Directory(p.join(appDir.path, 'images'));
        if (!await imgDir.exists()) {
          await imgDir.create(recursive: true);
        }
        for (final e in imagesMap.entries) {
          final f = File(p.join(appDir.path, e.key));
          await f.writeAsBytes(base64Decode(e.value as String));
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Purpose: Delete a specific backup.
  /// Inputs: `file`.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Delete a specific backup.
  static Future<void> deleteBackup(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Purpose: Provide the internal clean old backups helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static Future<void> _cleanOldBackups() async {
    if (retentionDays <= 0) return;
    final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
    final backups = await listBackups();
    for (final b in backups) {
      if (b.date.isBefore(cutoff)) {
        await b.file.delete();
      }
    }
  }
}

class BackupInfo {
  final File file;
  final DateTime date;
  final int sizeBytes;

  /// Purpose: Create a backup info instance.
  /// Inputs: `file`, `date`, `sizeBytes`.
  /// Returns: A new `BackupInfo` instance.
  /// Side effects: None.
  /// Notes: None.
  const BackupInfo({
    required this.file,
    required this.date,
    required this.sizeBytes,
  });

  /// Purpose: Implement the display size behavior for this file.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: None.
  String get displaySize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
