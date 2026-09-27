import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/models/anime_episode.dart';
import 'package:my_anime/features/anime/services/anime_media_service.dart';
import 'package:my_anime/features/anime/views/anime_native_player.dart';
import 'package:my_anime/features/anime/views/anime_player_page.dart';
import 'package:my_anime/l10n/app_localizations.dart';

class _Player implements AnimeNativePlayer {
  final failures = StreamController<String>.broadcast();
  final progress = StreamController<Duration>.broadcast();
  int disposed = 0;
  int opened = 0;
  bool failOpen = false;
  bool failDispose = false;
  @override
  Stream<String> get errors => failures.stream;
  @override
  Stream<Duration> get positions => progress.stream;
  @override
  Widget buildVideo() => const Text('native video');
  @override
  Future<void> open(AnimeMediaSource source) async {
    opened++;
    if (failOpen) throw StateError('decoder failure');
  }

  @override
  Future<void> dispose() async {
    disposed++;
    await failures.close();
    await progress.close();
    if (failDispose) throw StateError('cleanup failed');
  }
}

const episode = AnimeEpisodePage(
  url: 'https://anime1.me/episode',
  title: 'Episode',
  label: '1',
  group: 'Example',
);
const media = AnimeMediaSource('https://edge.v.anime1.me/test.mp4', {});

/// Purpose: Verify native startup, deterministic timeout and disposal without codecs or real network.
/// Inputs: None.
/// Returns: None.
/// Side effects: Widget navigation and controlled fake streams only.
/// Notes: WebView is deliberately unavailable so fallback errors remain testable on every host.
void main() {
  Future<void> mount(
    WidgetTester tester,
    _Player player,
    Future<AnimeMediaSource?> Function(String) resolver,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: AnimePlayerPage(
          page: episode,
          resolveMedia: resolver,
          playerFactory: () => player,
          websiteAvailable: () async => false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('native success stays native and leaving stops it once', (
    tester,
  ) async {
    final player = _Player();
    await mount(tester, player, (_) async => media);
    expect(find.text('native video'), findsOneWidget);
    player.progress.add(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(seconds: 25));
    expect(find.text('native video'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(player.opened, 1);
    expect(player.disposed, 1);
  });

  testWidgets('native error disposes and falls back once without retrying', (
    tester,
  ) async {
    final player = _Player();
    var resolves = 0;
    await mount(tester, player, (_) async {
      resolves++;
      return media;
    });
    player.failures.add('decoder failure');
    await tester.pump();
    await tester.pump();
    expect(find.text('Website player'), findsOneWidget);
    expect(find.text('native video'), findsNothing);
    expect(player.disposed, 1);
    await tester.pump(const Duration(seconds: 60));
    expect(resolves, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('decoder cleanup failure does not block website fallback', (
    tester,
  ) async {
    final player = _Player()..failDispose = true;
    await mount(tester, player, (_) async => media);
    player.failures.add('decoder failure');
    await tester.pump();
    await tester.pump();
    expect(find.text('Website player'), findsOneWidget);
    expect(player.disposed, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('native startup timeout releases a stalled decoder', (
    tester,
  ) async {
    final player = _Player();
    await mount(tester, player, (_) async => media);
    await tester.pump(const Duration(seconds: 21));
    await tester.pump();
    expect(player.disposed, 1);
    expect(find.text('Website player'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'expired or unsupported media falls back without creating a player',
    (tester) async {
      final player = _Player();
      await mount(tester, player, (_) async => null);
      expect(find.text('Website player'), findsOneWidget);
      expect(player.opened, 0);
      await player.dispose();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('late resolution after leaving cannot start audio', (
    tester,
  ) async {
    final player = _Player();
    final pending = Completer<AnimeMediaSource?>();
    await mount(tester, player, (_) => pending.future);
    await tester.pumpWidget(const SizedBox());
    pending.complete(media);
    await tester.pump();
    expect(player.opened, 0);
    await player.dispose();
  });
}
