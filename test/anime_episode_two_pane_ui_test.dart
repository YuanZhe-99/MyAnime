import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/models/anime.dart';
import 'package:my_anime/features/anime/models/anime_episode.dart';
import 'package:my_anime/features/anime/models/playback_progress.dart';
import 'package:my_anime/features/anime/services/anime_storage.dart';
import 'package:my_anime/features/anime/services/playback_progress_store.dart';
import 'package:my_anime/features/anime/views/anime_episode_page.dart';
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

const _source = 'https://anime1.me/?cat=1134';

/// Purpose: Build one catalog page.
/// Inputs: `label`.
/// Returns: `AnimeEpisodePage`.
/// Side effects: None.
/// Notes: Test helper.
AnimeEpisodePage _page(String label) => AnimeEpisodePage(
  url: 'https://anime1.me/$label',
  title: 'Example [$label]',
  label: label,
  group: 'Example',
);

/// Purpose: Test the episode page's two-pane layout and resume rows (1.6.5).
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: The cached directory is complete and fresh, so the page never
/// fetches; `edit: true` suppresses the automatic first playback. Driven in
/// Simplified Chinese, like the other layout tests, because `flutter_test`'s
/// font draws every glyph as a full em square.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('myanime_episode_ui');
    final docs = Directory(p.join(tempDir.path, 'docs'))..createSync();
    PathProviderPlatform.instance = _FakePathProvider(docs.path);
    final t = DateTime.utc(2026, 9, 1);
    await AnimeStorage.save(
      AnimeData(
        animes: [
          Anime(
            id: 'a',
            title: 'Example',
            startEpisode: 1,
            endEpisode: 3,
            watchUrl: _source,
            createdAt: t,
            modifiedAt: t,
            externalMeta: AnimeExternalMeta(
              episodeCatalog: AnimeEpisodeCatalog(
                sourceUrl: _source,
                categoryUrl: _source,
                title: 'Example',
                checkedAt: DateTime.now().toUtc(),
                complete: true,
                pages: [_page('1'), _page('2'), _page('3'), _page('SP')],
              ),
            ),
          ),
        ],
      ),
    );
    await PlaybackProgressStore.put(
      PlaybackProgressEntry(
        key: playbackProgressKey('a', 2),
        animeId: 'a',
        episode: 2,
        positionMs: 40000,
        durationMs: 100000,
        updatedAt: t,
      ),
    );
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> open(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('zh'),
          home: AnimeEpisodeLinksPage(animeId: 'a', edit: true),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
  }

  const mappingPane = ValueKey('episodeMappingPane');
  const tile1 = ValueKey('episodeTile1');

  testWidgets('a Z Fold 8 in landscape puts the episodes beside the form', (
    tester,
  ) async {
    await open(tester, const Size(933, 704));
    expect(find.byKey(mappingPane), findsOneWidget);
    expect(find.byType(VerticalDivider), findsOneWidget);
    final form = tester.getTopLeft(
      find.byType(DropdownButtonFormField<String>),
    );
    final episode = tester.getTopLeft(find.byKey(tile1));
    expect(episode.dx, greaterThan(form.dx + 200));
    expect(find.text('续播 0:40'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a Z Fold 8 in portrait keeps one column', (tester) async {
    await open(tester, const Size(704, 933));
    expect(find.byKey(mappingPane), findsNothing);
    final form = tester.getTopLeft(
      find.byType(DropdownButtonFormField<String>),
    );
    final episode = tester.getTopLeft(find.byKey(tile1));
    expect(episode.dx, lessThan(form.dx + 20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a wide desktop window puts the episodes in two columns', (
    tester,
  ) async {
    await open(tester, const Size(1400, 900));
    final one = tester.getTopLeft(find.byKey(tile1));
    final two = tester.getTopLeft(find.byKey(const ValueKey('episodeTile2')));
    expect(two.dy, closeTo(one.dy, 0.5));
    expect(two.dx, greaterThan(one.dx + 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the smallest splittable window does not overflow', (
    tester,
  ) async {
    await open(tester, const Size(600, 480));
    expect(find.byKey(mappingPane), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
