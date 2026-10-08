import 'package:flutter/material.dart';
import 'package:myapps_ai_local_ui/myapps_ai_local_ui.dart';
import 'package:myapps_ai_models/myapps_ai_models.dart';
import 'package:myapps_ai_online_ui/myapps_ai_online_ui.dart';
import 'package:myapps_ai_ui/myapps_ai_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/adaptive_layout.dart';
import '../services/ai_source_backend.dart';
import '../services/on_device_ai_service.dart';
import 'online_sources_page.dart';

/// App labels and pages around the shared source section.
class AiSourceControls extends StatelessWidget {
  /// Purpose: Bind the router. Inputs: [backend]; [onSelected], which pauses
  /// the AI service and offers to clear old insights.
  /// Returns: Widget. Side effects: None. Notes: None.
  const AiSourceControls({
    super.key,
    required this.backend,
    required this.onSelected,
  });

  final AiSourceRouter backend;
  final Future<void> Function(String) onSelected;

  /// Purpose: Build the section. Inputs: [context]. Returns: Widget.
  /// Side effects: Starts loading the router's metadata. Notes: None.
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    backend.initialize();
    return MyAppsAiSourceSection(
      controller: backend,
      labels: AiSourceSectionLabels(
        title: l.aiSourceTitle,
        automatic: l.aiSourceAuto,
        system: l.aiSourceSystem,
        needsPreparation: l.aiSourceNeedsPreparation,
        cancel: l.aiActionCancel,
        localModels: l.aiLocalModels,
        onlineSources: l.aiOnlineSources,
        gpuTitle: l.aiGpuTitle,
        gpuDescription: l.aiGpuDescription,
        gpuUnavailable: l.aiGpuUnavailable,
      ),
      onSelected: onSelected,
      onOpenLocalModels: (id) => openAiLocalModels(context, backend, id),
      onOpenOnlineSources: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (ctx) =>
              onlineSourcesPage(ctx, OnDeviceAiService.onlineSources),
        ),
      ),
      sourceIcon: (o) {
        final online = OnDeviceAiService.onlineSources;
        final p = online.providerFor(o.id);
        if (p == null) return null;
        return MyAppsProviderIcon(
          iconKey: onlineProviderIconKey(p, online.templates),
          name: p.name,
          size: 20,
        );
      },
    );
  }
}

/// Purpose: Open the local models page.
/// Inputs: [context], [backend], [initial] model to reveal.
/// Returns: Completion. Side effects: Navigation. Notes: Shared by the
/// source section and the AI settings.
Future<void> openAiLocalModels(
  BuildContext context,
  AiSourceRouter backend,
  String? initial,
) {
  final l = AppLocalizations.of(context)!;
  String gb(int b) => '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        appBar: AppBar(title: Text(l.aiLocalModels)),
        body: ListenableBuilder(
          listenable: backend.notifier,
          builder: (context, _) => ListView(
            padding: navBarAwarePadding(context, EdgeInsets.zero),
            children: [
              MyAppsLocalModelList(
                controller: backend,
                initialEntryId: initial,
                groups: [
                  MyAppsLocalModelGroup(
                    capability: 'llm',
                    title: l.aiLocalModels,
                  ),
                ],
                formatBytes: gb,
                labels: _modelLabels(l, backend),
                entryMenu: (e) =>
                    _ModelMenu(backend: backend, modelId: e.modelId),
              ),
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(l.aiCustomModelAdd),
                onTap: () =>
                    Navigator.of(context, rootNavigator: true).push<String>(
                      MaterialPageRoute(
                        builder: (_) => MyAppsAddCustomModelPage(
                          controller: backend,
                          formatBytes: gb,
                          labels: MyAppsCustomModelLabels(
                            title: l.aiCustomModelAdd,
                            repositoryLabel: l.aiCustomModelRepository,
                            repositoryHint: l.aiCustomModelRepositoryHint,
                            list: l.aiCustomModelList,
                            noFiles: l.aiCustomModelNoFiles,
                            splitUnsupported: l.aiCustomModelSplit,
                            listFailed: l.aiCustomModelListFailed,
                            warningTitle: l.aiCustomModelWarningTitle,
                            warningBody: l.aiCustomModelWarningBody,
                            architecture: (arch, supported) =>
                                switch ((arch, supported)) {
                                  (final a?, true) =>
                                    l.aiCustomModelArchSupported(a),
                                  (final a?, false) =>
                                    l.aiCustomModelArchUnsupported(a),
                                  _ => l.aiCustomModelArchUnknown,
                                },
                            storageAndMemory: l.aiCustomModelStorage,
                            license: (id) => id == null
                                ? l.aiCustomModelLicenseUnknown
                                : l.aiCustomModelLicense(id),
                            accept: l.aiCustomModelAccept,
                            download: l.aiDownload,
                            cancel: l.aiActionCancel,
                          ),
                        ),
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Purpose: Labels of the local model list.
/// Inputs: [l], [backend]. Returns: Labels. Side effects: None.
/// Notes: Names come from the router (friendly name or alias).
MyAppsLocalModelLabels _modelLabels(
  AppLocalizations l,
  AiSourceRouter backend,
) => MyAppsLocalModelLabels(
  modelName: (e) => backend.sourceName(e.modelId) ?? e.modelId,
  badge: (e) => backend.isCustom(e.modelId) ? l.aiCustomModelBadge : null,
  state: (s) => switch (s) {
    ModelInstallState.installed => l.aiModelInstalled,
    ModelInstallState.downloading => l.aiModelDownloading,
    ModelInstallState.verifying => l.aiModelVerifying,
    ModelInstallState.failed || ModelInstallState.corrupt => l.aiModelFailed,
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
);

/// Rename and, for custom models, remove-from-list.
class _ModelMenu extends StatelessWidget {
  /// Purpose: Bind a model. Inputs: [backend], [modelId]. Returns: Widget.
  /// Side effects: None. Notes: Internal.
  const _ModelMenu({required this.backend, required this.modelId});
  final AiSourceRouter backend;
  final String modelId;

  /// Purpose: Build the menu. Inputs: [context]. Returns: PopupMenuButton.
  /// Side effects: None. Notes: None.
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return PopupMenuButton<String>(
      onSelected: (v) async {
        if (v == 'remove') {
          await backend.removeCustomModel(modelId);
          return;
        }
        final alias = await showDialog<String>(
          context: context,
          builder: (_) => _AliasDialog(modelId: modelId),
        );
        if (alias != null) await backend.setModelAlias(modelId, alias);
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'rename', child: Text(l.aiModelRename)),
        if (backend.isCustom(modelId))
          PopupMenuItem(value: 'remove', child: Text(l.aiCustomModelRemove)),
      ],
    );
  }
}

/// The rename dialog; owns its controller so it outlives the pop animation.
class _AliasDialog extends StatefulWidget {
  /// Purpose: Bind a model. Inputs: [modelId]. Returns: Widget.
  /// Side effects: None. Notes: Internal.
  const _AliasDialog({required this.modelId});
  final String modelId;

  @override
  State<_AliasDialog> createState() => _AliasDialogState();
}

class _AliasDialogState extends State<_AliasDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Purpose: Build the dialog. Inputs: [context]. Returns: AlertDialog.
  /// Side effects: None. Notes: Pops the typed alias on save.
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.aiModelRename),
      content: TextField(
        controller: _c,
        autofocus: true,
        decoration: InputDecoration(
          hintText: l.aiModelAliasHint,
          helperText: widget.modelId,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.aiActionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_c.text),
          child: Text(l.aiModelSave),
        ),
      ],
    );
  }
}
