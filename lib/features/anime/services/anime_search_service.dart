import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../shared/utils/chinese_convert.dart';

/// A single search result from an anime database.
class AnimeSearchResult {
  final String source;
  final String? sourceUrl;
  final String? title;
  final String? titleJa;
  final int? episodes;
  final DateTime? firstAirDate;
  final int? airDayOfWeek;
  final String? airTime;
  final String? coverImageUrl;
  final String? summary;

  const AnimeSearchResult({
    required this.source,
    this.sourceUrl,
    this.title,
    this.titleJa,
    this.episodes,
    this.firstAirDate,
    this.airDayOfWeek,
    this.airTime,
    this.coverImageUrl,
    this.summary,
  });
}

class AnimeSearchService {
  static const _userAgent = 'MyAnime/0.1.1 (anime tracker)';

  /// Search all sources in parallel and return combined results.
  /// Automatically tries S↔T Chinese variants on Chinese-language sources.
  static Future<List<AnimeSearchResult>> searchAll(String query) async {
    final simplified = ChineseConvert.toSimplified(query);

    final futures = <Future<List<AnimeSearchResult>>>[
      _searchBangumi(query).catchError((_) => <AnimeSearchResult>[]),
      _searchMAL(query).catchError((_) => <AnimeSearchResult>[]),
      _searchAcgsecrets(query).catchError((_) => <AnimeSearchResult>[]),
      _searchFilmarks(query).catchError((_) => <AnimeSearchResult>[]),
    ];
    // bangumi.tv is mainland-Chinese — also try simplified variant.
    if (simplified != query) {
      futures.add(
        _searchBangumi(simplified).catchError((_) => <AnimeSearchResult>[]),
      );
    }

    final results = await Future.wait(futures);
    // Deduplicate by sourceUrl.
    final seen = <String>{};
    final deduped = <AnimeSearchResult>[];
    for (final r in results.expand((r) => r)) {
      final key = r.sourceUrl ?? r.title ?? '';
      if (seen.add(key)) {
        deduped.add(r);
      }
    }
    return deduped;
  }

  /// bangumi.tv — uses legacy search API.
  static Future<List<AnimeSearchResult>> _searchBangumi(String query) async {
    final url = Uri.parse(
      'https://api.bgm.tv/search/subject/${Uri.encodeComponent(query)}'
      '?type=2&responseGroup=large&max_results=5',
    );
    final resp = await http.get(url, headers: {
      'User-Agent': _userAgent,
      'Accept': 'application/json',
    }).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return [];

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final list = json['list'] as List<dynamic>?;
    if (list == null) return [];

    return list.take(5).map((item) {
      final m = item as Map<String, dynamic>;
      final images = m['images'] as Map<String, dynamic>?;
      DateTime? airDate;
      if (m['air_date'] != null) {
        airDate = DateTime.tryParse(m['air_date'] as String);
      }
      return AnimeSearchResult(
        source: 'bangumi.tv',
        sourceUrl: 'https://bgm.tv/subject/${m['id']}',
        title: (m['name_cn'] as String?)?.isNotEmpty == true
            ? m['name_cn'] as String
            : null,
        titleJa: m['name'] as String?,
        episodes: m['eps'] as int? ?? m['eps_count'] as int?,
        firstAirDate: airDate,
        coverImageUrl: images?['large'] as String? ??
            images?['common'] as String?,
        summary: m['summary'] as String?,
      );
    }).toList();
  }

  /// MyAnimeList — uses Jikan v4 API.
  static Future<List<AnimeSearchResult>> _searchMAL(String query) async {
    final url = Uri.parse(
      'https://api.jikan.moe/v4/anime'
      '?q=${Uri.encodeComponent(query)}&limit=5',
    );
    final resp = await http.get(url, headers: {
      'User-Agent': _userAgent,
      'Accept': 'application/json',
    }).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return [];

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = json['data'] as List<dynamic>?;
    if (data == null) return [];

    return data.take(5).map((item) {
      final m = item as Map<String, dynamic>;
      final images = m['images'] as Map<String, dynamic>?;
      final jpgImages = images?['jpg'] as Map<String, dynamic>?;
      final aired = m['aired'] as Map<String, dynamic>?;
      DateTime? airDate;
      if (aired?['from'] != null) {
        airDate = DateTime.tryParse(aired!['from'] as String);
      }
      final broadcast = m['broadcast'] as Map<String, dynamic>?;
      int? airDayOfWeek;
      String? airTime;
      if (broadcast != null) {
        final dayStr = broadcast['day'] as String?;
        if (dayStr != null) airDayOfWeek = _parseDayOfWeek(dayStr);
        airTime = broadcast['time'] as String?;
      }
      return AnimeSearchResult(
        source: 'MyAnimeList',
        sourceUrl: m['url'] as String?,
        title: m['title'] as String?,
        titleJa: m['title_japanese'] as String?,
        episodes: m['episodes'] as int?,
        firstAirDate: airDate,
        airDayOfWeek: airDayOfWeek,
        airTime: airTime,
        coverImageUrl: jpgImages?['large_image_url'] as String? ??
            jpgImages?['image_url'] as String?,
        summary: m['synopsis'] as String?,
      );
    }).toList();
  }

