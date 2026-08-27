/// Purpose: Read and write `metadata_updates.json`, the device-local cache of
/// background metadata work and downloaded update candidates.
/// Inputs: `MetadataUpdateStore` documents and prefetched cover bytes.
/// Returns: Store load/save plus cover cache helpers.
/// Side effects: File I/O under the app data directory, and one HTTP request
/// per prefetched cover.
/// Notes: This file is deliberately **not** registered in
/// `lib/app/data_modules.dart`, which is what keeps it out of both sync and
/// backup — the sync and backup engines only ever touch the file names in the
/// module registry plus `images/`. It still lives under
/// `AnimeStorage.getAppDir()`, so a storage-path change carries it along.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/metadata_update.dart';
import 'anime_storage.dart';

class MetadataCache {
  /// Purpose: Prevent direct instantiation and expose only static members.
  /// Inputs: None.
  /// Returns: A new `MetadataCache._` instance.
  /// Side effects: None.
  /// Notes: None.
  const MetadataCache._();

  /// Name of the local-only cache document. Not a sync module.
  static const fileName = 'metadata_updates.json';

  /// Directory holding prefetched cover images, when that option is enabled.
  static const coverDirName = 'metadata_covers';

  /// Purpose: Resolve the cache file inside the active storage directory.
  /// Inputs: None.
  /// Returns: `Future<File>`.
  /// Side effects: May create the app directory via the storage hub.
  /// Notes: Internal helper used within this file only.
  static Future<File> _file() async {
    final dir = await AnimeStorage.getAppDir();
    return File(p.join(dir.path, fileName));
  }

  /// Purpose: Write a file atomically through a temporary file and rename step.
  /// Inputs: `file`, `content`.
  /// Returns: None.
  /// Side effects: Writes a temp file and renames it over the target path.
  /// Notes: Internal helper used within this file only. Mirrors
  /// `AnimeStorage._atomicWrite` so a kill mid-write cannot leave a truncated
  /// cache behind; the cache is rebuildable, but a corrupt file would still
  /// cost a full re-scan.
  static Future<void> _atomicWrite(File file, String content) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(content, flush: true);
    await tmp.rename(file.path);
  }

  /// Purpose: Load the local update cache.
  /// Inputs: None.
  /// Returns: `Future<MetadataUpdateStore>` — empty when absent or unreadable.
  /// Side effects: Reads local storage.
  /// Notes: A parse failure yields an empty store rather than throwing. This is
  /// a rebuildable cache: losing it costs network work, never user data, so
  /// degrading quietly beats blocking startup.
  static Future<MetadataUpdateStore> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const MetadataUpdateStore();
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return const MetadataUpdateStore();
      return MetadataUpdateStore.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const MetadataUpdateStore();
    }
  }

  /// Purpose: Persist the local update cache.
  /// Inputs: `store`.
  /// Returns: None.
  /// Side effects: Writes the cache file atomically.
  /// Notes: Pretty-printed like every other file this app writes. Deliberately
  /// does **not** call `AutoSyncService.notifySaved()` — this file never syncs,
  /// so scheduling an upload for it would be pure churn.
  static Future<void> save(MetadataUpdateStore store) async {
    final file = await _file();
    await _atomicWrite(
      file,
      const JsonEncoder.withIndent('  ').convert(store.toJson()),
    );
  }

  // ── Cover prefetch ──

  /// Purpose: Resolve the prefetched-cover directory, creating it on demand.
  /// Inputs: None.
  /// Returns: `Future<Directory>`.
  /// Side effects: May create the directory.
  /// Notes: Internal helper used within this file only.
  static Future<Directory> _coverDir() async {
    final appDir = await AnimeStorage.getAppDir();
    final dir = Directory(p.join(appDir.path, coverDirName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Purpose: Download a candidate's cover into the local prefetch cache.
  /// Inputs: `animeId`, `url`.
  /// Returns: `Future<String?>` — the path relative to the app directory, or
  /// `null` when the download failed.
  /// Side effects: One HTTP GET, and one file write.
  /// Notes: Only called when the user enabled cover prefetch, which is off by
  /// default because covers are the only large data in this cache. Failure is
  /// silent: the review UI falls back to loading the source URL directly.
  static Future<String?> prefetchCover(String animeId, String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;
      final dir = await _coverDir();
      var ext = p.extension(Uri.parse(url).path);
      if (ext.isEmpty || ext.length > 5) ext = '.jpg';
      final file = File(p.join(dir.path, '$animeId$ext'));
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return '$coverDirName/${p.basename(file.path)}';
    } catch (_) {
      return null;
    }
  }

  /// Purpose: Delete one prefetched cover once its proposal is resolved.
  /// Inputs: `relativePath`.
  /// Returns: None.
  /// Side effects: Deletes a file when it exists.
  /// Notes: Called after a proposal is applied or dismissed so the prefetch
  /// cache cannot grow without bound. Missing files are ignored.
  static Future<void> deleteCover(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return;
    try {
      final appDir = await AnimeStorage.getAppDir();
      final file = File(p.join(appDir.path, relativePath));
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Purpose: Remove prefetched covers no longer referenced by any entry.
  /// Inputs: `store`.
  /// Returns: None.
  /// Side effects: Deletes unreferenced files in the cover cache directory.
  /// Notes: Runs after a prune so covers belonging to deleted anime go away
  /// too. Any failure is ignored — this is opportunistic cleanup.
  static Future<void> pruneCovers(MetadataUpdateStore store) async {
    try {
      final dir = await _coverDir();
      final referenced = <String>{
        for (final entry in store.entries)
          if (entry.coverCachePath != null) p.basename(entry.coverCachePath!),
      };
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        if (!referenced.contains(p.basename(entity.path))) {
          await entity.delete();
        }
      }
    } catch (_) {}
  }
}
