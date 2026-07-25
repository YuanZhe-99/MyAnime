// COPIED from MyApps-DATA test/golden/request_recorder.dart (canonical golden harness).
// Keep in sync with the canonical copy; do not edit app-specific behavior here.
/// Purpose: Record the WebDAV request sequence (method, path, headers-that-matter,
/// body) into stable, diff-able golden files for characterization testing.
/// Inputs: HTTP requests observed while wrapped around a `FakeWebDAVServer`.
/// Returns: A canonical text transcript (`toTranscript`) and per-scenario goldens.
/// Side effects: Accumulates an ordered request log in memory; can write goldens.
/// Notes: Volatile values (etags, timestamps, client ids, upload tokens, UUIDs,
/// sha256 blob hashes, absolute temp paths) are normalized to placeholders so the
/// recorded sequence is deterministic across runs and machines. This is the proof
/// surface for PLAN invariants I1-I3.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Purpose: One recorded HTTP request/response exchange.
/// Inputs: All fields via constructor.
/// Returns: An immutable record.
/// Side effects: None.
/// Notes: [body] is stored pre-normalization; normalization happens at render time.
class RecordedExchange {
  /// Purpose: Create a recorded exchange.
  /// Inputs: [method], [path], [requestHeaders], [body], [statusCode].
  /// Returns: A new record.
  /// Side effects: None.
  /// Notes: None.
  RecordedExchange({
    required this.method,
    required this.path,
    required this.requestHeaders,
    required this.body,
    required this.statusCode,
  });

  /// HTTP method (PROPFIND, MKCOL, GET, PUT, DELETE).
  final String method;

  /// Request path (URL-decoded for readability).
  final String path;

  /// Headers that matter to the protocol, already filtered.
  final Map<String, String> requestHeaders;

  /// Request body bytes (empty for GET/DELETE/MKCOL/PROPFIND-depth-0).
  final List<int> body;

  /// Response status code the server returned.
  final int statusCode;
}

/// Purpose: Wrap a `FakeWebDAVServer` (or any client) and record every exchange.
/// Inputs: [inner] the client to delegate to.
/// Returns: Streamed responses from [inner], after recording.
/// Side effects: Appends to [exchanges].
/// Notes: Used with `runWithClient(() => recorder)`.
class RequestRecorder extends http.BaseClient {
  /// Purpose: Create a recorder around [inner].
  /// Inputs: [inner].
  /// Returns: A new recorder.
  /// Side effects: None.
  /// Notes: None.
  RequestRecorder(this.inner);

  /// The wrapped client (the fake server).
  final http.BaseClient inner;

  /// Ordered, observed exchanges.
  final List<RecordedExchange> exchanges = [];

  /// Headers captured when present (case-insensitive lookup by the apps).
  static const List<String> _interestingHeaders = [
    'authorization',
    'depth',
    'content-type',
    'if-match',
    'if-none-match',
  ];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = await request.finalize().toBytes();
    final headers = <String, String>{};
    for (final name in _interestingHeaders) {
      final value = request.headers[name];
      if (value != null) {
        headers[name] = name == 'authorization' ? '<basic-auth>' : value;
      }
    }
    final response = await _sendCopy(request, body);
    exchanges.add(
      RecordedExchange(
        method: request.method,
        path: request.url.path,
        requestHeaders: headers,
        body: body,
        statusCode: response.statusCode,
      ),
    );
    return response;
  }

  /// Purpose: Re-issue the already-consumed request against [inner].
  /// Inputs: [request] (for method/url/headers), [body] the drained bytes.
  /// Returns: The inner client's response.
  /// Side effects: Performs the delegated request.
  /// Notes: `finalize()` may only be read once, so we rebuild a fresh request.
  Future<http.StreamedResponse> _sendCopy(
    http.BaseRequest request,
    List<int> body,
  ) {
    final copy = http.Request(request.method, request.url)
      ..headers.addAll(request.headers);
    if (body.isNotEmpty) {
      copy.bodyBytes = body;
    }
    return inner.send(copy);
  }

  /// Purpose: Clear the recorded exchanges (between scenarios).
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Empties [exchanges].
  /// Notes: None.
  void reset() => exchanges.clear();
}

/// Purpose: Render exchanges into a canonical, normalized golden transcript.
/// Inputs: The recorded [exchanges] and a [scenario] name.
/// Returns: A deterministic string (stable across runs/machines).
/// Side effects: None.
/// Notes: Normalization replaces volatile tokens with stable placeholders so the
/// transcript proves *sequence and shape*, not random values.
class GoldenTranscript {
  /// Purpose: Create a renderer for [exchanges].
  /// Inputs: [exchanges].
  /// Returns: A new renderer.
  /// Side effects: None.
  /// Notes: None.
  GoldenTranscript(this.exchanges);

  /// The exchanges to render.
  final List<RecordedExchange> exchanges;

