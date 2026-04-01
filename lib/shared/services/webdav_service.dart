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

  const WebDAVConfig({
    required this.serverUrl,
    required this.username,
    required this.password,
    this.remotePath = '/MyAnime',
    this.autoSync = false,
  });

  bool get isConfigured =>
      serverUrl.isNotEmpty && username.isNotEmpty && password.isNotEmpty;

  WebDAVConfig copyWith({bool? autoSync}) => WebDAVConfig(
        serverUrl: serverUrl,
        username: username,
        password: password,
        remotePath: remotePath,
        autoSync: autoSync ?? this.autoSync,
      );

  Map<String, dynamic> toJson() => {
        'serverUrl': serverUrl,
        'username': username,
        'password': password,
        'remotePath': remotePath,
        'autoSync': autoSync,
      };

  factory WebDAVConfig.fromJson(Map<String, dynamic> json) => WebDAVConfig(
        serverUrl: json['serverUrl'] as String? ?? '',
        username: json['username'] as String? ?? '',
        password: json['password'] as String? ?? '',
        remotePath: json['remotePath'] as String? ?? '/MyAnime',
        autoSync: json['autoSync'] as bool? ?? false,
      );

  factory WebDAVConfig.nextcloud(
          String host, String username, String password) =>
      WebDAVConfig(
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

  const SyncResult({
    required this.success,
    this.error,
    this.pending,
  });

  bool get hasConflicts => pending != null;
}

/// Holds pending merge results that contain per-record conflicts.
class PendingSync {
  final AnimeMergeResult? animeMerge;

  const PendingSync({this.animeMerge});

  List<RecordConflict<Anime>> get allConflicts => [
        ...?animeMerge?.conflicts,
      ];
}

class WebDAVService {
  static const _configFileName = 'webdav_config.json';
  static const _syncBaseDirName = '.sync_base';
  static const _dataFileNames = [
    'anime_data.json',
  ];

  /// Global lock to prevent concurrent syncs.
  static bool _syncing = false;

  // ── Config persistence ──

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

  static Future<void> saveConfig(WebDAVConfig config) async {
    final dir = await AnimeStorage.getAppDir();
    final file = File('${dir.path}/$_configFileName');
    await file.writeAsString(jsonEncode(config.toJson()));
  }

  static Future<void> deleteConfig() async {
    final dir = await AnimeStorage.getAppDir();
    final file = File('${dir.path}/$_configFileName');
    if (await file.exists()) await file.delete();
  }

  // ── Base (last-synced) file management ──

  static Future<Directory> _getBaseDir() async {
    final appDir = await AnimeStorage.getAppDir();
    final dir = Directory('${appDir.path}/$_syncBaseDirName');
    if (!await dir.exists()) await dir.create();
    return dir;
  }

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

  static Future<void> _saveBase(String fileName, String content) async {
    final dir = await _getBaseDir();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(content);
  }

  // ── HTTP helpers ──

  static Map<String, String> _authHeaders(WebDAVConfig config) {
    final creds =
        base64Encode(utf8.encode('${config.username}:${config.password}'));
    return {'Authorization': 'Basic $creds'};
  }

  static String _remoteFileUrl(WebDAVConfig config, String fileName) {
    final base = config.serverUrl.endsWith('/')
        ? config.serverUrl.substring(0, config.serverUrl.length - 1)
        : config.serverUrl;
    final path = config.remotePath.endsWith('/')
        ? config.remotePath
        : '${config.remotePath}/';
    return '$base$path$fileName';
  }

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

