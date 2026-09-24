import 'package:uuid/uuid.dart';

const _animeJsonKeys = {
  'id',
  'title',
  'titleJa',
  'season',
  'startEpisode',
  'endEpisode',
  'manualType',
  'airDayOfWeek',
  'airTime',
  'firstAirDate',
  'episodeStatuses',
  'coverImage',
  'infoUrl',
  'watchUrl',
  'episodeWeekOffsets',
  'notes',
  'rating',
  'localArchive',
  'seriesLink',
  'externalMeta',
  'createdAt',
  'modifiedAt',
};

const _ratingJsonKeys = {
  'overall',
  'visual',
  'story',
  'character',
  'music',
  'enjoyment',
};

const _localArchiveJsonKeys = {
  'archived',
  'source',
  'resolution',
  'copies',
  'location',
};

const _seriesLinkJsonKeys = {'seriesId', 'order', 'standalone'};

const _externalMetaJsonKeys = {
  'synonyms',
  'titleRomaji',
  'titleEn',
  'format',
  'status',
  'durationMinutes',
  'genres',
  'studios',
  'endDate',
  'ratings',
  'refreshedAt',
  'watchProgress',
};

const _watchProgressJsonKeys = {
  'sourceUrl',
  'catId',
  'latestEpisode',
  'episodesText',
  'ongoing',
  'checkedAt',
};

const _externalRatingJsonKeys = {
  'source',
  'sourceUrl',
  'score',
  'scoreMax',
  'votes',
  'rank',
  'fetchedAt',
};

const _animeDataJsonKeys = {'animes'};

/// Purpose: Provide the internal unknown json helper for this file.
/// Inputs: `json`, `knownKeys`.
/// Returns: `Map<String, dynamic>`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
Map<String, dynamic> _unknownJson(
  Map<String, dynamic> json,
  Set<String> knownKeys,
) {
  final extra = Map<String, dynamic>.from(json);
  extra.removeWhere((key, _) => knownKeys.contains(key));
  return extra;
}

/// Purpose: Provide the internal string keyed map helper for this file.
/// Inputs: `map`.
/// Returns: `Map<String, dynamic>`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
Map<String, dynamic> _stringKeyedMap(Map<dynamic, dynamic> map) => {
  for (final entry in map.entries) entry.key.toString(): entry.value,
};

/// Purpose: Provide the internal merge json maps helper for this file.
/// Inputs: `maps`.
/// Returns: `Map<String, dynamic>`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
Map<String, dynamic> _mergeJsonMaps(Iterable<Map<String, dynamic>> maps) {
  final merged = <String, dynamic>{};
  for (final map in maps) {
    for (final entry in map.entries) {
      final existing = merged[entry.key];
      final value = entry.value;
      if (existing is Map && value is Map) {
        merged[entry.key] = _mergeJsonMaps([
          _stringKeyedMap(existing),
          _stringKeyedMap(value),
        ]);
      } else {
        merged[entry.key] = value;
      }
    }
  }
  return merged;
}

/// Purpose: Provide the internal parse anime type helper for this file.
/// Inputs: `value`.
/// Returns: `AnimeType?`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
AnimeType? _parseAnimeType(Object? value) {
  if (value is! String) return null;
  for (final type in AnimeType.values) {
    if (type.name == value) return type;
  }
  return null;
}

/// Purpose: Provide the internal parse archive source helper for this file.
/// Inputs: `value`.
/// Returns: `ArchiveSource?`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
ArchiveSource? _parseArchiveSource(Object? value) {
  if (value is! String) return null;
  for (final source in ArchiveSource.values) {
    if (source.name == value) return source;
  }
  return null;
}

/// Purpose: Provide the internal parse archive resolution helper for this file.
/// Inputs: `value`.
/// Returns: `ArchiveResolution?`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
ArchiveResolution? _parseArchiveResolution(Object? value) {
  if (value is! String) return null;
  for (final resolution in ArchiveResolution.values) {
    if (resolution.name == value) return resolution;
  }
  return null;
}

/// Purpose: Provide the internal parse episode status helper for this file.
/// Inputs: `value`.
/// Returns: `EpisodeStatus?`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
EpisodeStatus? _parseEpisodeStatus(Object? value) {
  if (value is! String) return null;
  for (final status in EpisodeStatus.values) {
    if (status.name == value) return status;
  }
  return null;
}

/// Purpose: Provide the internal parse string list helper for this file.
/// Inputs: `value`.
/// Returns: `List<String>?`.
/// Side effects: None.
/// Notes: Internal helper used within this file only. Returns `null` when the
/// value is not a list of strings, so the caller can preserve it verbatim in
/// `extraJson` instead of dropping it.
List<String>? _parseStringList(Object? value) {
  if (value is! List) return null;
  final result = <String>[];
  for (final entry in value) {
    if (entry is! String) return null;
    result.add(entry);
  }
  return result;
}

/// Purpose: Provide the internal parse UTC timestamp helper for this file.
/// Inputs: `value`.
/// Returns: `DateTime?`.
/// Side effects: None.
/// Notes: Internal helper used within this file only. Normalizes to UTC so
/// values compared across devices stay timezone-stable. Use this only for real
/// instants (`fetchedAt`, `refreshedAt`) — never for calendar dates, which
/// `_parseCalendarDate` handles instead.
DateTime? _parseUtcDateTime(Object? value) {
  if (value is! String) return null;
  final parsed = DateTime.tryParse(value);
  return parsed?.toUtc();
}

/// Purpose: Provide the internal parse calendar-date helper for this file.
/// Inputs: `value`.
/// Returns: `DateTime?`.
/// Side effects: None.
/// Notes: Internal helper used within this file only. Deliberately does **not**
/// normalize to UTC. A broadcast date is a calendar day, not an instant: it is
/// written as local midnight, so converting it to UTC on read shifts it behind
/// midnight for every timezone east of UTC and `DateFormat.yMd()` then renders
/// the previous day. Japan is UTC+9, so that off-by-one would hit this app's
/// core audience. `Anime.firstAirDate` has always parsed this way; `endDate`
/// matches it.
DateTime? _parseCalendarDate(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value);
}

/// Anime broadcast type based on episode count.
enum AnimeType {
  /// ≤13 episodes, single cour
  singleCour,

  /// 14–26 episodes, half year
  halfYear,

  /// 27–52 episodes, full year
  fullYear,

  /// No end episode set, ongoing
  longRunning,

  /// All episodes released at once (Netflix style)
  allAtOnce,
}

/// Per-episode watch status.
enum EpisodeStatus { unwatched, watched, skippedThisWeek }

/// Derived viewing status for an anime.
enum AnimeViewingStatus { completed, watching, dropped, notStarted }

/// Rating fields available for sorting and display.
enum AnimeRatingField { overall, visual, story, character, music, enjoyment }

/// Source medium a locally archived copy was obtained from.
enum ArchiveSource {
  /// Ripped from a Blu-ray release.
  bd,

  /// Ripped from a DVD release.
  dvd,

  /// Downloaded from a streaming/web release.
  web,

  /// Recorded from a broadcast.
  tv,

  /// Anything the other values do not cover.
  other,
}

/// Video resolution of a locally archived copy.
enum ArchiveResolution {
  /// 3840×2160 (4K UHD).
  uhd2160p,

  /// 1920×1080 (Full HD).
  fhd1080p,

  /// 1280×720 (HD).
  hd720p,

  /// 854×480 or lower (SD).
  sd480p,

  /// Anything the other values do not cover.
  other,
}

class AnimeRating {
  /// Manual overall score. When null, [effectiveOverall] is averaged from
  /// sub-scores.
  final double? overall;
  final double? visual;
  final double? story;
  final double? character;
  final double? music;
  final double? enjoyment;

  /// JSON fields this app version does not understand yet.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a anime rating instance.
  /// Inputs: `overall`, `visual`, `story`, `character`, `music`, `enjoyment`, `extraJson`.
  /// Returns: A new `AnimeRating` instance.
  /// Side effects: None.
  /// Notes: None.
  const AnimeRating({
    this.overall,
    this.visual,
    this.story,
    this.character,
    this.music,
    this.enjoyment,
    this.extraJson = const {},
  });

  /// Purpose: Return the current manual overall value.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get hasManualOverall => overall != null;

  /// Purpose: Return the current any score value.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get hasAnyScore =>
      overall != null ||
      visual != null ||
      story != null ||
      character != null ||
      music != null ||
      enjoyment != null;

  /// Purpose: Return the current any data value.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get hasAnyData => hasAnyScore || extraJson.isNotEmpty;

  /// Purpose: Implement the effective overall behavior for this file.
  /// Inputs: None.
  /// Returns: `double?`.
  /// Side effects: None.
  /// Notes: None.
  double? get effectiveOverall {
    if (overall != null) return overall;
    final scores = [
      visual,
      story,
      character,
      music,
      enjoyment,
    ].whereType<double>().toList();
    if (scores.isEmpty) return null;
    final sum = scores.fold<double>(0, (total, score) => total + score);
    return sum / scores.length;
  }

  /// Purpose: Implement the score for behavior for this file.
  /// Inputs: `field`.
  /// Returns: `double?`.
  /// Side effects: None.
  /// Notes: None.
  double? scoreFor(AnimeRatingField field) {
    switch (field) {
      case AnimeRatingField.overall:
        return effectiveOverall;
      case AnimeRatingField.visual:
        return visual;
      case AnimeRatingField.story:
        return story;
      case AnimeRatingField.character:
        return character;
      case AnimeRatingField.music:
        return music;
      case AnimeRatingField.enjoyment:
        return enjoyment;
    }
  }

