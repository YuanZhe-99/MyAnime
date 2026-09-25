import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

/// Purpose: Test moving between seasons from the detail page's series card,
/// and the season-label correction that runs when the page loads.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: Uses a router with a stub home page and the app's detail route
/// definition. Before 1.6.1 the series card used `context.go`: the first hop
/// dropped the stack (no way back) and the second hop reused the same page
/// State, so nothing changed on screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File dataFile;

  Map<String, Object?> record(String id, String title, String season) => {
    'id': id,
    'title': title,
    'season': season,
    'startEpisode': 1,
    'endEpisode': 12,
    'createdAt': '2026-01-01T00:00:00.000Z',
    'modifiedAt': '2026-01-01T00:00:00.000Z',
  };

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('myanime_series_nav');
    final docsDir = Directory(p.join(tempDir.path, 'docs'))
      ..createSync(recursive: true);
    final appDir = Directory(p.join(docsDir.path, 'MyAnime'))
      ..createSync(recursive: true);
    PathProviderPlatform.instance = _FakePathProvider(docsDir.path);
    dataFile = File(p.join(appDir.path, 'anime_data.json'))
      ..writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'animes': [
            record('a', 'Frieren', 'Season 1'),
            // Both still carry the default label; their titles say otherwise.
            record('b', 'Frieren 第二季', 'Season 1'),
            record('c', 'Frieren Season 3', 'Season 1'),
          ],
        }),
      );
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  GoRouter buildRouter() => GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('home'))),
      ),
      // Same definition as lib/app/router.dart.
      GoRoute(
        path: '/anime/detail/:id',
        builder: (context, state) => AnimeDetailPage(
          key: ValueKey(state.pathParameters['id']!),
          animeId: state.pathParameters['id']!,
        ),
      ),
    ],
  );

  /// Lets the page's real file I/O finish, then settles the frames.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
  }

  /// The title of the series-card row marked as the page being shown.
  String currentRow(WidgetTester tester) {
    final tile = tester.widget<ListTile>(
      find.byWidgetPredicate((w) => w is ListTile && w.selected).last,
    );
    return (tile.title as Text).data!;
  }

  Future<void> openRow(WidgetTester tester, String title) async {
    final row = find.widgetWithText(ListTile, title).last;
    await tester.ensureVisible(row);
    await tester.tap(row);
    await settle(tester);
  }

  testWidgets('hops between seasons keep a working back stack', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(420, 2400);
    addTearDown(tester.view.reset);

    final router = buildRouter();
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
      ),
    );
    router.push('/anime/detail/a');
    await settle(tester);
    expect(currentRow(tester), 'Frieren');

    await openRow(tester, 'Frieren 第二季');
    expect(currentRow(tester), 'Frieren 第二季');
    expect(router.canPop(), isTrue);

    // The second hop is the one that used to do nothing.
    await openRow(tester, 'Frieren Season 3');
    expect(currentRow(tester), 'Frieren Season 3');

    router.pop();
    await settle(tester);
    expect(currentRow(tester), 'Frieren 第二季');
    router.pop();
    await settle(tester);
    expect(currentRow(tester), 'Frieren');
    router.pop();
    await settle(tester);
    expect(find.text('home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening the page corrects default season labels', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(420, 2400);
    addTearDown(tester.view.reset);

    final router = buildRouter();
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
      ),
    );
    router.push('/anime/detail/a');
    await settle(tester);

    final saved = {
      for (final a
          in (jsonDecode(await tester.runAsync(dataFile.readAsString) ?? '{}')
                  as Map<String, dynamic>)['animes']
              as List)
        (a as Map<String, dynamic>)['id']: a,
    };
    expect(saved['a']!['season'], 'Season 1');
    expect(saved['b']!['season'], 'Season 2');
    expect(saved['c']!['season'], 'Season 3');
    // Corrected without marking the records edited, so sync sees no change.
    expect(saved['b']!['modifiedAt'], '2026-01-01T00:00:00.000Z');
    expect(find.textContaining('Season 2'), findsWidgets);
  });
}
