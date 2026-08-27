import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;

import '../../../shared/utils/chinese_convert.dart';
import '../models/anime.dart';

/// A single search result from an anime database.
class AnimeSearchResult {
  final String source;
  final String? sourceUrl;
  final String? title;
  final String? titleJa;

  /// Romanized Japanese title, when the source reports one.
  final String? titleRomaji;

  /// English title, when the source reports one separately.
  final String? titleEn;

  /// Alternate titles in any language, as reported by the source.
  final List<String> synonyms;

  final int? episodes;
  final DateTime? firstAirDate;
  final int? airDayOfWeek;
  final String? airTime;

  /// Date the final episode aired, when the source reports one.
  final DateTime? endDate;

  /// Release format, e.g. `TV`, `MOVIE`, `OVA`, `ONA`, `SPECIAL`.
  final String? format;

  /// Broadcast status, e.g. `FINISHED`, `RELEASING`, `NOT_YET_RELEASED`.
  final String? status;

  /// Per-episode runtime in minutes.
  final int? durationMinutes;

  /// Genre tags reported by the source.
  final List<String> genres;

  /// Animation studios reported by the source.
  final List<String> studios;

  /// The source's own score, normalized onto [scoreMax].
  final double? score;

  /// Upper bound of [score]; every source is normalized onto a 10-point scale.
  final double scoreMax;

  /// Number of votes behind [score], when reported.
  final int? scoreVotes;

  /// The source's rank for this title, when reported.
  final int? scoreRank;

  final String? coverImageUrl;
  final String? summary;

  /// Purpose: Create a anime search result instance.
  /// Inputs: `source`, `sourceUrl`, `title`, `titleJa`, `titleRomaji`, `titleEn`, `synonyms`, `episodes`, `firstAirDate`, `airDayOfWeek`, `airTime`, `endDate`, `format`, `status`, `durationMinutes`, `genres`, `studios`, `score`, `scoreMax`, `scoreVotes`, `scoreRank`, `coverImageUrl`, `summary`.
  /// Returns: A new `AnimeSearchResult` instance.
  /// Side effects: None.
  /// Notes: Only `source` is required — no single source supplies every field.
  const AnimeSearchResult({
    required this.source,
    this.sourceUrl,
    this.title,
    this.titleJa,
    this.titleRomaji,
    this.titleEn,
    this.synonyms = const [],
    this.episodes,
    this.firstAirDate,
    this.airDayOfWeek,
    this.airTime,
    this.endDate,
    this.format,
    this.status,
    this.durationMinutes,
    this.genres = const [],
    this.studios = const [],
    this.score,
    this.scoreMax = 10,
    this.scoreVotes,
    this.scoreRank,
    this.coverImageUrl,
    this.summary,
  });

  /// Purpose: Collect every title this result knows about, in display order.
  /// Inputs: None.
  /// Returns: `List<String>`.
  /// Side effects: None.
  /// Notes: Deduplicated and blank-filtered; used for relevance scoring, the
  /// long-press detail sheet, and cross-language backfill queries.
  List<String> get allTitles {
    final seen = <String>{};
    final titles = <String>[];
    for (final t in [title, titleJa, titleRomaji, titleEn, ...synonyms]) {
      final trimmed = t?.trim();
      if (trimmed == null || trimmed.isEmpty) continue;
      if (seen.add(trimmed)) titles.add(trimmed);
    }
    return titles;
  }

  /// Purpose: Return the best title to show as the result's headline.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Falls back through the known titles before giving up.
  String get displayTitle {
    final titles = allTitles;
    return titles.isEmpty ? '?' : titles.first;
  }
}

/// Source display names, also used as the keys of per-source result maps.
class AnimeSearchSource {
  /// Purpose: Prevent direct instantiation and expose only static members.
  /// Inputs: None.
  /// Returns: A new `AnimeSearchSource._` instance.
  /// Side effects: None.
  /// Notes: None.
  const AnimeSearchSource._();

  static const bangumi = 'bangumi.tv';
  static const mal = 'MyAnimeList';
  static const anilist = 'AniList';
  static const acgsecrets = 'acgsecrets.hk';
  static const filmarks = 'filmarks.com';

  /// Every source `searchAll` queries, in display order.
  static const all = [bangumi, mal, anilist, acgsecrets, filmarks];
}

class AnimeSearchService {
  static const _userAgent = 'MyAnime/1.4.0 (anime tracker)';

  /// Maximum results requested from, and kept per, each individual source.
  static const _maxPerSource = 10;

  /// Minimum relevance a phase-one hit needs before its titles are trusted as
  /// cross-language backfill queries.
  static const _backfillMinRelevance = 0.45;

  /// Maximum number of harvested titles carried into the phase-two round.
  static const _maxBackfillTitles = 3;

  /// Relevance bonus for a result that carries a title in the UI's language.
  /// Kept far below the spread between a good and a bad fuzzy match so it only
  /// ever settles near-ties.
  static const _languageBonus = 0.05;

  // ──── Public API ────

  /// Purpose: Search all sources in parallel and return combined results.
  /// Inputs: `query`; `preferredLanguage` — the UI language tag (e.g. `zh_TW`,
  /// `ja`); results carrying a title in that language win a near-tie.
  /// Returns: `Future<List<AnimeSearchResult>>`.
  /// Side effects: Issues HTTP requests to five external services concurrently,
  /// and to a subset of them a second time when cross-language backfill runs.
  /// Notes: Runs two rounds. Round one sends every source the query variant it
  /// indexes best (Simplified for bangumi.tv, Traditional for acgsecrets.hk,
  /// the Japanese-preferred variant for filmarks.com). Round two re-queries
  /// only the sources that came back empty, using titles harvested from round
  /// one, so a Chinese query can still reach a Japanese-only source. Results
  /// are deduplicated by `sourceUrl` and sorted by descending relevance.
  static Future<List<AnimeSearchResult>> searchAll(
    String query, {
    String? preferredLanguage,
  }) async {
    final variants = queryVariants(query);

    final firstRound = await _runRound(
      bangumiQuery: ChineseConvert.toSimplified(query),
      acgsecretsQuery: ChineseConvert.toTraditional(query),
      filmarksQuery: query,
      globalQuery: query,
    );

    final combined = <String, List<AnimeSearchResult>>{...firstRound};

    final emptySources = AnimeSearchSource.all
        .where((s) => (firstRound[s] ?? const []).isEmpty)
        .toSet();
    if (emptySources.isNotEmpty) {
      final backfill = _harvestBackfillTitles(firstRound, variants);
      if (backfill.hasAny) {
        final secondRound = await _runRound(
          bangumiQuery: emptySources.contains(AnimeSearchSource.bangumi)
              ? backfill.chinese
              : null,
          acgsecretsQuery: emptySources.contains(AnimeSearchSource.acgsecrets)
              ? backfill.chineseTraditional
              : null,
          filmarksQuery: emptySources.contains(AnimeSearchSource.filmarks)
              ? backfill.japanese
              : null,
          globalQuery: null,
          // Both index native titles too, so a harvested Japanese title is a
          // usable second choice when no romanized one was found.
          malQuery: emptySources.contains(AnimeSearchSource.mal)
              ? backfill.latin ?? backfill.japanese
              : null,
          anilistQuery: emptySources.contains(AnimeSearchSource.anilist)
              ? backfill.latin ?? backfill.japanese
              : null,
        );
        for (final entry in secondRound.entries) {
          combined[entry.key] = [
            ...?combined[entry.key],
            ...entry.value,
          ];
        }
      }
    }

    // Deduplicate by sourceUrl, preserving first-seen order.
    final seen = <String>{};
    final deduped = <AnimeSearchResult>[];
    for (final source in AnimeSearchSource.all) {
      for (final r in combined[source] ?? const <AnimeSearchResult>[]) {
        final key = r.sourceUrl ?? r.title ?? r.titleJa ?? '';
        if (seen.add(key)) deduped.add(r);
      }
    }

    deduped.sort((a, b) {
      final cmp = relevance(b, variants, preferredLanguage: preferredLanguage)
          .compareTo(
            relevance(a, variants, preferredLanguage: preferredLanguage),
          );
      if (cmp != 0) return cmp;
      return a.source.compareTo(b.source);
    });
    return deduped;
  }

