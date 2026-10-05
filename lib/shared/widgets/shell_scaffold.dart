import 'package:flutter/material.dart';
import 'package:myapps_ui/myapps_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../providers/app_settings.dart';

class ShellScaffold extends ConsumerWidget {
  final Widget child;

  /// Purpose: Create a shell scaffold instance.
  /// Inputs: `key`, `child`.
  /// Returns: A new `ShellScaffold` instance.
  /// Side effects: None.
  /// Notes: None.
  const ShellScaffold({super.key, required this.child});

  /// Purpose: Provide the internal current index helper for this file.
  /// Inputs: `context`, `destinations` — the visible destinations.
  /// Returns: `int` — the index of the destination whose path prefixes the
  /// current location, or 0.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Derived from the
  /// location every build, never remembered, so hiding the Kana tab cannot
  /// leave a stale index behind.
  int _currentIndex(
    BuildContext context,
    List<_ShellDestination> destinations,
  ) {
    final location = GoRouterState.of(context).uri.path;
    for (var i = 0; i < destinations.length; i++) {
      if (location.startsWith(destinations[i].path)) return i;
    }
    return 0;
  }

  /// Purpose: Describe the shell's visible destinations once, paths and icons
  /// included.
  /// Inputs: `l10n`, `kanaTabEnabled`.
  /// Returns: `List<_ShellDestination>` — Home, Manage, Stats, then Kana when
  /// enabled, then Settings.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Both the bottom bar and
  /// the rail read from this one list, and each entry carries its own route,
  /// so a destination can never end up in one and not the other, or in a
  /// different order, or pointing at the wrong route when Kana is hidden.
  List<_ShellDestination> _destinations(
    AppLocalizations l10n, {
    required bool kanaTabEnabled,
  }) {
    return [
      _ShellDestination('/home', Icons.home_outlined, Icons.home, l10n.navHome),
      _ShellDestination(
        '/manage',
        Icons.video_library_outlined,
        Icons.video_library,
        l10n.navManage,
      ),
      _ShellDestination(
        '/stats',
        Icons.bar_chart_outlined,
        Icons.bar_chart,
        l10n.navStats,
      ),
      if (kanaTabEnabled)
        _ShellDestination(
          '/kana',
          Icons.translate_outlined,
          Icons.translate,
          l10n.navKana,
        ),
      _ShellDestination(
        '/settings',
        Icons.settings_outlined,
        Icons.settings,
        l10n.navSettings,
      ),
    ];
  }

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`, `ref`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often. The rail
  /// and the bottom bar are two renderings of the same four or five
  /// destinations (five only while the Kana tab is on). Which one appears
  /// follows the navigation-position setting (1.7.2, both styles): bottom
  /// everywhere (the default), the rail once the shared width rule says the
  /// window is wide enough, or the rail everywhere. The rail sits on the
  /// left or, by setting, the right. Expressive's bottom bar floats over the
  /// pages (`extendBody`), and the Scaffold reports its height as bottom
  /// padding so every page can leave room to scroll its last content above it
  /// (see the app padding helper). Nothing here is stateful, so folding a device
  /// swaps layouts on the next frame with no route change.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final kanaTabEnabled = ref.watch(
      appSettingsProvider.select((s) => s.kanaTabEnabled),
    );
    final expressive = ref.watch(
      appSettingsProvider.select((s) => s.uiStyle == AppUiStyle.expressive),
    );
    final placement = ref.watch(
      appSettingsProvider.select((s) => s.navPlacement),
    );
    final railOnRight = ref.watch(
      appSettingsProvider.select((s) => s.navRailOnRight),
    );
    final destinations = _destinations(l10n, kanaTabEnabled: kanaTabEnabled);
    final index = _currentIndex(context, destinations);

    void select(int i) => context.go(destinations[i].path);

    return MyAppsNavigationShell(
      destinations: [
        for (final d in destinations)
          MyAppsDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: d.label,
          ),
      ],
      selectedIndex: index,
      onSelected: select,
      style: expressive ? AppUiStyle.expressive : AppUiStyle.material3,
      placement: placement,
      railOnRight: railOnRight,
      child: child,
    );
  }
}

class _ShellDestination {
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// Purpose: Create a shell destination instance.
  /// Inputs: `path` — the shell route it opens, `icon`, `selectedIcon`, `label`.
  /// Returns: A new `_ShellDestination` instance.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  const _ShellDestination(this.path, this.icon, this.selectedIcon, this.label);
}
