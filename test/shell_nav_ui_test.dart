import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_anime/app/theme.dart';
import 'package:my_anime/app/router.dart';
import 'package:my_anime/l10n/app_localizations.dart';
import 'package:my_anime/shared/providers/app_settings.dart';
import 'package:my_anime/shared/utils/adaptive_layout.dart';
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

  // The Expressive bottom bar (the default style) has this key.
  const island = ValueKey('floatingNavBarIsland');

  Future<GoRouter> pumpAt(
    WidgetTester tester,
    double width,
    double height, {
    bool kanaTabEnabled = false,
    AppUiStyle uiStyle = AppUiStyle.expressive,
    // The app default is bottom everywhere; most cases here exercise the
    // wide-window rail, so they default to side-on-wide.
    NavPlacement placement = NavPlacement.sideOnWide,
    bool railRight = false,
    String initialLocation = '/home',
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.reset);

    GoRoute stub(String path) => GoRoute(
      path: path,
      redirect: path == '/kana' ? kanaRouteRedirect : null,
      builder: (context, state) => path == '/manage'
          // A long list with a FAB, laid out the way the real tab pages are:
          // explicit padding passed through navBarAwarePadding.
          ? Scaffold(
              floatingActionButton: FloatingActionButton(
                key: const ValueKey('fab'),
                onPressed: () {},
                child: const Icon(Icons.add),
              ),
              body: Builder(
                builder: (context) => ListView(
                  padding: navBarAwarePadding(
                    context,
                    const EdgeInsets.only(bottom: 80),
                  ),
                  children: [
                    for (var i = 0; i < 40; i++)
                      SizedBox(height: 56, child: Text('row $i')),
                  ],
                ),
              ),
            )
          : Scaffold(body: Center(child: Text('page $path'))),
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
              AppSettings(
                kanaTabEnabled: kanaTabEnabled,
                uiStyle: uiStyle,
                navPlacement: placement,
                navRailOnRight: railRight,
              ),
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
    expect(find.byKey(island), findsOneWidget);
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

  group('bottom bar style', () {
    testWidgets('the default Expressive style floats the bar as an island', (
      tester,
    ) async {
      await pumpAt(tester, 412, 915);
      expect(find.byKey(island), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      // Only the selected destination shows its label; the others are icons
      // with tooltips.
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Manage'), findsNothing);
      expect(find.byTooltip('Manage'), findsOneWidget);
    });

    testWidgets('the Material 3 style keeps the classic bar', (tester) async {
      await pumpAt(tester, 412, 915, uiStyle: AppUiStyle.material3);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byKey(island), findsNothing);
    });

    testWidgets('the rail ignores the setting', (tester) async {
      await pumpAt(tester, 933, 704);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byKey(island), findsNothing);
    });

    testWidgets('tapping an island destination navigates', (tester) async {
      await pumpAt(tester, 412, 915);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.text('page /settings'), findsOneWidget);
    });
  });

  group('content behind the Expressive bar (1.7.2)', () {
    testWidgets('the last row and the FAB clear the floating bar', (
      tester,
    ) async {
      await pumpAt(tester, 412, 915, initialLocation: '/manage');
      final barTop = tester.getRect(find.byKey(island)).top;
      expect(
        tester.getRect(find.byKey(const ValueKey('fab'))).bottom,
        lessThanOrEqualTo(barTop),
      );
      // Before scrolling, rows are drawn behind the bar.
      expect(tester.getRect(find.text('row 14')).bottom, greaterThan(barTop));
      await tester.scrollUntilVisible(find.text('row 39'), 400);
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('row 39')).bottom,
        lessThanOrEqualTo(barTop),
      );
    });

    testWidgets('Material 3 keeps content above its bar', (tester) async {
      await pumpAt(
        tester,
        412,
        915,
        uiStyle: AppUiStyle.material3,
        initialLocation: '/manage',
      );
      final barTop = tester.getRect(find.byType(NavigationBar)).top;
      expect(
        tester.getRect(find.byType(ListView)).bottom,
        lessThanOrEqualTo(barTop),
      );
    });
  });

  group('navigation position (1.7.2)', () {
    test('the default is bottom everywhere', () {
      expect(const AppSettings().navPlacement, NavPlacement.bottom);
    });

    for (final style in AppUiStyle.values) {
      testWidgets('bottom keeps the bar on a wide window (${style.name})', (
        tester,
      ) async {
        await pumpAt(
          tester,
          933,
          704,
          uiStyle: style,
          placement: NavPlacement.bottom,
        );
        expect(find.byType(NavigationRail), findsNothing);
        expect(
          style == AppUiStyle.expressive
              ? find.byKey(island)
              : find.byType(NavigationBar),
          findsOneWidget,
        );
      });

      testWidgets('side puts the rail on a phone too (${style.name})', (
        tester,
      ) async {
        await pumpAt(
          tester,
          412,
          915,
          uiStyle: style,
          placement: NavPlacement.side,
        );
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byKey(island), findsNothing);
        expect(find.byType(NavigationBar), findsNothing);
      });

      testWidgets('the rail can sit on the right (${style.name})', (
        tester,
      ) async {
        await pumpAt(tester, 933, 704, uiStyle: style, railRight: true);
        final rail = tester.getRect(find.byType(NavigationRail));
        expect(rail.right, 933);
        expect(find.text('page /home'), findsOneWidget);
      });
    }

    testWidgets('side on wide keeps the bar on a phone', (tester) async {
      await pumpAt(tester, 412, 915);
      expect(find.byKey(island), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('the rail sits on the left by default', (tester) async {
      await pumpAt(tester, 933, 704);
      expect(tester.getTopLeft(find.byType(NavigationRail)).dx, 0);
    });
  });

  group('Kana tab off (the default)', () {
    testWidgets('the bar and the rail both carry four destinations', (
      tester,
    ) async {
      await pumpAt(tester, 412, 915, uiStyle: AppUiStyle.material3);
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
        uiStyle: AppUiStyle.material3,
      );
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.destinations, hasLength(5));
      expect(bar.selectedIndex, 4);
    });
  });
}
