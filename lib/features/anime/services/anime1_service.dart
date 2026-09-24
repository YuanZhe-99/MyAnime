import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;

import '../../../shared/utils/chinese_convert.dart';
import '../../../shared/utils/season_label.dart';
import '../models/anime.dart';
import 'anime_search_service.dart';

/// Release-format family parsed out of anime1.me's episode text.
enum Anime1EpisodeKind { range, ongoing, movie, special, other }

/// Parsed form of one `animelist.json` episode cell such as `1-12+OVA`.
class Anime1EpisodeInfo {
  /// The cell verbatim, always set; shown when nothing else applies.
  final String raw;

  final Anime1EpisodeKind kind;

  /// First and last episode of a completed run (`13-24` → 13, 24).
  final int? first;
  final int? last;

  /// The newest episode the site lists: `連載中(09)` → 9, `1-12` → 12.
  final int? latest;

  /// Text after the main range, e.g. `+OVA`, `+SP1-2`, `EP4`.
  final String? extras;

  /// Purpose: Create an episode info instance.
  /// Inputs: `raw`, `kind`, `first`, `last`, `latest`, `extras`.
  /// Returns: A new `Anime1EpisodeInfo` instance.
  /// Side effects: None.
  /// Notes: None.
  const Anime1EpisodeInfo({
    required this.raw,
    required this.kind,
    this.first,
    this.last,
    this.latest,
    this.extras,
  });

  /// Purpose: Report whether the site marks the series as still updating.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get isOngoing => kind == Anime1EpisodeKind.ongoing;
}

/// One row of anime1.me's `animelist.json` series index.
class Anime1IndexEntry {
  final int catId;

  /// Entity-decoded, trimmed display title.
  final String title;

  /// `AnimeSearchService.foldTitle(title)`, computed once at parse time.
  final String foldedTitle;

  final String episodesText;

  /// Four-digit year, or empty.
  final String year;

  /// 春 / 夏 / 秋 / 冬, or empty.
  final String season;

  final String fansub;

  /// Purpose: Create an index entry instance.
  /// Inputs: `catId`, `title`, `foldedTitle`, `episodesText`, `year`, `season`, `fansub`.
  /// Returns: A new `Anime1IndexEntry` instance.
  /// Side effects: None.
  /// Notes: None.
  const Anime1IndexEntry({
    required this.catId,
    required this.title,
    required this.foldedTitle,
    required this.episodesText,
    this.year = '',
    this.season = '',
    this.fansub = '',
  });

  /// Purpose: Return the series page URL the site's own list links to.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: The site answers with a 301 to the `/category/…` slug; the id form
  /// is stored because it survives a title change and resolves without a request.
  String get url => 'https://anime1.me/?cat=$catId';

  /// Purpose: Parse this row's episode cell.
  /// Inputs: None.
  /// Returns: `Anime1EpisodeInfo`.
  /// Side effects: None.
  /// Notes: None.
  Anime1EpisodeInfo get episodes => Anime1Service.parseEpisodes(episodesText);
}

/// One ranked watch-URL candidate returned by [Anime1Service.search].
class Anime1Match {
  final String title;
  final String url;

  /// Null for hits found through the `?s=` scrape fallback.
  final int? catId;
  final Anime1EpisodeInfo? episodes;
  final String? year;
  final String? season;
  final String? fansub;

  /// Ranking score; may exceed 1.0 once season boosts are added.
  final double score;

  /// True when the hit needed aliases harvested from bangumi.tv.
  final bool viaAliases;

  /// Purpose: Create a match instance.
  /// Inputs: `title`, `url`, `catId`, `episodes`, `year`, `season`, `fansub`, `score`, `viaAliases`.
  /// Returns: A new `Anime1Match` instance.
  /// Side effects: None.
  /// Notes: None.
  const Anime1Match({
    required this.title,
    required this.url,
    required this.score,
    this.catId,
    this.episodes,
    this.year,
    this.season,
    this.fansub,
    this.viaAliases = false,
  });

