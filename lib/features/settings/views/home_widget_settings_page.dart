import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myapps_ui/myapps_ui.dart' show MyAppsSettingsSection;
import 'package:myapps_widget_ui/myapps_widget_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/providers/app_settings.dart';
import '../widgets/home_widget_preview.dart';

/// Settings › Home-screen widgets (1.9.7): one section per widget, each with
/// its own text-size slider and a live preview of that widget.
///
/// Before 1.9.7 one slider on the first Settings level scaled both widgets.
class HomeWidgetSettingsPage extends ConsumerStatefulWidget {
  /// Purpose: Create the widget settings page.
  /// Inputs: None.
  /// Returns: A new `HomeWidgetSettingsPage`.
  /// Side effects: None.
  /// Notes: Pushed full screen on a narrow window and hosted in the Settings
  /// detail pane on a wide one.
  const HomeWidgetSettingsPage({super.key});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  ConsumerState<HomeWidgetSettingsPage> createState() =>
      _HomeWidgetSettingsPageState();
}

class _HomeWidgetSettingsPageState
    extends ConsumerState<HomeWidgetSettingsPage> {
  /// Library state and placed sizes, loaded once per visit and shared by
  /// both previews.
  late final Future<HomeWidgetPreviewData> _data = HomeWidgetPreview.load();

  /// Purpose: Build the page.
  /// Inputs: `context`.
  /// Returns: A `Scaffold` with the large widget and strip sections.
  /// Side effects: The sliders persist their scale and schedule a widget
  /// refresh through `AppSettingsNotifier`.
  /// Notes: Each preview redraws as its own slider moves.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    Widget section(
      String title,
      HomeWidgetPreviewKind kind,
      double scale,
      ValueChanged<double> onChanged,
    ) => MyAppsSettingsSection(
      title: title,
      children: [
        WidgetTextScaleControl(
          value: scale,
          title: l10n.settingsWidgetTextSize,
          subtitle: l10n.settingsWidgetTextSizeDesc,
          onChanged: onChanged,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: HomeWidgetPreview(data: _data, kind: kind, textScale: scale),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsWidgets)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          section(
            l10n.settingsWidgetLarge,
            HomeWidgetPreviewKind.large,
            settings.widgetTextScale,
            notifier.setWidgetTextScale,
          ),
          section(
            l10n.settingsWidgetStrip,
            HomeWidgetPreviewKind.strip,
            settings.widgetStripTextScale,
            notifier.setWidgetStripTextScale,
          ),
        ],
      ),
    );
  }
}
