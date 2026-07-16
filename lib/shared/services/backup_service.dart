import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../features/anime/models/anime.dart';
import '../../features/anime/services/anime_storage.dart';

/// Manages local backups with manual/auto creation and retention policies.
///
/// Backup format v2: each `backup_*.json` bundle stores data-module JSON
/// strings plus an `_imageRefs` map pointing at content-addressed image
/// blobs under `backups/blobs/<sha256><ext>`. Identical images are stored
/// once and shared by every backup that references them; a blob is deleted
/// only when no remaining backup references it. Legacy v1 bundles with
/// inline base64 `_images` remain restorable.
class BackupService {
  static const _backupDir = 'backups';
  static const _blobSubDir = 'blobs';
  static const _formatVersion = 2;

  /// Bundles at or below this size are parsed by [listBackups] to compute
  /// validity and referenced-blob sizes; larger (legacy inline-image)
  /// bundles are listed by file size alone.
  static const _probeMaxBytes = 4 * 1024 * 1024;

  /// Blobs younger than this are never garbage collected, protecting a
  /// backup that is being written concurrently with a GC pass.
  static const _blobGcGrace = Duration(minutes: 10);

  static bool autoBackupEnabled = false;
  static int retentionDays = 0; // 0 = keep forever
  static DateTime? _lastAutoBackup;
  static bool _autoBackupRunning = false;

  /// Purpose: Allow tests to redirect backup I/O to a temporary directory.
  /// Inputs: None.
  /// Returns: The overridden app directory future, or null in production.
  /// Side effects: None.
  /// Notes: Only set from tests; production always uses [AnimeStorage].
  @visibleForTesting
  static Future<Directory> Function()? appDirProvider;

  /// Data module identifiers used for per-module restore.
  static const modules = <String, String>{'anime_data.json': 'anime'};

