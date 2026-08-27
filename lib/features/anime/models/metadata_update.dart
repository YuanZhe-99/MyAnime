/// Purpose: Model the device-local queue of background metadata work and the
/// update candidates it has already downloaded.
/// Inputs: `Anime` records and `AnimeSearchResult` candidates.
/// Returns: The `MetadataUpdateEntry`/`MetadataUpdateStore` types plus the pure
/// diff and apply helpers the review UI and the background service share.
/// Side effects: None — this file is pure model code.
/// Notes: This data is deliberately **not** synced and **not** backed up. It is
/// per-device bookkeeping (attempt counts, backoff) plus a download cache, and
/// it is rebuilt from the network whenever it is missing. See
/// `doc/en-us/features/metadata-auto-update.md`.
library;

import '../services/anime_search_service.dart';
import 'anime.dart';

/// Known keys of a serialized [MetadataUpdateEntry], for `extraJson`.
const _entryJsonKeys = {
  'animeId',
  'status',
  'candidate',
  'relevance',
  'lastAttemptAt',
  'nextAttemptAt',
  'failureCount',
  'coverCachePath',
};

/// Known keys of a serialized [MetadataUpdateStore], for `extraJson`.
const _storeJsonKeys = {'entries'};

/// When the background metadata pipeline is allowed to use the network.
///
/// Persisted in `storage_config.json` under `metadataAutoUpdate` as the enum
/// name. Absent means the platform default: [noCellular] on Android and iOS,
/// [always] on desktop.
enum MetadataUpdatePolicy {
  /// Never work in the background.
  off,

  /// Work on Wi-Fi and wired connections, but never over a cellular link.
  ///
  /// This is a **link-type heuristic, not a metered-connection guarantee**:
  /// a laptop on a phone's Wi-Fi hotspot reports Wi-Fi while its uplink is
  /// cellular, and a mobile VPN can mask the underlying transport. Android has
  /// a real answer (`NET_CAPABILITY_NOT_METERED`) that `connectivity_plus`
  /// does not expose. The UI wording says "don't use cellular data", which is
  /// exactly what this does, rather than promising more.
  noCellular,

  /// Work on any connection.
  always,
}

/// Purpose: Parse the persisted background-update policy.
/// Inputs: `value` — the raw `storage_config.json` string; `fallback` — the
/// platform default to use when the value is absent or unrecognized.
/// Returns: `MetadataUpdatePolicy`.
/// Side effects: None.
/// Notes: An unknown string falls back rather than throwing, so a config
/// written by a newer build never breaks an older one.
MetadataUpdatePolicy parseMetadataUpdatePolicy(
  String? value,
  MetadataUpdatePolicy fallback,
) {
  for (final policy in MetadataUpdatePolicy.values) {
    if (policy.name == value) return policy;
  }
  return fallback;
}

/// Where an anime stands in the background update pipeline.
enum MetadataUpdateStatus {
  /// A confident candidate is downloaded and waiting for the user to confirm.
  proposed,

  /// Candidates were found but none was confident enough to offer. The user has
  /// to pick one through the normal search dialog. Excluded from batch apply.
  needsManualPick,

  /// The user rejected the candidate. Not offered again until the record
  /// changes.
  dismissed,

  /// Searched, nothing usable came back.
  noMatch,

  /// Nothing to propose — the record is complete, or it only needed its
  /// `externalMeta` cache refreshed, which happens silently.
  upToDate,
}

/// A core [Anime] field the background pipeline is allowed to propose.
///
/// `externalMeta` is deliberately absent: it is a cache of someone else's data
/// and is written straight through without asking. Everything listed here is
/// part of the user's own record, so it always goes through confirmation.
enum MetadataField {
  title,
  titleJa,
  endEpisode,
  firstAirDate,
  airDayOfWeek,
  airTime,
  coverImage,
  infoUrl,
  notes,
}

/// One proposed change to one field, with both sides for display.
class MetadataFieldChange {
  /// Which field would change.
  final MetadataField field;

  /// The record's current value, or `null` when the field is empty.
  final Object? currentValue;

  /// The value the candidate would write.
  final Object? proposedValue;

