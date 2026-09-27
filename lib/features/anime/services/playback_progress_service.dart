import '../models/anime.dart';
import '../models/playback_progress.dart';
import 'anime_storage.dart';
import 'playback_progress_store.dart';

/// Applies the 1.6.5 playback-progress rules: positions under 5% are not
/// recorded, positions past 95% finish the episode — the resume point is
/// deleted and a numbered episode is marked watched — and everything in
/// between becomes the resume point.
class PlaybackProgressService {
  /// Purpose: Prevent direct instantiation and expose only static members.
  /// Inputs: None.
  /// Returns: A new `PlaybackProgressService._` instance.
  /// Side effects: None.
  /// Notes: None.
  const PlaybackProgressService._();

  /// Purpose: Build the key for an episode or an extra page.
  /// Inputs: `animeId`; `episode` — local number, null for extras;
  /// `pageUrl` — used only for extras.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: None.
  static String keyFor(String animeId, int? episode, String pageUrl) =>
      episode == null
      ? playbackProgressExtraKey(animeId, pageUrl)
      : playbackProgressKey(animeId, episode);

  /// Purpose: Record one playback position.
  /// Inputs: `animeId`; `episode` — null for extras; `pageUrl`; `position`;
  /// `duration`; `now` — injectable clock.
  /// Returns: `Future<PlaybackProgressRule>` — what was done.
  /// Side effects: May write `playback_progress.json`; on completion of a
  /// numbered episode may also write `anime_data.json`.
  /// Notes: `ignore` leaves an existing resume point untouched, so briefly
  /// reopening an episode near its start does not erase where it stopped.
  static Future<PlaybackProgressRule> report({
    required String animeId,
    required int? episode,
    required String pageUrl,
    required Duration position,
    required Duration duration,
    DateTime? now,
  }) async {
    final rule = classifyPlayback(position, duration);
    final key = keyFor(animeId, episode, pageUrl);
    switch (rule) {
      case PlaybackProgressRule.ignore:
        break;
      case PlaybackProgressRule.save:
        await PlaybackProgressStore.put(
          PlaybackProgressEntry(
            key: key,
            animeId: animeId,
            episode: episode,
            pageUrl: pageUrl,
            positionMs: position.inMilliseconds,
            durationMs: duration.inMilliseconds,
            updatedAt: now ?? DateTime.now().toUtc(),
          ),
        );
      case PlaybackProgressRule.complete:
        await PlaybackProgressStore.remove(key);
        if (episode != null) await markWatched(animeId, episode);
    }
    return rule;
  }

  /// Purpose: Mark one local episode watched.
  /// Inputs: `animeId`, `episode`.
  /// Returns: `Future<bool>` — whether anything was written.
  /// Side effects: Rewrites `anime_data.json` with a fresh `modifiedAt`.
  /// Notes: A visible status change, so `modifiedAt` is bumped exactly like
  /// the home page's watched toggle. No-op when already watched or the
  /// record is gone.
  static Future<bool> markWatched(String animeId, int episode) async {
    final data = await AnimeStorage.load();
    final anime = data.animes.where((a) => a.id == animeId).firstOrNull;
    if (anime == null) return false;
    if (anime.episodeStatuses[episode] == EpisodeStatus.watched) return false;
    await AnimeStorage.addOrUpdate(
      anime.copyWith(
        episodeStatuses: Map.of(anime.episodeStatuses)
          ..[episode] = EpisodeStatus.watched,
        modifiedAt: DateTime.now().toUtc(),
      ),
    );
    return true;
  }

  /// Purpose: Return the stored resume point for a key.
  /// Inputs: `key`.
  /// Returns: `Future<PlaybackProgressEntry?>`.
  /// Side effects: Reads the file.
  /// Notes: None.
  static Future<PlaybackProgressEntry?> resumePoint(String key) async =>
      (await PlaybackProgressStore.load()).entries[key];
}