  /// Purpose: Build the Simplified/Traditional query variants used everywhere.
  /// Inputs: `query`.
  /// Returns: `List<String>` — the raw query first, then any distinct variants.
  /// Side effects: None.
  /// Notes: Public so the search dialog can score results with the same variant
  /// set the service searched with, instead of re-deriving it.
  static List<String> queryVariants(String query) {
    final trimmed = query.trim();
    return <String>{
      trimmed,
      ChineseConvert.toSimplified(trimmed),
      ChineseConvert.toTraditional(trimmed),
    }.where((v) => v.isNotEmpty).toList();
  }

  /// Purpose: Score how well a result matches a set of query variants.
  /// Inputs: `result`, `queries`; `preferredLanguage` — the UI language tag
  /// (e.g. `zh_TW`, `ja`) whose titles should win a near-tie.
  /// Returns: `double` in `0.0..1.05`.
  /// Side effects: None.
  /// Notes: Scores every known title of the result and keeps the best, so a hit
  /// whose Japanese title matches a Japanese query ranks as highly as one whose
  /// Chinese title matches a Chinese query. When `preferredLanguage` is given,
  /// a result that carries a title in that language gets `_languageBonus` added
  /// — small enough that it only reorders results that already match about
  /// equally well, never enough to lift a worse match above a better one.
  static double relevance(
    AnimeSearchResult result,
    List<String> queries, {
    String? preferredLanguage,
  }) {
    double best = 0;
    for (final title in result.allTitles) {
      final s = _bestSimilarity(title, queries);
      if (s > best) best = s;
    }
    return best + _languageBonus * _languageAffinity(result, preferredLanguage);
  }

  /// Purpose: Report whether a result carries a title in the user's UI language.
  /// Inputs: `result`, `languageTag`.
  /// Returns: `double` — `1` when it does, `0` otherwise.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. A `zh` UI wants the
  /// Chinese-titled hit first, a `ja` UI the Japanese-titled one, and any other
  /// (Latin-script) UI one that actually has an English or romanized title.
  static double _languageAffinity(
    AnimeSearchResult result,
    String? languageTag,
  ) {
    if (languageTag == null || languageTag.isEmpty) return 0;
    final lang = languageTag.toLowerCase();
    if (lang.startsWith('ja')) {
      final ja = result.titleJa;
      return ja != null && _containsJapanese(ja) ? 1 : 0;
    }
    if (lang.startsWith('zh')) {
      final cn = result.title;
      return cn != null && _isLikelyChinese(cn) ? 1 : 0;
    }
    return result.titleEn != null || result.titleRomaji != null ? 1 : 0;
  }

  /// Purpose: Convert a search result into the persisted external-metadata record.
  /// Inputs: `result`; `fetchedAt` — override for the timestamp, for tests.
  /// Returns: `AnimeExternalMeta`.
  /// Side effects: None.
  /// Notes: The source's own score becomes an `AnimeExternalRating` entry that
  /// remembers `sourceUrl`, which is what a later refresh re-queries. The
  /// user's personal `AnimeRating` is never involved.
  static AnimeExternalMeta toExternalMeta(
    AnimeSearchResult result, {
    DateTime? fetchedAt,
  }) {
    final now = (fetchedAt ?? DateTime.now()).toUtc();
    final hasScore =
        result.score != null ||
        result.scoreVotes != null ||
        result.scoreRank != null;
    return AnimeExternalMeta(
      synonyms: result.synonyms,
      titleRomaji: result.titleRomaji,
      titleEn: result.titleEn,
      format: result.format,
      status: result.status,
      durationMinutes: result.durationMinutes,
      genres: result.genres,
      studios: result.studios,
      endDate: result.endDate,
      ratings: hasScore
          ? [
              AnimeExternalRating(
                source: result.source,
                sourceUrl: result.sourceUrl,
                score: result.score,
                scoreMax: result.scoreMax,
                votes: result.scoreVotes,
                rank: result.scoreRank,
                fetchedAt: now,
              ),
            ]
          : const [],
      refreshedAt: now,
    );
  }

  /// Purpose: Re-fetch one anime's metadata from the page URL it came from.
  /// Inputs: `url` — an AniList, MyAnimeList, or bangumi.tv subject page URL.
  /// Returns: `Future<AnimeSearchResult?>` — `null` when the host is not one of
  /// the three API-backed sources, or when the fetch fails.
  /// Side effects: One HTTP request to the matching API.
  /// Notes: acgsecrets.hk and filmarks.com are scraped rather than queried by
  /// id, so they have no stable by-URL endpoint and are skipped here.
  static Future<AnimeSearchResult?> fetchByUrl(String url) async {
    final anilistId = RegExp(r'anilist\.co/anime/(\d+)').firstMatch(url);
    if (anilistId != null) {
      return _fetchAniListById(int.parse(anilistId.group(1)!));
    }
    final malId = RegExp(r'myanimelist\.net/anime/(\d+)').firstMatch(url);
    if (malId != null) {
      return _fetchMalById(int.parse(malId.group(1)!));
    }
    final bangumiId = RegExp(
      r'(?:bgm\.tv|bangumi\.tv|chii\.in)/subject/(\d+)',
    ).firstMatch(url);
    if (bangumiId != null) {
      return _fetchBangumiById(int.parse(bangumiId.group(1)!));
    }
    return null;
  }

