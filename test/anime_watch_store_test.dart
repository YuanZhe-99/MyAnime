import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/app/flavor.dart';
import 'package:my_anime/features/anime/models/anime_episode.dart';
import 'package:my_anime/features/anime/views/anime_episode_page.dart';
import 'package:my_anime/features/anime/views/anime_player_page.dart';
import 'package:my_anime/l10n/app_localizations.dart';

/// Purpose: Ensure even direct construction cannot reach online Anime1 playback in store builds.
/// Inputs: FLAVOR=store Dart define.
/// Returns: None.
/// Side effects: In-memory widget rendering only.
/// Notes: Run explicitly with the store define; skips in the full-flavor suite.
void main() {
  testWidgets(
    'store route constructors never resolve media or fetch a directory',
    (tester) async {
      var requested = false;
      Widget app(Widget page) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: page,
      );
      await tester.pumpWidget(
        app(
          AnimePlayerPage(
            page: const AnimeEpisodePage(
              url: 'https://anime1.me/1',
              title: 'Example',
              label: '1',
              group: 'Example',
            ),
            resolveMedia: (_) async {
              requested = true;
              return null;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requested, false);
      await tester.pumpWidget(
        app(const AnimeEpisodeLinksPage(animeId: 'no-storage-needed')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
    skip: !AppFlavor.isStore,
  );
}
