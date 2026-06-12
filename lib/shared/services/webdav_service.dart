import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../features/anime/models/anime.dart';
import '../../features/anime/services/anime_storage.dart';
import 'sync_merge.dart';

/// Persisted WebDAV configuration.
class WebDAVConfig {
  final String serverUrl;
  final String username;
  final String password;
  final String remotePath;
  final bool autoSync;

  /// Purpose: Create a web davconfig instance.
  /// Inputs: `serverUrl`, `username`, `password`, `remotePath`, `autoSync`.
  /// Returns: A new `WebDAVConfig` instance.
  /// Side effects: None.
  /// Notes: None.
  const WebDAVConfig({
    required this.serverUrl,
    required this.username,
    required this.password,
    this.remotePath = '/MyAnime',
    this.autoSync = false,
  });

  /// Purpose: Return whether configured is true.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get isConfigured =>
      serverUrl.isNotEmpty && username.isNotEmpty && password.isNotEmpty;

  /// Purpose: Create a copy with selected fields replaced.
  /// Inputs: None.
  /// Returns: `WebDAVConfig`.
  /// Side effects: None.
  /// Notes: None.
  WebDAVConfig copyWith({bool? autoSync}) => WebDAVConfig(
    serverUrl: serverUrl,
    username: username,
    password: password,
    remotePath: remotePath,
    autoSync: autoSync ?? this.autoSync,
  );

  /// Purpose: Serialize this value into a JSON-compatible map.
  /// Inputs: None.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: None.
  Map<String, dynamic> toJson() => {
    'serverUrl': serverUrl,
    'username': username,
    'password': password,
    'remotePath': remotePath,
    'autoSync': autoSync,
  };

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: `json`.
  /// Returns: A new `WebDAVConfig.fromJson` instance.
  /// Side effects: None.
  /// Notes: None.
  factory WebDAVConfig.fromJson(Map<String, dynamic> json) => WebDAVConfig(
    serverUrl: json['serverUrl'] as String? ?? '',
    username: json['username'] as String? ?? '',
    password: json['password'] as String? ?? '',
    remotePath: json['remotePath'] as String? ?? '/MyAnime',
    autoSync: json['autoSync'] as bool? ?? false,
  );

  /// Purpose: Create a web davconfig instance.
  /// Inputs: `host`, `username`, `password`.
  /// Returns: A new `WebDAVConfig.nextcloud` instance.
  /// Side effects: None.
  /// Notes: None.
  factory WebDAVConfig.nextcloud(
    String host,
    String username,
    String password,
  ) => WebDAVConfig(
    serverUrl: 'https://$host/remote.php/dav/files/$username',
    username: username,
    password: password,
  );
}

/// Result of a sync operation.
class SyncResult {
  final bool success;
  final String? error;
  final PendingSync? pending;

  /// Non-fatal warnings collected during sync (e.g. individual image failures).
  final List<String> warnings;

  /// Purpose: Create a sync result instance.
  /// Inputs: `success`, `error`, `pending`, `warnings`.
  /// Returns: A new `SyncResult` instance.
  /// Side effects: None.
  /// Notes: None.
  const SyncResult({
    required this.success,
    this.error,
    this.pending,
    this.warnings = const [],
  });

  /// Purpose: Return the current conflicts value.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get hasConflicts => pending != null;
}

/// Holds pending merge results that contain per-record conflicts.
class PendingSync {
  final AnimeMergeResult? animeMerge;

  /// Strong ETag of the remote anime file at download time, used as an
  /// `If-Match` precondition when uploading the resolved merge.
  final String? animeEtag;

  /// Purpose: Create a pending sync instance.
  /// Inputs: `animeMerge`, `animeEtag`.
  /// Returns: A new `PendingSync` instance.
  /// Side effects: None.
  /// Notes: None.
  const PendingSync({this.animeMerge, this.animeEtag});

  /// Purpose: Implement the all conflicts behavior for this file.
  /// Inputs: None.
  /// Returns: `List<RecordConflict<Anime>>`.
  /// Side effects: None.
  /// Notes: None.
  List<RecordConflict<Anime>> get allConflicts => [...?animeMerge?.conflicts];
}

/// Outcome status of a remote file download attempt.
enum RemoteFileStatus { found, notFound, error }