  /// Purpose: Create a copy with extra json.
  /// Inputs: `extraJson`.
  /// Returns: `AnimeRating`.
  /// Side effects: None.
  /// Notes: None.
  AnimeRating withExtraJson(Map<String, dynamic> extraJson) => AnimeRating(
    overall: overall,
    visual: visual,
    story: story,
    character: character,
    music: music,
    enjoyment: enjoyment,
    extraJson: extraJson,
  );

  /// Purpose: Serialize this value into a JSON-compatible map.
  /// Inputs: None.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: None.
  Map<String, dynamic> toJson() {
    final json = Map<String, dynamic>.from(extraJson);
    _writeScore(json, 'overall', overall);
    _writeScore(json, 'visual', visual);
    _writeScore(json, 'story', story);
    _writeScore(json, 'character', character);
    _writeScore(json, 'music', music);
    _writeScore(json, 'enjoyment', enjoyment);
    return json;
  }

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: `json`.
  /// Returns: A new `AnimeRating.fromJson` instance.
  /// Side effects: None.
  /// Notes: None.
  factory AnimeRating.fromJson(Map<String, dynamic> json) {
    final extraJson = _unknownJson(json, _ratingJsonKeys);

    double? readScore(String key) {
      final score = _parseScore(json[key]);
      if (json.containsKey(key) && score == null) {
        extraJson[key] = json[key];
      }
      return score;
    }

    return AnimeRating(
      overall: readScore('overall'),
      visual: readScore('visual'),
      story: readScore('story'),
      character: readScore('character'),
      music: readScore('music'),
      enjoyment: readScore('enjoyment'),
      extraJson: extraJson,
    );
  }
}

/// Purpose: Provide the internal parse score helper for this file.
/// Inputs: `value`.
/// Returns: `double?`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
double? _parseScore(Object? value) {
  if (value is num) return value.toDouble();
  return null;
}

/// Purpose: Provide the internal write score helper for this file.
/// Inputs: `json`, `key`, `score`.
/// Returns: None.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
void _writeScore(Map<String, dynamic> json, String key, double? score) {
  if (score != null) {
    json[key] = score;
  } else if (!json.containsKey(key)) {
    json.remove(key);
  }
}

/// Optional record of a downloaded local copy of an anime.
///
/// Everything here is personal infrastructure information: it is persisted and
/// WebDAV-synced across the user's own devices, but never drawn into shared
/// image cards and stripped from `.myanimeitem` share files.
class AnimeLocalArchive {
  /// Whether a local copy of this anime is kept.
  final bool archived;

  /// Medium the local copy came from.
  final ArchiveSource? source;

  /// Video resolution of the local copy.
  final ArchiveResolution? resolution;

  /// Number of archived copies kept.
  final int? copies;

  /// Repository code or physical location holding the copies. Free text, so
  /// several codes can be listed together (e.g. `NAS-01, HDD-C3`).
  final String? location;

  /// JSON fields this app version does not understand yet.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a anime local archive instance.
  /// Inputs: `archived`, `source`, `resolution`, `copies`, `location`, `extraJson`.
  /// Returns: A new `AnimeLocalArchive` instance.
  /// Side effects: None.
  /// Notes: None.
  const AnimeLocalArchive({
    this.archived = false,
    this.source,
    this.resolution,
    this.copies,
    this.location,
    this.extraJson = const {},
  });

  /// Purpose: Report whether any archive detail beyond the flag was filled in.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get hasAnyDetail =>
      source != null ||
      resolution != null ||
      copies != null ||
      (location != null && location!.isNotEmpty);

  /// Purpose: Report whether this record carries anything worth persisting.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: When false the owning `Anime` drops the record entirely, so an
  /// untouched anime never gains a `localArchive` key.
  bool get hasAnyData => archived || hasAnyDetail || extraJson.isNotEmpty;

  /// Purpose: Create a copy with extra json.
  /// Inputs: `extraJson`.
  /// Returns: `AnimeLocalArchive`.
  /// Side effects: None.
  /// Notes: None.
  AnimeLocalArchive withExtraJson(Map<String, dynamic> extraJson) =>
      AnimeLocalArchive(
        archived: archived,
        source: source,
        resolution: resolution,
        copies: copies,
        location: location,
        extraJson: extraJson,
      );

  /// Purpose: Serialize this value into a JSON-compatible map.
  /// Inputs: None.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: None.
  Map<String, dynamic> toJson() {
    final json = Map<String, dynamic>.from(extraJson);
    // A raw `archived` that failed to parse is preserved verbatim in extraJson;
    // only write the parsed flag when there is nothing to preserve.
    if (!extraJson.containsKey('archived')) {
      json['archived'] = archived;
    }
    if (source != null) {
      json['source'] = source!.name;
    } else if (!extraJson.containsKey('source')) {
      json.remove('source');
    }
    if (resolution != null) {
      json['resolution'] = resolution!.name;
    } else if (!extraJson.containsKey('resolution')) {
      json.remove('resolution');
    }
    if (copies != null) {
      json['copies'] = copies;
    } else if (!extraJson.containsKey('copies')) {
      json.remove('copies');
    }
    if (location != null) {
      json['location'] = location;
    } else if (!extraJson.containsKey('location')) {
      json.remove('location');
    }
    return json;
  }

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: `json`.
  /// Returns: A new `AnimeLocalArchive.fromJson` instance.
  /// Side effects: None.
  /// Notes: Values that fail to parse are kept in `extraJson` rather than
  /// dropped, so a newer build's data survives an older build's edits.
  factory AnimeLocalArchive.fromJson(Map<String, dynamic> json) {
    final extraJson = _unknownJson(json, _localArchiveJsonKeys);

    final rawArchived = json['archived'];
    var archived = false;
    if (rawArchived is bool) {
      archived = rawArchived;
    } else if (json.containsKey('archived')) {
      extraJson['archived'] = rawArchived;
    }

    final source = _parseArchiveSource(json['source']);
    if (json.containsKey('source') && source == null) {
      extraJson['source'] = json['source'];
    }

    final resolution = _parseArchiveResolution(json['resolution']);
    if (json.containsKey('resolution') && resolution == null) {
      extraJson['resolution'] = json['resolution'];
    }

    final rawCopies = json['copies'];
    int? copies;
    if (rawCopies is int) {
      copies = rawCopies;
    } else if (json.containsKey('copies')) {
      extraJson['copies'] = rawCopies;
    }

    final rawLocation = json['location'];
    String? location;
    if (rawLocation is String) {
      location = rawLocation;
    } else if (json.containsKey('location')) {
      extraJson['location'] = rawLocation;
    }

    return AnimeLocalArchive(
      archived: archived,
      source: source,
      resolution: resolution,
      copies: copies,
      location: location,
      extraJson: extraJson,
    );
  }
}

/// Optional record of the series a user placed an anime in.
///
/// Membership is a shared group id rather than prev/next pointers, so no
/// record ever references another record's `id`: deleting, merging or
/// importing a record cannot leave a dangling link. Synced and backed up, but
/// stripped from `.myanimeitem` share files and dropped on import, because a
/// foreign `seriesId` means nothing in another library.
class AnimeSeriesLink {
  /// Lowercase UUID shared by every member of one curated series.
  final String? seriesId;

  /// Position within the series after the user reordered it (1-based).
  final int? order;

  /// Whether the user took this record out of every series.
  final bool standalone;

  /// JSON fields this app version does not understand yet.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create an anime series link instance.
  /// Inputs: `seriesId`, `order`, `standalone`, `extraJson`.
  /// Returns: A new `AnimeSeriesLink` instance.
  /// Side effects: None.
  /// Notes: None.
  const AnimeSeriesLink({
    this.seriesId,
    this.order,
    this.standalone = false,
    this.extraJson = const {},
  });

  /// Purpose: Return the curated series this record belongs to, if any.
  /// Inputs: None.
  /// Returns: `String?` — `null` for standalone records and records without
  /// a `seriesId`.
  /// Side effects: None.
  /// Notes: When a hand-edited file carries both `standalone` and `seriesId`,
  /// `standalone` wins; the id is still written back untouched.
  String? get curatedSeriesId => standalone ? null : seriesId;

  /// Purpose: Report whether this link carries anything worth persisting.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: When false the owning `Anime` omits the `seriesLink` key.
  bool get hasAnyData =>
      standalone || seriesId != null || order != null || extraJson.isNotEmpty;

  /// Purpose: Create a copy with extra json.
  /// Inputs: `extraJson`.
  /// Returns: `AnimeSeriesLink`.
  /// Side effects: None.
  /// Notes: None.
  AnimeSeriesLink withExtraJson(Map<String, dynamic> extraJson) =>
      AnimeSeriesLink(
        seriesId: seriesId,
        order: order,
        standalone: standalone,
        extraJson: extraJson,
      );