  /// Purpose: Create a metadata field change instance.
  /// Inputs: `field`, `currentValue`, `proposedValue`.
  /// Returns: A new `MetadataFieldChange` instance.
  /// Side effects: None.
  /// Notes: Held only in memory — the diff is recomputed from the cached
  /// candidate rather than persisted, so it can never go stale against an
  /// anime the user edited in the meantime.
  const MetadataFieldChange({
    required this.field,
    required this.currentValue,
    required this.proposedValue,
  });
}

/// One anime's entry in the local background-update cache.
class MetadataUpdateEntry {
  /// The anime this entry tracks.
  final String animeId;

  /// Where the anime stands in the pipeline.
  final MetadataUpdateStatus status;

  /// The downloaded candidate, when there is one.
  final AnimeSearchResult? candidate;

  /// How well [candidate] matched the anime's title, from
  /// `AnimeSearchService.relevance`.
  final double relevance;

  /// When the pipeline last tried to work on this anime, in UTC.
  final DateTime? lastAttemptAt;

  /// Earliest UTC time the pipeline may try again — the backoff gate.
  final DateTime? nextAttemptAt;

  /// Consecutive failures, driving the backoff schedule.
  final int failureCount;

  /// Relative path of a prefetched cover, when cover prefetch is enabled.
  final String? coverCachePath;

  /// JSON fields this app version does not understand yet.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a metadata update entry instance.
  /// Inputs: `animeId`, `status`, `candidate`, `relevance`, `lastAttemptAt`,
  /// `nextAttemptAt`, `failureCount`, `coverCachePath`, `extraJson`.
  /// Returns: A new `MetadataUpdateEntry` instance.
  /// Side effects: None.
  /// Notes: None.
  const MetadataUpdateEntry({
    required this.animeId,
    this.status = MetadataUpdateStatus.upToDate,
    this.candidate,
    this.relevance = 0,
    this.lastAttemptAt,
    this.nextAttemptAt,
    this.failureCount = 0,
    this.coverCachePath,
    this.extraJson = const {},
  });

  /// Purpose: Report whether this entry is waiting on the user.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Drives the management-page badge count.
  bool get isPending =>
      status == MetadataUpdateStatus.proposed ||
      status == MetadataUpdateStatus.needsManualPick;

  /// Purpose: Report whether the backoff gate currently allows another attempt.
  /// Inputs: `now` — the reference time, in UTC.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: An entry that has never been attempted is always allowed.
  bool isDue(DateTime now) =>
      nextAttemptAt == null || !now.isBefore(nextAttemptAt!);

  /// Purpose: Create a modified copy of this entry.
  /// Inputs: `status`, `candidate`, `relevance`, `lastAttemptAt`,
  /// `nextAttemptAt`, `failureCount`, `coverCachePath`, `extraJson`;
  /// `clearCandidate` and `clearCoverCachePath` remove those values.
  /// Returns: `MetadataUpdateEntry`.
  /// Side effects: None.
  /// Notes: Explicit clear flags exist because `null` means "leave unchanged".
  MetadataUpdateEntry copyWith({
    MetadataUpdateStatus? status,
    AnimeSearchResult? candidate,
    bool clearCandidate = false,
    double? relevance,
    DateTime? lastAttemptAt,
    DateTime? nextAttemptAt,
    bool clearNextAttemptAt = false,
    int? failureCount,
    String? coverCachePath,
    bool clearCoverCachePath = false,
    Map<String, dynamic>? extraJson,
  }) => MetadataUpdateEntry(
    animeId: animeId,
    status: status ?? this.status,
    candidate: clearCandidate ? null : (candidate ?? this.candidate),
    relevance: relevance ?? this.relevance,
    lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    nextAttemptAt: clearNextAttemptAt
        ? null
        : (nextAttemptAt ?? this.nextAttemptAt),
    failureCount: failureCount ?? this.failureCount,
    coverCachePath: clearCoverCachePath
        ? null
        : (coverCachePath ?? this.coverCachePath),
    extraJson: extraJson ?? this.extraJson,
  );