/// Discriminated result of a remote file download.
///
/// Distinguishes "the file does not exist on the remote" (HTTP 404) from
/// transport/server failures, because only a true 404 may trigger the
/// upload-local-as-new sync path. Treating errors as "missing" can overwrite
/// remote data and cascade into cross-device record deletion.
class RemoteFile {
  final RemoteFileStatus status;
  final String? content;
  final String? etag;
  final String? error;

  /// Purpose: Create a found result with downloaded content.
  /// Inputs: `content`, optional `etag` response header value.
  /// Returns: A new `RemoteFile` instance with `RemoteFileStatus.found`.
  /// Side effects: None.
  /// Notes: None.
  const RemoteFile.found(String this.content, {this.etag})
    : status = RemoteFileStatus.found,
      error = null;

  /// Purpose: Create a not-found result for HTTP 404.
  /// Inputs: None.
  /// Returns: A new `RemoteFile` instance with `RemoteFileStatus.notFound`.
  /// Side effects: None.
  /// Notes: None.
  const RemoteFile.notFound()
    : status = RemoteFileStatus.notFound,
      content = null,
      etag = null,
      error = null;

  /// Purpose: Create an error result for any non-404 failure.
  /// Inputs: `error` message.
  /// Returns: A new `RemoteFile` instance with `RemoteFileStatus.error`.
  /// Side effects: None.
  /// Notes: None.
  const RemoteFile.failure(String this.error)
    : status = RemoteFileStatus.error,
      content = null,
      etag = null;
}

class WebDAVService {
  static const _configFileName = 'webdav_config.json';
  static const _syncBaseDirName = '.sync_base';
  static const _dataFileNames = ['anime_data.json'];

  /// Global lock to prevent concurrent syncs.
  static bool _syncing = false;

  /// Whether the last sync wrote changes to local data files.
  static bool _localDataChanged = false;

  /// Purpose: Report whether the previous sync changed local files and clear that flag.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Call this after sync completion when callers need a one-shot change signal.
  static bool consumeLocalDataChanged() {
    final v = _localDataChanged;
    _localDataChanged = false;
    return v;
  }

