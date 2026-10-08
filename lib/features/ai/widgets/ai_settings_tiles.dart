import 'package:myapps_ai_ui/myapps_ai_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/providers/app_settings.dart';
import '../services/genai_backend.dart';
import '../services/on_device_ai_service.dart';
import 'ai_source_controls.dart';
import '../services/ai_insights_cache.dart';

/// The on-device AI rows of the *Categories & recommendations* Settings
/// section: the switch, the model status with its actions, the size
/// preference, the notes, and a collapsed technical-details tile.
///
/// Renders nothing on a platform that cannot have an on-device model
/// (Windows, Linux, web), so the section there holds only the feature
/// switches.
class AiSettingsTiles extends ConsumerStatefulWidget {
  /// Whether at least one feature that uses the model is on; the AI switch
  /// is enabled only then.
  final bool featuresOn;

  /// Purpose: Create the AI settings rows.
  /// Inputs: `featuresOn`.
  /// Returns: A new `AiSettingsTiles`.
  /// Side effects: None.
  /// Notes: Reads `OnDeviceAiService.instance` through
  /// `onDeviceAiServiceProvider`, so tests can substitute a fake backend.
  const AiSettingsTiles({super.key, required this.featuresOn});

  /// Purpose: Create the state object.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  ConsumerState<AiSettingsTiles> createState() => _AiSettingsTilesState();
}

class _AiSettingsTilesState extends ConsumerState<AiSettingsTiles> {
  /// Purpose: Refresh the model status when Settings opens.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: One forced status probe, only while the switch is on.
  /// Notes: Flutter lifecycle override.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ai = ref.read(onDeviceAiServiceProvider);
      if (ai.enabled) ai.refreshStatus(localeTag: _localeTag());
    });
  }

  /// Purpose: Return the app's current locale as a tag such as `zh_TW`.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String _localeTag() {
    final l = Localizations.localeOf(context);
    return l.countryCode == null
        ? l.languageCode
        : '${l.languageCode}_${l.countryCode}';
  }

  /// Purpose: Word a model status.
  /// Inputs: `status`, `l10n`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: `unsupported` only reaches here on iOS and macOS older than 26.
  String _statusLabel(GenAiStatus status, AppLocalizations l10n) =>
      switch (status) {
        GenAiStatus.available => l10n.aiStatusAvailable,
        GenAiStatus.unavailable => l10n.aiStatusUnavailable,
        GenAiStatus.unreachable => l10n.aiStatusUnreachable,
        GenAiStatus.unknown => l10n.aiStatusUnknown,
        GenAiStatus.downloadable => l10n.aiStatusDownloadable,
        GenAiStatus.downloading => l10n.aiStatusDownloading,
        GenAiStatus.notEnabled => l10n.aiStatusNotEnabled,
        GenAiStatus.unsupported => l10n.aiStatusUnsupportedApple,
      };

  /// Purpose: Build the rows.
  /// Inputs: `context`.
  /// Returns: A `Column` of tiles, or an empty box on unsupported platforms.
  /// Side effects: None.
  /// Notes: Rebuilds whenever the service notifies.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final ai = ref.watch(onDeviceAiServiceProvider);

    return ListenableBuilder(
      listenable: ai,
      builder: (context, _) => MyAppsAiSettingsSkeleton(
        enabled: settings.onDeviceAiEnabled,
        master: MyAppsAiPreference(
          title: l10n.aiUseOnDevice,
          description: widget.featuresOn
              ? l10n.aiUseOnDeviceDesc
              : '${l10n.aiUseOnDeviceDesc}\n${l10n.aiNeedsFeature}',
          value: settings.onDeviceAiEnabled,
          onChanged: widget.featuresOn || settings.onDeviceAiEnabled
              ? notifier.setOnDeviceAiEnabled
              : null,
        ),
        source: [
          AiSourceControls(
            backend: OnDeviceAiService.sourceBackend,
            onSelected: (id) async {
              if (id == OnDeviceAiService.sourceBackend.selection.global) {
                return;
              }
              await ai.setEnabled(false);
              await OnDeviceAiService.sourceBackend.select(id);
              await ai.setEnabled(settings.onDeviceAiEnabled);
              final cache = await AiInsightsCache.load();
              if (cache.categories.isEmpty || !context.mounted) return;
              if (await confirmClearAfterSourceChange(
                context,
                AiClearAfterSwitchLabels(
                  title: l10n.aiSourceTitle,
                  body: l10n.aiSourceClearBody,
                  clear: l10n.aiModelRemove,
                  keep: l10n.aiSourceKeep,
                ),
              )) {
                cache.categories.clear();
                await AiInsightsCache.save(cache);
              }
            },
          ),
          if (ai.report.hasSizeChoice)
            MyAppsAiPreference(
              title: l10n.aiPreferFast,
              description: l10n.aiPreferFastBody,
              value: settings.onDeviceAiPreferFast,
              onChanged: notifier.setOnDeviceAiPreferFast,
            ),
        ],
        features: [
          MyAppsAiCapabilityTile(
            title: l10n.aiUseOnDevice,
            statusText: _statusLabel(ai.report.status, l10n),
            icon: Icons.auto_awesome_outlined,
            action: ai.report.status == GenAiStatus.downloadable
                ? FilledButton(
                    onPressed: ai.downloading ? null : ai.download,
                    child: Text(l10n.aiDownload),
                  )
                : TextButton(
                    onPressed: () => ai.refreshStatus(localeTag: _localeTag()),
                    child: Text(l10n.aiCheckAgain),
                  ),
          ),
          if (ai.report.status == GenAiStatus.notEnabled)
            ListTile(subtitle: Text(l10n.aiTurnOnAppleIntelligence)),
          if (ai.downloading && ai.downloadProgress != null)
            ListTile(
              subtitle: Text(
                l10n.aiDownloadedBytes(
                  (ai.downloadProgress!.bytes / (1024 * 1024)).toStringAsFixed(
                    1,
                  ),
                ),
              ),
            ),
          if (OnDeviceAiService.sourceBackend.selection.global == 'auto' ||
              OnDeviceAiService.sourceBackend.selection.global == 'system')
            MyAppsAiModelNotes(
              downloadNote: l10n.aiDownloadNote,
              storageNote: l10n.aiModelStorageNote,
            ),
        ],
        diagnostics: MyAppsAiDiagnosticsView(
          load: () => OnDeviceAiService.sourceBackend.diagnostics(
            localeTag: _localeTag(),
          ),
          labels: AiDiagnosticsLabels(
            title: l10n.aiTechnicalDetails,
            copy: l10n.aiDiagnosticsCopy,
            copied: l10n.aiDiagnosticsCopied,
            notIncluded: l10n.aiDiagnosticsNotIncluded,
          ),
        ),
      ),
    );
  }
}
