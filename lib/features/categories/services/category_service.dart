import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleListener, AppLifecycleState;

import '../../ai/services/ai_insights_cache.dart';
import '../../ai/services/genai_backend.dart';
import '../../ai/services/on_device_ai_service.dart';
import '../../ai/services/prompt_templates.dart';
import '../../anime/models/anime.dart';
import '../../anime/models/anime_category.dart';
import '../../anime/services/anime_storage.dart';
import '../../anime/services/series_service.dart';

/// Which of the three sources produced a record's effective categories.
enum CategoryOrigin {
  /// The user's own `Anime.categories`.
  user,

  /// Mapped from the source databases' genres.
  mapped,

  /// Suggested by the on-device model.
  ai,
}

/// A record's categories as the app shows them.
@immutable
class EffectiveCategories {
  /// Category ids, known ones only, in taxonomy order for mapped and AI
  /// results and in the user's order for their own.
  final List<String> ids;

  /// Where they came from, or null when there are none.
  final CategoryOrigin? origin;

  /// Purpose: Create the effective categories.
  /// Inputs: `ids`, `origin`.
  /// Returns: A new `EffectiveCategories`.
  /// Side effects: None.
  /// Notes: None.
  const EffectiveCategories(this.ids, this.origin);

  /// No categories.
  static const empty = EffectiveCategories([], null);
}

/// Purpose: Resolve a record's categories.
/// Inputs: `anime`; `insights` — the AI cache, or null when AI is off.
/// Returns: `EffectiveCategories`.
/// Side effects: None.
/// Notes: The order is fixed: the user's `categories` whenever the field is
/// present, even empty; else the genre mapping; else a cached AI result whose
/// fingerprint is current. Unknown ids in the user's list are kept on the
/// record but not shown.
EffectiveCategories resolveCategories(Anime anime, {AiInsights? insights}) {
  final own = anime.categories;
  if (own != null) {
    return EffectiveCategories([
      for (final id in own)
        if (animeCategoryIds.contains(id)) id,
    ], CategoryOrigin.user);
  }
  final mapped = mapGenresToCategories(anime.externalMeta?.genres ?? const []);
  if (mapped.isNotEmpty) {
    return EffectiveCategories(mapped, CategoryOrigin.mapped);
  }
  final entry = insights?.categories[anime.id];
  // An entry whose inputs have changed since it was generated is stale: it is
  // hidden until the classifier replaces it.
  if (entry != null &&
      entry.status == AiCategoryStatus.ok &&
      entry.fingerprint ==
          classificationFingerprint(
            classificationInputOf(anime),
            entry.model ?? '',
          )) {
    final ids = [
      for (final c in animeCategories)
        if (entry.ids.contains(c.id)) c.id,
    ];
    if (ids.isNotEmpty) return EffectiveCategories(ids, CategoryOrigin.ai);
  }
  return EffectiveCategories.empty;
}

/// Purpose: Collect what the model may know about a work.
/// Inputs: `anime`.
/// Returns: `ClassificationInput`.
/// Side effects: None.
/// Notes: Titles, format, year, length type, episode count, studios and raw
/// genres only — never notes, ratings or viewing progress.
ClassificationInput classificationInputOf(Anime anime) {
  final meta = anime.externalMeta;
  return ClassificationInput(
    titles: seriesTitlesOf(anime).take(5).toList(),
    format: meta?.format,
    year: anime.firstAirDate?.year,
    type: anime.effectiveType.name,
    episodes: anime.totalEpisodes,
    studios: meta?.studios ?? const [],
    genres: meta?.genres ?? const [],
  );
}

/// Purpose: Name the model that would answer, for fingerprints and the cache.
/// Inputs: `report`.
/// Returns: `String` — e.g. `stable/full · nano-v3`, or `apple`.
/// Side effects: None.
/// Notes: A different model re-queues classification, because models change
/// with OS and AICore updates.
String modelIdentityOf(GenAiStatusReport report) {
  final parts = [?report.variant, ?report.baseModelName];
  return parts.isEmpty ? 'apple' : parts.join(' · ');
}

