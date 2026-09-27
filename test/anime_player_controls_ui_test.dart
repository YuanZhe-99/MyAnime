import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/views/anime_player_controls.dart';
import 'package:my_anime/l10n/app_localizations.dart';

import 'support/fake_anime_player.dart';

/// Purpose: Test the 1.6.5 player controls overlay with a fake decoder.
/// Inputs: None.
/// Returns: None.
/// Side effects: Widget tests only.
/// Notes: The overlay sits in an 800 x 450 box; (100, 100) is empty video
/// area, away from the centre buttons and the bottom bar.
void main() {
  const empty = Offset(100, 100);

  Future<FakeAnimePlayer> mount(
    WidgetTester tester, {
    double rate = 1.0,
    ValueChanged<double>? onRate,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 450);
    addTearDown(tester.view.reset);
    final player = FakeAnimePlayer()
      ..currentRate = rate
      ..currentDuration = const Duration(seconds: 60)
      ..currentPosition = const Duration(seconds: 10);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: AnimePlayerControls(
            player: player,
            fullscreen: null,
            title: 'Episode',
            onRateSelected: onRate,
          ),
        ),
      ),
    );
    return player;
  }

  test('pure helpers', () {
    expect(boostedPlaybackRate(1.0), 2.0);
    expect(boostedPlaybackRate(1.5), 2.5);
    expect(boostedPlaybackRate(2.0), 3.0);
    expect(boostedPlaybackRate(3.0), 3.0);
    expect(formatPlaybackRate(0.25), '0.25x');
    expect(formatPlaybackRate(1.0), '1.0x');
    const hour = Duration(hours: 1);
    // A full-width swipe covers at most 90 seconds of a long episode.
    expect(
      dragSeekTarget(
        start: const Duration(minutes: 10),
        dx: 400,
        width: 400,
        duration: hour,
      ),
      const Duration(minutes: 11, seconds: 30),
    );
    // A short clip maps the full width to its whole length, clamped.
    expect(
      dragSeekTarget(
        start: const Duration(seconds: 10),
        dx: -400,
        width: 400,
        duration: const Duration(seconds: 60),
      ),
      Duration.zero,
    );
    expect(
      dragSeekTarget(
        start: const Duration(seconds: 5),
        dx: 100,
        width: 400,
        duration: Duration.zero,
      ),
      const Duration(seconds: 5),
    );
  });

  testWidgets('double tap toggles play and pause', (tester) async {
    final player = await mount(tester);
    await tester.tapAt(empty);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(empty);
    await tester.pump(const Duration(milliseconds: 400));
    expect(player.toggles, 1);
  });

  testWidgets('seek buttons jump five seconds and clamp', (tester) async {
    final player = await mount(tester);
    await tester.tap(find.byTooltip('Forward 5 seconds'));
    await tester.pump();
    expect(player.seeks.last, const Duration(seconds: 15));
    player.emitPosition(const Duration(seconds: 2));
    await tester.pump();
    await tester.tap(find.byTooltip('Back 5 seconds'));
    await tester.pump();
    expect(player.seeks.last, Duration.zero);
    player.emitPosition(const Duration(seconds: 58));
    await tester.pump();
    await tester.tap(find.byTooltip('Forward 5 seconds'));
    await tester.pump();
    expect(player.seeks.last, const Duration(seconds: 60));
  });

  testWidgets('holding speeds up by one step and releasing restores', (
    tester,
  ) async {
    final player = await mount(tester, rate: 1.5);
    final gesture = await tester.startGesture(empty);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(player.rateCalls.last, 2.5);
    expect(find.byKey(const ValueKey('animePlayerBoost')), findsOneWidget);
    expect(find.text('2.5x'), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(player.rateCalls.last, 1.5);
    expect(find.byKey(const ValueKey('animePlayerBoost')), findsNothing);
  });

  testWidgets('holding at 3x stays at 3x', (tester) async {
    final player = await mount(tester, rate: 3.0);
    final gesture = await tester.startGesture(empty);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(player.rateCalls.last, 3.0);
    await gesture.up();
    await tester.pump();
    expect(player.rateCalls.last, 3.0);
  });

  testWidgets('a horizontal swipe previews and seeks on release', (
    tester,
  ) async {
    final player = await mount(tester);
    final gesture = await tester.startGesture(empty);
    await gesture.moveBy(const Offset(20, 0));
    await gesture.moveBy(const Offset(200, 0));
    await tester.pump();
    expect(find.byKey(const ValueKey('animePlayerDragLabel')), findsOneWidget);
    expect(player.seeks, isEmpty);
    await gesture.up();
    await tester.pump();
    expect(find.byKey(const ValueKey('animePlayerDragLabel')), findsNothing);
    // 800 px is the whole 60 s clip, so about 200 px is about 15 s.
    expect(
      player.seeks.single.inMilliseconds,
      closeTo(const Duration(seconds: 25).inMilliseconds, 2000),
    );
    // Let the double-tap recognizer's countdown expire.
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('the speed menu offers six speeds and reports the choice', (
    tester,
  ) async {
    double? reported;
    final player = await mount(tester, onRate: (r) => reported = r);
    await tester.tap(find.byKey(const ValueKey('animePlayerSpeed')));
    await tester.pumpAndSettle();
    for (final r in ['0.25x', '0.5x', '1.5x', '2.0x', '3.0x']) {
      expect(find.text(r), findsOneWidget);
    }
    await tester.tap(
      find.ancestor(
        of: find.text('2.0x'),
        matching: find.byType(CheckedPopupMenuItem<double>),
      ),
    );
    await tester.pumpAndSettle();
    expect(player.rateCalls.last, 2.0);
    expect(reported, 2.0);
  });

  testWidgets('controls hide while playing and stay while paused', (
    tester,
  ) async {
    final player = await mount(tester);
    double opacity() =>
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;
    player.emitPlaying(true);
    await tester.pump(const Duration(seconds: 4));
    expect(opacity(), 0);
    await tester.tapAt(empty);
    await tester.pump(const Duration(milliseconds: 400));
    expect(opacity(), 1);
    player.emitPlaying(false);
    await tester.pump(const Duration(seconds: 5));
    expect(opacity(), 1);
  });

  testWidgets('keyboard: space toggles, arrows jump five seconds', (
    tester,
  ) async {
    final player = await mount(tester);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(player.seeks.last, const Duration(seconds: 15));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(player.seeks.last, const Duration(seconds: 10));
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(player.toggles, 1);
  });
}
