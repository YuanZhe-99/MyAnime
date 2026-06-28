import '../../features/anime/models/anime.dart';
import '../../l10n/app_localizations.dart';

/// Reason two anime records were considered duplicates.
enum DuplicateReason {
  /// Same record id.
  sameId,

  /// Same non-empty info URL or watch URL.
  sameUrl,

  /// Normalized title/season/air-date match.
  sameTitleSeason,
}

/// A group of anime records considered duplicates of each other.
class DuplicateGroup {
  final List<Anime> animes;
  final DuplicateReason reason;

  /// Purpose: Create a duplicate group instance.
  /// Inputs: `animes`, `reason`.
  /// Returns: A new `DuplicateGroup` instance.
  /// Side effects: None.
  /// Notes: None.
  const DuplicateGroup({required this.animes, required this.reason});

  /// Purpose: Return the localized reason label.
  /// Inputs: `l10n`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String label(AppLocalizations l10n) {
    return switch (reason) {
      DuplicateReason.sameId => l10n.duplicateReasonSameId,
      DuplicateReason.sameUrl => l10n.duplicateReasonSameUrl,
      DuplicateReason.sameTitleSeason => l10n.duplicateReasonSameTitleSeason,
    };
  }
}

/// Result of scanning a list for duplicate groups.
class DuplicateResult {
  final List<DuplicateGroup> groups;

  /// Purpose: Create a duplicate result instance.
  /// Inputs: `groups`.
  /// Returns: A new `DuplicateResult` instance.
  /// Side effects: None.
  /// Notes: None.
  const DuplicateResult({required this.groups});

  /// Purpose: Return whether any duplicate groups were found.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get hasDuplicates => groups.isNotEmpty;

  /// Purpose: Return the total number of anime involved in duplicates.
  /// Inputs: None.
  /// Returns: `int`.
  /// Side effects: None.
  /// Notes: None.
  int get totalDuplicates =>
      groups.fold<int>(0, (sum, g) => sum + g.animes.length);
}

/// Result of parsing a `.myanimeitem` bundle before applying it.
class ImportBundle {
  /// Parsed anime records from the bundle (with new UUIDs already assigned).
  final List<Anime> animes;

  /// Indices into [animes] that conflict with an existing local record.
  final List<int> conflictIndices;

  /// Local record keyed by bundle index for each conflict.
  final Map<int, Anime> localVersions;

  /// Purpose: Create an import bundle instance.
  /// Inputs: `animes`, `conflictIndices`, `localVersions`.
  /// Returns: A new `ImportBundle` instance.
  /// Side effects: None.
  /// Notes: None.
  const ImportBundle({
    required this.animes,
    required this.conflictIndices,
    required this.localVersions,
  });

  /// Purpose: Return whether the bundle has any conflicts.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get hasConflicts => conflictIndices.isNotEmpty;
}

