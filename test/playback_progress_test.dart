import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/app/data_modules.dart';
import 'package:my_anime/features/anime/models/anime.dart';
import 'package:my_anime/features/anime/models/playback_progress.dart';
import 'package:my_anime/features/anime/services/anime_storage.dart';
import 'package:my_anime/features/anime/services/playback_progress_merge.dart';
import 'package:my_anime/features/anime/services/playback_progress_service.dart';
import 'package:my_anime/features/anime/services/playback_progress_store.dart';
import 'package:my_anime/shared/utils/playback_time.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Fake application-documents provider (pattern from existing app tests).
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsPath);
  final String documentsPath;
  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

final _t1 = DateTime.utc(2026, 9, 1);
final _t2 = DateTime.utc(2026, 9, 2);

/// Purpose: Build one resume point.
/// Inputs: `episode`, `position` seconds, `at`.
/// Returns: `PlaybackProgressEntry` for record `a`.
/// Side effects: None.
/// Notes: Test helper; the duration is 100 s so seconds read as percent.
PlaybackProgressEntry entry(int episode, int position, DateTime at) =>
    PlaybackProgressEntry(
      key: playbackProgressKey('a', episode),
      animeId: 'a',
      episode: episode,
      pageUrl: 'https://anime1.me/$episode',
      positionMs: position * 1000,
      durationMs: 100000,
      updatedAt: at,
    );

/// Purpose: Build store contents from entries.
/// Inputs: `entries`.
/// Returns: `PlaybackProgressData`.
/// Side effects: None.
/// Notes: Test helper.
PlaybackProgressData data(List<PlaybackProgressEntry> entries) =>
    PlaybackProgressData(entries: {for (final e in entries) e.key: e});

/// Purpose: Encode store contents the way the file stores them.
/// Inputs: `d`.
/// Returns: `String`.
/// Side effects: None.
/// Notes: Test helper.
String enc(PlaybackProgressData d) => encodePlaybackProgress(d);

/// Purpose: Decode a merged file.
/// Inputs: `json`.
/// Returns: `PlaybackProgressData`.
/// Side effects: None.
/// Notes: Test helper.
PlaybackProgressData dec(String json) =>
    PlaybackProgressData.fromJson(jsonDecode(json));

