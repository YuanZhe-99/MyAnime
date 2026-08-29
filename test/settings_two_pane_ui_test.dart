import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/models/metadata_update.dart';
import 'package:my_anime/features/settings/views/settings_page.dart';
import 'package:my_anime/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Purpose: Test the settings page's list-detail layout on wide windows.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: The privacy policy is the probe because it is the only one of the
/// five second-level pages that touches neither the file system nor the
/// network, so what these cases measure is the layout and nothing else. The
/// distinguishing assertion is not that the page appeared — it appears in both
/// modes — but whether the first-level list is still on screen beside it.
///
/// Driven in Simplified Chinese on purpose. `flutter_test`'s default font
/// renders every glyph as a full em square, so an English option label such as
/// "Don't use cellular data" measures 395 logical pixels here against roughly
/// 150 with the fonts the app ships, and the settings rows' trailing dropdowns
/// overflow their tile in the test environment and nowhere else. The Chinese
/// labels are short enough in glyph count that what these cases measure is the
/// real layout, with no errors to filter and nothing designed around.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsPath);
  final String documentsPath;
  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  const theme = '主题'; // a row that only ever lives in the first-level list
  const privacy = '隐私政策';
  const placeholder = '从左侧列表中选择一项';

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('myanime_settings_ui');
    final docsDir = Directory(p.join(tempDir.path, 'docs'))
      ..createSync(recursive: true);
    Directory(p.join(docsDir.path, 'MyAnime')).createSync(recursive: true);
    PathProviderPlatform.instance = _FakePathProvider(docsDir.path);
    PackageInfo.setMockInitialValues(
      appName: 'MyAnime',
      packageName: 'com.example.my_anime',
      version: '1.5.6',
      buildNumber: '59',
      buildSignature: '',
    );
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> pumpAt(WidgetTester tester, double width, double height) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.reset);
    // The page reads its config through real dart:io, so the first frames have
    // to run outside the binding's fake-async zone.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('zh'),
            home: SettingsPage(),
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

  Future<void> openPrivacyPolicy(WidgetTester tester) async {
    final row = find.widgetWithText(ListTile, privacy);
    await tester.scrollUntilVisible(
      row,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  testWidgets('the background-update description runs under its dropdown', (
    tester,
  ) async {
    // Since 1.5.6 the policy dropdown rides the title row instead of the tile's
    // `trailing` slot, so the description gets the tile's full width rather
    // than the narrow column left beside the dropdown.
    await pumpAt(tester, 933, 704);
    const desc = '应用打开时，自动刷新已保存的资料库信息，并为资料不全的记录查找在线资料。';
    final row = find.widgetWithText(ListTile, desc);
    await tester.scrollUntilVisible(
      row,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final tile = tester.getRect(row);
    final text = tester.getRect(find.text(desc));
    final dropdown = tester.getRect(
      find.descendant(
        of: row,
        matching: find.byType(DropdownButton<MetadataUpdatePolicy>),
      ),
    );

    // The dropdown is on the title row, above the description...
    expect(dropdown.bottom, lessThanOrEqualTo(text.top));
    // ...and the description now runs past its left edge, out to the tile.
    expect(text.right, greaterThan(dropdown.left));
    expect(text.right, greaterThan(tile.right - 32));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a Z Fold 8 unfolded shows the placeholder until a pick', (
    tester,
  ) async {
    await pumpAt(tester, 933, 704);
    expect(find.text(placeholder), findsOneWidget);
    // The first-level list is on screen at the same time.
    expect(find.text(theme), findsOneWidget);
  });

  testWidgets('picking a row fills the pane and keeps the list beside it', (
    tester,
  ) async {
    await pumpAt(tester, 933, 704);
    await openPrivacyPolicy(tester);
    // The distinguishing assertion. In one pane the pushed page covers the
    // list and the title is found once; here the list is still beside it, so
    // the row and the pane's own app bar both carry the title.
    expect(find.text(privacy), findsNWidgets(2));
    expect(find.text(placeholder), findsNothing);
    // Reaching the row scrolled the left pane, so scroll it back: the list is
    // still there, still scrollable, and still the first-level page.
    await tester.scrollUntilVisible(
      find.text(theme),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text(theme), findsOneWidget);
    // Nothing was pushed, so the pane's app bar grew no back arrow.
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('the same device in portrait pushes full-screen instead', (
    tester,
  ) async {
    await pumpAt(tester, 704, 933);
    expect(find.text(placeholder), findsNothing);
    await openPrivacyPolicy(tester);
    expect(find.text(privacy), findsOneWidget);
    // The pushed page covers the list.
    expect(find.text(theme), findsNothing);
  });

  testWidgets('a phone keeps the single-pane behaviour it always had', (
    tester,
  ) async {
    await pumpAt(tester, 412, 915); // Pixel 9
    expect(find.text(placeholder), findsNothing);
    await openPrivacyPolicy(tester);
    expect(find.text(theme), findsNothing);
  });
}