  /// acgsecrets.hk — scrape seasonal page JSON-LD data and fuzzy-match.
  static Future<List<AnimeSearchResult>> _searchAcgsecrets(
      String query) async {
    final seasons = _recentSeasons();
    final allResults = <(AnimeSearchResult, double)>[];
    final seenUrls = <String>{};
    final queryTrad = ChineseConvert.toTraditional(query);
    final querySimp = ChineseConvert.toSimplified(query);

    for (final season in seasons) {
      final url = Uri.parse('https://acgsecrets.hk/bangumi/$season/');
      final resp = await http.get(url, headers: {
        'User-Agent': _userAgent,
      }).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) continue;

      final html = utf8.decode(resp.bodyBytes);
      final ldPattern = RegExp(
        r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>',
        dotAll: true,
      );
      for (final m in ldPattern.allMatches(html)) {
        try {
          final data = jsonDecode(m.group(1)!) as Map<String, dynamic>;
          final items = data['itemListElement'] as List?;
          if (items == null) continue;
          for (final item in items) {
            if (item is! Map) continue;
            final name = item['name'] as String? ?? '';
            final altNames =
                (item['alternateName'] as List?)?.cast<String>() ?? [];
            final allNames = [name, ...altNames];

            // Compute best fuzzy score against query variants.
            double bestScore = 0;
            for (final n in allNames) {
              for (final q in [query, queryTrad, querySimp]) {
                final s = _similarity(n, q);
                if (s > bestScore) bestScore = s;
              }
            }
            if (bestScore < 0.3) continue;

            final itemUrl = item['url'] as String?;
            if (itemUrl != null && !seenUrls.add(itemUrl)) continue;

            DateTime? startDate;
            if (item['startDate'] != null) {
              startDate = DateTime.tryParse(item['startDate'] as String);
            }
            // Pick Japanese title from alternateName.
            String? titleJa;
            for (final n in altNames) {
              if (_containsJapanese(n)) {
                titleJa = n;
                break;
              }
            }
            allResults.add((
              AnimeSearchResult(
                source: 'acgsecrets.hk',
                sourceUrl: itemUrl,
                title: name.isNotEmpty ? name : null,
                titleJa: titleJa,
                coverImageUrl: item['image'] as String?,
                firstAirDate: startDate,
              ),
              bestScore,
            ));
          }
        } catch (_) {}
      }
      // If we already found matches in the current season, skip older ones.
      if (allResults.isNotEmpty) break;
    }

