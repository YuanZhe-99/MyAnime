/// The contents of `playback_progress.json` (1.6.5): where in-app playback
/// of each episode stopped. The file is synced and backed up as its own module
/// (`lib/app/data_modules.dart`), so every class here keeps unknown JSON keys
/// in `extraJson` and writes them back — an older build must never delete a
/// newer build's data.
library;

/// Share of an episode below which no resume point is recorded (5%).
const playbackMinFraction = 0.05;

/// Share of an episode above which the episode counts as finished (95%).
const playbackDoneFraction = 0.95;

/// Purpose: Build the entry key for a numbered local episode.
/// Inputs: `animeId` — the record's stable id; `episode` — local number.
/// Returns: `String` in the form `<animeId>/<episode>`.
/// Side effects: None.
/// Notes: Uses the same local numbering as `Anime.episodeStatuses`.
String playbackProgressKey(String animeId, int episode) => '$animeId/$episode';

/// Purpose: Build the entry key for an extra page without a local number.
/// Inputs: `animeId`; `pageUrl` — the episode page address.
/// Returns: `String` in the form `<animeId>/extra/<pageUrl>`.
/// Side effects: None.
/// Notes: A positive integer can never collide with the `extra/` segment.
String playbackProgressExtraKey(String animeId, String pageUrl) =>
    '$animeId/extra/$pageUrl';

/// What a playback position means for the stored record.
enum PlaybackProgressRule {
  /// Leave the store untouched.
  ignore,

  /// Store this position as the resume point.
  save,

  /// The episode is finished: delete the resume point.
  complete,
}

/// Purpose: Classify a playback position against the 5% / 95% thresholds.
/// Inputs: `position`, `duration`.
/// Returns: `PlaybackProgressRule`.
/// Side effects: None.
/// Notes: An unknown (zero or negative) duration is `ignore`. Exactly 5% and
/// exactly 95% are `save`; only strictly past 95% completes.
PlaybackProgressRule classifyPlayback(Duration position, Duration duration) {
  if (duration <= Duration.zero) return PlaybackProgressRule.ignore;
  final fraction = position.inMilliseconds / duration.inMilliseconds;
  if (fraction < playbackMinFraction) return PlaybackProgressRule.ignore;
  if (fraction > playbackDoneFraction) return PlaybackProgressRule.complete;
  return PlaybackProgressRule.save;
}

/// Purpose: Collect the keys of `json` that `known` does not list.
/// Inputs: `json`; `known`.
/// Returns: `Map<String, dynamic>` — the unknown entries.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
Map<String, dynamic> _unknown(Map json, Set<String> known) => {
  for (final e in json.entries)
    if (e.key is String && !known.contains(e.key)) e.key as String: e.value,
};

/// One resume point.
class PlaybackProgressEntry {
  /// The entry key, from [playbackProgressKey] or [playbackProgressExtraKey].
  final String key;

  /// The record this entry belongs to.
  final String animeId;

  /// Local episode number; null for extras.
  final int? episode;

  /// The episode page the position was recorded on.
  final String? pageUrl;

  /// Playback position in milliseconds.
  final int positionMs;

  /// Media duration in milliseconds, always positive.
  final int durationMs;

  /// When this position was recorded, UTC.
  final DateTime updatedAt;

  /// JSON keys this build does not know.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create one resume point.
  /// Inputs: see fields.
  /// Returns: A new `PlaybackProgressEntry`.
  /// Side effects: None.
  /// Notes: `updatedAt` is normalized to UTC.
  PlaybackProgressEntry({
    required this.key,
    required this.animeId,
    this.episode,
    this.pageUrl,
    required this.positionMs,
    required this.durationMs,
    required DateTime updatedAt,
    Map<String, dynamic>? extraJson,
  }) : updatedAt = updatedAt.toUtc(),
       extraJson = extraJson ?? const {};

  /// Purpose: Read one entry tolerantly.
  /// Inputs: `key` — the map key it was stored under; `json`.
  /// Returns: `PlaybackProgressEntry?` — null when a required field is
  /// missing or malformed.
  /// Side effects: None.
  /// Notes: `animeId` falls back to the part of the key before the first `/`.
  static PlaybackProgressEntry? fromJson(String key, Object? json) {
    if (json is! Map) return null;
    final position = json['positionMs'];
    final duration = json['durationMs'];
    final updated = json['updatedAt'];
    if (position is! int || duration is! int || duration <= 0) return null;
    if (updated is! String) return null;
    final at = DateTime.tryParse(updated);
    if (at == null) return null;
    final slash = key.indexOf('/');
    final animeId = json['animeId'] is String
        ? json['animeId'] as String
        : (slash > 0 ? key.substring(0, slash) : key);
    return PlaybackProgressEntry(
      key: key,
      animeId: animeId,
      episode: json['episode'] is int ? json['episode'] as int : null,
      pageUrl: json['pageUrl'] is String ? json['pageUrl'] as String : null,
      positionMs: position < 0 ? 0 : position,
      durationMs: duration,
      updatedAt: at,
      extraJson: _unknown(json, const {
        'animeId',
        'episode',
        'pageUrl',
        'positionMs',
        'durationMs',
        'updatedAt',
      }),
    );
  }

