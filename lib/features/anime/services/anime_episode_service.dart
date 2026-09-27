import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import '../../../shared/utils/season_label.dart';
import '../models/anime.dart';
import '../models/anime_episode.dart';
import 'anime1_service.dart';
import 'anime_search_service.dart';
import 'anime_storage.dart';

/// Resolved links are deliberately derived, so changing local ranges cannot leave stale keys.
class AnimeEpisodeResolution {
  final Map<int, AnimeEpisodePage> links;
  final bool needsConfirmation;
  final String? group;
  final int? first;

  /// Purpose: Return one season's mapping together with its uncertainty.
  /// Inputs: Resolved links, season title group and first site number.
  /// Returns: Resolution result.
  /// Side effects: None.
  /// Notes: Missing links are not proof that an episode has not aired.
  const AnimeEpisodeResolution(
    this.links, {
    required this.needsConfirmation,
    this.group,
    this.first,
  });
}

class AnimeEpisodeService {
  static final _pending = <String, Future<bool>>{};
  static final _retryAfter = <String, DateTime>{};

  /// Purpose: Refresh a due public directory once for concurrent UI callers.
  /// Inputs: Current record and optional explicit refresh.
  /// Returns: Whether a complete directory is available.
  /// Side effects: Network and guarded external-metadata storage patch.
  /// Notes: Callers must gate on full builds; a failed request backs off for one hour.
  static Future<bool> ensure(Anime anime, {bool force = false}) {
    final source = anime.watchUrl?.trim();
    if (source == null || !isPageUrl(source)) return Future.value(false);
    final key = '${anime.id}\n$source';
    final active = _pending[key];
    if (active != null) return active;
    final cached = catalogFor(anime);
    final now = DateTime.now().toUtc();
    final ttl = Duration(
      hours: anime.validWatchProgress?.ongoing == false ? 168 : 6,
    );
    if (!force &&
        cached?.complete == true &&
        now.difference(cached!.checkedAt) < ttl) {
      return Future.value(true);
    }
    if (!force && (_retryAfter[key]?.isAfter(now) ?? false)) {
      return Future.value(false);
    }
    final future = _refresh(anime, source)
        .then((complete) {
          if (!complete) {
            _retryAfter[key] = DateTime.now().toUtc().add(
              const Duration(hours: 1),
            );
          } else {
            _retryAfter.remove(key);
          }
          return complete;
        })
        .whenComplete(() {
          _pending.remove(key);
        });
    _pending[key] = future;
    return future;
  }

  /// Purpose: Fetch a snapshot and guard its write against a changed viewing URL.
  /// Inputs: Record identity and captured source.
  /// Returns: Directory completeness.
  /// Side effects: Index/page requests and cache write.
  /// Notes: Does not change watching progress or manual corrections.
  static Future<bool> _refresh(Anime anime, String source) async {
    try {
      var index = <Anime1IndexEntry>[];
      try {
        index = await Anime1Service.loadIndex();
      } catch (_) {
        /* Directory still works offline from the index. */
      }
      final catalog = await fetch(source, index: index);
      if (catalog.pages.isNotEmpty) {
        await AnimeStorage.patchExternalMeta(
          {anime.id: AnimeExternalMeta(episodeCatalog: catalog)},
          expectedWatchUrls: {anime.id: source},
        );
      }
      return catalog.complete;
    } catch (_) {
      return false;
    }
  }