  /// Purpose: Serialize this value into a JSON-compatible map.
  /// Inputs: None.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: `standalone` is written only when true.
  Map<String, dynamic> toJson() {
    final json = Map<String, dynamic>.from(extraJson);
    if (seriesId != null) {
      json['seriesId'] = seriesId;
    } else if (!extraJson.containsKey('seriesId')) {
      json.remove('seriesId');
    }
    if (order != null) {
      json['order'] = order;
    } else if (!extraJson.containsKey('order')) {
      json.remove('order');
    }
    if (standalone) {
      json['standalone'] = true;
    } else if (!extraJson.containsKey('standalone')) {
      json.remove('standalone');
    }
    return json;
  }

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: `json`.
  /// Returns: A new `AnimeSeriesLink.fromJson` instance.
  /// Side effects: None.
  /// Notes: Unparseable values — a non-string or empty `seriesId`, an `order`
  /// that is not a positive integer, a non-bool `standalone` — are preserved
  /// verbatim in `extraJson` and treated as absent.
  factory AnimeSeriesLink.fromJson(Map<String, dynamic> json) {
    final extraJson = _unknownJson(json, _seriesLinkJsonKeys);

    final rawSeriesId = json['seriesId'];
    String? seriesId;
    if (rawSeriesId is String && rawSeriesId.trim().isNotEmpty) {
      seriesId = rawSeriesId;
    } else if (json.containsKey('seriesId')) {
      extraJson['seriesId'] = rawSeriesId;
    }

    final rawOrder = json['order'];
    int? order;
    if (rawOrder is int && rawOrder > 0) {
      order = rawOrder;
    } else if (json.containsKey('order')) {
      extraJson['order'] = rawOrder;
    }

    final rawStandalone = json['standalone'];
    var standalone = false;
    if (rawStandalone is bool) {
      standalone = rawStandalone;
    } else if (json.containsKey('standalone')) {
      extraJson['standalone'] = rawStandalone;
    }

    return AnimeSeriesLink(
      seriesId: seriesId,
      order: order,
      standalone: standalone,
      extraJson: extraJson,
    );
  }
}

/// One external database's rating for an anime.
///
/// Deliberately separate from [AnimeRating]: that type holds the user's own
/// scores and is never overwritten by a fetch. Each entry remembers the page
/// [sourceUrl] it came from so the record can be refreshed later.
class AnimeExternalRating {
  /// Display name of the originating source, e.g. `AniList`.
  final String source;

  /// Canonical page URL this rating was read from; the refresh key.
  final String? sourceUrl;

  /// Score normalized onto [scoreMax].
  final double? score;

  /// Upper bound of [score]. Sources are normalized to a 10-point scale.
  final double scoreMax;

  /// Number of votes behind [score], when the source reports it.
  final int? votes;

  /// The source's popularity/score rank, when reported.
  final int? rank;

  /// When this rating was last fetched (UTC).
  final DateTime? fetchedAt;

  /// JSON fields this app version does not understand yet.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create an external rating instance.
  /// Inputs: `source`, `sourceUrl`, `score`, `scoreMax`, `votes`, `rank`, `fetchedAt`, `extraJson`.
  /// Returns: A new `AnimeExternalRating` instance.
  /// Side effects: None.
  /// Notes: `scoreMax` defaults to 10 because every supported source is
  /// normalized onto a 10-point scale before being stored.
  const AnimeExternalRating({
    required this.source,
    this.sourceUrl,
    this.score,
    this.scoreMax = 10,
    this.votes,
    this.rank,
    this.fetchedAt,
    this.extraJson = const {},
  });

  /// Purpose: Report whether this rating carries anything worth persisting.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: A bare source name with no numbers is dropped by the owning meta.
  bool get hasAnyData =>
      score != null || votes != null || rank != null || extraJson.isNotEmpty;

  /// Purpose: Return this source's score rebased onto a 0-10 scale.
  /// Inputs: None.
  /// Returns: `double?`.
  /// Side effects: None.
  /// Notes: Every supported source is already normalized onto [scoreMax], which
  /// defaults to 10, but `scoreMax` is stored per entry — so anything comparing
  /// scores across sources must divide through rather than read [score] raw.
  /// Returns `null` when there is no score, or when `scoreMax` is unusable.
  double? get normalizedScore {
    final value = score;
    if (value == null || scoreMax <= 0) return null;
    return value / scoreMax * 10;
  }

  /// Purpose: Create a copy with extra json.
  /// Inputs: `extraJson`.
  /// Returns: `AnimeExternalRating`.
  /// Side effects: None.
  /// Notes: None.
  AnimeExternalRating withExtraJson(Map<String, dynamic> extraJson) =>
      AnimeExternalRating(
        source: source,
        sourceUrl: sourceUrl,
        score: score,
        scoreMax: scoreMax,
        votes: votes,
        rank: rank,
        fetchedAt: fetchedAt,
        extraJson: extraJson,
      );

  /// Purpose: Serialize this value into a JSON-compatible map.
  /// Inputs: None.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: None.
  Map<String, dynamic> toJson() {
    final json = Map<String, dynamic>.from(extraJson);
    json['source'] = source;
    if (sourceUrl != null) {
      json['sourceUrl'] = sourceUrl;
    } else if (!extraJson.containsKey('sourceUrl')) {
      json.remove('sourceUrl');
    }
    if (score != null) {
      json['score'] = score;
    } else if (!extraJson.containsKey('score')) {
      json.remove('score');
    }
    json['scoreMax'] = scoreMax;
    if (votes != null) {
      json['votes'] = votes;
    } else if (!extraJson.containsKey('votes')) {
      json.remove('votes');
    }
    if (rank != null) {
      json['rank'] = rank;
    } else if (!extraJson.containsKey('rank')) {
      json.remove('rank');
    }
    if (fetchedAt != null) {
      json['fetchedAt'] = fetchedAt!.toUtc().toIso8601String();
    } else if (!extraJson.containsKey('fetchedAt')) {
      json.remove('fetchedAt');
    }
    return json;
  }

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: `json`.
  /// Returns: A new `AnimeExternalRating.fromJson` instance.
  /// Side effects: None.
  /// Notes: Values that fail to parse are kept in `extraJson` rather than
  /// dropped, so a newer build's data survives an older build's edits.
  factory AnimeExternalRating.fromJson(Map<String, dynamic> json) {
    final extraJson = _unknownJson(json, _externalRatingJsonKeys);

    final rawSource = json['source'];
    var source = '';
    if (rawSource is String) {
      source = rawSource;
    } else if (json.containsKey('source')) {
      extraJson['source'] = rawSource;
    }

    final rawSourceUrl = json['sourceUrl'];
    String? sourceUrl;
    if (rawSourceUrl is String) {
      sourceUrl = rawSourceUrl;
    } else if (json.containsKey('sourceUrl')) {
      extraJson['sourceUrl'] = rawSourceUrl;
    }

    final score = _parseScore(json['score']);
    if (json.containsKey('score') && score == null) {
      extraJson['score'] = json['score'];
    }

    final rawScoreMax = _parseScore(json['scoreMax']);
    if (json.containsKey('scoreMax') && rawScoreMax == null) {
      extraJson['scoreMax'] = json['scoreMax'];
    }

    final rawVotes = json['votes'];
    int? votes;
    if (rawVotes is int) {
      votes = rawVotes;
    } else if (json.containsKey('votes')) {
      extraJson['votes'] = rawVotes;
    }

    final rawRank = json['rank'];
    int? rank;
    if (rawRank is int) {
      rank = rawRank;
    } else if (json.containsKey('rank')) {
      extraJson['rank'] = rawRank;
    }

    final fetchedAt = _parseUtcDateTime(json['fetchedAt']);
    if (json.containsKey('fetchedAt') && fetchedAt == null) {
      extraJson['fetchedAt'] = json['fetchedAt'];
    }

    return AnimeExternalRating(
      source: source,
      sourceUrl: sourceUrl,
      score: score,
      scoreMax: rawScoreMax ?? 10,
      votes: votes,
      rank: rank,
      fetchedAt: fetchedAt,
      extraJson: extraJson,
    );
  }
}

/// Public metadata pulled from external anime databases.
///
/// Everything here is publicly available information about the work itself, not
/// the user's personal tracking data, so it travels with `.myanimeitem` share
/// files rather than being stripped like [AnimeLocalArchive].
/// What the watch site (anime1.me) listed for an anime's `watchUrl` when it
/// was last checked — the newest available episode, and whether the run is
/// still updating.
///
/// This is a cached copy of public site data, like the rest of
/// `AnimeExternalMeta`: it is written through `AnimeStorage.patchExternalMeta`
/// and never bumps `modifiedAt`. `sourceUrl` remembers which `watchUrl` it was
/// read for, so an edited URL invalidates it (see `Anime.validWatchProgress`).
class AnimeWatchProgress {
  /// The `watchUrl` this record was fetched for.
  final String sourceUrl;

  /// anime1.me category id, when known.
  final int? catId;

  /// Newest episode the site lists; `null` for films and specials.
  final int? latestEpisode;

  /// The site's episode cell verbatim, e.g. `連載中(09)` or `1-12+OVA`.
  final String? episodesText;

  /// Whether the site marks the series as still updating.
  final bool ongoing;

  /// When the site was last read (UTC).
  final DateTime? checkedAt;

  /// JSON fields this app version does not understand yet.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a watch progress instance.
  /// Inputs: `sourceUrl`, `catId`, `latestEpisode`, `episodesText`, `ongoing`, `checkedAt`, `extraJson`.
  /// Returns: A new `AnimeWatchProgress` instance.
  /// Side effects: None.
  /// Notes: None.
  const AnimeWatchProgress({
    required this.sourceUrl,
    this.catId,
    this.latestEpisode,
    this.episodesText,
    this.ongoing = false,
    this.checkedAt,
    this.extraJson = const {},
  });

  /// Purpose: Report whether this record carries anything worth persisting.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: A record with only a `sourceUrl` is still data — it records that
  /// the site was checked and listed nothing.
  bool get hasAnyData =>
      sourceUrl.isNotEmpty ||
      latestEpisode != null ||
      episodesText != null ||
      checkedAt != null ||
      extraJson.isNotEmpty;

