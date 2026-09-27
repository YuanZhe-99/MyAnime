/// Anime1's public directory and user-owned episode corrections.
library;

/// Purpose: Decode an optional object without losing unrecognized keys.
/// Inputs: `value` from JSON.
/// Returns: A string-keyed map.
/// Side effects: None.
/// Notes: Invalid containers are treated as absent by callers.
Map<String, dynamic> episodeJsonMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

class AnimeEpisodePage {
  final String url;
  final String title;
  final String label;
  final String group;
  final Map<String, dynamic> extraJson;

  /// Purpose: Describe one real episode page without coercing special labels.
  /// Inputs: Page URL, title, original label and season-title group.
  /// Returns: An immutable page descriptor.
  /// Side effects: None.
  /// Notes: Only strictly positive integer labels are regular episodes.
  const AnimeEpisodePage({
    required this.url,
    required this.title,
    required this.label,
    required this.group,
    this.extraJson = const {},
  });

  /// Purpose: Distinguish numbered regular episodes from extras.
  /// Inputs: None.
  /// Returns: A positive episode number or null.
  /// Side effects: None.
  /// Notes: Fractional labels are never truncated.
  int? get number =>
      RegExp(r'^\d+$').hasMatch(label) && (int.tryParse(label) ?? 0) > 0
      ? int.parse(label)
      : null;

  /// Purpose: Serialize a public episode page, preserving unknown fields.
  /// Inputs: None.
  /// Returns: JSON object.
  /// Side effects: None.
  /// Notes: Contains page addresses, never media credentials.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'url': url,
    'title': title,
    'label': label,
    'group': group,
  };

  /// Purpose: Read a cached episode page.
  /// Inputs: JSON object.
  /// Returns: Page descriptor.
  /// Side effects: None.
  /// Notes: Original object is retained for forward compatibility.
  factory AnimeEpisodePage.fromJson(Map<String, dynamic> json) =>
      AnimeEpisodePage(
        url: json['url'] as String? ?? '',
        title: json['title'] as String? ?? '',
        label: json['label'] as String? ?? '',
        group: json['group'] as String? ?? '',
        extraJson: json,
      );
}

class AnimeEpisodeCatalog {
  final String sourceUrl;
  final String categoryUrl;
  final String title;
  final int? catId;
  final String? indexTitle;
  final String? indexEpisodes;
  final DateTime checkedAt;
  final bool complete;
  final List<AnimeEpisodePage> pages;
  final Map<String, dynamic> extraJson;

  /// Purpose: Hold a public directory snapshot independently of user choices.
  /// Inputs: Source, category, index evidence, completeness and pages.
  /// Returns: Directory snapshot.
  /// Side effects: None.
  /// Notes: Completeness describes pagination, not whether the site has missing episodes.
  const AnimeEpisodeCatalog({
    required this.sourceUrl,
    required this.categoryUrl,
    required this.title,
    required this.checkedAt,
    required this.complete,
    required this.pages,
    this.catId,
    this.indexTitle,
    this.indexEpisodes,
    this.extraJson = const {},
  });

  /// Purpose: Preserve newer unknown directory fields during a public metadata refresh.
  /// Inputs: Previous snapshot from the same source, if any.
  /// Returns: This snapshot with unknown fields retained by page URL.
  /// Side effects: None.
  /// Notes: Known fields and the current page set always come from this snapshot.
  AnimeEpisodeCatalog preservingUnknownFrom(AnimeEpisodeCatalog? previous) {
    if (previous == null || previous.sourceUrl != sourceUrl) return this;
    final oldPages = {for (final p in previous.pages) p.url: p};
    return AnimeEpisodeCatalog.fromJson({
      ...previous.extraJson,
      ...toJson(),
      'pages': [
        for (final page in pages)
          {...?oldPages[page.url]?.extraJson, ...page.toJson()},
      ],
    });
  }

  /// Purpose: Serialize the directory for external metadata storage.
  /// Inputs: None.
  /// Returns: JSON object.
  /// Side effects: None.
  /// Notes: All timestamps are UTC.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'sourceUrl': sourceUrl,
    'categoryUrl': categoryUrl,
    'title': title,
    'catId': catId,
    'indexTitle': indexTitle,
    'indexEpisodes': indexEpisodes,
    'checkedAt': checkedAt.toUtc().toIso8601String(),
    'complete': complete,
    'pages': pages.map((p) => p.toJson()).toList(),
  };

  /// Purpose: Read a directory snapshot from stored metadata.
  /// Inputs: JSON object.
  /// Returns: Directory snapshot.
  /// Side effects: None.
  /// Notes: Missing timestamps expire immediately.
  factory AnimeEpisodeCatalog.fromJson(Map<String, dynamic> json) =>
      AnimeEpisodeCatalog(
        sourceUrl: json['sourceUrl'] as String? ?? '',
        categoryUrl: json['categoryUrl'] as String? ?? '',
        title: json['title'] as String? ?? '',
        catId: json['catId'] as int?,
        indexTitle: json['indexTitle'] as String?,
        indexEpisodes: json['indexEpisodes'] as String?,
        checkedAt:
            DateTime.tryParse(json['checkedAt'] as String? ?? '')?.toUtc() ??
            DateTime.utc(1970),
        complete: json['complete'] == true,
        pages: [
          for (final p in (json['pages'] as List? ?? []))
            if (p is Map) AnimeEpisodePage.fromJson(episodeJsonMap(p)),
        ],
        extraJson: json,
      );
}

class AnimeEpisodeMapping {
  final String sourceUrl;
  final String? group;
  final int? first;
  final int? last;
  final Map<int, String> overrides;
  final Map<String, dynamic> extraJson;

  /// Purpose: Store user-confirmed season boundaries and individual choices.
  /// Inputs: Source, optional title group, inclusive site bounds and local page overrides.
  /// Returns: User mapping configuration.
  /// Side effects: None.
  /// Notes: An empty override explicitly leaves that local episode unmapped.
  const AnimeEpisodeMapping({
    required this.sourceUrl,
    this.group,
    this.first,
    this.last,
    this.overrides = const {},
    this.extraJson = const {},
  });

  /// Purpose: Serialize user choices for ordinary record sync.
  /// Inputs: None.
  /// Returns: JSON object.
  /// Side effects: None.
  /// Notes: Reset writes null optional fields rather than resurrecting old values.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'sourceUrl': sourceUrl,
    'group': group,
    'first': first,
    'last': last,
    'overrides': {for (final e in overrides.entries) '${e.key}': e.value},
  };

  /// Purpose: Read saved user choices.
  /// Inputs: JSON object.
  /// Returns: Mapping configuration.
  /// Side effects: None.
  /// Notes: Unknown outer fields survive editing.
  factory AnimeEpisodeMapping.fromJson(Map<String, dynamic> json) =>
      AnimeEpisodeMapping(
        sourceUrl: json['sourceUrl'] as String? ?? '',
        group: json['group'] as String?,
        first: json['first'] as int?,
        last: json['last'] as int?,
        overrides: {
          for (final e in episodeJsonMap(json['overrides']).entries)
            if (int.tryParse(e.key) != null && e.value is String)
              int.parse(e.key): e.value as String,
        },
        extraJson: json,
      );
}
