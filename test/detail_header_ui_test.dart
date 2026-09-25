import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// Purpose: Test the 1.6.3 detail-page header: one info line, a separate
/// action row, and categories with an edit icon.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: Runs in the default (full) flavor, so the refresh action shows.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('myanime_detail_header');
    final docs = Directory(p.join(tempDir.path, 'docs'))..createSync();
    final app = Directory(p.join(docs.path, 'MyAnime'))..createSync();
    PathProviderPlatform.instance = _FakePathProvider(docs.path);
    const pretty = JsonEncoder.withIndent('  ');
    File(p.join(app.path, 'anime_data.json')).writeAsStringSync(
      pretty.convert({
        'animes': [
          {
            'id': 'a1',
            'title': 'Seihantai na Kimi to Boku Season 2',
            'titleJa': '正反対な君と僕 第2期',
            'season': 'Season 2',
            'startEpisode': 1,
            'endEpisode': 13,
            'airDayOfWeek': 7,
            'airTime': '21:00',
            'infoUrl': 'https://bangumi.tv/subject/1',
            'watchUrl': 'https://anime1.me/?cat=1',
            'categories': ['romance', 'school'],
            'createdAt': '2026-07-01T00:00:00.000Z',
            'modifiedAt': '2026-07-01T00:00:00.000Z',
          },
        ],
      }),
    );
    File(
      p.join(app.path, 'storage_config.json'),
    ).writeAsStringSync(pretty.convert({'autoCategoriesEnabled': true}));
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> pump(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: AnimeDetailPage(animeId: 'a1'),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
  }

  for (final (name, size) in [
    ('phone', const Size(412, 915)),
    ('two panes', const Size(1280, 800)),
  ]) {
    testWidgets('facts are one line, actions a button row ($name)', (
      tester,
    ) async {
      await pump(tester, size);

      final line = tester.widget<Text>(
        find.byKey(const ValueKey('detailInfoLine')),
      );
      expect(line.data, 'Season 2 · Single Cour · Sun · 21:00');
      // The facts are no longer chips.
      expect(find.widgetWithText(Chip, 'Season 2'), findsNothing);
      expect(find.widgetWithText(Chip, '21:00'), findsNothing);

      // Watch is the one labelled button; Info and Refresh are icons.
      expect(find.widgetWithText(FilledButton, 'Watch'), findsOneWidget);
      expect(find.byTooltip('Info'), findsOneWidget);
      expect(find.byTooltip('Refresh database info'), findsOneWidget);
      expect(find.text('Refresh database info'), findsNothing);
      expect(
        find.byKey(const ValueKey('detailAnime1Progress')),
        findsOneWidget,
      );

      // Categories stay chips; editing is an icon at the end.
      expect(find.widgetWithText(Chip, 'Romance'), findsOneWidget);
      expect(find.byTooltip('Edit categories'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Edit categories'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
