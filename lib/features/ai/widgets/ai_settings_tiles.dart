import 'package:myapps_ai_ui/myapps_ai_ui.dart';
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

    return MyAppsAiSettings(
      ai: ai,
      enabled: settings.onDeviceAiEnabled,
      preferFast: settings.onDeviceAiPreferFast,
      onEnabledChanged: widget.featuresOn || settings.onDeviceAiEnabled
          ? notifier.setOnDeviceAiEnabled
          : null,
      onPreferFastChanged: notifier.setOnDeviceAiPreferFast,
      localeTag: _localeTag(),
      statusLabel: (status) => _statusLabel(status, l10n),
      label: (key) => switch (key) {
        'aiUseOnDevice' => l10n.aiUseOnDevice,
        'aiUseOnDeviceDesc' =>
          widget.featuresOn
              ? l10n.aiUseOnDeviceDesc
              : '${l10n.aiUseOnDeviceDesc}\n${l10n.aiNeedsFeature}',
        'aiTurnOnAppleIntelligence' => l10n.aiTurnOnAppleIntelligence,
        'aiDownload' => l10n.aiDownload,
        'aiCheckAgain' => l10n.aiCheckAgain,
        'aiPreferFast' => l10n.aiPreferFast,
        'aiPreferFastBody' => l10n.aiPreferFastBody,
        'aiDownloadNote' => l10n.aiDownloadNote,
        'aiModelStorageNote' => l10n.aiModelStorageNote,
        'aiModelAppleNote' => l10n.aiModelAppleNote,
        'aiTechnicalDetails' => l10n.aiTechnicalDetails,
        'aiCoreMissing' => l10n.aiCoreMissing,
        _ => throw ArgumentError.value(key),
      },
      format: (key, value) => switch (key) {
        'aiDownloadedBytes' => l10n.aiDownloadedBytes(value),
        'aiCoreVersion' => l10n.aiCoreVersion(value),
        _ => throw ArgumentError.value(key),
      },
    );
  }
}