  /// Purpose: Serialize this value into a JSON-compatible map.
  /// Inputs: None.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: Unknown fields are carried through from `extraJson`.
  Map<String, dynamic> toJson() {
    final json = Map<String, dynamic>.from(extraJson);
    json['sourceUrl'] = sourceUrl;
    if (catId != null) json['catId'] = catId;
    if (latestEpisode != null) json['latestEpisode'] = latestEpisode;
    if (episodesText != null) json['episodesText'] = episodesText;
    json['ongoing'] = ongoing;
    if (checkedAt != null) {
      json['checkedAt'] = checkedAt!.toUtc().toIso8601String();
    }
    return json;
  }

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: `json`.
  /// Returns: A new `AnimeWatchProgress`.
  /// Side effects: None.
  /// Notes: Values that fail to parse are kept in `extraJson` rather than
  /// dropped, following the pattern of every other record in this file.
  factory AnimeWatchProgress.fromJson(Map<String, dynamic> json) {
    final extraJson = _unknownJson(json, _watchProgressJsonKeys);

    String? readString(String key) {
      final raw = json[key];
      if (raw is String) return raw;
      if (json.containsKey(key)) extraJson[key] = raw;
      return null;
    }

    int? readInt(String key) {
      final raw = json[key];
      if (raw is int) return raw;
      if (json.containsKey(key)) extraJson[key] = raw;
      return null;
    }

    final rawOngoing = json['ongoing'];
    var ongoing = false;
    if (rawOngoing is bool) {
      ongoing = rawOngoing;
    } else if (json.containsKey('ongoing')) {
      extraJson['ongoing'] = rawOngoing;
    }

    final checkedAt = _parseUtcDateTime(json['checkedAt']);
    if (json.containsKey('checkedAt') && checkedAt == null) {
      extraJson['checkedAt'] = json['checkedAt'];
    }

    return AnimeWatchProgress(
      sourceUrl: readString('sourceUrl') ?? '',
      catId: readInt('catId'),
      latestEpisode: readInt('latestEpisode'),
      episodesText: readString('episodesText'),
      ongoing: ongoing,
      checkedAt: checkedAt,
      extraJson: extraJson,
    );
  }
}

class AnimeExternalMeta {
  /// Alternate titles across languages, as reported by the sources.
  final List<String> synonyms;

  /// Romanized Japanese title.
  final String? titleRomaji;

  /// English title, when it differs from the romanized one.
  final String? titleEn;

  /// Release format, e.g. `TV`, `MOVIE`, `OVA`, `ONA`, `SPECIAL`.
  final String? format;

  /// Broadcast status, e.g. `FINISHED`, `RELEASING`, `NOT_YET_RELEASED`.
  final String? status;

  /// Per-episode runtime in minutes.
  final int? durationMinutes;

  /// Genre tags.
  final List<String> genres;

  /// Animation studios.
  final List<String> studios;

  /// Date the final episode aired, when known.
  final DateTime? endDate;

  /// One entry per external source, keyed by its `source` name.
  final List<AnimeExternalRating> ratings;

  /// When this record was last refreshed from its sources (UTC).
  final DateTime? refreshedAt;

  /// What the watch site listed for `watchUrl` when last checked.
  final AnimeWatchProgress? watchProgress;

  /// JSON fields this app version does not understand yet.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create an external metadata instance.
  /// Inputs: `synonyms`, `titleRomaji`, `titleEn`, `format`, `status`, `durationMinutes`, `genres`, `studios`, `endDate`, `ratings`, `refreshedAt`, `watchProgress`, `extraJson`.
  /// Returns: A new `AnimeExternalMeta` instance.
  /// Side effects: None.
  /// Notes: None.
  const AnimeExternalMeta({
    this.synonyms = const [],
    this.titleRomaji,
    this.titleEn,
    this.format,
    this.status,
    this.durationMinutes,
    this.genres = const [],
    this.studios = const [],
    this.endDate,
    this.ratings = const [],
    this.refreshedAt,
    this.watchProgress,
    this.extraJson = const {},
  });

  /// Purpose: Report whether this record carries anything worth persisting.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: When false the owning `Anime` drops the record entirely, so an
  /// untouched anime never gains an `externalMeta` key.
  bool get hasAnyData =>
      synonyms.isNotEmpty ||
      titleRomaji != null ||
      titleEn != null ||
      format != null ||
      status != null ||
      durationMinutes != null ||
      genres.isNotEmpty ||
      studios.isNotEmpty ||
      endDate != null ||
      ratings.isNotEmpty ||
      watchProgress != null ||
      extraJson.isNotEmpty;

  /// Purpose: Look up this record's rating for one source.
  /// Inputs: `source`.
  /// Returns: `AnimeExternalRating?`.
  /// Side effects: None.
  /// Notes: Returns `null` when the source has never been fetched.
  AnimeExternalRating? ratingFor(String source) {
    for (final rating in ratings) {
      if (rating.source == source) return rating;
    }
    return null;
  }

  /// Purpose: Return one source's score rebased onto a 0-10 scale.
  /// Inputs: `source`.
  /// Returns: `double?`.
  /// Side effects: None.
  /// Notes: `null` when the source was never fetched or reported no score.
  double? normalizedScoreFor(String source) =>
      ratingFor(source)?.normalizedScore;

  /// Purpose: Return the mean of every external score this record holds.
  /// Inputs: None.
  /// Returns: `double?`.
  /// Side effects: None.
  /// Notes: Averages the 0-10 normalized scores, so sources reporting on
  /// different scales still combine correctly. Returns `null` when no source
  /// supplied a score.
  double? get averageNormalizedScore {
    var total = 0.0;
    var count = 0;
    for (final rating in ratings) {
      final value = rating.normalizedScore;
      if (value == null) continue;
      total += value;
      count++;
    }
    return count == 0 ? null : total / count;
  }

  /// Purpose: List the sources that actually supplied a score.
  /// Inputs: None.
  /// Returns: `List<String>`.
  /// Side effects: None.
  /// Notes: Drives the ranking view's source picker, which must only offer
  /// sources the data can actually rank by.
  List<String> get scoredSources => [
    for (final rating in ratings)
      if (rating.normalizedScore != null) rating.source,
  ];

  /// Purpose: Fold freshly fetched metadata into this record.
  /// Inputs: `other`, `refreshedAt`.
  /// Returns: `AnimeExternalMeta`.
  /// Side effects: None.
  /// Notes: Scalar and list fields are taken from `other` only when it actually
  /// supplies them, so refreshing against one source never erases what another
  /// source contributed. Ratings are replaced per `source` name.
  AnimeExternalMeta mergedWith(
    AnimeExternalMeta other, {
    DateTime? refreshedAt,
  }) {
    final mergedRatings = <String, AnimeExternalRating>{
      for (final rating in ratings) rating.source: rating,
    };
    for (final rating in other.ratings) {
      mergedRatings[rating.source] = rating;
    }
    final mergedSynonyms = <String>{...synonyms, ...other.synonyms}.toList();
    return AnimeExternalMeta(
      synonyms: mergedSynonyms,
      titleRomaji: other.titleRomaji ?? titleRomaji,
      titleEn: other.titleEn ?? titleEn,
      format: other.format ?? format,
      status: other.status ?? status,
      durationMinutes: other.durationMinutes ?? durationMinutes,
      genres: other.genres.isNotEmpty ? other.genres : genres,
      studios: other.studios.isNotEmpty ? other.studios : studios,
      endDate: other.endDate ?? endDate,
      ratings: mergedRatings.values.toList(),
      refreshedAt: refreshedAt ?? other.refreshedAt ?? this.refreshedAt,
      watchProgress: other.watchProgress ?? watchProgress,
      extraJson: _mergeJsonMaps([extraJson, other.extraJson]),
    );
  }

  /// Purpose: Create a copy with extra json.
  /// Inputs: `extraJson`.
  /// Returns: `AnimeExternalMeta`.
  /// Side effects: None.
  /// Notes: None.
  AnimeExternalMeta withExtraJson(Map<String, dynamic> extraJson) =>
      AnimeExternalMeta(
        synonyms: synonyms,
        titleRomaji: titleRomaji,
        titleEn: titleEn,
        format: format,
        status: status,
        durationMinutes: durationMinutes,
        genres: genres,
        studios: studios,
        endDate: endDate,
        ratings: ratings,
        refreshedAt: refreshedAt,
        watchProgress: watchProgress,
        extraJson: extraJson,
      );

