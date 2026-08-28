import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/views/statistics_page.dart';
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

/// Purpose: Test the statistics page's summary/chart row and filter pairings.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: Asserts on geometry, because both layouts are about where blocks land
/// rather than which widgets exist. The summary row needs the trend chart to
/// have something to plot, so the seed spans two quarters — an empty chart
/// renders nothing and the page falls back to the stacked layout by design.
///
/// Driven in Simplified Chinese on purpose. `flutter_test`'s default font
/// renders every glyph as a full em square, which inflates Latin labels by
/// roughly 2.5x and overflows the ranking filter row at widths where it is
/// comfortable in production — including on the unchanged phone layout. CJK
/// glyphs really are square, so these labels measure close to their real size
/// and the assertions describe the layout users get.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('myanime_stats_ui');
    final docsDir = Directory(p.join(tempDir.path, 'docs'))
      ..createSync(recursive: true);
    final appDir = Directory(p.join(docsDir.path, 'MyAnime'))
      ..createSync(recursive: true);
    PathProviderPlatform.instance = _FakePathProvider(docsDir.path);

    File(p.join(appDir.path, 'anime_data.json')).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'animes': [
          {
            'id': 'a',
            'title': 'Spring Show',
            'season': 'Season 1',
            'startEpisode': 1,
            'endEpisode': 12,
            'firstAirDate': '2026-04-06T00:00:00.000Z',
            'episodeStatuses': <String, dynamic>{},
            'rating': {'overall': 8.0},
            'createdAt': '2026-01-01T00:00:00.000Z',
            'modifiedAt': '2026-01-01T00:00:00.000Z',
          },
          {
            'id': 'b',
            'title': 'Summer Show',
            'season': 'Season 1',
            'startEpisode': 1,
            'endEpisode': 12,
            'firstAirDate': '2026-07-06T00:00:00.000Z',
            'episodeStatuses': <String, dynamic>{},
            'rating': {'overall': 7.0},
            'createdAt': '2026-01-01T00:00:00.000Z',
            'modifiedAt': '2026-01-01T00:00:00.000Z',
          },
        ],
      }),
    );
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> openStats(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('zh'),
            home: StatisticsPage(),
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

  testWidgets('a Z Fold 8 in landscape puts the numbers beside the chart', (
    tester,
  ) async {
    await openStats(tester, const Size(933, 704));

    final watching = tester.getTopLeft(find.text('在追'));
    final notStarted = tester.getTopLeft(find.text('未开始'));
    final trend = tester.getTopLeft(find.text('趋势'));

    // 2x2 grid: the fourth card is below the first and to its right.
    expect(notStarted.dx, greaterThan(watching.dx));
    expect(notStarted.dy, greaterThan(watching.dy));
    // The chart sits to the right of the cards, not under them.
    expect(trend.dx, greaterThan(watching.dx));
    expect(trend.dy, lessThan(notStarted.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a Z Fold 8 in portrait keeps the numbers above the chart', (
    tester,
  ) async {
    await openStats(tester, const Size(704, 933));

    final watching = tester.getTopLeft(find.text('在追'));
    final notStarted = tester.getTopLeft(find.text('未开始'));
    final trend = tester.getTopLeft(find.text('趋势'));

    // One row of four, then the chart beneath it.
    expect(notStarted.dy, closeTo(watching.dy, 0.5));
    expect(trend.dy, greaterThan(watching.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a Z Fold 5 splits, but keeps the numbers above the chart', (
    tester,
  ) async {
    // Passes canSplitLayout and fails the width floor: the chart would be left
    // about 215 logical pixels. The double gate is what keeps it stacked.
    await openStats(tester, const Size(659, 791));

    final watching = tester.getTopLeft(find.text('在追'));
    final notStarted = tester.getTopLeft(find.text('未开始'));

    expect(notStarted.dy, closeTo(watching.dy, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the ranking filters pair up on a wide window', (tester) async {
    await openStats(tester, const Size(933, 704));
    await tester.tap(find.text('排行').first);
    await tester.pumpAndSettle();

    final time = tester.getTopLeft(find.text('时间'));
    final type = tester.getTopLeft(find.text('类型'));
    final sortBy = tester.getTopLeft(find.text('排序依据'));
    final myRating = tester.getTopLeft(find.text('我的评分'));

    // Time and Type share a row; the sort controls share the next one.
    expect(type.dy, closeTo(time.dy, 0.5));
    expect(type.dx, greaterThan(time.dx));
    expect(sortBy.dy, greaterThan(time.dy));
    expect(myRating.dx, lessThan(sortBy.dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a phone in portrait keeps the filters stacked', (tester) async {
    await openStats(tester, const Size(412, 915));
    await tester.tap(find.text('排行').first);
    await tester.pumpAndSettle();

    final time = tester.getTopLeft(find.text('时间'));
    final type = tester.getTopLeft(find.text('类型'));

    expect(type.dx, closeTo(time.dx, 0.5));
    expect(type.dy, greaterThan(time.dy));
    expect(tester.takeException(), isNull);
  });
}
