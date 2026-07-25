// COPIED from MyApps-DATA test/golden/fake_webdav_server.dart (canonical golden harness).
// Keep in sync with the canonical copy; do not edit app-specific behavior here.
/// Purpose: In-memory WebDAV server double for characterization ("golden") tests.
/// Inputs: HTTP requests routed via `runWithClient`.
/// Returns: `http.StreamedResponse` mirroring a real Nextcloud-style WebDAV server.
/// Side effects: Mutates an in-memory file map; records nothing itself (pair with
/// `RequestRecorder`). Fault-injection hooks simulate 404/5xx/timeouts/stale locks.
/// Notes: Byte-faithful to the spec captured from the apps' `webdav_service.dart`
/// (see MyApps-DATA docs/feature-matrix.md §A-§D). Not a network server; intercepts
/// `package:http` calls through the zone-scoped client factory.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Purpose: One stored remote object (a file) with content and a strong ETag.
/// Inputs: [bytes], [etag].
/// Returns: A mutable holder.
/// Side effects: None.
/// Notes: Directories are implicit in path prefixes, not stored as objects.
class FakeRemoteObject {
  /// Purpose: Create a remote object.
  /// Inputs: [bytes] content, [etag] strong ETag (quoted, e.g. `"abc"`).
  /// Returns: A new instance.
  /// Side effects: None.
  /// Notes: None.
  FakeRemoteObject(this.bytes, this.etag);

  /// Raw file bytes.
  List<int> bytes;

  /// Strong, quoted ETag (e.g. `"v1"`). Weak (`W/`) etags are never emitted.
  String etag;

  /// Decoded UTF-8 body, convenience for JSON files.
  String get text => utf8.decode(bytes);
}

/// Purpose: A fault to inject for a specific request matcher.
/// Inputs: [matches] predicate, [respond] factory for the synthetic response.
/// Returns: None.
/// Side effects: None.
/// Notes: Evaluated in registration order; first match wins, before normal handling.
typedef FaultMatcher = bool Function(String method, String path);
typedef FaultResponder = http.StreamedResponse Function();

/// Purpose: In-memory WebDAV server emulating the subset the apps use.
/// Inputs: HTTP requests from `package:http` (any verb the apps send).
/// Returns: `http.StreamedResponse`.
/// Side effects: Mutates [files]; honors injected [faults]; tracks [lockEtag].
/// Notes: Implements PROPFIND (depth 0/1), MKCOL, GET, PUT (with If-Match /
/// If-None-Match and 412), DELETE. Lock semantics mirror the real `.lock` flow.
class FakeWebDAVServer extends http.BaseClient {
  /// Purpose: Create an empty server rooted at [basePath] (e.g. `/dav/files/u`).
  /// Inputs: [basePath] prefix prepended to remote paths; [etagCounterSeed].
  /// Returns: A new server with no files.
  /// Side effects: None.
  /// Notes: Paths are stored keyed by their full request path (no URL-decoding),
  /// matching the apps' non-encoding `_remoteFileUrl`.
  FakeWebDAVServer({this.basePath = ''});

  /// Path prefix that precedes the app remote path in request URLs.
  final String basePath;

  /// In-memory remote file store: full request path -> object.
  final Map<String, FakeRemoteObject> files = {};

  /// Registered fault rules, checked before normal handling.
  final List<({FaultMatcher matches, FaultResponder respond})> _faults = [];

  int _etagCounter = 0;

  /// Purpose: Normalize a request URL to a store key (path only).
  /// Inputs: [url].
  /// Returns: The path used as the map key.
  /// Side effects: None.
  /// Notes: The apps send literal (non-encoded) paths; we key on `url.path` verbatim.
  String _key(Uri url) => url.path;

  /// Purpose: Allocate the next strong, quoted ETag.
  /// Inputs: None.
  /// Returns: A quoted ETag string.
  /// Side effects: Increments the counter.
  /// Notes: Strong etags are required for the apps' lock preconditions.
  String _nextEtag() => '"etag-${++_etagCounter}"';

  /// Purpose: Register a fault rule evaluated before normal request handling.
  /// Inputs: [matches] predicate, [respond] synthetic response factory.
  /// Returns: None.
  /// Side effects: Appends to the fault list.
  /// Notes: Use to simulate 5xx (retry), 404, timeout (throw), or stale locks.
  void injectFault(FaultMatcher matches, FaultResponder respond) {
    _faults.add((matches: matches, respond: respond));
  }

  /// Purpose: Remove all registered faults.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Clears the fault list.
  /// Notes: None.
  void clearFaults() => _faults.clear();

