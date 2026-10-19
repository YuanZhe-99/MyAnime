import 'dart:async';
import 'package:myapps_ai/myapps_ai.dart'
    show generateWithFallback, AiInsightCoordinator, AiInsightState;
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../categories/services/category_service.dart' show modelIdentityOf;
import 'ai_insight_cards_cache.dart';
import 'insight_language.dart';
import 'insight_prompts.dart';
import 'on_device_ai_service.dart';

export 'package:myapps_ai/myapps_ai.dart' show AiInsightPhase, AiInsightState;

/// One card's request: its facts and the language to answer in.
class AiInsightRequest {
  /// The app-computed facts.
  final InsightFacts facts;

  /// The reply language.
  final InsightLanguage language;

  /// Local time the facts were computed for; its date is fingerprinted.
  final DateTime now;

  /// A plainer second try, or null: sent once when the model declines
  /// [facts] or returns nothing usable for them. The statistics cards pass a
  /// version without titles. Not part of the fingerprint.
  final InsightFacts? fallbackFacts;

  /// Purpose: Create a request.
  /// Inputs: see fields.
  /// Returns: A new `AiInsightRequest`.
  /// Side effects: None.
  /// Notes: `fallbackFacts` must carry the same module and the same slot
  /// ids in the same order as `facts`, so the card's sections still apply.
  const AiInsightRequest({
    required this.facts,
    required this.language,
    required this.now,
    this.fallbackFacts,
  });
}

/// Purpose: Fingerprint one card request.
/// Inputs: `request`, `model` — from [modelIdentityOf].
/// Returns: `String` — hex SHA-256.
/// Side effects: None.
/// Notes: Covers the module, the prompt version, the language, the local
/// date, the model and the
/// facts. A change to any of them regenerates the card; nothing else does.
String insightFingerprint(AiInsightRequest request, String model) {
  final text = [
    request.facts.module.name,
    'prompt:$insightPromptVersion',
    'language:${request.language.localeTag}',
    'date:${factDate(request.now)}',
    'model:$model',
    request.facts.canonical(),
  ].join('\n');
  return sha256.convert(utf8.encode(text)).toString();
}

/// Owns the insight cards: the cache, what each card shows, and when to run
/// the model.
///
/// At most one generation per module runs or waits in the model queue; a
/// request that arrives meanwhile replaces the pending one, so rapid data
/// changes (ticking off several tasks) cost at most one extra run.
class AiInsightStore extends ChangeNotifier {
  /// Purpose: Create the store.
  /// Inputs: `ai` — the model service; `load`/`save`/`clear` — cache I/O,
  /// injectable for tests; `clock` — UTC clock for `generatedAt`.
  /// Returns: A new `AiInsightStore`.
  /// Side effects: None until first use.
  /// Notes: Defaults use `OnDeviceAiService.instance` and `AiInsightCardsCache`.
  AiInsightStore({
    OnDeviceAiService? ai,
    Future<AiInsightCards> Function()? load,
    Future<void> Function(AiInsightCards insights)? save,
    Future<void> Function()? clear,
    DateTime Function()? clock,
  }) : _aiOverride = ai,
       _load = load ?? AiInsightCardsCache.load,
       _save = save ?? AiInsightCardsCache.save,
       _clear = clear ?? AiInsightCardsCache.clear,
       _clock = clock ?? DateTime.now;

  /// The app-wide store.
  static AiInsightStore instance = AiInsightStore();

  /// Purpose: Replace the app-wide store.
  /// Inputs: `store`.
  /// Returns: None.
  /// Side effects: Swaps [instance].
  /// Notes: Tests only.
  @visibleForTesting
  static void setInstanceForTest(AiInsightStore store) => instance = store;

  final OnDeviceAiService? _aiOverride;
  final Future<AiInsightCards> Function() _load;
  final Future<void> Function(AiInsightCards insights) _save;
  final Future<void> Function() _clear;
  final DateTime Function() _clock;

