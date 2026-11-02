import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/services/anime_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Purpose: Test that the strip widget's text scale is stored apart from the
/// large widget's, and that an install with one shared scale reads as unset.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: An absent `widgetStripTextScale` means "same as the large widget".
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsPath);
  final String documentsPath;
  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File configFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'myanime_widget_scale_prefs',
    );
    final docsDir = Directory(p.join(tempDir.path, 'docs'))
      ..createSync(recursive: true);
    Directory(p.join(docsDir.path, 'MyAnime')).createSync(recursive: true);
    configFile = File(p.join(docsDir.path, 'MyAnime', 'storage_config.json'));
    PathProviderPlatform.instance = _FakePathProvider(docsDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Map<String, dynamic> readConfig() {
    if (!configFile.existsSync()) return {};
    return jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
  }

  test('the strip scale is unset until stored', () async {
    await AnimeStorage.setWidgetTextScale(1.3);
    expect(await AnimeStorage.getWidgetTextScale(), 1.3);
    expect(await AnimeStorage.getWidgetStripTextScale(), isNull);
  });

  test(
    'the two scales are independent, and 1.0 is stored for the strip',
    () async {
      await AnimeStorage.setWidgetTextScale(1.3);
      await AnimeStorage.setWidgetStripTextScale(1.0);
      expect(await AnimeStorage.getWidgetTextScale(), 1.3);
      expect(await AnimeStorage.getWidgetStripTextScale(), 1.0);
      expect(readConfig()['widgetStripTextScale'], 1.0);
    },
  );
}