/// Purpose: Fingerprint one classification request.
/// Inputs: `input`, `model`.
/// Returns: `String` — hex SHA-256.
/// Side effects: None.
/// Notes: Covers the inputs, the taxonomy version, the prompt version and the
/// model identity; a change to any of them re-queues the record.
String classificationFingerprint(ClassificationInput input, String model) {
  final text = [
    input.canonical(),
    'taxonomy:$categoryTaxonomyVersion',
    'prompt:$classificationPromptVersion',
    'model:$model',
  ].join('\n');
  return sha256.convert(utf8.encode(text)).toString();
}

/// Purpose: Say whether a record needs an AI classification.
/// Inputs: `anime`, `insights`, `model`.
/// Returns: `bool` — true only when the user has no override, the genres map
/// to nothing, and no cache entry matches the current fingerprint.
/// Side effects: None.
/// Notes: A `skipped` entry with the current fingerprint is not retried.
bool needsClassification(Anime anime, AiInsights insights, String model) {
  if (anime.categories != null) return false;
  if (mapGenresToCategories(
    anime.externalMeta?.genres ?? const [],
  ).isNotEmpty) {
    return false;
  }
  final fp = classificationFingerprint(classificationInputOf(anime), model);
  return insights.categories[anime.id]?.fingerprint != fp;
}

/// Fills category gaps with the on-device model: a trickle of at most
/// [sessionLimit] records per foreground session while the app is resumed,
/// plus "Categorise now" from Settings. Results go to `ai_insights.json` only.
class CategoryClassifier extends ChangeNotifier {
  /// Purpose: Create the classifier.
  /// Inputs: `ai`; `loadLibrary`, `loadInsights`, `saveInsights` — injectable
  /// for tests; `enabled` — whether automatic categories are on.
  /// Returns: A new `CategoryClassifier`.
  /// Side effects: None.
  /// Notes: Does nothing until [enabled] is set and the model is available.
  CategoryClassifier({
    OnDeviceAiService? ai,
    Future<List<Anime>> Function()? loadLibrary,
    Future<AiInsights> Function(Set<String> liveIds)? loadInsights,
    Future<void> Function(AiInsights)? saveInsights,
  }) : _ai = ai,
       _loadLibrary =
           loadLibrary ?? (() async => (await AnimeStorage.load()).animes),
       _loadInsights =
           loadInsights ?? ((ids) => AiInsightsCache.load(liveIds: ids)),
       _saveInsights = saveInsights ?? AiInsightsCache.save;

  /// The app-wide instance.
  static CategoryClassifier instance = CategoryClassifier();

  /// Purpose: Replace the singleton for a test.
  /// Inputs: `classifier`.
  /// Returns: None.
  /// Side effects: Points [instance] at another classifier.
  /// Notes: Test-only.
  @visibleForTesting
  static void setInstanceForTest(CategoryClassifier classifier) =>
      instance = classifier;

  /// The most records classified automatically per foreground session.
  static const sessionLimit = 20;

  final OnDeviceAiService? _ai;
  final Future<List<Anime>> Function() _loadLibrary;
  final Future<AiInsights> Function(Set<String> liveIds) _loadInsights;
  final Future<void> Function(AiInsights) _saveInsights;

  /// Whether automatic categories are on; set by `AppSettingsNotifier`.
  bool enabled = false;

  int _thisSession = 0;
  bool _running = false;
  AppLifecycleListener? _lifecycle;

  /// Pending and total counts from the last pass, for "N of M".
  int pending = 0;

  /// Records that the model could classify at all (no user override, no
  /// genre mapping).
  int candidates = 0;

  /// Whether a pass is running.
  bool get running => _running;

  OnDeviceAiService get _service => _ai ?? OnDeviceAiService.instance;

  /// Purpose: Start the per-session trickle on each resume.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Registers an `AppLifecycleListener` once.
  /// Notes: Called from `main`. The session counter resets on every resume.
  void start() {
    _lifecycle ??= AppLifecycleListener(
      onStateChange: (state) {
        if (state == AppLifecycleState.resumed) {
          _thisSession = 0;
          unawaited(trickle());
        }
      },
    );
  }

