import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/views/anime_detail_page.dart';
import 'package:my_anime/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Purpose: Test that the anime detail page renders correctly in both layouts.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: Drives the real page against a seeded storage directory, at the real
/// logical-pixel geometry of the devices named in each case, so an overflow or
/// a wrong-layout regression is caught at the size it would actually happen.
/// Fake application-documents provider (pattern from existing app tests).
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsPath);
  final String documentsPath;
  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  // A 1x1 opaque PNG, so the cover is a real decodable image in both layouts.
  final pngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmM'
    'IQAAAABJRU5ErkJggg==',
  );

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('myanime_detail_ui');
    final docsDir = Directory(p.join(tempDir.path, 'docs'))
      ..createSync(recursive: true);
    final appDir = Directory(p.join(docsDir.path, 'MyAnime'))
      ..createSync(recursive: true);
    Directory(p.join(appDir.path, 'images')).createSync(recursive: true);
    File(p.join(appDir.path, 'images', 'cover.png')).writeAsBytesSync(pngBytes);

    PathProviderPlatform.instance = _FakePathProvider(docsDir.path);

    File(p.join(appDir.path, 'anime_data.json')).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'animes': [
          {
            'id': 'a1',
            'title': '与奔驰于透明之夜的你，谈一场看不见的恋爱。',
            'titleJa': '透明な夜に駆ける君と、目に見えない恋をした。',
            'season': 'Season 1',
            'startEpisode': 1,
            'endEpisode': 12,
            'airDayOfWeek': 1,
            'airTime': '23:30',
            'firstAirDate': '2026-07-06T00:00:00.000Z',
            'coverImage': 'images/cover.png',
            'infoUrl': 'https://bangumi.tv/subject/1',
            'notes': 'A note that sits below the cards.',
            'episodeStatuses': {
              '1': 'watched',
              '2': 'watched',
              '3': 'watched',
              '4': 'watched',
              '5': 'watched',
              '6': 'watched',
              '7': 'watched',
            },
            'rating': {'overall': 8.5, 'visual': 9},
            'localArchive': {
              'archived': true,
              'source': 'bd',
              'resolution': 'fhd1080p',
            },
            'externalMeta': {
              'genres': ['恋爱', '校园'],
              'synonyms': ['與奔馳於透明之夜的你，談一場看不見的戀愛。'],
              'format': 'TV',
              'ratings': [
                {
                  'source': 'bangumi.tv',
                  'score': 7.0,
                  'scoreMax': 10.0,
                  'votes': 714,
                },
              ],
              'refreshedAt': '2026-08-27T00:00:00.000Z',
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

  Future<void> pumpAt(
    WidgetTester tester,
    double width,
    double height,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.reset);
    // The page loads from disk and decodes its cover through real dart:io, so
    // the first frames have to run outside the binding's fake-async zone or
    // the record never arrives and the page stays on its loading spinner.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh', 'TW'),
          home: const AnimeDetailPage(animeId: 'a1'),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
  }

  testWidgets('a Z Fold 8 in landscape splits into two panes', (tester) async {
    await pumpAt(tester, 933, 704);

    expect(find.byType(VerticalDivider), findsOneWidget);
    // Left pane: cover through progress. Right pane: cards and episodes.
    expect(find.text('7 / 12 集'), findsOneWidget);
    expect(find.text('資料庫資訊'), findsOneWidget);
    expect(find.text('劇集列表'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the same Z Fold 8 in portrait stays single column', (
    tester,
  ) async {
    await pumpAt(tester, 704, 933);

    expect(find.byType(VerticalDivider), findsNothing);
    expect(find.text('7 / 12 集'), findsOneWidget);
    expect(find.text('資料庫資訊'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a near-square Z Fold 7 splits in portrait too', (tester) async {
    await pumpAt(tester, 750, 832);

    expect(find.byType(VerticalDivider), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a folded cover screen stays single column', (tester) async {
    await pumpAt(tester, 411, 923);

    expect(find.byType(VerticalDivider), findsNothing);
    expect(find.text('7 / 12 集'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a phone in landscape stays single column', (tester) async {
    await pumpAt(tester, 915, 412);

    expect(find.byType(VerticalDivider), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('both panes scroll independently when split', (tester) async {
    await pumpAt(tester, 1024, 768);

    expect(find.byType(VerticalDivider), findsOneWidget);
    // The episode list lives in the right pane, so scrolling there must not
    // move the cover, which is what the fixed left pane is for.
    final coverBefore = tester.getTopLeft(find.byType(Image));
    await tester.drag(find.text('劇集列表'), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(Image)), coverBefore);
    expect(tester.takeException(), isNull);
  });
}
