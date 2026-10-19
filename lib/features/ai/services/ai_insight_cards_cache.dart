import 'package:myapps_ai/myapps_ai.dart' show AiInsightEntry;
import 'dart:convert';
import 'dart:io';

import 'package:myapps_data/myapps_data.dart'
    show AtomicWriteQueue, atomicWriteString;
import 'package:path/path.dart' as p;

import '../../anime/services/anime_storage.dart';
import 'insight_prompts.dart';

export 'package:myapps_ai/myapps_ai.dart' show AiInsightEntry, AiInsightStatus;

/// Every cached card, keyed by module.
class AiInsightCards {
  /// The entries.
  final Map<InsightModule, AiInsightEntry> entries;

  /// Purpose: Create a cache value.
  /// Inputs: `entries`.
  /// Returns: A new `AiInsightCards`.
  /// Side effects: None.
  /// Notes: Copies the map.
  AiInsightCards([Map<InsightModule, AiInsightEntry>? entries])
    : entries = {...?entries};

  /// Purpose: Serialize the cache file.
  /// Inputs: None.
  /// Returns: A JSON map with sorted module keys.
  /// Side effects: None.
  /// Notes: None.
  Map<String, dynamic> toJson() {
    final keys = entries.keys.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return {
      'version': 1,
      'insights': {for (final k in keys) k.name: entries[k]!.toJson()},
    };
  }

  /// Purpose: Parse the cache file.
  /// Inputs: `json`.
  /// Returns: `AiInsightCards` — empty when malformed.
  /// Side effects: None.
  /// Notes: Unknown modules and malformed entries are dropped.
  factory AiInsightCards.fromJson(Object? json) {
    final out = <InsightModule, AiInsightEntry>{};
    if (json is Map && json['insights'] is Map) {
      final map = json['insights'] as Map;
      for (final module in InsightModule.values) {
        final entry = AiInsightEntry.fromJson(map[module.name]);
        if (entry != null) out[module] = entry;
      }
    }
    return AiInsightCards(out);
  }
}

/// The device-local cache of the Statistics insight cards,
/// `ai_insight_cards.json` in the app data folder (1.9.1).
///
/// A separate file from `ai_insights.json`: that file's `AiInsights` keeps
/// only AI categories and drops any other key on save, so sharing it would
/// let the category classifier erase card entries.
///
/// Deliberately **not** a registered data module: it is never synced, never
/// in a backup bundle or ZIP export, and has no preservation schema. Unlike the
/// data files, an unreadable cache reads as empty — it is rebuildable, and
/// losing it only costs one regeneration per card.
class AiInsightCardsCache {
  /// Purpose: Prevent instantiation; the cache is static.
  /// Inputs: None.
  /// Returns: Never used.
  /// Side effects: None.
  /// Notes: None.
  AiInsightCardsCache._();

  /// The cache file name.
  static const fileName = 'ai_insight_cards.json';

  static final _queue = AtomicWriteQueue();

  /// Purpose: Resolve the cache file.
  /// Inputs: None.
  /// Returns: `Future<File>` under `AnimeStorage.getAppDir()`.
  /// Side effects: May create the app directory.
  /// Notes: Goes through the storage hub so custom paths work.
  static Future<File> file() async =>
      File(p.join((await AnimeStorage.getAppDir()).path, fileName));

  /// Purpose: Read the cache.
  /// Inputs: None.
  /// Returns: `Future<AiInsightCards>` — empty when absent or unreadable.
  /// Side effects: Reads local storage.
  /// Notes: Never throws; see the class note on why.
  static Future<AiInsightCards> load() async {
    try {
      final f = await file();
      if (!await f.exists()) return AiInsightCards();
      return AiInsightCards.fromJson(jsonDecode(await f.readAsString()));
    } catch (_) {
      return AiInsightCards();
    }
  }

  /// Purpose: Write the cache atomically.
  /// Inputs: `insights`.
  /// Returns: `Future<void>`.
  /// Side effects: Replaces `ai_insight_cards.json` through a serialized queue.
  /// Notes: Never notifies auto-sync.
  static Future<void> save(AiInsightCards insights) => _queue.enqueue(() async {
    await atomicWriteString(
      await file(),
      const JsonEncoder.withIndent('  ').convert(insights.toJson()),
    );
  });

  /// Purpose: Delete the cache.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Removes `ai_insight_cards.json` if present.
  /// Notes: Serialized with writes.
  static Future<void> clear() => _queue.enqueue(() async {
    final f = await file();
    if (await f.exists()) await f.delete();
  });
}
