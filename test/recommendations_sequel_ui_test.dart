import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:my_anime/features/ai/services/on_device_ai_service.dart';
import 'package:my_anime/features/recommendations/models/recommendation_data.dart';
import 'package:my_anime/features/recommendations/services/recommendation_merge.dart';
import 'package:my_anime/features/recommendations/services/recommendation_store.dart';
import 'package:my_anime/features/recommendations/services/sequel_info_service.dart';
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

/// Purpose: Test the 1.6.3 missing-sequel card: thumbnail, synopsis, pin,
/// and the trash dropping the fetched info.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: The fetcher is stubbed, so no test reaches the network.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Directory appDir;
  const key = 'anilist:182255';

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('myanime_sequel_ui');
    final docs = Directory(p.join(tempDir.path, 'docs'))..createSync();
    appDir = Directory(p.join(docs.path, 'MyAnime'))..createSync();
    PathProviderPlatform.instance = _FakePathProvider(docs.path);
    File(p.join(appDir.path, 'anime_data.json')).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'animes': [
          {
            'id': 's1',
            'title': 'Frieren',
            'season': 'Season 1',
            'startEpisode': 1,
            'endEpisode': 2,
            'episodeStatuses': {'1': 'watched', '2': 'watched'},
            'externalMeta': {
              'relations': [
                {
                  'source': 'AniList',
                  'type': 'sequel',
                  'targetUrl': 'https://anilist.co/anime/182255',
                  'title': 'Frieren Season 2',
                  'format': 'TV',
                },
              ],
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

  setUp(() {
    SequelInfoService.resetSession();
    SequelInfoService.fetchPage = (url) async => null;
    SequelInfoService.download = (url) async => null;
  });

  File storeFile() => File(p.join(appDir.path, RecommendationStore.fileName));

  /// Purpose: Seed the store with fetched info for the sequel.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Writes `recommendations.json`.
  /// Notes: Test helper.
  void seedInfo() {
    final image = img.Image(width: 112, height: 160);
    img.fill(image, color: img.ColorRgb8(30, 120, 200));
    storeFile().writeAsStringSync(
      encodeRecommendationData(
        RecommendationData(
          sequelInfo: {
            key: SequelInfo(
              synopsis: 'The journey after the journey continues.',
              coverThumb: base64Encode(img.encodeJpg(image)),
              fetchedAt: DateTime.utc(2026, 9, 20),
            ),
          },
        ),
      ),
    );
  }

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
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsProvider.overrideWithValue(
              AppSettingsNotifier.fixed(const AppSettings()),
            ),
            onDeviceAiServiceProvider.overrideWithValue(
              OnDeviceAiService(backend: FakeBackend()),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: const RecommendationsPage(),
          ),
        ),
      );
    });
    await settle(tester);
  }

  testWidgets('the card shows the stored thumbnail and synopsis', (
    tester,
  ) async {
    await tester.runAsync(() async => seedInfo());
    await pump(tester);
    expect(find.textContaining('Frieren Season 2'), findsOneWidget);
    expect(
      find.text('The journey after the journey continues.'),
      findsOneWidget,
    );
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async => storeFile().deleteSync());
  });

  testWidgets('a pinned sequel survives refresh; trashing drops its info', (
    tester,
  ) async {
    await tester.runAsync(() async => seedInfo());
    await pump(tester);

    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.push_pin_outlined));
    });
    await settle(tester);
    var stored = await tester.runAsync(RecommendationStore.load);
    expect(stored!.pinnedSequels.keys, [key]);
    final refresh = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.refresh),
    );
    expect(refresh.onPressed, isNull);

    await tester.runAsync(() async {
      await tester.tap(find.text('Not interested'));
    });
    await settle(tester);
    stored = await tester.runAsync(RecommendationStore.load);
    expect(stored!.hiddenSequels.keys, [key]);
    expect(stored.pinnedSequels, isEmpty);
    expect(stored.sequelInfo, isEmpty);
    expect(find.textContaining('Frieren Season 2'), findsNothing);
    await tester.runAsync(() async => storeFile().deleteSync());
  });

  testWidgets('a card without info fetches it once and shows it', (
    tester,
  ) async {
    var calls = 0;
    SequelInfoService.fetchPage = (url) async {
      calls++;
      return (summary: 'Fetched synopsis.', coverUrl: null);
    };
    await pump(tester);
    expect(calls, 1);
    expect(find.text('Fetched synopsis.'), findsOneWidget);
    final stored = await tester.runAsync(RecommendationStore.load);
    expect(stored!.sequelInfo[key]!.synopsis, 'Fetched synopsis.');
    await tester.runAsync(() async => storeFile().deleteSync());
  });
}