  /// Purpose: Render the full transcript with volatile values normalized.
  /// Inputs: None.
  /// Returns: Canonical transcript text.
  /// Side effects: None.
  /// Notes: JSON bodies are pretty-printed after normalization for readability.
  String render() {
    final buffer = StringBuffer();
    for (var i = 0; i < exchanges.length; i++) {
      final e = exchanges[i];
      buffer.writeln('=== [$i] ${e.method} ${_normalize(e.path)} -> ${e.statusCode}');
      final sortedHeaderKeys = e.requestHeaders.keys.toList()..sort();
      for (final name in sortedHeaderKeys) {
        buffer.writeln('  $name: ${_normalize(e.requestHeaders[name]!)}');
      }
      if (e.body.isNotEmpty) {
        buffer.writeln('  body:');
        buffer.writeln(_indent(_normalizeBody(e.body)));
      }
    }
    return buffer.toString();
  }

  /// Purpose: Normalize volatile tokens in arbitrary text.
  /// Inputs: [input].
  /// Returns: Text with placeholders substituted.
  /// Side effects: None.
  /// Notes: Order matters: normalize the longest/most-specific patterns first.
  static String _normalize(String input) {
    var out = input;
    out = out.replaceAllMapped(
      RegExp(r'"etag-\d+"'),
      (m) => '"<etag>"',
    );
    out = out.replaceAllMapped(
      RegExp(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
          caseSensitive: false),
      (m) => '<uuid>',
    );
    out = out.replaceAllMapped(
      RegExp(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:?\d{2})?'),
      (m) => '<timestamp>',
    );
    out = out.replaceAllMapped(
      RegExp(r'[0-9a-f]{64}', caseSensitive: false),
      (m) => '<sha256>',
    );
    return out;
  }

  /// Purpose: Normalize a request body, pretty-printing JSON when possible.
  /// Inputs: [body].
  /// Returns: Normalized body text.
  /// Side effects: None.
  /// Notes: Non-JSON bodies (image bytes) are summarized by length+hash so the
  /// golden stays stable without embedding binary.
  static String _normalizeBody(List<int> body) {
    String text;
    try {
      text = utf8.decode(body);
    } catch (_) {
      return '<binary ${body.length} bytes>';
    }
    final trimmed = text.trim();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(text);
        final pretty = const JsonEncoder.withIndent('  ').convert(decoded);
        return _normalize(pretty);
      } catch (_) {
        return _normalize(text);
      }
    }
    // PROPFIND XML bodies and other non-JSON text.
    return _normalize(text);
  }

  /// Purpose: Indent every line of [text] by two spaces for the body block.
  /// Inputs: [text].
  /// Returns: Indented text.
  /// Side effects: None.
  /// Notes: None.
  static String _indent(String text) {
    return text
        .split('\n')
        .map((line) => line.isEmpty ? line : '    $line')
        .join('\n');
  }
}

/// Purpose: Compare or write a golden file for a scenario.
/// Inputs: [goldenFile] path, [actual] freshly rendered transcript.
/// Returns: Match result with a unified-diff-ish message on mismatch.
/// Side effects: Writes the golden when [record] is true.
/// Notes: `record` mode rewrites goldens; verify mode returns pass/fail.
class GoldenMatcher {
  /// Purpose: Create a matcher for [goldenFile].
  /// Inputs: [goldenFile], [record].
  /// Returns: A new matcher.
  /// Side effects: None.
  /// Notes: None.
  GoldenMatcher(this.goldenFile, {this.record = false});

  /// Golden file location.
  final File goldenFile;

  /// When true, write instead of compare.
  final bool record;

  /// Purpose: Assert [actual] matches the golden (or write it in record mode).
  /// Inputs: [actual] transcript text.
  /// Returns: Null on match/record; a mismatch description otherwise.
  /// Side effects: May write [goldenFile] in record mode.
  /// Notes: Returns a string (never throws) so the caller can report all
  /// mismatches across scenarios in one run.
  Future<String?> check(String actual) async {
    if (record) {
      await goldenFile.parent.create(recursive: true);
      await goldenFile.writeAsString(actual);
      return null;
    }
    if (!await goldenFile.exists()) {
      return 'golden missing: ${goldenFile.path} (run with --record to create)';
    }
    final expected = await goldenFile.readAsString();
    if (expected == actual) return null;
    return _diff(expected, actual);
  }

  /// Purpose: Produce a compact first-difference report.
  /// Inputs: [expected], [actual].
  /// Returns: A human-readable mismatch summary.
  /// Side effects: None.
  /// Notes: Reports the first divergent line with context.
  static String _diff(String expected, String actual) {
    final eLines = expected.split('\n');
    final aLines = actual.split('\n');
    final max = eLines.length > aLines.length ? eLines.length : aLines.length;
    for (var i = 0; i < max; i++) {
      final e = i < eLines.length ? eLines[i] : '<eof>';
      final a = i < aLines.length ? aLines[i] : '<eof>';
      if (e != a) {
        return 'first diff at line ${i + 1}:\n  expected: $e\n  actual:   $a';
      }
    }
    return 'transcripts differ';
  }
}
