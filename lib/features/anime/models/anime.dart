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

const _animeDataJsonKeys = {'animes'};

Map<String, dynamic> _unknownJson(
  Map<String, dynamic> json,
  Set<String> knownKeys,
) {
  final extra = Map<String, dynamic>.from(json);
  extra.removeWhere((key, _) => knownKeys.contains(key));
  return extra;
}

Map<String, dynamic> _stringKeyedMap(Map<dynamic, dynamic> map) => {
  for (final entry in map.entries) entry.key.toString(): entry.value,
};

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

AnimeType? _parseAnimeType(Object? value) {
  if (value is! String) return null;
  for (final type in AnimeType.values) {
    if (type.name == value) return type;
  }
  return null;
}

EpisodeStatus? _parseEpisodeStatus(Object? value) {
  if (value is! String) return null;
  for (final status in EpisodeStatus.values) {
    if (status.name == value) return status;
  }
  return null;
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

/// Rating fields available for sorting and display.
enum AnimeRatingField { overall, visual, story, character, music, enjoyment }

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

  const AnimeRating({
    this.overall,
    this.visual,
    this.story,
    this.character,
    this.music,
    this.enjoyment,
    this.extraJson = const {},
  });

  bool get hasManualOverall => overall != null;

  bool get hasAnyScore =>
      overall != null ||
      visual != null ||
      story != null ||
      character != null ||
      music != null ||
      enjoyment != null;

  bool get hasAnyData => hasAnyScore || extraJson.isNotEmpty;

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

  AnimeRating withExtraJson(Map<String, dynamic> extraJson) => AnimeRating(
    overall: overall,
    visual: visual,
    story: story,
    character: character,
    music: music,
    enjoyment: enjoyment,
    extraJson: extraJson,
  );

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

double? _parseScore(Object? value) {
  if (value is num) return value.toDouble();
  return null;
}

void _writeScore(Map<String, dynamic> json, String key, double? score) {
  if (score != null) {
    json[key] = score;
  } else if (!json.containsKey(key)) {
    json.remove(key);
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

  final DateTime createdAt;
  final DateTime modifiedAt;

  /// JSON fields this app version does not understand yet.
  ///
  /// These are preserved verbatim so older app versions do not erase data
  /// written by newer versions during normal edits or sync.
  final Map<String, dynamic> extraJson;

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
    required this.createdAt,
    required this.modifiedAt,
    this.extraJson = const {},
  });

  /// The display title: title ?? titleJa ?? ''.
  String get displayTitle => title?.isNotEmpty == true
      ? title!
      : (titleJa?.isNotEmpty == true ? titleJa! : '');

  /// Total episode count, or null if long-running.
  int? get totalEpisodes =>
      endEpisode != null ? endEpisode! - startEpisode + 1 : null;

  /// Auto-detected type based on episode count.
  AnimeType get autoType {
    final total = totalEpisodes;
    if (total == null) return AnimeType.longRunning;
    if (total <= 13) return AnimeType.singleCour;
    if (total <= 26) return AnimeType.halfYear;
    if (total <= 52) return AnimeType.fullYear;
    return AnimeType.longRunning;
  }

  /// Effective type: manual override always wins when set.
  AnimeType get effectiveType {
    if (manualType != null) return manualType!;
    return autoType;
  }

  /// Whether this anime airs in a given season quarter (1-4).
  ///
  /// When [manualType] is set, the anime spans a fixed number of consecutive
  /// quarters from its start quarter (Japanese anime cour convention):
  ///   - allAtOnce / singleCour → 1 quarter
  ///   - halfYear (2クール) → 2 quarters
  ///   - fullYear (4クール) → 4 quarters
  ///   - longRunning → falls through to week-based estimation
  ///
  /// When no manual type is set, the actual run duration is calculated from
  /// episode count + [episodeWeekOffsets], then mapped to cour boundaries:
  ///   - ≤13 weeks → 1 quarter
  ///   - ≤26 weeks → 2 quarters
  ///   - ≤52 weeks → 4 quarters
  ///
  /// For long-running anime (no end episode), falls back to date overlap
  /// estimation.
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

  /// The season quarter this anime starts in.
  /// Returns (year, quarterStartMonth).
  (int, int)? get startQuarter {
    if (firstAirDate == null) return null;
    final month = firstAirDate!.month;
    final year = firstAirDate!.year;
    if (month >= 1 && month <= 3) return (year, 1);
    if (month >= 4 && month <= 6) return (year, 2);
    if (month >= 7 && month <= 9) return (year, 3);
    return (year, 4);
  }

  /// Get the total week offset for a specific episode from [episodeWeekOffsets].
  int weekOffsetFor(int episodeNumber) {
    int offset = 0;
    for (final entry in episodeWeekOffsets.entries) {
      if (entry.key <= episodeNumber) offset += entry.value;
    }
    return offset;
  }

  /// Get the air DateTime for a specific episode (in Japan time).
  /// Returns null if not enough info to calculate.
  DateTime? getEpisodeAirDate(int episodeNumber) {
    if (firstAirDate == null) return null;
    if (effectiveType == AnimeType.allAtOnce) return firstAirDate;
    if (airDayOfWeek == null) return null;

    // Calculate weeks from first air date
    final episodeOffset = episodeNumber - startEpisode;
    if (episodeOffset < 0) return null;

    final totalWeeks = episodeOffset + weekOffsetFor(episodeNumber);
    final baseDate = firstAirDate!.add(Duration(days: totalWeeks * 7));

    // Adjust to the correct day of week
    final currentDow = baseDate.weekday; // 1=Mon..7=Sun
    final diff = airDayOfWeek! - currentDow;
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

  /// Get the calendar date (date-only) for a specific episode.
  /// Unlike [getEpisodeAirDate], this always returns the date corresponding
  /// to [airDayOfWeek], even for late-night times like 24:00 or 25:00.
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

    final currentDow = baseDate.weekday;
    final diff = airDayOfWeek! - currentDow;
    final dayDate = baseDate.add(Duration(days: diff));
    return DateTime(dayDate.year, dayDate.month, dayDate.day);
  }

  /// Get the next unwatched episode number, or null if all watched.
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

  /// Whether all episodes have been watched.
  bool get isCompleted {
    if (endEpisode == null) return false;
    for (int ep = startEpisode; ep <= endEpisode!; ep++) {
      if (episodeStatuses[ep] != EpisodeStatus.watched) return false;
    }
    return true;
  }

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
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? DateTime.now().toUtc(),
      extraJson: extraJson,
    );
  }

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
    createdAt: createdAt,
    modifiedAt: modifiedAt,
    extraJson: extraJson,
  );

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
      createdAt: createdAt,
      modifiedAt: modifiedAt,
      extraJson: _mergeJsonMaps([
        for (final source in sources)
          if (source != null) source.extraJson,
        extraJson,
      ]),
    );
  }

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
    json['createdAt'] = createdAt.toIso8601String();
    json['modifiedAt'] = modifiedAt.toIso8601String();

    return json;
  }

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
      createdAt: DateTime.parse(json['createdAt'] as String),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
      extraJson: extraJson,
    );
  }

  /// Create a new Anime with sensible defaults.
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
      createdAt: now,
      modifiedAt: now,
    );
  }
}

/// Top-level data container for all anime entries.
class AnimeData {
  final List<Anime> animes;
  final Map<String, dynamic> extraJson;

  List<Anime> get animeList => animes;

  const AnimeData({this.animes = const [], this.extraJson = const {}});

  AnimeData withExtraJson(Map<String, dynamic> extraJson) =>
      AnimeData(animes: animes, extraJson: extraJson);

  AnimeData withPreservedUnknownJson(Iterable<AnimeData?> fallbackSources) =>
      withExtraJson(
        _mergeJsonMaps([
          for (final source in fallbackSources)
            if (source != null) source.extraJson,
          extraJson,
        ]),
      );

  Map<String, dynamic> toJson() => {
    ...extraJson,
    'animes': animes.map((a) => a.toJson()).toList(),
  };

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