  /// Purpose: Build a match from an index row.
  /// Inputs: `entry`, `score`, `viaAliases`.
  /// Returns: A new `Anime1Match`.
  /// Side effects: None.
  /// Notes: Blank cells become `null` so the UI can skip them.
  factory Anime1Match.fromIndex(
    Anime1IndexEntry entry,
    double score, {
    bool viaAliases = false,
  }) => Anime1Match(
    title: entry.title,
    url: entry.url,
    catId: entry.catId,
    episodes: entry.episodes,
    year: entry.year.isEmpty ? null : entry.year,
    season: entry.season.isEmpty ? null : entry.season,
    fansub: entry.fansub.isEmpty ? null : entry.fansub,
    score: score,
    viaAliases: viaAliases,
  );

  /// Purpose: Build a match from a scraped search-result link.
  /// Inputs: `title`, `url`, `score`.
  /// Returns: A new `Anime1Match`.
  /// Side effects: None.
  /// Notes: Carries no episode or season data.
  factory Anime1Match.fromScrape({
    required String title,
    required String url,
    required double score,
  }) => Anime1Match(title: title, url: url, score: score);

  /// Purpose: Convert this match into the persisted watch-progress record.
  /// Inputs: `now`.
  /// Returns: `AnimeWatchProgress` keyed to this match's URL.
  /// Side effects: None.
  /// Notes: A scrape hit yields a record with no episode data but a
  /// `checkedAt`, so the background refresher still schedules it normally.
  AnimeWatchProgress toProgress(DateTime now) => AnimeWatchProgress(
    sourceUrl: url,
    catId: catId,
    latestEpisode: episodes?.latest,
    episodesText: episodes?.raw,
    ongoing: episodes?.isOngoing ?? false,
    checkedAt: now.toUtc(),
  );

  /// Purpose: Return a copy flagged as found through harvested aliases.
  /// Inputs: None.
  /// Returns: `Anime1Match`.
  /// Side effects: None.
  /// Notes: None.
  Anime1Match markedViaAliases() => Anime1Match(
    title: title,
    url: url,
    catId: catId,
    episodes: episodes,
    year: year,
    season: season,
    fansub: fansub,
    score: score,
    viaAliases: true,
  );
}

/// anime1.me watch-URL lookup and update-progress reader.
///
/// Index-first: the site publishes its whole catalogue as `animelist.json`,
/// so matching is done locally against every row. The WordPress `?s=` search
/// only matches exact Traditional substrings and is kept as the last resort.
class Anime1Service {
  /// Purpose: Prevent direct instantiation and expose only static members.
  /// Inputs: None.
  /// Returns: A new `Anime1Service._` instance.
  /// Side effects: None.
  /// Notes: None.
  const Anime1Service._();

  static const indexUrl = 'https://anime1.me/animelist.json';
  static const _indexTtl = Duration(minutes: 30);
  static const _indexTimeout = Duration(seconds: 15);
  static const _pageTimeout = Duration(seconds: 15);

  /// Minimum folded similarity for an index row to be offered at all.
  /// Containment floors any "same franchise ± subtitle" pair at 0.7; 0.5 sits
  /// above the 0.45 backfill threshold because 1,900 candidates make false
  /// positives visible in a ten-row list.
  static const minScore = 0.5;

  /// Below this top score the alias harvest is attempted.
  static const confidentScore = 0.9;

  /// Added when a row's year/season equals the record's premiere quarter.
  /// Sibling seasons differ by at most ~0.04 on containment, so 0.10 settles
  /// them without lifting a partial hit over an exact one.
  static const seasonBoost = 0.10;

  /// Added when the row's quarter is one away from the record's.
  static const adjacentSeasonBoost = 0.03;

  /// Added when the row's 第N季 ordinal equals the record's.
  static const ordinalBoost = 0.10;

  /// Subtracted when the record names a season and the row names a different
  /// one (a row with no ordinal is the first season).
  static const ordinalMismatchPenalty = 0.05;

  /// Minimum order-aware similarity (LCS-Dice or containment) a row must also
  /// reach. The set-based Dice term inside [minScore] is blind to order, and
  /// on short Latin strings it scores unrelated titles at 0.5.
  static const minOrderedScore = 0.4;

  static const _maxResults = 10;
  static const _maxQueries = 12;
  static const _minQueryRunes = 2;
  static const _maxScrapeVariants = 6;