  /// Purpose: Seed a remote file directly (bypassing HTTP).
  /// Inputs: [path] full request path, [content] string or bytes.
  /// Returns: None.
  /// Side effects: Writes to [files].
  /// Notes: Convenience for scenario setup (e.g. pre-existing remote data).
  void seed(String path, Object content) {
    final bytes =
        content is String ? utf8.encode(content) : (content as List<int>);
    files[path] = FakeRemoteObject(bytes, _nextEtag());
  }

  /// Purpose: Read a remote file's text, or null if absent.
  /// Inputs: [path].
  /// Returns: Decoded content or null.
  /// Side effects: None.
  /// Notes: Test assertion helper.
  String? readText(String path) => files[path]?.text;

  /// Purpose: Whether a remote path exists.
  /// Inputs: [path].
  /// Returns: True if present in the store.
  /// Side effects: None.
  /// Notes: None.
  bool exists(String path) => files.containsKey(path);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final method = request.method;
    final path = _key(request.url);

    for (final fault in _faults) {
      if (fault.matches(method, path)) {
        return fault.respond();
      }
    }

    switch (method) {
      case 'PROPFIND':
        return _handlePropfind(request, path);
      case 'MKCOL':
        return _handleMkcol(path);
      case 'GET':
        return _handleGet(path);
      case 'PUT':
        return _handlePut(request, path);
      case 'DELETE':
        return _handleDelete(request, path);
      default:
        return _textResponse(405, 'Method Not Allowed');
    }
  }

  /// Purpose: Handle PROPFIND depth 0 (existence) and depth 1 (listing).
  /// Inputs: [request], [path].
  /// Returns: 207 multistatus for known collections, else 404.
  /// Side effects: None.
  /// Notes: Depth:1 lists direct children as `<d:href>` entries; only the hrefs
  /// matter to the apps' regex parser. Depth:0 returns 207 if the path is a known
  /// collection prefix, 404 otherwise.
  Future<http.StreamedResponse> _handlePropfind(
    http.BaseRequest request,
    String path,
  ) async {
    final depth = request.headers['Depth'] ?? '0';
    final collection = path.endsWith('/') ? path : '$path/';
    final isKnownCollection = files.keys.any((k) => k.startsWith(collection));

    if (depth == '0') {
      // testConnection accepts 207 or 404. Return 207 if the collection (or any
      // child) exists, else 404.
      final existsAsFile = files.containsKey(path);
      if (isKnownCollection || existsAsFile) {
        return _multistatus([_hrefEntry(collection, isCollection: true)]);
      }
      return _textResponse(404, 'Not Found');
    }

    // depth == '1': list direct children of the collection.
    if (!isKnownCollection && !files.containsKey(path)) {
      return _textResponse(404, 'Not Found');
    }
    final entries = <String>[_hrefEntry(collection, isCollection: true)];
    final seen = <String>{};
    for (final key in files.keys) {
      if (!key.startsWith(collection)) continue;
      final rest = key.substring(collection.length);
      if (rest.isEmpty) continue;
      final firstSlash = rest.indexOf('/');
      final childName = firstSlash == -1 ? rest : rest.substring(0, firstSlash);
      if (seen.contains(childName)) continue;
      seen.add(childName);
      final isDir = firstSlash != -1;
      entries.add(_hrefEntry('$collection$childName${isDir ? '/' : ''}',
          isCollection: isDir));
    }
    return _multistatus(entries);
  }

  /// Purpose: Handle MKCOL by recording the collection implicitly (no-op object).
  /// Inputs: [path].
  /// Returns: 201 Created (tolerated statuses are ignored by the apps anyway).
  /// Side effects: None (collections are implicit).
  /// Notes: The apps swallow MKCOL errors entirely.
  http.StreamedResponse _handleMkcol(String path) {
    return _textResponse(201, 'Created');
  }

  /// Purpose: Handle GET by returning file bytes with a strong ETag, or 404.
  /// Inputs: [path].
  /// Returns: 200 with body + ETag, or 404.
  /// Side effects: None.
  /// Notes: The apps treat only 404 as "missing".
  http.StreamedResponse _handleGet(String path) {
    final obj = files[path];
    if (obj == null) return _textResponse(404, 'Not Found');
    return http.StreamedResponse(
      Stream.value(obj.bytes),
      200,
      headers: {'etag': obj.etag, 'content-type': 'application/octet-stream'},
    );
  }

  /// Purpose: Handle PUT with If-Match / If-None-Match preconditions (412 on fail).
  /// Inputs: [request], [path].
  /// Returns: 2xx on success (new ETag assigned), 412 on precondition failure.
  /// Side effects: Writes/updates [files].
  /// Notes: Mirrors the apps' `.lock` conditional-PUT flow and data-file force PUTs.
  Future<http.StreamedResponse> _handlePut(
    http.BaseRequest request,
    String path,
  ) async {
    final body = await request.finalize().toBytes();
    final ifMatch = request.headers['If-Match'];
    final ifNoneMatch = request.headers['If-None-Match'];
    final existing = files[path];

    if (ifNoneMatch == '*' && existing != null) {
      return _textResponse(412, 'Precondition Failed');
    }
    if (ifMatch != null) {
      if (existing == null || existing.etag != ifMatch) {
        return _textResponse(412, 'Precondition Failed');
      }
    }

    files[path] = FakeRemoteObject(body, _nextEtag());
    return _textResponse(existing == null ? 201 : 204, '');
  }

  /// Purpose: Handle DELETE with optional If-Match precondition.
  /// Inputs: [request], [path].
  /// Returns: 204 on delete, 404 if absent, 412 on precondition failure.
  /// Side effects: Removes from [files].
  /// Notes: Used only for the `.lock` file by the apps.
  http.StreamedResponse _handleDelete(http.BaseRequest request, String path) {
    final ifMatch = request.headers['If-Match'];
    final existing = files[path];
    if (existing == null) return _textResponse(404, 'Not Found');
    if (ifMatch != null && existing.etag != ifMatch) {
      return _textResponse(412, 'Precondition Failed');
    }
    files.remove(path);
    return _textResponse(204, 'No Content');
  }

  /// Purpose: Build a minimal multistatus XML body from href entries.
  /// Inputs: [entries] pre-rendered `<d:response>` blocks.
  /// Returns: 207 response with `application/xml` body.
  /// Side effects: None.
  /// Notes: Only `<d:href>` tags are consumed by the apps; propstat is decorative.
  http.StreamedResponse _multistatus(List<String> entries) {
    final body = StringBuffer()
      ..write('<?xml version="1.0" encoding="utf-8"?>')
      ..write('<d:multistatus xmlns:d="DAV:">');
    for (final e in entries) {
      body.write(e);
    }
    body.write('</d:multistatus>');
    return http.StreamedResponse(
      Stream.value(utf8.encode(body.toString())),
      207,
      headers: {'content-type': 'application/xml; charset=utf-8'},
    );
  }

  /// Purpose: Render one `<d:response>` entry with an href.
  /// Inputs: [href], [isCollection].
  /// Returns: XML fragment string.
  /// Side effects: None.
  /// Notes: Hrefs are full paths because the apps take `p.basename(href)`.
  String _hrefEntry(String href, {required bool isCollection}) {
    final rt = isCollection
        ? '<d:resourcetype><d:collection/></d:resourcetype>'
        : '<d:resourcetype/>';
    return '<d:response><d:href>$href</d:href>'
        '<d:propstat><d:prop>$rt</d:prop>'
        '<d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>';
  }

  /// Purpose: Build a plain-text response.
  /// Inputs: [status], [body].
  /// Returns: Streamed response.
  /// Side effects: None.
  /// Notes: None.
  http.StreamedResponse _textResponse(int status, String body) {
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      status,
      headers: {'content-type': 'text/plain'},
    );
  }
}

