import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
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

/// Purpose: Test the ranking view's own-rating vs database score source.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: Seeds one anime rated only by the user and one scored only by a
/// database, so switching the source has to change which rows appear at all —
/// a reordering assertion alone would pass even if the switch did nothing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  Map<String, dynamic> anime(
    String id,
    String title, {
    Map<String, dynamic>? rating,
    List<Map<String, dynamic>>? ratings,
  }) => {
    'id': id,
    'title': title,
    'season': 'Season 1',
    'startEpisode': 1,
    'endEpisode': 12,
    'firstAirDate': '2026-07-06T00:00:00.000Z',
    'episodeStatuses': const {},
    'rating': ?rating,
    if (ratings != null) 'externalMeta': {'ratings': ratings},
    'createdAt': '2026-07-01T00:00:00.000Z',
    'modifiedAt': '2026-07-01T00:00:00.000Z',
  };

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('myanime_ranking_ui');
    final docsDir = Directory(p.join(tempDir.path, 'docs'))
      ..createSync(recursive: true);
    final appDir = Directory(p.join(docsDir.path, 'MyAnime'))
      ..createSync(recursive: true);
    PathProviderPlatform.instance = _FakePathProvider(docsDir.path);

    File(p.join(appDir.path, 'anime_data.json')).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'animes': [
          anime('mine', 'OnlyMine', rating: {'overall': 9.0}),
          anime(
            'theirs',
            'OnlyDatabase',
            ratings: [
              {'source': 'bangumi.tv', 'score': 7.0, 'scoreMax': 10.0},
            ],
          ),
          anime(
            'both',
            'BothScores',
            rating: {'overall': 1.0},
            ratings: [
              {'source': 'bangumi.tv', 'score': 9.0, 'scoreMax': 10.0},
              {'source': 'MyAnimeList', 'score': 70.0, 'scoreMax': 100.0},
            ],
          ),
        ],
      }),
    );
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> openRanking(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(900, 1400);
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const StatisticsPage(),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ranking').first);
    await tester.pumpAndSettle();
  }

  testWidgets('the ranking defaults to the user own rating', (tester) async {
    await openRanking(tester);

    expect(find.text('My rating'), findsOneWidget);
    expect(find.text('Database'), findsOneWidget);
    expect(find.text('Sort by'), findsOneWidget);
    expect(find.text('OnlyMine'), findsOneWidget);
    expect(find.text('BothScores'), findsOneWidget);
    // No personal rating, so it cannot be ranked by the user's own score.
    expect(find.text('OnlyDatabase'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching to the database changes which anime rank', (
    tester,
  ) async {
    await openRanking(tester);
    await tester.tap(find.text('Database'));
    await tester.pumpAndSettle();

    // The sub-score dropdown is replaced, not merely disabled: an external
    // source reports one scalar, so "Sort by: visual" would be meaningless.
    expect(find.text('Sort by'), findsNothing);
    expect(find.text('Database source'), findsOneWidget);
    expect(find.text('Average of all sources'), findsWidgets);

    expect(find.text('OnlyDatabase'), findsOneWidget);
    expect(find.text('BothScores'), findsOneWidget);
    expect(find.text('OnlyMine'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a single database source can be picked', (tester) async {
    await openRanking(tester);
    await tester.tap(find.text('Database'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Average of all sources').first);
    await tester.pumpAndSettle();

    // Only the sources actually present in the data are offered.
    expect(find.text('bangumi.tv').hitTestable(), findsWidgets);
    expect(find.text('AniList'), findsNothing);

    await tester.tap(find.text('MyAnimeList').last);
    await tester.pumpAndSettle();

    // 70/100 rebased onto ten; only this anime carries a MyAnimeList score.
    expect(find.text('BothScores'), findsOneWidget);
    expect(find.text('OnlyDatabase'), findsNothing);
    expect(find.text('7'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
