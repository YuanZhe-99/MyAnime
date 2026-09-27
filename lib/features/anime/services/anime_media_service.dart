import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'anime_episode_service.dart';
import 'anime_search_service.dart';

class AnimeMediaSource {
  final String url;
  final Map<String, String> headers;

  /// Purpose: Carry a temporary playable URL and request credentials in memory only.
  /// Inputs: URL and HTTP headers.
  /// Returns: Session-only source.
  /// Side effects: None.
  /// Notes: Deliberately has no serialization or diagnostic string method.
  const AnimeMediaSource(this.url, this.headers);
}

class AnimeMediaService {
  /// Purpose: Validate a media source returned by Anime1's own player API.
  /// Inputs: API JSON, episode URL and response cookies.
  /// Returns: Supported HTTPS media or null.
  /// Side effects: None.
  /// Notes: Credentials are sent only to a matching Anime1 video host.
  static AnimeMediaSource? parseSource(
    dynamic json,
    String pageUrl,
    List<Cookie> cookies,
  ) {
    if (json is! Map || json['s'] is! List) return null;
    for (final source in json['s'] as List) {
      if (source is! Map || source['src'] is! String) continue;
      final uri = Uri.parse(
        'https://v.anime1.me',
      ).resolve(source['src'] as String);
      if (uri.scheme != 'https' ||
          uri.userInfo.isNotEmpty ||
          !(uri.host == 'v.anime1.me' || uri.host.endsWith('.v.anime1.me'))) {
        continue;
      }
      final selected = cookies.where((c) {
        final domain = (c.domain ?? 'v.anime1.me').replaceFirst(
          RegExp(r'^\.'),
          '',
        );
        return (uri.host == domain || uri.host.endsWith('.$domain')) &&
            uri.path.startsWith(c.path ?? '/') &&
            (c.expires == null || c.expires!.isAfter(DateTime.now().toUtc()));
      });
      return AnimeMediaSource(uri.toString(), {
        'Referer': pageUrl,
        'User-Agent': AnimeSearchService.userAgent,
        if (selected.isNotEmpty)
          'Cookie': selected.map((c) => '${c.name}=${c.value}').join('; '),
      });
    }
    return null;
  }

  /// Purpose: Resolve the same short-lived source requested by the website player.
  /// Inputs: An Anime1 episode page URL.
  /// Returns: Media source or null so the caller can use the embedded website.
  /// Side effects: Fetches page and posts its public player request to v.anime1.me.
  /// Notes: Does not persist or log tokens; owns and closes both network clients.
  static Future<AnimeMediaSource?> resolve(String pageUrl) async {
    final client = http.Client();
    final api = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final page = await AnimeEpisodeService.getPage(pageUrl, client);
      final encoded = html
          .parse(page)
          .querySelector('video[data-apireq]')
          ?.attributes['data-apireq'];
      if (encoded == null || encoded.isEmpty) return null;
      final request = await api
          .postUrl(Uri.parse('https://v.anime1.me/api'))
          .timeout(const Duration(seconds: 10));
      request.followRedirects = false;
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/x-www-form-urlencoded',
      );
      request.headers.set(HttpHeaders.refererHeader, pageUrl);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        AnimeSearchService.userAgent,
      );
      request.write('d=$encoded');
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode != 200) return null;
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 10));
      return parseSource(jsonDecode(body), pageUrl, response.cookies);
    } catch (_) {
      return null;
    } finally {
      client.close();
      api.close(force: true);
    }
  }
}
