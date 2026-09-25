import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../anime/services/anime_storage.dart';

/// How an AI classification ended.
enum AiCategoryStatus {
  /// The model chose one or more categories.
  ok,

  /// The model answered NONE.
  none,

  /// A guardrail or an unsupported language refused the request; not retried
  /// until the fingerprint changes.
  skipped,
}

/// One cached AI classification.
class AiCategoryEntry {
  /// Fingerprint of the inputs, taxonomy version, prompt version and model.
  final String fingerprint;

  /// Chosen category ids, already validated.
  final List<String> ids;

  /// How the classification ended.
  final AiCategoryStatus status;

  /// The model that answered, e.g. `stable/full · nano-v3`.
  final String? model;

  /// When it was generated (UTC).
  final DateTime generatedAt;

  /// Purpose: Create a cache entry.
  /// Inputs: `fingerprint`, `ids`, `status`, `model`, `generatedAt`.
  /// Returns: A new `AiCategoryEntry`.
  /// Side effects: None.
  /// Notes: None.
  const AiCategoryEntry({
    required this.fingerprint,
    required this.ids,
    required this.status,
    this.model,
    required this.generatedAt,
  });

  /// Purpose: Serialize the entry.
  /// Inputs: None.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: None.
  Map<String, dynamic> toJson() => {
    'fingerprint': fingerprint,
    'ids': ids,
    'status': status.name,
    'model': ?model,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
  };

  /// Purpose: Read an entry tolerantly.
  /// Inputs: `json`.
  /// Returns: `AiCategoryEntry?` — null when unusable.
  /// Side effects: None.
  /// Notes: A cache is rebuildable, so anything malformed is dropped rather
  /// than preserved.
  static AiCategoryEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final fingerprint = json['fingerprint'];
    final status = AiCategoryStatus.values
        .where((s) => s.name == json['status'])
        .firstOrNull;
    final at = json['generatedAt'] is String
        ? DateTime.tryParse(json['generatedAt'] as String)
        : null;
    if (fingerprint is! String || status == null || at == null) return null;
    return AiCategoryEntry(
      fingerprint: fingerprint,
      ids: [
        if (json['ids'] is List)
          for (final i in json['ids'] as List)
            if (i is String) i,
      ],
      status: status,
      model: json['model'] as String?,
      generatedAt: at.toUtc(),
    );
  }
}

/// The contents of `ai_insights.json`.
class AiInsights {
  /// Cached classifications by anime id.
  final Map<String, AiCategoryEntry> categories;

  /// Anime ids marked "Not interested" on this device in 1.6.0-1.6.1. Since
  /// 1.6.2 the trash is the synced `recommendations.json`; this set is only
  /// read by `RecommendationStore.migrateFromInsights` and then left empty.
  final Set<String> hiddenRecommendations;

  /// Purpose: Create the insights store.
  /// Inputs: `categories`, `hiddenRecommendations`.
  /// Returns: A new `AiInsights`.
  /// Side effects: None.
  /// Notes: None.
  AiInsights({
    Map<String, AiCategoryEntry>? categories,
    Set<String>? hiddenRecommendations,
  }) : categories = categories ?? {},
       hiddenRecommendations = hiddenRecommendations ?? {};

  /// Purpose: Serialize the store.
  /// Inputs: None.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: Keys are sorted so an unchanged store writes identical bytes.
  Map<String, dynamic> toJson() => {
    'version': 1,
    'categories': {
      for (final id in categories.keys.toList()..sort())
        id: categories[id]!.toJson(),
    },
    'hiddenRecommendations': hiddenRecommendations.toList()..sort(),
  };

  /// Purpose: Read the store tolerantly.
  /// Inputs: `json`.
  /// Returns: `AiInsights`.
  /// Side effects: None.
  /// Notes: Malformed parts are dropped.
  factory AiInsights.fromJson(Object? json) {
    if (json is! Map) return AiInsights();
    final raw = json['categories'];
    final hidden = json['hiddenRecommendations'];
    return AiInsights(
      categories: {
        if (raw is Map)
          for (final e in raw.entries)
            if (e.key is String && AiCategoryEntry.fromJson(e.value) != null)
              e.key as String: AiCategoryEntry.fromJson(e.value)!,
      },
      hiddenRecommendations: {
        if (hidden is List)
          for (final h in hidden)
            if (h is String) h,
      },
    );
  }
}

/// Owns `ai_insights.json`, the per-device cache of generated results.
///
/// In the style of `MetadataCache`: tolerant load, atomic pretty-printed
/// writes, no `AutoSyncService.notifySaved`, and no registration in
/// `lib/app/data_modules.dart` — so it is neither synced nor backed up —
/// while still living under `AnimeStorage.getAppDir()` and moving with a
/// storage-path change.
class AiInsightsCache {
  /// Purpose: Prevent direct instantiation and expose only static members.
  /// Inputs: None.
  /// Returns: A new `AiInsightsCache._` instance.
  /// Side effects: None.
  /// Notes: None.
  const AiInsightsCache._();

  /// The cache file's name under the app directory.
  static const fileName = 'ai_insights.json';

  /// Purpose: Resolve the cache file.
  /// Inputs: None.
  /// Returns: `Future<File>`.
  /// Side effects: May create the app directory.
  /// Notes: Internal helper used within this file only.
  static Future<File> _file() async {
    final dir = await AnimeStorage.getAppDir();
    return File(p.join(dir.path, fileName));
  }

  /// Purpose: Load the cache, pruning entries for deleted records.
  /// Inputs: `liveIds` — ids of the records that still exist, or null to skip
  /// pruning.
  /// Returns: `Future<AiInsights>` — empty when absent or unreadable.
  /// Side effects: Reads the cache file.
  /// Notes: Pruning happens in memory; the next save writes it out.
  static Future<AiInsights> load({Set<String>? liveIds}) async {
    try {
      final file = await _file();
      if (!await file.exists()) return AiInsights();
      final insights = AiInsights.fromJson(
        jsonDecode(await file.readAsString()),
      );
      if (liveIds != null) {
        insights.categories.removeWhere((id, _) => !liveIds.contains(id));
        insights.hiddenRecommendations.removeWhere(
          (id) => !liveIds.contains(id),
        );
      }
      return insights;
    } catch (_) {
      return AiInsights();
    }
  }

  /// Purpose: Save the cache.
  /// Inputs: `insights`.
  /// Returns: None.
  /// Side effects: Writes the cache file atomically (tmp then rename).
  /// Notes: Never notifies auto-sync.
  static Future<void> save(AiInsights insights) async {
    final file = await _file();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(insights.toJson()),
      flush: true,
    );
    await tmp.rename(file.path);
  }
}
