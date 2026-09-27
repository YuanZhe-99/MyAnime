import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/services/anime1_service.dart';
import 'package:my_anime/features/anime/services/anime_episode_service.dart';
import 'package:my_anime/features/anime/services/anime_media_service.dart';

/// Purpose: Opt-in verification against the site's current public player protocol.
/// Inputs: ANIME1_LIVE Dart define.
/// Returns: None.
/// Side effects: Reads public pages, obtains temporary credentials and reads a small media range.
/// Notes: Never prints or persists source URLs, response bodies or credentials.
void main() {
  test(
    'live collection and native media byte access',
    () async {
      final index = await Anime1Service.loadIndex();
      final directory = await AnimeEpisodeService.fetch(
        'https://anime1.me/19159',
        index: index,
      );
      expect(
        directory.complete,
        true,
        reason: 'All archive pages should be reachable',
      );
      expect(
        directory.pages.where((p) => p.number != null).length,
        greaterThanOrEqualTo(12),
      );
      final media = await AnimeMediaService.resolve('https://anime1.me/19159');
      expect(
        media != null,
        true,
        reason: 'The public player API should yield a supported source',
      );
      if (media == null) return;
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(media.url));
        media.headers.forEach(request.headers.set);
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-1023');
        final response = await request.close().timeout(
          const Duration(seconds: 20),
        );
        expect(
          [200, 206].contains(response.statusCode),
          true,
          reason: 'The media host must accept the session credentials',
        );
        final firstBytes = await response.first.timeout(
          const Duration(seconds: 20),
        );
        expect(firstBytes.isNotEmpty, true);
      } finally {
        client.close(force: true);
      }
    },
    skip: !const bool.fromEnvironment('ANIME1_LIVE'),
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