  /// Purpose: Re-fetch several source pages at once for a metadata refresh.
  /// Inputs: `urls`.
  /// Returns: `Future<List<AnimeSearchResult>>` — only the fetches that
  /// succeeded, in completion-independent input order.
  /// Side effects: One HTTP request per recognized URL, issued in parallel.
  /// Notes: A failing or unrecognized URL is skipped rather than failing the
  /// whole refresh, matching how `searchAll` tolerates a dead source.
  static Future<List<AnimeSearchResult>> refreshAll(Iterable<String> urls) async {
    final distinct = urls.where((u) => u.trim().isNotEmpty).toSet().toList();
    if (distinct.isEmpty) return [];
    final fetched = await Future.wait(
      distinct.map(
        (u) => fetchByUrl(u).catchError((_) => null),
      ),
    );
    return fetched.whereType<AnimeSearchResult>().toList();
  }

  // ──── Round orchestration ────

  /// Purpose: Query the requested sources once, in parallel, tolerating failures.
  /// Inputs: `bangumiQuery`, `acgsecretsQuery`, `filmarksQuery`, `globalQuery`,
  /// `malQuery`, `anilistQuery`.
  /// Returns: `Future<Map<String, List<AnimeSearchResult>>>` keyed by source name.
  /// Side effects: One HTTP request per non-null, non-blank query.
  /// Notes: Internal helper used within this file only. `globalQuery` is the
  /// default for MyAnimeList and AniList, which index every language; passing
  /// `malQuery`/`anilistQuery` overrides it for the backfill round. A `null` or
  /// blank query means "skip this source in this round".
  static Future<Map<String, List<AnimeSearchResult>>> _runRound({
    required String? bangumiQuery,
    required String? acgsecretsQuery,
    required String? filmarksQuery,
    required String? globalQuery,
    String? malQuery,
    String? anilistQuery,
  }) async {
    Future<List<AnimeSearchResult>> run(
      String? query,
      Future<List<AnimeSearchResult>> Function(String) fetch,
    ) {
      if (query == null || query.trim().isEmpty) {
        return Future.value(const <AnimeSearchResult>[]);
      }
      return fetch(query.trim()).catchError((_) => <AnimeSearchResult>[]);
    }

    final futures = <String, Future<List<AnimeSearchResult>>>{
      AnimeSearchSource.bangumi: run(bangumiQuery, _searchBangumi),
      AnimeSearchSource.mal: run(malQuery ?? globalQuery, _searchMAL),
      AnimeSearchSource.anilist: run(anilistQuery ?? globalQuery, _searchAniList),
      AnimeSearchSource.acgsecrets: run(acgsecretsQuery, _searchAcgsecrets),
      AnimeSearchSource.filmarks: run(filmarksQuery, _searchFilmarks),
    };

    final resolved = await Future.wait(futures.values);
    final keys = futures.keys.toList();
    return {for (int i = 0; i < keys.length; i++) keys[i]: resolved[i]};
  }

  /// Purpose: Pick cross-language titles from round one to search with in round two.
  /// Inputs: `round`, `queryVariants`.
  /// Returns: `_BackfillTitles`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Only titles from hits
  /// scoring at least `_backfillMinRelevance` are trusted, so a stray unrelated
  /// hit cannot hijack the second round.
  static _BackfillTitles _harvestBackfillTitles(
    Map<String, List<AnimeSearchResult>> round,
    List<String> queryVariants,
  ) {
    final confident = <AnimeSearchResult>[];
    for (final results in round.values) {
      for (final r in results) {
        if (relevance(r, queryVariants) >= _backfillMinRelevance) {
          confident.add(r);
        }
        if (confident.length >= _maxBackfillTitles * 2) break;
      }
    }

    String? japanese;
    String? latin;
    String? chinese;
    for (final r in confident) {
      japanese ??= [
        r.titleJa,
        ...r.synonyms,
      ].whereType<String>().where(_containsJapanese).firstOrNull;
      latin ??= [
        r.titleRomaji,
        r.titleEn,
        // bangumi.tv has no romaji/English field — it files both under 别名.
        ...r.synonyms,
      ].whereType<String>().where(_isLatinScript).firstOrNull;
      chinese ??= [
        r.title,
        ...r.synonyms,
      ].whereType<String>().where(_isLikelyChinese).firstOrNull;
      if (japanese != null && latin != null && chinese != null) break;
    }

    return _BackfillTitles(
      japanese: japanese,
      latin: latin,
      chinese: chinese == null ? null : ChineseConvert.toSimplified(chinese),
      chineseTraditional: chinese == null
          ? null
          : ChineseConvert.toTraditional(chinese),
    );
  }

  // ──── bangumi.tv ────