  static List<Anime1IndexEntry>? _index;
  static DateTime? _indexFetchedAt;
  static Future<List<Anime1IndexEntry>>? _inFlight;

  // ──── Index ────

  /// Purpose: Return the series index, fetching it at most once per TTL.
  /// Inputs: `forceRefresh`.
  /// Returns: `Future<List<Anime1IndexEntry>>`.
  /// Side effects: At most one HTTP GET; updates the in-memory cache.
  /// Notes: Concurrent callers share one request. A failed refresh keeps
  /// serving the stale copy; only a first-ever failure throws.
  static Future<List<Anime1IndexEntry>> loadIndex({
    bool forceRefresh = false,
  }) async {
    final cached = _index;
    final fetchedAt = _indexFetchedAt;
    if (!forceRefresh &&
        cached != null &&
        fetchedAt != null &&
        DateTime.now().difference(fetchedAt) < _indexTtl) {
      return cached;
    }
    final running = _inFlight;
    if (running != null) return running;
    final future = _fetchIndex();
    _inFlight = future;
    try {
      final fresh = await future;
      _index = fresh;
      _indexFetchedAt = DateTime.now();
      return fresh;
    } catch (_) {
      if (cached != null) return cached;
      rethrow;
    } finally {
      _inFlight = null;
    }
  }

  /// Purpose: Drop the cached index.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Clears the static cache.
  /// Notes: For tests.
  @visibleForTesting
  static void resetIndexCache() {
    _index = null;
    _indexFetchedAt = null;
    _inFlight = null;
  }

  /// Purpose: Download and parse `animelist.json`.
  /// Inputs: None.
  /// Returns: `Future<List<Anime1IndexEntry>>`.
  /// Side effects: One HTTP GET (15 s timeout).
  /// Notes: Internal helper used within this file only. An empty parse is
  /// treated as a failure so a broken deploy cannot replace a good cache.
  static Future<List<Anime1IndexEntry>> _fetchIndex() async {
    final resp = await http
        .get(
          Uri.parse(indexUrl),
          headers: {
            'User-Agent': AnimeSearchService.userAgent,
            'Accept': 'application/json',
          },
        )
        .timeout(_indexTimeout);
    if (resp.statusCode != 200) {
      throw StateError('anime1 index HTTP ${resp.statusCode}');
    }
    final entries = parseIndex(utf8.decode(resp.bodyBytes));
    if (entries.isEmpty) throw StateError('anime1 index is empty');
    return entries;
  }

  /// Purpose: Parse the index JSON into entries.
  /// Inputs: `jsonText` — a bare array of rows, or an object with a `data` array.
  /// Returns: `List<Anime1IndexEntry>` in file order (newest-updated first).
  /// Side effects: None.
  /// Notes: Rows are `[catId, title, episodesText, year, season, fansub]`.
  /// Rows without an integer id or a title are skipped; missing trailing
  /// cells read as empty.
  @visibleForTesting
  static List<Anime1IndexEntry> parseIndex(String jsonText) {
    final decoded = jsonDecode(jsonText);
    final rows = decoded is List
        ? decoded
        : decoded is Map
        ? decoded['data']
        : null;
    if (rows is! List) return const [];
    final out = <Anime1IndexEntry>[];
    for (final row in rows) {
      if (row is! List || row.length < 3) continue;
      final rawId = row[0];
      final id = rawId is int ? rawId : int.tryParse('$rawId');
      if (id == null) continue;
      String cell(int i) =>
          i < row.length && row[i] != null ? '${row[i]}'.trim() : '';
      final title = AnimeSearchService.decodeHtmlEntities(cell(1));
      if (title.isEmpty) continue;
      out.add(
        Anime1IndexEntry(
          catId: id,
          title: title,
          foldedTitle: AnimeSearchService.foldTitle(title),
          episodesText: cell(2),
          year: cell(3),
          season: cell(4),
          fansub: cell(5),
        ),
      );
    }
    return out;
  }

  // ──── Pure parsers ────