  /// Purpose: Serialize one entry.
  /// Inputs: None.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: Unknown keys first, then known ones; null fields are omitted.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'animeId': animeId,
    'episode': ?episode,
    'pageUrl': ?pageUrl,
    'positionMs': positionMs,
    'durationMs': durationMs,
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// Purpose: Return the playback position.
  /// Inputs: None.
  /// Returns: `Duration`.
  /// Side effects: None.
  /// Notes: None.
  Duration get position => Duration(milliseconds: positionMs);

  /// Purpose: Return the media duration.
  /// Inputs: None.
  /// Returns: `Duration`.
  /// Side effects: None.
  /// Notes: None.
  Duration get duration => Duration(milliseconds: durationMs);

  /// Purpose: Return how far through the episode this position is.
  /// Inputs: None.
  /// Returns: `double` between 0 and 1.
  /// Side effects: None.
  /// Notes: Clamped, so a position past the recorded end reads as 1.
  double get fraction => (positionMs / durationMs).clamp(0.0, 1.0);

  /// Purpose: Pick the later of two records of the same key.
  /// Inputs: `other` — the remote side.
  /// Returns: `PlaybackProgressEntry` — the one with the later `updatedAt`.
  /// Side effects: None.
  /// Notes: A tie keeps `this`, the local side, as every merge here does.
  PlaybackProgressEntry newerOf(PlaybackProgressEntry other) =>
      other.updatedAt.isAfter(updatedAt) ? other : this;
}

/// The whole of `playback_progress.json`.
class PlaybackProgressData {
  /// The file format version this build writes.
  static const currentVersion = 1;

  /// The version read from disk, kept so a newer file is not relabelled.
  final int version;

  /// Resume points by key.
  final Map<String, PlaybackProgressEntry> entries;

  /// JSON keys this build does not know.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create the store contents.
  /// Inputs: see fields.
  /// Returns: A new `PlaybackProgressData`.
  /// Side effects: None.
  /// Notes: Collections are mutable so the store helpers can edit in place.
  PlaybackProgressData({
    this.version = currentVersion,
    Map<String, PlaybackProgressEntry>? entries,
    Map<String, dynamic>? extraJson,
  }) : entries = entries ?? {},
       extraJson = extraJson ?? {};

  /// Purpose: Read the file tolerantly.
  /// Inputs: `json` — the decoded file.
  /// Returns: `PlaybackProgressData`.
  /// Side effects: None.
  /// Notes: Throws `FormatException` when `json` is not an object, so the
  /// sync module's validation rejects a file that is not ours; inside the
  /// object, malformed entries are dropped.
  factory PlaybackProgressData.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('playback_progress.json is not an object');
    }
    final raw = json['entries'];
    return PlaybackProgressData(
      version: json['version'] is int ? json['version'] as int : currentVersion,
      entries: {
        if (raw is Map)
          for (final e in raw.entries)
            if (e.key is String)
              e.key as String: ?PlaybackProgressEntry.fromJson(
                e.key as String,
                e.value,
              ),
      },
      extraJson: _unknown(json, const {'version', 'entries'}),
    );
  }

  /// Purpose: Serialize the file.
  /// Inputs: None.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: Entries are sorted by key, so unchanged data writes identical
  /// bytes and sync hits its raw-equality fast path.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'version': version,
    'entries': {
      for (final k in entries.keys.toList()..sort()) k: entries[k]!.toJson(),
    },
  };

  /// Purpose: Return the most recently updated entry of one record.
  /// Inputs: `animeId`.
  /// Returns: `PlaybackProgressEntry?` — null when the record has none.
  /// Side effects: None.
  /// Notes: Used to pick the episode to continue.
  PlaybackProgressEntry? latestFor(String animeId) {
    PlaybackProgressEntry? best;
    for (final e in entries.values) {
      if (e.animeId != animeId) continue;
      if (best == null || e.updatedAt.isAfter(best.updatedAt)) best = e;
    }
    return best;
  }
}
