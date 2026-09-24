import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/providers/app_settings.dart';
import '../services/genai_backend.dart';
import '../services/on_device_ai_service.dart';

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
    if (!platformMayHaveOnDeviceModel) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final ai = ref.watch(onDeviceAiServiceProvider);
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;

    return ListenableBuilder(
      listenable: ai,
      builder: (context, _) {
        final report = ai.report;
        final status = report.status;
        final info = ai.coreInfo;
        final progress = ai.downloadProgress;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.auto_awesome_outlined),
              title: Text(l10n.aiUseOnDevice),
              subtitle: Text(
                widget.featuresOn
                    ? l10n.aiUseOnDeviceDesc
                    : '${l10n.aiUseOnDeviceDesc}\n${l10n.aiNeedsFeature}',
              ),
              value: settings.onDeviceAiEnabled,
              onChanged: widget.featuresOn || settings.onDeviceAiEnabled
                  ? notifier.setOnDeviceAiEnabled
                  : null,
            ),
            if (settings.onDeviceAiEnabled) ...[
              ListTile(
                leading: const SizedBox(width: 24),
                title: Text(_statusLabel(status, l10n)),
                subtitle: status == GenAiStatus.notEnabled
                    ? Text(l10n.aiTurnOnAppleIntelligence)
                    : (ai.downloading && progress != null
                          ? Text(
                              l10n.aiDownloadedBytes(
                                (progress.bytes / (1024 * 1024))
                                    .toStringAsFixed(1),
                              ),
                            )
                          : null),
                trailing: switch (status) {
                  GenAiStatus.downloadable when isAndroid => FilledButton(
                    onPressed: ai.downloading ? null : ai.download,
                    child: Text(l10n.aiDownload),
                  ),
                  GenAiStatus.unavailable ||
                  GenAiStatus.unreachable ||
                  GenAiStatus.notEnabled ||
                  GenAiStatus.unknown ||
                  GenAiStatus.downloading => TextButton(
                    onPressed: () => ai.refreshStatus(localeTag: _localeTag()),
                    child: Text(l10n.aiCheckAgain),
                  ),
                  _ => null,
                },
              ),
              if (isAndroid && report.hasSizeChoice)
                SwitchListTile(
                  secondary: const SizedBox(width: 24),
                  title: Text(l10n.aiPreferFast),
                  subtitle: Text(l10n.aiPreferFastBody),
                  value: settings.onDeviceAiPreferFast,
                  onChanged: notifier.setOnDeviceAiPreferFast,
                ),
              ListTile(
                leading: const SizedBox(width: 24),
                subtitle: Text(
                  isAndroid
                      ? '${l10n.aiDownloadNote}\n${l10n.aiModelStorageNote}'
                      : l10n.aiModelAppleNote,
                ),
              ),
              ExpansionTile(
                leading: const SizedBox(width: 24),
                title: Text(l10n.aiTechnicalDetails),
                children: [
                  ListTile(
                    dense: true,
                    title: SelectableText(
                      [
                        'status: ${status.name} (${report.code})',
                        if (report.detail != null) 'detail: ${report.detail}',
                        if (report.variant != null)
                          'variant: ${report.variant}',
                        if (report.served != null) 'served: ${report.served}',
                        if (report.refused != null)
                          'refused: ${report.refused}',
                        if (report.baseModelName != null)
                          'model: ${report.baseModelName}',
                        if (report.tokenLimit != null)
                          'tokenLimit: ${report.tokenLimit}',
                        if (info?.versionName != null)
                          l10n.aiCoreVersion(info!.versionName!),
                        if (isAndroid && info != null && !info.installed)
                          l10n.aiCoreMissing,
                        if (info?.sdk != null) 'sdk: ${info!.sdk}',
                        if (info?.device != null) 'device: ${info!.device}',
                        if (info?.compatible != null)
                          'compatible: ${info!.compatible}',
                        if (info?.osVersion != null) 'os: ${info!.osVersion}',
                        if (info?.localeSupported != null)
                          'localeSupported: ${info!.localeSupported}',
                      ].join('\n'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
