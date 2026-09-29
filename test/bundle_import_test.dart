import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/models/anime.dart';
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

/// Purpose: Test .myanimeitem multi-anime bundle export/import format.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: Covers v1 single-anime backward compatibility, v2 multi-anime
/// bundle format, and personal data stripping on export.
void main() {
  const createdAt = '2026-01-01T00:00:00.000Z';
  const modifiedAt = '2026-01-02T00:00:00.000Z';

  Anime makeAnime({
    String id = 'a1',
    String title = 'Test',
    Map<int, EpisodeStatus> episodeStatuses = const {},
  }) {
    return Anime.fromJson({
      'id': id,
      'title': title,
      'season': 'Season 1',
      'startEpisode': 1,
      'endEpisode': 12,
      'episodeStatuses': {
        for (final e in episodeStatuses.entries) e.key.toString(): e.value.name,
      },
      'createdAt': createdAt,
      'modifiedAt': modifiedAt,
    });
  }

  group('.myanimeitem bundle format', () {
    test('v1 single-anime format is backward compatible', () {
      final v1Json = {
        'version': 1,
        'anime': {
          'id': 'original-id',
          'title': 'Single Show',
          'season': 'Season 1',
          'startEpisode': 1,
          'endEpisode': 12,
          'episodeStatuses': {'1': 'watched'},
          'createdAt': createdAt,
          'modifiedAt': modifiedAt,
        },
      };
      expect(v1Json['version'], 1);
      expect(v1Json['anime'], isNotNull);
      final anime = Anime.fromJson(v1Json['anime'] as Map<String, dynamic>);
      expect(anime.title, 'Single Show');
      expect(anime.episodeStatuses[1], EpisodeStatus.watched);
    });

    test('v2 multi-anime bundle contains items list', () {
      final v2Json = {
        'version': 2,
        'items': [
          {
            'anime': {
              'id': 'a1',
              'title': 'Show A',
              'season': 'Season 1',
              'startEpisode': 1,
              'endEpisode': 12,
              'createdAt': createdAt,
              'modifiedAt': modifiedAt,
            },
          },
          {
            'anime': {
              'id': 'a2',
              'title': 'Show B',
              'season': 'Season 1',
              'startEpisode': 1,
              'endEpisode': 24,
              'createdAt': createdAt,
              'modifiedAt': modifiedAt,
            },
          },
        ],
      };
      expect(v2Json['version'], 2);
      final items = v2Json['items'] as List<dynamic>;
      expect(items, hasLength(2));
      final anime0 = Anime.fromJson(items[0]['anime'] as Map<String, dynamic>);
      expect(anime0.title, 'Show A');
      final anime1 = Anime.fromJson(items[1]['anime'] as Map<String, dynamic>);
      expect(anime1.title, 'Show B');
    });

    test('export strips personal viewing data', () {
      final anime =
          makeAnime(
            title: 'Private Show',
            episodeStatuses: {
              1: EpisodeStatus.watched,
              2: EpisodeStatus.skippedThisWeek,
            },
          ).copyWith(
            localArchive: const AnimeLocalArchive(
              archived: true,
              source: ArchiveSource.bd,
              copies: 2,
              location: 'NAS-01',
            ),
          );
      // The archive record is only worth stripping if it was written at all.
      expect(anime.toJson().containsKey('localArchive'), isTrue);

      final json = FileOpenService.stripPersonalData(anime.toJson());
      expect(json.containsKey('episodeStatuses'), isFalse);
      expect(json.containsKey('episodeWeekOffsets'), isFalse);
      // Repository codes and copy counts never leave the user's devices.
      expect(json.containsKey('localArchive'), isFalse);
      // But other fields remain.
      expect(json['title'], 'Private Show');
      expect(json['endEpisode'], 12);
    });

    test('export strips the series link', () {
      final anime = makeAnime(title: 'Linked').copyWith(
        seriesLink: const AnimeSeriesLink(seriesId: 'sid-1', order: 2),
      );
      expect(anime.toJson().containsKey('seriesLink'), isTrue);
      final json = FileOpenService.stripPersonalData(anime.toJson());
      expect(json.containsKey('seriesLink'), isFalse);
      expect(json['title'], 'Linked');
    });

    test('import drops a series link and keeps public metadata', () {
      final parsed = Anime.fromJson({
        ...makeAnime(title: 'Hand-written').toJson(),
        'seriesLink': {'seriesId': 'foreign', 'futureField': 1},
        'externalMeta': {
          'genres': ['Drama'],
        },
        'futureTopLevel': 'keep-me',
      });
      final now = DateTime.utc(2026, 9, 24);
      final imported = FileOpenService.importedCopy(
        parsed,
        id: 'fresh',
        now: now,
      );
      expect(imported.id, 'fresh');
      expect(imported.seriesLink, isNull);
      expect(imported.toJson().containsKey('seriesLink'), isFalse);
      expect(imported.externalMeta?.genres, ['Drama']);
      expect(imported.toJson()['futureTopLevel'], 'keep-me');
      expect(imported.modifiedAt, now);

      final unparseable = Anime.fromJson({
        ...makeAnime(title: 'Odd').toJson(),
        'seriesLink': 'not-an-object',
      });
      expect(
        FileOpenService.importedCopy(
          unparseable,
          id: 'x',
          now: now,
        ).toJson().containsKey('seriesLink'),
        isFalse,
      );
    });

    test('v2 bundle round-trips through JSON', () {
      final animes = [
        makeAnime(id: 'a1', title: 'Alpha'),
        makeAnime(id: 'a2', title: 'Beta'),
      ];
      final items = animes.map((a) {
        final json = a.toJson();
        json.remove('episodeStatuses');
        json.remove('episodeWeekOffsets');
        return {'anime': json};
      }).toList();
      final bundle = <String, dynamic>{'version': 2, 'items': items};
      final encoded = const JsonEncoder.withIndent('  ').convert(bundle);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      expect(decoded['version'], 2);
      final decodedItems = decoded['items'] as List<dynamic>;
      expect(decodedItems, hasLength(2));
    });
  });
  group('import path safety', () {
    test('safeCoverExt accepts a short alphanumeric extension only', () {
      const cases = <Object?, String>{
        '.png': '.png',
        '.JPEG': '.JPEG',
        '.webp': '.webp',
        '.jpg': '.jpg',
        null: '.jpg',
        42: '.jpg',
        '': '.jpg',
        'png': '.jpg',
        '.': '.jpg',
        '.toolong': '.jpg',
        '/../../evil': '.jpg',
        '.p/ng': '.jpg',
        r'.p\ng': '.jpg',
        '.a b': '.jpg',
        '.png\n': '.jpg',
      };
      cases.forEach((input, expected) {
        expect(FileOpenService.safeCoverExt(input), expected, reason: '$input');
      });
    });

    test('isSafeCoverPath allows only images/<plain name>', () {
      const cases = <String?, bool>{
        'images/abc-123.jpg': true,
        'images/a_b.c.png': true,
        null: false,
        '': false,
        'images/': false,
        '/images/a.jpg': false,
        'images/../a.jpg': false,
        'images/..': false,
        'images/sub/a.jpg': false,
        'other/a.jpg': false,
        r'images\a.jpg': false,
        'C:/x/a.jpg': false,
        'images/a b.jpg': false,
      };
      cases.forEach((input, expected) {
        expect(
          FileOpenService.isSafeCoverPath(input),
          expected,
          reason: '$input',
        );
      });
    });

    test('importedCopy drops an unsafe cover but keeps a fresh cover path', () {
      final now = DateTime.utc(2026, 9, 28);
      final hostile = Anime.fromJson({
        ...makeAnime(title: 'Hostile').toJson(),
        'coverImage': '../../secret.png',
      });
      expect(
        FileOpenService.importedCopy(hostile, id: 'x', now: now).coverImage,
        isNull,
      );
      expect(
        FileOpenService.importedCopy(
          hostile,
          id: 'x',
          now: now,
          coverPath: 'images/new.png',
        ).coverImage,
        'images/new.png',
      );
      final plain = Anime.fromJson({
        ...makeAnime(title: 'Plain').toJson(),
        'coverImage': 'images/old.png',
      });
      expect(
        FileOpenService.importedCopy(plain, id: 'x', now: now).coverImage,
        'images/old.png',
      );
    });

    group('discardUnusedCovers', () {
      late Directory tempDir;
      late Directory imagesDir;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('myanime_covers');
        final docs = Directory(p.join(tempDir.path, 'docs'))
          ..createSync(recursive: true);
        imagesDir = Directory(p.join(docs.path, 'MyAnime', 'images'))
          ..createSync(recursive: true);
        PathProviderPlatform.instance = _FakePathProvider(docs.path);
      });

      tearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      test(
        'deletes only covers written for records that were not kept',
        () async {
          for (final name in [
            'kept.png',
            'skipped.png',
            'merged.png',
            'local.png',
          ]) {
            File(p.join(imagesDir.path, name)).writeAsStringSync('x');
          }
          final bundle = ImportBundle(
            animes: [
              Anime.fromJson({
                ...makeAnime(id: 'k').toJson(),
                'coverImage': 'images/kept.png',
              }),
              Anime.fromJson({
                ...makeAnime(id: 's').toJson(),
                'coverImage': 'images/skipped.png',
              }),
              Anime.fromJson({
                ...makeAnime(id: 'm').toJson(),
                'coverImage': 'images/merged.png',
              }),
              // Merely references an existing local cover; nothing was written.
              Anime.fromJson({
                ...makeAnime(id: 'r').toJson(),
                'coverImage': 'images/local.png',
              }),
            ],
            conflictIndices: const [],
            localVersions: const {},
            writtenCovers: const {
              0: 'images/kept.png',
              1: 'images/skipped.png',
              2: 'images/merged.png',
            },
          );
          final merged = Anime.fromJson({
            ...makeAnime(id: 'local-m').toJson(),
            'coverImage': 'images/merged.png',
          });

          final deleted = await FileOpenService.discardUnusedCovers(
            bundle,
            {0},
            [merged],
          );

          expect(deleted, 1);
          bool exists(String n) => File(p.join(imagesDir.path, n)).existsSync();
          expect(exists('kept.png'), isTrue);
          expect(exists('skipped.png'), isFalse);
          expect(exists('merged.png'), isTrue);
          expect(exists('local.png'), isTrue);
        },
      );
    });
  });
}
