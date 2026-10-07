import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapps_ai/myapps_ai.dart';
import 'package:myapps_ai_online/myapps_ai_online.dart';
import 'package:myapps_data/myapps_data.dart';
import 'package:my_anime/features/ai/services/ai_source_backend.dart';

class _Storage implements StorageAdapter {
  _Storage(this.dir);
  final Directory dir;
  Map<String, dynamic> config = {'unrelated': 'keep'};
  @override
  Future<Directory> getAppDir() async => dir;
  @override
  Future<Map<String, dynamic>> readConfig() async => Map.of(config);
  @override
  Future<void> writeConfig(Map<String, dynamic> value) async =>
      config.addAll(value);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'missing selected model is unavailable without downloading or overwriting config',
    () async {
      final dir = await Directory.systemTemp.createTemp('source_test');
      addTearDown(() => dir.delete(recursive: true));
      final storage = _Storage(dir);
      final backend = AiSourceBackend(storage: storage);
      await backend.initialize();
      expect(await Directory('${dir.path}/ai_models').exists(), isFalse);
      await backend.select('local:qwen3.5-0.8b');
      expect((await backend.statusReport()).status, GenAiStatus.unavailable);
      expect(storage.config['unrelated'], 'keep');
      expect(await Directory('${dir.path}/ai_models').exists(), isFalse);
      final restored = AiSourceBackend(storage: storage);
      await restored.initialize();
      expect(restored.selection.global, 'local:qwen3.5-0.8b');
      expect(restored.catalog.length, 3);
    },
  );

  test(
    'an online source sends the request and reports its own identity',
    () async {
      // The test binding answers every HTTP request with 400; this test
      // talks to its own loopback server.
      final overrides = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = overrides);
      final dir = await Directory.systemTemp.createTemp('source_online');
      addTearDown(() => dir.delete(recursive: true));
      final requests = <(String, String?, Map<String, dynamic>)>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((r) async {
        final body = jsonDecode(await utf8.decodeStream(r)) as Map;
        requests.add((
          r.uri.path,
          r.headers.value('authorization'),
          body.cast<String, dynamic>(),
        ));
        r.response.headers.contentType = ContentType('text', 'event-stream');
        r.response.write(
          'data: ${jsonEncode({
            'choices': [
              {
                'delta': {'content': 'Online answer'},
              },
            ],
          })}\n\n',
        );
        r.response.write(
          'data: ${jsonEncode({
            'choices': [
              {'delta': <String, Object>{}, 'finish_reason': 'stop'},
            ],
          })}\n\ndata: [DONE]\n\n',
        );
        await r.response.close();
      });

      final storage = _Storage(dir);
      final backend = AiSourceBackend(storage: storage);
      await backend.initialize();
      final provider = OnlineProvider(
        id: 'provider:test',
        dialect: OnlineDialect.openaiCompatible,
        baseUrl: 'http://127.0.0.1:${server.port}/v1',
        name: 'Local test',
        modelId: 'test-model',
      );
      await backend.online.save(provider, newKey: 'sk-test');
      await backend.select('provider:test');
      expect(
        (await backend.statusReport()).status,
        GenAiStatus.unavailable,
        reason: 'nothing is sent before the privacy notice is acknowledged',
      );
      expect(requests, isEmpty);

      await backend.online.acknowledge(
        'provider:test',
        OnlinePrivacyAcknowledgement(
          noticeVersion: 1,
          acknowledgedAt: DateTime.now(),
          recipientHost: provider.recipientHost,
        ),
      );
      final report = await backend.statusReport();
      expect(report.status, GenAiStatus.available);
      expect(report.variant, 'provider:test');
      final text = await backend.generate(
        instructions: 'Be brief.',
        prompt: 'Hello',
      );
      expect(text, 'Online answer');
      expect(requests, hasLength(1));
      expect(requests.single.$1, '/v1/chat/completions');
      expect(requests.single.$2, 'Bearer sk-test');
      expect(requests.single.$3['model'], 'test-model');
    },
  );
}
