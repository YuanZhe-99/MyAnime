import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/anime/views/anime_detail_page.dart';
import '../features/anime/views/anime_edit_page.dart';
import '../features/anime/views/home_page.dart';
import '../features/anime/views/management_page.dart';
import '../features/anime/views/metadata_updates_page.dart';
import '../features/anime/views/statistics_page.dart';
import '../features/kana/views/kana_page.dart';
import '../features/settings/views/settings_page.dart';
import '../shared/providers/app_settings.dart';
import '../shared/widgets/duplicate_check_page.dart';
import '../shared/widgets/shell_scaffold.dart';

/// Purpose: Keep `/kana` unreachable while the Kana tab is hidden.
/// Inputs: `context` — must sit below the app's `ProviderScope`; `state`.
/// Returns: `String?` — `null` to allow the route, or `'/home'`.
/// Side effects: None; reads `appSettingsProvider` without listening.
/// Notes: The tab is off by default. Settings load asynchronously, but the
/// initial location is `/home`, so no real visit is bounced before they do.
String? kanaRouteRedirect(BuildContext context, GoRouterState state) {
  final settings = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(appSettingsProvider);
  return settings.kanaTabEnabled ? null : '/home';
}

final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    ShellRoute(
      builder: (context, state, child) => ShellScaffold(child: child),
      routes: [
        GoRoute(path: '/home', builder: (context, state) => const HomePage()),
        GoRoute(
          path: '/manage',
          builder: (context, state) => const ManagementPage(),
        ),
        GoRoute(
          path: '/stats',
          builder: (context, state) => const StatisticsPage(),
        ),
        GoRoute(
          path: '/kana',
          redirect: kanaRouteRedirect,
          builder: (context, state) => const KanaPage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    ),
    GoRoute(
      path: '/anime/detail/:id',
      builder: (context, state) =>
          AnimeDetailPage(animeId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/anime/edit',
      builder: (context, state) => const AnimeEditPage(),
    ),
    GoRoute(
      path: '/anime/edit/:id',
      // `extra: true` asks the page to open the online search as soon as it
      // loads — how the update-review screen hands off a record it could not
      // match on its own.
      builder: (context, state) => AnimeEditPage(
        animeId: state.pathParameters['id'],
        autoSearch: state.extra == true,
      ),
    ),
    GoRoute(
      path: '/metadata-updates',
      // `extra` carries the ids the user was looking at, which is what
      // "update this page" means on the review screen.
      builder: (context, state) => MetadataUpdatesPage(
        currentPageAnimeIds: state.extra is List<String>
            ? state.extra! as List<String>
            : const [],
      ),
    ),
    GoRoute(
      path: '/duplicate-check',
      builder: (context, state) => const DuplicateCheckPage(),
    ),
  ],
);