  /// Purpose: Serialize this value into a JSON-compatible map.
  /// Inputs: None.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: None.
  Map<String, dynamic> toJson() {
    final json = Map<String, dynamic>.from(extraJson);

    void writeString(String key, String? value) {
      if (value != null) {
        json[key] = value;
      } else if (!extraJson.containsKey(key)) {
        json.remove(key);
      }
    }

    void writeList(String key, List<String> value) {
      if (value.isNotEmpty) {
        json[key] = List<String>.from(value);
      } else if (!extraJson.containsKey(key)) {
        json.remove(key);
      }
    }

    writeList('synonyms', synonyms);
    writeString('titleRomaji', titleRomaji);
    writeString('titleEn', titleEn);
    writeString('format', format);
    writeString('status', status);
    if (durationMinutes != null) {
      json['durationMinutes'] = durationMinutes;
    } else if (!extraJson.containsKey('durationMinutes')) {
      json.remove('durationMinutes');
    }
    writeList('genres', genres);
    writeList('studios', studios);
    if (endDate != null) {
      json['endDate'] = endDate!.toIso8601String();
    } else if (!extraJson.containsKey('endDate')) {
      json.remove('endDate');
    }
    if (ratings.isNotEmpty) {
      json['ratings'] = ratings.map((r) => r.toJson()).toList();
    } else if (!extraJson.containsKey('ratings')) {
      json.remove('ratings');
    }
    if (refreshedAt != null) {
      json['refreshedAt'] = refreshedAt!.toUtc().toIso8601String();
    } else if (!extraJson.containsKey('refreshedAt')) {
      json.remove('refreshedAt');
    }
    if (watchProgress != null) {
      json['watchProgress'] = watchProgress!.toJson();
    } else if (!extraJson.containsKey('watchProgress')) {
      json.remove('watchProgress');
    }
    return json;
  }

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: `json`.
  /// Returns: A new `AnimeExternalMeta.fromJson` instance.
  /// Side effects: None.
  /// Notes: Values that fail to parse are kept in `extraJson` rather than
  /// dropped, so a newer build's data survives an older build's edits.
  factory AnimeExternalMeta.fromJson(Map<String, dynamic> json) {
    final extraJson = _unknownJson(json, _externalMetaJsonKeys);

    String? readString(String key) {
      final raw = json[key];
      if (raw is String) return raw;
      if (json.containsKey(key)) extraJson[key] = raw;
      return null;
    }

    List<String> readList(String key) {
      final parsed = _parseStringList(json[key]);
      if (parsed == null) {
        if (json.containsKey(key)) extraJson[key] = json[key];
        return const [];
      }
      return parsed;
    }

    final rawDuration = json['durationMinutes'];
    int? durationMinutes;
    if (rawDuration is int) {
      durationMinutes = rawDuration;
    } else if (json.containsKey('durationMinutes')) {
      extraJson['durationMinutes'] = rawDuration;
    }

    final endDate = _parseCalendarDate(json['endDate']);
    if (json.containsKey('endDate') && endDate == null) {
      extraJson['endDate'] = json['endDate'];
    }

    final ratings = <AnimeExternalRating>[];
    final rawRatings = json['ratings'];
    if (rawRatings is List) {
      final unparsed = <dynamic>[];
      for (final entry in rawRatings) {
        if (entry is Map) {
          final rating = AnimeExternalRating.fromJson(_stringKeyedMap(entry));
          if (rating.hasAnyData || rating.source.isNotEmpty) {
            ratings.add(rating);
          }
        } else {
          unparsed.add(entry);
        }
      }
      if (unparsed.isNotEmpty) extraJson['ratings'] = unparsed;
    } else if (json.containsKey('ratings')) {
      extraJson['ratings'] = rawRatings;
    }

    final refreshedAt = _parseUtcDateTime(json['refreshedAt']);
    if (json.containsKey('refreshedAt') && refreshedAt == null) {
      extraJson['refreshedAt'] = json['refreshedAt'];
    }

    AnimeWatchProgress? watchProgress;
    final rawProgress = json['watchProgress'];
    if (rawProgress is Map) {
      final parsed = AnimeWatchProgress.fromJson(_stringKeyedMap(rawProgress));
      if (parsed.hasAnyData) watchProgress = parsed;
    } else if (json.containsKey('watchProgress')) {
      extraJson['watchProgress'] = rawProgress;
    }

    return AnimeExternalMeta(
      synonyms: readList('synonyms'),
      titleRomaji: readString('titleRomaji'),
      titleEn: readString('titleEn'),
      format: readString('format'),
      status: readString('status'),
      durationMinutes: durationMinutes,
      genres: readList('genres'),
      studios: readList('studios'),
      endDate: endDate,
      ratings: ratings,
      refreshedAt: refreshedAt,
      watchProgress: watchProgress,
      extraJson: extraJson,
    );
  }
}

class Anime {
  final String id;

  /// Display title (Chinese/English). If null, titleJa is used.
  final String? title;

  /// Japanese title (optional, but at least one of title/titleJa must be set).
  final String? titleJa;

  /// Season identifier, e.g. "Season 1".
  final String season;

  /// First episode number, default 1.
  final int startEpisode;

  /// Last episode number. null = long-running / unknown end.
  final int? endEpisode;

  /// Manual type override. When set, always takes effect.
  final AnimeType? manualType;

  /// Day of the week the anime airs (1=Monday..7=Sunday), Japan time.
  /// null if [effectiveType] is allAtOnce.
  final int? airDayOfWeek;

  /// Air time in Japan time, e.g. "21:00" or "25:00".
  /// null means end of day (23:59). null if allAtOnce.
  final String? airTime;

  /// First air date (the actual premiere date).
  final DateTime? firstAirDate;

  /// Per-episode status map. Key = episode number.
  final Map<int, EpisodeStatus> episodeStatuses;

  /// Optional cover image relative path (e.g. "images/xxx.png").
  final String? coverImage;

  /// Optional info URL (source page from search, e.g. bangumi.tv, AniList).
  final String? infoUrl;

  /// Optional watch URL for quick browser launch.
  final String? watchUrl;

  /// Per-episode cumulative week offset adjustments.
  /// Key = episode number where an adjustment starts.
  /// Value = number of weeks to shift (positive = delay, negative = earlier).
  /// The total offset for an episode is the sum of all entries with key <= ep.
  final Map<int, int> episodeWeekOffsets;

  /// Optional notes.
  final String? notes;

  /// Optional personal rating.
  final AnimeRating? rating;

  /// Optional record of a downloaded local copy.
  final AnimeLocalArchive? localArchive;

  /// Optional series membership set by the user (see [AnimeSeriesLink]).
  final AnimeSeriesLink? seriesLink;

  /// Optional public metadata pulled from external anime databases.
  final AnimeExternalMeta? externalMeta;

  final DateTime createdAt;
  final DateTime modifiedAt;

  /// JSON fields this app version does not understand yet.
  ///
  /// These are preserved verbatim so older app versions do not erase data
  /// written by newer versions during normal edits or sync.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a anime instance.
  /// Inputs: `id`, `title`, `titleJa`, `season`, `startEpisode`, `endEpisode`, `manualType`, `airDayOfWeek`, `airTime`, `firstAirDate`, `episodeStatuses`, `coverImage`, `infoUrl`, `watchUrl`, `episodeWeekOffsets`, `notes`, `rating`, `localArchive`, `seriesLink`, `externalMeta`, `createdAt`, `modifiedAt`, `extraJson`.
  /// Returns: A new `Anime` instance.
  /// Side effects: None.
  /// Notes: None.
  const Anime({
    required this.id,
    this.title,
    this.titleJa,
    this.season = 'Season 1',
    this.startEpisode = 1,
    this.endEpisode = 13,
    this.manualType,
    this.airDayOfWeek,
    this.airTime,
    this.firstAirDate,
    this.episodeStatuses = const {},
    this.coverImage,
    this.infoUrl,
    this.watchUrl,
    this.episodeWeekOffsets = const {},
    this.notes,
    this.rating,
    this.localArchive,
    this.seriesLink,
    this.externalMeta,
    required this.createdAt,
    required this.modifiedAt,
    this.extraJson = const {},
  });

  /// Purpose: Return the best available title for display.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Prefers `title`, then `titleJa`, and falls back to an empty string.
  String get displayTitle => title?.isNotEmpty == true
      ? title!
      : (titleJa?.isNotEmpty == true ? titleJa! : '');

  /// Purpose: Return the total episode count when the ending episode is known.
  /// Inputs: None.
  /// Returns: `int?`.
  /// Side effects: None.
  /// Notes: Returns `null` for long-running or open-ended series.
  int? get totalEpisodes =>
      endEpisode != null ? endEpisode! - startEpisode + 1 : null;

  /// Purpose: Infer the anime type from the current episode count.
  /// Inputs: None.
  /// Returns: `AnimeType`.
  /// Side effects: None.
  /// Notes: Only reflects automatic detection and does not apply the manual override.
  AnimeType get autoType {
    final total = totalEpisodes;
    if (total == null) return AnimeType.longRunning;
    if (total <= 13) return AnimeType.singleCour;
    if (total <= 26) return AnimeType.halfYear;
    if (total <= 52) return AnimeType.fullYear;
    return AnimeType.longRunning;
  }

  /// Purpose: Return the anime type that should drive app behavior.
  /// Inputs: None.
  /// Returns: `AnimeType`.
  /// Side effects: None.
  /// Notes: Uses `manualType` when present and otherwise falls back to `autoType`.
  AnimeType get effectiveType {
    if (manualType != null) return manualType!;
    return autoType;
  }

