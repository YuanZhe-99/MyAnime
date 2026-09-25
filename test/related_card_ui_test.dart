import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/ai/services/on_device_ai_service.dart';
import 'package:my_anime/features/anime/views/anime_detail_page.dart';
import 'package:my_anime/features/recommendations/services/recommendation_store.dart';
import 'package:my_anime/features/recommendations/views/related_card.dart';
import 'package:my_anime/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'on_device_ai_test.dart' show FakeBackend;

/// Fake application-documents provider (pattern from existing app tests).
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsPath);
  final String documentsPath;
  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

/// Purpose: Test the detail page's related card (1.6.2).
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: Drives the real detail page with recommendations switched on in
/// `storage_config.json`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Directory appDir;

  Map<String, dynamic> record(String id, String title, List<String> genres) => {
    'id': id,
    'title': title,
    'season': 'Season 1',
    'startEpisode': 1,
    'endEpisode': 12,
    'episodeStatuses': <String, dynamic>{},
    'externalMeta': {'genres': genres},
    'createdAt': '2026-07-01T00:00:00.000Z',
    'modifiedAt': '2026-07-01T00:00:00.000Z',
  };

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('myanime_related_ui');
    final docs = Directory(p.join(tempDir.path, 'docs'))..createSync();
    appDir = Directory(p.join(docs.path, 'MyAnime'))..createSync();
    PathProviderPlatform.instance = _FakePathProvider(docs.path);
    const pretty = JsonEncoder.withIndent('  ');
    File(p.join(appDir.path, 'anime_data.json')).writeAsStringSync(
      pretty.convert({
        'animes': [
          record('subject', 'Kaguya-sama', ['Romance', 'Comedy']),
          record('alike', 'Tonikawa', ['Romance', 'Comedy']),
          record('half', 'Horimiya', ['Romance']),
          record('none', 'Berserk', ['Horror']),
        ],
      }),
    );
    File(
      p.join(appDir.path, 'storage_config.json'),
    ).writeAsStringSync(pretty.convert({'recommendationsEnabled': true}));
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(412, 2400);
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onDeviceAiServiceProvider.overrideWithValue(
              OnDeviceAiService(backend: FakeBackend()),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: AnimeDetailPage(animeId: 'subject'),
          ),
        ),
      );
    });
    await settle(tester);
  }

  Finder inCard(Finder f) =>
      find.descendant(of: find.byType(RelatedRecommendationsCard), matching: f);

  testWidgets('the list is generated once, persisted and reused', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Related'), findsOneWidget);
    expect(inCard(find.text('Tonikawa')), findsOneWidget);
    expect(inCard(find.text('Horimiya')), findsOneWidget);
    expect(inCard(find.text('Berserk')), findsNothing);
    final first = await tester.runAsync(RecommendationStore.load);
    final snap = first!.related['subject']!;
    expect(snap.items.map((i) => i.id), ['alike', 'half']);

    // A second visit shows the stored list without regenerating it.
    await pump(tester);
    final again = await tester.runAsync(RecommendationStore.load);
    expect(again!.related['subject']!.generatedAt, snap.generatedAt);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh trashes the shown batch into this record\'s bin', (
    tester,
  ) async {
    await pump(tester);
    await tester.runAsync(() async {
      await tester.tap(inCard(find.byIcon(Icons.refresh)));
    });
    await settle(tester);
    expect(inCard(find.text('Tonikawa')), findsNothing);
    expect(
      inCard(find.text('Nothing in your library looks related yet.')),
      findsOneWidget,
    );
    final d = await tester.runAsync(RecommendationStore.load);
    final snap = d!.related['subject']!;
    expect(snap.hidden.keys.toSet(), {'alike', 'half'});
    expect(snap.items, isEmpty);
    // The global trash is a different bin.
    expect(d.hidden, isEmpty);
  });

  testWidgets('not interested trashes one item', (tester) async {
    await tester.runAsync(
      () => RecommendationStore.restoreRelated('subject', ['alike', 'half']),
    );
    await tester.runAsync(
      () => RecommendationStore.putRelated('subject', const []),
    );
    // With the bin emptied, a refresh while nothing is shown trashes nothing
    // and generates the list again.
    await pump(tester);
    await tester.runAsync(() async {
      await tester.tap(inCard(find.byIcon(Icons.refresh)));
    });
    await settle(tester);
    expect(inCard(find.text('Tonikawa')), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(inCard(find.byIcon(Icons.close)).first);
    });
    await settle(tester);
    final d = await tester.runAsync(RecommendationStore.load);
    expect(d!.related['subject']!.hidden.keys, ['alike']);
    expect(inCard(find.text('Tonikawa')), findsNothing);
    expect(inCard(find.text('Horimiya')), findsOneWidget);
  });
}
