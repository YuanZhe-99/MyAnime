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
import 'duplicate_service.dart';

class FileOpenService {
  static String? _pendingFile;
  static const _channel = MethodChannel('com.yuanzhe.my_anime/file_open');

  /// Purpose: Implement the init behavior for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: None.
  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openFile') {
        final path = call.arguments as String;
        final id = await handleFile(path);
        if (id != null) appRouter.go('/anime/detail/$id');
      }
    });
  }

  /// Purpose: Update pending file with the provided value.
  /// Inputs: `path`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: None.
  static void setPendingFile(String path) {
    _pendingFile = path;
  }

  /// Purpose: Implement the process pending file behavior for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: None.
  static Future<void> processPendingFile() async {
    if (_pendingFile != null) {
      final path = _pendingFile!;
      _pendingFile = null;
      final id = await handleFile(path);
      if (id != null) appRouter.go('/anime/detail/$id');
    }
  }

  /// Purpose: Implement the handle file behavior for this file.
  /// Inputs: `path`.
  /// Returns: `Future<String?>`.
  /// Side effects: None.
  /// Notes: Backward-compatible single-anime import. Always creates a new UUID
  /// and never overwrites an existing anime. For multi-anime bundles use
  /// [parseBundle] and [applyBundle] instead.
  static Future<String?> handleFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;

      final raw = await file.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['version'] == 1 && json['anime'] != null) {
        final anime = await _importOne(
          Anime.fromJson(json['anime'] as Map<String, dynamic>),
          json,
        );
        await AnimeStorage.addOrUpdate(anime);
        return anime.id;
      }
      // Multi-anime bundle: import all without conflict UI (file-association
      // cold start). Each record gets a fresh UUID so existing data is never
      // overwritten.
      if (json['version'] == 2 && json['items'] is List) {
        String? lastId;
        for (final item in json['items'] as List<dynamic>) {
          if (item is! Map<String, dynamic>) continue;
          final animeJson = item['anime'] as Map<String, dynamic>?;
          if (animeJson == null) continue;
          final anime = await _importOne(Anime.fromJson(animeJson), item);
          await AnimeStorage.addOrUpdate(anime);
          lastId = anime.id;
        }
        return lastId;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Purpose: Provide the internal import one helper for this file.
  /// Inputs: `parsed`, `itemJson`.
  /// Returns: `Future<Anime>`.
  /// Side effects: Writes cover images to the app images directory.
  /// Notes: Internal helper used within this file only. Always assigns a new
  /// UUID and current UTC timestamps so imports never overwrite existing data.
  static Future<Anime> _importOne(
    Anime parsed,
    Map<String, dynamic> itemJson,
  ) async {
    String? coverPath;
    if (itemJson['coverImage'] != null) {
      final ext = itemJson['coverImageExt'] as String? ?? '.jpg';
      final bytes = base64Decode(itemJson['coverImage'] as String);
      final appDir = await AnimeStorage.getAppDir();
      final imgDir = Directory(p.join(appDir.path, 'images'));
      if (!await imgDir.exists()) await imgDir.create(recursive: true);
      final newName = '${const Uuid().v4()}$ext';
      await File(p.join(imgDir.path, newName)).writeAsBytes(bytes);
      coverPath = 'images/$newName';
    }

    final now = DateTime.now().toUtc();
    return Anime(
      id: const Uuid().v4(),
      title: parsed.title,
      titleJa: parsed.titleJa,
      season: parsed.season,
      startEpisode: parsed.startEpisode,
      endEpisode: parsed.endEpisode,
      manualType: parsed.manualType,
      airDayOfWeek: parsed.airDayOfWeek,
      airTime: parsed.airTime,
      firstAirDate: parsed.firstAirDate,
      episodeStatuses: parsed.episodeStatuses,
      coverImage: coverPath ?? parsed.coverImage,
      infoUrl: parsed.infoUrl,
      watchUrl: parsed.watchUrl,
      episodeWeekOffsets: parsed.episodeWeekOffsets,
      notes: parsed.notes,
      rating: parsed.rating,
      createdAt: now,
      modifiedAt: now,
      extraJson: parsed.extraJson,
    );
  }

  /// Purpose: Parse a `.myanimeitem` file into a bundle without writing data.
  /// Inputs: `path`.
  /// Returns: `Future<ImportBundle?>`.
  /// Side effects: Writes embedded cover images to the app images directory.
  /// Notes: Returns null on parse failure. Assigns fresh UUIDs to every
  /// incoming record so applying them never overwrites existing data. Call
  /// [applyBundle] afterwards to persist the chosen records.
  static Future<ImportBundle?> parseBundle(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;

      final raw = await file.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;

      final parsed = <Anime>[];
      final itemJsons = <Map<String, dynamic>>[];

      if (json['version'] == 1 && json['anime'] != null) {
        itemJsons.add(json);
      } else if (json['version'] == 2 && json['items'] is List) {
        for (final item in json['items'] as List<dynamic>) {
          if (item is Map<String, dynamic>) itemJsons.add(item);
        }
      } else {
        return null;
      }

      for (final itemJson in itemJsons) {
        final animeJson = itemJson['anime'] as Map<String, dynamic>?;
        if (animeJson == null) continue;
        parsed.add(await _importOne(Anime.fromJson(animeJson), itemJson));
      }
      if (parsed.isEmpty) return null;

      // Detect conflicts against current local data.
      final local = await AnimeStorage.load();
      final localList = local.animes;
      final conflictIndices = <int>[];
      final localVersions = <int, Anime>{};
      for (var i = 0; i < parsed.length; i++) {
        final match = DuplicateService.findConflict(localList, parsed[i]);
        if (match != null) {
          conflictIndices.add(i);
          localVersions[i] = match;
        }
      }

      return ImportBundle(
        animes: parsed,
        conflictIndices: conflictIndices,
        localVersions: localVersions,
      );
    } catch (_) {
      return null;
    }
  }

  /// Purpose: Open a file picker and parse the selected .myanimeitem file.
  /// Inputs: None.
  /// Returns: `Future<ImportBundle?>`.
  /// Side effects: Shows file picker, writes embedded cover images to storage.
  /// Notes: Returns null when the user cancels or the file is invalid.
  static Future<ImportBundle?> pickAndParseBundle() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.single.path;
    if (path == null) return null;
    return parseBundle(path);
  }

  /// Purpose: Persist the chosen subset of a parsed bundle to storage.
  /// Inputs: `bundle`, `skipIndices`.
  /// Returns: `Future<int>`.
  /// Side effects: Writes anime records to storage.
  /// Notes: `skipIndices` are bundle indices to skip (e.g. conflicts the user
  /// chose to keep local for). Returns the number of records actually saved.
  static Future<int> applyBundle(
    ImportBundle bundle, {
    Set<int> skipIndices = const {},
  }) async {
    final data = await AnimeStorage.load();
    final list = List<Anime>.of(data.animes);
    var added = 0;
    for (var i = 0; i < bundle.animes.length; i++) {
      if (skipIndices.contains(i)) continue;
      list.add(bundle.animes[i]);
      added++;
    }
    await AnimeStorage.save(AnimeData(animes: list));
    return added;
  }

  /// Purpose: Replace a local anime with a merged or imported version.
  /// Inputs: `localId`, `replacement`.
  /// Returns: `Future<void>`.
  /// Side effects: Updates storage in place.
  /// Notes: Used by the import conflict flow when the user chooses to merge or
  /// use the imported version for an existing record.
  static Future<void> replaceAnime(String localId, Anime replacement) async {
    final data = await AnimeStorage.load();
    final list = List<Anime>.of(data.animes);
    final idx = list.indexWhere((a) => a.id == localId);
    if (idx >= 0) {
      list[idx] = replacement;
    } else {
      list.add(replacement);
    }
    await AnimeStorage.save(AnimeData(animes: list));
  }

  /// Purpose: Delete anime records by id from storage.
  /// Inputs: `ids`.
  /// Returns: `Future<void>`.
  /// Side effects: Removes records from storage.
  /// Notes: Used by the duplicate-resolution flow when the user merges records
  /// and the redundant copies must be removed.
  static Future<void> deleteAnimeByIds(Iterable<String> ids) async {
    final idSet = ids.toSet();
    final data = await AnimeStorage.load();
    final list = data.animes.where((a) => !idSet.contains(a.id)).toList();
    await AnimeStorage.save(AnimeData(animes: list));
  }

  /// Purpose: Open a file picker for the user to select a .myanimeitem file,.
  /// Inputs: None.
  /// Returns: `Future<String?>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: then import it. Returns the imported anime ID, or null on failure/cancel.
  static Future<String?> importFromPicker() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.single.path;
    if (path == null) return null;
    return handleFile(path);
  }

  /// Purpose: Export an anime to a .myanimeitem JSON file.
  /// Inputs: `anime`.
  /// Returns: `Future<String?>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Export an anime to a .myanimeitem JSON file. Returns the file path, or null on failure. Personal data (episodeStatuses, episodeWeekOffsets) is stripped.
  static Future<String?> exportAnimeItem(Anime anime) async {
    final animeJson = _stripPersonalData(anime.toJson());
    final json = <String, dynamic>{
      'version': 1,
      'anime': animeJson,
      'coverImage': await _readCoverBase64(anime),
    };
    if (anime.coverImage != null) {
      json['coverImageExt'] = p.extension(anime.coverImage!);
    }

    return _writeBundleFile(
      _sanitizeFileName(anime.displayTitle),
      json,
    );
  }

  /// Purpose: Export a collection of anime to a multi-anime .myanimeitem file.
  /// Inputs: `animes`, `displayName`.
  /// Returns: `Future<String?>`.
  /// Side effects: Writes a temporary `.myanimeitem` file.
  /// Notes: Returns the file path, or null on failure. Uses bundle version 2
  /// so single-anime v1 files remain backward compatible. Personal viewing
  /// data (episodeStatuses, episodeWeekOffsets) is stripped from each record.
  static Future<String?> exportAnimeBundle(
    List<Anime> animes, {
    String displayName = 'myanime_collection',
  }) async {
    final items = <Map<String, dynamic>>[];
    for (final anime in animes) {
      final animeJson = _stripPersonalData(anime.toJson());
      final item = <String, dynamic>{
        'anime': animeJson,
        'coverImage': await _readCoverBase64(anime),
      };
      if (anime.coverImage != null) {
        item['coverImageExt'] = p.extension(anime.coverImage!);
      }
      items.add(item);
    }

    final json = <String, dynamic>{
      'version': 2,
      'items': items,
    };
    return _writeBundleFile(_sanitizeFileName(displayName), json);
  }

  /// Purpose: Provide the internal strip personal data helper for this file.
  /// Inputs: `json`.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Removes personal
  /// viewing data so shared bundles do not leak the sender's watch progress.
  static Map<String, dynamic> _stripPersonalData(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);
    copy.remove('episodeStatuses');
    copy.remove('episodeWeekOffsets');
    return copy;
  }

  /// Purpose: Provide the internal read cover base64 helper for this file.
  /// Inputs: `anime`.
  /// Returns: `Future<String?>`.
  /// Side effects: Reads cover image files from storage.
  /// Notes: Internal helper used within this file only. Returns null when the
  /// cover image is missing or unreadable.
  static Future<String?> _readCoverBase64(Anime anime) async {
    if (anime.coverImage == null) return null;
    try {
      final appDir = await AnimeStorage.getAppDir();
      final coverFile = File(p.join(appDir.path, anime.coverImage!));
      if (await coverFile.exists()) {
        final bytes = await coverFile.readAsBytes();
        return base64Encode(bytes);
      }
    } catch (_) {}
    return null;
  }

  /// Purpose: Provide the internal write bundle file helper for this file.
  /// Inputs: `safeName`, `json`.
  /// Returns: `Future<String?>`.
  /// Side effects: Writes a temporary `.myanimeitem` file.
  /// Notes: Internal helper used within this file only.
  static Future<String?> _writeBundleFile(
    String safeName,
    Map<String, dynamic> json,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final filePath = p.join(tempDir.path, '$safeName.myanimeitem');
    await File(
      filePath,
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(json));
    return filePath;
  }

  /// Purpose: Sanitize a string for use as a filename.
  /// Inputs: `name`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Sanitize a string for use as a filename. Removes characters illegal on Windows/macOS/Linux filesystems, keeps CJK, accented, and other Unicode letters.
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
