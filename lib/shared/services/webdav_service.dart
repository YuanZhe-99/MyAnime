import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:flutter/foundation.dart';

import '../../features/anime/models/anime.dart';
import '../../features/anime/services/anime_storage.dart';
import 'sync_merge.dart';
import 'sync_progress.dart';

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

  /// Purpose: Create a pending sync instance.
  /// Inputs: `animeMerge`.
  /// Returns: A new `PendingSync` instance.
  /// Side effects: None.
  /// Notes: None.
  const PendingSync({this.animeMerge});

  /// Purpose: Implement the all conflicts behavior for this file.
  /// Inputs: None.
  /// Returns: `List<RecordConflict<Anime>>`.
  /// Side effects: None.
  /// Notes: None.
  List<RecordConflict<Anime>> get allConflicts => [...?animeMerge?.conflicts];
}

/// A WebDAV upload lock stored in the remote `.lock` file.
class WebDAVUploadLock {
  final String clientId;
  final String token;
  final DateTime startedAt;
  final DateTime updatedAt;
  final int ttlSeconds;

  /// Purpose: Create a WebDAV upload lock value.
  /// Inputs: `clientId`, `token`, `startedAt`, `updatedAt`, `ttlSeconds`.
  /// Returns: A new `WebDAVUploadLock` instance.
  /// Side effects: None.
  /// Notes: Times are stored in UTC and compared against [ttlSeconds].
  const WebDAVUploadLock({
    required this.clientId,
    required this.token,
    required this.startedAt,
    required this.updatedAt,
    required this.ttlSeconds,
  });

  /// Purpose: Parse a WebDAV upload lock from JSON.
  /// Inputs: `json`.
  /// Returns: A parsed `WebDAVUploadLock`.
  /// Side effects: None.
  /// Notes: Throws when required fields are missing or malformed.
  factory WebDAVUploadLock.fromJson(Map<String, dynamic> json) {
    return WebDAVUploadLock(
      clientId: json['clientId'] as String,
      token: json['token'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      ttlSeconds:
          json['ttlSeconds'] as int? ?? WebDAVService._lockTtlSeconds,
    );
  }

  /// Purpose: Serialize this lock to the remote `.lock` JSON format.
  /// Inputs: None.
  /// Returns: JSON-compatible map.
  /// Side effects: None.
  /// Notes: None.
  Map<String, dynamic> toJson() => {
    'clientId': clientId,
    'token': token,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'ttlSeconds': ttlSeconds,
  };

  /// Purpose: Return whether this lock is expired at [now].
  /// Inputs: `now`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Expired locks are treated as failed uploads and may be replaced.
  bool isExpired(DateTime now) =>
      now.toUtc().difference(updatedAt.toUtc()).inSeconds >= ttlSeconds;

  /// Purpose: Return whether this lock belongs to the given session.
  /// Inputs: `clientId`, `token`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Used before refreshing or deleting remote locks.
  bool matches(String clientId, String token) =>
      this.clientId == clientId && this.token == token;

  /// Purpose: Create a refreshed copy of this lock.
  /// Inputs: `updatedAt`.
  /// Returns: `WebDAVUploadLock`.
  /// Side effects: None.
  /// Notes: Keeps the original token and started time.
  WebDAVUploadLock refreshed(DateTime updatedAt) => WebDAVUploadLock(
    clientId: clientId,
    token: token,
    startedAt: startedAt,
    updatedAt: updatedAt.toUtc(),
    ttlSeconds: ttlSeconds,
  );
}

/// Local state for the upload lock currently held by this process.
class _UploadSession {
  final String clientId;
  final String token;

  /// Purpose: Create an upload session marker.
  /// Inputs: `clientId`, `token`.
  /// Returns: A new `_UploadSession` instance.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  const _UploadSession({required this.clientId, required this.token});
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
  static const _lockFileName = '.lock';
  static const _clientIdFileName = 'client_id.txt';
  static const _localLockFileName = 'upload_lock.json';
  static const _lockTtlSeconds = 60;

  /// Global lock to prevent concurrent syncs.
  static bool _syncing = false;

  /// Whether the last sync wrote changes to local data files.
  static bool _localDataChanged = false;

  /// Live progress of the currently running sync/force operation.
  ///
  /// UI pages bind with `ValueListenableBuilder<SyncProgress>`; the service
  /// reports raw phases/counts only and the UI localizes the phase text.
  static final ValueNotifier<SyncProgress> progress = ValueNotifier(
    SyncProgress.idle,
  );

  /// Purpose: Publish a progress snapshot for the running sync operation.
  /// Inputs: `phase`, optional `detail`, `current`, `total`.
  /// Returns: None.
  /// Side effects: Updates the [progress] value notifier.
  /// Notes: Internal helper used within this file only.
  static void _reportProgress(
    SyncPhase phase, {
    String? detail,
    int current = 0,
    int total = 0,
  }) {
    progress.value = SyncProgress(
      phase,
      detail: detail,
      current: current,
      total: total,
    );
  }

