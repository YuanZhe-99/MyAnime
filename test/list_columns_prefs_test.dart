import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/services/anime_storage.dart';
import 'package:my_anime/shared/utils/adaptive_layout.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Purpose: Test that each module's list column preference round-trips and
/// that the default is absent from `storage_config.json` rather than written.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: The three keys must stay independent — the user picks a count per
/// module, and one module's choice must never move another's.
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
    tempDir = await Directory.systemTemp.createTemp('myanime_cols_prefs');
    final docsDir = Directory(p.join(tempDir.path, 'docs'))
      ..createSync(recursive: true);
    Directory(p.join(docsDir.path, 'MyAnime')).createSync(recursive: true);
    configFile = File(
      p.join(docsDir.path, 'MyAnime', 'storage_config.json'),
    );
    PathProviderPlatform.instance = _FakePathProvider(docsDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Map<String, dynamic> readConfig() {
    if (!configFile.existsSync()) return {};
    return jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
  }

  test('every module defaults to auto with nothing stored', () async {
    expect(await AnimeStorage.getHomeListColumns(), listColumnsAuto);
    expect(await AnimeStorage.getManageListColumns(), listColumnsAuto);
    expect(await AnimeStorage.getStatsListColumns(), listColumnsAuto);
  });

  test('a pinned count round-trips per module, independently', () async {
    await AnimeStorage.setHomeListColumns(2);
    await AnimeStorage.setManageListColumns(3);

    expect(await AnimeStorage.getHomeListColumns(), 2);
    expect(await AnimeStorage.getManageListColumns(), 3);
    // Untouched, so still auto.
    expect(await AnimeStorage.getStatsListColumns(), listColumnsAuto);

    final config = readConfig();
    expect(config['homeListColumns'], 2);
    expect(config['manageListColumns'], 3);
    expect(config.containsKey('statsListColumns'), isFalse);
  });

  test('going back to auto removes the key rather than storing it', () async {
    await AnimeStorage.setStatsListColumns(4);
    expect(readConfig()['statsListColumns'], 4);

    await AnimeStorage.setStatsListColumns(listColumnsAuto);
    expect(readConfig().containsKey('statsListColumns'), isFalse);
    expect(await AnimeStorage.getStatsListColumns(), listColumnsAuto);
  });

  test('an out-of-range or malformed stored value falls back to auto', () async {
    configFile.writeAsStringSync(
      jsonEncode({
        'homeListColumns': 99,
        'manageListColumns': 'two',
        'statsListColumns': 0,
      }),
    );
    expect(await AnimeStorage.getHomeListColumns(), listColumnsAuto);
    expect(await AnimeStorage.getManageListColumns(), listColumnsAuto);
    expect(await AnimeStorage.getStatsListColumns(), listColumnsAuto);
  });

  test('writing one preference preserves unrelated config keys', () async {
    configFile.writeAsStringSync(jsonEncode({'themeMode': 'dark'}));
    await AnimeStorage.setHomeListColumns(2);
    final config = readConfig();
    expect(config['themeMode'], 'dark');
    expect(config['homeListColumns'], 2);
  });
}
