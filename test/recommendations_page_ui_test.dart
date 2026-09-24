import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/ai/services/on_device_ai_service.dart';
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
}