  /// Purpose: Parse an episode cell such as `1-12+OVA` or `連載中(09)`.
  /// Inputs: `text`.
  /// Returns: `Anime1EpisodeInfo`; `raw` always holds the trimmed input.
  /// Side effects: None.
  /// Notes: Rules in priority order: `連載中(N…)` → ongoing with `latest = N`;
  /// `A-B[.x][extras]` → range; a bare integer → one-episode range; text
  /// containing 劇場版 → movie, 特別編 → special; anything else (`OVA`, `SP`,
  /// `ONA`) → other. Only the leading integer of an ongoing cell is trusted.
  static Anime1EpisodeInfo parseEpisodes(String text) {
    final raw = text.trim();
    final ongoing = RegExp(r'^連載中\s*\((\d+)([^)]*)\)').firstMatch(raw);
    if (ongoing != null) {
      final extras = ongoing.group(2)!.trim();
      return Anime1EpisodeInfo(
        raw: raw,
        kind: Anime1EpisodeKind.ongoing,
        latest: int.parse(ongoing.group(1)!),
        extras: extras.isEmpty ? null : extras,
      );
    }
    final range = RegExp(r'^(\d+)\s*-\s*(\d+)(?:\.\d+)?(.*)$').firstMatch(raw);
    if (range != null) {
      final first = int.parse(range.group(1)!);
      final last = int.parse(range.group(2)!);
      final extras = range.group(3)!.trim();
      return Anime1EpisodeInfo(
        raw: raw,
        kind: Anime1EpisodeKind.range,
        first: first,
        last: last,
        latest: last,
        extras: extras.isEmpty ? null : extras,
      );
    }
    final single = RegExp(r'^(\d+)$').firstMatch(raw);
    if (single != null) {
      final n = int.parse(single.group(1)!);
      return Anime1EpisodeInfo(
        raw: raw,
        kind: Anime1EpisodeKind.range,
        first: n,
        last: n,
        latest: n,
      );
    }
    if (raw.contains('劇場版')) {
      return Anime1EpisodeInfo(raw: raw, kind: Anime1EpisodeKind.movie);
    }
    if (raw.contains('特別編')) {
      return Anime1EpisodeInfo(raw: raw, kind: Anime1EpisodeKind.special);
    }
    return Anime1EpisodeInfo(raw: raw, kind: Anime1EpisodeKind.other);
  }

  /// Purpose: Place a row's year/season on a continuous quarter timeline.
  /// Inputs: `year`, `season` — 冬 = 0, 春 = 1, 夏 = 2, 秋 = 3.
  /// Returns: `int?` — `year * 4 + season`, or `null` when unparseable.
  /// Side effects: None.
  /// Notes: A combined cell such as `春/秋` uses its first season.
  @visibleForTesting
  static int? seasonIndex(String year, String season) {
    final y = int.tryParse(year.trim());
    if (y == null) return null;
    const order = ['冬', '春', '夏', '秋'];
    for (final ch in season.runes) {
      final i = order.indexOf(String.fromCharCode(ch));
      if (i >= 0) return y * 4 + i;
    }
    return null;
  }

  /// Purpose: Place a premiere date on the same quarter timeline as [seasonIndex].
  /// Inputs: `firstAirDate`.
  /// Returns: `int?`.
  /// Side effects: None.
  /// Notes: A premiere on or after the 21st of a quarter's last month is
  /// filed under the next quarter — a 29 September show is a 秋 show, which
  /// is how anime1 files it.
  @visibleForTesting
  static int? quarterIndexFor(DateTime? firstAirDate) {
    if (firstAirDate == null) return null;
    var idx = firstAirDate.year * 4 + (firstAirDate.month - 1) ~/ 3;
    if (firstAirDate.month % 3 == 0 && firstAirDate.day >= 21) idx += 1;
    return idx;
  }

  /// Purpose: Build the folded query set for one lookup.
  /// Inputs: `query`, `altQueries`.
  /// Returns: `List<String>` — folded, deduplicated, at most 12 entries.
  /// Side effects: None.
  /// Notes: Queries shorter than two runes are dropped; a single character
  /// matches half the catalogue.
  @visibleForTesting
  static List<String> querySet(String query, List<String> altQueries) {
    final out = <String>[];
    final seen = <String>{};
    for (final q in [query, ...altQueries]) {
      final folded = AnimeSearchService.foldTitle(q);
      if (folded.runes.length < _minQueryRunes) continue;
      if (seen.add(folded)) out.add(folded);
      if (out.length >= _maxQueries) break;
    }
    return out;
  }

