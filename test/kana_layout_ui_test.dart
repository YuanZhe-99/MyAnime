import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/kana/views/kana_page.dart';
import 'package:my_anime/l10n/app_localizations.dart';

/// Purpose: Test the kana page's two-column layout at real device geometries.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: The kana page reads nothing from disk, so it can be driven directly.
/// The section headings are the probe: two columns put the basic and voiced
/// tables at the same top and different x, one column stacks them. Each case
/// names the device it stands for, so a regression names what it would break.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpAt(WidgetTester tester, double width, double height) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: KanaPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The section headings, in English, from the ARB.
  final basic = find.text('Gojūon');
  final voiced = find.text('Dakuten');
  final yoon = find.text('Yōon');

  void expectTwoColumns(WidgetTester tester) {
    final left = tester.getTopLeft(basic);
    final right = tester.getTopLeft(voiced);
    expect(right.dx, greaterThan(left.dx), reason: 'voiced sits to the right');
    expect(right.dy, left.dy, reason: 'both tables start at the same top');
    // Yoon follows the basic table down the left column.
    final below = tester.getTopLeft(yoon);
    expect(below.dx, left.dx);
    expect(below.dy, greaterThan(left.dy));
  }

  void expectOneColumn(WidgetTester tester) {
    final left = tester.getTopLeft(basic);
    final right = tester.getTopLeft(voiced);
    expect(right.dx, left.dx, reason: 'both tables share the left edge');
    expect(right.dy, greaterThan(left.dy), reason: 'voiced sits below');
  }

  testWidgets('a Z Fold 8 unfolded in landscape uses two columns', (
    tester,
  ) async {
    await pumpAt(tester, 933, 704);
    expectTwoColumns(tester);
  });

  testWidgets('the same device in portrait stays on one column', (
    tester,
  ) async {
    // 704 x 933 is 0.755 wide-to-tall, under the aspect threshold: one device,
    // two answers, which is the whole reason the gate is not width alone.
    await pumpAt(tester, 704, 933);
    expectOneColumn(tester);
  });

  testWidgets('a Pixel 10 Pro Fold is wide enough for two tables', (
    tester,
  ) async {
    await pumpAt(tester, 791, 820);
    expectTwoColumns(tester);
  });

  testWidgets('a Z Fold 5 unfolded stays on one column', (tester) async {
    // It passes the split gate but two 330-wide tables do not fit in the 546
    // it has left after the rail and the page padding, so the second gate —
    // the column capacity — is what holds it back. No extra breakpoint needed.
    await pumpAt(tester, 659, 791);
    expectOneColumn(tester);
  });

  testWidgets('a tablet splits in landscape but not in portrait', (
    tester,
  ) async {
    await pumpAt(tester, 1024, 768);
    expectTwoColumns(tester);
    await pumpAt(tester, 768, 1024);
    expectOneColumn(tester);
  });

  testWidgets('a phone in landscape stays on one column', (tester) async {
    // Wide enough, far too short: the height floor rejects it.
    await pumpAt(tester, 915, 412);
    expectOneColumn(tester);
  });

  testWidgets('a phone in portrait keeps the original stacked layout', (
    tester,
  ) async {
    await pumpAt(tester, 412, 915);
    expectOneColumn(tester);
  });

  testWidgets('searching replaces the tables and keeps the rules', (
    tester,
  ) async {
    await pumpAt(tester, 933, 704);
    await tester.enterText(find.byType(TextField), 'ka');
    await tester.pumpAndSettle();
    expect(basic, findsNothing);
    expect(voiced, findsNothing);
    expect(find.text('Pronunciation'), findsOneWidget);
  });
}
