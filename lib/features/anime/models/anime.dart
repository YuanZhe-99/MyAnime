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

  /// Purpose: Create a anime instance.
  /// Inputs: `id`, `title`, `titleJa`, `season`, `startEpisode`, `endEpisode`, `manualType`, `airDayOfWeek`, `airTime`, `firstAirDate`, `episodeStatuses`, `coverImage`, `infoUrl`, `watchUrl`, `episodeWeekOffsets`, `notes`, `rating`, `createdAt`, `modifiedAt`, `extraJson`.
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
  /// Inputs: `title`, `titleJa`, `season`, `startEpisode`, `endEpisode`, `clearEndEpisode`, `manualType`, `clearManualType`, `airDayOfWeek`, `clearAirDayOfWeek`, `airTime`, `clearAirTime`, `firstAirDate`, `clearFirstAirDate`, `episodeStatuses`, `coverImage`, `clearCoverImage`, `infoUrl`, `clearInfoUrl`, `watchUrl`, `clearWatchUrl`, `episodeWeekOffsets`, `notes`, `clearNotes`, `rating`, `clearRating`, `modifiedAt`.
  /// Returns: `Anime`.
  /// Side effects: None.
  /// Notes: None.
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

  /// Purpose: Create a new anime record with default values for manual entry.
  /// Inputs: `title`, `titleJa`, `season`, `startEpisode`, `endEpisode`, `manualType`, `airDayOfWeek`, `airTime`, `firstAirDate`, `coverImage`, `infoUrl`, `watchUrl`, `notes`, `rating`.
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