class DuplicateService {
  /// Purpose: Normalize a title for duplicate comparison.
  /// Inputs: `text`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Lowercases, trims, and
  /// strips common punctuation/whitespace so minor formatting differences do
  /// not prevent duplicate detection.
  static String _normalizeTitle(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\u3000·\-\-_:：!！?？.。,，()（）\[\]【】「」『』]'), '')
        .trim();
  }

  /// Purpose: Provide the internal titles match helper for this file.
  /// Inputs: `a`, `b`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Returns true when a
  /// non-empty normalized title or Japanese title overlaps.
  static bool _titlesMatch(Anime a, Anime b) {
    final aTitle = _normalizeTitle(a.displayTitle);
    final bTitle = _normalizeTitle(b.displayTitle);
    if (aTitle.isNotEmpty && aTitle == bTitle) return true;

    final aJa = _normalizeTitle(a.titleJa ?? '');
    final bJa = _normalizeTitle(b.titleJa ?? '');
    if (aJa.isNotEmpty && aJa == bJa) return true;

    // Cross match: one side's main title equals the other's Japanese title.
    if (aTitle.isNotEmpty && aTitle == bJa) return true;
    if (aJa.isNotEmpty && aJa == bTitle) return true;
    return false;
  }

  /// Purpose: Provide the internal dates match helper for this file.
  /// Inputs: `a`, `b`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Treats null dates as a
  /// weak match so undated anime can still group by title+season.
  static bool _datesMatch(Anime a, Anime b) {
    if (a.firstAirDate == null || b.firstAirDate == null) return true;
    return a.firstAirDate!.year == b.firstAirDate!.year &&
        a.firstAirDate!.month == b.firstAirDate!.month &&
        a.firstAirDate!.day == b.firstAirDate!.day;
  }

  /// Purpose: Provide the internal seasons match helper for this file.
  /// Inputs: `a`, `b`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static bool _seasonsMatch(Anime a, Anime b) {
    final aSeason = (a.season).toLowerCase().trim();
    final bSeason = (b.season).toLowerCase().trim();
    if (aSeason.isEmpty || bSeason.isEmpty) return true;
    return aSeason == bSeason;
  }

  /// Purpose: Provide the internal urls match helper for this file.
  /// Inputs: `a`, `b`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Returns true when both
  /// anime share a non-empty info URL or watch URL.
  static bool _urlsMatch(Anime a, Anime b) {
    if (a.infoUrl != null &&
        a.infoUrl!.isNotEmpty &&
        a.infoUrl == b.infoUrl) {
      return true;
    }
    if (a.watchUrl != null &&
        a.watchUrl!.isNotEmpty &&
        a.watchUrl == b.watchUrl) {
      return true;
    }
    return false;
  }

  /// Purpose: Provide the internal is duplicate pair helper for this file.
  /// Inputs: `a`, `b`.
  /// Returns: `DuplicateReason?`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Returns the strongest
  /// duplicate reason or `null` when the pair is not a duplicate.
  static DuplicateReason? _duplicateReason(Anime a, Anime b) {
    if (a.id == b.id) return DuplicateReason.sameId;
    if (_urlsMatch(a, b)) return DuplicateReason.sameUrl;
    if (_titlesMatch(a, b) &&
        _seasonsMatch(a, b) &&
        _datesMatch(a, b)) {
      return DuplicateReason.sameTitleSeason;
    }
    return null;
  }

  /// Purpose: Scan a list of anime and return groups of duplicates.
  /// Inputs: `animes`.
  /// Returns: `DuplicateResult`.
  /// Side effects: None.
  /// Notes: Groups are formed transitively; each anime appears in at most one
  /// group and only groups with two or more members are returned.
  static DuplicateResult detect(List<Anime> animes) {
    // Union-find over indices.
    final parent = List<int>.generate(animes.length, (i) => i);

    int find(int x) {
      while (parent[x] != x) {
        parent[x] = parent[parent[x]];
        x = parent[x];
      }
      return x;
    }

    void union(int a, int b) {
      final ra = find(a);
      final rb = find(b);
      if (ra != rb) parent[ra] = rb;
    }

    for (var i = 0; i < animes.length; i++) {
      for (var j = i + 1; j < animes.length; j++) {
        if (_duplicateReason(animes[i], animes[j]) != null) {
          union(i, j);
        }
      }
    }

    // Collect groups, tracking the strongest reason in each group.
    final groupsMap = <int, List<int>>{};
    for (var i = 0; i < animes.length; i++) {
      final root = find(i);
      groupsMap.putIfAbsent(root, () => []).add(i);
    }

    final groups = <DuplicateGroup>[];
    for (final entry in groupsMap.entries) {
      if (entry.value.length < 2) continue;
      final members = entry.value.map((i) => animes[i]).toList();
      // Determine the strongest reason present in this group.
      DuplicateReason strongest = DuplicateReason.sameTitleSeason;
      for (var i = 0; i < members.length; i++) {
        for (var j = i + 1; j < members.length; j++) {
          final reason = _duplicateReason(members[i], members[j]);
          if (reason == DuplicateReason.sameId) {
            strongest = DuplicateReason.sameId;
          } else if (reason == DuplicateReason.sameUrl &&
              strongest == DuplicateReason.sameTitleSeason) {
            strongest = DuplicateReason.sameUrl;
          }
        }
      }
      groups.add(
        DuplicateGroup(animes: members, reason: strongest),
      );
    }

    // Sort groups by first member's display title for stable UI order.
    groups.sort(
      (a, b) => a.animes.first.displayTitle.compareTo(b.animes.first.displayTitle),
    );
    return DuplicateResult(groups: groups);
  }

  /// Purpose: Find the first local anime that duplicates the candidate.
  /// Inputs: `local`, `candidate`.
  /// Returns: `Anime?`.
  /// Side effects: None.
  /// Notes: Used by import to decide whether an incoming record conflicts.
  static Anime? findConflict(List<Anime> local, Anime candidate) {
    for (final existing in local) {
      if (_duplicateReason(existing, candidate) != null) return existing;
    }
    return null;
  }

  /// Purpose: Provide the internal first non null helper for this file.
  /// Inputs: `values`.
  /// Returns: `T?`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Returns the first
  /// non-null value from the iterable, or null when all values are null.
  static T? _firstNonNull<T>(Iterable<T?> values) {
    for (final v in values) {
      if (v != null) return v;
    }
    return null;
  }

  /// Purpose: Merge a primary anime with fallback records, primary wins conflicts.
  /// Inputs: `primary`, `others`.
  /// Returns: `Anime`.
  /// Side effects: None.
  /// Notes: Missing fields on `primary` are filled from `others`. Episode
  /// statuses merge with watched > skipped > unwatched. Rating sub-scores fill
  /// from fallbacks. Notes are concatenated. Unknown JSON is preserved.
  static Anime merge(Anime primary, List<Anime> others) {
    // Episode statuses: union, watched wins over skipped wins over unwatched.
    final mergedStatuses = Map<int, EpisodeStatus>.of(primary.episodeStatuses);
    for (final other in others) {
      for (final entry in other.episodeStatuses.entries) {
        final current = mergedStatuses[entry.key];
        if (current == null) {
          mergedStatuses[entry.key] = entry.value;
          continue;
        }
        if (entry.value == EpisodeStatus.watched) {
          mergedStatuses[entry.key] = entry.value;
        } else if (current != EpisodeStatus.watched &&
            entry.value == EpisodeStatus.skippedThisWeek) {
          mergedStatuses[entry.key] = entry.value;
        }
      }
    }

    // Week offsets: primary wins, fill missing from others.
    final mergedOffsets = Map<int, int>.of(primary.episodeWeekOffsets);
    for (final other in others) {
      for (final entry in other.episodeWeekOffsets.entries) {
        mergedOffsets.putIfAbsent(entry.key, () => entry.value);
      }
    }

    // Rating: field-by-field, primary wins, fill from fallbacks.
    final pRating = primary.rating;
    final oRatings = others.map((o) => o.rating).toList();
    final allRatings = [pRating, ...oRatings].whereType<AnimeRating>().toList();
    AnimeRating? mergedRating;
    if (pRating != null) {
      mergedRating = AnimeRating(
        overall: pRating.overall ??
            _firstNonNull(allRatings.map((r) => r.overall)),
        visual: pRating.visual ??
            _firstNonNull(allRatings.map((r) => r.visual)),
        story: pRating.story ??
            _firstNonNull(allRatings.map((r) => r.story)),
        character: pRating.character ??
            _firstNonNull(allRatings.map((r) => r.character)),
        music: pRating.music ??
            _firstNonNull(allRatings.map((r) => r.music)),
        enjoyment: pRating.enjoyment ??
            _firstNonNull(allRatings.map((r) => r.enjoyment)),
      );
    } else {
      for (final r in oRatings) {
        if (r != null && r.hasAnyData) {
          mergedRating = r;
          break;
        }
      }
    }
    if (mergedRating != null && mergedRating.hasAnyData) {
      // Preserve unknown rating JSON from all sources.
      final mergedRatingExtra = <String, dynamic>{};
      for (final r in allRatings) {
        mergedRatingExtra.addAll(r.extraJson);
      }
      mergedRating = mergedRating.withExtraJson(mergedRatingExtra);
    } else {
      mergedRating = null;
    }

    // Notes: concatenate non-empty, non-duplicate notes.
    final notesParts = <String>[];
    final seenNotes = <String>{};
    for (final anime in [primary, ...others]) {
      final n = anime.notes?.trim();
      if (n != null && n.isNotEmpty && seenNotes.add(n)) {
        notesParts.add(n);
      }
    }
    final mergedNotes =
        notesParts.isEmpty ? null : notesParts.join('\n');

    // Cover: primary wins, fill from others.
    String? mergedCover = primary.coverImage;
    if (mergedCover == null) {
      for (final other in others) {
        if (other.coverImage != null) {
          mergedCover = other.coverImage;
          break;
        }
      }
    }

    return primary.copyWith(
      endEpisode: primary.endEpisode ??
          _firstNonNull(others.map((o) => o.endEpisode)),
      manualType: primary.manualType ??
          _firstNonNull(others.map((o) => o.manualType)),
      airDayOfWeek: primary.airDayOfWeek ??
          _firstNonNull(others.map((o) => o.airDayOfWeek)),
      airTime: primary.airTime ??
          _firstNonNull(others.map((o) => o.airTime)),
      firstAirDate: primary.firstAirDate ??
          _firstNonNull(others.map((o) => o.firstAirDate)),
      episodeStatuses: mergedStatuses,
      episodeWeekOffsets: mergedOffsets,
      coverImage: mergedCover,
      infoUrl: primary.infoUrl ??
          _firstNonNull(others.map((o) => o.infoUrl)),
      watchUrl: primary.watchUrl ??
          _firstNonNull(others.map((o) => o.watchUrl)),
      notes: mergedNotes,
      rating: mergedRating,
      modifiedAt: DateTime.now().toUtc(),
    ).withPreservedUnknownJson([primary, ...others]);
  }
}
