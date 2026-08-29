import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/models/metadata_update.dart';
import 'package:my_anime/features/anime/services/anime_search_service.dart';
import 'package:my_anime/features/anime/views/metadata_updates_page.dart';
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

/// Purpose: Test the metadata review page's column rule.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: Asserts on geometry, because the change is about where cards land
/// rather than which widgets exist. The page is pushed outside the shell, so
/// the viewport it is given is the whole window — there is no navigation rail
/// to subtract, and the sizes below are raw device geometry.
///
/// Driven in Simplified Chinese on purpose, like the other layout UI tests:
/// `flutter_test`'s default font renders every glyph as a full em square, which
/// inflates Latin labels by roughly 2.5x and overflows rows at widths that are
/// comfortable in production.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('myanime_meta_ui');
    final docsDir = Directory(p.join(tempDir.path, 'docs'))
      ..createSync(recursive: true);
    final appDir = Directory(p.join(docsDir.path, 'MyAnime'))
      ..createSync(recursive: true);
    PathProviderPlatform.instance = _FakePathProvider(docsDir.path);

    // Four records, each with a pending proposal that changes the episode
    // count — enough rows to fill two columns and start a second row.
    final animes = <Map<String, dynamic>>[];
    final entries = <MetadataUpdateEntry>[];
    for (var i = 0; i < 4; i++) {
      final id = 'a$i';
      animes.add({
        'id': id,
        'title': '番剧 $i',
        'season': 'S1',
        'startEpisode': 1,
        'endEpisode': 12,
        'episodeStatuses': <String, dynamic>{},
        'createdAt': '2026-01-01T00:00:00.000Z',
        'modifiedAt': '2026-01-01T00:00:00.000Z',
      });
      entries.add(
        MetadataUpdateEntry(
          animeId: id,
          status: MetadataUpdateStatus.proposed,
          relevance: 0.95,
          candidate: AnimeSearchResult(
            source: 'AniList',
            sourceUrl: 'https://anilist.co/anime/$i',
            title: '番剧 $i',
            episodes: 13,
          ),
        ),
      );
    }

    const encoder = JsonEncoder.withIndent('  ');
    File(
      p.join(appDir.path, 'anime_data.json'),
    ).writeAsStringSync(encoder.convert({'animes': animes}));
    File(p.join(appDir.path, 'metadata_updates.json')).writeAsStringSync(
      encoder.convert(MetadataUpdateStore(entries: entries).toJson()),
    );
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> openPage(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('zh'),
          home: MetadataUpdatesPage(currentPageAnimeIds: []),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
  }

  /// Purpose: Return the on-screen rect of the card carrying a given title.
  /// Inputs: `tester`, `title`.
  /// Returns: `Rect`.
  /// Side effects: None.
  /// Notes: The title `Text` is unique per proposal, so its enclosing `Card` is
  /// the proposal card; `.first` takes the innermost such ancestor.
  Rect cardRect(WidgetTester tester, String title) => tester.getRect(
    find.ancestor(of: find.text(title), matching: find.byType(Card)).first,
  );

  testWidgets('an unfolded Fold 8 in landscape lays the cards out two across', (
    tester,
  ) async {
    await openPage(tester, const Size(933, 704));

    final first = cardRect(tester, '番剧 0');
    final second = cardRect(tester, '番剧 1');
    final third = cardRect(tester, '番剧 2');

    // Left to right, then top to bottom.
    expect(second.left, greaterThan(first.left));
    expect(second.top, closeTo(first.top, 0.5));
    expect(third.left, closeTo(first.left, 0.5));
    expect(third.top, greaterThan(first.top));
    // Neither column is anywhere near the whole window.
    expect(first.width, lessThan(500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the same device in portrait keeps one column', (tester) async {
    // 704 x 933 fails the aspect test, so the capacity is never consulted.
    await openPage(tester, const Size(704, 933));

    final first = cardRect(tester, '番剧 0');
    final second = cardRect(tester, '番剧 1');

    expect(second.left, closeTo(first.left, 0.5));
    expect(second.top, greaterThan(first.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a phone in portrait keeps one column', (tester) async {
    await openPage(tester, const Size(412, 915));

    final first = cardRect(tester, '番剧 0');
    final second = cardRect(tester, '番剧 1');

    expect(second.left, closeTo(first.left, 0.5));
    expect(second.top, greaterThan(first.top));
    expect(tester.takeException(), isNull);
  });
}