  /// Purpose: bangumi.tv — uses legacy search API.
  /// Inputs: `query`.
  /// Returns: `Future<List<AnimeSearchResult>>`.
  /// Side effects: One HTTP POST (15s timeout) to `api.bgm.tv`.
  /// Notes: Internal helper used within this file only. Uses the **v0** search
  /// API. The legacy `/search/subject/` endpoint this used through 1.3.3 now
  /// answers `502 Bad gateway` from Cloudflare, which the old code silently
  /// swallowed as "no results" — bangumi.tv had effectively dropped out of
  /// search. `filter.type: [2]` restricts results to the anime subject type.
  static Future<List<AnimeSearchResult>> _searchBangumi(String query) async {
    final url = Uri.parse(
      'https://api.bgm.tv/v0/search/subjects?limit=$_maxPerSource',
    );
    final resp = await http
        .post(
          url,
          headers: {
            'User-Agent': _userAgent,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'keyword': query,
            'filter': {
              'type': [2],
            },
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) return [];

    final json = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final list = json['data'] as List<dynamic>?;
    if (list == null) return [];

    return list
        .take(_maxPerSource)
        .whereType<Map<String, dynamic>>()
        .map(mapBangumiSubject)
        .toList();
  }

  /// Purpose: Fetch one bangumi.tv subject by its numeric id.
  /// Inputs: `id`.
  /// Returns: `Future<AnimeSearchResult?>` — `null` on a non-200 response.
  /// Side effects: One HTTP GET (10s timeout) to `api.bgm.tv`.
  /// Notes: Internal helper used within this file only. The v0 subject endpoint
  /// is `/v0/subjects/{id}` — **plural**; the singular path 404s. It returns the
  /// same object shape as v0 search, so one mapper serves both.
  static Future<AnimeSearchResult?> _fetchBangumiById(int id) async {
    final url = Uri.parse('https://api.bgm.tv/v0/subjects/$id');
    final resp = await http
        .get(
          url,
          headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return null;
    final json = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    if (json['id'] == null) return null;
    return mapBangumiSubject(json);
  }

  /// Purpose: Map one bangumi.tv v0 subject object onto an `AnimeSearchResult`.
  /// Inputs: `m` — a v0 subject map, from either search or the by-id endpoint.
  /// Returns: `AnimeSearchResult`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. bangumi.tv scores are
  /// already on a 10-point scale, so they are stored unscaled. The schedule,
  /// alternate titles, studio, and end date all live in `infobox` rather than
  /// as top-level fields.
  @visibleForTesting
  static AnimeSearchResult mapBangumiSubject(Map<String, dynamic> m) {
    final images = m['images'] as Map<String, dynamic>?;
    final rating = m['rating'] as Map<String, dynamic>?;
    final infobox = m['infobox'] as List<dynamic>?;

    final nameCn = m['name_cn'] as String?;
    final name = m['name'] as String?;

    // `tags` is [{name, count}, ...], ordered most-used first.
    final genres = <String>[];
    final rawTags = m['tags'];
    if (rawTags is List) {
      for (final tag in rawTags.take(5)) {
        if (tag is Map && tag['name'] is String) genres.add(tag['name'] as String);
      }
    }

    return AnimeSearchResult(
      source: AnimeSearchSource.bangumi,
      sourceUrl: 'https://bgm.tv/subject/${m['id']}',
      title: nameCn?.isNotEmpty == true ? nameCn : null,
      titleJa: name,
      synonyms: _bangumiInfoboxList(infobox, '别名'),
      episodes: m['eps'] as int? ?? m['total_episodes'] as int?,
      firstAirDate: m['date'] is String
          ? DateTime.tryParse(m['date'] as String)
          : _parseCjkDate(_bangumiInfoboxText(infobox, '放送开始')),
      endDate: _parseCjkDate(_bangumiInfoboxText(infobox, '播放结束')),
      airDayOfWeek: parseBangumiWeekday(
        _bangumiInfoboxText(infobox, '放送星期'),
      ),
      studios: _bangumiInfoboxList(infobox, '动画制作'),
      genres: genres,
      coverImageUrl:
          images?['large'] as String? ??
          images?['common'] as String? ??
          m['image'] as String?,
      score: _toDouble(rating?['score']),
      scoreVotes: rating?['total'] as int?,
      scoreRank: rating?['rank'] as int?,
      summary: m['summary'] as String?,
    );
  }

  /// Purpose: Read one `infobox` entry as plain text.
  /// Inputs: `infobox`, `key`.
  /// Returns: `String?` — `null` when the key is absent or not a plain string.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. bangumi's `infobox` is
  /// a list of `{key, value}` where `value` is either a string or a list of
  /// `{v: ...}` maps; this reads only the string form.
  static String? _bangumiInfoboxText(List<dynamic>? infobox, String key) {
    if (infobox == null) return null;
    for (final entry in infobox) {
      if (entry is Map && entry['key'] == key) {
        final value = entry['value'];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
    }
    return null;
  }

  /// Purpose: Read one `infobox` entry as a list of strings.
  /// Inputs: `infobox`, `key`.
  /// Returns: `List<String>` — empty when the key is absent.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Accepts both `infobox`
  /// value shapes: a bare string becomes a one-element list, and a list of
  /// `{v: ...}` maps is flattened to its `v` values.
  static List<String> _bangumiInfoboxList(List<dynamic>? infobox, String key) {
    if (infobox == null) return const [];
    for (final entry in infobox) {
      if (entry is! Map || entry['key'] != key) continue;
      final value = entry['value'];
      if (value is String) {
        final trimmed = value.trim();
        return trimmed.isEmpty ? const [] : [trimmed];
      }
      if (value is List) {
        final out = <String>[];
        for (final item in value) {
          if (item is Map && item['v'] is String) {
            final v = (item['v'] as String).trim();
            if (v.isNotEmpty) out.add(v);
          }
        }
        return out;
      }
    }
    return const [];
  }

  /// Purpose: Parse bangumi.tv's `放送星期` text onto Monday=1..Sunday=7.
  /// Inputs: `value` — e.g. `星期五`, `週五`, `金曜日`.
  /// Returns: `int?` — `null` when nothing recognizable matches.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. bangumi's v0 API states
  /// the broadcast day as free text rather than a number, in Simplified,
  /// Traditional, or Japanese form depending on who edited the entry. An
  /// unrecognized value becomes "no data" rather than a guess, because a wrong
  /// weekday silently mis-schedules every episode.
  @visibleForTesting
  static int? parseBangumiWeekday(String? value) {
    if (value == null) return null;
    const days = [
      ['一', '月'],
      ['二', '火'],
      ['三', '水'],
      ['四', '木'],
      ['五', '金'],
      ['六', '土'],
      ['日', '天'],
    ];
    for (var i = 0; i < days.length; i++) {
      for (final marker in days[i]) {
        if (value.contains('星期$marker') ||
            value.contains('週$marker') ||
            value.contains('周$marker') ||
            value.contains('$marker曜')) {
          return i + 1;
        }
      }
    }
    return null;
  }

  /// Purpose: Parse a CJK-formatted date such as `2023年9月29日`.
  /// Inputs: `value`.
  /// Returns: `DateTime?` — `null` when the text holds no such date.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. bangumi's `infobox`
  /// dates are prose, unlike the ISO `date` field on the subject itself.
  static DateTime? _parseCjkDate(String? value) {
    if (value == null) return null;
    final m = RegExp(r'(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日')
        .firstMatch(value);
    if (m == null) return null;
    return DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }

  // ──── MyAnimeList (Jikan) ────

  /// Purpose: MyAnimeList — uses Jikan v4 API.
  /// Inputs: `query`.
  /// Returns: `Future<List<AnimeSearchResult>>`.
  /// Side effects: One HTTP GET (10s timeout) to `api.jikan.moe`.
  /// Notes: Internal helper used within this file only.
  static Future<List<AnimeSearchResult>> _searchMAL(String query) async {
    final url = Uri.parse(
      'https://api.jikan.moe/v4/anime'
      '?q=${Uri.encodeComponent(query)}&limit=$_maxPerSource',
    );
    final resp = await http
        .get(
          url,
          headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return [];

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = json['data'] as List<dynamic>?;
    if (data == null) return [];

    return data
        .take(_maxPerSource)
        .map((item) => mapJikanAnime(item as Map<String, dynamic>))
        .toList();
  }

  /// Purpose: Fetch one MyAnimeList entry by its numeric id via Jikan.
  /// Inputs: `id`.
  /// Returns: `Future<AnimeSearchResult?>` — `null` on a non-200 response.
  /// Side effects: One HTTP GET (10s timeout) to `api.jikan.moe`.
  /// Notes: Internal helper used within this file only. The `/full` variant
  /// returns the same object shape as search, plus relations this app ignores.
  static Future<AnimeSearchResult?> _fetchMalById(int id) async {
    final url = Uri.parse('https://api.jikan.moe/v4/anime/$id/full');
    final resp = await http
        .get(
          url,
          headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return null;
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = json['data'];
    if (data is! Map<String, dynamic>) return null;
    return mapJikanAnime(data);
  }

  /// Purpose: Map one Jikan anime object onto an `AnimeSearchResult`.
  /// Inputs: `m`.
  /// Returns: `AnimeSearchResult`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. `broadcast.time` is
  /// only trusted as Japan time when `broadcast.timezone` says `Asia/Tokyo`;
  /// any other timezone is dropped rather than silently mislabelled as JST.
  @visibleForTesting
  static AnimeSearchResult mapJikanAnime(Map<String, dynamic> m) {
    final images = m['images'] as Map<String, dynamic>?;
    final jpgImages = images?['jpg'] as Map<String, dynamic>?;
    final aired = m['aired'] as Map<String, dynamic>?;

    DateTime? airDate;
    if (aired?['from'] != null) {
      airDate = DateTime.tryParse(aired!['from'] as String);
    }
    DateTime? endDate;
    if (aired?['to'] != null) {
      endDate = DateTime.tryParse(aired!['to'] as String);
    }

    final broadcast = m['broadcast'] as Map<String, dynamic>?;
    int? airDayOfWeek;
    String? airTime;
    if (broadcast != null) {
      final dayStr = broadcast['day'] as String?;
      if (dayStr != null) airDayOfWeek = parseDayOfWeek(dayStr);
      final timezone = broadcast['timezone'] as String?;
      if (timezone == null || timezone == 'Asia/Tokyo') {
        airTime = broadcast['time'] as String?;
      }
      // Jikan reports the wall-clock day and time, so a 01:00 slot arrives as
      // "Thursdays 01:00" and has to be filed back under Wednesday 25:00.
      final hhmm = airTime?.split(':');
      if (airDayOfWeek != null && hhmm != null && hhmm.length == 2) {
        final hour = int.tryParse(hhmm[0]);
        final minute = int.tryParse(hhmm[1]);
        if (hour != null && minute != null) {
          final clockWeekday = airDayOfWeek;
          final slot = _jstBroadcastSlot(clockWeekday, hour, minute);
          airDayOfWeek = slot.weekday;
          airTime = slot.time;
          airDate = _alignFirstAirDateToSlot(airDate, slot, clockWeekday);
        }
      }
    }

    // Jikan's `titles` array carries every alias the entry has, tagged by type.
    String? titleEn;
    String? titleJa;
    String? titleRomaji;
    final synonyms = <String>[];
    final rawTitles = m['titles'];
    if (rawTitles is List) {
      for (final entry in rawTitles) {
        if (entry is! Map) continue;
        final type = entry['type'] as String?;
        final value = (entry['title'] as String?)?.trim();
        if (value == null || value.isEmpty) continue;
        switch (type) {
          case 'Default':
            titleRomaji ??= value;
          case 'English':
            titleEn ??= value;
          case 'Japanese':
            titleJa ??= value;
          default:
            synonyms.add(value);
        }
      }
    }
    titleRomaji ??= m['title'] as String?;
    titleEn ??= m['title_english'] as String?;
    titleJa ??= m['title_japanese'] as String?;

    return AnimeSearchResult(
      source: AnimeSearchSource.mal,
      sourceUrl: m['url'] as String?,
      title: titleEn ?? m['title'] as String?,
      titleJa: titleJa,
      titleRomaji: titleRomaji,
      titleEn: titleEn,
      synonyms: synonyms,
      episodes: m['episodes'] as int?,
      firstAirDate: airDate,
      airDayOfWeek: airDayOfWeek,
      airTime: airTime,
      endDate: endDate,
      format: m['type'] as String?,
      status: m['status'] as String?,
      durationMinutes: parseJikanDuration(m['duration'] as String?),
      genres: _namedList(m['genres']),
      studios: _namedList(m['studios']),
      score: _toDouble(m['score']),
      scoreVotes: m['scored_by'] as int?,
      scoreRank: m['rank'] as int?,
      coverImageUrl:
          jpgImages?['large_image_url'] as String? ??
          jpgImages?['image_url'] as String?,
      summary: m['synopsis'] as String?,
    );
  }

  /// Purpose: Parse Jikan's human-readable duration string into minutes.
  /// Inputs: `duration` — e.g. `"24 min per ep"` or `"1 hr 35 min"`.
  /// Returns: `int?` — `null` when nothing parseable is present.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Jikan reports duration
  /// as prose, so hours and minutes are extracted independently and summed.
  @visibleForTesting
  static int? parseJikanDuration(String? duration) {
    if (duration == null || duration.isEmpty) return null;
    final hours = RegExp(r'(\d+)\s*hr').firstMatch(duration);
    final minutes = RegExp(r'(\d+)\s*min').firstMatch(duration);
    if (hours == null && minutes == null) return null;
    final h = hours != null ? int.parse(hours.group(1)!) : 0;
    final m = minutes != null ? int.parse(minutes.group(1)!) : 0;
    final total = h * 60 + m;
    return total > 0 ? total : null;
  }

  /// Purpose: Read a Jikan `[{name: ...}]` array into a plain string list.
  /// Inputs: `value`.
  /// Returns: `List<String>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static List<String> _namedList(Object? value) {
    if (value is! List) return const [];
    final names = <String>[];
    for (final entry in value) {
      if (entry is Map && entry['name'] is String) {
        names.add(entry['name'] as String);
      }
    }
    return names;
  }

  // ──── acgsecrets.hk ────

  /// Purpose: acgsecrets.hk — scrape seasonal page JSON-LD data and fuzzy-match.
  /// Inputs: `query`.
  /// Returns: `Future<List<AnimeSearchResult>>` sorted by descending match score.
  /// Side effects: Up to two HTTP GETs (15s timeout each) to `acgsecrets.hk`.
  /// Notes: Internal helper used within this file only.
  static Future<List<AnimeSearchResult>> _searchAcgsecrets(String query) async {
    final seasons = _recentSeasons();
    final allResults = <(AnimeSearchResult, double)>[];
    final seenUrls = <String>{};
    final queryTrad = ChineseConvert.toTraditional(query);
    final querySimp = ChineseConvert.toSimplified(query);

    for (final season in seasons) {
      final url = Uri.parse('https://acgsecrets.hk/bangumi/$season/');
      final resp = await http
          .get(url, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 15));
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
                source: AnimeSearchSource.acgsecrets,
                sourceUrl: itemUrl,
                title: name.isNotEmpty ? name : null,
                titleJa: titleJa,
                synonyms: altNames.where((n) => n != titleJa).toList(),
                episodes: item['numberOfEpisodes'] as int?,
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
    return allResults.take(_maxPerSource).map((e) => e.$1).toList();
  }

  /// Purpose: Return recent season codes (YYYYMM) for scraping, newest first.
  /// Inputs: None.
  /// Returns: `List<String>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Return recent season codes (YYYYMM) for scraping, newest first.
  static List<String> _recentSeasons() {
    final now = DateTime.now();
    final y = now.year;
    final m = now.month;
    // Current season month: 01, 04, 07, 10.
    final sm = [1, 4, 7, 10].lastWhere((s) => m >= s);
    final seasons = <String>['$y${sm.toString().padLeft(2, '0')}'];
    // Previous season.
    if (sm == 1) {
      seasons.add('${y - 1}10');
    } else {
      seasons.add('$y${(sm - 3).toString().padLeft(2, '0')}');
    }
    return seasons;
  }

  /// Purpose: Check if a string contains Japanese kana characters.
  /// Inputs: `s`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Kanji-only strings do
  /// not count, because Kanji alone cannot separate Japanese from Chinese.
  static bool _containsJapanese(String s) {
    for (final c in s.runes) {
      // Hiragana: 3040-309F, Katakana: 30A0-30FF
      if ((c >= 0x3040 && c <= 0x309F) || (c >= 0x30A0 && c <= 0x30FF)) {
        return true;
      }
    }
    return false;
  }

  /// Purpose: Check whether a string is written in Latin script.
  /// Inputs: `s`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. True when the string
  /// holds at least one ASCII letter and no CJK ideograph or Kana, which is
  /// what makes a harvested title safe to send to a romaji/English index.
  static bool _isLatinScript(String s) {
    if (s.trim().isEmpty) return false;
    var hasLatin = false;
    for (final c in s.runes) {
      if ((c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A)) {
        hasLatin = true;
      } else if ((c >= 0x3040 && c <= 0x30FF) || (c >= 0x4E00 && c <= 0x9FFF)) {
        return false;
      }
    }
    return hasLatin;
  }

  /// Purpose: Check whether a string reads as Chinese rather than Japanese.
  /// Inputs: `s`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. True when the string
  /// contains CJK ideographs but no Kana — the practical test for "this title
  /// is safe to send to a Chinese-language source".
  static bool _isLikelyChinese(String s) {
    if (_containsJapanese(s)) return false;
    for (final c in s.runes) {
      // CJK Unified Ideographs.
      if (c >= 0x4E00 && c <= 0x9FFF) return true;
    }
    return false;
  }

  // ──── filmarks.com ────

  /// Purpose: filmarks.com — HTML scraping.
  /// Inputs: `query`.
  /// Returns: `Future<List<AnimeSearchResult>>`.
  /// Side effects: One HTTP GET (10s timeout, `Accept-Language: ja`).
  /// Notes: Internal helper used within this file only. The markup yields only
  /// title, cover, and URL — no episode count, air date, or schedule.
  static Future<List<AnimeSearchResult>> _searchFilmarks(String query) async {
    final url = Uri.parse(
      'https://filmarks.com/search/animes'
      '?q=${Uri.encodeComponent(query)}',
    );
    final resp = await http
        .get(url, headers: {'User-Agent': _userAgent, 'Accept-Language': 'ja'})
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return [];

    final html = utf8.decode(resp.bodyBytes);
    final results = <AnimeSearchResult>[];
    final seen = <String>{};

    // Each result is a "content cassette" whose detail link is carried in an
    // escaped click handler, with the title in the poster image's alt text:
    //   onClickDetailLink($event, &#39;/animes/3844/5200&#39;) ... <img alt="…" src="…">
    final cassette = RegExp(
      r'onClickDetailLink\([^)]*?&#39;(/animes/\d+/\d+)&#39;\)'
      r'.{0,3000}?<img alt="([^"]*)"[^>]*src="([^"]+)"',
      dotAll: true,
    );
    for (final match in cassette.allMatches(html)) {
      final path = match.group(1)!;
      final title = match.group(2)?.trim();
      if (title == null || title.isEmpty) continue;
      if (!seen.add(path)) continue;
      results.add(
        AnimeSearchResult(
          source: AnimeSearchSource.filmarks,
          sourceUrl: 'https://filmarks.com$path',
          titleJa: _decodeHtmlEntities(title),
          coverImageUrl: match.group(3),
        ),
      );
      if (results.length >= _maxPerSource) break;
    }

    // Fallback: a plain season anchor with an adjacent poster alt text.
    if (results.isEmpty) {
      final fallback = RegExp(
        r'<a[^>]*href="(/animes/\d+/\d+)"[^>]*>.{0,1500}?<img alt="([^"]+)"',
        dotAll: true,
      );
      for (final match in fallback.allMatches(html)) {
        final path = match.group(1)!;
        final title = match.group(2)?.trim();
        if (title == null || title.length < 2) continue;
        if (!seen.add(path)) continue;
        results.add(
          AnimeSearchResult(
            source: AnimeSearchSource.filmarks,
            sourceUrl: 'https://filmarks.com$path',
            titleJa: _decodeHtmlEntities(title),
          ),
        );
        if (results.length >= _maxPerSource) break;
      }
    }

    return results;
  }

  // ──── AniList ────

  /// The field selection shared by the search query and the by-id refresh.
  static const _aniListMediaFields = r'''
      id
      title { romaji native english }
      synonyms
      episodes
      duration
      format
      status
      genres
      startDate { year month day }
      endDate { year month day }
      studios(isMain: true) { nodes { name } }
      nextAiringEpisode { airingAt episode }
      airingSchedule(perPage: 1) { nodes { airingAt episode } }
      averageScore
      popularity
      coverImage { large }
      description(asHtml: false)
      siteUrl
''';

  /// Purpose: AniList — GraphQL API.
  /// Inputs: `query`.
  /// Returns: `Future<List<AnimeSearchResult>>`.
  /// Side effects: One HTTP POST (10s timeout) to `graphql.anilist.co`.
  /// Notes: Internal helper used within this file only.
  static Future<List<AnimeSearchResult>> _searchAniList(String query) async {
    final graphqlQuery =
        '''
query (\$search: String) {
  Page(perPage: $_maxPerSource) {
    media(search: \$search, type: ANIME, sort: SEARCH_MATCH) {
$_aniListMediaFields    }
  }
}
''';
    final json = await _postAniList(graphqlQuery, {'search': query});
    if (json == null) return [];
    final page = json['Page'] as Map<String, dynamic>?;
    final media = page?['media'] as List<dynamic>?;
    if (media == null) return [];
    return media
        .map((item) => mapAniListMedia(item as Map<String, dynamic>))
        .toList();
  }

  /// Purpose: Fetch one AniList media entry by its numeric id.
  /// Inputs: `id`.
  /// Returns: `Future<AnimeSearchResult?>` — `null` when the id is unknown.
  /// Side effects: One HTTP POST (10s timeout) to `graphql.anilist.co`.
  /// Notes: Internal helper used within this file only.
  static Future<AnimeSearchResult?> _fetchAniListById(int id) async {
    final graphqlQuery =
        '''
query (\$id: Int) {
  Media(id: \$id, type: ANIME) {
$_aniListMediaFields  }
}
''';
    final json = await _postAniList(graphqlQuery, {'id': id});
    final media = json?['Media'];
    if (media is! Map<String, dynamic>) return null;
    return mapAniListMedia(media);
  }

  /// Purpose: POST a GraphQL document to AniList and return its `data` object.
  /// Inputs: `document`, `variables`.
  /// Returns: `Future<Map<String, dynamic>?>` — `null` on a non-200 response.
  /// Side effects: One HTTP POST (10s timeout) to `graphql.anilist.co`.
  /// Notes: Internal helper used within this file only.
  static Future<Map<String, dynamic>?> _postAniList(
    String document,
    Map<String, dynamic> variables,
  ) async {
    final resp = await http
        .post(
          Uri.parse('https://graphql.anilist.co'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': _userAgent,
          },
          body: jsonEncode({'query': document, 'variables': variables}),
        )
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return null;
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return json['data'] as Map<String, dynamic>?;
  }

  /// Purpose: Map one AniList media object onto an `AnimeSearchResult`.
  /// Inputs: `m`.
  /// Returns: `AnimeSearchResult`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. The broadcast weekday
  /// and time come from the real airing schedule when AniList has one, and only
  /// fall back to `startDate.weekday` when it does not. Times are reported on
  /// the actual Japan-time calendar day (a 01:00 slot stays `01:00` on that day
  /// rather than being rewritten to the `25:00` convention), which keeps the
  /// weekday consistent with `firstAirDate`.
  @visibleForTesting
  static AnimeSearchResult mapAniListMedia(Map<String, dynamic> m) {
    final titles = m['title'] as Map<String, dynamic>?;
    final coverImg = m['coverImage'] as Map<String, dynamic>?;

    var airDate = _aniListDate(m['startDate']);
    final endDate = _aniListDate(m['endDate']);

    int? airDayOfWeek;
    String? airTime;
    final airingAt = _aniListFirstAiringAt(m);
    if (airingAt != null) {
      final jst = DateTime.fromMillisecondsSinceEpoch(
        airingAt * 1000,
        isUtc: true,
      ).add(const Duration(hours: 9));
      final slot = _jstBroadcastSlot(jst.weekday, jst.hour, jst.minute);
      airDayOfWeek = slot.weekday;
      airTime = slot.time;
      airDate = _alignFirstAirDateToSlot(airDate, slot, jst.weekday);
    } else if (airDate != null) {
      airDayOfWeek = airDate.weekday;
    }

    // Clean HTML tags from description
    String? summary = m['description'] as String?;
    if (summary != null) {
      summary = summary
          .replaceAll(RegExp(r'<br\s*/?>'), '\n')
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'")
          .trim();
    }

    final studios = <String>[];
    final studioNodes =
        (m['studios'] as Map<String, dynamic>?)?['nodes'] as List<dynamic>?;
    if (studioNodes != null) {
      for (final node in studioNodes) {
        if (node is Map && node['name'] is String) {
          studios.add(node['name'] as String);
        }
      }
    }

    // AniList reports averageScore on a 0-100 scale.
    final rawScore = _toDouble(m['averageScore']);

    return AnimeSearchResult(
      source: AnimeSearchSource.anilist,
      sourceUrl: m['siteUrl'] as String?,
      title: titles?['english'] as String? ?? titles?['romaji'] as String?,
      titleJa: titles?['native'] as String?,
      titleRomaji: titles?['romaji'] as String?,
      titleEn: titles?['english'] as String?,
      synonyms: (m['synonyms'] as List?)?.whereType<String>().toList() ?? const [],
      episodes: m['episodes'] as int?,
      firstAirDate: airDate,
      airDayOfWeek: airDayOfWeek,
      airTime: airTime,
      endDate: endDate,
      format: m['format'] as String?,
      status: m['status'] as String?,
      durationMinutes: m['duration'] as int?,
      genres: (m['genres'] as List?)?.whereType<String>().toList() ?? const [],
      studios: studios,
      score: rawScore != null ? rawScore / 10 : null,
      scoreVotes: m['popularity'] as int?,
      coverImageUrl: coverImg?['large'] as String?,
      summary: summary,
    );
  }

  /// Purpose: Build a `DateTime` from an AniList `{year, month, day}` object.
  /// Inputs: `value`.
  /// Returns: `DateTime?` — `null` unless all three parts are present.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. AniList leaves parts
  /// null for unannounced dates, and a partial date cannot be scheduled.
  static DateTime? _aniListDate(Object? value) {
    if (value is! Map) return null;
    final year = value['year'];
    final month = value['month'];
    final day = value['day'];
    if (year is! int || month is! int || day is! int) return null;
    return DateTime(year, month, day);
  }

  /// Purpose: Pick the airing timestamp that best describes the broadcast slot.
  /// Inputs: `m` — an AniList media object.
  /// Returns: `int?` — a Unix timestamp in seconds, or `null` when unscheduled.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Prefers
  /// `nextAiringEpisode` for a currently-airing show, and falls back to the
  /// first `airingSchedule` node so finished shows still yield a real slot.
  static int? _aniListFirstAiringAt(Map<String, dynamic> m) {
    final next = m['nextAiringEpisode'];
    if (next is Map && next['airingAt'] is int) return next['airingAt'] as int;
    final schedule = m['airingSchedule'];
    if (schedule is Map) {
      final nodes = schedule['nodes'];
      if (nodes is List) {
        for (final node in nodes) {
          if (node is Map && node['airingAt'] is int) {
            return node['airingAt'] as int;
          }
        }
      }
    }
    return null;
  }

  // ──── Shared helpers ────

  /// Hour before which a Japan-time airing still belongs to the previous day's
  /// late-night block. 04:00 is the broadcast industry's programming-day
  /// boundary, and the one the `25:00`-style `airTime` convention assumes.
  static const _lateNightBoundaryHour = 4;

  /// Purpose: Map a Japan-time airing moment onto the broadcast slot it is filed under.
  /// Inputs: `weekday` (1..7), `hour`, `minute` — all in Japan time.
  /// Returns: A record of the slot's `weekday`, its `time` (`HH:mm`, hour ≥ 24
  /// for late-night), and `dayShift` — how many days earlier the slot's calendar
  /// date sits than the wall-clock date.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Japanese scheduling
  /// files everything before 04:00 under the *previous* evening: a show at
  /// 01:00 Thursday is "Wednesday 25:00" and belongs on Wednesday's calendar
  /// row. `Anime.getEpisodeCalendarDate` ignores `airTime` entirely and places
  /// an episode purely from `firstAirDate` + `airDayOfWeek`, so reporting the
  /// raw wall-clock weekday would put every late-night episode one day late.
  /// Callers must apply `dayShift` to the first-air date as well, or the two
  /// fields disagree and the forward-snap pushes episode 1 a week out.
  static ({int weekday, String time, int dayShift}) _jstBroadcastSlot(
    int weekday,
    int hour,
    int minute,
  ) {
    final mm = minute.toString().padLeft(2, '0');
    if (hour < _lateNightBoundaryHour) {
      // 1 (Mon) .. 7 (Sun): stepping back from Monday wraps to Sunday.
      final previous = weekday == DateTime.monday ? DateTime.sunday : weekday - 1;
      return (weekday: previous, time: '${hour + 24}:$mm', dayShift: 1);
    }
    return (
      weekday: weekday,
      time: '${hour.toString().padLeft(2, '0')}:$mm',
      dayShift: 0,
    );
  }

  /// Purpose: Move a first-air date back onto the late-night slot's calendar day.
  /// Inputs: `airDate`, `slot`, `clockWeekday` — the un-shifted wall-clock weekday.
  /// Returns: `DateTime?`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Only shifts when the
  /// source's own first-air date sits on the wall-clock day, which is how both
  /// AniList and MyAnimeList record it. If a source already reports the
  /// programming day, its weekday matches the shifted slot and the date is left
  /// alone — so this cannot double-shift.
  static DateTime? _alignFirstAirDateToSlot(
    DateTime? airDate,
    ({int weekday, String time, int dayShift}) slot,
    int clockWeekday,
  ) {
    if (airDate == null || slot.dayShift == 0) return airDate;
    if (airDate.weekday != clockWeekday) return airDate;
    return airDate.subtract(Duration(days: slot.dayShift));
  }

  /// Purpose: Coerce a JSON number into a `double`.
  /// Inputs: `value`.
  /// Returns: `double?`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Sources report scores
  /// as either integers or decimals depending on the endpoint.
  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return null;
  }

  /// Purpose: Provide the internal parse day of week helper for this file.
  /// Inputs: `day`.
  /// Returns: `int?`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Matches by 3-letter
  /// prefix, so both `"Monday"` and `"Mondays"` parse.
  @visibleForTesting
  static int? parseDayOfWeek(String day) {
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
    String query, {
    List<String> altQueries = const [],
  }) async {
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
      final trad = ChineseConvert.toTraditional(
        query,
      ).replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
      if (trad.length >= 4) {
        int attempts = 0;
        for (
          int i = trad.length - 2;
          i >= 0 && attempts < 3 && allResults.isEmpty;
          i--
        ) {
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
    final variants = queries.toList();
    allResults.sort((a, b) {
      final sa = _bestSimilarity(a.title, variants);
      final sb = _bestSimilarity(b.title, variants);
      return sb.compareTo(sa); // descending
    });

    return allResults.take(10).toList();
  }

  /// Purpose: Compute the best similarity score of [title] against any of [queries].
  /// Inputs: `title`, `queries`.
  /// Returns: `double`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Compute the best similarity score of [title] against any of [queries]. Returns 0.0..1.0.
  static double _bestSimilarity(String title, List<String> queries) {
    double best = 0;
    for (final q in queries) {
      final s = _similarity(title, q);
      if (s > best) best = s;
    }
    return best;
  }

  /// Purpose: Fuzzy similarity combining LCS, Dice (set-based), and containment.
  /// Inputs: `a`, `b`.
  /// Returns: `double`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Fuzzy similarity combining LCS, Dice (set-based), and containment. Also compares S↔T normalized forms.  Returns 0.0..1.0.
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

  /// Purpose: Longest common subsequence length (O(n*m) but strings are short titles).
  /// Inputs: `a`, `b`.
  /// Returns: `int`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Longest common subsequence length (O(n*m) but strings are short titles).
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

  /// Purpose: Run one anime1.me query and extract series title/URL pairs.
  /// Inputs: `query`.
  /// Returns: `Future<List<({String title, String url})>>`.
  /// Side effects: One HTTP GET (10s timeout) to `anime1.me`.
  /// Notes: Internal helper used within this file only. Three fallback patterns
  /// run in priority order so cleaner category links win over per-episode posts.
  static Future<List<({String title, String url})>> _searchAnime1Single(
    String query,
  ) async {
    final url = Uri.parse('https://anime1.me/?s=${Uri.encodeComponent(query)}');
    final resp = await http
        .get(url, headers: {'User-Agent': _userAgent})
        .timeout(const Duration(seconds: 10));
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
          final cleanTitle = _decodeHtmlEntities(
            rawTitle.replaceAll(RegExp(r'\s*\[\d+\]\s*$'), ''),
          );
          if (seen.add(cleanTitle)) {
            results.add((title: cleanTitle, url: href));
          }
        }
      }
    }

    return results;
  }

  /// Purpose: Provide the internal decode html entities helper for this file.
  /// Inputs: `text`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
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

/// Titles harvested from the first search round, one per language family, used
/// to re-query the sources that came back empty.
class _BackfillTitles {
  final String? japanese;
  final String? latin;
  final String? chinese;
  final String? chineseTraditional;

  /// Purpose: Create a backfill titles instance.
  /// Inputs: `japanese`, `latin`, `chinese`, `chineseTraditional`.
  /// Returns: A new `_BackfillTitles` instance.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  const _BackfillTitles({
    this.japanese,
    this.latin,
    this.chinese,
    this.chineseTraditional,
  });

  /// Purpose: Report whether any usable title was harvested.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: When false the caller skips the second round entirely.
  bool get hasAny =>
      japanese != null ||
      latin != null ||
      chinese != null ||
      chineseTraditional != null;
}
