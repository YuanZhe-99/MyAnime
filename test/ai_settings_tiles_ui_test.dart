import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/ai/services/genai_backend.dart';
import 'package:my_anime/features/ai/services/on_device_ai_service.dart';
import 'package:my_anime/features/ai/widgets/ai_settings_tiles.dart';
import 'package:my_anime/l10n/app_localizations.dart';
import 'package:my_anime/shared/providers/app_settings.dart';

import 'on_device_ai_test.dart' show FakeBackend;

/// Purpose: Test the on-device AI Settings rows per platform.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: Uses the fake backend from `on_device_ai_test.dart`, so nothing
/// reaches a method channel; `debugDefaultTargetPlatformOverride` picks the
/// platform.
void main() {
  late FakeBackend backend;
  late OnDeviceAiService service;

  setUp(() {
    backend = FakeBackend();
    service = OnDeviceAiService(backend: backend);
    OnDeviceAiService.setInstanceForTest(service);
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> pump(
    WidgetTester tester, {
    bool enabled = false,
    bool featuresOn = true,
  }) async {
    if (enabled) await service.setEnabled(true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsProvider.overrideWithValue(
            AppSettingsNotifier.fixed(AppSettings(onDeviceAiEnabled: enabled)),
          ),
          onDeviceAiServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: ListView(children: [AiSettingsTiles(featuresOn: featuresOn)]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Windows shows no AI rows at all', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await pump(tester);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(backend.calls, isEmpty);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android with the switch off shows only the switch', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await pump(tester);
    expect(find.text('Use on-device AI'), findsOneWidget);
    expect(find.text('Technical details'), findsNothing);
    expect(backend.calls, isEmpty);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the switch is disabled until a feature needs it', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await pump(tester, featuresOn: false);
    final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(tile.onChanged, isNull);
    expect(find.textContaining('Turn on automatic categories'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a downloadable model offers Download on Android', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    backend.status = const GenAiStatusReport(GenAiStatus.downloadable);
    await pump(tester, enabled: true);
    expect(find.text('Needs a one-time download'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('download'));
    expect(find.text('Ready'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the size choice appears only when both sizes are served', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    backend.status = const GenAiStatusReport(
      GenAiStatus.available,
      served: 'stable/full, stable/fast',
    );
    await pump(tester, enabled: true);
    expect(find.text('Use the faster model'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Apple Intelligence turned off is worded and rechecked', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    backend.status = const GenAiStatusReport(GenAiStatus.notEnabled);
    await pump(tester, enabled: true);
    expect(find.text('Apple Intelligence is turned off'), findsOneWidget);
    expect(find.text('Download'), findsNothing);
    backend.calls.clear();
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('status'));
    debugDefaultTargetPlatformOverride = null;
  });
}
