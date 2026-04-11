import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
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
        await handleFile(path);
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
      await handleFile(path);
    }
  }

  static Future<void> handleFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return;

      final raw = await file.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['version'] != 1 || json['anime'] == null) return;

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
      appRouter.go('/anime/detail/${imported.id}');
    } catch (_) {
      // Silently fail — file might be corrupted or wrong format
    }
  }

  /// Export an anime to a .myanimeitem JSON file.
  /// Returns the file path, or null on failure.
  static Future<String?> exportAnimeItem(Anime anime) async {
    final json = <String, dynamic>{
      'version': 1,
      'anime': anime.toJson(),
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

    final tempDir = await Directory.systemTemp.createTemp('myanimeitem');
    final safeName = anime.displayTitle.replaceAll(RegExp(r'[^\w\s\-]'), '');
    final filePath =
        p.join(tempDir.path, '${safeName.trim()}.myanimeitem');
    await File(filePath)
        .writeAsString(const JsonEncoder.withIndent('  ').convert(json));
    return filePath;
  }
}