  static Future<bool> _upload(
      WebDAVConfig config, String fileName, String content) async {
    try {
      final url = Uri.parse(_remoteFileUrl(config, fileName));
      final response = await http
          .put(
            url,
            headers: {
              ..._authHeaders(config),
              'Content-Type': 'application/octet-stream',
            },
            body: utf8.encode(content),
          )
          .timeout(const Duration(seconds: 30));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _uploadBytes(
      WebDAVConfig config, String fileName, Uint8List bytes) async {
    try {
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
          .timeout(const Duration(seconds: 60));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> _download(
      WebDAVConfig config, String fileName) async {
    try {
      final url = Uri.parse(_remoteFileUrl(config, fileName));
      final response = await http
          .get(url, headers: _authHeaders(config))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) return response.body;
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> _downloadBytes(
      WebDAVConfig config, String fileName) async {
    try {
      final url = Uri.parse(_remoteFileUrl(config, fileName));
      final response = await http
          .get(url, headers: _authHeaders(config))
          .timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) return response.bodyBytes;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// List file names inside a remote subdirectory via PROPFIND.
  static Future<List<String>> _listRemoteFiles(
      WebDAVConfig config, String subPath) async {
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
      final hrefRegex = RegExp(r'<d:href>([^<]+)</d:href>', caseSensitive: false);
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

  static Future<void> _ensureRemoteSubDir(
      WebDAVConfig config, String subPath) async {
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

  static Future<void> _syncImages(
      WebDAVConfig config, Directory appDir) async {
    final imgDir = Directory(p.join(appDir.path, 'images'));
    if (!await imgDir.exists()) {
      await imgDir.create(recursive: true);
    }

    await _ensureRemoteSubDir(config, 'images');

    // Collect local file names
    final localNames = <String>{};
    await for (final entity in imgDir.list()) {
      if (entity is File) {
        localNames.add(p.basename(entity.path));
      }
    }

    // List remote file names
    final remoteNames = (await _listRemoteFiles(config, 'images')).toSet();

    // Upload local-only images
    for (final name in localNames) {
      if (!remoteNames.contains(name)) {
        final bytes = await File(p.join(imgDir.path, name)).readAsBytes();
        await _uploadBytes(config, 'images/$name', bytes);
      }
    }

    // Download remote-only images
    for (final name in remoteNames) {
      if (!localNames.contains(name)) {
        final bytes = await _downloadBytes(config, 'images/$name');
        if (bytes != null) {
          await File(p.join(imgDir.path, name)).writeAsBytes(bytes);
        }
      }
    }
  }

  // ── Per-record merge sync ──

  /// Sync data files with the remote server using per-record three-way merge.
  ///
  /// For each data file:
  /// - Reads local, remote, and base (last-synced) versions
  /// - Merges per-record using `modifiedAt` timestamps
  /// - Auto-resolves when only one side changed
  /// - Returns conflicts when both sides modified the same record
  ///
  /// When [autoResolve] is true, conflicts are resolved automatically using
  /// last-writer-wins per record. Used by auto-sync to prevent blocking.
  static Future<SyncResult> sync(WebDAVConfig config,
      {bool autoResolve = false}) async {
    if (_syncing) {
      return const SyncResult(
          success: false, error: 'Sync already in progress');
    }
    _syncing = true;
    try {
      await _ensureRemoteDir(config);
      final appDir = await AnimeStorage.getAppDir();

      AnimeMergeResult? pendingAnime;

      for (final name in _dataFileNames) {
        final localFile = File('${appDir.path}/$name');
        final localExists = await localFile.exists();
        final remoteRaw = await _download(config, name);

        if (!localExists && remoteRaw == null) continue;

        if (!localExists && remoteRaw != null) {
          // Only on remote → download
          await localFile.writeAsString(remoteRaw);
          await _saveBase(name, remoteRaw);
          continue;
        }

        final localRaw = await localFile.readAsString();

        if (localExists && remoteRaw == null) {
          // Only on local → upload
          await _upload(config, name, localRaw);
          await _saveBase(name, localRaw);
          continue;
        }

        // Both exist → per-record merge
        if (localRaw == remoteRaw) {
          await _saveBase(name, localRaw);
          continue;
        }

        final baseJson = await _readBase(name);

        switch (name) {
          case 'anime_data.json':
            final result = mergeAnimeData(
              localRaw,
              remoteRaw!,
              baseJson,
              autoResolve: autoResolve,
            );
            if (result.hasConflicts) {
              pendingAnime = result;
            } else {
              final mergedData =
                  AnimeData(animes: result.merged);
              final mergedJson = jsonEncode(mergedData.toJson());
              await localFile.writeAsString(mergedJson);
              await _upload(config, name, mergedJson);
              await _saveBase(name, mergedJson);
            }
        }
      }

      // Sync images (additive, no conflict)
      await _syncImages(config, appDir);

      if (pendingAnime != null) {
        return SyncResult(
          success: true,
          pending: PendingSync(animeMerge: pendingAnime),
        );
      }

      return const SyncResult(success: true);
    } catch (e) {
      return SyncResult(success: false, error: e.toString());
    } finally {
      _syncing = false;
    }
  }

  /// Finalize sync by applying user's conflict resolutions.
  ///
  /// [resolutions] maps anime ID → the chosen Anime record.
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
        await File('${appDir.path}/anime_data.json')
            .writeAsString(mergedJson);
        await _upload(config, 'anime_data.json', mergedJson);
        await _saveBase('anime_data.json', mergedJson);
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
