# lib/shared/services/webdav_service.dart

The WebDAV sync client: config persistence, the remote `.lock` concurrency guard (client id,
token, TTL, heartbeat), conditional-PUT primitives, retry/backoff, per-record three-way sync
(`sync`/`_syncLocked`), conflict finalization (`finalizePendingSync`), and the merge-free force
operations (`forceUpload`/`forceDownload`). It delegates per-record merge decisions to
[`sync_merge.dart`](sync_merge.md) and publishes progress through
[`sync_progress.dart`](sync_progress.md)'s `SyncProgress`. See [`../../../sync.md`](../../../sync.md)
for the full 10-step sync flow, retry policy, heartbeat, and image-sync rules this file
implements, and [`../../../algorithms/three-way-merge.md`](../../../algorithms/three-way-merge.md)
for the merge engine itself.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`WebDAVConfig(...)`](#webdavconfig-new) | constructor (`WebDAVConfig`) | A | Create a persisted WebDAV configuration. |
| `isConfigured` | getter (`WebDAVConfig`) | B | Whether server URL, username, and password are all non-empty. |
| [`copyWith`](#copywith-webdavconfig) | method (`WebDAVConfig`) | A | Create a copy with `autoSync` replaced. |
| [`toJson`](#tojson-webdavconfig) | method (`WebDAVConfig`) | A | Serialize config to a JSON map. |
| [`WebDAVConfig.fromJson`](#webdavconfig-fromjson) | factory constructor | A | Parse config from a JSON map. |
| [`WebDAVConfig.nextcloud`](#webdavconfig-nextcloud) | factory constructor | A | Build a config from a Nextcloud host + credentials. |
| [`SyncResult(...)`](#syncresult-new) | constructor (`SyncResult`) | A | Create a sync/force-operation outcome. |
| `hasConflicts` | getter (`SyncResult`) | B | Whether `pending` is non-null. |
| [`PendingSync(...)`](#pendingsync-new) | constructor (`PendingSync`) | A | Wrap an unresolved per-record merge result. |
| `allConflicts` | getter (`PendingSync`) | B | Flatten `animeMerge?.conflicts` to a list. |
| [`WebDAVUploadLock(...)`](#webdavuploadlock-new) | constructor (`WebDAVUploadLock`) | A | Create an upload-lock value (client id, token, timestamps, TTL). |
| [`WebDAVUploadLock.fromJson`](#webdavuploadlock-fromjson) | factory constructor | A | Parse a lock from the remote `.lock` JSON. |
| [`toJson`](#tojson-webdavuploadlock) | method (`WebDAVUploadLock`) | A | Serialize a lock to the `.lock` JSON format. |
| [`isExpired`](#isexpired) | method (`WebDAVUploadLock`) | A | Whether the lock's age has passed its TTL. |
| [`matches`](#matches) | method (`WebDAVUploadLock`) | A | Whether this lock was issued by the given client/token. |
| [`refreshed`](#refreshed) | method (`WebDAVUploadLock`) | A | Return a copy with `updatedAt` bumped. |
| `_UploadSession(...)` | constructor (`_UploadSession`) | B | Store the client id/token pair for a held lock. |
| [`RemoteFile.found`](#remotefile-found) | named constructor | A | Discriminated "download succeeded" result. |
| [`RemoteFile.notFound`](#remotefile-notfound) | named constructor | A | Discriminated "HTTP 404" result. |
| [`RemoteFile.failure`](#remotefile-failure) | named constructor | A | Discriminated "any other failure" result. |
| [`_reportProgress`](#reportprogress) | static method (`WebDAVService`) | A | Publish a `SyncProgress` snapshot. |
| [`_withRetry`](#withretry) | static method (`WebDAVService`) | A | Retry a transient-failing operation with 1s/2s backoff. |
| [`consumeLocalDataChanged`](#consumelocaldatachanged) | static method (`WebDAVService`) | A | Read-and-clear the "local data changed" flag. |
| [`_atomicWrite`](#atomicwrite) | static method (`WebDAVService`) | A | Write a file via tmp-then-rename. |
| [`loadConfig`](#loadconfig) | static method (`WebDAVService`) | A | Load `webdav_config.json`. |
| [`saveConfig`](#saveconfig) | static method (`WebDAVService`) | A | Write `webdav_config.json`. |
| [`deleteConfig`](#deleteconfig) | static method (`WebDAVService`) | A | Delete `webdav_config.json`. |
| [`_getBaseDir`](#getbasedir) | static method (`WebDAVService`) | A | Resolve/create `.sync_base/`. |
| [`_readBase`](#readbase) | static method (`WebDAVService`) | A | Read a base-snapshot file. |
| [`_saveBase`](#savebase) | static method (`WebDAVService`) | A | Write a base-snapshot file atomically. |
| [`_loadClientId`](#loadclientid) | static method (`WebDAVService`) | A | Load or create the stable local client id. |
| [`_readLocalUploadLock`](#readlocaluploadlock) | static method (`WebDAVService`) | A | Read `.sync_base/upload_lock.json`. |
| [`_saveLocalUploadLock`](#savelocaluploadlock) | static method (`WebDAVService`) | A | Write the local upload-lock marker. |
| [`_clearLocalUploadLock`](#clearlocaluploadlock) | static method (`WebDAVService`) | A | Delete the local upload-lock marker. |
| [`_authHeaders`](#authheaders) | static method (`WebDAVService`) | A | Build the HTTP Basic auth header. |
| [`_remoteFileUrl`](#remotefileurl) | static method (`WebDAVService`) | A | Build the full remote URL for a file name. |
| [`testConnection`](#testconnection) | static method (`WebDAVService`) | A | PROPFIND the remote root to verify reachability. |
| [`_ensureRemoteDir`](#ensureremotedir) | static method (`WebDAVService`) | A | MKCOL the configured remote directory. |
| [`_upload`](#upload) | static method (`WebDAVService`) | A | Conditional PUT with retry, used for data and `.lock` writes. |
| [`_strongEtag`](#strongetag) | static method (`WebDAVService`) | A | Filter out weak (`W/...`) ETags. |
| [`_uploadBytes`](#uploadbytes) | static method (`WebDAVService`) | A | PUT raw bytes (images) with retry. |
| [`_download`](#download) | static method (`WebDAVService`) | A | GET a data file with a found/notFound/error discriminated result. |
| [`_readRemoteUploadLock`](#readremoteuploadlock) | static method (`WebDAVService`) | A | Download and parse the remote `.lock`. |
| [`_writeRemoteUploadLock`](#writeremoteuploadlock) | static method (`WebDAVService`) | A | PUT a lock value with optional preconditions. |
| [`_deleteRemoteUploadLock`](#deleteremoteuploadlock) | static method (`WebDAVService`) | A | DELETE the remote `.lock` if it is still ours. |
| [`_prepareInterruptedUpload`](#prepareinterruptedupload) | static method (`WebDAVService`) | A | Detect and recover from a crash mid-upload. |
| [`_acquireUploadSession`](#acquireuploadsession) | static method (`WebDAVService`) | A | Take the remote upload lock before syncing. |
| [`_refreshUploadLock`](#refreshuploadlock) | static method (`WebDAVService`) | A | Re-write the lock's timestamp before a PUT. |
| [`_withLockHeartbeat`](#withlockheartbeat) | static method (`WebDAVService`) | A | Run a transfer while periodically refreshing the lock. |
| [`_uploadWithSession`](#uploadwithsession) | static method (`WebDAVService`) | A | Upload data content under a heartbeat-refreshed lock. |
| [`_uploadBytesWithSession`](#uploadbyteswithsession) | static method (`WebDAVService`) | A | Upload image bytes under a heartbeat-refreshed lock. |
| [`_releaseUploadSession`](#releaseuploadsession) | static method (`WebDAVService`) | A | Delete the local and (if still owned) remote lock. |
| [`_downloadBytes`](#downloadbytes) | static method (`WebDAVService`) | A | GET raw bytes (images) with retry. |
| [`_listRemoteFiles`](#listremotefiles) | static method (`WebDAVService`) | A | PROPFIND-list file names in a remote subdirectory. |
| [`_ensureRemoteSubDir`](#ensureremotesubdir) | static method (`WebDAVService`) | A | MKCOL a remote subdirectory (e.g. `images`). |
| [`_getReferencedImageNames`](#getreferencedimagenames) | static method (`WebDAVService`) | A | Extract referenced cover-image basenames from anime JSON. |
| [`_syncImages`](#syncimages) | static method (`WebDAVService`) | A | Additively sync only referenced images. |
| [`sync`](#sync) | static method (`WebDAVService`) | A | Public entry point for a merge-based sync run. |
| [`_syncLocked`](#synclocked) | static method (`WebDAVService`) | A | The 10-step merge-sync body, run while `_syncing` is held. |
| `ensureUploadSession` | local function (nested in `_syncLocked`) | B | Return the already-acquired session for this attempt. |
| `uploadJson` | local function (nested in `_syncLocked`) | B | Force-upload one data file's JSON under the held lock. |
| [`finalizePendingSync`](#finalizependingsync) | static method (`WebDAVService`) | A | Apply user conflict resolutions and upload the result. |
| [`forceUpload`](#forceupload) | static method (`WebDAVService`) | A | Public entry point for a merge-free upload. |
| [`_forceUploadLocked`](#forceuploadlocked) | static method (`WebDAVService`) | A | The force-upload body, run while `_syncing` is held. |
| [`_forceUploadImages`](#forceuploadimages) | static method (`WebDAVService`) | A | Upload all referenced local images unconditionally. |
| [`forceDownload`](#forcedownload) | static method (`WebDAVService`) | A | Public entry point for a merge-free download. |
| [`_forceDownloadLocked`](#forcedownloadlocked) | static method (`WebDAVService`) | A | The force-download body, run while `_syncing` is held. |
| [`_forceDownloadImages`](#forcedownloadimages) | static method (`WebDAVService`) | A | Download all referenced remote images unconditionally. |

## Documentation

### `const WebDAVConfig({required serverUrl, required username, required password, remotePath = '/MyAnime', autoSync = false})` <a id="webdavconfig-new"></a>
- **Kind:** constructor of `WebDAVConfig`
- **Source:** `lib/shared/services/webdav_service.dart` (line 29)
- **Purpose:** Hold the persisted WebDAV connection settings.
- **Inputs:** `serverUrl`, `username`, `password`; `remotePath` defaults to `/MyAnime`; `autoSync` defaults to `false`.
- **Returns:** A new `WebDAVConfig`.
- **Side effects:** None.
- **Algorithm:** Plain field assignment via `const` constructor; no derived state.
- **Usage:**
  ```dart
  WebDAVConfig get _currentConfig => WebDAVConfig(
    serverUrl: _urlController.text.trim(),
    username: _userController.text.trim(),
    password: _passController.text.trim(),
    remotePath: _pathController.text.trim(),
    autoSync: _autoSync,
  );
  ```
  (`lib/shared/views/webdav_config_page.dart`)
- **Notes:** None.

### `WebDAVConfig copyWith({bool? autoSync})` <a id="copywith-webdavconfig"></a>
- **Kind:** method of `WebDAVConfig`
- **Source:** `lib/shared/services/webdav_service.dart` (line 50)
- **Purpose:** Return a copy with only `autoSync` replaceable.
- **Inputs:** Optional `autoSync`.
- **Returns:** A new `WebDAVConfig` with all other fields unchanged.
- **Side effects:** None.
- **Algorithm:** Rebuilds a `WebDAVConfig` reusing every field except `autoSync`, which falls back to `this.autoSync` when not supplied.
- **Usage:**
  ```dart
  await WebDAVService.saveConfig(config.copyWith(autoSync: false));
  ```
  (`lib/features/settings/views/backup_page.dart`, disabling auto-sync before a backup restore — see [`../../../backup-restore.md`](../../../backup-restore.md))
- **Notes:** Only `autoSync` is overridable; there is no general-purpose field-by-field `copyWith` here.

### `Map<String, dynamic> toJson()` <a id="tojson-webdavconfig"></a>
- **Kind:** method of `WebDAVConfig`
- **Source:** `lib/shared/services/webdav_service.dart` (line 63)
- **Purpose:** Serialize the config to the JSON shape stored in `webdav_config.json`.
- **Inputs:** None.
- **Returns:** `{serverUrl, username, password, remotePath, autoSync}`.
- **Side effects:** None.
- **Algorithm:** Direct field-to-key mapping, no transformation.
- **Usage:**
  ```dart
  await file.writeAsString(jsonEncode(config.toJson()));
  ```
  (`WebDAVService.saveConfig`, same file)
- **Notes:** The password is stored in plain text in this JSON file, same as the rest of local app config.

### `factory WebDAVConfig.fromJson(Map<String, dynamic> json)` <a id="webdavconfig-fromjson"></a>
- **Kind:** factory constructor of `WebDAVConfig`
- **Source:** `lib/shared/services/webdav_service.dart` (line 76)
- **Purpose:** Reconstruct a config from its persisted JSON form.
- **Inputs:** `json` — a decoded `webdav_config.json` map.
- **Returns:** A `WebDAVConfig` with every field defaulted when absent (`''` for strings except `remotePath` which defaults to `/MyAnime`, `false` for `autoSync`).
- **Side effects:** None.
- **Algorithm:** Reads each key with `as String? ?? default` / `as bool? ?? default`; never throws on a missing key.
- **Usage:**
  ```dart
  return WebDAVConfig.fromJson(json);
  ```
  (`WebDAVService.loadConfig`, same file)
- **Notes:** Tolerant of a partially-written or older-format JSON file; unknown extra keys are simply ignored (not preserved, unlike `AnimeData`'s `extraJson` pattern).

### `factory WebDAVConfig.nextcloud(String host, String username, String password)` <a id="webdavconfig-nextcloud"></a>
- **Kind:** factory constructor of `WebDAVConfig`
- **Source:** `lib/shared/services/webdav_service.dart` (line 89)
- **Purpose:** Build a config pre-filled with the standard Nextcloud WebDAV endpoint shape.
- **Inputs:** `host` (e.g. `cloud.example.com`), `username`, `password`.
- **Returns:** A `WebDAVConfig` with `serverUrl` set to `https://$host/remote.php/dav/files/$username` and the default `remotePath`/`autoSync`.
- **Side effects:** None.
- **Algorithm:** Single string interpolation into the well-known Nextcloud WebDAV path convention, then delegates to the default constructor.
- **Usage:** Not called anywhere else in this repo at present (no UI currently offers a Nextcloud quick-setup shortcut; the WebDAV settings page builds `WebDAVConfig` directly from its text fields). Direct use would look like:
  ```dart
  final config = WebDAVConfig.nextcloud('cloud.example.com', 'alice', 'app-password');
  ```
- **Notes:** Dead from an in-repo call-site perspective today — verify before relying on it that the constructed URL still matches the target server's actual WebDAV path if reintroducing a "Nextcloud" quick-connect UI.

### `const SyncResult({required success, error, pending, warnings = const []})` <a id="syncresult-new"></a>
- **Kind:** constructor of `SyncResult`
- **Source:** `lib/shared/services/webdav_service.dart` (line 114)
- **Purpose:** Represent the outcome of any sync/force operation.
- **Inputs:** `success`, optional `error`, optional `pending` (unresolved conflicts), `warnings` (non-fatal per-image failures).
- **Returns:** A new `SyncResult`.
- **Side effects:** None.
- **Algorithm:** Plain field assignment.
- **Usage:**
  ```dart
  result = await WebDAVService.sync(_currentConfig);
  ```
  (`lib/shared/views/webdav_config_page.dart`, `_syncNow`)
- **Notes:** `success` and `pending` are not mutually exclusive at the type level — `_syncLocked` returns `success: true` together with a non-null `pending` when the merge itself succeeded but left record conflicts (see [`sync`](#sync)/[`_syncLocked`](#synclocked)).

### `bool get hasConflicts` <a id="syncresult-hasconflicts-unused"></a>
(Table row only — trivial getter, Tier B; see the Declarations table.)

### `const PendingSync({this.animeMerge})` <a id="pendingsync-new"></a>
- **Kind:** constructor of `PendingSync`
- **Source:** `lib/shared/services/webdav_service.dart` (line 138)
- **Purpose:** Carry an `AnimeMergeResult` with unresolved conflicts across the sync/finalize boundary.
- **Inputs:** Optional `animeMerge`.
- **Returns:** A new `PendingSync`.
- **Side effects:** None.
- **Algorithm:** Plain field assignment.
- **Usage:**
  ```dart
  return SyncResult(
    success: true,
    pending: PendingSync(animeMerge: pendingAnime),
    warnings: imageErrors,
  );
  ```
  (`WebDAVService._syncLocked`, same file)
- **Notes:** Currently only ever holds an anime merge result — the shape allows for other data modules to be added the same way in the future.

### `WebDAVUploadLock({required clientId, required token, required startedAt, required updatedAt, required ttlSeconds})` <a id="webdavuploadlock-new"></a>
- **Kind:** constructor of `WebDAVUploadLock`
- **Source:** `lib/shared/services/webdav_service.dart` (line 161)
- **Purpose:** Represent one client's claim on the remote `.lock` file.
- **Inputs:** `clientId` (stable per-install id), `token` (per-upload-attempt id), `startedAt`/`updatedAt` (UTC), `ttlSeconds`.
- **Returns:** A new `WebDAVUploadLock`.
- **Side effects:** None.
- **Algorithm:** Plain field assignment; callers are responsible for passing UTC `DateTime`s.
- **Usage:**
  ```dart
  final lock = WebDAVUploadLock(
    clientId: clientId,
    token: resumeToken ?? const Uuid().v4(),
    startedAt: now,
    updatedAt: now,
    ttlSeconds: _lockTtlSeconds,
  );
  ```
  (`WebDAVService._acquireUploadSession`, same file)
- **Notes:** `ttlSeconds` is 60 (`_lockTtlSeconds`) for every lock this app writes; see [`../../../sync.md`](../../../sync.md) for the TTL rationale.

### `factory WebDAVUploadLock.fromJson(Map<String, dynamic> json)` <a id="webdavuploadlock-fromjson"></a>
- **Kind:** factory constructor of `WebDAVUploadLock`
- **Source:** `lib/shared/services/webdav_service.dart` (line 174)
- **Purpose:** Parse a lock value out of the remote `.lock` file's JSON.
- **Inputs:** `json`.
- **Returns:** A `WebDAVUploadLock`; `ttlSeconds` falls back to `WebDAVService._lockTtlSeconds` (60) when absent.
- **Side effects:** None.
- **Algorithm:** Reads `clientId`/`token` as required `String`s and `startedAt`/`updatedAt` via `DateTime.parse(...).toUtc()`; throws `TypeError`/`FormatException` if a required field is missing or malformed.
- **Usage:**
  ```dart
  return (
    lock: WebDAVUploadLock.fromJson(json),
    etag: _strongEtag(remote.etag),
    error: null,
  );
  ```
  (`WebDAVService._readRemoteUploadLock`, same file — the `catch` around this call treats a parse failure as "no valid lock", i.e. replaceable)
- **Notes:** Because parse failures propagate as exceptions, every call site wraps this in a `try/catch` and treats failure as "lock missing/stale" rather than aborting sync.

### `Map<String, dynamic> toJson()` <a id="tojson-webdavuploadlock"></a>
- **Kind:** method of `WebDAVUploadLock`
- **Source:** `lib/shared/services/webdav_service.dart` (line 190)
- **Purpose:** Serialize a lock to the exact JSON shape written to the remote `.lock` file.
- **Inputs:** None.
- **Returns:** `{clientId, token, startedAt, updatedAt, ttlSeconds}` with timestamps as UTC ISO-8601 strings.
- **Side effects:** None.
- **Algorithm:** Direct field mapping; both timestamps are explicitly `.toUtc()`'d before formatting so the lock is TTL-comparable regardless of the writer's local timezone.
- **Usage:**
  ```dart
  return _upload(config, _lockFileName, jsonEncode(lock.toJson()), ...);
  ```
  (`WebDAVService._writeRemoteUploadLock`, same file)
- **Notes:** None.

### `bool isExpired(DateTime now)` <a id="isexpired"></a>
- **Kind:** method of `WebDAVUploadLock`
- **Source:** `lib/shared/services/webdav_service.dart` (line 203)
- **Purpose:** Decide whether this lock's TTL has elapsed as of `now`.
- **Inputs:** `now`.
- **Returns:** `true` once `now - updatedAt >= ttlSeconds` (in whole seconds).
- **Side effects:** None.
- **Algorithm:** `now.toUtc().difference(updatedAt.toUtc()).inSeconds >= ttlSeconds`. Uses `updatedAt`, not `startedAt`, so a heartbeat-refreshed lock never expires purely from a long-running transfer.
- **Usage:**
  ```dart
  if (remoteLock.clientId != clientId && !remoteLock.isExpired(now)) { ... }
  ```
  (`WebDAVService._prepareInterruptedUpload`, same file)
- **Notes:** An expired lock is treated as a failed/abandoned upload and may be replaced by any client (see [`../../../sync.md`](../../../sync.md)).

### `bool matches(String clientId, String token)` <a id="matches"></a>
- **Kind:** method of `WebDAVUploadLock`
- **Source:** `lib/shared/services/webdav_service.dart` (line 211)
- **Purpose:** Check whether this lock was issued by a specific client/token pair.
- **Inputs:** `clientId`, `token`.
- **Returns:** `true` iff both fields match exactly.
- **Side effects:** None.
- **Algorithm:** Straight equality on both fields (not just `clientId`), so a stale token from an earlier interrupted attempt by the *same* client never matches a newer session.
- **Usage:**
  ```dart
  if (remoteLock.matches(session.clientId, session.token)) { ... }
  ```
  (`WebDAVService._refreshUploadLock`, same file)
- **Notes:** Used to decide both "can I refresh/delete this lock" and "should I resume this interrupted upload" — see [`_prepareInterruptedUpload`](#prepareinterruptedupload).

### `WebDAVUploadLock refreshed(DateTime updatedAt)` <a id="refreshed"></a>
- **Kind:** method of `WebDAVUploadLock`
- **Source:** `lib/shared/services/webdav_service.dart` (line 219)
- **Purpose:** Produce a copy of this lock with a bumped `updatedAt`, for the heartbeat.
- **Inputs:** `updatedAt` (new UTC timestamp).
- **Returns:** A new `WebDAVUploadLock` with the same `clientId`/`token`/`startedAt`/`ttlSeconds`.
- **Side effects:** None.
- **Algorithm:** Copies every field except `updatedAt`, which is coerced with `.toUtc()`.
- **Usage:**
  ```dart
  final lock = (remoteLock != null && remoteLock.matches(session.clientId, session.token))
      ? remoteLock.refreshed(now)
      : WebDAVUploadLock(...);
  ```
  (`WebDAVService._refreshUploadLock`, same file)
- **Notes:** `startedAt` is preserved across refreshes, so the original acquisition time survives the whole heartbeat lifetime of a session.

### `const RemoteFile.found(String content, {String? etag})` <a id="remotefile-found"></a>
- **Kind:** named constructor of `RemoteFile`
- **Source:** `lib/shared/services/webdav_service.dart` (line 261)
- **Purpose:** Build the "download succeeded" branch of the discriminated `RemoteFile` result.
- **Inputs:** `content`, optional `etag` (from the HTTP response's `etag` header).
- **Returns:** A `RemoteFile` with `status = RemoteFileStatus.found`, `error = null`.
- **Side effects:** None.
- **Algorithm:** Initializer-list assignment; no branching.
- **Usage:**
  ```dart
  if (response.statusCode == 200) {
    return RemoteFile.found(response.body, etag: response.headers['etag']);
  }
  ```
  (`WebDAVService._download`, same file)
- **Notes:** None.

### `const RemoteFile.notFound()` <a id="remotefile-notfound"></a>
- **Kind:** named constructor of `RemoteFile`
- **Source:** `lib/shared/services/webdav_service.dart` (line 270)
- **Purpose:** Build the "HTTP 404 — genuinely missing on remote" branch.
- **Inputs:** None.
- **Returns:** A `RemoteFile` with `status = RemoteFileStatus.notFound`, all other fields `null`.
- **Side effects:** None.
- **Algorithm:** Initializer-list assignment.
- **Usage:**
  ```dart
  if (response.statusCode == 404) return const RemoteFile.notFound();
  ```
  (`WebDAVService._download`, same file)
- **Notes:** This is the *only* outcome sync code may treat as "safe to upload local as new" — see [`../../../sync.md`](../../../sync.md) step 2.

### `const RemoteFile.failure(String error)` <a id="remotefile-failure"></a>
- **Kind:** named constructor of `RemoteFile`
- **Source:** `lib/shared/services/webdav_service.dart` (line 281)
- **Purpose:** Build the "any other failure" branch (auth, server error, network error, timeout).
- **Inputs:** `error` message.
- **Returns:** A `RemoteFile` with `status = RemoteFileStatus.error`, `content`/`etag` null.
- **Side effects:** None.
- **Algorithm:** Initializer-list assignment.
- **Usage:**
  ```dart
  return RemoteFile.failure('HTTP ${response.statusCode}');
  ```
  (`WebDAVService._download`, same file)
- **Notes:** Callers must abort that file's sync on this outcome rather than falling back to "missing", or local data could overwrite a remote file the client simply failed to read.

### `static void _reportProgress(SyncPhase phase, {String? detail, int current = 0, int total = 0})` <a id="reportprogress"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 320)
- **Purpose:** Publish one `SyncProgress` snapshot to the `progress` value notifier.
- **Inputs:** `phase`; optional `detail` (file/image name or error text), `current`/`total` counts.
- **Returns:** None.
- **Side effects:** Sets `WebDAVService.progress.value`, notifying any `ValueListenableBuilder<SyncProgress>`.
- **Algorithm:** Constructs a `SyncProgress` from the arguments and assigns it directly — no debouncing or coalescing.
- **Usage:**
  ```dart
  _reportProgress(SyncPhase.connecting);
  ```
  (`WebDAVService.sync`, same file)
- **Notes:** The UI, not this file, maps `SyncPhase` to localized text (see [`sync_progress.md`](sync_progress.md)).

### `static Future<T> _withRetry<T>(Future<T> Function() attempt, {bool Function(T value)? shouldRetry, int retries = 2})` <a id="withretry"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 342)
- **Purpose:** Retry a network operation on transient failures with linear backoff.
- **Inputs:** `attempt` (the operation), `shouldRetry` (predicate over a successful value, used for HTTP 5xx), `retries` (extra attempts after the first; default 2).
- **Returns:** The last attempt's value, or rethrows its final error.
- **Side effects:** `await`s `Future.delayed(Duration(seconds: attemptIndex))` between attempts.
- **Algorithm:**
  1. Loop with `attemptIndex` starting at 0.
  2. Run `attempt()`. If it returns a value and `shouldRetry(value)` is true and attempts remain, delay `attemptIndex + 1` seconds (i.e. 1s then 2s), increment `attemptIndex`, and loop; otherwise return the value.
  3. If `attempt()` throws, only retry when the exception is transient (`SocketException`, `TimeoutException`, `http.ClientException`, `HttpException`) and attempts remain; otherwise rethrow immediately.
  4. On a retryable exception, delay and loop the same as step 2.
- **Usage:**
  ```dart
  final response = await _withRetry(
    () => http.put(url, headers: {...}, body: utf8.encode(content)).timeout(const Duration(seconds: 30)),
    shouldRetry: (r) => r.statusCode >= 500,
    retries: retries,
  );
  ```
  (`WebDAVService._upload`, same file)
- **Notes:** HTTP 4xx is never retried (callers' `shouldRetry` only checks `>= 500`). See [`../../../sync.md`](../../../sync.md) retry policy for why `.lock` writes pass `retries: 0` at the call site instead of relying on this function's default.

### `static bool consumeLocalDataChanged()` <a id="consumelocaldatachanged"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 375)
- **Purpose:** Report whether the most recent sync/force operation wrote local data or image files, then clear that flag.
- **Inputs:** None.
- **Returns:** `bool` — the flag's value before clearing.
- **Side effects:** Resets the internal `_localDataChanged` flag to `false`.
- **Algorithm:** Read-then-clear in two statements; not atomic across isolates but the app is single-isolate for this state.
- **Usage:**
  ```dart
  if (WebDAVService.consumeLocalDataChanged()) {
    for (final cb in List.of(_onLocalDataChanged)) { cb(); }
  }
  ```
  (`AutoSyncService._trySync`, [`auto_sync_service.md`](auto_sync_service.md))
- **Notes:** One-shot by design — call it exactly once per sync attempt, immediately after the attempt completes, or a reload signal can be silently dropped.

### `static Future<void> _atomicWrite(File file, String content)` <a id="atomicwrite"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 386)
- **Purpose:** Write text to a file without ever leaving a truncated file behind on a crash.
- **Inputs:** `file`, `content`.
- **Returns:** None.
- **Side effects:** Writes `<file>.tmp` then renames it over `file`.
- **Algorithm:** Write `content` to a sibling `.tmp` file, then `rename()` it onto the target path (rename is atomic on the same filesystem).
- **Usage:**
  ```dart
  await _atomicWrite(localFile, remoteRaw);
  ```
  (`WebDAVService._syncLocked`, same file)
- **Notes:** Unlike `BackupService`'s atomic-write helpers (see [`backup_service.md`](backup_service.md)), this one does not uniquify the tmp file name with a timestamp and does not clean up the tmp file on a failed rename — acceptable here because sync writes are always to the same fixed data-file paths.

### `static Future<WebDAVConfig?> loadConfig()` <a id="loadconfig"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 399)
- **Purpose:** Load the persisted WebDAV configuration, if any.
- **Inputs:** None.
- **Returns:** `Future<WebDAVConfig?>` — `null` if the file is missing or unparseable.
- **Side effects:** Reads `webdav_config.json` from the app directory.
- **Algorithm:** Returns `null` if the file doesn't exist; otherwise JSON-decodes it and calls `WebDAVConfig.fromJson`; any exception (including a corrupt file) is caught and also yields `null`.
- **Usage:**
  ```dart
  final config = await WebDAVService.loadConfig();
  if (config == null || !config.isConfigured || !config.autoSync) return;
  ```
  (`AutoSyncService._trySync`, [`auto_sync_service.md`](auto_sync_service.md))
- **Notes:** A corrupt config file is indistinguishable from "not configured" to callers — both just get `null`.

### `static Future<void> saveConfig(WebDAVConfig config)` <a id="saveconfig"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 417)
- **Purpose:** Persist the WebDAV configuration.
- **Inputs:** `config`.
- **Returns:** None.
- **Side effects:** Overwrites `webdav_config.json`.
- **Algorithm:** `jsonEncode(config.toJson())` then a plain (non-atomic) `writeAsString`.
- **Usage:**
  ```dart
  await WebDAVService.saveConfig(config);
  if (config.isConfigured && config.autoSync) {
    AutoSyncService.instance.requestSyncNow();
  }
  ```
  (`lib/shared/views/webdav_config_page.dart`, `_saveConfig`)
- **Notes:** Not atomic (no tmp-then-rename), unlike data-file writes elsewhere in this file.

### `static Future<void> deleteConfig()` <a id="deleteconfig"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 428)
- **Purpose:** Remove the persisted WebDAV configuration (disconnect).
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Deletes `webdav_config.json` if present.
- **Algorithm:** Existence check then `delete()`; no-op if the file is already absent.
- **Usage:**
  ```dart
  await WebDAVService.deleteConfig();
  ```
  (`lib/shared/views/webdav_config_page.dart`)
- **Notes:** Does not touch `.sync_base/` (base snapshots, client id, or any lingering local upload lock) — a subsequent reconnect starts sync fresh against whatever base files remain on disk.

### `static Future<Directory> _getBaseDir()` <a id="getbasedir"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 441)
- **Purpose:** Resolve (creating if necessary) the `.sync_base/` directory used for base snapshots, client id, and the local upload lock.
- **Inputs:** None.
- **Returns:** `Future<Directory>`.
- **Side effects:** Creates `.sync_base/` under the app directory if missing.
- **Algorithm:** Existence check, then `create()` (non-recursive — the app directory itself is assumed to already exist).
- **Usage:**
  ```dart
  final dir = await _getBaseDir();
  final file = File('${dir.path}/$fileName');
  ```
  (`WebDAVService._readBase`, same file)
- **Notes:** None.

### `static Future<String?> _readBase(String fileName)` <a id="readbase"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 453)
- **Purpose:** Read the last-synced base snapshot of a data file, if any.
- **Inputs:** `fileName` (e.g. `anime_data.json`).
- **Returns:** `Future<String?>` — `null` when the base file doesn't exist or can't be read.
- **Side effects:** None (read-only).
- **Algorithm:** Existence check then `readAsString()`; any exception is swallowed to `null`.
- **Usage:**
  ```dart
  final baseJson = await _readBase(name);
  ```
  (`WebDAVService._syncLocked`, same file — feeds the three-way merge)
- **Notes:** A `null` base (first sync, or the base file was deleted) is what makes `mergeRecords`/`mergeAnimeData` treat every record as additive — see [`../../../algorithms/three-way-merge.md`](../../../algorithms/three-way-merge.md).

### `static Future<void> _saveBase(String fileName, String content)` <a id="savebase"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 470)
- **Purpose:** Persist the new base snapshot after a successful sync/upload.
- **Inputs:** `fileName`, `content`.
- **Returns:** None.
- **Side effects:** Writes `.sync_base/<fileName>` atomically.
- **Algorithm:** Delegates straight to [`_atomicWrite`](#atomicwrite).
- **Usage:**
  ```dart
  await _saveBase(name, mergedJson);
  ```
  (`WebDAVService._syncLocked`, same file)
- **Notes:** Per [`../../../sync.md`](../../../sync.md) step 10, this must only be called after the corresponding upload has already succeeded — every call site in this file follows that order.

### `static Future<String> _loadClientId()` <a id="loadclientid"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 481)
- **Purpose:** Load this installation's stable client id, generating one on first use.
- **Inputs:** None.
- **Returns:** `Future<String>` — a UUID v4 string.
- **Side effects:** May create `.sync_base/client_id.txt`.
- **Algorithm:** If the file exists and its trimmed content is non-empty, return it; otherwise generate `const Uuid().v4()`, write it to the file, and return it.
- **Usage:**
  ```dart
  final clientId = await _loadClientId();
  ```
  (`WebDAVService._syncLocked`, same file)
- **Notes:** The client id is local-only — it is never synced/exported, and is the identity used to tell "my lock" from "another device's lock".

### `static Future<WebDAVUploadLock?> _readLocalUploadLock()` <a id="readlocaluploadlock"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 498)
- **Purpose:** Read the local marker left behind before an upload started, used to detect an interrupted upload on the next launch.
- **Inputs:** None.
- **Returns:** `Future<WebDAVUploadLock?>` — `null` if absent or unparseable.
- **Side effects:** None (read-only).
- **Algorithm:** Existence check, JSON-decode, `WebDAVUploadLock.fromJson`; any exception yields `null`.
- **Usage:**
  ```dart
  final localLock = await _readLocalUploadLock();
  if (localLock == null) return (resumeToken: null, error: null);
  ```
  (`WebDAVService._prepareInterruptedUpload`, same file)
- **Notes:** An invalid local lock is silently treated as "no interrupted upload" rather than surfaced as an error.

### `static Future<void> _saveLocalUploadLock(WebDAVUploadLock lock)` <a id="savelocaluploadlock"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 516)
- **Purpose:** Persist the local upload-lock marker before the remote lock write.
- **Inputs:** `lock`.
- **Returns:** None.
- **Side effects:** Writes `.sync_base/upload_lock.json` atomically.
- **Algorithm:** `jsonEncode(lock.toJson())` through [`_atomicWrite`](#atomicwrite).
- **Usage:**
  ```dart
  await _saveLocalUploadLock(lock);
  ```
  (`WebDAVService._acquireUploadSession`, same file)
- **Notes:** This local file, plus the matching remote `.lock`, is what lets [`_prepareInterruptedUpload`](#prepareinterruptedupload) resume the *same* token after a crash instead of contending with itself.

### `static Future<void> _clearLocalUploadLock()` <a id="clearlocaluploadlock"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 527)
- **Purpose:** Remove the local upload-lock marker once it's no longer needed.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Deletes `.sync_base/upload_lock.json` if present.
- **Algorithm:** Existence check then delete; no-op otherwise.
- **Usage:**
  ```dart
  await _clearLocalUploadLock();
  ```
  (`WebDAVService._releaseUploadSession`, same file)
- **Notes:** Called both on normal release and when `_prepareInterruptedUpload` determines a stale/foreign lock should be forgotten.

### `static Map<String, String> _authHeaders(WebDAVConfig config)` <a id="authheaders"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 540)
- **Purpose:** Build the HTTP Basic `Authorization` header for a config.
- **Inputs:** `config`.
- **Returns:** `{'Authorization': 'Basic <base64(username:password)>'}`.
- **Side effects:** None.
- **Algorithm:** `base64Encode(utf8.encode('$username:$password'))`, wrapped in the standard Basic-auth header format.
- **Usage:**
  ```dart
  final response = await http.get(url, headers: _authHeaders(config));
  ```
  (`WebDAVService._download`, same file)
- **Notes:** None.

### `static String _remoteFileUrl(WebDAVConfig config, String fileName)` <a id="remotefileurl"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 552)
- **Purpose:** Build the full URL for a file under the configured remote path.
- **Inputs:** `config`, `fileName`.
- **Returns:** `String` URL.
- **Side effects:** None.
- **Algorithm:** Strips a trailing `/` from `serverUrl`, ensures `remotePath` ends with exactly one `/`, then concatenates `base + path + fileName`.
- **Usage:**
  ```dart
  final url = Uri.parse(_remoteFileUrl(config, fileName));
  ```
  (`WebDAVService._upload`, same file)
- **Notes:** None.

### `static Future<bool> testConnection(WebDAVConfig config)` <a id="testconnection"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 567)
- **Purpose:** Verify the configured server/credentials are reachable, for the "Test connection" button.
- **Inputs:** `config`.
- **Returns:** `Future<bool>`.
- **Side effects:** Sends one PROPFIND request (10s timeout); no local/remote state is written.
- **Algorithm:** Issues a depth-0 PROPFIND on the remote root path; treats both HTTP 207 (Multi-Status, directory exists) and 404 (directory doesn't exist yet, but credentials/server were reachable) as success. Any exception (auth failure, DNS, timeout, etc.) yields `false`.
- **Usage:**
  ```dart
  final ok = await WebDAVService.testConnection(_currentConfig);
  ```
  (`lib/shared/views/webdav_config_page.dart`, `_testConnection`)
- **Notes:** A 404 counting as success means this only validates that the server/credentials respond to WebDAV requests, not that the target directory already exists — `_ensureRemoteDir` creates it separately when sync actually runs.

### `static Future<void> _ensureRemoteDir(WebDAVConfig config)` <a id="ensureremotedir"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 594)
- **Purpose:** Create the configured remote directory if it doesn't already exist.
- **Inputs:** `config`.
- **Returns:** None.
- **Side effects:** Sends one MKCOL request (10s timeout, best-effort).
- **Algorithm:** Issues MKCOL on the remote root path; any failure (including "already exists") is swallowed silently — this call never blocks or fails sync.
- **Usage:**
  ```dart
  await _ensureRemoteDir(config);
  ```
  (`WebDAVService._syncLocked`, same file)
- **Notes:** No retry — a transient MKCOL failure when the directory already exists from a prior run is harmless.

### `static Future<({bool is412, String? error})> _upload(WebDAVConfig config, String fileName, String content, {String? ifMatchEtag, bool ifNoneMatchAll = false, int retries = 2})` <a id="upload"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 615)
- **Purpose:** PUT string content to a remote path, optionally with conditional-request preconditions, used for both data files and the `.lock` file.
- **Inputs:** `config`, `fileName`, `content`; `ifMatchEtag` (conditional update), `ifNoneMatchAll` (conditional create-only), `retries` (0 for `.lock` writes).
- **Returns:** `(is412: bool, error: String?)` — `error == null` on success.
- **Side effects:** One (or more, via retry) HTTP PUT, 30s timeout per attempt.
- **Algorithm:**
  1. Build the URL via [`_remoteFileUrl`](#remotefileurl).
  2. PUT through [`_withRetry`](#withretry), setting `If-Match: <etag>` when `ifMatchEtag` is given and `If-None-Match: *` when `ifNoneMatchAll` is true; retries only on HTTP 5xx (`shouldRetry`).
  3. Map HTTP 412 to `is412: true`; any 2xx to success; anything else to an `HTTP <code>` error string; a thrown exception is caught and stringified into `error`.
- **Usage:**
  ```dart
  return _upload(config, _lockFileName, jsonEncode(lock.toJson()), ifMatchEtag: ifMatchEtag, ifNoneMatchAll: ifNoneMatchAll, retries: 0);
  ```
  (`WebDAVService._writeRemoteUploadLock`, same file)
- **Notes:** Data JSON writes go through [`_uploadWithSession`](#uploadwithsession) instead, which does **not** pass `ifMatchEtag`/`ifNoneMatchAll` — `.lock` is the sole concurrency guard for data uploads (see [`../../../sync.md`](../../../sync.md)).

### `static String? _strongEtag(String? etag)` <a id="strongetag"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 659)
- **Purpose:** Filter an ETag down to only the strong (non-`W/`-prefixed) form usable in lock preconditions.
- **Inputs:** `etag`, possibly `null` or weak.
- **Returns:** `String?` — the etag unchanged if strong, else `null`.
- **Side effects:** None.
- **Algorithm:** Returns `null` if `etag` is `null` or starts with `W/`; otherwise returns it as-is.
- **Usage:**
  ```dart
  return (lock: WebDAVUploadLock.fromJson(json), etag: _strongEtag(remote.etag), error: null);
  ```
  (`WebDAVService._readRemoteUploadLock`, same file)
- **Notes:** Per RFC 9110, `If-Match`/`If-None-Match` require strong comparison; passing a weak ETag as a lock precondition would be semantically wrong, so this function is the single gate all lock ETag usage passes through.

### `static Future<bool> _uploadBytes(WebDAVConfig config, String fileName, Uint8List bytes)` <a id="uploadbytes"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 669)
- **Purpose:** PUT raw bytes (an image) to a remote path.
- **Inputs:** `config`, `fileName`, `bytes`.
- **Returns:** `Future<bool>` — `true` on 2xx.
- **Side effects:** One (or more, via retry) HTTP PUT, 120s timeout per attempt.
- **Algorithm:** PUT through [`_withRetry`](#withretry) (retry on 5xx); throws `Exception('HTTP <code>')` on any non-2xx response rather than returning `false` for it.
- **Usage:**
  ```dart
  return _withLockHeartbeat(config, session, () => _uploadBytes(config, fileName, bytes));
  ```
  (`WebDAVService._uploadBytesWithSession`, same file)
- **Notes:** Unlike [`_upload`](#upload), failures surface as a thrown exception, not a result tuple — callers (`_syncImages`, `_forceUploadImages`) catch it per-image so one failed image doesn't abort the whole sync.

### `static Future<RemoteFile> _download(WebDAVConfig config, String fileName)` <a id="download"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 703)
- **Purpose:** GET a remote data file with a discriminated found/notFound/error outcome.
- **Inputs:** `config`, `fileName`.
- **Returns:** `Future<RemoteFile>`.
- **Side effects:** One (or more, via retry) HTTP GET, 30s timeout per attempt.
- **Algorithm:** GET through [`_withRetry`](#withretry) (retry on 5xx); maps HTTP 200 to `RemoteFile.found(body, etag: ...)`, HTTP 404 to `RemoteFile.notFound()`, anything else (including a thrown exception) to `RemoteFile.failure(...)`.
- **Usage:**
  ```dart
  final remote = await _download(config, name);
  if (remote.status == RemoteFileStatus.error) {
    return SyncResult(success: false, error: 'Failed to download $name from remote: ${remote.error}');
  }
  ```
  (`WebDAVService._syncLocked`, same file)
- **Notes:** This is the function that makes "only HTTP 404 means missing" enforceable throughout sync — see [`../../../sync.md`](../../../sync.md) step 2.

### `static Future<({WebDAVUploadLock? lock, String? etag, String? error})> _readRemoteUploadLock(WebDAVConfig config)` <a id="readremoteuploadlock"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 731)
- **Purpose:** Download and parse the remote `.lock` file.
- **Inputs:** `config`.
- **Returns:** `(lock: WebDAVUploadLock?, etag: String?, error: String?)`.
- **Side effects:** One network GET (via [`_download`](#download)).
- **Algorithm:**
  1. Download `.lock` via `_download`.
  2. A download `error` status short-circuits to `(null, null, error)`.
  3. `notFound` or empty content short-circuits to `(null, null, null)` (no lock held).
  4. Otherwise JSON-decode and `WebDAVUploadLock.fromJson`; a parse failure is treated as "no valid lock" (`lock: null`) rather than an error, still passing through the strong ETag.
- **Usage:**
  ```dart
  final remote = await _readRemoteUploadLock(config);
  if (remote.error != null) return remote.error;
  ```
  (`WebDAVService._refreshUploadLock`, same file)
- **Notes:** A malformed `.lock` file is deliberately treated as replaceable rather than as a blocking error, so a corrupted lock can never permanently wedge sync for every client.

### `static Future<({bool is412, String? error})> _writeRemoteUploadLock(WebDAVConfig config, WebDAVUploadLock lock, {String? ifMatchEtag, bool ifNoneMatchAll = false})` <a id="writeremoteuploadlock"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 756)
- **Purpose:** PUT a lock value to the remote `.lock` file, with the caller supplying the appropriate concurrency precondition.
- **Inputs:** `config`, `lock`; optional `ifMatchEtag`/`ifNoneMatchAll`.
- **Returns:** Same shape as [`_upload`](#upload).
- **Side effects:** One HTTP PUT (never retried — `retries: 0`).
- **Algorithm:** Thin forwarding call to [`_upload`](#upload) with `fileName = _lockFileName`, `content = jsonEncode(lock.toJson())`, and `retries: 0` hard-coded.
- **Usage:**
  ```dart
  final write = await _writeRemoteUploadLock(config, lock, ifMatchEtag: remote.etag, ifNoneMatchAll: remoteLock == null && remote.etag == null);
  ```
  (`WebDAVService._acquireUploadSession`, same file)
- **Notes:** `retries: 0` is deliberate: a retried create-only PUT could otherwise misreport lock contention as if a second client held it (see [`../../../sync.md`](../../../sync.md) retry policy).

### `static Future<void> _deleteRemoteUploadLock(WebDAVConfig config, {String? etag})` <a id="deleteremoteuploadlock"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 777)
- **Purpose:** Remove the remote `.lock` file when this client is done holding it.
- **Inputs:** `config`, optional `etag` (conditional delete).
- **Returns:** None.
- **Side effects:** One HTTP DELETE, 10s timeout, best-effort.
- **Algorithm:** Sends DELETE with `If-Match: <etag>` when supplied; a 404 response and any exception are both silently ignored.
- **Usage:**
  ```dart
  await _deleteRemoteUploadLock(config, etag: remote.etag);
  ```
  (`WebDAVService._releaseUploadSession`, same file)
- **Notes:** Errors are ignored because a lock that fails to delete simply expires after its TTL instead — never worth failing the whole sync over.

### `static Future<({String? resumeToken, String? error})> _prepareInterruptedUpload(WebDAVConfig config, String clientId)` <a id="prepareinterruptedupload"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 798)
- **Purpose:** On sync start, detect whether a previous run of this app was interrupted mid-upload and, if so, prepare to resume with the same lock token instead of contending with itself.
- **Inputs:** `config`, `clientId`.
- **Returns:** `(resumeToken: String?, error: String?)`.
- **Side effects:** May clear the local upload-lock marker via [`_clearLocalUploadLock`](#clearlocaluploadlock).
- **Algorithm:**
  1. Read the local upload-lock marker ([`_readLocalUploadLock`](#readlocaluploadlock)); if none, return `(null, null)` (nothing interrupted).
  2. Read the remote lock ([`_readRemoteUploadLock`](#readremoteuploadlock)); a download error short-circuits to that error.
  3. If the remote lock is now gone (`remoteLock == null`), the previous upload must have completed or the lock expired and was cleared elsewhere — clear the local marker and return `(null, null)`.
  4. If the remote lock still matches `(localLock.clientId, localLock.token)` **and** it's this same `clientId`, return `resumeToken: localLock.token` so the next acquisition reuses the same session instead of creating a new one.
  5. Otherwise, if the remote lock belongs to a different, still-active client, return a blocking error ("Another device is uploading…").
  6. Otherwise (foreign lock but expired, or some other stale state) clear the local marker and return `(null, null)` — normal sync proceeds and acquires a fresh lock.
- **Usage:**
  ```dart
  final interrupted = await _prepareInterruptedUpload(config, clientId);
  if (interrupted.error != null) {
    return SyncResult(success: false, error: interrupted.error);
  }
  ```
  (`WebDAVService._syncLocked`, same file)
- **Notes:** This is what lets a crashed/killed app re-download, re-merge, and re-upload on the next launch instead of blindly retrying a possibly-stale local write (see [`../../../sync.md`](../../../sync.md) step 1).

### `static Future<({_UploadSession? session, String? error})> _acquireUploadSession(WebDAVConfig config, String clientId, {String? resumeToken})` <a id="acquireuploadsession"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 833)
- **Purpose:** Take the remote upload lock before any sync/force operation proceeds.
- **Inputs:** `config`, `clientId`; optional `resumeToken` (from [`_prepareInterruptedUpload`](#prepareinterruptedupload)).
- **Returns:** `(session: _UploadSession?, error: String?)`.
- **Side effects:** Writes the local upload-lock marker and the remote `.lock` file.
- **Algorithm:**
  1. Read the remote lock; a download error short-circuits to that error.
  2. If a remote lock exists, belongs to a different client, and is not expired, return a blocking error.
  3. Otherwise build a new `WebDAVUploadLock` — reusing `resumeToken` if given, else a fresh UUID v4 — with `startedAt = updatedAt = now`.
  4. Write it remotely via [`_writeRemoteUploadLock`](#writeremoteuploadlock), using `ifMatchEtag: remote.etag` (update the existing lock resource) or `ifNoneMatchAll` when there is truly no existing lock resource at all (create-only, prevents a race where two clients both see "no lock" and both try to create one).
  5. On a write failure, translate HTTP 412 specifically into "another device started uploading" (a race was detected); otherwise return the raw error.
  6. On success, persist the same lock locally ([`_saveLocalUploadLock`](#savelocaluploadlock)) and return the new `_UploadSession`.
- **Usage:**
  ```dart
  final acquired = await _acquireUploadSession(config, clientId, resumeToken: interrupted.resumeToken);
  uploadSession = acquired.session;
  if (uploadSession == null) {
    return SyncResult(success: false, error: acquired.error ?? 'Upload lock was not acquired');
  }
  ```
  (`WebDAVService._syncLocked`, same file)
- **Notes:** None beyond the algorithm above.

### `static Future<String?> _refreshUploadLock(WebDAVConfig config, _UploadSession session)` <a id="refreshuploadlock"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 885)
- **Purpose:** Re-write the held lock's timestamp immediately before a PUT, and again periodically during a slow transfer (the heartbeat).
- **Inputs:** `config`, `session`.
- **Returns:** `String?` error, or `null` on success.
- **Side effects:** Writes local + remote lock files with a bumped `updatedAt`.
- **Algorithm:**
  1. Read the remote lock; a download error is returned directly.
  2. If the remote lock exists, doesn't match this `session`, belongs to a different client, and isn't expired, return a blocking error (someone else has taken over the lock).
  3. Otherwise build the refreshed lock: `remoteLock.refreshed(now)` if it still matches this session, else a brand-new `WebDAVUploadLock` for this session (covers the case where the remote lock briefly disappeared).
  4. Write it with the same ETag-precondition logic as [`_acquireUploadSession`](#acquireuploadsession); a 412 becomes "another device started uploading".
  5. On success, persist the refreshed lock locally too.
- **Usage:**
  ```dart
  final lockError = await _refreshUploadLock(config, session);
  if (lockError != null) return (is412: false, error: lockError);
  ```
  (`WebDAVService._uploadWithSession`, same file)
- **Notes:** Called both once before every PUT and every 20 seconds by [`_withLockHeartbeat`](#withlockheartbeat) while a PUT is in flight.

### `static Future<T> _withLockHeartbeat<T>(WebDAVConfig config, _UploadSession session, Future<T> Function() operation)` <a id="withlockheartbeat"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 936)
- **Purpose:** Run a network transfer while periodically refreshing the held lock so a transfer slower than the lock TTL can never let another client treat it as expired.
- **Inputs:** `config`, `session`, `operation` (the in-flight transfer).
- **Returns:** `operation()`'s result.
- **Side effects:** Runs a `Timer.periodic(_lockHeartbeatInterval, ...)` (every 20 seconds) calling [`_refreshUploadLock`](#refreshuploadlock) until `operation` completes.
- **Algorithm:**
  1. Start a periodic timer at `_lockHeartbeatInterval` (20s) that calls `_refreshUploadLock`, guarded by a `refreshing` flag so overlapping ticks can't overlap each other.
  2. `await operation()`.
  3. In `finally`, cancel the timer regardless of success/failure/exception.
  4. Heartbeat refresh failures inside the timer callback are caught and swallowed — they must never abort the transfer that's already in flight.
- **Usage:**
  ```dart
  return _withLockHeartbeat(config, session, () => _upload(config, fileName, content));
  ```
  (`WebDAVService._uploadWithSession`, same file)
- **Notes:** 20s is well under the 60s lock TTL specifically so at least two heartbeats land before expiry even under jitter; see [`../../../sync.md`](../../../sync.md) heartbeat section.

### `static Future<({bool is412, String? error})> _uploadWithSession(WebDAVConfig config, String fileName, String content, _UploadSession session)` <a id="uploadwithsession"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 968)
- **Purpose:** Upload a data file's content while holding and heartbeat-refreshing the upload lock.
- **Inputs:** `config`, `fileName`, `content`, `session`.
- **Returns:** Same shape as [`_upload`](#upload).
- **Side effects:** Network I/O; periodic lock refresh via [`_withLockHeartbeat`](#withlockheartbeat).
- **Algorithm:** Refresh the lock once up front (abort early on failure); then run `_upload(config, fileName, content)` (no data-file preconditions — `.lock` is the sole guard) wrapped in `_withLockHeartbeat`.
- **Usage:**
  ```dart
  final uploadResult = await uploadJson(name, mergedJson);
  ```
  where `uploadJson` (a nested helper in `_syncLocked`) calls `_uploadWithSession(config, fileName, content, session)`.
- **Notes:** Intentionally does not send `If-Match`/`If-None-Match` for the data file itself — only the `.lock` file uses conditional headers.

### `static Future<bool> _uploadBytesWithSession(WebDAVConfig config, String fileName, Uint8List bytes, _UploadSession session)` <a id="uploadbyteswithsession"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 990)
- **Purpose:** Upload image bytes while holding and heartbeat-refreshing the upload lock.
- **Inputs:** `config`, `fileName`, `bytes`, `session`.
- **Returns:** `Future<bool>`.
- **Side effects:** Network I/O; periodic lock refresh.
- **Algorithm:** Refresh the lock once up front, throwing if that fails; then run [`_uploadBytes`](#uploadbytes) wrapped in [`_withLockHeartbeat`](#withlockheartbeat).
- **Usage:**
  ```dart
  await _uploadBytesWithSession(config, 'images/$name', bytes, uploadSession);
  ```
  (`WebDAVService._syncImages`, same file)
- **Notes:** Unlike `_uploadWithSession`, a lock-refresh failure here is raised as a thrown `Exception`, matching `_uploadBytes`'s own throw-on-failure contract.

### `static Future<void> _releaseUploadSession(WebDAVConfig config, _UploadSession? session)` <a id="releaseuploadsession"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 1010)
- **Purpose:** Release the upload lock at the end of a sync/force attempt.
- **Inputs:** `config`, `session` (nullable — no-op if the session was never acquired).
- **Returns:** None.
- **Side effects:** Deletes the local upload-lock marker; deletes the remote `.lock` only if it still belongs to this session.
- **Algorithm:** No-op if `session` is `null`. Otherwise read the remote lock; delete it remotely only if it still `matches(session.clientId, session.token)` (never delete a lock some other client has since taken over); always clear the local marker.
- **Usage:**
  ```dart
  } finally {
    await _releaseUploadSession(config, uploadSession);
  }
  ```
  (`WebDAVService._syncLocked`, same file — always run in `finally`)
- **Notes:** Called in `finally` in every function that acquires a session (`_syncLocked`, `finalizePendingSync`, `_forceUploadLocked`), so completion, failure, and exceptions all release the lock.

### `static Future<Uint8List?> _downloadBytes(WebDAVConfig config, String fileName)` <a id="downloadbytes"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 1027)
- **Purpose:** GET raw bytes (an image) from a remote path.
- **Inputs:** `config`, `fileName`.
- **Returns:** `Future<Uint8List?>` — never actually returns `null` in the current implementation (see Notes).
- **Side effects:** One (or more, via retry) HTTP GET, 120s timeout per attempt.
- **Algorithm:** GET through [`_withRetry`](#withretry) (retry on 5xx); returns `response.bodyBytes` on 200, else throws `Exception('HTTP <code>')`.
- **Usage:**
  ```dart
  final bytes = await _downloadBytes(config, 'images/$name');
  if (bytes != null) {
    await File(p.join(imgDir.path, name)).writeAsBytes(bytes);
  }
  ```
  (`WebDAVService._syncImages`, same file)
- **Notes:** The nullable return type and the `if (bytes != null)` check at call sites are defensive — as written, this function always either returns non-null bytes or throws, it never returns `null` itself. Callers still catch the thrown exception around the whole `await` and add a per-image warning.

### `static Future<Set<String>?> _listRemoteFiles(WebDAVConfig config, String subPath)` <a id="listremotefiles"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 1050)
- **Purpose:** List the file (not subdirectory) names inside a remote subdirectory via PROPFIND.
- **Inputs:** `config`, `subPath` (e.g. `images`).
- **Returns:** `Future<Set<String>?>` — `null` specifically means "listing failed", not "empty directory".
- **Side effects:** One (or more, via retry) PROPFIND request, 15s timeout per attempt.
- **Algorithm:**
  1. Build the subdirectory URL; send a depth-1 PROPFIND requesting `resourcetype` through [`_withRetry`](#withretry) (retry on 5xx).
  2. A non-207 response returns `null`.
  3. Otherwise, regex-extract every `<d:href>` value from the XML body, URL-decode it, skip any href ending in `/` (directories, including the listed directory itself), and collect `p.basename(href)` into a set.
  4. Any exception (malformed XML, network error) is caught and returns `null`.
- **Usage:**
  ```dart
  final remoteNames = await _listRemoteFiles(config, 'images');
  if (remoteNames == null) {
    errors.add('Image sync skipped: could not list the remote images directory');
    return errors;
  }
  ```
  (`WebDAVService._syncImages`, same file)
- **Notes:** The `null`-means-unknown contract is deliberate and load-bearing: treating a failed listing as "empty" previously caused every referenced image to be re-uploaded after a transient PROPFIND failure (see [`../../../sync.md`](../../../sync.md) image-sync section). `_forceUploadImages` instead falls back to "upload everything" on a `null` listing, since force upload must guarantee remote completeness.

### `static Future<void> _ensureRemoteSubDir(WebDAVConfig config, String subPath)` <a id="ensureremotesubdir"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 1099)
- **Purpose:** Create a remote subdirectory (e.g. `images/`) if it doesn't already exist.
- **Inputs:** `config`, `subPath`.
- **Returns:** None.
- **Side effects:** One MKCOL request, 10s timeout, best-effort.
- **Algorithm:** Same shape as [`_ensureRemoteDir`](#ensureremotedir) but targeting `<remotePath>/<subPath>/`; all failures swallowed.
- **Usage:**
  ```dart
  await _ensureRemoteSubDir(config, 'images');
  ```
  (`WebDAVService._syncImages`, same file)
- **Notes:** None.

### `static Set<String> _getReferencedImageNames(String? json)` <a id="getreferencedimagenames"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 1122)
- **Purpose:** Extract the basenames of every cover image referenced by the anime records in a JSON string.
- **Inputs:** `json` — raw `anime_data.json` content, or `null`.
- **Returns:** `Set<String>` — empty if `json` is `null` or unparseable.
- **Side effects:** None.
- **Algorithm:** `null` input returns `{}` immediately; otherwise parse via `AnimeData.fromJson`, map every anime's `coverImage` through `whereType<String>()` (drop nulls) and `p.basename(...)`, collect into a set; any parse exception also yields `{}`.
- **Usage:**
  ```dart
  final referencedImages = {
    ..._getReferencedImageNames(localAnimeJson),
    ..._getReferencedImageNames(remoteAnimeJson),
  };
  ```
  (`WebDAVService._syncLocked`, same file)
- **Notes:** The union of local + remote referenced names (not just one side) is what the sync image phase treats as "referenced" (see [`_syncImages`](#syncimages)).

### `static Future<List<String>> _syncImages(WebDAVConfig config, Directory appDir, Set<String> referencedImages, Future<_UploadSession?> Function() ensureUploadSession)` <a id="syncimages"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 1141)
- **Purpose:** Additively sync only the cover images actually referenced by local or remote anime records, without touching orphaned images.
- **Inputs:** `config`, `appDir`, `referencedImages` (union of local+remote basenames), `ensureUploadSession` (lazily acquires/reuses the upload session, only when an upload is actually needed).
- **Returns:** `Future<List<String>>` — non-fatal per-image warning strings.
- **Side effects:** Creates the local `images/` directory if missing; may upload/download image files; reports `SyncPhase.uploadingImages`/`downloadingImages` progress; may set `_localDataChanged`.
- **Algorithm:**
  1. Return early if `referencedImages` is empty.
  2. Ensure the local `images/` directory and the remote `images/` subdirectory both exist.
  3. Collect local file basenames that are both present on disk and in `referencedImages` (`localNames`) — orphans are skipped.
  4. List remote file names via [`_listRemoteFiles`](#listremotefiles); if that returns `null` (unknown remote state), add one warning and return immediately without transferring anything, rather than assuming "empty".
  5. Upload every name in `localNames` not already in `remoteNames`, one at a time, reporting progress; acquire the session lazily per image via `ensureUploadSession()` and skip (with a warning) if it's unavailable; catch `TimeoutException` and other errors per image into `errors` without aborting the loop.
  6. Download every name in `referencedImages` that's remote but not local, one at a time, reporting progress; on success set `_localDataChanged = true` (so UI reloads even if the data JSON itself was unchanged); catch failures per image into `errors`.
  7. Return the accumulated `errors`.
- **Usage:**
  ```dart
  final imageErrors = await _syncImages(config, appDir, referencedImages, ensureUploadSession);
  ```
  (`WebDAVService._syncLocked`, same file, where the passed `ensureUploadSession` is a nested closure that just returns the already-acquired session)
- **Notes:** See [`../../../sync.md`](../../../sync.md) image-sync section for the full policy (additive-only, union-referenced, no orphan deletion).

### `static Future<SyncResult> sync(WebDAVConfig config, {bool autoResolve = false})` <a id="sync"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 1252)
- **Purpose:** Public entry point for a full merge-based sync cycle.
- **Inputs:** `config`; `autoResolve` (both production callers leave this `false`).
- **Returns:** `Future<SyncResult>`.
- **Side effects:** Everything [`_syncLocked`](#synclocked) does; also sets/clears the `_syncing` guard and reports `connecting`/`done`/`error` progress phases around it.
- **Algorithm:**
  1. If `_syncing` is already `true`, return an immediate `SyncResult(success: false, error: 'Sync already in progress')` — no re-entrant syncs.
  2. Set `_syncing = true`, report `SyncPhase.connecting`.
  3. `await _syncLocked(config, autoResolve: autoResolve)`.
  4. Report `SyncPhase.done` or `SyncPhase.error` (with the result's error as `detail`).
  5. In `finally`, clear `_syncing`.
- **Usage:**
  ```dart
  result = await WebDAVService.sync(_currentConfig);
  ```
  (`lib/shared/views/webdav_config_page.dart`, `_syncNow` — manual sync) and
  ```dart
  final result = await WebDAVService.sync(config);
  ```
  (`AutoSyncService._trySync`, [`auto_sync_service.md`](auto_sync_service.md) — background auto-sync)
- **Notes:** Both call sites omit `autoResolve`, so it defaults to `false` — true two-sided conflicts always surface for manual resolution rather than being silently last-writer-wins resolved (see [`../../../sync.md`](../../../sync.md)).

### `static Future<SyncResult> _syncLocked(WebDAVConfig config, {bool autoResolve = false})` <a id="synclocked"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 1283)
- **Purpose:** Run the full 10-step merge-based sync body; only ever called while `sync()` holds the `_syncing` guard.
- **Inputs:** `config`, `autoResolve`.
- **Returns:** `Future<SyncResult>`.
- **Side effects:** Reads/writes local data files and `.sync_base/` snapshots; performs all the remote lock/download/upload network I/O; publishes progress; may set `_localDataChanged`.
- **Algorithm:** This implements the full flow in [`../../../sync.md`](../../../sync.md); in source order:
  1. `_ensureRemoteDir`, load the app directory and client id.
  2. `_prepareInterruptedUpload` — abort with its error if blocked by another active client.
  3. `_acquireUploadSession` (reusing a resume token if one was found) — abort if the session couldn't be acquired.
  4. Define two nested helpers: `ensureUploadSession()` (returns the already-acquired session) and `uploadJson(fileName, content)` (forwards to [`_uploadWithSession`](#uploadwithsession)).
  5. For each data file name (currently only `anime_data.json`): download the remote copy via [`_download`](#download); a download **error** (not 404) aborts the *entire* sync immediately with a visible error, never falling through to "treat as missing".
  6. If missing on both sides, skip. If only remote has it, write it locally and save the base snapshot (download-as-new). If only local has it, force-upload it under the lock and save the base snapshot (upload-as-new).
  7. If both sides have it and the raw strings are byte-identical, just save the base snapshot (no network write needed).
  8. Otherwise, read the last base snapshot and call `mergeAnimeData(local, remote, base, autoResolve: autoResolve)` (see [`../../../algorithms/three-way-merge.md`](../../../algorithms/three-way-merge.md)). If the result has no conflicts, re-read the local file once more to catch a concurrent user edit made *during* the network I/O above, and re-merge if it changed.
  9. If the (possibly re-)merge still has conflicts, stash the `AnimeMergeResult` as `pendingAnime` and remember `remoteAnimeJson` — nothing is written or uploaded for this file this attempt.
  10. Otherwise, pretty-print the merged `AnimeData` (matching `AnimeStorage`'s local save format so an unchanged file hits the raw-equality fast path next time), atomically write it locally, mark `_localDataChanged`, force-upload it under the lock via `uploadJson`, and save the new base snapshot only after that upload succeeds.
  11. After the data-file loop, compute the referenced-image set as the union of [`_getReferencedImageNames`](#getreferencedimagenames) over the local and remote anime JSON, then run [`_syncImages`](#syncimages).
  12. If there is a `pendingAnime`, return `SyncResult(success: true, pending: PendingSync(animeMerge: pendingAnime), warnings: imageErrors)` — the caller must resolve conflicts via [`finalizePendingSync`](#finalizependingsync). Otherwise return `SyncResult(success: true, warnings: imageErrors)`.
  13. Any exception is caught into `SyncResult(success: false, error: '$e\n$st')`; in `finally`, [`_releaseUploadSession`](#releaseuploadsession) always runs, so the lock is released even when conflicts are left pending (the *next* real upload, `finalizePendingSync`, reacquires it).
- **Usage:**
  ```dart
  final result = await _syncLocked(config, autoResolve: autoResolve);
  ```
  (`WebDAVService.sync`, same file)
- **Notes:** This is the single function implementing sync.md's 10-step flow end-to-end; see that doc for the cross-cutting rationale (why 404-only, why re-read-after-network-IO, why images are additive, etc.).

### `Future<_UploadSession?> ensureUploadSession()` (nested in `_syncLocked`)
(Table row only — trivial local closure, Tier B; see the Declarations table. It exists purely to hand the already-acquired `uploadSession` to [`_syncImages`](#syncimages) through the `Future<_UploadSession?> Function()` callback shape that function expects.)

### `Future<({bool is412, String? error})> uploadJson(String fileName, String content)` (nested in `_syncLocked`)
(Table row only — Tier B; forwards to [`_uploadWithSession`](#uploadwithsession) after checking the outer `uploadSession` is non-null. Its behavior is fully described as part of `_syncLocked`'s algorithm above.)

### `static Future<bool> finalizePendingSync(WebDAVConfig config, PendingSync pending, Map<String, Anime> resolutions)` <a id="finalizependingsync"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 1508)
- **Purpose:** Apply the user's manual conflict resolutions from a prior [`sync`](#sync) attempt and upload the final result.
- **Inputs:** `config`, `pending` (the `PendingSync` returned by `sync`), `resolutions` (conflict ID → chosen `Anime`).
- **Returns:** `Future<bool>` — `false` when acquiring the lock, applying, or uploading the resolution fails.
- **Side effects:** Writes `anime_data.json` locally, force-uploads it under a freshly-reacquired remote lock, and saves the base snapshot only after that upload succeeds.
- **Algorithm:**
  1. Load the app directory and client id; run [`_prepareInterruptedUpload`](#prepareinterruptedupload) again — return `false` if it errors.
  2. [`_acquireUploadSession`](#acquireuploadsession) — return `false` if it fails.
  3. If `pending.animeMerge != null`, build the final `AnimeData` via `pending.animeMerge!.buildResolved(resolutions)` (see [`../../../algorithms/three-way-merge.md`](../../../algorithms/three-way-merge.md) `buildResolved`), pretty-print it, atomically write it locally, mark `_localDataChanged`, force-upload it via [`_uploadWithSession`](#uploadwithsession) — return `false` on upload failure — then save the base snapshot.
  4. Return `true`.
  5. Any exception is caught to `false`; `finally` always releases the upload session.
- **Usage:**
  ```dart
  ok = await WebDAVService.finalizePendingSync(_currentConfig, pending, resolutions);
  ```
  (`lib/shared/views/webdav_config_page.dart`, after the user resolves each conflict dialog)
- **Notes:** Because the base snapshot is only saved after the force-upload succeeds, a failure here leaves the base untouched, so the next `sync()` call re-merges from scratch instead of silently treating the resolution as already synced (see [`../../../sync.md`](../../../sync.md)).

### `static Future<SyncResult> forceUpload(WebDAVConfig config)` <a id="forceupload"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 1563)
- **Purpose:** Public entry point for uploading all local data unconditionally, overwriting the remote copy with no merge or conflict check.
- **Inputs:** `config`.
- **Returns:** `Future<SyncResult>`.
- **Side effects:** Everything [`_forceUploadLocked`](#forceuploadlocked) does; sets/clears `_syncing`; reports progress.
- **Algorithm:** Same `_syncing`-guard/progress-reporting wrapper shape as [`sync`](#sync), delegating the body to `_forceUploadLocked`.
- **Usage:**
  ```dart
  result = await WebDAVService.forceUpload(_currentConfig);
  ```
  (`lib/shared/views/webdav_config_page.dart`, `_forceUpload` — after a destructive-action confirmation dialog) and
  ```dart
  result = await WebDAVService.forceUpload(config);
  ```
  (`lib/features/settings/views/backup_page.dart`, offered after a backup restore — see [`../../../backup-restore.md`](../../../backup-restore.md))
- **Notes:** Remote changes made since the last sync are lost by design; runs under the remote `.lock` and the `_syncing` guard exactly like a normal sync.

### `static Future<SyncResult> _forceUploadLocked(WebDAVConfig config)` <a id="forceuploadlocked"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 1589)
- **Purpose:** Run the force-upload body while `_syncing` is held.
- **Inputs:** `config`.
- **Returns:** `Future<SyncResult>`.
- **Side effects:** Overwrites every remote data file and uploads all referenced images; saves base snapshots.
- **Algorithm:**
  1. `_ensureRemoteDir`, load app dir + client id, `_prepareInterruptedUpload`, `_acquireUploadSession` — abort with the appropriate error on any failure, same as `_syncLocked`.
  2. For each data file: if it exists locally, force-upload its raw content via [`_uploadWithSession`](#uploadwithsession) (no merge, no comparison against remote) — abort on failure; on success, save the local content as the new base (remote now equals local).
  3. Compute referenced images from the local `anime_data.json` only (there is no remote read in this path) and run [`_forceUploadImages`](#forceuploadimages).
  4. Return `SyncResult(success: true, warnings: ...)`; any exception becomes `SyncResult(success: false, error: '$e')`; `finally` always releases the session.
- **Usage:**
  ```dart
  final result = await _forceUploadLocked(config);
  ```
  (`WebDAVService.forceUpload`, same file)
- **Notes:** Unlike `_syncLocked`, this never downloads or reads the remote data file at all — it is a pure overwrite.

### `static Future<List<String>> _forceUploadImages(WebDAVConfig config, Directory appDir, Set<String> referencedImages, _UploadSession session)` <a id="forceuploadimages"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 1664)
- **Purpose:** Upload every referenced local image during a force upload, unconditionally guaranteeing remote completeness.
- **Inputs:** `config`, `appDir`, `referencedImages`, `session` (already acquired, not lazy).
- **Returns:** `Future<List<String>>` — non-fatal per-image warnings.
- **Side effects:** Ensures the remote `images/` directory exists; uploads image bytes; reports progress.
- **Algorithm:**
  1. Return early if `referencedImages` is empty or the local `images/` directory doesn't exist.
  2. Collect local referenced names; list remote names via [`_listRemoteFiles`](#listremotefiles).
  3. If the remote listing failed (`null`), upload **every** local referenced image (can't safely skip any, since force upload must guarantee the remote ends up complete); otherwise upload only the ones missing remotely.
  4. Upload each, reporting progress, catching per-image timeout/other errors into `errors` without aborting.
- **Usage:**
  ```dart
  final warnings = await _forceUploadImages(config, appDir, _getReferencedImageNames(localAnimeJson), uploadSession);
  ```
  (`WebDAVService._forceUploadLocked`, same file)
- **Notes:** Image names are immutable UUIDs, so "already present remotely" is a safe skip condition whenever the listing succeeded.

### `static Future<SyncResult> forceDownload(WebDAVConfig config)` <a id="forcedownload"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 1720)
- **Purpose:** Public entry point for replacing all local data with the remote copy unconditionally, with no merge or conflict check.
- **Inputs:** `config`.
- **Returns:** `Future<SyncResult>`.
- **Side effects:** Everything [`_forceDownloadLocked`](#forcedownloadlocked) does; sets/clears `_syncing`; reports progress.
- **Algorithm:** Same `_syncing`-guard/progress wrapper shape as [`sync`](#sync)/[`forceUpload`](#forceupload), delegating to `_forceDownloadLocked`.
- **Usage:**
  ```dart
  result = await WebDAVService.forceDownload(_currentConfig);
  ```
  (`lib/shared/views/webdav_config_page.dart`, `_forceDownload` — after a destructive-action confirmation dialog)
- **Notes:** Local changes made since the last sync are lost by design. Download-only, so no remote `.lock` is taken — only the `_syncing` guard applies (see [`../../../sync.md`](../../../sync.md) force-operations section).

### `static Future<SyncResult> _forceDownloadLocked(WebDAVConfig config)` <a id="forcedownloadlocked"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 1748)
- **Purpose:** Run the force-download body while `_syncing` is held.
- **Inputs:** `config`.
- **Returns:** `Future<SyncResult>`.
- **Side effects:** Overwrites local data files, downloads referenced images, saves base snapshots, sets `_localDataChanged`.
- **Algorithm:**
  1. For each data file: download it via [`_download`](#download); a download **error** aborts the whole operation with a visible error (never falls back to "keep local"). A `notFound` result adds a warning and keeps the existing local file untouched (nothing to overwrite it with).
  2. Otherwise, JSON-validate the remote content (`jsonDecode`) before writing anything — a non-JSON remote file aborts with an error rather than corrupting the local file.
  3. Atomically write the remote content locally, save it as the new base snapshot, and set `_localDataChanged`.
  4. After the loop, download referenced images via [`_forceDownloadImages`](#forcedownloadimages), using only the remote anime JSON to compute the referenced set (there's no local read involved in deciding what to fetch).
  5. Return `SyncResult(success: true, warnings: ...)`; any exception becomes `SyncResult(success: false, error: '$e')`. No upload session to release — this path is download-only.
- **Usage:**
  ```dart
  final result = await _forceDownloadLocked(config);
  ```
  (`WebDAVService.forceDownload`, same file)
- **Notes:** JSON-validating remote content before writing is the safeguard that prevents a corrupt/non-JSON remote file from clobbering good local data.

### `static Future<List<String>> _forceDownloadImages(WebDAVConfig config, Directory appDir, Set<String> referencedImages)` <a id="forcedownloadimages"></a>
- **Kind:** static method of `WebDAVService`
- **Source:** `lib/shared/services/webdav_service.dart` (line 1809)
- **Purpose:** Download every referenced remote image during a force download, unconditionally.
- **Inputs:** `config`, `appDir`, `referencedImages` (derived from the remote anime JSON only).
- **Returns:** `Future<List<String>>` — non-fatal per-image warnings.
- **Side effects:** Creates the local `images/` directory if missing; writes downloaded image bytes; reports progress; sets `_localDataChanged` on any successful write.
- **Algorithm:**
  1. Return early if `referencedImages` is empty.
  2. List remote file names via [`_listRemoteFiles`](#listremotefiles); if `null` (listing failed), add one warning and return without downloading anything.
  3. Compute the download set as referenced names that exist remotely **and** are not already present locally (`existsSync` check) — image names are immutable UUIDs, so an existing local file is trusted as-is and never re-fetched.
  4. Download each, reporting progress, catching per-image timeout/other errors into `errors` without aborting.
- **Usage:**
  ```dart
  warnings.addAll(await _forceDownloadImages(config, appDir, _getReferencedImageNames(remoteAnimeJson)));
  ```
  (`WebDAVService._forceDownloadLocked`, same file)
- **Notes:** Unlike `_forceUploadImages`, there is no "download everything if listing fails" fallback here — a failed listing just skips the image phase with a warning, since there is no completeness guarantee to protect on the download side.