  /// Purpose: Determine whether this anime should appear in the requested quarter.
  /// Inputs: `year`, `quarter`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Manual type overrides use cour-style spans; otherwise the method estimates quarter coverage from episode count, offsets, and fallback date overlap.
  bool airsInQuarter(int year, int quarter) {
    if (firstAirDate == null) return false;

    final sq = startQuarter;
    if (sq == null) return false;

    // When manual type is set, use cour-based quarter span.
    if (manualType != null && manualType != AnimeType.longRunning) {
      final int spanQuarters;
      switch (manualType!) {
        case AnimeType.allAtOnce:
        case AnimeType.singleCour:
          spanQuarters = 1;
        case AnimeType.halfYear:
          spanQuarters = 2;
        case AnimeType.fullYear:
          spanQuarters = 4;
        case AnimeType.longRunning:
          spanQuarters = 0; // unreachable
      }
      final startIdx = sq.$1 * 4 + sq.$2;
      final queryIdx = year * 4 + quarter;
      return queryIdx >= startIdx && queryIdx < startIdx + spanQuarters;
    }

    // No manual type — compute actual run weeks from episode count + offsets.
    final ep = totalEpisodes;
    if (ep != null) {
      final lastEp = startEpisode + ep - 1;
      final actualWeeks = (ep - 1) + weekOffsetFor(lastEp);
      // Map to cour count with ~2 weeks tolerance per boundary.
      final int spanQuarters;
      if (actualWeeks <= 15) {
        spanQuarters = 1;
      } else if (actualWeeks <= 28) {
        spanQuarters = 2;
      } else if (actualWeeks <= 41) {
        spanQuarters = 3;
      } else if (actualWeeks <= 54) {
        spanQuarters = 4;
      } else {
        spanQuarters = (actualWeeks / 13).ceil();
      }
      final startIdx = sq.$1 * 4 + sq.$2;
      final queryIdx = year * 4 + quarter;
      return queryIdx >= startIdx && queryIdx < startIdx + spanQuarters;
    }

    // Long-running (no end episode) — fall back to date overlap.
    final quarterStartMonth = (quarter - 1) * 3 + 1;
    final quarterStart = DateTime(year, quarterStartMonth);
    final quarterEnd = DateTime(
      quarterStartMonth == 10 ? year + 1 : year,
      quarterStartMonth == 10 ? 1 : quarterStartMonth + 3,
    );
    final estimatedEnd = firstAirDate!.add(const Duration(days: 51 * 7));
    return firstAirDate!.isBefore(quarterEnd) &&
        estimatedEnd.isAfter(quarterStart);
  }

  /// Purpose: Return the starting broadcast quarter for this anime.
  /// Inputs: None.
  /// Returns: `(int, int)?`.
  /// Side effects: None.
  /// Notes: Returns `(year, quarter)` when `firstAirDate` is known.
  (int, int)? get startQuarter {
    if (firstAirDate == null) return null;
    final month = firstAirDate!.month;
    final year = firstAirDate!.year;
    if (month >= 1 && month <= 3) return (year, 1);
    if (month >= 4 && month <= 6) return (year, 2);
    if (month >= 7 && month <= 9) return (year, 3);
    return (year, 4);
  }

  /// Purpose: Sum all configured week adjustments that affect the requested episode.
  /// Inputs: `episodeNumber`.
  /// Returns: `int`.
  /// Side effects: None.
  /// Notes: Uses cumulative offsets from every entry whose key is less than or equal to the episode number.
  int weekOffsetFor(int episodeNumber) {
    int offset = 0;
    for (final entry in episodeWeekOffsets.entries) {
      if (entry.key <= episodeNumber) offset += entry.value;
    }
    return offset;
  }