/// Purpose: Test the synced playback progress file (1.6.5).
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes temporary app storage directories.
/// Notes: Covers the 5% / 95% rule, the model, the conflict-free merge, the
/// store and the service's watched mark.
void main() {
  group('rule', () {
    const d = Duration(seconds: 100);
    test('unknown duration is ignored', () {
      expect(
        classifyPlayback(const Duration(seconds: 50), Duration.zero),
        PlaybackProgressRule.ignore,
      );
    });
    test('under 5% is ignored, 5% is saved', () {
      expect(
        classifyPlayback(const Duration(milliseconds: 4900), d),
        PlaybackProgressRule.ignore,
      );
      expect(
        classifyPlayback(const Duration(seconds: 5), d),
        PlaybackProgressRule.save,
      );
    });
    test('95% is saved, past 95% completes', () {
      expect(
        classifyPlayback(const Duration(seconds: 95), d),
        PlaybackProgressRule.save,
      );
      expect(
        classifyPlayback(const Duration(milliseconds: 95100), d),
        PlaybackProgressRule.complete,
      );
    });
    test('keys separate numbered episodes from extras', () {
      expect(playbackProgressKey('a', 3), 'a/3');
      expect(
        playbackProgressExtraKey('a', 'https://anime1.me/9'),
        'a/extra/https://anime1.me/9',
      );
      expect(
        PlaybackProgressService.keyFor('a', null, 'https://anime1.me/9'),
        'a/extra/https://anime1.me/9',
      );
      expect(PlaybackProgressService.keyFor('a', 3, 'x'), 'a/3');
    });
  });

  group('model', () {
    test('round trip keeps unknown keys at both levels', () {
      final raw = {
        'version': 1,
        'future': true,
        'entries': {
          'a/1': {
            'animeId': 'a',
            'episode': 1,
            'positionMs': 1000,
            'durationMs': 2000,
            'updatedAt': '2026-09-01T00:00:00.000Z',
            'note': 'x',
          },
        },
      };
      final decoded = PlaybackProgressData.fromJson(raw);
      expect(decoded.extraJson['future'], true);
      expect(decoded.entries['a/1']!.extraJson['note'], 'x');
      expect(jsonDecode(enc(decoded)), raw);
    });
    test('malformed entries are dropped and a non-object is rejected', () {
      final decoded = PlaybackProgressData.fromJson({
        'entries': {
          'a/1': {'positionMs': 'x'},
          'a/2': {
            'positionMs': 1,
            'durationMs': 0,
            'updatedAt': '2026-09-01T00:00:00Z',
          },
          'a/3': {
            'positionMs': 1,
            'durationMs': 5,
            'updatedAt': '2026-09-01T00:00:00Z',
          },
        },
      });
      expect(decoded.entries.keys, ['a/3']);
      expect(decoded.entries['a/3']!.animeId, 'a');
      expect(() => PlaybackProgressData.fromJson([]), throwsFormatException);
    });
    test('encoding is sorted and stable', () {
      final a = enc(data([entry(2, 10, _t1), entry(1, 10, _t1)]));
      final b = enc(data([entry(1, 10, _t1), entry(2, 10, _t1)]));
      expect(a, b);
      expect(a.indexOf('"a/1"'), lessThan(a.indexOf('"a/2"')));
      expect(a, contains('\n  "entries"'));
    });
    test('latestFor picks the newest entry of one record', () {
      final d = data([entry(1, 10, _t2), entry(2, 10, _t1)]);
      expect(d.latestFor('a')!.episode, 1);
      expect(d.latestFor('b'), isNull);
    });
  });

  group('merge', () {
    test('a first sync keeps both sides', () {
      final merged = dec(
        mergePlaybackProgressJson(
          enc(data([entry(1, 10, _t1)])),
          enc(data([entry(2, 10, _t1)])),
          null,
        ),
      );
      expect(merged.entries.keys.toSet(), {'a/1', 'a/2'});
    });
    test('on both sides the newer position wins, a tie keeps local', () {
      final newer = dec(
        mergePlaybackProgressJson(
          enc(data([entry(1, 10, _t1)])),
          enc(data([entry(1, 40, _t2)])),
          enc(data([])),
        ),
      );
      expect(newer.entries['a/1']!.positionMs, 40000);
      final tie = dec(
        mergePlaybackProgressJson(
          enc(data([entry(1, 10, _t1)])),
          enc(data([entry(1, 40, _t1)])),
          enc(data([])),
        ),
      );
      expect(tie.entries['a/1']!.positionMs, 10000);
    });
    test('an entry finished on the other side stays deleted', () {
      final merged = dec(
        mergePlaybackProgressJson(
          enc(data([entry(1, 50, _t2)])),
          enc(data([])),
          enc(data([entry(1, 10, _t1)])),
        ),
      );
      expect(merged.entries, isEmpty);
    });
    test('a new entry on one side is kept', () {
      final merged = dec(
        mergePlaybackProgressJson(
          enc(data([])),
          enc(data([entry(3, 20, _t1)])),
          enc(data([])),
        ),
      );
      expect(merged.entries.keys, ['a/3']);
    });
    test('an unreadable base is treated as absent', () {
      final merged = dec(
        mergePlaybackProgressJson(
          enc(data([entry(1, 10, _t1)])),
          enc(data([])),
          'not json',
        ),
      );
      expect(merged.entries.keys, ['a/1']);
    });
    test('the module never reports a conflict', () {
      final outcome = mergePlaybackProgressModule(
        localJson: enc(data([entry(1, 10, _t1)])),
        remoteJson: enc(data([entry(1, 60, _t2)])),
        baseJson: enc(data([entry(1, 5, _t1)])),
      );
      expect(outcome.conflicts, isEmpty);
      expect(dec(outcome.mergedJson!).entries['a/1']!.positionMs, 60000);
      expect(playbackProgressFileName, PlaybackProgressStore.fileName);
      expect(() => validatePlaybackProgressJson('[]'), throwsFormatException);
    });
  });

  group('store and service', () {
    late Directory tempDir;
    late File file;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('myanime_playback');
      final docs = Directory(p.join(tempDir.path, 'docs'))..createSync();
      PathProviderPlatform.instance = _FakePathProvider(docs.path);
      file = File(p.join(docs.path, 'MyAnime', playbackProgressFileName));
      await AnimeStorage.save(
        AnimeData(
          animes: [
            Anime(id: 'a', title: 'Example', createdAt: _t1, modifiedAt: _t1),
          ],
        ),
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('an empty store never creates the file', () async {
      await PlaybackProgressStore.update((_) {});
      expect(file.existsSync(), isFalse);
      expect((await PlaybackProgressStore.load()).entries, isEmpty);
    });

    test('put and remove round-trip through the file', () async {
      await PlaybackProgressStore.put(entry(1, 30, _t1));
      expect(file.readAsStringSync(), enc(await PlaybackProgressStore.load()));
      expect((await PlaybackProgressStore.load()).entries.keys, ['a/1']);
      await PlaybackProgressStore.remove('a/1');
      expect((await PlaybackProgressStore.load()).entries, isEmpty);
    });

    test('a corrupt file reads as empty', () async {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('{broken');
      expect((await PlaybackProgressStore.load()).entries, isEmpty);
    });

    test('an unreadable file is never overwritten by a write', () async {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('{broken');
      await expectLater(
        PlaybackProgressStore.put(entry(1, 30, _t1)),
        throwsA(isA<FormatException>()),
      );
      expect(file.readAsStringSync(), '{broken');
    });

    test('an unreadable file still lets a finished episode be marked', () async {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('{broken');
      await PlaybackProgressService.report(
        animeId: 'a',
        episode: 5,
        pageUrl: 'https://anime1.me/5',
        position: const Duration(seconds: 96),
        duration: const Duration(seconds: 100),
        now: _t2,
      );
      expect(file.readAsStringSync(), '{broken');
      final anime = (await AnimeStorage.load()).animes.single;
      expect(anime.episodeStatuses[5], EpisodeStatus.watched);
    });

    Future<PlaybackProgressRule> report(int episode, int seconds) =>
        PlaybackProgressService.report(
          animeId: 'a',
          episode: episode,
          pageUrl: 'https://anime1.me/$episode',
          position: Duration(seconds: seconds),
          duration: const Duration(seconds: 100),
          now: _t2,
        );

    test('under 5% leaves an existing resume point alone', () async {
      await report(1, 40);
      expect(await report(1, 2), PlaybackProgressRule.ignore);
      final saved = (await PlaybackProgressStore.load()).entries['a/1']!;
      expect(saved.positionMs, 40000);
    });

    test('past 95% deletes the entry and marks the episode watched', () async {
      await report(2, 40);
      final before = (await AnimeStorage.load()).animes.single.modifiedAt;
      expect(await report(2, 96), PlaybackProgressRule.complete);
      expect((await PlaybackProgressStore.load()).entries, isEmpty);
      final anime = (await AnimeStorage.load()).animes.single;
      expect(anime.episodeStatuses[2], EpisodeStatus.watched);
      expect(anime.modifiedAt.isAfter(before), isTrue);
    });

    test('an episode already watched is not rewritten', () async {
      await PlaybackProgressService.markWatched('a', 3);
      final first = (await AnimeStorage.load()).animes.single.modifiedAt;
      expect(await PlaybackProgressService.markWatched('a', 3), isFalse);
      expect((await AnimeStorage.load()).animes.single.modifiedAt, first);
    });

    test('finishing an extra never touches the anime record', () async {
      final before = File(
        p.join(file.parent.path, animeDataFileName),
      ).readAsStringSync();
      await PlaybackProgressService.report(
        animeId: 'a',
        episode: null,
        pageUrl: 'https://anime1.me/sp',
        position: const Duration(seconds: 99),
        duration: const Duration(seconds: 100),
      );
      expect(
        File(p.join(file.parent.path, animeDataFileName)).readAsStringSync(),
        before,
      );
    });
  });

  group('clock', () {
    test('formats minutes and hours', () {
      expect(formatPlaybackClock(Duration.zero), '0:00');
      expect(formatPlaybackClock(const Duration(seconds: 754)), '12:34');
      expect(
        formatPlaybackClock(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
      expect(formatPlaybackClock(const Duration(seconds: -5)), '0:00');
    });
  });
}