/// Purpose: Convenience fault factories for the scenarios.
/// Inputs: Various.
/// Returns: `http.StreamedResponse` factories.
/// Side effects: None.
/// Notes: Timeouts are modeled by throwing, which the apps' `_withRetry` catches.
class Faults {
  /// Purpose: A 500 response (retryable by the apps).
  /// Inputs: None.
  /// Returns: Fault responder.
  /// Side effects: None.
  /// Notes: Triggers the apps' `shouldRetry: statusCode >= 500` path.
  static FaultResponder serverError() => () => http.StreamedResponse(
        Stream.value(utf8.encode('Internal Server Error')),
        500,
      );

  /// Purpose: A 404 response.
  /// Inputs: None.
  /// Returns: Fault responder.
  /// Side effects: None.
  /// Notes: Models a missing resource independent of the store.
  static FaultResponder notFound() => () => http.StreamedResponse(
        Stream.value(utf8.encode('Not Found')),
        404,
      );

  /// Purpose: A responder that throws a timeout (transient, retryable).
  /// Inputs: None.
  /// Returns: Fault responder.
  /// Side effects: Throws.
  /// Notes: Matches the apps' retryable `TimeoutException` path.
  static FaultResponder timeout() => () =>
      throw TimeoutException('simulated timeout', const Duration(seconds: 5));
}
