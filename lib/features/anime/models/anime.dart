import 'package:uuid/uuid.dart';



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
enum EpisodeStatus {
  unwatched,
  watched,
  skippedThisWeek,
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

  final DateTime createdAt;
  final DateTime modifiedAt;

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
    required this.createdAt,
    required this.modifiedAt,
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
  bool airsInQuarter(int year, int quarter) {
    if (firstAirDate == null) return false;

    final quarterStartMonth = (quarter - 1) * 3 + 1;
    final quarterStart = DateTime(year, quarterStartMonth);
    final quarterEnd = DateTime(
      quarterStartMonth == 10 ? year + 1 : year,
      quarterStartMonth == 10 ? 1 : quarterStartMonth + 3,
    );

    // Calculate approximate end date based on type
    // First episode airs on firstAirDate, last episode (ep-1) weeks later
    final ep = totalEpisodes;
    final weeksToLastEp = ep != null ? (ep - 1) : 51;
    final estimatedEnd =
        firstAirDate!.add(Duration(days: weeksToLastEp * 7));

    // Anime airs in this quarter if its run overlaps with the quarter
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
      return DateTime(firstAirDate!.year, firstAirDate!.month, firstAirDate!.day);
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
      airDayOfWeek:
          clearAirDayOfWeek ? null : (airDayOfWeek ?? this.airDayOfWeek),
      airTime: clearAirTime ? null : (airTime ?? this.airTime),
      firstAirDate:
          clearFirstAirDate ? null : (firstAirDate ?? this.firstAirDate),
      episodeStatuses: episodeStatuses ?? this.episodeStatuses,
      coverImage: clearCoverImage ? null : (coverImage ?? this.coverImage),
      infoUrl: clearInfoUrl ? null : (infoUrl ?? this.infoUrl),
      watchUrl: clearWatchUrl ? null : (watchUrl ?? this.watchUrl),
      episodeWeekOffsets: episodeWeekOffsets ?? this.episodeWeekOffsets,
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (title != null) 'title': title,
        if (titleJa != null) 'titleJa': titleJa,
        'season': season,
        'startEpisode': startEpisode,
        if (endEpisode != null) 'endEpisode': endEpisode,
        if (manualType != null) 'manualType': manualType!.name,
        if (airDayOfWeek != null) 'airDayOfWeek': airDayOfWeek,
        if (airTime != null) 'airTime': airTime,
        if (firstAirDate != null)
          'firstAirDate': firstAirDate!.toIso8601String(),
        'episodeStatuses': episodeStatuses
            .map((k, v) => MapEntry(k.toString(), v.name)),
        if (coverImage != null) 'coverImage': coverImage,
        if (infoUrl != null) 'infoUrl': infoUrl,
        if (watchUrl != null) 'watchUrl': watchUrl,
        if (episodeWeekOffsets.isNotEmpty)
          'episodeWeekOffsets': episodeWeekOffsets
              .map((k, v) => MapEntry(k.toString(), v)),
        if (notes != null) 'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
      };

  factory Anime.fromJson(Map<String, dynamic> json) {
    final statuses = <int, EpisodeStatus>{};
    final rawStatuses = json['episodeStatuses'] as Map<String, dynamic>?;
    if (rawStatuses != null) {
      for (final entry in rawStatuses.entries) {
        final ep = int.tryParse(entry.key);
        if (ep != null) {
          statuses[ep] = EpisodeStatus.values.firstWhere(
            (e) => e.name == entry.value,
            orElse: () => EpisodeStatus.unwatched,
          );
        }
      }
    }

    final weekOffsets = <int, int>{};
    final rawOffsets = json['episodeWeekOffsets'] as Map<String, dynamic>?;
    if (rawOffsets != null) {
      for (final entry in rawOffsets.entries) {
        final ep = int.tryParse(entry.key);
        final val = entry.value as int?;
        if (ep != null && val != null) {
          weekOffsets[ep] = val;
        }
      }
    }

    return Anime(
      id: json['id'] as String,
      title: json['title'] as String?,
      titleJa: json['titleJa'] as String?,
      season: json['season'] as String? ?? 'Season 1',
      startEpisode: json['startEpisode'] as int? ?? 1,
      endEpisode: json['endEpisode'] as int?,
      manualType: json['manualType'] != null
          ? AnimeType.values.firstWhere(
              (e) => e.name == json['manualType'],
              orElse: () => AnimeType.singleCour,
            )
          : null,
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
      createdAt: DateTime.parse(json['createdAt'] as String),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
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
      createdAt: now,
      modifiedAt: now,
    );
  }
}

/// Top-level data container for all anime entries.
class AnimeData {
  final List<Anime> animes;

  List<Anime> get animeList => animes;

  const AnimeData({this.animes = const []});

  Map<String, dynamic> toJson() => {
        'animes': animes.map((a) => a.toJson()).toList(),
      };

  factory AnimeData.fromJson(Map<String, dynamic> json) {
    final list = (json['animes'] as List<dynamic>?)
            ?.map((e) => Anime.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return AnimeData(animes: list);
  }
}