  /// Purpose: Classify a few records in the background.
  /// Inputs: None.
  /// Returns: `Future<int>` — how many were classified.
  /// Side effects: Runs the model; writes `ai_insights.json`.
  /// Notes: Stops at [sessionLimit] per foreground session.
  Future<int> trickle() =>
      _run(sessionLimit - _thisSession, countSession: true);

  /// Purpose: Classify every pending record now ("Categorise now").
  /// Inputs: None.
  /// Returns: `Future<int>` — how many were classified.
  /// Side effects: Runs the model; writes `ai_insights.json`.
  /// Notes: Not counted against the session trickle; stops on the first
  /// failure that is not a per-record refusal.
  Future<int> classifyAll() => _run(1 << 30, countSession: false);

  /// Purpose: Refresh the pending counts without running the model.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Reads the library and the cache; notifies listeners.
  /// Notes: Drives the "N of M" count in Settings.
  Future<void> refreshCounts() async {
    final library = await _loadLibrary();
    final insights = await _loadInsights({for (final a in library) a.id});
    final model = modelIdentityOf(_service.report);
    candidates = 0;
    pending = 0;
    for (final a in library) {
      if (a.categories != null) continue;
      if (mapGenresToCategories(
        a.externalMeta?.genres ?? const [],
      ).isNotEmpty) {
        continue;
      }
      candidates++;
      if (needsClassification(a, insights, model)) pending++;
    }
    notifyListeners();
  }

  /// Purpose: Run one classification pass.
  /// Inputs: `budget` — the most records to classify; `countSession`.
  /// Returns: `Future<int>` — how many were classified.
  /// Side effects: Runs the model; writes the cache after every record.
  /// Notes: Internal helper used within this file only. Refused unless
  /// automatic categories are on and the model can generate. Guardrail and
  /// language refusals are cached as `skipped`; any other failure stops the
  /// pass, leaving the record for next time.
  Future<int> _run(int budget, {required bool countSession}) async {
    final ai = _service;
    if (!enabled || !ai.canGenerate || _running || budget <= 0) return 0;
    _running = true;
    notifyListeners();
    var done = 0;
    try {
      final library = await _loadLibrary();
      final insights = await _loadInsights({for (final a in library) a.id});
      final model = modelIdentityOf(ai.report);
      final queue = [
        for (final a in library)
          if (needsClassification(a, insights, model)) a,
      ];
      if (queue.isNotEmpty) await ai.prewarm();
      for (final anime in queue) {
        if (done >= budget || !enabled || !ai.enabled) break;
        final input = classificationInputOf(anime);
        final fp = classificationFingerprint(input, model);
        AiCategoryEntry entry;
        try {
          final chosen = await ai.choose(
            instructions: classificationInstructions(),
            prompt: classificationPrompt(input),
            options: [...animeCategoryIds, 'none'],
            maxItems: 3,
          );
          final ids = [
            for (final c in animeCategories)
              if (chosen.contains(c.id)) c.id,
          ].take(3).toList();
          entry = AiCategoryEntry(
            fingerprint: fp,
            ids: ids,
            status: ids.isEmpty ? AiCategoryStatus.none : AiCategoryStatus.ok,
            model: model,
            generatedAt: DateTime.now().toUtc(),
          );
        } on GenAiException catch (e) {
          if (e.failure != GenAiFailure.guardrail &&
              e.failure != GenAiFailure.unsupportedLanguage) {
            break;
          }
          entry = AiCategoryEntry(
            fingerprint: fp,
            ids: const [],
            status: AiCategoryStatus.skipped,
            model: model,
            generatedAt: DateTime.now().toUtc(),
          );
        }
        insights.categories[anime.id] = entry;
        await _saveInsights(insights);
        done++;
        if (countSession) _thisSession++;
      }
    } finally {
      _running = false;
      notifyListeners();
    }
    return done;
  }

  /// Purpose: Release the lifecycle listener.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Disposes the listener.
  /// Notes: Flutter `ChangeNotifier` override.
  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }
}