  /// Purpose: Retry a network operation on transient failures.
  /// Inputs: `attempt` closure, optional `shouldRetry` on the produced value,
  /// `retries` (extra attempts after the first).
  /// Returns: `Future<T>` — the last attempt's value, or rethrows its error.
  /// Side effects: Waits 1s/2s between attempts.
  /// Notes: Internal helper used within this file only. Retries on
  /// socket/timeout/client/HTTP exceptions and on `shouldRetry` (used for
  /// HTTP 5xx); 4xx results are never retried by callers.
  static Future<T> _withRetry<T>(
    Future<T> Function() attempt, {
    bool Function(T value)? shouldRetry,
    int retries = 2,
  }) async {
    var attemptIndex = 0;
    while (true) {
      try {
        final value = await attempt();
        if (attemptIndex < retries && (shouldRetry?.call(value) ?? false)) {
          attemptIndex += 1;
          await Future<void>.delayed(Duration(seconds: attemptIndex));
          continue;
        }
        return value;
      } on Object catch (e) {
        final transient =
            e is SocketException ||
            e is TimeoutException ||
            e is http.ClientException ||
            e is HttpException;
        if (!transient || attemptIndex >= retries) rethrow;
        attemptIndex += 1;
        await Future<void>.delayed(Duration(seconds: attemptIndex));
      }
    }
  }

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
  /// Side effects: Writes the base snapshot through a tmp-then-rename step.
  /// Notes: Internal helper used within this file only. Atomic so an
  /// interrupted write can never leave a truncated base snapshot behind.
  static Future<void> _saveBase(String fileName, String content) async {
    final dir = await _getBaseDir();
    final file = File('${dir.path}/$fileName');
    await _atomicWrite(file, content);
  }

  /// Purpose: Load or create the stable local WebDAV client ID.
  /// Inputs: None.
  /// Returns: `Future<String>`.
  /// Side effects: May create `.sync_base/client_id.txt`.
  /// Notes: The client ID is local-only and is never synced or exported.
  static Future<String> _loadClientId() async {
    final dir = await _getBaseDir();
    final file = File('${dir.path}/$_clientIdFileName');
    if (await file.exists()) {
      final existing = (await file.readAsString()).trim();
      if (existing.isNotEmpty) return existing;
    }
    final id = const Uuid().v4();
    await file.writeAsString(id);
    return id;
  }