    // Sort by score descending.
    allResults.sort((a, b) => b.$2.compareTo(a.$2));
    return allResults.take(5).map((e) => e.$1).toList();
  }

  /// Return recent season codes (YYYYMM) for scraping, newest first.
  static List<String> _recentSeasons() {
    final now = DateTime.now();
    final y = now.year;
    final m = now.month;
    // Current season month: 01, 04, 07, 10.
    final sm = [1, 4, 7, 10].lastWhere((s) => m >= s);
    final seasons = <String>[
      '$y${sm.toString().padLeft(2, '0')}',
    ];
    // Previous season.
    if (sm == 1) {
      seasons.add('${y - 1}10');
    } else {
      seasons.add('$y${(sm - 3).toString().padLeft(2, '0')}');
    }
    return seasons;
  }

  /// Check if a string contains Japanese kana characters.
  static bool _containsJapanese(String s) {
    for (final c in s.runes) {
      // Hiragana: 3040-309F, Katakana: 30A0-30FF
      if ((c >= 0x3040 && c <= 0x309F) || (c >= 0x30A0 && c <= 0x30FF)) {
        return true;
      }
    }
    return false;
  }

  /// filmarks.com — HTML scraping.
  static Future<List<AnimeSearchResult>> _searchFilmarks(String query) async {
    final url = Uri.parse(
      'https://filmarks.com/search/animes'
      '?q=${Uri.encodeComponent(query)}',
    );
    final resp = await http.get(url, headers: {
      'User-Agent': _userAgent,
      'Accept-Language': 'ja',
    }).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return [];

    final html = utf8.decode(resp.bodyBytes);
    final results = <AnimeSearchResult>[];

    // Match anime card items with title and optionally image
    final itemPattern = RegExp(
      r'<a[^>]*href="(/anime/[^"]*)"[^>]*>.*?'
      r'(?:<img[^>]*src="([^"]*)"[^>]*/?>)?.*?'
      r'class="[^"]*title[^"]*"[^>]*>([^<]+)<',
      dotAll: true,
    );
    for (final match in itemPattern.allMatches(html).take(5)) {
      final path = match.group(1);
      final imgUrl = match.group(2);
      final title = match.group(3)?.trim();
      if (title != null && title.isNotEmpty) {
        results.add(AnimeSearchResult(
          source: 'filmarks.com',
          sourceUrl: path != null ? 'https://filmarks.com$path' : null,
          titleJa: _decodeHtmlEntities(title),
          coverImageUrl: imgUrl,
        ));
      }
    }

    // Fallback: links to /anime/ with visible text
    if (results.isEmpty) {
      final fallback = RegExp(
        r'<a[^>]*href="(/anime/\d+[^"]*)"[^>]*>([^<]+)</a>',
      );
      for (final match in fallback.allMatches(html).take(5)) {
        final path = match.group(1);
        final title = match.group(2)?.trim();
        if (title != null && title.isNotEmpty && title.length > 1) {
          results.add(AnimeSearchResult(
            source: 'filmarks.com',
            sourceUrl: path != null ? 'https://filmarks.com$path' : null,
            titleJa: _decodeHtmlEntities(title),
          ));
        }
      }
    }

    return results;
  }

  static int? _parseDayOfWeek(String day) {
    final d = day.toLowerCase();
    if (d.startsWith('mon')) return 1;
    if (d.startsWith('tue')) return 2;
    if (d.startsWith('wed')) return 3;
    if (d.startsWith('thu')) return 4;
    if (d.startsWith('fri')) return 5;
    if (d.startsWith('sat')) return 6;
    if (d.startsWith('sun')) return 7;
    return null;
  }

  /// anime1.me — search for watch URLs.
  /// Returns list of (title, url) pairs for the anime's category page.
  /// Automatically tries S↔T Chinese variants + optional alternate queries.
  /// Results are ranked by fuzzy similarity to the queries.
  static Future<List<({String title, String url})>> searchAnime1(
      String query, {List<String> altQueries = const []}) async {
    // Build all query variants.
    final traditional = ChineseConvert.toTraditional(query);
    final simplified = ChineseConvert.toSimplified(query);
    final queries = <String>{query, traditional, simplified};
    for (final alt in altQueries) {
      if (alt.trim().isNotEmpty) {
        queries.add(alt.trim());
        queries.add(ChineseConvert.toTraditional(alt.trim()));
        queries.add(ChineseConvert.toSimplified(alt.trim()));
      }
    }

    final allResults = <({String title, String url})>[];
    final seenUrls = <String>{};

    // Try each query variant; merge results.
    for (final q in queries) {
      final partial = await _searchAnime1Single(q);
      for (final r in partial) {
        if (seenUrls.add(r.url)) {
          allResults.add(r);
        }
      }
    }

    // Fallback: if no results, try short substrings (bigrams) from the
    // traditional query.  E.g. "能幫我弄乾淨嗎" shares "乾淨" with
    // "可以幫忙洗乾淨嗎？" even though the full titles differ.
    if (allResults.isEmpty) {
      final trad = ChineseConvert.toTraditional(query)
          .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
      if (trad.length >= 4) {
        int attempts = 0;
        for (int i = trad.length - 2;
            i >= 0 && attempts < 3 && allResults.isEmpty;
            i--) {
          final sub = trad.substring(i, i + 2);
          attempts++;
          final partial = await _searchAnime1Single(sub);
          for (final r in partial) {
            if (seenUrls.add(r.url)) allResults.add(r);
          }
        }
      }
    }

    // Rank by fuzzy similarity to any query variant.
    final queryVariants = queries.toList();
    allResults.sort((a, b) {
      final sa = _bestSimilarity(a.title, queryVariants);
      final sb = _bestSimilarity(b.title, queryVariants);
      return sb.compareTo(sa); // descending
    });

    return allResults.take(10).toList();
  }

  /// Compute the best similarity score of [title] against any of [queries].
  /// Returns 0.0..1.0.
  static double _bestSimilarity(String title, List<String> queries) {
    double best = 0;
    for (final q in queries) {
      final s = _similarity(title, q);
      if (s > best) best = s;
    }
    return best;
  }

  /// Fuzzy similarity combining LCS, Dice (set-based), and containment.
  /// Also compares S↔T normalized forms.  Returns 0.0..1.0.
  static double _similarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final aNorm = ChineseConvert.toTraditional(a);
    final bNorm = ChineseConvert.toTraditional(b);
    double best = 0;
    for (final pair in [(a, b), (aNorm, bNorm)]) {
      final s1 = pair.$1, s2 = pair.$2;
      // LCS-based Dice coefficient.
      final lcs = 2.0 * _lcsLength(s1, s2) / (s1.length + s2.length);
      if (lcs > best) best = lcs;
      // Character-set Dice coefficient (order-independent).
      final set1 = s1.runes.toSet();
      final set2 = s2.runes.toSet();
      final shared = set1.intersection(set2).length;
      final dice = 2.0 * shared / (set1.length + set2.length);
      if (dice > best) best = dice;
      // Containment: if one contains the other, high score.
      if (s1.contains(s2) || s2.contains(s1)) {
        final shorter = s1.length < s2.length ? s1.length : s2.length;
        final longer = s1.length > s2.length ? s1.length : s2.length;
        final cont = shorter / longer;
        // Guarantee at least 0.7 for containment.
        final score = 0.7 + 0.3 * cont;
        if (score > best) best = score;
      }
    }
    return best;
  }

  /// Longest common subsequence length (O(n*m) but strings are short titles).
  static int _lcsLength(String a, String b) {
    final n = a.length, m = b.length;
    // Use two rows to save memory.
    var prev = List.filled(m + 1, 0);
    var curr = List.filled(m + 1, 0);
    for (int i = 1; i <= n; i++) {
      for (int j = 1; j <= m; j++) {
        if (a[i - 1] == b[j - 1]) {
          curr[j] = prev[j - 1] + 1;
        } else {
          curr[j] = prev[j] > curr[j - 1] ? prev[j] : curr[j - 1];
        }
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
      curr.fillRange(0, m + 1, 0);
    }
    return prev[m];
  }

  static Future<List<({String title, String url})>> _searchAnime1Single(
      String query) async {
    final url = Uri.parse(
      'https://anime1.me/?s=${Uri.encodeComponent(query)}',
    );
    final resp = await http.get(url, headers: {
      'User-Agent': _userAgent,
    }).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return [];

    final html = utf8.decode(resp.bodyBytes);
    final results = <({String title, String url})>[];
    final seen = <String>{};

    // Priority 1: category links — these are the collection/series pages.
    // anime1.me search results contain category tags like:
    // <a href="https://anime1.me/category/..." rel="category tag">Title</a>
    final catPattern = RegExp(
      r'<a[^>]*href="(https://anime1\.me/category/[^"]+)"[^>]*rel="[^"]*category[^"]*"[^>]*>([^<]+)</a>',
    );
    for (final match in catPattern.allMatches(html)) {
      final href = match.group(1);
      final title = match.group(2)?.trim();
      if (href != null && title != null && title.isNotEmpty) {
        if (seen.add(title)) {
          results.add((title: _decodeHtmlEntities(title), url: href));
        }
      }
    }

    // Priority 2: links with "/?cat=" pattern
    if (results.isEmpty) {
      final catIdPattern = RegExp(
        r'<a[^>]*href="(https://anime1\.me/\?cat=\d+)"[^>]*>([^<]+)</a>',
      );
      for (final match in catIdPattern.allMatches(html)) {
        final href = match.group(1);
        final title = match.group(2)?.trim();
        if (href != null && title != null && title.isNotEmpty) {
          if (seen.add(title)) {
            results.add((title: _decodeHtmlEntities(title), url: href));
          }
        }
      }
    }

    // Priority 3: fall back to entry-title links but strip episode numbers
    // so we can deduplicate the same series
    if (results.isEmpty) {
      final titlePattern = RegExp(
        r'<h2[^>]*class="[^"]*entry-title[^"]*"[^>]*>\s*<a[^>]*href="([^"]+)"[^>]*>([^<]+)</a>',
        dotAll: true,
      );
      for (final match in titlePattern.allMatches(html)) {
        final href = match.group(1);
        final rawTitle = match.group(2)?.trim();
        if (href != null && rawTitle != null && rawTitle.isNotEmpty) {
          // Strip episode suffix like " [34]" or " [1]"
          final cleanTitle =
              _decodeHtmlEntities(rawTitle.replaceAll(RegExp(r'\s*\[\d+\]\s*$'), ''));
          if (seen.add(cleanTitle)) {
            results.add((title: cleanTitle, url: href));
          }
        }
      }
    }

    return results;
  }

  static String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }
}
