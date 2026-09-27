import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/models/anime.dart';
import 'package:my_anime/features/anime/models/anime_episode.dart';
import 'package:my_anime/features/anime/services/anime_storage.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _Documents extends PathProviderPlatform {
  final String path;
  _Documents(this.path);
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

/// Purpose: Verify the real cache-write boundary against user edits and partial fetches.
/// Inputs: None.
/// Returns: None.
/// Side effects: Isolated temporary app storage, never user data.
/// Notes: No HTTP is needed; simulates completion of delayed network requests.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  const url = 'https://anime1.me/?cat=1';
  final oldTime = DateTime.utc(2025);
  AnimeEpisodeCatalog catalog({bool complete = true, int day = 1}) =>
      AnimeEpisodeCatalog(
        sourceUrl: url,
        categoryUrl: url,
        title: 'Example',
        checkedAt: DateTime.utc(2026, 1, day),
        complete: complete,
        pages: const [
          AnimeEpisodePage(
            url: 'https://anime1.me/1',
            title: 'Example [1]',
            label: '1',
            group: 'Example',
          ),
        ],
      );
  Future<Anime> load() async => (await AnimeStorage.load()).animes.single;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('myanime_episode_storage_');
    PathProviderPlatform.instance = _Documents(temp.path);
    await AnimeStorage.save(
      AnimeData(
        animes: [
          Anime(
            id: 'a',
            title: 'Example',
            watchUrl: url,
            createdAt: oldTime,
            modifiedAt: oldTime,
            episodeMapping: const AnimeEpisodeMapping(
              sourceUrl: url,
              first: 13,
              overrides: {2: 'https://anime1.me/manual'},
            ),
          ),
        ],
      ),
    );
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });

  test(
    'refresh preserves manual choices, unrelated metadata and modifiedAt',
    () async {
      await AnimeStorage.patchExternalMeta({
        'a': const AnimeExternalMeta(genres: ['Comedy']),
      });
      await AnimeStorage.patchExternalMeta(
        {'a': AnimeExternalMeta(episodeCatalog: catalog())},
        expectedWatchUrls: {'a': url},
      );
      final anime = await load();
      expect(anime.modifiedAt, oldTime);
      expect(anime.episodeMapping?.first, 13);
      expect(anime.episodeMapping?.overrides[2], 'https://anime1.me/manual');
      expect(anime.externalMeta?.genres, ['Comedy']);
      expect(anime.externalMeta?.episodeCatalog?.complete, true);
    },
  );

  test(
    'delayed old-source response cannot write after source changes',
    () async {
      await AnimeStorage.addOrUpdate(
        (await load()).copyWith(watchUrl: 'https://anime1.me/?cat=2'),
      );
      final wrote = await AnimeStorage.patchExternalMeta(
        {'a': AnimeExternalMeta(episodeCatalog: catalog())},
        expectedWatchUrls: {'a': url},
      );
      expect(wrote, false);
      expect((await load()).externalMeta?.episodeCatalog, isNull);
    },
  );

  test(
    'partial or older snapshots cannot replace a complete directory',
    () async {
      await AnimeStorage.patchExternalMeta(
        {'a': AnimeExternalMeta(episodeCatalog: catalog(day: 2))},
        expectedWatchUrls: {'a': url},
      );
      for (final replacement in [
        catalog(complete: false, day: 3),
        catalog(day: 1),
      ]) {
        expect(
          await AnimeStorage.patchExternalMeta(
            {'a': AnimeExternalMeta(episodeCatalog: replacement)},
            expectedWatchUrls: {'a': url},
          ),
          false,
        );
      }
      expect(
        (await load()).externalMeta?.episodeCatalog?.checkedAt,
        DateTime.utc(2026, 1, 2),
      );
    },
  );

  test('other metadata writers retain the directory', () async {
    await AnimeStorage.patchExternalMeta(
      {'a': AnimeExternalMeta(episodeCatalog: catalog())},
      expectedWatchUrls: {'a': url},
    );
    await AnimeStorage.patchExternalMeta({
      'a': const AnimeExternalMeta(studios: ['Example Studio']),
    });
    expect((await load()).externalMeta?.episodeCatalog?.pages.length, 1);
  });

  test('refresh retains future catalog and matching page fields', () async {
    final raw = catalog().toJson();
    raw['futureCatalog'] = {'value': 7};
    (raw['pages'] as List).first['futurePage'] = 'kept';
    await AnimeStorage.patchExternalMeta(
      {
        'a': AnimeExternalMeta(
          episodeCatalog: AnimeEpisodeCatalog.fromJson(raw),
        ),
      },
      expectedWatchUrls: {'a': url},
    );
    await AnimeStorage.patchExternalMeta(
      {'a': AnimeExternalMeta(episodeCatalog: catalog(day: 2))},
      expectedWatchUrls: {'a': url},
    );
    final saved = (await load()).externalMeta!.episodeCatalog!.toJson();
    expect(saved['futureCatalog'], {'value': 7});
    expect((saved['pages'] as List).first['futurePage'], 'kept');
    expect((await load()).modifiedAt, oldTime);
  });
}
