import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/ai/services/on_device_ai_service.dart';
import 'package:my_anime/features/recommendations/services/recommendation_store.dart';
import 'package:my_anime/features/recommendations/views/recommendation_trash_page.dart';
import 'package:my_anime/features/recommendations/views/recommendations_page.dart';
import 'package:my_anime/l10n/app_localizations.dart';
import 'package:my_anime/shared/providers/app_settings.dart';
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

/// Purpose: Test the recommendations page with and without on-device AI.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: The deterministic list renders either way; the AI reason appears
/// under its "Generated on this device" label only when the model answers.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  Map<String, dynamic> record(
    String id,
    String title, {
    int watched = 0,
    String? date,
  }) => {
    'id': id,
    'title': title,
    'season': 'Season 1',
    'startEpisode': 1,
    'endEpisode': 12,
    'firstAirDate': ?date,
    'episodeStatuses': {for (var e = 1; e <= watched; e++) '$e': 'watched'},
    'createdAt': '2026-07-01T00:00:00.000Z',
    'modifiedAt': '2026-07-01T00:00:00.000Z',
  };

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('myanime_recs_ui');
    final docs = Directory(p.join(tempDir.path, 'docs'))..createSync();
    final app = Directory(p.join(docs.path, 'MyAnime'))..createSync();
    PathProviderPlatform.instance = _FakePathProvider(docs.path);
    File(p.join(app.path, 'anime_data.json')).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'animes': [
          record('s1', 'Frieren', watched: 12, date: '2023-09-29T00:00:00.000'),
          record('s2', 'Frieren Season 2', date: '2026-01-16T00:00:00.000'),
        ],
      }),
    );
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> pump(WidgetTester tester, OnDeviceAiService ai) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsProvider.overrideWithValue(
              AppSettingsNotifier.fixed(const AppSettings()),
            ),
            onDeviceAiServiceProvider.overrideWithValue(ai),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: const RecommendationsPage(),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
  }

  testWidgets('without AI the deterministic list and chips show', (
    tester,
  ) async {
    await pump(tester, OnDeviceAiService(backend: FakeBackend()));
    expect(find.text('Frieren Season 2'), findsOneWidget);
    expect(find.text('Next after Frieren'), findsOneWidget);
    expect(find.text('Generated on this device — may be wrong'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with AI a labelled reason fills in', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final backend = FakeBackend()
      ..generateReplies.add('1: The story continues right where you left off.');
    final ai = OnDeviceAiService(backend: backend);
    await tester.runAsync(() => ai.setEnabled(true));
    await pump(tester, ai);
    expect(
      find.text('Generated on this device — may be wrong'),
      findsOneWidget,
    );
    expect(
      find.text('The story continues right where you left off.'),
      findsOneWidget,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  /// Purpose: Let real file I/O finish and the tree settle.
  /// Inputs: `tester`.
  /// Returns: None.
  /// Side effects: Pumps frames.
  /// Notes: Test helper; storage runs outside the fake clock.
  Future<void> settleIo(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
  }

  File storeFile() => File(
    p.join(tempDir.path, 'docs', 'MyAnime', RecommendationStore.fileName),
  );

  testWidgets('refresh trashes the shown batch and undo restores it', (
    tester,
  ) async {
    await pump(tester, OnDeviceAiService(backend: FakeBackend()));
    expect(find.text('Frieren Season 2'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.refresh));
    });
    await settleIo(tester);
    expect(find.text('Frieren Season 2'), findsNothing);
    expect(find.text('Moved 1 to the trash'), findsOneWidget);
    final stored = await tester.runAsync(RecommendationStore.load);
    expect(stored!.hidden.keys, ['s2']);

    await tester.runAsync(() async {
      await tester.tap(find.text('Undo'));
    });
    await settleIo(tester);
    expect(find.text('Frieren Season 2'), findsOneWidget);
    final after = await tester.runAsync(RecommendationStore.load);
    expect(after!.hidden, isEmpty);
    await tester.runAsync(() async {
      if (storeFile().existsSync()) storeFile().deleteSync();
    });
  });

  testWidgets('the trash lists a trashed record and restores it', (
    tester,
  ) async {
    await tester.runAsync(() => RecommendationStore.hide(['s2']));
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: RecommendationTrashPage(),
        ),
      );
    });
    await settleIo(tester);
    expect(find.text('Frieren Season 2'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Restore'));
    });
    await settleIo(tester);
    expect(find.text('Frieren Season 2'), findsNothing);
    expect(find.textContaining('The trash is empty'), findsOneWidget);
    final after = await tester.runAsync(RecommendationStore.load);
    expect(after!.hidden, isEmpty);
    await tester.runAsync(() async {
      if (storeFile().existsSync()) storeFile().deleteSync();
    });
  });
}