  /// Purpose: Serialize this value into a JSON-compatible map.
  /// Inputs: None.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: Unknown fields are written back first so a newer build's data
  /// survives an older build rewriting the cache.
  Map<String, dynamic> toJson() {
    final json = Map<String, dynamic>.from(extraJson);
    json['animeId'] = animeId;
    json['status'] = status.name;
    json['failureCount'] = failureCount;
    json['relevance'] = relevance;
    if (candidate != null) {
      json['candidate'] = candidate!.toJson();
    } else if (!extraJson.containsKey('candidate')) {
      json.remove('candidate');
    }
    if (lastAttemptAt != null) {
      json['lastAttemptAt'] = lastAttemptAt!.toIso8601String();
    } else if (!extraJson.containsKey('lastAttemptAt')) {
      json.remove('lastAttemptAt');
    }
    if (nextAttemptAt != null) {
      json['nextAttemptAt'] = nextAttemptAt!.toIso8601String();
    } else if (!extraJson.containsKey('nextAttemptAt')) {
      json.remove('nextAttemptAt');
    }
    if (coverCachePath != null) {
      json['coverCachePath'] = coverCachePath;
    } else if (!extraJson.containsKey('coverCachePath')) {
      json.remove('coverCachePath');
    }
    return json;
  }

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: `json`.
  /// Returns: `MetadataUpdateEntry?` — `null` when there is no usable `animeId`.
  /// Side effects: None.
  /// Notes: Values that fail to parse are kept in `extraJson` rather than
  /// dropped, matching `AnimeLocalArchive.fromJson`.
  static MetadataUpdateEntry? fromJson(Map<String, dynamic> json) {
    final rawId = json['animeId'];
    if (rawId is! String || rawId.isEmpty) return null;

    final extraJson = Map<String, dynamic>.from(json)
      ..removeWhere((key, _) => _entryJsonKeys.contains(key));

    var status = MetadataUpdateStatus.upToDate;
    final rawStatus = json['status'];
    MetadataUpdateStatus? parsedStatus;
    for (final value in MetadataUpdateStatus.values) {
      if (value.name == rawStatus) parsedStatus = value;
    }
    if (parsedStatus != null) {
      status = parsedStatus;
    } else if (json.containsKey('status')) {
      extraJson['status'] = rawStatus;
    }

    AnimeSearchResult? candidate;
    final rawCandidate = json['candidate'];
    if (rawCandidate is Map<String, dynamic>) {
      candidate = AnimeSearchResult.fromJson(rawCandidate);
    } else if (json.containsKey('candidate')) {
      extraJson['candidate'] = rawCandidate;
    }

    final rawRelevance = json['relevance'];
    var relevance = 0.0;
    if (rawRelevance is num) {
      relevance = rawRelevance.toDouble();
    } else if (json.containsKey('relevance')) {
      extraJson['relevance'] = rawRelevance;
    }

    final rawFailures = json['failureCount'];
    var failureCount = 0;
    if (rawFailures is int) {
      failureCount = rawFailures;
    } else if (json.containsKey('failureCount')) {
      extraJson['failureCount'] = rawFailures;
    }

    DateTime? utc(String key) {
      final raw = json[key];
      if (raw is String) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed.toUtc();
      }
      if (json.containsKey(key)) extraJson[key] = raw;
      return null;
    }

    final rawCover = json['coverCachePath'];
    String? coverCachePath;
    if (rawCover is String) {
      coverCachePath = rawCover;
    } else if (json.containsKey('coverCachePath')) {
      extraJson['coverCachePath'] = rawCover;
    }

    return MetadataUpdateEntry(
      animeId: rawId,
      status: status,
      candidate: candidate,
      relevance: relevance,
      lastAttemptAt: utc('lastAttemptAt'),
      nextAttemptAt: utc('nextAttemptAt'),
      failureCount: failureCount,
      coverCachePath: coverCachePath,
      extraJson: extraJson,
    );
  }
}

/// The whole `metadata_updates.json` document.
class MetadataUpdateStore {
  /// Every tracked anime, in no particular order.
  final List<MetadataUpdateEntry> entries;

  /// JSON fields this app version does not understand yet.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a metadata update store instance.
  /// Inputs: `entries`, `extraJson`.
  /// Returns: A new `MetadataUpdateStore` instance.
  /// Side effects: None.
  /// Notes: None.
  const MetadataUpdateStore({
    this.entries = const [],
    this.extraJson = const {},
  });

  /// Purpose: Look up one anime's entry.
  /// Inputs: `animeId`.
  /// Returns: `MetadataUpdateEntry?`.
  /// Side effects: None.
  /// Notes: None.
  MetadataUpdateEntry? entryFor(String animeId) {
    for (final entry in entries) {
      if (entry.animeId == animeId) return entry;
    }
    return null;
  }

