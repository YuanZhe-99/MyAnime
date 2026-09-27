import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../shared/services/auto_sync_service.dart';
import '../models/playback_progress.dart';
import 'anime_storage.dart';
import 'playback_progress_merge.dart';

/// Owns `playback_progress.json` (1.6.5): the resume point of every episode
/// played in the app.
///
/// The file is registered in `lib/app/data_modules.dart`, so it syncs over
/// WebDAV and is backed up; a save therefore notifies auto-sync. Every write
/// is a read-modify-write through [update], serialised inside this process.
class PlaybackProgressStore {
  /// Purpose: Prevent direct instantiation and expose only static members.
  /// Inputs: None.
  /// Returns: A new `PlaybackProgressStore._` instance.
  /// Side effects: None.
  /// Notes: None.
  const PlaybackProgressStore._();

  /// The file's name under the app directory. Must match
  /// `playbackProgressFileName` in `lib/app/data_modules.dart`.
  static const fileName = 'playback_progress.json';

  static Future<void> _tail = Future.value();

  /// Purpose: Resolve the file.
  /// Inputs: None.
  /// Returns: `Future<File>`.
  /// Side effects: May create the app directory.
  /// Notes: Internal helper used within this file only.
  static Future<File> _file() async {
    final dir = await AnimeStorage.getAppDir();
    return File(p.join(dir.path, fileName));
  }

  /// Purpose: Load the store.
  /// Inputs: None.
  /// Returns: `Future<PlaybackProgressData>` — empty when the file is absent
  /// or unreadable.
  /// Side effects: Reads the file.
  /// Notes: Entries for records that no longer exist are kept on disk;
  /// pruning here would read to sync as a deliberate deletion.
  static Future<PlaybackProgressData> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return PlaybackProgressData();
      return PlaybackProgressData.fromJson(
        jsonDecode(await file.readAsString()),
      );
    } catch (_) {
      return PlaybackProgressData();
    }
  }

  /// Purpose: Apply one change to the store and save it.
  /// Inputs: `mutate` — edits the loaded data in place.
  /// Returns: `Future<PlaybackProgressData>` — the data after the change.
  /// Side effects: Writes the file atomically (tmp then rename) and notifies
  /// auto-sync, but only when the bytes changed; never creates the file for
  /// an empty store.
  /// Notes: Calls are queued, so concurrent updates apply one after another.
  static Future<PlaybackProgressData> update(
    void Function(PlaybackProgressData data) mutate,
  ) {
    final done = Completer<PlaybackProgressData>();
    _tail = _tail.then((_) async {
      try {
        done.complete(await _apply(mutate));
      } catch (e, s) {
        done.completeError(e, s);
      }
    });
    return done.future;
  }

  /// Purpose: Run one queued update.
  /// Inputs: `mutate`.
  /// Returns: `Future<PlaybackProgressData>`.
  /// Side effects: See [update].
  /// Notes: Internal helper used within this file only.
  static Future<PlaybackProgressData> _apply(
    void Function(PlaybackProgressData data) mutate,
  ) async {
    final file = await _file();
    final exists = await file.exists();
    final before = exists ? await file.readAsString() : null;
    PlaybackProgressData data;
    try {
      data = before == null
          ? PlaybackProgressData()
          : PlaybackProgressData.fromJson(jsonDecode(before));
    } catch (_) {
      data = PlaybackProgressData();
    }
    mutate(data);
    final after = encodePlaybackProgress(data);
    if (after == before) return data;
    if (before == null &&
        after == encodePlaybackProgress(PlaybackProgressData())) {
      return data;
    }
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(after, flush: true);
    await tmp.rename(file.path);
    AutoSyncService.instance.notifySaved();
    return data;
  }

  /// Purpose: Store or replace one resume point.
  /// Inputs: `entry`.
  /// Returns: `Future<PlaybackProgressData>`.
  /// Side effects: Writes the file.
  /// Notes: None.
  static Future<PlaybackProgressData> put(PlaybackProgressEntry entry) =>
      update((d) {
        final old = d.entries[entry.key];
        d.entries[entry.key] = old == null || old.extraJson.isEmpty
            ? entry
            : PlaybackProgressEntry(
                key: entry.key,
                animeId: entry.animeId,
                episode: entry.episode,
                pageUrl: entry.pageUrl,
                positionMs: entry.positionMs,
                durationMs: entry.durationMs,
                updatedAt: entry.updatedAt,
                extraJson: old.extraJson,
              );
      });

  /// Purpose: Delete one resume point.
  /// Inputs: `key`.
  /// Returns: `Future<PlaybackProgressData>`.
  /// Side effects: Writes the file when the key existed.
  /// Notes: Used when an episode is finished.
  static Future<PlaybackProgressData> remove(String key) =>
      update((d) => d.entries.remove(key));
}
