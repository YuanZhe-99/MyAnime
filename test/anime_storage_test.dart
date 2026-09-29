import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/models/anime.dart';
import 'package:my_anime/features/anime/services/anime_storage.dart';
import 'package:my_anime/shared/services/duplicate_service.dart';
import 'package:my_anime/shared/services/file_open_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Purpose: Point `getApplicationDocumentsDirectory` at a temporary folder.
/// Inputs: `documentsPath`.
/// Returns: None.
/// Side effects: None.
/// Notes: Test double used only by this file.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsPath);
  final String documentsPath;
  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

/// Purpose: Test the serialised write queues of `AnimeStorage`.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: Guards the 1.6.7 fix for load-modify-save races: parallel writers
/// must all persist, unknown top-level fields must survive every bulk
/// operation, and no temporary file may be left behind.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory appDir;

  Anime make(String id, {String title = 'T'}) => Anime.fromJson({
    'id': id,
    'title': title,
    'season': 'Season 1',
    'startEpisode': 1,
    'endEpisode': 12,
    'createdAt': '2026-01-01T00:00:00.000Z',
    'modifiedAt': '2026-01-02T00:00:00.000Z',
  });

  Map<String, dynamic> readData() =>
      jsonDecode(
            File(p.join(appDir.path, 'anime_data.json')).readAsStringSync(),
          )
          as Map<String, dynamic>;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('myanime_storage');
    final docsDir = Directory(p.join(tempDir.path, 'docs'))
      ..createSync(recursive: true);
    appDir = Directory(p.join(docsDir.path, 'MyAnime'))
      ..createSync(recursive: true);
    PathProviderPlatform.instance = _FakePathProvider(docsDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('20 parallel addOrUpdate calls all survive', () async {
    await Future.wait([
      for (var i = 0; i < 20; i++) AnimeStorage.addOrUpdate(make('a$i')),
    ]);
    final data = await AnimeStorage.load();
    expect(data.animes.map((a) => a.id).toSet(), {
      for (var i = 0; i < 20; i++) 'a$i',
    });
  });

  test('parallel config setters all persist', () async {
    await Future.wait([
      AnimeStorage.setThemeMode('dark'),
      AnimeStorage.setLocaleTag('ja'),
      AnimeStorage.setWeekStartDay(1),
      AnimeStorage.setHomeListColumns(3),
      AnimeStorage.setKanaTabEnabled(true),
      AnimeStorage.updateConfig((c) => c['custom'] = 'x'),
    ]);
    final config = await AnimeStorage.readConfig();
    expect(config['themeMode'], 'dark');
    expect(config['locale'], 'ja');
    expect(config['weekStartDay'], 1);
    expect(config['homeListColumns'], 3);
    expect(config['custom'], 'x');
  });

  test('updateRecord computes from the freshly stored record', () async {
    await AnimeStorage.addOrUpdate(make('a1'));
    // A change made after a page loaded its copy must survive the update.
    await AnimeStorage.addOrUpdate(make('a1', title: 'Changed elsewhere'));
    final written = await AnimeStorage.updateRecord(
      'a1',
      (fresh) => fresh.copyWith(rating: const AnimeRating(overall: 9)),
    );
    expect(written, isTrue);
    final stored = (await AnimeStorage.load()).animes.single;
    expect(stored.title, 'Changed elsewhere');
    expect(stored.rating?.overall, 9);
  });

  test(
    'updateRecord with a missing id or a null result writes nothing',
    () async {
      expect(await AnimeStorage.updateRecord('nope', (a) => a), isFalse);
      expect(
        File(p.join(appDir.path, 'anime_data.json')).existsSync(),
        isFalse,
      );

      await AnimeStorage.addOrUpdate(make('a1'));
      final before = File(
        p.join(appDir.path, 'anime_data.json'),
      ).readAsStringSync();
      expect(await AnimeStorage.updateRecord('a1', (a) => null), isFalse);
      expect(
        File(p.join(appDir.path, 'anime_data.json')).readAsStringSync(),
        before,
      );
    },
  );

  test(
    'bundle, replace and delete flows keep unknown top-level fields',
    () async {
      File(p.join(appDir.path, 'anime_data.json')).writeAsStringSync(
        jsonEncode({
          'animes': [make('a1').toJson(), make('a2').toJson()],
          'futureField': {'keep': true},
        }),
      );

      final bundle = ImportBundle(
        animes: [make('n1')],
        conflictIndices: const [],
        localVersions: const {},
      );
      expect(await FileOpenService.applyBundle(bundle), 1);
      expect(readData()['futureField'], {'keep': true});

      await FileOpenService.replaceAnime('a1', make('a1', title: 'Merged'));
      expect(readData()['futureField'], {'keep': true});

      await FileOpenService.deleteAnimeByIds(['a2']);
      final json = readData();
      expect(json['futureField'], {'keep': true});
      expect((json['animes'] as List).map((a) => (a as Map)['id']).toSet(), {
        'a1',
        'n1',
      });
    },
  );

  test(
    'a mixed burst of writers never deadlocks and leaves no temp file',
    () async {
      await Future.wait([
        for (var i = 0; i < 6; i++) AnimeStorage.addOrUpdate(make('a$i')),
        AnimeStorage.updateRecord('a0', (a) => a.copyWith(notes: 'n')),
        AnimeStorage.patchSeasonLabels({'a1': 'Season 2'}),
        AnimeStorage.deleteAnime('a5'),
        AnimeStorage.setThemeMode('light'),
      ]).timeout(const Duration(seconds: 20));
      final leftovers = appDir
          .listSync(recursive: true)
          .where((e) => p.basename(e.path).contains('.tmp'));
      expect(leftovers, isEmpty);
    },
  );
}
