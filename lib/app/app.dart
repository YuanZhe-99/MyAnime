import 'package:device_preview/device_preview.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../shared/providers/app_settings.dart';
import 'router.dart';
import 'theme.dart';

/// Enable mouse wheel and trackpad scrolling on desktop.
class _DesktopScrollBehavior extends MaterialScrollBehavior {
  /// Purpose: Implement the drag devices behavior for this file.
  /// Inputs: None.
  /// Returns: `Set<PointerDeviceKind>`.
  /// Side effects: None.
  /// Notes: None.
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}

class MyAnimeApp extends ConsumerWidget {
  /// Purpose: Create a my anime app instance.
  /// Inputs: None.
  /// Returns: A new `MyAnimeApp` instance.
  /// Side effects: None.
  /// Notes: None.
  const MyAnimeApp({super.key});

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`, `ref`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return MaterialApp.router(
      title: 'MyAnime!!!!!',
      debugShowCheckedModeBanner: false,

      // Enable desktop scroll
      scrollBehavior: _DesktopScrollBehavior(),

      // Theme
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,

      // Localization
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,

      // DevicePreview
      builder: DevicePreview.appBuilder,

      // Routing
      routerConfig: appRouter,
    );
  }
}