  /// Purpose: Write a file atomically through a temporary file and rename step.
  /// Inputs: `file`, `content`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only; protects against mid-write app termination.
  static Future<void> _atomicWrite(File file, String content) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(content);
    await tmp.rename(file.path);
  }

  // ── Config persistence ──

  /// Purpose: Load config into the current workflow or state.
  /// Inputs: None.
  /// Returns: `Future<WebDAVConfig?>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<WebDAVConfig?> loadConfig() async {
    try {
      final dir = await AnimeStorage.getAppDir();
      final file = File('${dir.path}/$_configFileName');
      if (!await file.exists()) return null;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return WebDAVConfig.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Purpose: Save config to the relevant storage or service layer.
  /// Inputs: `config`.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<void> saveConfig(WebDAVConfig config) async {
    final dir = await AnimeStorage.getAppDir();
    final file = File('${dir.path}/$_configFileName');
    await file.writeAsString(jsonEncode(config.toJson()));
  }

  /// Purpose: Delete config from the relevant storage or state.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<void> deleteConfig() async {
    final dir = await AnimeStorage.getAppDir();
    final file = File('${dir.path}/$_configFileName');
    if (await file.exists()) await file.delete();
  }

  // ── Base (last-synced) file management ──

  /// Purpose: Provide the internal get base dir helper for this file.
  /// Inputs: None.
  /// Returns: `Future<Directory>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static Future<Directory> _getBaseDir() async {
    final appDir = await AnimeStorage.getAppDir();
    final dir = Directory('${appDir.path}/$_syncBaseDirName');
    if (!await dir.exists()) await dir.create();
    return dir;
  }

  /// Purpose: Provide the internal read base helper for this file.
  /// Inputs: `fileName`.
  /// Returns: `Future<String?>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static Future<String?> _readBase(String fileName) async {
    try {
      final dir = await _getBaseDir();
      final file = File('${dir.path}/$fileName');
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  /// Purpose: Provide the internal save base helper for this file.
  /// Inputs: `fileName`, `content`.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static Future<void> _saveBase(String fileName, String content) async {
    final dir = await _getBaseDir();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(content);
  }

  // ── HTTP helpers ──

  /// Purpose: Provide the internal auth headers helper for this file.
  /// Inputs: `config`.
  /// Returns: `Map<String, String>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static Map<String, String> _authHeaders(WebDAVConfig config) {
    final creds = base64Encode(
      utf8.encode('${config.username}:${config.password}'),
    );
    return {'Authorization': 'Basic $creds'};
  }

  /// Purpose: Provide the internal remote file url helper for this file.
  /// Inputs: `config`, `fileName`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static String _remoteFileUrl(WebDAVConfig config, String fileName) {
    final base = config.serverUrl.endsWith('/')
        ? config.serverUrl.substring(0, config.serverUrl.length - 1)
        : config.serverUrl;
    final path = config.remotePath.endsWith('/')
        ? config.remotePath
        : '${config.remotePath}/';
    return '$base$path$fileName';
  }

  /// Purpose: Test connection and report the outcome.
  /// Inputs: `config`.
  /// Returns: `Future<bool>`.
  /// Side effects: May perform network or file-system operations.
  /// Notes: None.
  static Future<bool> testConnection(WebDAVConfig config) async {
    try {
      final base = config.serverUrl.endsWith('/')
          ? config.serverUrl.substring(0, config.serverUrl.length - 1)
          : config.serverUrl;
      final url = Uri.parse('$base${config.remotePath}/');
      final request = http.Request('PROPFIND', url);
      request.headers.addAll(_authHeaders(config));
      request.headers['Depth'] = '0';
      request.headers['Content-Type'] = 'application/xml';
      request.body =
          '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>';

      final streamed = await http.Client()
          .send(request)
          .timeout(const Duration(seconds: 10));
      return streamed.statusCode == 207 || streamed.statusCode == 404;
    } catch (_) {
      return false;
    }
  }

  /// Purpose: Provide the internal ensure remote dir helper for this file.
  /// Inputs: `config`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static Future<void> _ensureRemoteDir(WebDAVConfig config) async {
    try {
      final base = config.serverUrl.endsWith('/')
          ? config.serverUrl.substring(0, config.serverUrl.length - 1)
          : config.serverUrl;
      final url = Uri.parse('$base${config.remotePath}/');
      final request = http.Request('MKCOL', url);
      request.headers.addAll(_authHeaders(config));
      await http.Client().send(request).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  /// Purpose: Provide the internal upload helper for this file.
  /// Inputs: `config`, `fileName`, `content`, optional `ifMatchEtag`, optional `ifNoneMatchAll`.
  /// Returns: `Future<String?>` — `null` on success, otherwise an error message.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only. When `ifMatchEtag` is set the PUT
  /// carries an `If-Match` precondition; `ifNoneMatchAll` sends `If-None-Match: *` so a
  /// first upload cannot overwrite a file created concurrently by another device.
  /// HTTP 412 means the remote changed during sync and the caller must re-sync.
  static Future<String?> _upload(
    WebDAVConfig config,
    String fileName,
    String content, {
    String? ifMatchEtag,
    bool ifNoneMatchAll = false,
  }) async {
    try {
      final url = Uri.parse(_remoteFileUrl(config, fileName));
      final response = await http
          .put(
            url,
            headers: {
              ..._authHeaders(config),
              'Content-Type': 'application/octet-stream',
              'If-Match': ?ifMatchEtag,
              if (ifNoneMatchAll) 'If-None-Match': '*',
            },
            body: utf8.encode(content),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 412) {
        return 'remote file changed during sync (HTTP 412); run sync again';
      }
      if (response.statusCode >= 200 && response.statusCode < 300) return null;
      return 'HTTP ${response.statusCode}';
    } catch (e) {
      return '$e';
    }
  }

  /// Purpose: Return [etag] only when it is a strong ETag usable in `If-Match`.
  /// Inputs: `etag` from a download response, possibly null or weak (`W/...`).
  /// Returns: `String?` — the strong ETag, or null when absent/weak.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Weak ETags must not be
  /// used in `If-Match` preconditions (RFC 9110 strong comparison).
  static String? _strongEtag(String? etag) {
    if (etag == null || etag.startsWith('W/')) return null;
    return etag;
  }

  /// Purpose: Provide the internal upload bytes helper for this file.
  /// Inputs: `config`, `fileName`, `bytes`.
  /// Returns: `Future<bool>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static Future<bool> _uploadBytes(
    WebDAVConfig config,
    String fileName,
    Uint8List bytes,
  ) async {
    final url = Uri.parse(_remoteFileUrl(config, fileName));
    final response = await http
        .put(
          url,
          headers: {
            ..._authHeaders(config),
            'Content-Type': 'application/octet-stream',
          },
          body: bytes,
        )
        .timeout(const Duration(seconds: 120));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}');
    }
    return true;
  }

  /// Purpose: Download a remote data file with a discriminated outcome.
  /// Inputs: `config`, `fileName`.
  /// Returns: `Future<RemoteFile>` — found with content/ETag, notFound for HTTP 404,
  /// or error for any other failure.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only. Callers must treat only
  /// `notFound` as "file missing on remote"; an `error` outcome (auth/server/network
  /// failure) must abort that file's sync so local data is never uploaded over an
  /// unreadable remote file.
  static Future<RemoteFile> _download(
    WebDAVConfig config,
    String fileName,
  ) async {
    try {
      final url = Uri.parse(_remoteFileUrl(config, fileName));
      final response = await http
          .get(url, headers: _authHeaders(config))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return RemoteFile.found(response.body, etag: response.headers['etag']);
      }
      if (response.statusCode == 404) return const RemoteFile.notFound();
      return RemoteFile.failure('HTTP ${response.statusCode}');
    } catch (e) {
      return RemoteFile.failure('$e');
    }
  }

  /// Purpose: Provide the internal download bytes helper for this file.
  /// Inputs: `config`, `fileName`.
  /// Returns: `Future<Uint8List?>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static Future<Uint8List?> _downloadBytes(
    WebDAVConfig config,
    String fileName,
  ) async {
    final url = Uri.parse(_remoteFileUrl(config, fileName));
    final response = await http
        .get(url, headers: _authHeaders(config))
        .timeout(const Duration(seconds: 120));
    if (response.statusCode == 200) return response.bodyBytes;
    throw Exception('HTTP ${response.statusCode}');
  }

  /// Purpose: List file names inside a remote subdirectory via PROPFIND.
  /// Inputs: `config`, `subPath`.
  /// Returns: `Future<List<String>>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. List file names inside a remote subdirectory via PROPFIND.
  static Future<List<String>> _listRemoteFiles(
    WebDAVConfig config,
    String subPath,
  ) async {
    try {
      final base = config.serverUrl.endsWith('/')
          ? config.serverUrl.substring(0, config.serverUrl.length - 1)
          : config.serverUrl;
      final remotePath = config.remotePath.endsWith('/')
          ? config.remotePath
          : '${config.remotePath}/';
      final url = Uri.parse('$base$remotePath$subPath/');
      final request = http.Request('PROPFIND', url);
      request.headers.addAll(_authHeaders(config));
      request.headers['Depth'] = '1';
      request.headers['Content-Type'] = 'application/xml';
      request.body =
          '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>';

      final streamed = await http.Client()
          .send(request)
          .timeout(const Duration(seconds: 15));
      if (streamed.statusCode != 207) return [];
      final body = await streamed.stream.bytesToString();
      // Extract href values and filter to files (not the directory itself)
      final hrefRegex = RegExp(
        r'<d:href>([^<]+)</d:href>',
        caseSensitive: false,
      );
      final names = <String>[];
      for (final match in hrefRegex.allMatches(body)) {
        final href = Uri.decodeFull(match.group(1)!);
        if (href.endsWith('/')) continue; // skip directories
        names.add(p.basename(href));
      }
      return names;
    } catch (_) {
      return [];
    }
  }

  // ── Image sync ──

  /// Purpose: Provide the internal ensure remote sub dir helper for this file.
  /// Inputs: `config`, `subPath`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static Future<void> _ensureRemoteSubDir(
    WebDAVConfig config,
    String subPath,
  ) async {
    try {
      final base = config.serverUrl.endsWith('/')
          ? config.serverUrl.substring(0, config.serverUrl.length - 1)
          : config.serverUrl;
      final remotePath = config.remotePath.endsWith('/')
          ? config.remotePath
          : '${config.remotePath}/';
      final url = Uri.parse('$base$remotePath$subPath/');
      final request = http.Request('MKCOL', url);
      request.headers.addAll(_authHeaders(config));
      await http.Client().send(request).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  /// Purpose: Extract basenames of cover images referenced by any anime in [json].
  /// Inputs: `json`.
  /// Returns: `Set<String>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Extract basenames of cover images referenced by any anime in [json].
  static Set<String> _getReferencedImageNames(String? json) {
    if (json == null) return {};
    try {
      final data = AnimeData.fromJson(jsonDecode(json) as Map<String, dynamic>);
      return data.animes
          .map((a) => a.coverImage)
          .whereType<String>()
          .map((path) => p.basename(path))
          .toSet();
    } catch (_) {
      return {};
    }
  }

  /// Purpose: Sync only images that are referenced by actual anime records.
  /// Inputs: `config`, `appDir`, `referencedImages`.
  /// Returns: `Future<List<String>>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only. Sync only images that are referenced by actual anime records. [referencedImages] is the union of basenames from local + remote anime data, so images from both sides are covered without syncing orphans. Returns a list of non-fatal error strings for individual transfer failures.
  static Future<List<String>> _syncImages(
    WebDAVConfig config,
    Directory appDir,
    Set<String> referencedImages,
  ) async {
    final errors = <String>[];
    if (referencedImages.isEmpty) return errors;

    final imgDir = Directory(p.join(appDir.path, 'images'));
    if (!await imgDir.exists()) {
      await imgDir.create(recursive: true);
    }

    await _ensureRemoteSubDir(config, 'images');

    // Collect local referenced images (skip orphans)
    final localNames = <String>{};
    await for (final entity in imgDir.list()) {
      if (entity is File) {
        final name = p.basename(entity.path);
        if (referencedImages.contains(name)) localNames.add(name);
      }
    }

    // List all remote file names (needed to avoid re-uploading existing files)
    final remoteNames = (await _listRemoteFiles(config, 'images')).toSet();

    // Upload local referenced images that are missing on remote
    for (final name in localNames) {
      if (!remoteNames.contains(name)) {
        try {
          final bytes = await File(p.join(imgDir.path, name)).readAsBytes();
          await _uploadBytes(config, 'images/$name', bytes);
        } on TimeoutException {
          errors.add('Upload timed out: $name');
        } catch (e) {
          errors.add('Upload failed for $name: $e');
        }
      }
    }

    // Download referenced remote images that are missing locally
    for (final name in referencedImages) {
      if (!localNames.contains(name) && remoteNames.contains(name)) {
        try {
          final bytes = await _downloadBytes(config, 'images/$name');
          if (bytes != null) {
            await File(p.join(imgDir.path, name)).writeAsBytes(bytes);
          }
        } on TimeoutException {
          errors.add('Download timed out: $name');
        } catch (e) {
          errors.add('Download failed for $name: $e');
        }
      }
    }

    return errors;
  }

  // ── Per-record merge sync ──

  /// Purpose: Sync data files with the remote server using per-record three-way merge.
  /// Inputs: `config`, `autoResolve`.
  /// Returns: `Future<SyncResult>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Sync data files with the remote server using per-record three-way merge. For each data file: - Reads local, remote, and base (last-synced) versions - Merges per-record using `modifiedAt` timestamps - Auto-resolves when only one side changed - Returns conflicts when both sides modified the same record When [autoResolve] is true, conflicts are resolved automatically using last-writer-wins per record. Used by auto-sync to prevent blocking.
  static Future<SyncResult> sync(
    WebDAVConfig config, {
    bool autoResolve = false,
  }) async {
    if (_syncing) {
      return const SyncResult(
        success: false,
        error: 'Sync already in progress',
      );
    }
    _syncing = true;
    try {
      await _ensureRemoteDir(config);
      final appDir = await AnimeStorage.getAppDir();

      AnimeMergeResult? pendingAnime;
      String? pendingAnimeEtag;
      // Track local/remote anime JSON to compute referenced image set.
      String? localAnimeJson;
      String? remoteAnimeJson;

      for (final name in _dataFileNames) {
        final localFile = File('${appDir.path}/$name');
        final localExists = await localFile.exists();
        final remote = await _download(config, name);

        // Any non-404 download failure aborts this file's sync; treating it
        // as "missing on remote" would overwrite remote data and can cascade
        // into cross-device record deletion on the next merge.
        if (remote.status == RemoteFileStatus.error) {
          return SyncResult(
            success: false,
            error: 'Failed to download $name from remote: ${remote.error}',
          );
        }
        final remoteRaw = remote.content;
        final remoteEtag = _strongEtag(remote.etag);

        if (!localExists && remoteRaw == null) continue;

        if (!localExists && remoteRaw != null) {
          // Only on remote → download
          await _atomicWrite(localFile, remoteRaw);
          await _saveBase(name, remoteRaw);
          _localDataChanged = true;
          if (name == 'anime_data.json') remoteAnimeJson = remoteRaw;
          continue;
        }

        final localRaw = await localFile.readAsString();
        if (name == 'anime_data.json') localAnimeJson = localRaw;

        if (localExists && remoteRaw == null) {
          // Only on local → upload as new; If-None-Match: * prevents
          // overwriting a file another device created concurrently.
          final uploadError = await _upload(
            config,
            name,
            localRaw,
            ifNoneMatchAll: true,
          );
          if (uploadError != null) {
            return SyncResult(
              success: false,
              error: 'Failed to upload $name to remote: $uploadError',
            );
          }
          await _saveBase(name, localRaw);
          continue;
        }

        if (name == 'anime_data.json') remoteAnimeJson = remoteRaw;

        // Both exist → per-record merge
        if (localRaw == remoteRaw) {
          await _saveBase(name, localRaw);
          continue;
        }

        final baseJson = await _readBase(name);

        switch (name) {
          case 'anime_data.json':
            var result = mergeAnimeData(
              localRaw,
              remoteRaw!,
              baseJson,
              autoResolve: autoResolve,
            );
            if (!result.hasConflicts) {
              // Re-read local to detect concurrent saves during network I/O.
              final freshLocalRaw = await localFile.readAsString();
              if (freshLocalRaw != localRaw) {
                result = mergeAnimeData(
                  freshLocalRaw,
                  remoteRaw,
                  baseJson,
                  autoResolve: autoResolve,
                );
                localAnimeJson = freshLocalRaw;
              }
            }
            if (result.hasConflicts) {
              pendingAnime = result;
              pendingAnimeEtag = remoteEtag;
            } else {
              final mergedData = AnimeData(
                animes: result.merged,
                extraJson: result.extraJson,
              );
              final mergedJson = jsonEncode(mergedData.toJson());
              await _atomicWrite(localFile, mergedJson);
              _localDataChanged = true;
              // If-Match guards against another device uploading between our
              // download and this upload (HTTP 412 → visible error, re-sync).
              final uploadError = await _upload(
                config,
                name,
                mergedJson,
                ifMatchEtag: remoteEtag,
              );
              if (uploadError != null) {
                return SyncResult(
                  success: false,
                  error: 'Failed to upload merged $name to remote: '
                      '$uploadError',
                );
              }
              await _saveBase(name, mergedJson);
              // Use the merged result for image reference computation.
              localAnimeJson = mergedJson;
            }
        }
      }

      // Sync only images referenced by actual anime records (local ∪ remote),
      // skipping orphaned images to avoid transferring stale/unused data.
      final referencedImages = {
        ..._getReferencedImageNames(localAnimeJson),
        ..._getReferencedImageNames(remoteAnimeJson),
      };
      final imageErrors = await _syncImages(config, appDir, referencedImages);

      if (pendingAnime != null) {
        return SyncResult(
          success: true,
          pending: PendingSync(
            animeMerge: pendingAnime,
            animeEtag: pendingAnimeEtag,
          ),
          warnings: imageErrors,
        );
      }

      return SyncResult(success: true, warnings: imageErrors);
    } catch (e, st) {
      return SyncResult(success: false, error: '$e\n$st');
    } finally {
      _syncing = false;
    }
  }

  /// Purpose: Finalize sync by applying user's conflict resolutions.
  /// Inputs: `config`, `pending`, `resolutions`.
  /// Returns: `Future<bool>` — false when applying or uploading the resolution fails.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Finalize sync by applying user's conflict resolutions. [resolutions] maps
  /// anime ID → the chosen Anime record. The base snapshot is only saved after a
  /// successful upload; an upload failure (including an If-Match HTTP 412 when the
  /// remote changed since download) returns false so the UI reports the failure.
  static Future<bool> finalizePendingSync(
    WebDAVConfig config,
    PendingSync pending,
    Map<String, Anime> resolutions,
  ) async {
    try {
      final appDir = await AnimeStorage.getAppDir();

      if (pending.animeMerge != null) {
        final mergedData = pending.animeMerge!.buildResolved(resolutions);
        final mergedJson = jsonEncode(mergedData.toJson());
        await _atomicWrite(File('${appDir.path}/anime_data.json'), mergedJson);
        _localDataChanged = true;
        final uploadError = await _upload(
          config,
          'anime_data.json',
          mergedJson,
          ifMatchEtag: pending.animeEtag,
        );
        if (uploadError != null) return false;
        await _saveBase('anime_data.json', mergedJson);
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
