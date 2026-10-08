import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
  Future<void> writeConfig(Map<String, dynamic> value) async {
    config = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'providers, host-specific consent and keys survive restart without joining sync modules',
    () async {
      final dir = await Directory.systemTemp.createTemp('online_sources');
      addTearDown(() => dir.delete(recursive: true));
      final storage = _Storage(dir);
      final sources = createOnlineSources(storage: storage);
      await sources.initialize();
      expect(sources.templates.templates.length, greaterThanOrEqualTo(30));
      const provider = OnlineProvider(
        id: 'provider:test',
        name: 'Test',
        dialect: OnlineDialect.openaiCompatible,
        baseUrl: 'https://example.test/v1',
        modelId: 'example',
        extra: {'future': 'kept'},
      );
      await sources.acknowledge(
        provider.id,
        OnlinePrivacyAcknowledgement(
          noticeVersion: 1,
          acknowledgedAt: DateTime.utc(2026),
          recipientHost: 'example.test',
        ),
      );
      await sources.save(provider, newKey: 'test-key');
      final restored = createOnlineSources(storage: storage);
      await restored.initialize();
      expect(restored.providers.single.extra['future'], 'kept');
      expect(await restored.hasKey(provider.id), isTrue);
      expect(
        restored.privacyNotice(provider)!.keySync,
        OnlineKeySync.deviceOnly,
      );
      expect(
        needsOnlinePrivacyAcknowledgement(
          await restored.acknowledgement(provider.id),
          1,
          recipientHost: 'different.test',
        ),
        isTrue,
      );
      expect(storage.config['unrelated'], 'keep');
      await restored.remove(provider.id);
      expect(await restored.hasKey(provider.id), isFalse);
      expect(restored.providers, isEmpty);
    },
  );
}
