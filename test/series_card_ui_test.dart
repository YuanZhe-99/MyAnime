import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/views/anime_detail_page.dart';
import 'package:my_anime/features/anime/views/series_widgets.dart';
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

/// Purpose: Test the detail page's series card in both detail layouts.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: Seeds three seasons of one work whose labels would sort wrongly as
/// strings, plus an unrelated record, and drives the real page.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  Map<String, dynamic> record(String id, String title, String season) => {
    'id': id,
    'title': title,
    'season': season,
    'startEpisode': 1,
    'endEpisode': 12,
    'episodeStatuses': <String, dynamic>{},
    'createdAt': '2026-07-01T00:00:00.000Z',
    'modifiedAt': '2026-07-01T00:00:00.000Z',
  };

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('myanime_series_ui');
    final docsDir = Directory(p.join(tempDir.path, 'docs'))
      ..createSync(recursive: true);
    final appDir = Directory(p.join(docsDir.path, 'MyAnime'))
      ..createSync(recursive: true);
    PathProviderPlatform.instance = _FakePathProvider(docsDir.path);
    File(p.join(appDir.path, 'anime_data.json')).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'animes': [
          record('s1', 'Railgun', 'Season 1'),
          record('s10', 'Railgun', 'Season 10'),
          record('s2', 'Railgun', 'Season 2'),
          record('solo', 'Mushishi', 'Season 1'),
        ],
      }),
    );
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> pumpAt(
    WidgetTester tester,
    double width,
    double height,
    String animeId,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: AnimeDetailPage(animeId: animeId),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
  }

  /// Purpose: Read the member order the series card shows.
  /// Inputs: `tester`.
  /// Returns: `List<String>` — each member's season subtitle, top to bottom.
  /// Side effects: None.
  /// Notes: Test helper.
  List<String> seasonsShown(WidgetTester tester) {
    final tiles = tester.widgetList<ListTile>(
      find.descendant(
        of: find.byType(SeriesCard),
        matching: find.byType(ListTile),
      ),
    );
    return [
      for (final t in tiles) (t.subtitle as Text).data!.split(' · ').first,
    ];
  }

  testWidgets('a phone shows the card in one column, ordered numerically', (
    tester,
  ) async {
    await pumpAt(tester, 412, 915, 's2');
    expect(find.byType(VerticalDivider), findsNothing);
    expect(find.byType(SeriesCard), findsOneWidget);
    expect(seasonsShown(tester), ['Season 1', 'Season 2', 'Season 10']);
    expect(find.text('Prev Season'), findsOneWidget);
    expect(find.text('Next Season'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a split layout puts the card in the right pane', (tester) async {
    await pumpAt(tester, 1024, 768, 's10');
    expect(find.byType(VerticalDivider), findsOneWidget);
    final divider = tester.getTopLeft(find.byType(VerticalDivider)).dx;
    expect(tester.getTopLeft(find.byType(SeriesCard)).dx, greaterThan(divider));
    expect(find.text('Next Season'), findsNothing);
    expect(find.text('Prev Season'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a record in no series has no card and a link menu instead', (
    tester,
  ) async {
    await pumpAt(tester, 412, 915, 'solo');
    expect(find.byType(SeriesCard), findsNothing);
    await tester.tap(find.byIcon(Icons.link));
    await tester.pumpAndSettle();
    expect(find.text('Link to series…'), findsOneWidget);
    expect(find.text('Add next season'), findsOneWidget);
    expect(find.text('Let the app decide'), findsNothing);
  });
}