  /// Purpose: Compute the JST air timestamp for the requested episode when scheduling data is complete.
  /// Inputs: `episodeNumber`.
  /// Returns: `DateTime?`.
  /// Side effects: None.
  /// Notes: Returns `null` when the anime lacks enough timing data to calculate the episode air time.
  DateTime? getEpisodeAirDate(int episodeNumber) {
    if (firstAirDate == null) return null;
    if (effectiveType == AnimeType.allAtOnce) return firstAirDate;
    if (airDayOfWeek == null) return null;

    // Calculate weeks from first air date
    final episodeOffset = episodeNumber - startEpisode;
    if (episodeOffset < 0) return null;

    final totalWeeks = episodeOffset + weekOffsetFor(episodeNumber);
    final baseDate = firstAirDate!.add(Duration(days: totalWeeks * 7));

    // Adjust to the correct day of week, snapping forward so episode 1 never
    // lands before firstAirDate when airDayOfWeek disagrees with its weekday.
    final currentDow = baseDate.weekday; // 1=Mon..7=Sun
    var diff = airDayOfWeek! - currentDow;
    if (diff < 0) diff += 7;
    var airDate = baseDate.add(Duration(days: diff));

    // Apply air time
    if (airTime != null) {
      final parts = airTime!.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]) ?? 23;
        final minute = int.tryParse(parts[1]) ?? 59;
        // Support times like 25:00 (= next day 01:00)
        airDate = DateTime(
          airDate.year,
          airDate.month,
          airDate.day,
          0,
          0,
        ).add(Duration(hours: hour, minutes: minute));
      }
    } else {
      airDate = DateTime(airDate.year, airDate.month, airDate.day, 23, 59);
    }

    return airDate;
  }

  /// Purpose: Compute the JST calendar date for the requested episode without applying late-night rollover.
  /// Inputs: `episodeNumber`.
  /// Returns: `DateTime?`.
  /// Side effects: None.
  /// Notes: Unlike `getEpisodeAirDate`, this stays on the scheduled broadcast date even for `24:00` or `25:00` times.
  DateTime? getEpisodeCalendarDate(int episodeNumber) {
    if (firstAirDate == null) return null;
    if (effectiveType == AnimeType.allAtOnce) {
      return DateTime(
        firstAirDate!.year,
        firstAirDate!.month,
        firstAirDate!.day,
      );
    }
    if (airDayOfWeek == null) return null;

    final episodeOffset = episodeNumber - startEpisode;
    if (episodeOffset < 0) return null;

    final totalWeeks = episodeOffset + weekOffsetFor(episodeNumber);
    final baseDate = firstAirDate!.add(Duration(days: totalWeeks * 7));

    // Snap forward (matching getEpisodeAirDate) so calendar placement never
    // precedes firstAirDate.
    final currentDow = baseDate.weekday;
    var diff = airDayOfWeek! - currentDow;
    if (diff < 0) diff += 7;
    final dayDate = baseDate.add(Duration(days: diff));
    return DateTime(dayDate.year, dayDate.month, dayDate.day);
  }

  /// Purpose: Return the first episode number that is still unwatched.
  /// Inputs: None.
  /// Returns: `int?`.
  /// Side effects: None.
  /// Notes: Returns `null` when every tracked episode is already watched or skipped.
  int? get nextUnwatchedEpisode {
    final end = endEpisode ?? (startEpisode + 999);
    for (int ep = startEpisode; ep <= end; ep++) {
      final status = episodeStatuses[ep];
      if (status == null || status == EpisodeStatus.unwatched) {
        return ep;
      }
    }
    return null;
  }

  /// Purpose: Return the stored watch-site progress if it still applies.
  /// Inputs: None.
  /// Returns: `AnimeWatchProgress?` — `null` when nothing is stored or when
  /// it was read for a different `watchUrl`.
  /// Side effects: None.
  /// Notes: The record keeps the URL it was fetched for, so editing the
  /// watch URL hides a stale count until the next check.
  AnimeWatchProgress? get validWatchProgress {
    final progress = externalMeta?.watchProgress;
    if (progress == null) return null;
    final url = watchUrl?.trim();
    if (url == null || url.isEmpty || progress.sourceUrl != url) return null;
    return progress;
  }

  /// Purpose: Whether all episodes have been watched.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Whether all episodes have been watched.
  bool get isCompleted {
    if (endEpisode == null) return false;
    for (int ep = startEpisode; ep <= endEpisode!; ep++) {
      if (episodeStatuses[ep] != EpisodeStatus.watched) return false;
    }
    return true;
  }

  /// Purpose: Return the derived viewing status for this anime.
  /// Inputs: None.
  /// Returns: `AnimeViewingStatus`.
  /// Side effects: None.
  /// Notes: Dropped means every tracked episode is either watched or skipped, with at least one skipped episode.
  AnimeViewingStatus get viewingStatus {
    if (isCompleted) return AnimeViewingStatus.completed;

    final end = endEpisode;
    if (end == null) {
      final hasWatched = episodeStatuses.values.any(
        (status) => status == EpisodeStatus.watched,
      );
      return hasWatched
          ? AnimeViewingStatus.watching
          : AnimeViewingStatus.notStarted;
    }

    var hasUnwatched = false;
    var hasWatched = false;
    var hasSkipped = false;
    for (var ep = startEpisode; ep <= end; ep++) {
      final status = episodeStatuses[ep] ?? EpisodeStatus.unwatched;
      if (status == EpisodeStatus.unwatched) hasUnwatched = true;
      if (status == EpisodeStatus.watched) hasWatched = true;
      if (status == EpisodeStatus.skippedThisWeek) hasSkipped = true;
    }

    if (hasSkipped && !hasUnwatched) return AnimeViewingStatus.dropped;
    if (hasWatched) return AnimeViewingStatus.watching;
    return AnimeViewingStatus.notStarted;
  }

  /// Purpose: Create a copy with selected fields replaced.
  /// Inputs: `title`, `titleJa`, `season`, `startEpisode`, `endEpisode`, `clearEndEpisode`, `manualType`, `clearManualType`, `airDayOfWeek`, `clearAirDayOfWeek`, `airTime`, `clearAirTime`, `firstAirDate`, `clearFirstAirDate`, `episodeStatuses`, `coverImage`, `clearCoverImage`, `infoUrl`, `clearInfoUrl`, `watchUrl`, `clearWatchUrl`, `episodeWeekOffsets`, `notes`, `clearNotes`, `rating`, `clearRating`, `localArchive`, `clearLocalArchive`, `seriesLink`, `clearSeriesLink`, `externalMeta`, `clearExternalMeta`, `modifiedAt`.
  /// Returns: `Anime`.
  /// Side effects: None.
  /// Notes: `modifiedAt` defaults to now, so a write that must not count as a
  /// user edit has to pass the old value explicitly.
  Anime copyWith({
    String? title,
    String? titleJa,
    String? season,
    int? startEpisode,
    int? endEpisode,
    bool clearEndEpisode = false,
    AnimeType? manualType,
    bool clearManualType = false,
    int? airDayOfWeek,
    bool clearAirDayOfWeek = false,
    String? airTime,
    bool clearAirTime = false,
    DateTime? firstAirDate,
    bool clearFirstAirDate = false,
    Map<int, EpisodeStatus>? episodeStatuses,
    String? coverImage,
    bool clearCoverImage = false,
    String? infoUrl,
    bool clearInfoUrl = false,
    String? watchUrl,
    bool clearWatchUrl = false,
    Map<int, int>? episodeWeekOffsets,
    String? notes,
    bool clearNotes = false,
    AnimeRating? rating,
    bool clearRating = false,
    AnimeLocalArchive? localArchive,
    bool clearLocalArchive = false,
    AnimeSeriesLink? seriesLink,
    bool clearSeriesLink = false,
    AnimeExternalMeta? externalMeta,
    bool clearExternalMeta = false,
    DateTime? modifiedAt,
  }) {
    return Anime(
      id: id,
      title: title ?? this.title,
      titleJa: titleJa ?? this.titleJa,
      season: season ?? this.season,
      startEpisode: startEpisode ?? this.startEpisode,
      endEpisode: clearEndEpisode ? null : (endEpisode ?? this.endEpisode),
      manualType: clearManualType ? null : (manualType ?? this.manualType),
      airDayOfWeek: clearAirDayOfWeek
          ? null
          : (airDayOfWeek ?? this.airDayOfWeek),
      airTime: clearAirTime ? null : (airTime ?? this.airTime),
      firstAirDate: clearFirstAirDate
          ? null
          : (firstAirDate ?? this.firstAirDate),
      episodeStatuses: episodeStatuses ?? this.episodeStatuses,
      coverImage: clearCoverImage ? null : (coverImage ?? this.coverImage),
      infoUrl: clearInfoUrl ? null : (infoUrl ?? this.infoUrl),
      watchUrl: clearWatchUrl ? null : (watchUrl ?? this.watchUrl),
      episodeWeekOffsets: episodeWeekOffsets ?? this.episodeWeekOffsets,
      notes: clearNotes ? null : (notes ?? this.notes),
      rating: clearRating ? null : (rating ?? this.rating),
      localArchive: clearLocalArchive
          ? null
          : (localArchive ?? this.localArchive),
      seriesLink: clearSeriesLink ? null : (seriesLink ?? this.seriesLink),
      externalMeta: clearExternalMeta
          ? null
          : (externalMeta ?? this.externalMeta),
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? DateTime.now().toUtc(),
      extraJson: extraJson,
    );
  }

  /// Purpose: Create a copy with extra json.
  /// Inputs: `extraJson`.
  /// Returns: `Anime`.
  /// Side effects: None.
  /// Notes: None.
  Anime withExtraJson(Map<String, dynamic> extraJson) => Anime(
    id: id,
    title: title,
    titleJa: titleJa,
    season: season,
    startEpisode: startEpisode,
    endEpisode: endEpisode,
    manualType: manualType,
    airDayOfWeek: airDayOfWeek,
    airTime: airTime,
    firstAirDate: firstAirDate,
    episodeStatuses: episodeStatuses,
    coverImage: coverImage,
    infoUrl: infoUrl,
    watchUrl: watchUrl,
    episodeWeekOffsets: episodeWeekOffsets,
    notes: notes,
    rating: rating,
    localArchive: localArchive,
    seriesLink: seriesLink,
    externalMeta: externalMeta,
    createdAt: createdAt,
    modifiedAt: modifiedAt,
    extraJson: extraJson,
  );

  /// Purpose: Create a copy with preserved unknown json.
  /// Inputs: `fallbackSources`.
  /// Returns: `Anime`.
  /// Side effects: None.
  /// Notes: None.
  Anime withPreservedUnknownJson(Iterable<Anime?> fallbackSources) {
    final sources = fallbackSources.toList();
    final mergedRatingExtraJson = _mergeJsonMaps([
      for (final source in sources)
        if (source?.rating != null) source!.rating!.extraJson,
      if (rating != null) rating!.extraJson,
    ]);
    final preservedRating = rating != null
        ? rating!.withExtraJson(mergedRatingExtraJson)
        : (mergedRatingExtraJson.isNotEmpty
              ? AnimeRating(extraJson: mergedRatingExtraJson)
              : null);

    final mergedArchiveExtraJson = _mergeJsonMaps([
      for (final source in sources)
        if (source?.localArchive != null) source!.localArchive!.extraJson,
      if (localArchive != null) localArchive!.extraJson,
    ]);
    final preservedLocalArchive = localArchive != null
        ? localArchive!.withExtraJson(mergedArchiveExtraJson)
        : (mergedArchiveExtraJson.isNotEmpty
              ? AnimeLocalArchive(extraJson: mergedArchiveExtraJson)
              : null);

    final mergedSeriesLinkExtraJson = _mergeJsonMaps([
      for (final source in sources)
        if (source?.seriesLink != null) source!.seriesLink!.extraJson,
      if (seriesLink != null) seriesLink!.extraJson,
    ]);
    final preservedSeriesLink = seriesLink != null
        ? seriesLink!.withExtraJson(mergedSeriesLinkExtraJson)
        : (mergedSeriesLinkExtraJson.isNotEmpty
              ? AnimeSeriesLink(extraJson: mergedSeriesLinkExtraJson)
              : null);

    final mergedExternalMetaExtraJson = _mergeJsonMaps([
      for (final source in sources)
        if (source?.externalMeta != null) source!.externalMeta!.extraJson,
      if (externalMeta != null) externalMeta!.extraJson,
    ]);
    final preservedExternalMeta = externalMeta != null
        ? externalMeta!.withExtraJson(mergedExternalMetaExtraJson)
        : (mergedExternalMetaExtraJson.isNotEmpty
              ? AnimeExternalMeta(extraJson: mergedExternalMetaExtraJson)
              : null);

    return Anime(
      id: id,
      title: title,
      titleJa: titleJa,
      season: season,
      startEpisode: startEpisode,
      endEpisode: endEpisode,
      manualType: manualType,
      airDayOfWeek: airDayOfWeek,
      airTime: airTime,
      firstAirDate: firstAirDate,
      episodeStatuses: episodeStatuses,
      coverImage: coverImage,
      infoUrl: infoUrl,
      watchUrl: watchUrl,
      episodeWeekOffsets: episodeWeekOffsets,
      notes: notes,
      rating: preservedRating,
      localArchive: preservedLocalArchive,
      seriesLink: preservedSeriesLink,
      externalMeta: preservedExternalMeta,
      createdAt: createdAt,
      modifiedAt: modifiedAt,
      extraJson: _mergeJsonMaps([
        for (final source in sources)
          if (source != null) source.extraJson,
        extraJson,
      ]),
    );
  }

  /// Purpose: Serialize this value into a JSON-compatible map.
  /// Inputs: None.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: None.
  Map<String, dynamic> toJson() {
    final json = Map<String, dynamic>.from(extraJson);

    final statusJson = <String, dynamic>{};
    final rawStatuses = extraJson['episodeStatuses'];
    if (rawStatuses is Map) {
      statusJson.addAll(_stringKeyedMap(rawStatuses));
    }
    statusJson.addAll(
      episodeStatuses.map((k, v) => MapEntry(k.toString(), v.name)),
    );

    final weekOffsetJson = <String, dynamic>{};
    final rawWeekOffsets = extraJson['episodeWeekOffsets'];
    if (rawWeekOffsets is Map) {
      weekOffsetJson.addAll(_stringKeyedMap(rawWeekOffsets));
    }
    weekOffsetJson.addAll(
      episodeWeekOffsets.map((k, v) => MapEntry(k.toString(), v)),
    );

    json['id'] = id;
    if (title != null) {
      json['title'] = title;
    } else {
      json.remove('title');
    }
    if (titleJa != null) {
      json['titleJa'] = titleJa;
    } else {
      json.remove('titleJa');
    }
    json['season'] = season;
    json['startEpisode'] = startEpisode;
    if (endEpisode != null) {
      json['endEpisode'] = endEpisode;
    } else {
      json.remove('endEpisode');
    }
    if (manualType != null) {
      json['manualType'] = manualType!.name;
    } else if (!extraJson.containsKey('manualType')) {
      json.remove('manualType');
    }
    if (airDayOfWeek != null) {
      json['airDayOfWeek'] = airDayOfWeek;
    } else {
      json.remove('airDayOfWeek');
    }
    if (airTime != null) {
      json['airTime'] = airTime;
    } else {
      json.remove('airTime');
    }
    if (firstAirDate != null) {
      json['firstAirDate'] = firstAirDate!.toIso8601String();
    } else {
      json.remove('firstAirDate');
    }
    json['episodeStatuses'] = statusJson;
    if (coverImage != null) {
      json['coverImage'] = coverImage;
    } else {
      json.remove('coverImage');
    }
    if (infoUrl != null) {
      json['infoUrl'] = infoUrl;
    } else {
      json.remove('infoUrl');
    }
    if (watchUrl != null) {
      json['watchUrl'] = watchUrl;
    } else {
      json.remove('watchUrl');
    }
    if (weekOffsetJson.isNotEmpty) {
      json['episodeWeekOffsets'] = weekOffsetJson;
    } else {
      json.remove('episodeWeekOffsets');
    }
    if (notes != null) {
      json['notes'] = notes;
    } else {
      json.remove('notes');
    }
    if (rating != null && rating!.hasAnyData) {
      json['rating'] = rating!.toJson();
    } else if (!extraJson.containsKey('rating')) {
      json.remove('rating');
    }
    if (localArchive != null && localArchive!.hasAnyData) {
      json['localArchive'] = localArchive!.toJson();
    } else if (!extraJson.containsKey('localArchive')) {
      json.remove('localArchive');
    }
    if (seriesLink != null && seriesLink!.hasAnyData) {
      json['seriesLink'] = seriesLink!.toJson();
    } else if (!extraJson.containsKey('seriesLink')) {
      json.remove('seriesLink');
    }
    if (externalMeta != null && externalMeta!.hasAnyData) {
      json['externalMeta'] = externalMeta!.toJson();
    } else if (!extraJson.containsKey('externalMeta')) {
      json.remove('externalMeta');
    }
    json['createdAt'] = createdAt.toIso8601String();
    json['modifiedAt'] = modifiedAt.toIso8601String();

    return json;
  }

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: `json`.
  /// Returns: A new `Anime.fromJson` instance.
  /// Side effects: None.
  /// Notes: None.
  factory Anime.fromJson(Map<String, dynamic> json) {
    final extraJson = _unknownJson(json, _animeJsonKeys);

    final manualType = _parseAnimeType(json['manualType']);
    if (json.containsKey('manualType') && manualType == null) {
      extraJson['manualType'] = json['manualType'];
    }

    final statuses = <int, EpisodeStatus>{};
    final unknownStatuses = <String, dynamic>{};
    final rawStatusesValue = json['episodeStatuses'];
    if (rawStatusesValue is Map) {
      final rawStatuses = _stringKeyedMap(rawStatusesValue);
      for (final entry in rawStatuses.entries) {
        final ep = int.tryParse(entry.key);
        final status = _parseEpisodeStatus(entry.value);
        if (ep != null && status != null) {
          statuses[ep] = status;
        } else {
          unknownStatuses[entry.key] = entry.value;
        }
      }
    } else if (json.containsKey('episodeStatuses')) {
      extraJson['episodeStatuses'] = rawStatusesValue;
    }
    if (unknownStatuses.isNotEmpty) {
      extraJson['episodeStatuses'] = unknownStatuses;
    }

    final weekOffsets = <int, int>{};
    final unknownWeekOffsets = <String, dynamic>{};
    final rawOffsetsValue = json['episodeWeekOffsets'];
    if (rawOffsetsValue is Map) {
      final rawOffsets = _stringKeyedMap(rawOffsetsValue);
      for (final entry in rawOffsets.entries) {
        final ep = int.tryParse(entry.key);
        final val = entry.value;
        if (ep != null && val is int) {
          weekOffsets[ep] = val;
        } else {
          unknownWeekOffsets[entry.key] = val;
        }
      }
    } else if (json.containsKey('episodeWeekOffsets')) {
      extraJson['episodeWeekOffsets'] = rawOffsetsValue;
    }
    if (unknownWeekOffsets.isNotEmpty) {
      extraJson['episodeWeekOffsets'] = unknownWeekOffsets;
    }

    AnimeRating? rating;
    final rawRatingValue = json['rating'];
    if (rawRatingValue is Map) {
      rating = AnimeRating.fromJson(_stringKeyedMap(rawRatingValue));
      if (!rating.hasAnyData) rating = null;
    } else if (json.containsKey('rating')) {
      extraJson['rating'] = rawRatingValue;
    }

    AnimeLocalArchive? localArchive;
    final rawArchiveValue = json['localArchive'];
    if (rawArchiveValue is Map) {
      localArchive = AnimeLocalArchive.fromJson(
        _stringKeyedMap(rawArchiveValue),
      );
      if (!localArchive.hasAnyData) localArchive = null;
    } else if (json.containsKey('localArchive')) {
      extraJson['localArchive'] = rawArchiveValue;
    }

    AnimeSeriesLink? seriesLink;
    final rawSeriesLinkValue = json['seriesLink'];
    if (rawSeriesLinkValue is Map) {
      seriesLink = AnimeSeriesLink.fromJson(
        _stringKeyedMap(rawSeriesLinkValue),
      );
      if (!seriesLink.hasAnyData) seriesLink = null;
    } else if (json.containsKey('seriesLink')) {
      extraJson['seriesLink'] = rawSeriesLinkValue;
    }

    AnimeExternalMeta? externalMeta;
    final rawExternalMetaValue = json['externalMeta'];
    if (rawExternalMetaValue is Map) {
      externalMeta = AnimeExternalMeta.fromJson(
        _stringKeyedMap(rawExternalMetaValue),
      );
      if (!externalMeta.hasAnyData) externalMeta = null;
    } else if (json.containsKey('externalMeta')) {
      extraJson['externalMeta'] = rawExternalMetaValue;
    }

    return Anime(
      id: json['id'] as String,
      title: json['title'] as String?,
      titleJa: json['titleJa'] as String?,
      season: json['season'] as String? ?? 'Season 1',
      startEpisode: json['startEpisode'] as int? ?? 1,
      endEpisode: json['endEpisode'] as int?,
      manualType: manualType,
      airDayOfWeek: json['airDayOfWeek'] as int?,
      airTime: json['airTime'] as String?,
      firstAirDate: json['firstAirDate'] != null
          ? DateTime.parse(json['firstAirDate'] as String)
          : null,
      episodeStatuses: statuses,
      coverImage: json['coverImage'] as String?,
      infoUrl: json['infoUrl'] as String?,
      watchUrl: json['watchUrl'] as String?,
      episodeWeekOffsets: weekOffsets,
      notes: json['notes'] as String?,
      rating: rating,
      localArchive: localArchive,
      seriesLink: seriesLink,
      externalMeta: externalMeta,
      createdAt: DateTime.parse(json['createdAt'] as String),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
      extraJson: extraJson,
    );
  }

  /// Purpose: Create a new anime record with default values for manual entry.
  /// Inputs: `title`, `titleJa`, `season`, `startEpisode`, `endEpisode`, `manualType`, `airDayOfWeek`, `airTime`, `firstAirDate`, `coverImage`, `infoUrl`, `watchUrl`, `notes`, `rating`, `localArchive`, `externalMeta`.
  /// Returns: A new `Anime.create` instance.
  /// Side effects: None.
  /// Notes: Generates a new UUID and initializes UTC creation and modification timestamps.
  factory Anime.create({
    String? title,
    String? titleJa,
    String? season,
    int startEpisode = 1,
    int? endEpisode = 13,
    AnimeType? manualType,
    int? airDayOfWeek,
    String? airTime,
    DateTime? firstAirDate,
    String? coverImage,
    String? infoUrl,
    String? watchUrl,
    String? notes,
    AnimeRating? rating,
    AnimeLocalArchive? localArchive,
    AnimeExternalMeta? externalMeta,
  }) {
    final now = DateTime.now().toUtc();
    return Anime(
      id: const Uuid().v4(),
      title: title,
      titleJa: titleJa,
      season: season ?? 'Season 1',
      startEpisode: startEpisode,
      endEpisode: endEpisode,
      manualType: manualType,
      airDayOfWeek: airDayOfWeek,
      airTime: airTime,
      firstAirDate: firstAirDate,
      coverImage: coverImage,
      infoUrl: infoUrl,
      watchUrl: watchUrl,
      notes: notes,
      rating: rating,
      localArchive: localArchive,
      externalMeta: externalMeta,
      createdAt: now,
      modifiedAt: now,
    );
  }
}

