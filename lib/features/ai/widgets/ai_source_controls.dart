import 'package:flutter/material.dart';
import 'package:myapps_ai/myapps_ai.dart';
import 'package:myapps_ai_ui/myapps_ai_ui.dart';
import 'package:myapps_ai_models/myapps_ai_models.dart';
import 'package:myapps_ai_local_ui/myapps_ai_local_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../services/ai_source_backend.dart';
import 'online_sources_page.dart';

/// Source and download controls; the app supplies its invalidation policy.
class AiSourceControls extends StatelessWidget {
  /// Purpose: Bind source controls. Inputs: backend and switch callback.
  /// Returns: Widget. Side effects: None. Notes: Callback cancels old app work.
  const AiSourceControls({
    super.key,
    required this.backend,
    required this.onSelected,
  });
  final AiSourceBackend backend;
  final Future<void> Function(String) onSelected;

  /// Purpose: Render registered sources and local model management.
  /// Inputs: context. Returns: Controls. Side effects: Explicit selections/navigation.
  /// Notes: Auto never chooses an online provider.
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    backend.initialize();
    return ListenableBuilder(
      listenable: backend.notifier,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MyAppsAiSourcePicker(
            title: l.aiSourceTitle,
            options: [
              const AiSourceOption(id: 'auto', kind: AiSourceKind.auto),
              AiSourceOption(
                id: 'system',
                kind: AiSourceKind.system,
                readiness: platformMayHaveOnDeviceModel
                    ? AiSourceReadiness.ready
                    : AiSourceReadiness.unavailable,
              ),
              for (final m in backend.catalog)
                AiSourceOption(
                  id: m.modelId,
                  kind: AiSourceKind.local,
                  readiness:
                      backend.state.entryFor(m.modelId)?.state ==
                          ModelInstallState.installed
                      ? AiSourceReadiness.ready
                      : AiSourceReadiness.needsDownload,
                ),
              for (final p in backend.online.providers)
                AiSourceOption(id: p.id, kind: AiSourceKind.online),
            ],
            selectedId: backend.selection.global,
            labels: AiSourceLabels(
              sourceName: (o) => switch (o.kind) {
                AiSourceKind.auto => l.aiSourceAuto,
                AiSourceKind.system => l.aiSourceSystem,
                AiSourceKind.online =>
                  backend.online.providers.firstWhere((p) => p.id == o.id).name,
                _ => modelDisplayName(o.id),
              },
              readiness: (r) => r == AiSourceReadiness.ready
                  ? null
                  : l.aiSourceNeedsPreparation,
              followGlobal: l.aiSourceAuto,
              cancel: l.aiActionCancel,
            ),
            onSelected: (id) {
              if (id != null) onSelected(id);
            },
            onResolve: (o) => _openModels(context, o.id),
          ),
          MyAppsAiManagementEntry(
            title: l.aiLocalModels,
            icon: Icons.folder_outlined,
            onTap: () => _openModels(context, null),
          ),
          MyAppsAiManagementEntry(
            title: l.aiOnlineSources,
            icon: Icons.cloud_outlined,
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (ctx) => onlineSourcesPage(ctx, backend.online),
                ),
              );
              backend.notifier.value++;
            },
          ),
        ],
      ),
    );
  }

  /// Purpose: Open shared model management. Inputs: context/highlight.
  /// Returns: Completion. Side effects: Navigation. Notes: Downloads require an explicit tap.
  Future<void> _openModels(BuildContext context, String? initial) async {
    final l = AppLocalizations.of(context)!;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(l.aiLocalModels)),
          body: SingleChildScrollView(
            child: MyAppsLocalModelList(
              controller: backend,
              initialEntryId: initial,
              groups: [
                MyAppsLocalModelGroup(
                  capability: 'llm',
                  title: l.aiLocalModels,
                ),
              ],
              formatBytes: (b) =>
                  '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB',
              labels: MyAppsLocalModelLabels(
                modelName: (e) => modelDisplayName(e.modelId),
                state: (s) => switch (s) {
                  ModelInstallState.installed => l.aiModelInstalled,
                  ModelInstallState.downloading => l.aiModelDownloading,
                  ModelInstallState.verifying => l.aiModelVerifying,
                  ModelInstallState.failed ||
                  ModelInstallState.corrupt => l.aiModelFailed,
                  _ => l.aiModelNotInstalled,
                },
                action: (a) => switch (a) {
                  ModelAction.download => l.aiDownload,
                  ModelAction.verify => l.aiModelVerify,
                  ModelAction.remove => l.aiModelRemove,
                  _ => l.aiActionCancel,
                },
                failure: (_) => l.aiModelFailed,
                progress: (f, b) => f == null
                    ? b ?? l.aiModelDownloading
                    : '${(f * 100).toStringAsFixed(0)}%',
                systemManaged: l.aiSourceSystem,
                removeTitle: (_) => l.aiModelRemove,
                removeBody: l.aiModelRemoveBody,
                removeConfirm: l.aiModelRemove,
                storage: (used, free) => used ?? '',
                empty: l.aiModelNotInstalled,
                actionFailed: l.aiModelFailed,
                cancel: l.aiActionCancel,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Purpose: Name catalog models. Inputs: stable id. Returns: Name.
/// Side effects: None. Notes: Model names are proper nouns.
String modelDisplayName(String id) => switch (id) {
  'local:qwen3.5-0.8b' => 'Qwen3.5 0.8B · Q4_K_M',
  'local:qwen3.5-2b' => 'Qwen3.5 2B · Q4_K_M',
  _ => 'Gemma 4 E2B · Q4_0',
};
