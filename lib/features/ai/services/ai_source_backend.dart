import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:myapps_ai/myapps_ai.dart';
import 'package:myapps_ai_llm/myapps_ai_llm.dart';
import 'package:myapps_ai_llm_llama/myapps_ai_llm_llama.dart';
import 'package:myapps_ai_models/myapps_ai_models.dart';
import 'package:myapps_data/myapps_data.dart';

import '../../../app/data_modules.dart';
import 'genai_backend.dart' show MethodChannelGenAiBackend;
import 'online_sources.dart';
import 'package:myapps_ai_online/myapps_ai_online.dart';

/// Application-owned source routing and model persistence.
class AiSourceBackend extends CapabilityGenAiBackend
    implements ModelManagementController {
  /// Purpose: Bind app storage and system inference.
  /// Inputs: Optional storage/system overrides for tests. Returns: Backend.
  /// Side effects: None. Notes: No implicit downloads or online fallback.
  AiSourceBackend({StorageAdapter? storage, CapabilityGenAiBackend? system})
    : storage = storage ?? const AnimeStorageAdapter(),
      system = system ?? MethodChannelGenAiBackend() {
    manager = ArtifactManager(
      storage: CallbackModelStorageRoot(
        () async =>
            Directory('${(await this.storage.getAppDir()).path}/ai_models'),
      ),
      downloader: ArtifactDownloader(clientFactory: http.Client.new),
    );
  }

  final StorageAdapter storage;
  final CapabilityGenAiBackend system;
  final catalog = llamaCatalogFor();
  late final online = OnlineSources(storage: storage);
  OpenAiCompatibleLlmBackend? _remote;
  late final ArtifactManager manager;
  final notifier = ValueNotifier<int>(0);
  final _changes = StreamController<ModelManagementState>.broadcast();
  AiSourceSelection selection = const AiSourceSelection();
  LlamaCppBackend? _local;
  ArtifactLease? _lease;
  String? _localId;
  Future<void>? _initializing;
  Future<GenAiBackend>? _resolving;

  /// Purpose: Read device-local choices and installed metadata.
  /// Inputs: None. Returns: Completion. Side effects: Local reads.
  /// Notes: Does not probe system AI or load a model.
  Future<void> initialize() => _initializing ??= _initialize().catchError((
    Object error,
    StackTrace stack,
  ) {
    _initializing = null;
    Error.throwWithStackTrace(error, stack);
  });

  /// Purpose: Initialize metadata once. Inputs: None. Returns: Completion.
  /// Side effects: Reads config and model manifests. Notes: Internal.
  Future<void> _initialize() async {
    await online.initialize();
    selection = AiSourceSelection.fromJson(
      (await storage.readConfig())['aiSourceSelection'],
    );
    for (final m in catalog) {
      await manager.refresh(m.artifactId);
      manager.watch(m.artifactId).listen((_) => _publish());
    }
    _publish();
  }

  /// Purpose: Persist a source change after callers invalidate their service.
  /// Inputs: source id. Returns: Completion. Side effects: Cancels/unloads, writes config.
  /// Notes: Keeps unknown selection fields and overrides.
  Future<void> select(String id) async {
    await initialize();
    if (id == selection.global) return;
    await _resolving;
    await cancel();
    await _releaseLocal();
    final next = selection.withGlobal(id);
    final config = await storage.readConfig();
    config['aiSourceSelection'] = next.toJson();
    await storage.writeConfig(config);
    selection = next;
    _publish();
  }

  /// Purpose: Publish metadata. Inputs: None. Returns: None.
  /// Side effects: Notifies settings. Notes: No inference.
  void _publish() {
    notifier.value++;
    _changes.add(state);
  }

  /// Purpose: Build management rows. Inputs: None. Returns: State.
  /// Side effects: None. Notes: Only supported catalog entries.
  @override
  ModelManagementState get state => ModelManagementState(
    entries: [
      for (final m in catalog)
        ModelCatalogEntry.forArtifact(
          manifest: m,
          status: manager.statusOf(m.artifactId),
          platform: manager.platform,
          capability: 'llm',
          leased: manager.isLeased(m.artifactId),
        ),
    ],
  );

  /// Purpose: Observe management changes. Inputs: None. Returns: Stream.
  /// Side effects: None. Notes: Broadcast.
  @override
  Stream<ModelManagementState> get changes => _changes.stream;

  /// Purpose: Execute an explicit model action. Inputs: model/action. Returns: Completion.
  /// Side effects: Downloads, verifies or removes files. Notes: Refuses unsupported actions.
  @override
  Future<void> perform(String modelId, ModelAction action) async {
    await initialize();
    final m = catalog.firstWhere((m) => m.modelId == modelId);
    if (!state.entryFor(modelId)!.can(action)) {
      throw StateError('actionUnavailable');
    }
    switch (action) {
      case ModelAction.download:
        await manager.install(m);
      case ModelAction.cancel:
        manager.cancel(m.artifactId);
      case ModelAction.verify:
        await manager.verify(m.artifactId);
      case ModelAction.remove:
        await manager.remove(m.artifactId);
      case ModelAction.pauseResume:
        throw StateError('actionUnavailable');
    }
    _publish();
  }

  /// Purpose: Resolve the explicitly chosen backend. Inputs: None. Returns: Backend.
  /// Side effects: Local metadata reads; acquires a lease. Notes: Auto selects system only.
  Future<GenAiBackend> _resolve() =>
      _resolving ??= _resolveSelected().whenComplete(() => _resolving = null);

  /// Purpose: Resolve one source without concurrent model allocations.
  /// Inputs: None. Returns: Backend. Side effects: Acquires model lease.
  /// Notes: Internal; source switches wait for this operation.
  Future<GenAiBackend> _resolveSelected() async {
    await initialize();
    final id = selection.global;
    if (id == 'auto' || id == 'system') return system;
    if (id.startsWith('provider:')) {
      final providers = online.providers.where((p) => p.id == id);
      if (providers.isEmpty) {
        throw const GenAiException(GenAiFailure.unavailable);
      }
      final provider = providers.first;
      if (needsOnlinePrivacyAcknowledgement(
        await online.acknowledgement(id),
        1,
        recipientHost: provider.recipientHost,
      )) {
        throw const GenAiException(GenAiFailure.unavailable);
      }
      if (_remote != null && _remote!.provider != provider) {
        await _remote!.unload();
        _remote = null;
      }
      _remote ??= OpenAiCompatibleLlmBackend(
        provider: provider,
        readSecret: online.secrets.keyFor,
      );
      return LlmGenAiBackend(_remote!);
    }
    final matches = catalog.where((m) => m.modelId == id);
    if (matches.isEmpty) throw const GenAiException(GenAiFailure.unavailable);
    final m = matches.first;
    final status = await manager.refresh(m.artifactId);
    if (status.state != ArtifactState.installed) {
      throw const GenAiException(GenAiFailure.unavailable);
    }
    if (_localId != id) {
      await _releaseLocal();
      _lease = manager.lease(m.artifactId);
      _local = LlamaCppBackend(
        modelPath: llamaModelPath(m, await manager.artifactDir(m.artifactId))!,
      );
      _localId = id;
      _publish();
    }
    return LlmGenAiBackend(_local!, baseModelName: id);
  }

  /// Purpose: Release the current model. Inputs: None. Returns: Completion.
  /// Side effects: Unloads native memory/releases lease. Notes: Safe idle.
  Future<void> _releaseLocal() async {
    await _remote?.unload();
    _remote = null;
    await _local?.dispose();
    _local = null;
    _localId = null;
    _lease?.release();
    _lease = null;
  }

  /// Purpose: Read selected readiness. Inputs: probe/preference. Returns: Report.
  /// Side effects: Backend readiness check. Notes: Missing files report unavailable.
  @override
  Future<GenAiStatusReport> statusReport({
    bool force = false,
    bool preferFast = false,
  }) async {
    try {
      final report = await (await _resolve()).statusReport(
        force: force,
        preferFast: preferFast,
      );
      if (selection.global == 'auto' || selection.global == 'system') {
        return report;
      }
      return GenAiStatusReport(
        report.status,
        code: report.code,
        detail: report.detail,
        variant: selection.global,
        baseModelName: selection.global,
        tokenLimit: report.tokenLimit,
      );
    } on GenAiException {
      return const GenAiStatusReport(GenAiStatus.unavailable);
    }
  }

  /// Purpose: Read backend diagnostics. Inputs: locale. Returns: Info.
  /// Side effects: Metadata queries. Notes: Missing source returns null.
  @override
  Future<GenAiCoreInfo?> coreInfo({String? localeTag}) async {
    try {
      return await (await _resolve()).coreInfo(localeTag: localeTag);
    } on GenAiException {
      return null;
    }
  }

  /// Purpose: Download a system model explicitly. Inputs: progress. Returns: Readiness.
  /// Side effects: System download only. Notes: Local downloads use management.
  @override
  Future<bool> download({void Function(int, int)? onProgress}) async =>
      (await _resolve()).download(onProgress: onProgress);

  /// Purpose: Generate with selected source. Inputs: prompt/sampling. Returns: Text.
  /// Side effects: Inference. Notes: No fallback to online.
  @override
  Future<String> generate({
    required String instructions,
    required String prompt,
    int maxOutputTokens = 256,
    double temperature = 0,
    int topK = 1,
  }) async => (await _resolve()).generate(
    instructions: instructions,
    prompt: prompt,
    maxOutputTokens: maxOutputTokens,
    temperature: temperature,
    topK: topK,
  );

  /// Purpose: Choose validated options. Inputs: prompt/options/cap. Returns: Ids.
  /// Side effects: Inference. Notes: Uses selected backend parser.
  @override
  Future<List<String>> choose({
    required String instructions,
    required String prompt,
    required List<String> options,
    int maxItems = 3,
  }) async => (await _resolve()).choose(
    instructions: instructions,
    prompt: prompt,
    options: options,
    maxItems: maxItems,
  );

  /// Purpose: Prewarm selected backend. Inputs: None. Returns: Completion.
  /// Side effects: Loads model. Notes: Advisory errors ignored.
  @override
  Future<void> prewarm() async {
    try {
      await (await _resolve()).prewarm();
    } catch (_) {}
  }

  /// Purpose: Cancel active inference. Inputs: None. Returns: Completion.
  /// Side effects: Cancels system and local work. Notes: No initialization while disabled.
  @override
  Future<void> cancel() async {
    await system.cancel();
    await _local?.cancel();
    await _remote?.cancel();
  }

  /// Purpose: Keep proofreading as a separate system capability.
  /// Inputs: feature/preferences. Returns: Report. Side effects: System query.
  /// Notes: General LLMs do not claim system proofreading.
  @override
  Future<GenAiStatusReport> capabilityReport(
    GenAiFeature feature, {
    bool force = false,
    bool preferFast = false,
  }) => feature == GenAiFeature.prompt
      ? statusReport(force: force, preferFast: preferFast)
      : system.capabilityReport(feature, force: force, preferFast: preferFast);

  /// Purpose: Download an independent capability. Inputs: feature/progress.
  /// Returns: Readiness. Side effects: Explicit system download. Notes: Prompt uses selected source.
  @override
  Future<bool> downloadCapability(
    GenAiFeature feature, {
    void Function(int, int)? onProgress,
  }) => feature == GenAiFeature.prompt
      ? download(onProgress: onProgress)
      : system.downloadCapability(feature, onProgress: onProgress);

  /// Purpose: Correct Japanese with the system capability. Inputs: text. Returns: Suggestions.
  /// Side effects: On-device inference. Notes: Independent of prompt selection.
  @override
  Future<List<String>> proofread(String text) => system.proofread(text);
}
