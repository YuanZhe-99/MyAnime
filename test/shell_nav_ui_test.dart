import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_anime/app/router.dart';
import 'package:my_anime/l10n/app_localizations.dart';
import 'package:my_anime/shared/providers/app_settings.dart';
import 'package:my_anime/shared/widgets/shell_scaffold.dart';

/// Purpose: Test that the shell swaps its bottom bar for a rail on wide windows,
/// and shows the Kana tab only when it is turned on.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: The rail is chosen on width alone, deliberately unlike the app-wide
/// split rule, so the case worth pinning hardest is a phone in landscape: wide
/// enough for a rail, far too short to split. The destinations are stubbed with
/// empty pages so this exercises the shell and nothing behind it; `/kana` uses
/// the app's real redirect.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GoRouter> pumpAt(
    WidgetTester tester,
    double width,
    double height, {
    bool kanaTabEnabled = false,
    String initialLocation = '/home',
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.reset);

    GoRoute stub(String path) => GoRoute(
      path: path,
      redirect: path == '/kana' ? kanaRouteRedirect : null,
      builder: (context, state) =>
          Scaffold(body: Center(child: Text('page $path'))),
    );

    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        ShellRoute(
          builder: (context, state, child) => ShellScaffold(child: child),
          routes: [
            for (final path in const [
              '/home',
              '/manage',
              '/stats',
              '/kana',
              '/settings',
            ])
              stub(path),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsProvider.overrideWithValue(
            AppSettingsNotifier.fixed(
              AppSettings(kanaTabEnabled: kanaTabEnabled),
            ),
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('a phone in portrait keeps the bottom navigation bar', (
    tester,
  ) async {
    await pumpAt(tester, 412, 915); // Pixel 9
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('a Z Fold 8 unfolded moves navigation to the side', (
    tester,
  ) async {
    await pumpAt(tester, 933, 704);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('a phone in landscape gets a rail even though it cannot split', (
    tester,
  ) async {
    // The reason the rail has a rule of its own: at 412 logical pixels tall a
    // bottom bar would spend a fifth of the height, and width is what is spare.
    await pumpAt(tester, 915, 412);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  group('Kana tab off (the default)', () {
    testWidgets('the bar and the rail both carry four destinations', (
      tester,
    ) async {
      await pumpAt(tester, 412, 915);
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.destinations, hasLength(4));
      expect(find.byIcon(Icons.translate_outlined), findsNothing);

      await pumpAt(tester, 1600, 900);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.destinations, hasLength(4));
      expect(rail.selectedIndex, 0);
    });

    testWidgets('Settings is the fourth destination', (tester) async {
      await pumpAt(tester, 933, 704);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.text('page /settings'), findsOneWidget);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.selectedIndex, 3);
    });

    testWidgets('/kana redirects to Home', (tester) async {
      final router = await pumpAt(tester, 933, 704);
      router.go('/kana');
      await tester.pumpAndSettle();
      expect(find.text('page /home'), findsOneWidget);
      expect(find.text('page /kana'), findsNothing);
    });
  });

  group('Kana tab on', () {
    testWidgets('the rail carries all five destinations, in order', (
      tester,
    ) async {
      await pumpAt(tester, 1600, 900, kanaTabEnabled: true); // desktop
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.destinations, hasLength(5));
      expect(rail.selectedIndex, 0);
      final labels = [
        for (final d in rail.destinations) (d.label as Text).data,
      ];
      expect(labels, ['Home', 'Manage', 'Stats', 'Kana', 'Settings']);
    });

    testWidgets('tapping a rail destination navigates', (tester) async {
      await pumpAt(tester, 933, 704, kanaTabEnabled: true);
      expect(find.text('page /home'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.translate_outlined));
      await tester.pumpAndSettle();
      expect(find.text('page /kana'), findsOneWidget);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.selectedIndex, 3);
    });

    testWidgets('Settings is the fifth destination', (tester) async {
      await pumpAt(
        tester,
        412,
        915,
        kanaTabEnabled: true,
        initialLocation: '/settings',
      );
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.destinations, hasLength(5));
      expect(bar.selectedIndex, 4);
    });
  });
}
