import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/views/management_page.dart';
import 'package:my_anime/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Purpose: Test multi-column list rendering and the long-press action sheet.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: Drives the real management page at the real logical-pixel geometry of
/// the devices named in each case, so a column-count or gesture regression is
/// caught at the size it would actually happen. The management page is the one
/// module whose tile changes shape between layouts — its swipe-to-edit
/// `Dismissible` is dropped once the tiles stop spanning the full width.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsPath);
  final String documentsPath;
  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  const longTitle = '与奔驰于透明之夜的你，谈一场看不见的恋爱，并且这个标题长到列表行里绝对放不下。';

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('myanime_columns_ui');
    final docsDir = Directory(p.join(tempDir.path, 'docs'))
      ..createSync(recursive: true);
    final appDir = Directory(p.join(docsDir.path, 'MyAnime'))
      ..createSync(recursive: true);

    PathProviderPlatform.instance = _FakePathProvider(docsDir.path);

    File(p.join(appDir.path, 'anime_data.json')).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'animes': [
          for (var i = 1; i <= 6; i++)
            {
              'id': 'a$i',
              'title': i == 1 ? longTitle : 'Anime $i',
              'titleJa': i == 1 ? 'とても長い日本語のタイトルです' : null,
              'startEpisode': 1,
              'endEpisode': 12,
              'airDayOfWeek': 1,
              'firstAirDate': '2026-07-06T00:00:00.000Z',
              'episodeStatuses': {'1': 'watched'},
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

  Future<void> pumpAt(WidgetTester tester, double width, double height) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.reset);
    // The page loads from disk through real dart:io, so the first frames have
    // to run outside the binding's fake-async zone or the list never arrives.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: ManagementPage(),
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

  testWidgets('a Z Fold 8 in landscape lays the list out in two columns', (
    tester,
  ) async {
    await pumpAt(tester, 933, 704);
    final tiles = find.byType(ListTile);
    expect(tiles, findsWidgets);
    // Two tiles at the same vertical centre means two columns.
    final first = tester.getCenter(tiles.at(0));
    final second = tester.getCenter(tiles.at(1));
    expect(second.dy, first.dy);
    expect(second.dx, greaterThan(first.dx));
    // Swipe actions are dropped once the tiles stop spanning the full width.
    expect(find.byType(Dismissible), findsNothing);
  });

  testWidgets('the same device in portrait stays on one column', (
    tester,
  ) async {
    await pumpAt(tester, 704, 933);
    final tiles = find.byType(ListTile);
    expect(tiles, findsWidgets);
    final first = tester.getCenter(tiles.at(0));
    final second = tester.getCenter(tiles.at(1));
    expect(second.dy, greaterThan(first.dy));
    expect(second.dx, first.dx);
    // Single column keeps swipe-to-edit and swipe-to-delete.
    expect(find.byType(Dismissible), findsWidgets);
  });

  testWidgets('a phone shows no column control at all', (tester) async {
    await pumpAt(tester, 411, 914);
    expect(find.byIcon(Icons.view_column_outlined), findsNothing);
    expect(find.byType(Dismissible), findsWidgets);
  });

  testWidgets('a wide window offers the column control', (tester) async {
    await pumpAt(tester, 1024, 768);
    expect(find.byIcon(Icons.view_column_outlined), findsOneWidget);
  });

  testWidgets('long-pressing a tile shows the full name and its actions', (
    tester,
  ) async {
    await pumpAt(tester, 411, 914);
    // Long-press the row that actually carries the long title, whatever
    // position the page's quarter grouping puts it in.
    final row = find
        .ancestor(of: find.text(longTitle), matching: find.byType(ListTile))
        .first;
    // The row renders it truncated to a single line.
    expect(tester.widget<Text>(find.text(longTitle).first).maxLines, 1);

    await tester.longPress(row);
    await tester.pumpAndSettle();

    // The sheet renders both stored titles in full, selectable and unclipped.
    final titles = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .toList();
    expect(titles.any((t) => t.data == longTitle), isTrue);
    expect(titles.any((t) => t.data == 'とても長い日本語のタイトルです'), isTrue);
    expect(titles.every((t) => t.maxLines == null), isTrue);

    expect(find.text('Edit Anime'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });
}