  /// Purpose: Restrict fetched pages to the configured Anime1 website.
  /// Inputs: Absolute URL.
  /// Returns: Whether HTTPS and the site's exact host match.
  /// Side effects: None.
  /// Notes: Media CDN hosts are handled separately by the playback resolver.
  static bool isPageUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri?.scheme == 'https' &&
        uri?.host == 'anime1.me' &&
        uri?.userInfo == '';
  }

  /// Purpose: Read a cached directory only for the current viewing source.
  /// Inputs: Anime record.
  /// Returns: Valid directory or null.
  /// Side effects: None.
  /// Notes: Editing a watch URL immediately invalidates its former directory.
  static AnimeEpisodeCatalog? catalogFor(Anime anime) {
    final catalog = anime.externalMeta?.episodeCatalog;
    return catalog?.sourceUrl == anime.watchUrl?.trim() ? catalog : null;
  }

  /// Purpose: Fetch one complete public page with a bounded request time.
  /// Inputs: Page URL and injectable HTTP client.
  /// Returns: HTML text.
  /// Side effects: Network GET.
  /// Notes: Fails closed on redirects leaving Anime1.
  static Future<String> getPage(String url, http.Client client) async {
    var uri = Uri.parse(url);
    for (var redirects = 0; redirects < 6; redirects++) {
      if (!isPageUrl(uri.toString())) {
        throw const FormatException('Invalid page host');
      }
      final request = http.Request('GET', uri)..followRedirects = false;
      request.headers['User-Agent'] = AnimeSearchService.userAgent;
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 15));
      final bytes = await response.stream.toBytes().timeout(
        const Duration(seconds: 15),
      );
      if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
        final location = response.headers['location'];
        if (location == null) throw const FormatException('Missing redirect');
        uri = uri.resolve(location);
        continue;
      }
      if (response.statusCode != 200) throw StateError('Page unavailable');
      return utf8.decode(bytes);
    }
    throw StateError('Too many redirects');
  }

  /// Purpose: Parse article links without reading sidebar recommendations as episodes.
  /// Inputs: HTML and absolute page URL.
  /// Returns: Pages, category identity and older-page navigation.
  /// Side effects: None.
  /// Notes: Unknown markup never establishes directory completeness.
  static ({
    List<AnimeEpisodePage> pages,
    String? next,
    String? category,
    int? catId,
    String title,
    bool archive,
  })
  parsePage(String text, String url) {
    final document = html.parse(text);
    final base = Uri.parse(url);
    final body = document.body?.classes ?? <String>{};
    final cat = body
        .where((c) => RegExp(r'^category-\d+$').hasMatch(c))
        .firstOrNull;
    final pages = <AnimeEpisodePage>[];
    for (final article in document.querySelectorAll('article')) {
      final heading = article.querySelector('.entry-title');
      if (heading == null) continue;
      final title = heading.text.trim();
      final match = RegExp(
        r'[\[【]([^\]】]+)[\]】]\s*$',
      ).firstMatch(halfWidthAscii(title));
      if (match == null) continue;
      final href =
          heading.querySelector('a[href]')?.attributes['href'] ??
          document.querySelector('link[rel="canonical"]')?.attributes['href'];
      if (href == null) continue;
      final target = base.resolve(href).toString();
      if (!isPageUrl(target)) continue;
      pages.add(
        AnimeEpisodePage(
          url: target,
          title: title,
          label: match.group(1)!.trim(),
          group: halfWidthAscii(title).substring(0, match.start).trim(),
        ),
      );
    }
    final next = document
        .querySelector(
          '.nav-previous a[href], a.next.page-numbers, a[rel="next"]',
        )
        ?.attributes['href'];
    final category = document
        .querySelector('article a[rel~="category"][href]')
        ?.attributes['href'];
    return (
      pages: pages,
      next: next == null ? null : base.resolve(next).toString(),
      category: category == null ? null : base.resolve(category).toString(),
      catId: cat == null ? null : int.tryParse(cat.substring(9)),
      title:
          document
              .querySelector('.page-title')
              ?.text
              .replaceFirst(RegExp(r'^.*?[:：]\s*'), '')
              .trim() ??
          '',
      archive: body.contains('archive') || body.contains('category'),
    );
  }

  /// Purpose: Traverse an Anime1 collection, retaining partial results on page failure.
  /// Inputs: Saved URL, optional index and HTTP client.
  /// Returns: Public directory snapshot.
  /// Side effects: Bounded serial HTTP requests; closes only an owned client.
  /// Notes: A 100-page safety limit and repeated pagination both mark the result incomplete.
  static Future<AnimeEpisodeCatalog> fetch(
    String sourceUrl, {
    List<Anime1IndexEntry> index = const [],
    http.Client? client,
  }) async {
    final transport = client ?? http.Client();
    final source = sourceUrl.trim();
    var category = source;
    var title = '';
    int? catId = Anime1Service.catIdFromUrl(source);
    final pages = <String, AnimeEpisodePage>{};
    final visited = <String>{};
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    var complete = false;
    String? next = source;
    try {
      for (var count = 0; next != null && count < 100; count++) {
        if (DateTime.now().isAfter(deadline)) break;
        if (!visited.add(next)) break;
        final parsed = parsePage(await getPage(next, transport), next);
        if (!parsed.archive) {
          if (count == 0 && parsed.category != null) {
            category = parsed.category!;
            next = category;
            continue;
          }
          break;
        }
        catId ??= parsed.catId;
        if (title.isEmpty) title = parsed.title;
        for (final page in parsed.pages) {
          pages[page.url] = page;
        }
        // Empty/unrecognized archives may be challenge pages or changed markup.
        if (parsed.pages.isEmpty) break;
        next = parsed.next;
        if (next == null) complete = true;
      }
    } catch (_) {
      // Return usable public links, but never label an interrupted crawl complete.
    } finally {
      if (client == null) transport.close();
    }
    final entry = index.where((e) => e.catId == catId).firstOrNull;
    return AnimeEpisodeCatalog(
      sourceUrl: source,
      categoryUrl: category,
      title: title,
      catId: catId,
      indexTitle: entry?.title,
      indexEpisodes: entry?.episodesText,
      checkedAt: DateTime.now().toUtc(),
      complete: complete,
      pages: pages.values.toList(),
    );
  }

  /// Purpose: Compare season-bearing titles across script and punctuation variations.
  /// Inputs: Two titles.
  /// Returns: Whether their folded full titles match.
  /// Side effects: None.
  /// Notes: Does not erase season numbers or accept mere franchise resemblance.
  static bool _sameTitle(String a, String b) =>
      a.isNotEmpty &&
      b.isNotEmpty &&
      AnimeSearchService.foldTitle(a) == AnimeSearchService.foldTitle(b);

  /// Purpose: Select the current season and map its real numbers without closing gaps.
  /// Inputs: Anime, optional preview choices and library context.
  /// Returns: Per-local-episode links plus confirmation state.
  /// Side effects: None.
  /// Notes: Dates, counts and relationship order never manufacture a missing starting number.
  /// Since 1.6.6 the chosen collection's own Anime1 names (index title and
  /// page title) also identify its groups, so a Taiwan translation
  /// (还要与你相恋到生命尽头 vs 與妳相戀到生命盡頭) or an English prefix
  /// (GRAND BLUE 碧藍之海 第三季) no longer blocks the match. Every season
  /// guard still applies, and a different-season sibling on the same URL
  /// shares those names, so it keeps an unmarked group ambiguous.
  static AnimeEpisodeResolution resolve(
    Anime anime, {
    AnimeEpisodeMapping? choices,
    List<Anime> library = const [],
  }) {
    final catalog = catalogFor(anime);
    if (catalog == null) {
      return const AnimeEpisodeResolution({}, needsConfirmation: true);
    }
    final saved = choices ?? anime.episodeMapping;
    final manual = saved?.sourceUrl == anime.watchUrl?.trim() ? saved : null;
    final aliases = [
      anime.title,
      anime.titleJa,
      anime.externalMeta?.titleEn,
      anime.externalMeta?.titleRomaji,
      ...?anime.externalMeta?.synonyms,
    ].whereType<String>().toList();
    // The collection's own names on Anime1: the user chose this URL, so
    // they identify the work even when its translation differs locally.
    final siteNames = [
      catalog.indexTitle,
      catalog.title,
    ].whereType<String>().where((t) => t.trim().isNotEmpty).toList();
    final ordinal =
        titleSeasonOrdinal(anime.displayTitle) ?? seasonOrdinal(anime.season);
    final groups = catalog.pages
        .where((p) => p.number != null)
        .map((p) => p.group)
        .toSet();
    var group = manual?.group;
    if (group == null) {
      final candidates = groups.where((g) {
        final number = titleSeasonOrdinal(g);
        if (number != null && ordinal != null && number != ordinal) {
          return false;
        }
        // An unnumbered franchise title cannot identify a sequel on its own.
        if (number == null && ordinal != null && ordinal > 1) return false;
        bool names(List<String> titles) =>
            titles.any((a) => _sameTitle(a, g)) ||
            (number != null &&
                number == ordinal &&
                titles.any(
                  (a) =>
                      _sameTitle(stripSeasonMarkers(a), stripSeasonMarkers(g)),
                ));
        final viaSite = names(siteNames);
        if (!names(aliases) && !viaSite) return false;
        // A sibling sharing this unmarked title makes the season boundary ambiguous.
        return number != null ||
            !library.any(
              (a) =>
                  a.id != anime.id &&
                  a.watchUrl == anime.watchUrl &&
                  a.season != anime.season &&
                  // A sibling on the same URL shares the collection's names.
                  (viaSite ||
                      _sameTitle(
                        stripSeasonMarkers(a.displayTitle),
                        stripSeasonMarkers(g),
                      )),
            );
      }).toList();
      if (candidates.length == 1) group = candidates.single;
    }
    final scoped = catalog.pages
        .where((p) => group != null && p.group == group)
        .toList();
    var first = manual?.first;
    if (first == null && catalog.complete && group != null) {
      final raw = catalog.indexEpisodes;
      if (raw != null &&
          _sameTitle(catalog.indexTitle ?? '', group) &&
          groups.length == 1) {
        final range = Anime1Service.parseEpisodes(raw);
        if (range.kind == Anime1EpisodeKind.range) first = range.first;
      }
      if (first == null && scoped.where((p) => p.number == 1).length == 1) {
        first = 1;
      }
    }
    final links = <int, AnimeEpisodePage>{};
    var ambiguous = group == null || first == null;
    if (first != null && group != null) {
      final numbered = <int, List<AnimeEpisodePage>>{};
      for (final p in scoped) {
        final n = p.number;
        if (n != null &&
            n >= first &&
            (manual?.last == null || n <= manual!.last!)) {
          numbered.putIfAbsent(n, () => []).add(p);
        }
      }
      for (final e in numbered.entries) {
        final local = anime.startEpisode + e.key - first;
        if (anime.endEpisode != null && local > anime.endEpisode!) continue;
        if (e.value.length == 1) {
          links[local] = e.value.single;
        } else {
          ambiguous = true;
        }
      }
    }
    for (final e in manual?.overrides.entries ?? <MapEntry<int, String>>[]) {
      links.remove(e.key);
      if (e.key < anime.startEpisode ||
          (anime.endEpisode != null && e.key > anime.endEpisode!)) {
        continue;
      }
      final page = catalog.pages.where((p) => p.url == e.value).firstOrNull;
      if (page != null) links[e.key] = page;
    }
    return AnimeEpisodeResolution(
      links,
      needsConfirmation: ambiguous,
      group: group,
      first: first,
    );
  }
}