/// Top-level data container for all anime entries.
class AnimeData {
  final List<Anime> animes;
  final Map<String, dynamic> extraJson;

  /// Purpose: Implement the anime list behavior for this file.
  /// Inputs: None.
  /// Returns: `List<Anime>`.
  /// Side effects: None.
  /// Notes: None.
  List<Anime> get animeList => animes;

  const AnimeData({this.animes = const [], this.extraJson = const {}});

  /// Purpose: Create a copy with extra json.
  /// Inputs: `extraJson`.
  /// Returns: `AnimeData`.
  /// Side effects: None.
  /// Notes: None.
  AnimeData withExtraJson(Map<String, dynamic> extraJson) =>
      AnimeData(animes: animes, extraJson: extraJson);

  /// Purpose: Create a copy with preserved unknown json.
  /// Inputs: `fallbackSources`.
  /// Returns: `AnimeData`.
  /// Side effects: None.
  /// Notes: None.
  AnimeData withPreservedUnknownJson(Iterable<AnimeData?> fallbackSources) =>
      withExtraJson(
        _mergeJsonMaps([
          for (final source in fallbackSources)
            if (source != null) source.extraJson,
          extraJson,
        ]),
      );

  /// Purpose: Serialize this value into a JSON-compatible map.
  /// Inputs: None.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: None.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'animes': animes.map((a) => a.toJson()).toList(),
  };

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: `json`.
  /// Returns: A new `AnimeData.fromJson` instance.
  /// Side effects: None.
  /// Notes: None.
  factory AnimeData.fromJson(Map<String, dynamic> json) {
    final list =
        (json['animes'] as List<dynamic>?)
            ?.map((e) => Anime.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return AnimeData(
      animes: list,
      extraJson: _unknownJson(json, _animeDataJsonKeys),
    );
  }
}