  /// Purpose: Read the local upload lock left by an interrupted upload.
  /// Inputs: None.
  /// Returns: `Future<WebDAVUploadLock?>`.
  /// Side effects: None.
  /// Notes: Invalid local locks are ignored and overwritten on the next upload.
  static Future<WebDAVUploadLock?> _readLocalUploadLock() async {
    try {
      final dir = await _getBaseDir();
      final file = File('${dir.path}/$_localLockFileName');
      if (!await file.exists()) return null;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return WebDAVUploadLock.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Purpose: Persist the local upload lock before remote uploads start.
  /// Inputs: `lock`.
  /// Returns: None.
  /// Side effects: Writes `.sync_base/upload_lock.json`.
  /// Notes: The local lock lets the next app start detect interrupted uploads.
  static Future<void> _saveLocalUploadLock(WebDAVUploadLock lock) async {
    final dir = await _getBaseDir();
    final file = File('${dir.path}/$_localLockFileName');
    await _atomicWrite(file, jsonEncode(lock.toJson()));
  }

  /// Purpose: Remove the local upload lock after upload completion or recovery.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Deletes `.sync_base/upload_lock.json` when present.
  /// Notes: Missing files are ignored.
  static Future<void> _clearLocalUploadLock() async {
    final dir = await _getBaseDir();
    final file = File('${dir.path}/$_localLockFileName');
    if (await file.exists()) await file.delete();
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

  /// Purpose: Upload content to a remote WebDAV path.
  /// Inputs: `config`, `fileName`, `content`, optional lock-file preconditions,
  /// `retries` for transient-failure retry (0 for `.lock` writes so a retried
  /// create-only PUT cannot misreport lock contention).
  /// Returns: `Future<({bool is412, String? error})>` — null error on success.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Conditional headers are used for `.lock` writes only. Data JSON
  /// writes go through `_uploadWithSession()` and do not pass data-file
  /// preconditions. Retries cover network errors and HTTP 5xx only.
  static Future<({bool is412, String? error})> _upload(
    WebDAVConfig config,
    String fileName,
    String content, {
    String? ifMatchEtag,
    bool ifNoneMatchAll = false,
    int retries = 2,
  }) async {
    try {
      final url = Uri.parse(_remoteFileUrl(config, fileName));
      final response = await _withRetry(
        () => http
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
            .timeout(const Duration(seconds: 30)),
        shouldRetry: (r) => r.statusCode >= 500,
        retries: retries,
      );
      if (response.statusCode == 412) {
        return (is412: true, error: 'conditional WebDAV PUT failed (HTTP 412)');
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (is412: false, error: null);
      }
      return (is412: false, error: 'HTTP ${response.statusCode}');
    } catch (e) {
      return (is412: false, error: '$e');
    }
  }

  /// Purpose: Return [etag] only when it is a strong ETag usable for lock preconditions.
  /// Inputs: `etag` from a download response, possibly null or weak (`W/...`).
  /// Returns: `String?` — the strong ETag, or null when absent/weak.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Weak ETags must not be
  /// used in `.lock` `If-Match` preconditions (RFC 9110 strong comparison).
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
    final response = await _withRetry(
      () => http
          .put(
            url,
            headers: {
              ..._authHeaders(config),
              'Content-Type': 'application/octet-stream',
            },
            body: bytes,
          )
          .timeout(const Duration(seconds: 120)),
      shouldRetry: (r) => r.statusCode >= 500,
    );
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
      final response = await _withRetry(
        () => http
            .get(url, headers: _authHeaders(config))
            .timeout(const Duration(seconds: 30)),
        shouldRetry: (r) => r.statusCode >= 500,
      );
      if (response.statusCode == 200) {
        return RemoteFile.found(response.body, etag: response.headers['etag']);
      }
      if (response.statusCode == 404) return const RemoteFile.notFound();
      return RemoteFile.failure('HTTP ${response.statusCode}');
    } catch (e) {
      return RemoteFile.failure('$e');
    }
  }

  /// Purpose: Read and parse the remote WebDAV upload lock.
  /// Inputs: `config`.
  /// Returns: Remote lock, ETag, and optional error.
  /// Side effects: Performs network I/O.
  /// Notes: Missing or malformed locks are treated as replaceable stale locks.
  static Future<({WebDAVUploadLock? lock, String? etag, String? error})>
  _readRemoteUploadLock(WebDAVConfig config) async {
    final remote = await _download(config, _lockFileName);
    if (remote.status == RemoteFileStatus.error) {
      return (lock: null, etag: null, error: remote.error);
    }
    if (remote.status == RemoteFileStatus.notFound || remote.content == null) {
      return (lock: null, etag: null, error: null);
    }
    try {
      final json = jsonDecode(remote.content!) as Map<String, dynamic>;
      return (
        lock: WebDAVUploadLock.fromJson(json),
        etag: _strongEtag(remote.etag),
        error: null,
      );
    } catch (_) {
      return (lock: null, etag: _strongEtag(remote.etag), error: null);
    }
  }

  /// Purpose: Write the remote WebDAV upload lock with optional preconditions.
  /// Inputs: `config`, `lock`, optional ETag or create-only flag.
  /// Returns: Upload result.
  /// Side effects: Performs network I/O and may replace `.lock`.
  /// Notes: Uses the same conditional PUT helper as data uploads.
  static Future<({bool is412, String? error})> _writeRemoteUploadLock(
    WebDAVConfig config,
    WebDAVUploadLock lock, {
    String? ifMatchEtag,
    bool ifNoneMatchAll = false,
  }) {
    return _upload(
      config,
      _lockFileName,
      jsonEncode(lock.toJson()),
      ifMatchEtag: ifMatchEtag,
      ifNoneMatchAll: ifNoneMatchAll,
      retries: 0,
    );
  }

  /// Purpose: Remove the remote WebDAV upload lock if it still belongs to us.
  /// Inputs: `config`, `etag`.
  /// Returns: None.
  /// Side effects: Performs network I/O.
  /// Notes: Errors are ignored because stale locks expire after the TTL.
  static Future<void> _deleteRemoteUploadLock(
    WebDAVConfig config, {
    String? etag,
  }) async {
    try {
      final response = await http
          .delete(
            Uri.parse(_remoteFileUrl(config, _lockFileName)),
            headers: {..._authHeaders(config), 'If-Match': ?etag},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 404) return;
    } catch (_) {}
  }

  /// Purpose: Inspect a leftover local upload lock from a previous app run.
  /// Inputs: `config`, `clientId`.
  /// Returns: Optional token to resume and optional blocking error.
  /// Side effects: May clear stale local lock state.
  /// Notes: Normal sync after this step re-downloads, merges, and uploads.
  static Future<({String? resumeToken, String? error})>
  _prepareInterruptedUpload(WebDAVConfig config, String clientId) async {
    final localLock = await _readLocalUploadLock();
    if (localLock == null) return (resumeToken: null, error: null);

    final remote = await _readRemoteUploadLock(config);
    if (remote.error != null) return (resumeToken: null, error: remote.error);

    final remoteLock = remote.lock;
    if (remoteLock == null) {
      await _clearLocalUploadLock();
      return (resumeToken: null, error: null);
    }

    final now = DateTime.now().toUtc();
    if (remoteLock.matches(localLock.clientId, localLock.token) &&
        localLock.clientId == clientId) {
      return (resumeToken: localLock.token, error: null);
    }
    if (remoteLock.clientId != clientId && !remoteLock.isExpired(now)) {
      return (
        resumeToken: null,
        error: 'Another device is uploading; retry after the lock expires.',
      );
    }

    await _clearLocalUploadLock();
    return (resumeToken: null, error: null);
  }

  /// Purpose: Acquire the remote WebDAV upload lock before uploading.
  /// Inputs: `config`, `clientId`, optional `resumeToken`.
  /// Returns: Upload session or a visible error.
  /// Side effects: Writes local and remote lock files.
  /// Notes: Active locks owned by other clients block uploads until expiry.
  static Future<({_UploadSession? session, String? error})>
  _acquireUploadSession(
    WebDAVConfig config,
    String clientId, {
    String? resumeToken,
  }) async {
    final now = DateTime.now().toUtc();
    final remote = await _readRemoteUploadLock(config);
    if (remote.error != null) return (session: null, error: remote.error);

    final remoteLock = remote.lock;
    if (remoteLock != null &&
        remoteLock.clientId != clientId &&
        !remoteLock.isExpired(now)) {
      return (
        session: null,
        error: 'Another device is uploading; retry after the lock expires.',
      );
    }

    final lock = WebDAVUploadLock(
      clientId: clientId,
      token: resumeToken ?? const Uuid().v4(),
      startedAt: now,
      updatedAt: now,
      ttlSeconds: _lockTtlSeconds,
    );
    final write = await _writeRemoteUploadLock(
      config,
      lock,
      ifMatchEtag: remote.etag,
      ifNoneMatchAll: remoteLock == null && remote.etag == null,
    );
    if (write.error != null) {
      return (
        session: null,
        error: write.is412
            ? 'Another device started uploading; retry after the lock expires.'
            : write.error,
      );
    }
    await _saveLocalUploadLock(lock);
    return (
      session: _UploadSession(clientId: clientId, token: lock.token),
      error: null,
    );
  }

  /// Purpose: Refresh the remote upload lock before a PUT.
  /// Inputs: `config`, `session`.
  /// Returns: Optional error string.
  /// Side effects: Updates local and remote lock timestamps.
  /// Notes: If another active client owns the lock, uploading is blocked.
  static Future<String?> _refreshUploadLock(
    WebDAVConfig config,
    _UploadSession session,
  ) async {
    final remote = await _readRemoteUploadLock(config);
    if (remote.error != null) return remote.error;
    final now = DateTime.now().toUtc();
    final remoteLock = remote.lock;
    if (remoteLock != null &&
        !remoteLock.matches(session.clientId, session.token) &&
        remoteLock.clientId != session.clientId &&
        !remoteLock.isExpired(now)) {
      return 'Another device is uploading; retry after the lock expires.';
    }

    final lock =
        (remoteLock != null &&
            remoteLock.matches(session.clientId, session.token))
        ? remoteLock.refreshed(now)
        : WebDAVUploadLock(
            clientId: session.clientId,
            token: session.token,
            startedAt: now,
            updatedAt: now,
            ttlSeconds: _lockTtlSeconds,
          );
    final write = await _writeRemoteUploadLock(
      config,
      lock,
      ifMatchEtag: remote.etag,
      ifNoneMatchAll: remoteLock == null && remote.etag == null,
    );
    if (write.error != null) {
      return write.is412
          ? 'Another device started uploading; retry after the lock expires.'
          : write.error;
    }
    await _saveLocalUploadLock(lock);
    return null;
  }

  /// Purpose: Force-upload content after refreshing the held upload lock.
  /// Inputs: `config`, `fileName`, `content`, `session`.
  /// Returns: Upload result.
  /// Side effects: Performs network I/O.
  /// Notes: Data JSON writes are protected by `.lock`, so they intentionally do
  /// not send data-file `If-Match`/`If-None-Match` preconditions.
  static Future<({bool is412, String? error})> _uploadWithSession(
    WebDAVConfig config,
    String fileName,
    String content,
    _UploadSession session,
  ) async {
    final lockError = await _refreshUploadLock(config, session);
    if (lockError != null) return (is412: false, error: lockError);
    return _upload(config, fileName, content);
  }

  /// Purpose: Upload bytes after refreshing the held upload lock.
  /// Inputs: `config`, `fileName`, `bytes`, `session`.
  /// Returns: `Future<bool>`.
  /// Side effects: Performs network I/O.
  /// Notes: Used for referenced image uploads under the same remote lock.
  static Future<bool> _uploadBytesWithSession(
    WebDAVConfig config,
    String fileName,
    Uint8List bytes,
    _UploadSession session,
  ) async {
    final lockError = await _refreshUploadLock(config, session);
    if (lockError != null) throw Exception(lockError);
    return _uploadBytes(config, fileName, bytes);
  }

  /// Purpose: Release the held WebDAV upload lock.
  /// Inputs: `config`, `session`.
  /// Returns: None.
  /// Side effects: Deletes matching local and remote lock files.
  /// Notes: Remote delete only runs if the lock still has our client ID and token.
  static Future<void> _releaseUploadSession(
    WebDAVConfig config,
    _UploadSession? session,
  ) async {
    if (session == null) return;
    final remote = await _readRemoteUploadLock(config);
    if (remote.lock?.matches(session.clientId, session.token) ?? false) {
      await _deleteRemoteUploadLock(config, etag: remote.etag);
    }
    await _clearLocalUploadLock();
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
    final response = await _withRetry(
      () => http
          .get(url, headers: _authHeaders(config))
          .timeout(const Duration(seconds: 120)),
      shouldRetry: (r) => r.statusCode >= 500,
    );
    if (response.statusCode == 200) return response.bodyBytes;
    throw Exception('HTTP ${response.statusCode}');
  }

  /// Purpose: List file names inside a remote subdirectory via PROPFIND.
  /// Inputs: `config`, `subPath`.
  /// Returns: `Future<Set<String>?>` — null when the listing failed.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. A null result means
  /// the remote state is unknown (network/server error); callers must not
  /// treat it as an empty directory, otherwise every referenced image would
  /// be re-uploaded on any transient PROPFIND failure.
  static Future<Set<String>?> _listRemoteFiles(
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
      final streamed = await _withRetry(() {
        final request = http.Request('PROPFIND', url);
        request.headers.addAll(_authHeaders(config));
        request.headers['Depth'] = '1';
        request.headers['Content-Type'] = 'application/xml';
        request.body =
            '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>';
        return http.Client()
            .send(request)
            .timeout(const Duration(seconds: 15));
      }, shouldRetry: (r) => r.statusCode >= 500);
      if (streamed.statusCode != 207) return null;
      final body = await streamed.stream.bytesToString();
      // Extract href values and filter to files (not the directory itself)
      final hrefRegex = RegExp(
        r'<d:href>([^<]+)</d:href>',
        caseSensitive: false,
      );
      final names = <String>{};
      for (final match in hrefRegex.allMatches(body)) {
        final href = Uri.decodeFull(match.group(1)!);
        if (href.endsWith('/')) continue; // skip directories
        names.add(p.basename(href));
      }
      return names;
    } catch (_) {
      return null;
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
    Future<_UploadSession?> Function() ensureUploadSession,
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

    // List all remote file names (needed to avoid re-uploading existing
    // files). A null listing means the remote state is unknown, so the image
    // phase is skipped entirely instead of re-uploading every image.
    final remoteNames = await _listRemoteFiles(config, 'images');
    if (remoteNames == null) {
      errors.add(
        'Image sync skipped: could not list the remote images directory',
      );
      return errors;
    }

    // Upload local referenced images that are missing on remote
    final toUpload = localNames.where((n) => !remoteNames.contains(n)).toList();
    var uploadIndex = 0;
    for (final name in toUpload) {
      uploadIndex += 1;
      _reportProgress(
        SyncPhase.uploadingImages,
        detail: name,
        current: uploadIndex,
        total: toUpload.length,
      );
      final uploadSession = await ensureUploadSession();
      if (uploadSession == null) {
        errors.add('Upload skipped for $name: upload lock was not acquired');
        continue;
      }
      try {
        final bytes = await File(p.join(imgDir.path, name)).readAsBytes();
        await _uploadBytesWithSession(
          config,
          'images/$name',
          bytes,
          uploadSession,
        );
      } on TimeoutException {
        errors.add('Upload timed out: $name');
      } catch (e) {
        errors.add('Upload failed for $name: $e');
      }
    }

    // Download referenced remote images that are missing locally
    final toDownload = referencedImages
        .where((n) => !localNames.contains(n) && remoteNames.contains(n))
        .toList();
    var downloadIndex = 0;
    for (final name in toDownload) {
      downloadIndex += 1;
      _reportProgress(
        SyncPhase.downloadingImages,
        detail: name,
        current: downloadIndex,
        total: toDownload.length,
      );
      try {
        final bytes = await _downloadBytes(config, 'images/$name');
        if (bytes != null) {
          await File(p.join(imgDir.path, name)).writeAsBytes(bytes);
          // New image files must trigger a UI reload even when the data
          // JSON itself did not change during this sync.
          _localDataChanged = true;
        }
      } on TimeoutException {
        errors.add('Download timed out: $name');
      } catch (e) {
        errors.add('Download failed for $name: $e');
      }
    }

    return errors;
  }

  // ── Per-record merge sync ──

  /// Purpose: Sync data files with the remote server using per-record three-way merge.
  /// Inputs: `config`, `autoResolve`.
  /// Returns: `Future<SyncResult>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: For each data file: reads local, remote, and base (last-synced)
  /// versions, merges per-record using `modifiedAt`, auto-resolves when only
  /// one side changed, and returns conflicts when both sides modified the same
  /// record. When [autoResolve] is true, two-sided conflicts fall back to
  /// last-writer-wins; every production caller (manual sync and auto-sync)
  /// leaves it false so true conflicts always surface for manual resolution.
  /// Progress is published through [progress].
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
      _reportProgress(SyncPhase.connecting);
      final result = await _syncLocked(config, autoResolve: autoResolve);
      _reportProgress(
        result.success ? SyncPhase.done : SyncPhase.error,
        detail: result.error,
      );
      return result;
    } finally {
      _syncing = false;
    }
  }