  late final _coordinator =
      AiInsightCoordinator<InsightModule, AiInsightRequest>(
        keyOf: (request) => request.facts.module,
        fingerprintOf: insightFingerprint,
        modelOf: () => modelIdentityOf(_ai.report),
        canGenerate: () => _ai.canGenerate,
        load: () async => (await _load()).entries,
        save: (entries) => _save(AiInsightCards(entries)),
        clear: _clear,
        answer: (request, fingerprint, model, force) async {
          final (facts, parsed) = await _answer(request, force);
          if (parsed.isEmpty) return null;
          final numbers = parsed.keys.toList()..sort();
          return AiInsightEntry(
            fingerprint: fingerprint,
            lines: [
              for (final n in numbers) request.language.finish(parsed[n]!),
            ],
            slots: [for (final n in numbers) facts.slots[n - 1].id],
            status: AiInsightStatus.ok,
            generatedAt: _clock().toUtc(),
            model: model,
            language: request.language.localeTag,
            promptVersion: insightPromptVersion,
          );
        },
        skippedEntry: (request, fingerprint, model) => AiInsightEntry(
          fingerprint: fingerprint,
          lines: const [],
          status: AiInsightStatus.skipped,
          generatedAt: _clock().toUtc(),
          model: model,
          language: request.language.localeTag,
          promptVersion: insightPromptVersion,
        ),
      )..addListener(notifyListeners);

  /// Purpose: Resolve the model service.
  /// Inputs: None.
  /// Returns: The injected service, else the current singleton.
  /// Side effects: None.
  /// Notes: Read on every use so `OnDeviceAiService.setInstanceForTest`
  /// takes effect without rebuilding the store.
  OnDeviceAiService get _ai => _aiOverride ?? OnDeviceAiService.instance;

  /// Purpose: Read shared state. Inputs: module. Returns: state. Side effects: None. Notes: App key.
  AiInsightState stateOf(InsightModule module) => _coordinator.stateOf(module);

  /// Purpose: Ensure current insight. Inputs: request, force. Returns: completion.
  /// Side effects: Shared generation/cache. Notes: Business callbacks remain here.
  Future<void> ensure(AiInsightRequest request, {bool force = false}) =>
      _coordinator.ensure(request, force: force);

  /// Purpose: Run the model once for one facts value and parse the reply.
  /// Inputs: `facts`, `language`, `force` — interactive priority when true.
  /// Returns: `Future<Map<int, String>>` — slot number to sentence; empty
  /// when nothing in the reply was usable.
  /// Side effects: Runs the model.
  /// Notes: Internal helper used within this file only. Throws
  /// `GenAiException` as the service does.
  Future<Map<int, String>> _generateParsed(
    InsightFacts facts,
    InsightLanguage language,
    bool force,
  ) async {
    final reply = await _ai.generate(
      instructions: insightInstructions(language),
      prompt: insightPrompt(facts),
      maxOutputTokens: insightMaxOutputTokens,
      priority: force ? AiPriority.interactive : AiPriority.background,
    );
    return parseInsightReply(
      reply,
      facts.slots.length,
      language.code,
      quotedTerms: facts.quotedTerms,
      asks: [for (final s in facts.slots) s.ask],
    );
  }

  /// Purpose: Answer a request, trying its fallback facts once if needed.
  /// Inputs: `request`, `force`.
  /// Returns: `Future<(InsightFacts, Map<int, String>)>` — the facts that
  /// were actually answered and the parsed reply, which may be empty.
  /// Side effects: Runs the model once or twice.
  /// Notes: Internal helper used within this file only. The fallback runs
  /// when the first reply is refused (guardrail) or parses to nothing, and
  /// only when the request carries one. A guardrail on the fallback itself
  /// propagates, so it is cached as skipped like any other refusal.
  Future<(InsightFacts, Map<int, String>)> _answer(
    AiInsightRequest request,
    bool force,
  ) async {
    final primary = request.facts;
    final fallback = request.fallbackFacts;
    return generateWithFallback(
      primary: primary,
      fallback: fallback,
      generate: (facts) => _generateParsed(facts, request.language, force),
      usable: (parsed) => parsed.isNotEmpty,
    );
  }

  /// Purpose: Clear cache. Inputs: None. Returns: completion. Side effects: Deletes local cache. Notes: Shared invalidation.
  Future<void> clearAll() => _coordinator.clearAll();

  /// Purpose: Release listeners. Inputs: None. Returns: None. Side effects: Disposes coordinator. Notes: App lifetime.
  @override
  void dispose() {
    _coordinator.removeListener(notifyListeners);
    _coordinator.dispose();
    super.dispose();
  }
}

/// A plain `Provider` over the singleton, like `onDeviceAiServiceProvider`,
/// so tests can override it; widgets listen to the store itself.
final aiInsightStoreProvider = Provider<AiInsightStore>(
  (ref) => AiInsightStore.instance,
);
