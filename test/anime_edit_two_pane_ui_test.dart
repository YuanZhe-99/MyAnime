import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/views/anime_edit_page.dart';
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

/// Purpose: Test the anime edit page's two-pane layout on wide viewports.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: Asserts on geometry rather than on widget types, because the point of
/// the layout is where the fields land: the two titles beside the cover on the
/// left, everything from the season down in the scrolling pane on the right.
/// The `takeException` checks are the ones that matter most — the left pane is
/// declared non-scrolling, so an overflow there would be a real defect.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('myanime_edit_ui');
    final docsDir = Directory(p.join(tempDir.path, 'docs'))
      ..createSync(recursive: true);
    final appDir = Directory(p.join(docsDir.path, 'MyAnime'))
      ..createSync(recursive: true);
    PathProviderPlatform.instance = _FakePathProvider(docsDir.path);

    File(p.join(appDir.path, 'anime_data.json')).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'animes': [
          {
            'id': 'one',
            'title': 'Byousoku 5 Centimeter',
            'titleJa': '秒速5センチメートル',
            'season': 'Season 1',
            'startEpisode': 1,
            'endEpisode': 3,
            'episodeStatuses': const {},
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

  Future<void> openEdit(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: AnimeEditPage(animeId: 'one'),
          ),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
  }

  testWidgets('a Z Fold 8 in landscape puts the titles beside the season', (
    tester,
  ) async {
    await openEdit(tester, const Size(933, 704));

    final title = tester.getTopLeft(find.text('Title'));
    final titleJa = tester.getTopLeft(find.text('Japanese Title'));
    final season = tester.getTopLeft(find.text('Season'));

    // Both titles share the left pane, stacked.
    expect(titleJa.dx, closeTo(title.dx, 0.5));
    expect(titleJa.dy, greaterThan(title.dy));
    // The season is the first field of the right pane.
    expect(season.dx, greaterThan(title.dx + 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a Z Fold 8 in portrait keeps one column', (tester) async {
    await openEdit(tester, const Size(704, 933));

    final title = tester.getTopLeft(find.text('Title'));
    final season = tester.getTopLeft(find.text('Season'));

    expect(season.dx, closeTo(title.dx, 0.5));
    expect(season.dy, greaterThan(title.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the left pane does not overflow at the minimum split height', (
    tester,
  ) async {
    // 600 x 480 is the smallest viewport canSplitLayout admits, and the case
    // editCoverSize's floor has to survive: the cover shrinks rather than the
    // column running off the bottom of a pane that is declared non-scrolling.
    await openEdit(tester, const Size(600, 480));

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Japanese Title'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
