import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_anime/app/flavor.dart';
import 'package:my_anime/features/anime/services/anime1_service.dart';
import 'package:my_anime/features/anime/views/anime_detail_page.dart';
import 'package:my_anime/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Fake application-documents provider (pattern from existing app tests).
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsPath);
  final String documentsPath;
  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

const _source = 'https://anime1.me/?cat=7';

/// Purpose: Render an Anime1 collection archive with the given episodes.
/// Inputs: Episode numbers.
/// Returns: HTML.
/// Side effects: None.
/// Notes: Same markup shape as the live site (checked 2026-09-27).
String _archive(List<int> numbers) =>
    '<body class="archive category category-7">'
    '<h1 class="page-title">Example</h1>'
    '${numbers.map((n) => '<article><h2 class="entry-title"><a href="/$n">Example [$n]</a></h2></article>').join()}'
    '</body>';

/// Purpose: Test that tapping the site progress line refreshes what it shows.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory; mock
/// HTTP only.
/// Notes: 1.6.6. Through 1.6.5 the tap re-read only the index progress, but a
/// mapped label comes from the episode directory, which the 6 h TTL kept
/// from refetching — so the tap changed nothing visible. It also saved the
/// page's snapshot meta, which could put back an older directory.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late File data;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('myanime_recheck');
    final docs = Directory(p.join(tempDir.path, 'docs'))..createSync();
    final app = Directory(p.join(docs.path, 'MyAnime'))..createSync();
    PathProviderPlatform.instance = _FakePathProvider(docs.path);
    Anime1Service.resetIndexCache();
    // A complete directory checked just now, so opening the page does not
    // refetch it on its own.
    final now = DateTime.now().toUtc().toIso8601String();
    data = File(p.join(app.path, 'anime_data.json'))
      ..writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'animes': [
            {
              'id': 'a1',
              'title': 'Example',
              'season': 'Season 1',
              'startEpisode': 1,
              'endEpisode': 12,
              'watchUrl': _source,
              'externalMeta': {
                'episodeCatalog': {
                  'sourceUrl': _source,
                  'categoryUrl': _source,
                  'title': 'Example',
                  'catId': 7,
                  'checkedAt': now,
                  'complete': true,
                  'pages': [
                    for (final n in [1, 2])
                      {
                        'url': 'https://anime1.me/$n',
                        'title': 'Example [$n]',
                        'label': '$n',
                        'group': 'Example',
                      },
                  ],
                },
              },
              'createdAt': '2026-07-01T00:00:00.000Z',
              'modifiedAt': '2026-07-01T00:00:00.000Z',
            },
          ],
        }),
      );
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets(
    'tapping the progress line refreshes the mapped episode',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(412, 915);
      addTearDown(tester.view.reset);
      final status = find.byKey(const ValueKey('detailAnime1Progress'));

      await tester.runAsync(() async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: AnimeDetailPage(animeId: 'a1'),
          ),
        );
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      expect(
        find.descendant(of: status, matching: find.text('Local 2 / Anime1 2')),
        findsOneWidget,
      );

      final client = MockClient((request) async {
        if (request.url.toString() == Anime1Service.indexUrl) {
          return http.Response(
            '[[7,"Example","連載中(03)","2026","夏",""]]',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          _archive([3, 2, 1]),
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      });
      await tester.runAsync(
        () => http.runWithClient(() async {
          await tester.tap(status);
          for (var i = 0; i < 60; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            await tester.pump();
            if (find
                .descendant(
                  of: status,
                  matching: find.byType(CircularProgressIndicator),
                )
                .evaluate()
                .isEmpty) {
              break;
            }
          }
          // Let the reload after the check land.
          for (var i = 0; i < 20; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            await tester.pump();
          }
        }, () => client),
      );

      expect(
        find.descendant(of: status, matching: find.text('Local 3 / Anime1 3')),
        findsOneWidget,
      );
      final saved =
          (jsonDecode(data.readAsStringSync())['animes'] as List).single
              as Map<String, dynamic>;
      final meta = saved['externalMeta'] as Map<String, dynamic>;
      expect((meta['episodeCatalog']['pages'] as List).length, 3);
      expect(meta['watchProgress']['latestEpisode'], 3);
      // Site data never counts as a user edit.
      expect(saved['modifiedAt'], '2026-07-01T00:00:00.000Z');
      expect(tester.takeException(), isNull);
    },
    skip: AppFlavor.isStore,
  );
}
