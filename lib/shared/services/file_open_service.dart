import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../app/router.dart';
import '../../features/anime/models/anime.dart';
import '../../features/anime/services/anime_storage.dart';

class FileOpenService {
  static String? _pendingFile;
  static const _channel = MethodChannel('com.yuanzhe.my_anime/file_open');

  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openFile') {
        final path = call.arguments as String;
        final id = await handleFile(path);
        if (id != null) appRouter.go('/anime/detail/$id');
      }
    });
  }

  static void setPendingFile(String path) {
    _pendingFile = path;
  }

  static Future<void> processPendingFile() async {
    if (_pendingFile != null) {
      final path = _pendingFile!;
      _pendingFile = null;
      final id = await handleFile(path);
      if (id != null) appRouter.go('/anime/detail/$id');
    }
  }

  static Future<String?> handleFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;

      final raw = await file.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['version'] != 1 || json['anime'] == null) return null;

      final anime = Anime.fromJson(json['anime'] as Map<String, dynamic>);

      // Save cover image if present
      String? coverPath;
      if (json['coverImage'] != null) {
        final ext = json['coverImageExt'] as String? ?? '.jpg';
        final bytes = base64Decode(json['coverImage'] as String);
        final appDir = await AnimeStorage.getAppDir();
        final imgDir = Directory(p.join(appDir.path, 'images'));
        if (!await imgDir.exists()) await imgDir.create(recursive: true);
        final newName = '${const Uuid().v4()}$ext';
        await File(p.join(imgDir.path, newName)).writeAsBytes(bytes);
        coverPath = 'images/$newName';
      }

      // Always create with a new ID to avoid overwriting existing anime
      final now = DateTime.now().toUtc();
      final imported = Anime(
        id: const Uuid().v4(),
        title: anime.title,
        titleJa: anime.titleJa,
        season: anime.season,
        startEpisode: anime.startEpisode,
        endEpisode: anime.endEpisode,
        manualType: anime.manualType,
        airDayOfWeek: anime.airDayOfWeek,
        airTime: anime.airTime,
        firstAirDate: anime.firstAirDate,
        episodeStatuses: anime.episodeStatuses,
        coverImage: coverPath ?? anime.coverImage,
        infoUrl: anime.infoUrl,
        watchUrl: anime.watchUrl,
        episodeWeekOffsets: anime.episodeWeekOffsets,
        notes: anime.notes,
        createdAt: now,
        modifiedAt: now,
      );

      await AnimeStorage.addOrUpdate(imported);
      return imported.id;
    } catch (_) {
      return null;
    }
  }

  /// Open a file picker for the user to select a .myanimeitem file,
  /// then import it. Returns the imported anime ID, or null on failure/cancel.
  static Future<String?> importFromPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.single.path;
    if (path == null) return null;
    return handleFile(path);
  }

  /// Export an anime to a .myanimeitem JSON file.
  /// Returns the file path, or null on failure.
  /// Personal data (episodeStatuses, episodeWeekOffsets) is stripped.
  static Future<String?> exportAnimeItem(Anime anime) async {
    final animeJson = anime.toJson();
    animeJson.remove('episodeStatuses');
    animeJson.remove('episodeWeekOffsets');
    final json = <String, dynamic>{
      'version': 1,
      'anime': animeJson,
    };

    // Embed cover image as base64
    if (anime.coverImage != null) {
      try {
        final appDir = await AnimeStorage.getAppDir();
        final coverFile = File(p.join(appDir.path, anime.coverImage!));
        if (await coverFile.exists()) {
          final bytes = await coverFile.readAsBytes();
          json['coverImage'] = base64Encode(bytes);
          json['coverImageExt'] = p.extension(anime.coverImage!);
        }
      } catch (_) {}
    }

    final tempDir = await getTemporaryDirectory();
    final safeName = _sanitizeFileName(anime.displayTitle);
    final filePath =
        p.join(tempDir.path, '$safeName.myanimeitem');
    await File(filePath)
        .writeAsString(const JsonEncoder.withIndent('  ').convert(json));
    return filePath;
  }

  /// Sanitize a string for use as a filename.
  /// Removes characters illegal on Windows/macOS/Linux filesystems,
  /// keeps CJK, accented, and other Unicode letters.
  static String _sanitizeFileName(String name) {
    // Remove characters illegal in filenames: / \ : * ? " < > |
    // Also remove control characters.
    var safe = name.replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1F]'), '');
    safe = safe.trim();
    if (safe.isEmpty) safe = 'anime';
    // Limit length to avoid filesystem issues
    if (safe.length > 100) safe = safe.substring(0, 100);
    return safe;
  }
}