  /// Purpose: Run the merge-based sync body while `_syncing` is held.
  /// Inputs: `config`, `autoResolve`.
  /// Returns: `Future<SyncResult>`.
  /// Side effects: Reads and writes local data files, base snapshots, remote
  /// WebDAV files, and sync state.
  /// Notes: Internal helper used within this file only. Callers must set and
  /// clear the `_syncing` guard.
  static Future<SyncResult> _syncLocked(
    WebDAVConfig config, {
    bool autoResolve = false,
  }) async {
    _UploadSession? uploadSession;
    try {
      await _ensureRemoteDir(config);
      final appDir = await AnimeStorage.getAppDir();
      final clientId = await _loadClientId();
      final interrupted = await _prepareInterruptedUpload(config, clientId);
      if (interrupted.error != null) {
        return SyncResult(success: false, error: interrupted.error);
      }
      final acquired = await _acquireUploadSession(
        config,
        clientId,
        resumeToken: interrupted.resumeToken,
      );
      uploadSession = acquired.session;
      if (uploadSession == null) {
        return SyncResult(
          success: false,
          error: acquired.error ?? 'Upload lock was not acquired',
        );
      }

      /// Purpose: Return the upload lock acquired before data downloads.
      /// Inputs: None.
      /// Returns: The active upload session, or null if acquisition failed.
      /// Side effects: May write local and remote lock files.
      /// Notes: Internal helper used only within this sync attempt.
      Future<_UploadSession?> ensureUploadSession() async {
        return uploadSession;
      }

      /// Purpose: Force-upload JSON while holding the remote upload lock.
      /// Inputs: `fileName`, `content`.
      /// Returns: Upload result.
      /// Side effects: Performs network I/O.
      /// Notes: Internal helper used only within this sync attempt.
      Future<({bool is412, String? error})> uploadJson(
        String fileName,
        String content,
      ) async {
        final session = await ensureUploadSession();
        if (session == null) {
          return (is412: false, error: 'Upload lock was not acquired');
        }
        return _uploadWithSession(config, fileName, content, session);
      }

      AnimeMergeResult? pendingAnime;
      // Track local/remote anime JSON to compute referenced image set.
      String? localAnimeJson;
      String? remoteAnimeJson;

      var fileIndex = 0;
      for (final name in _dataFileNames) {
        fileIndex += 1;
        _reportProgress(
          SyncPhase.downloadingData,
          detail: name,
          current: fileIndex,
          total: _dataFileNames.length,
        );
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
        var remoteRaw = remote.content;

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
          // Only on local → force-upload as new under the remote lock.
          _reportProgress(
            SyncPhase.uploadingData,
            detail: name,
            current: fileIndex,
            total: _dataFileNames.length,
          );
          final uploadResult = await uploadJson(name, localRaw);
          if (uploadResult.error == null) {
            await _saveBase(name, localRaw);
            continue;
          }
          return SyncResult(
            success: false,
            error:
                'Failed to force-upload $name under WebDAV lock: ${uploadResult.error}',
          );
        }

        if (name == 'anime_data.json') remoteAnimeJson = remoteRaw;

        // Both exist → per-record merge
        if (localRaw == remoteRaw) {
          await _saveBase(name, localRaw);
          continue;
        }

        final baseJson = await _readBase(name);
        _reportProgress(
          SyncPhase.merging,
          detail: name,
          current: fileIndex,
          total: _dataFileNames.length,
        );

        switch (name) {
          case 'anime_data.json':
            var currentLocalRaw = localRaw;
            var result = mergeAnimeData(
              currentLocalRaw,
              remoteRaw!,
              baseJson,
              autoResolve: autoResolve,
            );
            if (!result.hasConflicts) {
              // Re-read local to detect concurrent saves during network I/O.
              final freshLocalRaw = await localFile.readAsString();
              if (freshLocalRaw != currentLocalRaw) {
                currentLocalRaw = freshLocalRaw;
                localAnimeJson = freshLocalRaw;
                result = mergeAnimeData(
                  currentLocalRaw,
                  remoteRaw,
                  baseJson,
                  autoResolve: autoResolve,
                );
              }
            }
            if (result.hasConflicts) {
              pendingAnime = result;
              remoteAnimeJson = remoteRaw;
            } else {
              final mergedData = AnimeData(
                animes: result.merged,
                extraJson: result.extraJson,
              );
              // Pretty-print to match AnimeStorage's local save format so an
              // unchanged file hits the raw-equality fast path next sync.
              final mergedJson = const JsonEncoder.withIndent(
                '  ',
              ).convert(mergedData.toJson());
              await _atomicWrite(localFile, mergedJson);
              _localDataChanged = true;
              _reportProgress(
                SyncPhase.uploadingData,
                detail: name,
                current: fileIndex,
                total: _dataFileNames.length,
              );
              final uploadResult = await uploadJson(name, mergedJson);
              if (uploadResult.error != null) {
                return SyncResult(
                  success: false,
                  error:
                      'Failed to force-upload merged $name under WebDAV lock: '
                      '${uploadResult.error}',
                );
              }
              await _saveBase(name, mergedJson);
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
      final imageErrors = await _syncImages(
        config,
        appDir,
        referencedImages,
        ensureUploadSession,
      );

      if (pendingAnime != null) {
        return SyncResult(
          success: true,
          pending: PendingSync(animeMerge: pendingAnime),
          warnings: imageErrors,
        );
      }

      return SyncResult(success: true, warnings: imageErrors);
    } catch (e, st) {
      return SyncResult(success: false, error: '$e\n$st');
    } finally {
      await _releaseUploadSession(config, uploadSession);
    }
  }

  /// Purpose: Finalize sync by applying user's conflict resolutions.
  /// Inputs: `config`, `pending`, `resolutions`.
  /// Returns: `Future<bool>` — false when applying or uploading the resolution fails.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Finalize sync by applying user's conflict resolutions. [resolutions] maps
  /// anime ID → the chosen Anime record. The base snapshot is only saved after a
  /// successful force-upload under the held remote `.lock`.
  static Future<bool> finalizePendingSync(
    WebDAVConfig config,
    PendingSync pending,
    Map<String, Anime> resolutions,
  ) async {
    _UploadSession? uploadSession;
    try {
      final appDir = await AnimeStorage.getAppDir();
      final clientId = await _loadClientId();
      final interrupted = await _prepareInterruptedUpload(config, clientId);
      if (interrupted.error != null) return false;
      final acquired = await _acquireUploadSession(
        config,
        clientId,
        resumeToken: interrupted.resumeToken,
      );
      uploadSession = acquired.session;
      if (uploadSession == null) return false;

      if (pending.animeMerge != null) {
        final mergedData = pending.animeMerge!.buildResolved(resolutions);
        // Pretty-print to match AnimeStorage's local save format.
        final mergedJson = const JsonEncoder.withIndent(
          '  ',
        ).convert(mergedData.toJson());
        await _atomicWrite(File('${appDir.path}/anime_data.json'), mergedJson);
        _localDataChanged = true;
        final uploadResult = await _uploadWithSession(
          config,
          'anime_data.json',
          mergedJson,
          uploadSession,
        );
        if (uploadResult.error != null) return false;
        await _saveBase('anime_data.json', mergedJson);
      }

      return true;
    } catch (_) {
      return false;
    } finally {
      await _releaseUploadSession(config, uploadSession);
    }
  }

  // ── Force upload / download ──

  /// Purpose: Upload all local data files and referenced images to the remote,
  /// overwriting remote data without any conflict check or merge.
  /// Inputs: `config`.
  /// Returns: `Future<SyncResult>`.
  /// Side effects: Overwrites remote data files, uploads images, saves base
  /// snapshots, and publishes progress through [progress].
  /// Notes: Remote changes made since the last sync are lost. Runs under the
  /// remote `.lock` and the `_syncing` guard like a normal sync.
  static Future<SyncResult> forceUpload(WebDAVConfig config) async {
    if (_syncing) {
      return const SyncResult(
        success: false,
        error: 'Sync already in progress',
      );
    }
    _syncing = true;
    try {
      _reportProgress(SyncPhase.connecting);
      final result = await _forceUploadLocked(config);
      _reportProgress(
        result.success ? SyncPhase.done : SyncPhase.error,
        detail: result.error,
      );
      return result;
    } finally {
      _syncing = false;
    }
  }

  /// Purpose: Run the force-upload body while `_syncing` is held.
  /// Inputs: `config`.
  /// Returns: `Future<SyncResult>`.
  /// Side effects: Uploads local data/images and saves base snapshots.
  /// Notes: Internal helper used within this file only.
  static Future<SyncResult> _forceUploadLocked(WebDAVConfig config) async {
    _UploadSession? uploadSession;
    try {
      await _ensureRemoteDir(config);
      final appDir = await AnimeStorage.getAppDir();
      final clientId = await _loadClientId();
      final interrupted = await _prepareInterruptedUpload(config, clientId);
      if (interrupted.error != null) {
        return SyncResult(success: false, error: interrupted.error);
      }
      final acquired = await _acquireUploadSession(
        config,
        clientId,
        resumeToken: interrupted.resumeToken,
      );
      uploadSession = acquired.session;
      if (uploadSession == null) {
        return SyncResult(
          success: false,
          error: acquired.error ?? 'Upload lock was not acquired',
        );
      }

      String? localAnimeJson;
      var fileIndex = 0;
      for (final name in _dataFileNames) {
        fileIndex += 1;
        final localFile = File('${appDir.path}/$name');
        if (!await localFile.exists()) continue;
        final localRaw = await localFile.readAsString();
        if (name == 'anime_data.json') localAnimeJson = localRaw;
        _reportProgress(
          SyncPhase.uploadingData,
          detail: name,
          current: fileIndex,
          total: _dataFileNames.length,
        );
        final uploadResult = await _uploadWithSession(
          config,
          name,
          localRaw,
          uploadSession,
        );
        if (uploadResult.error != null) {
          return SyncResult(
            success: false,
            error: 'Failed to force-upload $name: ${uploadResult.error}',
          );
        }
        // The remote now equals local, so local content is the new base.
        await _saveBase(name, localRaw);
      }

      final warnings = await _forceUploadImages(
        config,
        appDir,
        _getReferencedImageNames(localAnimeJson),
        uploadSession,
      );
      return SyncResult(success: true, warnings: warnings);
    } catch (e) {
      return SyncResult(success: false, error: '$e');
    } finally {
      await _releaseUploadSession(config, uploadSession);
    }
  }

  /// Purpose: Upload all referenced local images during a force upload.
  /// Inputs: `config`, `appDir`, `referencedImages`, `session`.
  /// Returns: `Future<List<String>>` — non-fatal per-image warnings.
  /// Side effects: Uploads image bytes and publishes progress.
  /// Notes: Internal helper used within this file only. Image names are
  /// immutable UUIDs, so names already present remotely are skipped when the
  /// remote listing is available; a failed listing falls back to uploading
  /// everything because force upload must guarantee remote completeness.
  static Future<List<String>> _forceUploadImages(
    WebDAVConfig config,
    Directory appDir,
    Set<String> referencedImages,
    _UploadSession session,
  ) async {
    final errors = <String>[];
    if (referencedImages.isEmpty) return errors;

    final imgDir = Directory(p.join(appDir.path, 'images'));
    if (!await imgDir.exists()) return errors;

    await _ensureRemoteSubDir(config, 'images');

    final localNames = <String>[];
    await for (final entity in imgDir.list()) {
      if (entity is File) {
        final name = p.basename(entity.path);
        if (referencedImages.contains(name)) localNames.add(name);
      }
    }

    final remoteNames = await _listRemoteFiles(config, 'images');
    final toUpload = remoteNames == null
        ? localNames
        : localNames.where((n) => !remoteNames.contains(n)).toList();

    var uploadIndex = 0;
    for (final name in toUpload) {
      uploadIndex += 1;
      _reportProgress(
        SyncPhase.uploadingImages,
        detail: name,
        current: uploadIndex,
        total: toUpload.length,
      );
      try {
        final bytes = await File(p.join(imgDir.path, name)).readAsBytes();
        await _uploadBytesWithSession(config, 'images/$name', bytes, session);
      } on TimeoutException {
        errors.add('Upload timed out: $name');
      } catch (e) {
        errors.add('Upload failed for $name: $e');
      }
    }
    return errors;
  }

  /// Purpose: Replace local data files and images with the remote copies,
  /// without any conflict check or merge.
  /// Inputs: `config`.
  /// Returns: `Future<SyncResult>`.
  /// Side effects: Overwrites local data files, saves base snapshots, sets the
  /// local-data-changed flag, and publishes progress through [progress].
  /// Notes: Local changes made since the last sync are lost. Download-only, so
  /// no remote `.lock` is taken; the `_syncing` guard still applies.
  static Future<SyncResult> forceDownload(WebDAVConfig config) async {
    if (_syncing) {
      return const SyncResult(
        success: false,
        error: 'Sync already in progress',
      );
    }
    _syncing = true;
    try {
      _reportProgress(SyncPhase.connecting);
      final result = await _forceDownloadLocked(config);
      _reportProgress(
        result.success ? SyncPhase.done : SyncPhase.error,
        detail: result.error,
      );
      return result;
    } finally {
      _syncing = false;
    }
  }

  /// Purpose: Run the force-download body while `_syncing` is held.
  /// Inputs: `config`.
  /// Returns: `Future<SyncResult>`.
  /// Side effects: Overwrites local data files and downloads images.
  /// Notes: Internal helper used within this file only. Remote content is
  /// JSON-validated before it replaces any local file; a missing remote file
  /// keeps the local copy and adds a warning.
  static Future<SyncResult> _forceDownloadLocked(WebDAVConfig config) async {
    try {
      final appDir = await AnimeStorage.getAppDir();
      final warnings = <String>[];
      String? remoteAnimeJson;

      var fileIndex = 0;
      for (final name in _dataFileNames) {
        fileIndex += 1;
        _reportProgress(
          SyncPhase.downloadingData,
          detail: name,
          current: fileIndex,
          total: _dataFileNames.length,
        );
        final remote = await _download(config, name);
        if (remote.status == RemoteFileStatus.error) {
          return SyncResult(
            success: false,
            error: 'Failed to download $name from remote: ${remote.error}',
          );
        }
        if (remote.status == RemoteFileStatus.notFound ||
            remote.content == null) {
          warnings.add('$name: not found on remote; local file kept');
          continue;
        }
        final remoteRaw = remote.content!;
        try {
          jsonDecode(remoteRaw);
        } catch (_) {
          return SyncResult(
            success: false,
            error: '$name: remote content is not valid JSON',
          );
        }
        await _atomicWrite(File('${appDir.path}/$name'), remoteRaw);
        await _saveBase(name, remoteRaw);
        _localDataChanged = true;
        if (name == 'anime_data.json') remoteAnimeJson = remoteRaw;
      }

      warnings.addAll(
        await _forceDownloadImages(
          config,
          appDir,
          _getReferencedImageNames(remoteAnimeJson),
        ),
      );
      return SyncResult(success: true, warnings: warnings);
    } catch (e) {
      return SyncResult(success: false, error: '$e');
    }
  }

  /// Purpose: Download referenced remote images during a force download.
  /// Inputs: `config`, `appDir`, `referencedImages`.
  /// Returns: `Future<List<String>>` — non-fatal per-image warnings.
  /// Side effects: Writes image files locally and publishes progress.
  /// Notes: Internal helper used within this file only. Image names are
  /// immutable UUIDs, so names already present locally are kept as-is.
  static Future<List<String>> _forceDownloadImages(
    WebDAVConfig config,
    Directory appDir,
    Set<String> referencedImages,
  ) async {
    final errors = <String>[];
    if (referencedImages.isEmpty) return errors;

    final imgDir = Directory(p.join(appDir.path, 'images'));
    if (!await imgDir.exists()) await imgDir.create(recursive: true);

    final remoteNames = await _listRemoteFiles(config, 'images');
    if (remoteNames == null) {
      errors.add(
        'Image download skipped: could not list the remote images directory',
      );
      return errors;
    }

    final toDownload = referencedImages
        .where(remoteNames.contains)
        .where((n) => !File(p.join(imgDir.path, n)).existsSync())
        .toList();
    var downloadIndex = 0;
    for (final name in toDownload) {
      downloadIndex += 1;
      _reportProgress(
        SyncPhase.downloadingImages,
        detail: name,
        current: downloadIndex,
        total: toDownload.length,
      );
      try {
        final bytes = await _downloadBytes(config, 'images/$name');
        if (bytes != null) {
          await File(p.join(imgDir.path, name)).writeAsBytes(bytes);
          _localDataChanged = true;
        }
      } on TimeoutException {
        errors.add('Download timed out: $name');
      } catch (e) {
        errors.add('Download failed for $name: $e');
      }
    }
    return errors;
  }
}
