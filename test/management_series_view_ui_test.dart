import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/views/management_page.dart';
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

/// Purpose: Test the Manage tab's series view (1.6.2).
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: Drives the real page and checks the device-local preferences it
/// writes to `storage_config.json`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Directory appDir;

  Map<String, dynamic> record(
    String id,
    String title, {
    String? date,
    int? order,
  }) => {
    'id': id,
    'title': title,
    'season': 'Season 1',
    'startEpisode': 1,
    'endEpisode': 12,
    'firstAirDate': ?date,
    'episodeStatuses': <String, dynamic>{},
    if (order != null)
      'seriesLink': {
        'seriesId': '55555555-5555-4555-8555-555555555555',
        'order': order,
      },
    'createdAt': '2026-07-01T00:00:00.000Z',
    'modifiedAt': '2026-07-01T00:00:00.000Z',
  };

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('myanime_series_view_ui');
    final docs = Directory(p.join(tempDir.path, 'docs'))..createSync();
    appDir = Directory(p.join(docs.path, 'MyAnime'))..createSync();
    PathProviderPlatform.instance = _FakePathProvider(docs.path);
    File(p.join(appDir.path, 'anime_data.json')).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'animes': [
          record('f1', 'Frieren', date: '2023-09-29T00:00:00.000', order: 1),
          record(
            'f2',
            'Frieren Season 2',
            date: '2026-01-16T00:00:00.000',
            order: 2,
          ),
          record('solo', 'Akira', date: '1988-07-16T00:00:00.000'),
        ],
      }),
    );
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Map<String, dynamic> config() {
    final f = File(p.join(appDir.path, 'storage_config.json'));
    return f.existsSync()
        ? jsonDecode(f.readAsStringSync()) as Map<String, dynamic>
        : {};
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
  }

  /// Purpose: Let a write started on the test clock finish.
  /// Inputs: `tester`.
  /// Returns: None.
  /// Side effects: Pumps frames.
  /// Notes: Test helper. Real I/O completes during the real waits; the
  /// continuations it schedules run on the fake clock's pumps. Nothing reads
  /// the file meanwhile: on Windows a read during the page's tmp-then-rename
  /// fails the rename.
  Future<void> drainIo(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.reset);
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
    });
    await settle(tester);
  }

  testWidgets('the series view groups, sorts and is remembered', (
    tester,
  ) async {
    await pump(tester);
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('View by series'));
    });
    await settle(tester);
    expect(config()['manageViewMode'], 'series');

    // One expandable row for the series, one plain row for the other record.
    expect(find.byType(ExpansionTile), findsOneWidget);
    expect(find.text('2 entries · 0 completed'), findsOneWidget);
    expect(find.text('Akira'), findsOneWidget);
    expect(find.text('Frieren Season 2'), findsNothing);

    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    expect(find.text('Frieren Season 2'), findsOneWidget);

    // Newest premiere first: the 2026 series is above the 1988 film.
    expect(
      tester.getTopLeft(find.byType(ExpansionTile)).dy,
      lessThan(tester.getTopLeft(find.text('Akira')).dy),
    );

    // Sort by title: "Akira" moves above "Frieren".
    await tester.tap(find.byTooltip('Sort series'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Title').last);
    await tester.pumpAndSettle();
    await drainIo(tester);
    expect(config()['manageSeriesSort'], 'title');
    expect(
      tester.getTopLeft(find.text('Akira')).dy,
      lessThan(tester.getTopLeft(find.byType(ExpansionTile)).dy),
    );

    // A fresh page opens in the remembered view.
    await pump(tester);
    expect(find.byType(ExpansionTile), findsOneWidget);

    // Back to quarters removes the key: only non-defaults are stored.
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('View by quarter'));
    });
    await settle(tester);
    expect(config().containsKey('manageViewMode'), isFalse);
    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.byType(PageView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
