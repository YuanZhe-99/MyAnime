import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/app/flavor.dart';
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

/// Purpose: Test the detail-page header: facts, one Watch row, progress with
/// the site progress line under it, and Info/Refresh in the database card.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: 1.6.3 split facts from actions; 1.6.6 regrouped them by role so no
/// row mixes variable-length text with buttons. Narrow geometries run in
/// Japanese: in the test font the unchanged English episode-list header is
/// wider than the right pane of a 600-wide split. The status line is never
/// tapped here — its spinner would keep `pumpAndSettle` from settling.
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
            'externalMeta': {
              'format': 'TV',
              'refreshedAt': '2026-09-26T00:00:00.000Z',
            },
            'createdAt': '2026-07-01T00:00:00.000Z',
            'modifiedAt': '2026-07-01T00:00:00.000Z',
          },
          {
            'id': 'a2',
            'title': 'Info Only Record',
            'season': 'Season 1',
            'startEpisode': 1,
            'endEpisode': 12,
            'infoUrl': 'https://bangumi.tv/subject/2',
            'createdAt': '2026-07-01T00:00:00.000Z',
            'modifiedAt': '2026-07-01T00:00:00.000Z',
          },
          {
            'id': 'a3',
            'title': 'Stored Progress Record',
            'season': 'Season 1',
            'startEpisode': 1,
            'endEpisode': 12,
            'watchUrl': 'https://anime1.me/?cat=2',
            'externalMeta': {
              'watchProgress': {
                'sourceUrl': 'https://anime1.me/?cat=2',
                'latestEpisode': 9,
                'episodesText': '連載中(09)',
                'ongoing': true,
                'checkedAt': '2026-09-26T00:00:00.000Z',
              },
            },
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

  Future<void> pump(
    WidgetTester tester,
    Size size, {
    String id = 'a1',
    Locale locale = const Locale('en'),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          home: AnimeDetailPage(animeId: id),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
  }

  final card = find.byKey(const ValueKey('detailExternalMetaCard'));
  final status = find.byKey(const ValueKey('detailAnime1Progress'));
  Finder inCard(Finder f) => find.descendant(of: card, matching: f);

  for (final (name, size) in [
    ('412x915', const Size(412, 915)),
    ('1280x800', const Size(1280, 800)),
  ]) {
    testWidgets('header is grouped by role ($name)', (tester) async {
      await pump(tester, size);

      final line = tester.widget<Text>(
        find.byKey(const ValueKey('detailInfoLine')),
      );
      expect(line.data, 'Season 2 · Single Cour · Sun · 21:00');
      expect(find.widgetWithText(Chip, 'Season 2'), findsNothing);

      // Categories sit with the facts, above the Watch row.
      final watch = find.widgetWithText(FilledButton, 'Watch');
      expect(watch, findsOneWidget);
      expect(
        tester.getBottomLeft(find.byTooltip('Edit categories')).dy,
        lessThanOrEqualTo(tester.getTopLeft(watch).dy),
      );
      // Watch and the episode-links icon share one row.
      expect(
        tester.getCenter(find.byTooltip('Episode links')).dy,
        moreOrLessEquals(tester.getCenter(watch).dy, epsilon: 1),
      );

      // Info and Refresh live in the database card, once each.
      expect(find.byTooltip('Info'), findsOneWidget);
      expect(find.byTooltip('Refresh database info'), findsOneWidget);
      expect(inCard(find.byTooltip('Info')), findsOneWidget);
      expect(inCard(find.byTooltip('Refresh database info')), findsOneWidget);

      // The site progress line sits under the bar and the count, flush left.
      final count = find.text('0 / 13 episodes');
      expect(
        tester.getTopLeft(status).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(count).dy),
      );
      expect(
        tester.getTopLeft(status).dy,
        greaterThan(
          tester.getBottomLeft(find.byType(LinearProgressIndicator)).dy,
        ),
      );
      expect(
        tester
            .getTopLeft(
              find.descendant(of: status, matching: find.byIcon(Icons.update)),
            )
            .dx,
        moreOrLessEquals(tester.getTopLeft(count).dx, epsilon: 0.5),
      );
      expect(
        find.descendant(of: status, matching: find.text('Check Anime1')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }, skip: AppFlavor.isStore);
  }

  for (final (name, size, split) in [
    ('600x700', const Size(600, 700), true),
    ('933x704', const Size(933, 704), true),
    ('411x923', const Size(411, 923), false),
  ]) {
    testWidgets('header fits without overflow in Japanese ($name)', (
      tester,
    ) async {
      await pump(tester, size, locale: const Locale('ja'));

      expect(
        find.byType(VerticalDivider),
        split ? findsOneWidget : findsNothing,
      );
      final watch = find.widgetWithText(FilledButton, '視聴');
      expect(
        tester.getCenter(find.byTooltip('各話の対応')).dy,
        moreOrLessEquals(tester.getCenter(watch).dy, epsilon: 1),
      );
      expect(inCard(find.byTooltip('情報')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, skip: AppFlavor.isStore);
  }

  testWidgets('a record without a watch link has no Watch row', (tester) async {
    await pump(tester, const Size(412, 915), id: 'a2');

    expect(find.byType(FilledButton), findsNothing);
    expect(status, findsNothing);
    // No data rows, but the card still carries both actions.
    expect(inCard(find.byTooltip('Info')), findsOneWidget);
    expect(inCard(find.byTooltip('Refresh database info')), findsOneWidget);
    expect(find.textContaining('Updated'), findsNothing);
    expect(tester.takeException(), isNull);
  }, skip: AppFlavor.isStore);

  testWidgets(
    'the same record fits the narrowest split in Japanese',
    (tester) async {
      await pump(
        tester,
        const Size(600, 700),
        id: 'a2',
        locale: const Locale('ja'),
      );
      expect(inCard(find.byTooltip('情報')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    skip: AppFlavor.isStore,
  );

  testWidgets(
    'stored progress shows under the bar and no empty card',
    (tester) async {
      await pump(tester, const Size(412, 915), id: 'a3');

      expect(
        find.descendant(
          of: status,
          matching: find.text('Anime1: Updated to episode 9'),
        ),
        findsOneWidget,
      );
      // Only the watch progress is stored: nothing for the card to show.
      expect(card, findsNothing);
      expect(tester.takeException(), isNull);
    },
    skip: AppFlavor.isStore,
  );

  testWidgets(
    'store builds show stored data but no online actions',
    (tester) async {
      await pump(tester, const Size(412, 915));
      expect(find.widgetWithText(FilledButton, 'Watch'), findsOneWidget);
      expect(find.byTooltip('Episode links'), findsNothing);
      expect(find.byTooltip('Refresh database info'), findsNothing);
      expect(inCard(find.byTooltip('Info')), findsOneWidget);
      // Nothing stored: no "Check Anime1" prompt a store build cannot act on.
      expect(status, findsNothing);

      await pump(tester, const Size(412, 915), id: 'a3');
      expect(find.text('Anime1: Updated to episode 9'), findsOneWidget);
      expect(
        find.ancestor(of: status, matching: find.byType(TextButton)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
    skip: !AppFlavor.isStore,
  );
}
