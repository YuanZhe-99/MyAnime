import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../features/anime/services/anime_storage.dart';

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

  const SyncResult({
    required this.success,
    this.error,
  });
}

class WebDAVService {
  static const _configFileName = 'webdav_config.json';
  static const _dataFileNames = [
    'anime_data.json',
  ];

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

  // ── Last-write-wins file sync ──

  /// Sync data with WebDAV using last-write-wins strategy.
  static Future<SyncResult> sync(WebDAVConfig config) async {
    try {
      await _ensureRemoteDir(config);
      final appDir = await AnimeStorage.getAppDir();

      for (final name in _dataFileNames) {
        final localFile = File('${appDir.path}/$name');
        final localExists = await localFile.exists();
        final remoteRaw = await _download(config, name);

        if (!localExists && remoteRaw == null) continue;

        // Remote exists, local doesn't
        if (!localExists && remoteRaw != null) {
          await localFile.writeAsString(remoteRaw);
          continue;
        }

        final localRaw = await localFile.readAsString();

        // Local exists, remote doesn't
        if (localExists && remoteRaw == null) {
          await _upload(config, name, localRaw);
          continue;
        }

        // Both exist: LWW compare
        if (localRaw == remoteRaw) continue;

        final localTime = _extractModifiedAt(localRaw);
        final remoteTime = _extractModifiedAt(remoteRaw!);

        if (remoteTime != null &&
            (localTime == null || remoteTime.isAfter(localTime))) {
          // Remote wins
          await localFile.writeAsString(remoteRaw);
        } else {
          // Local wins
          await _upload(config, name, localRaw);
        }
      }

      // Sync images
      await _syncImages(config, appDir);

      return const SyncResult(success: true);
    } catch (e) {
      return SyncResult(success: false, error: e.toString());
    }
  }

  static DateTime? _extractModifiedAt(String json) {
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      DateTime? latest;
      for (final key in ['animes']) {
        final list = data[key] as List<dynamic>?;
        if (list == null) continue;
        for (final item in list) {
          if (item is Map<String, dynamic> &&
              item.containsKey('modifiedAt')) {
            final t = DateTime.tryParse(item['modifiedAt'] as String);
            if (t != null && (latest == null || t.isAfter(latest))) {
              latest = t;
            }
          }
        }
      }
      return latest;
    } catch (_) {
      return null;
    }
  }
}
