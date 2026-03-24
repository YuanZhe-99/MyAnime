import 'dart:io';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../features/anime/services/anime_storage.dart';

class ImportExportService {
  /// Export all anime data as a ZIP file containing anime_data.json and images/.
  /// Returns the exported file path, or null on failure.
  static Future<String?> exportZIP(String destDir) async {
    try {
      final appDir = await AnimeStorage.getAppDir();
      final archive = Archive();

      final dataFile = File(p.join(appDir.path, 'anime_data.json'));
      if (await dataFile.exists()) {
        final bytes = await dataFile.readAsBytes();
        archive.addFile(ArchiveFile('anime_data.json', bytes.length, bytes));
      }

      // Include images
      final imgDir = Directory(p.join(appDir.path, 'images'));
      if (await imgDir.exists()) {
        await for (final entity in imgDir.list()) {
          if (entity is File) {
            final bytes = await entity.readAsBytes();
            final name = 'images/${p.basename(entity.path)}';
            archive.addFile(ArchiveFile(name, bytes.length, bytes));
          }
        }
      }

      final zipData = ZipEncoder().encode(archive);

      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final outFile = File(p.join(destDir, 'myanime_export_$stamp.zip'));
      await outFile.writeAsBytes(zipData);
      return outFile.path;
    } catch (_) {
      return null;
    }
  }

  /// Import data from a previously exported ZIP file.
  /// Returns true on success.
  static Future<bool> importZIP(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final appDir = await AnimeStorage.getAppDir();

      for (final entry in archive) {
        if (entry.isFile) {
          // Prevent path traversal attacks
          final normalized = p.normalize(entry.name);
          if (p.isAbsolute(normalized) || normalized.startsWith('..')) continue;

          final outPath = p.join(appDir.path, normalized);
          // Ensure parent directory exists
          final parent = Directory(p.dirname(outPath));
          if (!await parent.exists()) {
            await parent.create(recursive: true);
          }
          final outFile = File(outPath);
          await outFile.writeAsBytes(entry.content as List<int>);
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
