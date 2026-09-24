import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../providers/app_settings.dart';
import '../utils/adaptive_layout.dart';

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
  /// destinations (five only while the Kana tab is on); which one appears is
  /// [useNavigationRail]'s width-only decision, deliberately not the app-wide
  /// split rule. Nothing here is stateful, so folding a device swaps one for
  /// the other on the next frame with no route change.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final kanaTabEnabled = ref.watch(
      appSettingsProvider.select((s) => s.kanaTabEnabled),
    );
    final destinations = _destinations(l10n, kanaTabEnabled: kanaTabEnabled);
    final index = _currentIndex(context, destinations);

    void select(int i) => context.go(destinations[i].path);

    if (!useNavigationRail(MediaQuery.sizeOf(context).width)) {
      return Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: select,
          destinations: [
            for (final d in destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          // Five destinations (the most there can be) with labels run to roughly
          // 370 logical pixels, which fits every window wide enough to earn a
          // rail — but a rail can appear at compact heights, so let it scroll
          // rather than overflow.
          LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: NavigationRail(
                    selectedIndex: index,
                    onDestinationSelected: select,
                    labelType: NavigationRailLabelType.all,
                    // Centred rather than the default top alignment. A rail
                    // top-aligns to sit under a leading menu button or FAB;
                    // this one has neither, so the destinations pinned to the
                    // top of a tall rail would leave the whole lower half
                    // empty. Centring also keeps them near the thumb when the
                    // window is tall.
                    groupAlignment: 0,
                    destinations: [
                      for (final d in destinations)
                        NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: Text(d.label),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
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
