import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/shared/services/local_api_server.dart';
import 'package:shelf/shelf.dart';

/// Purpose: Test the local API's browser-origin policy (1.6.7).
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: Drives the real middleware pipeline through `buildHandler` without
/// binding a socket. A web page on another origin must get neither a readable
/// response nor a state-changing request through; non-browser clients (no
/// `Origin` header) keep working unchanged.
void main() {
  group('isAllowedOrigin', () {
    const cases = <String?, bool>{
      null: true,
      'http://localhost': true,
      'http://localhost:3000': true,
      'https://localhost:8443': true,
      'http://LOCALHOST:5173': true,
      'http://127.0.0.1': true,
      'http://127.0.0.1:7788': true,
      'http://127.5.5.5': true,
      'http://[::1]:3000': true,
      'null': false,
      '': false,
      'file:///C:/page.html': false,
      'chrome-extension://abcdefghijklmnop': false,
      'moz-extension://1234-5678': false,
      'http://localhost.evil.com': false,
      'http://evil.com': false,
      'http://evil.com/localhost': false,
      'http://192.168.1.10:7788': false,
      'http://10.0.0.5': false,
      'http://0.0.0.0': false,
      'http://user@localhost': false,
      'ftp://localhost': false,
      'localhost': false,
    };
    cases.forEach((origin, allowed) {
      test('${origin ?? '(no header)'} -> $allowed', () {
        expect(LocalApiServer.isAllowedOrigin(origin), allowed);
      });
    });
  });

  group('pipeline', () {
    final handler = LocalApiServer.buildHandler();

    Future<Response> send(
      String method,
      String path, {
      String? origin,
      String? body,
    }) => Future.value(
      handler(
        Request(
          method,
          Uri.parse('http://localhost:7788$path'),
          headers: {'origin': ?origin},
          body: body,
        ),
      ),
    );

    test('a request without Origin passes and gets no CORS headers', () async {
      final response = await send('GET', '/ping');
      expect(response.statusCode, 200);
      expect(response.headers.containsKey('access-control-allow-origin'), isFalse);
    });

    test('a foreign Origin is rejected for every method', () async {
      for (final method in ['GET', 'POST', 'OPTIONS']) {
        final response = await send(
          method,
          method == 'POST' ? '/anime/add' : '/ping',
          origin: 'http://evil.com',
          body: method == 'POST' ? '{"title":"x"}' : null,
        );
        expect(response.statusCode, 403, reason: method);
        expect(jsonDecode(await response.readAsString()), {
          'error': 'origin not allowed',
        });
        expect(
          response.headers.containsKey('access-control-allow-origin'),
          isFalse,
          reason: method,
        );
      }
    });

    test('the opaque "null" origin is rejected', () async {
      final response = await send('POST', '/anime/add', origin: 'null');
      expect(response.statusCode, 403);
    });

    test('an allowed preflight is answered with the echoed origin', () async {
      final response = await send(
        'OPTIONS',
        '/anime/add',
        origin: 'http://localhost:3000',
      );
      expect(response.statusCode, 200);
      expect(
        response.headers['access-control-allow-origin'],
        'http://localhost:3000',
      );
      expect(response.headers['vary'], 'Origin');
      expect(response.headers['access-control-allow-methods'], contains('POST'));
      expect(
        response.headers['access-control-allow-headers'],
        contains('Authorization'),
      );
    });

    test('an allowed origin on a normal request gets the echo header', () async {
      final response = await send(
        'GET',
        '/ping',
        origin: 'http://127.0.0.1:5173',
      );
      expect(response.statusCode, 200);
      expect(
        response.headers['access-control-allow-origin'],
        'http://127.0.0.1:5173',
      );
      expect(response.headers['access-control-allow-origin'], isNot('*'));
    });
  });
}