  /// Purpose: Resolve the app data directory honoring the test override.
  /// Inputs: None.
  /// Returns: `Future<Directory>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static Future<Directory> _getAppDir() {
    final provider = appDirProvider;
    if (provider != null) return provider();
    return AnimeStorage.getAppDir();
  }

  /// Purpose: Provide the internal get backup dir helper for this file.
  /// Inputs: None.
  /// Returns: `Future<Directory>`.
  /// Side effects: Creates the backups directory when missing.
  /// Notes: Internal helper used within this file only.
  static Future<Directory> _getBackupDir() async {
    final appDir = await _getAppDir();
    final dir = Directory(p.join(appDir.path, _backupDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Purpose: Provide the shared content-addressed image blob directory.
  /// Inputs: None.
  /// Returns: `Future<Directory>`.
  /// Side effects: Creates `backups/blobs/` when missing.
  /// Notes: Internal helper used within this file only.
  static Future<Directory> _getBlobDir() async {
    final backupDir = await _getBackupDir();
    final dir = Directory(p.join(backupDir.path, _blobSubDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Purpose: Load backup settings from config.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Reads `storage_config.json` and mutates static settings.
  /// Notes: Load backup settings from config.
  static Future<void> loadSettings() async {
    final config = await AnimeStorage.readConfig();
    autoBackupEnabled = config['autoBackupEnabled'] as bool? ?? false;
    retentionDays = config['backupRetentionDays'] as int? ?? 0;
  }

  /// Purpose: Save backup settings to config.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Writes `storage_config.json`.
  /// Notes: Save backup settings to config.
  static Future<void> saveSettings() async {
    final config = await AnimeStorage.readConfig();
    config['autoBackupEnabled'] = autoBackupEnabled;
    config['backupRetentionDays'] = retentionDays;
    await AnimeStorage.writeConfig(config);
  }

  /// Purpose: Write a string to a file atomically (tmp-then-rename).
  /// Inputs: `file`, `content`.
  /// Returns: None.
  /// Side effects: Writes a temp file and renames it over the target path.
  /// Notes: Internal helper; creates parent directories as needed and
  /// prevents truncated backup bundles when the app is killed mid-write.
  static Future<void> _atomicWriteString(File file, String content) async {
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    final tmp = File(
      '${file.path}.tmp-${DateTime.now().microsecondsSinceEpoch}',
    );
    await tmp.writeAsString(content, flush: true);
    try {
      await tmp.rename(file.path);
    } catch (e) {
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
      rethrow;
    }
  }

  /// Purpose: Write bytes to a file atomically (tmp-then-rename).
  /// Inputs: `file`, `bytes`.
  /// Returns: None.
  /// Side effects: Writes a temp file and renames it over the target path.
  /// Notes: Internal helper used for blob writes and image restore. Creates
  /// parent directories as needed.
  static Future<void> _atomicWriteBytes(File file, List<int> bytes) async {
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    final tmp = File(
      '${file.path}.tmp-${DateTime.now().microsecondsSinceEpoch}',
    );
    await tmp.writeAsBytes(bytes, flush: true);
    try {
      await tmp.rename(file.path);
    } catch (e) {
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
      rethrow;
    }
  }

  /// Purpose: Create a backup now. Returns the backup file, or null on failure.
  /// Inputs: None.
  /// Returns: `Future<File?>`.
  /// Side effects: Writes the bundle JSON atomically, deduplicates images
  /// into `backups/blobs/`, then runs retention cleanup and blob GC.
  /// Notes: Images are stored once per unique content hash; the bundle only
  /// records `_imageRefs` so repeated backups stay small.
  static Future<File?> createBackup() async {
    try {
      final appDir = await _getAppDir();
      final backupDir = await _getBackupDir();
      final bundle = <String, dynamic>{'_backupFormat': _formatVersion};

      for (final name in modules.keys) {
        final file = File(p.join(appDir.path, name));
        if (await file.exists()) {
          bundle[name] = await file.readAsString();
        }
      }

      // Deduplicate images into the shared blob store and reference them.
      final imgDir = Directory(p.join(appDir.path, 'images'));
      if (await imgDir.exists()) {
        final blobDir = await _getBlobDir();
        final refs = <String, String>{};
        await for (final entity in imgDir.list()) {
          if (entity is File) {
            final bytes = await entity.readAsBytes();
            final hash = sha256.convert(bytes).toString();
            final ext = p.extension(entity.path);
            final blobName = '$hash$ext';
            final blobFile = File(p.join(blobDir.path, blobName));
            if (!await blobFile.exists()) {
              await _atomicWriteBytes(blobFile, bytes);
            }
            refs['images/${p.basename(entity.path)}'] = blobName;
          }
        }
        if (refs.isNotEmpty) bundle['_imageRefs'] = refs;
      }

      final content = jsonEncode(bundle);

      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File(p.join(backupDir.path, 'backup_$stamp.json'));
      await _atomicWriteString(file, content);

      await _cleanOldBackups();
      await _collectUnreferencedBlobs();
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Purpose: Run auto-backup if enabled and not yet done today.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May create a backup file and mutate `_lastAutoBackup`.
  /// Notes: Re-entrancy guarded; a corrupt (unparseable) bundle from today
  /// does not count as today's backup, so an interrupted write is retried.
  static Future<void> runAutoBackupIfNeeded() async {
    if (_autoBackupRunning) return;
    _autoBackupRunning = true;
    try {
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
        if (b.corrupt) return false;
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
    } finally {
      _autoBackupRunning = false;
    }
  }

  /// Purpose: List all backups sorted by date descending.
  /// Inputs: None.
  /// Returns: `Future<List<BackupInfo>>`.
  /// Side effects: None.
  /// Notes: Small bundles are parsed to detect corruption and to add the
  /// referenced blob sizes to the displayed size; oversized legacy bundles
  /// are listed by file size alone.
  static Future<List<BackupInfo>> listBackups() async {
    final backupDir = await _getBackupDir();
    if (!await backupDir.exists()) return [];
    final blobDir = await _getBlobDir();

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

        var sizeBytes = stat.size;
        var corrupt = false;
        if (stat.size <= _probeMaxBytes) {
          try {
            final bundle =
                jsonDecode(await entity.readAsString())
                    as Map<String, dynamic>;
            final refs = bundle['_imageRefs'];
            if (refs is Map<String, dynamic>) {
              for (final blobName in refs.values) {
                if (blobName is! String) continue;
                final blobFile = File(
                  p.join(blobDir.path, p.basename(blobName)),
                );
                if (await blobFile.exists()) {
                  sizeBytes += await blobFile.length();
                }
              }
            }
          } catch (_) {
            corrupt = true;
          }
        }
        files.add(
          BackupInfo(
            file: entity,
            date: date,
            sizeBytes: sizeBytes,
            corrupt: corrupt,
          ),
        );
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

  /// Purpose: Return a sanitized flat `images/<name>` relative path or null.
  /// Inputs: `rawKey` from a backup bundle image map.
  /// Returns: The normalized safe relative path, or null when rejected.
  /// Side effects: None.
  /// Notes: Internal helper; rejects traversal, nesting, and absolute paths
  /// so a crafted backup bundle cannot write outside `images/`.
  static String? _safeImageRelativePath(String rawKey) {
    final normalized = p.normalize(rawKey).replaceAll('\\', '/');
    if (!normalized.startsWith('images/') ||
        normalized.split('/').length != 2 ||
        normalized.contains('..') ||
        p.isAbsolute(normalized)) {
      return null;
    }
    return normalized;
  }

  /// Purpose: Restore from a backup file, optionally only specific modules.
  /// Inputs: `file`, `moduleKeys`.
  /// Returns: `Future<RestoreResult>` describing success, whether any file
  /// was written, and how many v2 image references had no blob on disk.
  /// Side effects: Overwrites app data files atomically and restores image
  /// files from blob references (v2) or inline base64 (legacy v1).
  /// Notes: Every selected module payload is validated against the model
  /// parser before anything is written; image names are sanitized. A failure
  /// with `wroteAnything == false` means local data is untouched; callers
  /// use that to decide whether re-enabling auto-sync is safe.
  static Future<RestoreResult> restoreBackup(
    File file, {
    Set<String>? moduleKeys,
  }) async {
    var wrote = false;
    var missingImages = 0;
    try {
      final raw = await file.readAsString();

      final bundle = jsonDecode(raw) as Map<String, dynamic>;
      final appDir = await _getAppDir();

      // Validate every selected payload before writing any file.
      final writes = <String, String>{};
      for (final entry in modules.entries) {
        final fileName = entry.key;
        final moduleId = entry.value;
        if (moduleKeys != null && !moduleKeys.contains(moduleId)) continue;
        if (!bundle.containsKey(fileName)) continue;
        final content = bundle[fileName] as String;
        AnimeData.fromJson(jsonDecode(content) as Map<String, dynamic>);
        writes[fileName] = content;
      }

      for (final entry in writes.entries) {
        await _atomicWriteString(
          File(p.join(appDir.path, entry.key)),
          entry.value,
        );
        wrote = true;
      }

      // Restore images: v2 blob references first, then legacy inline base64.
      final refs = bundle['_imageRefs'];
      if (refs is Map<String, dynamic>) {
        final blobDir = await _getBlobDir();
        for (final e in refs.entries) {
          final relPath = _safeImageRelativePath(e.key);
          final blobName = e.value;
          if (relPath == null || blobName is! String) continue;
          final blobFile = File(p.join(blobDir.path, p.basename(blobName)));
          if (!await blobFile.exists()) {
            // Blob store incomplete (e.g. bundle copied without blobs);
            // count it so the UI can warn instead of silently dropping.
            missingImages += 1;
            continue;
          }
          await _atomicWriteBytes(
            File(p.join(appDir.path, relPath)),
            await blobFile.readAsBytes(),
          );
          wrote = true;
        }
      } else if (bundle.containsKey('_images')) {
        final imagesMap = bundle['_images'] as Map<String, dynamic>;
        for (final e in imagesMap.entries) {
          final relPath = _safeImageRelativePath(e.key);
          if (relPath == null || e.value is! String) continue;
          await _atomicWriteBytes(
            File(p.join(appDir.path, relPath)),
            base64Decode(e.value as String),
          );
          wrote = true;
        }
      }

      return RestoreResult(
        ok: true,
        wroteAnything: wrote,
        missingImages: missingImages,
      );
    } catch (_) {
      return RestoreResult(
        ok: false,
        wroteAnything: wrote,
        missingImages: missingImages,
      );
    }
  }

  /// Purpose: Delete a specific backup.
  /// Inputs: `file`.
  /// Returns: None.
  /// Side effects: Deletes the bundle, then garbage collects image blobs no
  /// remaining backup references.
  /// Notes: Delete a specific backup.
  static Future<void> deleteBackup(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
    await _collectUnreferencedBlobs();
  }

  /// Purpose: Provide the internal clean old backups helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Deletes bundles older than the retention window.
  /// Notes: Internal helper; callers run blob GC afterwards.
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

  /// Purpose: Delete image blobs that no remaining backup references.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Deletes files under `backups/blobs/`.
  /// Notes: Conservative: when any remaining bundle cannot be parsed the
  /// pass is aborted (the reference set is unknown), and blobs younger than
  /// [_blobGcGrace] are kept so a concurrent backup write is never raced.
  static Future<void> _collectUnreferencedBlobs() async {
    try {
      final blobDir = await _getBlobDir();
      final blobs = <File>[];
      await for (final entity in blobDir.list()) {
        if (entity is File) blobs.add(entity);
      }
      if (blobs.isEmpty) return;

      final backupDir = await _getBackupDir();
      final referenced = <String>{};
      await for (final entity in backupDir.list()) {
        if (entity is! File ||
            !p.basename(entity.path).startsWith('backup_') ||
            !entity.path.endsWith('.json')) {
          continue;
        }
        Map<String, dynamic> bundle;
        try {
          bundle = jsonDecode(await entity.readAsString())
              as Map<String, dynamic>;
        } catch (_) {
          // Unknown reference set: never delete blobs under uncertainty.
          return;
        }
        final refs = bundle['_imageRefs'];
        if (refs is Map<String, dynamic>) {
          for (final v in refs.values) {
            if (v is String) referenced.add(p.basename(v));
          }
        }
      }

      final now = DateTime.now();
      for (final blob in blobs) {
        if (referenced.contains(p.basename(blob.path))) continue;
        final stat = await blob.stat();
        if (now.difference(stat.modified) < _blobGcGrace) continue;
        try {
          await blob.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }
}

class RestoreResult {
  final bool ok;
  final bool wroteAnything;
  final int missingImages;

  /// Purpose: Create a restore result instance.
  /// Inputs: `ok`, `wroteAnything`, `missingImages`.
  /// Returns: A new `RestoreResult` instance.
  /// Side effects: None.
  /// Notes: `wroteAnything` is false only when the restore failed before
  /// writing any data or image file, so local data is guaranteed untouched.
  /// `missingImages` counts v2 image references whose blob was absent.
  const RestoreResult({
    required this.ok,
    required this.wroteAnything,
    this.missingImages = 0,
  });
}

class BackupInfo {
  final File file;
  final DateTime date;
  final int sizeBytes;
  final bool corrupt;

  /// Purpose: Create a backup info instance.
  /// Inputs: `file`, `date`, `sizeBytes`, `corrupt`.
  /// Returns: A new `BackupInfo` instance.
  /// Side effects: None.
  /// Notes: `sizeBytes` includes referenced blob sizes for v2 bundles;
  /// `corrupt` marks bundles whose JSON could not be parsed.
  const BackupInfo({
    required this.file,
    required this.date,
    required this.sizeBytes,
    this.corrupt = false,
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