  /// Purpose: Replace or insert one entry, returning a new store.
  /// Inputs: `entry`.
  /// Returns: `MetadataUpdateStore`.
  /// Side effects: None.
  /// Notes: None.
  MetadataUpdateStore withEntry(MetadataUpdateEntry entry) {
    final next = entries.where((e) => e.animeId != entry.animeId).toList()
      ..add(entry);
    return MetadataUpdateStore(entries: next, extraJson: extraJson);
  }

  /// Purpose: Drop entries whose anime no longer exists.
  /// Inputs: `liveIds` — every id currently in `anime_data.json`.
  /// Returns: `MetadataUpdateStore`.
  /// Side effects: None.
  /// Notes: Keeps the cache from growing without bound as anime are deleted.
  MetadataUpdateStore prunedTo(Set<String> liveIds) => MetadataUpdateStore(
    entries: entries.where((e) => liveIds.contains(e.animeId)).toList(),
    extraJson: extraJson,
  );

  /// Purpose: Serialize this value into a JSON-compatible map.
  /// Inputs: None.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: None.
  Map<String, dynamic> toJson() {
    final json = Map<String, dynamic>.from(extraJson);
    json['entries'] = [for (final entry in entries) entry.toJson()];
    return json;
  }

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: `json`.
  /// Returns: A new `MetadataUpdateStore`.
  /// Side effects: None.
  /// Notes: Malformed entries are skipped individually rather than failing the
  /// whole file — this is a rebuildable cache, so partial recovery beats
  /// throwing away everything.
  factory MetadataUpdateStore.fromJson(Map<String, dynamic> json) {
    final extraJson = Map<String, dynamic>.from(json)
      ..removeWhere((key, _) => _storeJsonKeys.contains(key));

    final entries = <MetadataUpdateEntry>[];
    final rawEntries = json['entries'];
    if (rawEntries is List) {
      for (final raw in rawEntries) {
        if (raw is! Map<String, dynamic>) continue;
        final entry = MetadataUpdateEntry.fromJson(raw);
        if (entry != null) entries.add(entry);
      }
    } else if (json.containsKey('entries')) {
      extraJson['entries'] = rawEntries;
    }

    return MetadataUpdateStore(entries: entries, extraJson: extraJson);
  }
}

// ─── Pure diff / apply helpers ──────────────────────────────────────

/// Purpose: Report whether an anime's episode count disagrees with a source.
/// Inputs: `anime`, `candidate`.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Only meaningful when `startEpisode == 1`. A split-cour entry tracked
/// as episodes 13–24 has `totalEpisodes == 12` while the source reports 24, and
/// that is the **correct** way to record it — without this guard the feature
/// would raise false alarms on exactly the records a user curated most
/// carefully. An open-ended record (`endEpisode == null`) is handled as a
/// missing field instead, not a mismatch.
bool hasEpisodeCountMismatch(Anime anime, AnimeSearchResult candidate) {
  final sourceEpisodes = candidate.episodes;
  if (sourceEpisodes == null || sourceEpisodes <= 0) return false;
  if (anime.startEpisode != 1) return false;
  final total = anime.totalEpisodes;
  if (total == null) return false;
  return total != sourceEpisodes;
}

/// Purpose: Report whether an anime is missing enough data to be worth a search.
/// Inputs: `anime`.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Drives which records the discovery queue picks up. A record with no
/// source URL and no cached metadata always qualifies, because nothing can be
/// refreshed from it.
bool needsMetadataDiscovery(Anime anime) {
  final hasSource =
      (anime.infoUrl != null && anime.infoUrl!.isNotEmpty) ||
      anime.externalMeta != null;
  if (!hasSource) return true;
  return anime.firstAirDate == null ||
      anime.airDayOfWeek == null ||
      anime.endEpisode == null ||
      anime.coverImage == null;
}

