import 'package:go_router/go_router.dart';

import '../features/anime/views/anime_detail_page.dart';
import '../features/anime/views/anime_edit_page.dart';
import '../features/anime/views/home_page.dart';
import '../features/anime/views/management_page.dart';
import '../features/settings/views/settings_page.dart';
import '../shared/widgets/shell_scaffold.dart';

final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    ShellRoute(
      builder: (context, state, child) => ShellScaffold(child: child),
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: '/manage',
          builder: (context, state) => const ManagementPage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    ),
    GoRoute(
      path: '/anime/detail/:id',
      builder: (context, state) => AnimeDetailPage(
        animeId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/anime/edit',
      builder: (context, state) => const AnimeEditPage(),
    ),
    GoRoute(
      path: '/anime/edit/:id',
      builder: (context, state) => AnimeEditPage(
        animeId: state.pathParameters['id'],
      ),
    ),
  ],
);
