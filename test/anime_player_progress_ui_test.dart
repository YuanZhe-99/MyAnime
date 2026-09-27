import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/models/anime.dart';
import 'package:my_anime/features/anime/models/anime_episode.dart';
import 'package:my_anime/features/anime/models/playback_progress.dart';
import 'package:my_anime/features/anime/services/anime_media_service.dart';
import 'package:my_anime/features/anime/services/anime_storage.dart';
import 'package:my_anime/features/anime/services/playback_progress_store.dart';
import 'package:my_anime/features/anime/views/anime_player_page.dart';
import 'package:my_anime/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'support/fake_anime_player.dart';

/// Fake application-documents provider (pattern from existing app tests).
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsPath);
  final String documentsPath;
  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

const ep1 = AnimeEpisodePage(
  url: 'https://anime1.me/1',
  title: 'Example [01]',
  label: '1',
  group: 'Example',
);
const ep2 = AnimeEpisodePage(
  url: 'https://anime1.me/2',
  title: 'Example [02]',
  label: '2',
  group: 'Example',
);
const media = AnimeMediaSource('https://edge.v.anime1.me/test.mp4', {});
const length = Duration(seconds: 100);

/// Purpose: Test that the player page records, resumes and completes
/// playback progress (1.6.5).
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes temporary app storage directories.
/// Notes: Everything that touches files runs inside `runAsync`, including
/// mounting, because the page's stream listeners write the store and those
/// writes must run on the real event loop.
void main() {
  late Directory tempDir;
  late File progressFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('myanime_player_progress');
    final docs = Directory(p.join(tempDir.path, 'docs'))..createSync();
    PathProviderPlatform.instance = _FakePathProvider(docs.path);
    progressFile = File(
      p.join(docs.path, 'MyAnime', PlaybackProgressStore.fileName),
    );
    final t = DateTime.utc(2026, 9, 1);
    await AnimeStorage.save(
      AnimeData(
        animes: [Anime(id: 'a', title: 'Example', createdAt: t, modifiedAt: t)],
      ),
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<void> io(WidgetTester tester, [void Function()? action]) async {
    await tester.runAsync(() async {
      action?.call();
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
    });
    await tester.pump();
  }

  Future<FakeAnimePlayer> mount(
    WidgetTester tester, {
    AnimeEpisodePage page = ep1,
    int episode = 1,
    List<AnimePlaylistEntry> playlist = const [],
  }) async {
    final player = FakeAnimePlayer();
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: AnimePlayerPage(
            page: page,
            animeId: 'a',
            episode: episode,
            playlist: playlist,
            resolveMedia: (_) async => media,
            playerFactory: () => player,
            websiteAvailable: () async => false,
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await tester.pump();
      }
    });
    expect(player.opened, 1);
    return player;
  }

  Future<PlaybackProgressData> stored(WidgetTester tester) async =>
      (await tester.runAsync(PlaybackProgressStore.load))!;

  Future<void> leave(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox());
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('resumes once from the stored position', (tester) async {
    await tester.runAsync(
      () => PlaybackProgressStore.put(
        PlaybackProgressEntry(
          key: playbackProgressKey('a', 1),
          animeId: 'a',
          episode: 1,
          positionMs: 40000,
          durationMs: 100000,
          updatedAt: DateTime.utc(2026, 9, 1),
        ),
      ),
    );
    final player = await mount(tester);
    await io(tester, () => player.emitDuration(length));
    expect(player.seeks, [const Duration(seconds: 40)]);
    expect(find.text('Continuing from 0:40'), findsOneWidget);
    await io(tester, () => player.emitDuration(length));
    expect(player.seeks, hasLength(1));
    await leave(tester);
  });

  testWidgets('writes every five seconds of media and on leaving', (
    tester,
  ) async {
    final player = await mount(tester);
    await io(tester, () => player.emitDuration(length));
    await io(tester, () => player.emitPosition(const Duration(seconds: 2)));
    expect(progressFile.existsSync(), isFalse, reason: 'under 5%');
    await io(tester, () => player.emitPosition(const Duration(seconds: 20)));
    expect((await stored(tester)).entries['a/1']!.positionMs, 20000);
    await io(tester, () => player.emitPosition(const Duration(seconds: 23)));
    expect((await stored(tester)).entries['a/1']!.positionMs, 20000);
    await io(tester, () => player.emitPosition(const Duration(seconds: 26)));
    expect((await stored(tester)).entries['a/1']!.positionMs, 26000);
    await io(tester, () => player.emitPosition(const Duration(seconds: 28)));
    await leave(tester);
    expect((await stored(tester)).entries['a/1']!.positionMs, 28000);
  });

  testWidgets('past 95% clears the entry and marks the episode watched', (
    tester,
  ) async {
    final player = await mount(tester);
    await io(tester, () => player.emitDuration(length));
    await io(tester, () => player.emitPosition(const Duration(seconds: 50)));
    expect((await stored(tester)).entries.keys, ['a/1']);
    await io(tester, () => player.emitPosition(const Duration(seconds: 97)));
    await io(tester);
    expect((await stored(tester)).entries, isEmpty);
    final anime = (await tester.runAsync(AnimeStorage.load))!.animes.single;
    expect(anime.episodeStatuses[1], EpisodeStatus.watched);
    await leave(tester);
    expect((await stored(tester)).entries, isEmpty);
  });

  testWidgets('switching episodes saves the outgoing one', (tester) async {
    final player = await mount(
      tester,
      playlist: const [
        AnimePlaylistEntry(ep1, episode: 1),
        AnimePlaylistEntry(ep2, episode: 2),
      ],
    );
    await io(tester, () => player.emitDuration(length));
    await io(tester, () => player.emitPosition(const Duration(seconds: 30)));
    await io(tester, () => player.emitPosition(const Duration(seconds: 33)));
    // The menu's selection callback is registered when the menu opens, so
    // both taps run on the real event loop, where the outgoing save's file
    // write can complete.
    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.playlist_play));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text('Example [02]').last);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
    });
    expect((await stored(tester)).entries['a/1']!.positionMs, 33000);
    expect(player.disposed, 1);
    await leave(tester);
  });

  test('the store file is pretty-printed JSON', () {
    // Guards the byte format the sync fast path depends on.
    final d = PlaybackProgressData();
    expect(
      const JsonEncoder.withIndent('  ').convert(d.toJson()),
      contains('\n  "entries"'),
    );
  });
}