/// Purpose: Work out which core fields a candidate would change.
/// Inputs: `anime`, `candidate`.
/// Returns: `List<MetadataFieldChange>` — empty when nothing would change.
/// Side effects: None.
/// Notes: **Never proposes overwriting a non-empty user value**, with one
/// deliberate exception: `endEpisode` when [hasEpisodeCountMismatch] says the
/// counts genuinely disagree. That rule is what makes "update all" defensible —
/// a batch apply can only fill blanks and correct a demonstrable mismatch.
/// Recomputed on demand rather than persisted, so it always reflects the
/// anime's current state.
List<MetadataFieldChange> diffCandidate(
  Anime anime,
  AnimeSearchResult candidate,
) {
  final changes = <MetadataFieldChange>[];

  void propose(MetadataField field, Object? current, Object? proposed) {
    if (proposed == null) return;
    if (proposed is String && proposed.trim().isEmpty) return;
    changes.add(
      MetadataFieldChange(
        field: field,
        currentValue: current,
        proposedValue: proposed,
      ),
    );
  }

  bool blank(String? value) => value == null || value.trim().isEmpty;

  if (blank(anime.title)) {
    propose(MetadataField.title, anime.title, candidate.title);
  }
  if (blank(anime.titleJa)) {
    propose(MetadataField.titleJa, anime.titleJa, candidate.titleJa);
  }
  if (anime.endEpisode == null) {
    propose(MetadataField.endEpisode, null, candidate.episodes);
  } else if (hasEpisodeCountMismatch(anime, candidate)) {
    propose(
      MetadataField.endEpisode,
      anime.endEpisode,
      // startEpisode is 1 here, so the source count is the end episode.
      candidate.episodes,
    );
  }
  if (anime.firstAirDate == null) {
    propose(MetadataField.firstAirDate, null, candidate.firstAirDate);
  }
  if (anime.airDayOfWeek == null) {
    propose(MetadataField.airDayOfWeek, null, candidate.airDayOfWeek);
  }
  if (blank(anime.airTime)) {
    propose(MetadataField.airTime, anime.airTime, candidate.airTime);
  }
  if (anime.coverImage == null) {
    propose(MetadataField.coverImage, null, candidate.coverImageUrl);
  }
  if (blank(anime.infoUrl)) {
    propose(MetadataField.infoUrl, anime.infoUrl, candidate.sourceUrl);
  }
  if (blank(anime.notes)) {
    propose(MetadataField.notes, anime.notes, candidate.summary);
  }

  return changes;
}

/// Purpose: Apply the selected proposed fields onto an anime record.
/// Inputs: `anime`, `changes`, `selected` — the fields the user accepted;
/// `coverImagePath` — the already-downloaded relative cover path, when the
/// cover field was accepted.
/// Returns: `Anime` with the accepted fields written.
/// Side effects: None — the caller persists the result and downloads the cover.
/// Notes: Leaves `modifiedAt` exactly as it was, so the caller decides. That
/// takes an explicit pass-through, because `Anime.copyWith` defaults
/// `modifiedAt` to now whenever it is omitted. Applying a proposal *is* a user
/// edit and the caller does bump it — the opposite of the background
/// `externalMeta` refresh, which must never bump it.
Anime applyMetadataChanges(
  Anime anime, {
  required List<MetadataFieldChange> changes,
  required Set<MetadataField> selected,
  String? coverImagePath,
}) {
  var result = anime;
  for (final change in changes) {
    if (!selected.contains(change.field)) continue;
    final value = change.proposedValue;
    switch (change.field) {
      case MetadataField.title:
        result = result.copyWith(title: value as String);
      case MetadataField.titleJa:
        result = result.copyWith(titleJa: value as String);
      case MetadataField.endEpisode:
        result = result.copyWith(endEpisode: value as int);
      case MetadataField.firstAirDate:
        result = result.copyWith(firstAirDate: value as DateTime);
      case MetadataField.airDayOfWeek:
        result = result.copyWith(airDayOfWeek: value as int);
      case MetadataField.airTime:
        result = result.copyWith(airTime: value as String);
      case MetadataField.infoUrl:
        result = result.copyWith(infoUrl: value as String);
      case MetadataField.notes:
        result = result.copyWith(notes: value as String);
      case MetadataField.coverImage:
        // The proposed value is a remote URL; the caller downloads it first and
        // passes the resulting relative path back in.
        if (coverImagePath != null) {
          result = result.copyWith(coverImage: coverImagePath);
        }
    }
  }
  // Every `copyWith` above stamped `modifiedAt` with the current time. Restore
  // it so the caller alone decides whether this counts as a user edit.
  return result.copyWith(modifiedAt: anime.modifiedAt);
}