  /// Purpose: Score and order index rows against folded queries.
  /// Inputs: `entries`, `foldedQueries`; `quarterIndex` — the record's
  /// premiere quarter from [quarterIndexFor]; `ordinal` — the record's season
  /// ordinal; `minScore`; `limit`.
  /// Returns: `List<Anime1Match>` best first.
  /// Side effects: None.
  /// Notes: Base score is the best folded similarity over the queries; rows
  /// below `minScore` are dropped; season and ordinal agreement add the boost
  /// constants. Ties keep file order, which is newest-updated first.
  @visibleForTesting
  static List<Anime1Match> rank(
    List<Anime1IndexEntry> entries,
    List<String> foldedQueries, {
    int? quarterIndex,
    int? ordinal,
    double minScore = minScore,
    int limit = _maxResults,
  }) {
    if (foldedQueries.isEmpty) return const [];
    final scored = <(int, double, Anime1IndexEntry)>[];
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      if (e.foldedTitle.isEmpty) continue;
      var best = 0.0;
      var ordered = 0.0;
      for (final q in foldedQueries) {
        final s = AnimeSearchService.similarityRaw(e.foldedTitle, q);
        if (s > best) best = s;
        final o = AnimeSearchService.orderedSimilarity(e.foldedTitle, q);
        if (o > ordered) ordered = o;
      }
      if (best < minScore || ordered < minOrderedScore) continue;
      var score = best;
      final rowQuarter = seasonIndex(e.year, e.season);
      if (quarterIndex != null && rowQuarter != null) {
        final diff = (rowQuarter - quarterIndex).abs();
        if (diff == 0) {
          score += seasonBoost;
        } else if (diff == 1) {
          score += adjacentSeasonBoost;
        }
      }
      if (ordinal != null) {
        final rowOrdinal = seasonOrdinal(e.title);
        if (rowOrdinal == ordinal) {
          score += ordinalBoost;
        } else if (rowOrdinal != null || ordinal >= 2) {
          // A row without an ordinal is the first season; when the record
          // asks for a sequel it must not tie with the exact-title base row.
          score -= ordinalMismatchPenalty;
        }
      }
      scored.add((i, score, e));
    }
    scored.sort((a, b) {
      final cmp = b.$2.compareTo(a.$2);
      return cmp != 0 ? cmp : a.$1.compareTo(b.$1);
    });
    return [
      for (final s in scored.take(limit)) Anime1Match.fromIndex(s.$3, s.$2),
    ];
  }

  // ──── Search ────

  /// Purpose: Find anime1.me series pages for a record, index-first.
  /// Inputs: `query` — the display title; `altQueries` — Japanese, English,
  /// romaji titles and stored synonyms; `firstAirDate` — enables the season
  /// boost; `seasonText` — the record's season label, read for an ordinal;
  /// `harvestAliases` — allow one bangumi.tv query for aliases.
  /// Returns: `Future<List<Anime1Match>>`, best first, at most ten.
  /// Side effects: At most one index GET per 30 minutes, at most one
  /// bangumi.tv POST, and the `?s=` scrape only when the index is unreachable
  /// or matched nothing.
  /// Notes: The alias harvest runs when no row reaches [confidentScore] and no
  /// Chinese alias is already stored — a mainland title and a Taiwanese one
  /// can share no characters at all, and bangumi.tv's 别名 usually lists both.
  static Future<List<Anime1Match>> search(
    String query, {
    List<String> altQueries = const [],
    DateTime? firstAirDate,
    String? seasonText,
    bool harvestAliases = true,
  }) async {
    final queries = querySet(query, altQueries);
    if (queries.isEmpty) return const [];

    List<Anime1IndexEntry>? entries;
    try {
      entries = await loadIndex();
    } catch (_) {
      entries = null;
    }
    final quarter = quarterIndexFor(firstAirDate);
    final ordinal =
        seasonOrdinal(query) ??
        (seasonText == null ? null : seasonOrdinal(seasonText));

    var matches = entries == null
        ? <Anime1Match>[]
        : rank(entries, queries, quarterIndex: quarter, ordinal: ordinal);

    final needAliases =
        harvestAliases &&
        entries != null &&
        (matches.isEmpty || matches.first.score < confidentScore) &&
        !altQueries.any(_isLikelyChinese);
    if (needAliases) {
      var aliases = const <String>[];
      try {
        aliases = await AnimeSearchService.harvestAliases(query);
      } catch (_) {}
      if (aliases.isNotEmpty) {
        final again = rank(
          entries,
          querySet(query, [...altQueries, ...aliases]),
          quarterIndex: quarter,
          ordinal: ordinal,
        );
        matches = _mergeMatches(matches, again);
      }
    }
    if (matches.isNotEmpty) return matches;
    return _scrapeSearch(query, altQueries);
  }

  /// Purpose: Merge an alias-assisted ranking into the base ranking.
  /// Inputs: `base`, `again`.
  /// Returns: `List<Anime1Match>` best first, at most ten.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Rows are keyed by
  /// URL; the higher score wins, and a row that is new or improved is flagged
  /// `viaAliases` so the dialog can say where it came from.
  static List<Anime1Match> _mergeMatches(
    List<Anime1Match> base,
    List<Anime1Match> again,
  ) {
    final byUrl = <String, Anime1Match>{for (final m in base) m.url: m};
    for (final m in again) {
      final existing = byUrl[m.url];
      if (existing == null || m.score > existing.score) {
        byUrl[m.url] = m.markedViaAliases();
      }
    }
    final merged = byUrl.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return merged.take(_maxResults).toList();
  }

  /// Purpose: Check whether a string reads as Chinese (Han, no kana).
  /// Inputs: `s`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static bool _isLikelyChinese(String s) {
    var han = false;
    for (final c in s.runes) {
      if ((c >= 0x3040 && c <= 0x30FF)) return false;
      if (c >= 0x4E00 && c <= 0x9FFF) han = true;
    }
    return han;
  }

  // ──── Progress ────

  /// Purpose: Report whether a URL points at anime1.me.
  /// Inputs: `url`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Accepts the bare host and any subdomain.
  static bool isAnime1Url(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final host = Uri.tryParse(url.trim())?.host.toLowerCase();
    if (host == null) return false;
    return host == 'anime1.me' || host.endsWith('.anime1.me');
  }

  /// Purpose: Read the category id out of a `?cat=` URL.
  /// Inputs: `url`.
  /// Returns: `int?` — `null` for slug URLs and anything else.
  /// Side effects: None.
  /// Notes: None.
  static int? catIdFromUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    return int.tryParse(uri.queryParameters['cat'] ?? '');
  }

  /// Purpose: Extract the category id, title, newest episode and category
  /// link from a series or episode page.
  /// Inputs: `html`.
  /// Returns: A record of `catId`, `title`, `latestEpisode`, `categoryUrl`;
  /// each `null` when absent.
  /// Side effects: None.
  /// Notes: `latestEpisode` is the largest integer `[N]` suffix among the
  /// `entry-title` posts (`[OVA]` and `[SP1]` are ignored, `[12.5]` reads as
  /// 12). `categoryUrl` is the first `rel="category tag"` link, which is how
  /// an episode post points back at its series.
  @visibleForTesting
  static ({int? catId, String? title, int? latestEpisode, String? categoryUrl})
  parseCategoryPage(String html) {
    final catId = int.tryParse(
      RegExp(
            r'<body[^>]*class="[^"]*\bcategory-(\d+)\b',
          ).firstMatch(html)?.group(1) ??
          '',
    );
    final rawTitle = RegExp(
      r'<h1[^>]*class="[^"]*page-title[^"]*"[^>]*>(.*?)</h1>',
      dotAll: true,
    ).firstMatch(html)?.group(1);
    final title = rawTitle == null
        ? null
        : AnimeSearchService.decodeHtmlEntities(
            rawTitle.replaceAll(RegExp(r'<[^>]+>'), ''),
          ).trim();
    int? latest;
    final entry = RegExp(
      r'<h2[^>]*class="[^"]*entry-title[^"]*"[^>]*>\s*<a[^>]*>([^<]*)</a>',
      dotAll: true,
    );
    for (final m in entry.allMatches(html)) {
      final n = RegExp(r'\[(\d+)(?:\.\d+)?\]\s*$').firstMatch(m.group(1)!.trim());
      if (n == null) continue;
      final value = int.parse(n.group(1)!);
      if (latest == null || value > latest) latest = value;
    }
    final categoryUrl = RegExp(
      r'<a[^>]*href="(https://anime1\.me/category/[^"]+)"[^>]*rel="[^"]*category[^"]*"',
    ).firstMatch(html)?.group(1);
    return (
      catId: catId,
      title: title == null || title.isEmpty ? null : title,
      latestEpisode: latest,
      categoryUrl: categoryUrl,
    );
  }

  /// Purpose: Read what anime1.me currently lists for a saved watch URL.
  /// Inputs: `watchUrl`; `index` — a pre-loaded index to reuse.
  /// Returns: `Future<AnimeWatchProgress?>` — `null` when the URL is not
  /// anime1.me or nothing could be read.
  /// Side effects: Possibly one index GET and up to two page GETs.
  /// Notes: A `?cat=` URL resolves from the index with no page request. A
  /// `/category/…` slug, or an id the index lacks, fetches the page and reads
  /// the newest `[N]`; an episode-post URL follows its category link once.
  /// The index row is preferred whenever its id becomes known, because only
  /// the index says whether the run is still updating.
  static Future<AnimeWatchProgress?> fetchProgress(
    String watchUrl, {
    List<Anime1IndexEntry>? index,
  }) async {
    if (!isAnime1Url(watchUrl)) return null;
    final now = DateTime.now().toUtc();
    var entries = index;
    if (entries == null) {
      try {
        entries = await loadIndex();
      } catch (_) {
        entries = null;
      }
    }
    Anime1IndexEntry? row(int? id) {
      if (id == null || entries == null) return null;
      for (final e in entries) {
        if (e.catId == id) return e;
      }
      return null;
    }

    final direct = row(catIdFromUrl(watchUrl));
    if (direct != null) return _progressFromEntry(direct, watchUrl, now);

    try {
      var parsed = parseCategoryPage(await _getPage(watchUrl));
      if (parsed.catId == null &&
          parsed.latestEpisode == null &&
          parsed.categoryUrl != null) {
        parsed = parseCategoryPage(await _getPage(parsed.categoryUrl!));
      }
      final byPage = row(parsed.catId);
      if (byPage != null) return _progressFromEntry(byPage, watchUrl, now);
      if (parsed.latestEpisode == null && parsed.title == null) return null;
      return AnimeWatchProgress(
        sourceUrl: watchUrl,
        catId: parsed.catId,
        latestEpisode: parsed.latestEpisode,
        episodesText: parsed.latestEpisode?.toString(),
        ongoing: false,
        checkedAt: now,
      );
    } catch (_) {
      return null;
    }
  }

  /// Purpose: Build a progress record from an index row.
  /// Inputs: `entry`, `watchUrl`, `now`.
  /// Returns: `AnimeWatchProgress`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. `sourceUrl` keeps the
  /// URL as stored, so the record stays valid for the anime it was read for.
  static AnimeWatchProgress _progressFromEntry(
    Anime1IndexEntry entry,
    String watchUrl,
    DateTime now,
  ) {
    final ep = entry.episodes;
    return AnimeWatchProgress(
      sourceUrl: watchUrl,
      catId: entry.catId,
      latestEpisode: ep.latest,
      episodesText: ep.raw,
      ongoing: ep.isOngoing,
      checkedAt: now,
    );
  }

  /// Purpose: GET one anime1.me page as text.
  /// Inputs: `url`.
  /// Returns: `Future<String>`.
  /// Side effects: One HTTP GET (15 s timeout), following redirects.
  /// Notes: Internal helper used within this file only.
  static Future<String> _getPage(String url) async {
    final resp = await http
        .get(
          Uri.parse(url),
          headers: {'User-Agent': AnimeSearchService.userAgent},
        )
        .timeout(_pageTimeout);
    if (resp.statusCode != 200) {
      throw StateError('anime1 page HTTP ${resp.statusCode}');
    }
    return utf8.decode(resp.bodyBytes);
  }

  // ──── Scrape fallback ────

  /// Purpose: Search the site's own `?s=` endpoint, the pre-1.5.7 method.
  /// Inputs: `query`, `altQueries`.
  /// Returns: `Future<List<Anime1Match>>` ranked by fuzzy similarity.
  /// Side effects: Up to six sequential HTTP GETs, plus up to three bigram
  /// retries when nothing matched.
  /// Notes: Internal helper used within this file only. Only reached when the
  /// index is unreachable or matched nothing. The site search matches exact
  /// Traditional substrings only, hence the variant fan-out.
  static Future<List<Anime1Match>> _scrapeSearch(
    String query,
    List<String> altQueries,
  ) async {
    final variants = <String>{};
    for (final q in [query, ...altQueries]) {
      final t = q.trim();
      if (t.isEmpty) continue;
      variants
        ..add(t)
        ..add(ChineseConvert.toTraditional(t))
        ..add(ChineseConvert.toSimplified(t));
      if (variants.length >= _maxScrapeVariants) break;
    }
    final queries = variants.take(_maxScrapeVariants).toList();

    final results = <({String title, String url})>[];
    final seenUrls = <String>{};
    for (final q in queries) {
      for (final r in await _scrapeOne(q)) {
        if (seenUrls.add(r.url)) results.add(r);
      }
    }

    if (results.isEmpty) {
      final trad = ChineseConvert.toTraditional(
        query,
      ).replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
      if (trad.length >= 4) {
        var attempts = 0;
        for (
          var i = trad.length - 2;
          i >= 0 && attempts < 3 && results.isEmpty;
          i--
        ) {
          attempts++;
          for (final r in await _scrapeOne(trad.substring(i, i + 2))) {
            if (seenUrls.add(r.url)) results.add(r);
          }
        }
      }
    }

    final matches = [
      for (final r in results)
        Anime1Match.fromScrape(
          title: r.title,
          url: r.url,
          score: AnimeSearchService.bestSimilarity(r.title, queries),
        ),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return matches.take(_maxResults).toList();
  }

  /// Purpose: Run one `?s=` query and extract series title/URL pairs.
  /// Inputs: `query`.
  /// Returns: `Future<List<({String title, String url})>>`.
  /// Side effects: One HTTP GET (10 s timeout).
  /// Notes: Internal helper used within this file only. Three patterns run in
  /// priority order so category links win over per-episode posts.
  static Future<List<({String title, String url})>> _scrapeOne(
    String query,
  ) async {
    final url = Uri.parse('https://anime1.me/?s=${Uri.encodeComponent(query)}');
    final resp = await http
        .get(url, headers: {'User-Agent': AnimeSearchService.userAgent})
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return const [];

    final html = utf8.decode(resp.bodyBytes);
    final results = <({String title, String url})>[];
    final seen = <String>{};

    void collect(RegExp pattern, {bool stripEpisode = false}) {
      for (final match in pattern.allMatches(html)) {
        final href = match.group(1);
        var title = match.group(2)?.trim();
        if (href == null || title == null || title.isEmpty) continue;
        if (stripEpisode) {
          title = title.replaceAll(RegExp(r'\s*\[\d+\]\s*$'), '');
        }
        final clean = AnimeSearchService.decodeHtmlEntities(title);
        if (seen.add(clean)) results.add((title: clean, url: href));
      }
    }

    collect(
      RegExp(
        r'<a[^>]*href="(https://anime1\.me/category/[^"]+)"[^>]*rel="[^"]*category[^"]*"[^>]*>([^<]+)</a>',
      ),
    );
    if (results.isEmpty) {
      collect(
        RegExp(r'<a[^>]*href="(https://anime1\.me/\?cat=\d+)"[^>]*>([^<]+)</a>'),
      );
    }
    if (results.isEmpty) {
      collect(
        RegExp(
          r'<h2[^>]*class="[^"]*entry-title[^"]*"[^>]*>\s*<a[^>]*href="([^"]+)"[^>]*>([^<]+)</a>',
          dotAll: true,
        ),
        stripEpisode: true,
      );
    }
    return results;
  }
}
