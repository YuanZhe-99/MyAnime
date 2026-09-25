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

  /// Related works the source lists; empty when the fetch did not ask for
  /// them (search results never do).
  final List<AnimeExternalRelation> relations;

  /// Purpose: Create a anime search result instance.
  /// Inputs: `source`, `sourceUrl`, `title`, `titleJa`, `titleRomaji`, `titleEn`, `synonyms`, `episodes`, `firstAirDate`, `airDayOfWeek`, `airTime`, `endDate`, `format`, `status`, `durationMinutes`, `genres`, `studios`, `score`, `scoreMax`, `scoreVotes`, `scoreRank`, `coverImageUrl`, `summary`, `relations`.
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
    this.relations = const [],
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

  /// Purpose: Return a copy carrying `relations`.
  /// Inputs: `relations`.
  /// Returns: `AnimeSearchResult`.
  /// Side effects: None.
  /// Notes: Used by the bangumi.tv by-id fetch, whose relations arrive from a
  /// second request.
  AnimeSearchResult withRelations(List<AnimeExternalRelation> relations) =>
      AnimeSearchResult(
        source: source,
        sourceUrl: sourceUrl,
        title: title,
        titleJa: titleJa,
        titleRomaji: titleRomaji,
        titleEn: titleEn,
        synonyms: synonyms,
        episodes: episodes,
        firstAirDate: firstAirDate,
        airDayOfWeek: airDayOfWeek,
        airTime: airTime,
        endDate: endDate,
        format: format,
        status: status,
        durationMinutes: durationMinutes,
        genres: genres,
        studios: studios,
        score: score,
        scoreMax: scoreMax,
        scoreVotes: scoreVotes,
        scoreRank: scoreRank,
        coverImageUrl: coverImageUrl,
        summary: summary,
        relations: relations,
      );

  /// Purpose: Return the best title to show as the result's headline.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Falls back through the known titles before giving up.
  String get displayTitle {
    final titles = allTitles;
    return titles.isEmpty ? '?' : titles.first;
  }

  /// Purpose: Serialize a fetched result so it can be cached on disk.
  /// Inputs: None.
  /// Returns: `Map<String, dynamic>` holding only the non-null fields.
  /// Side effects: None.
  /// Notes: Backs the background update cache, which downloads a candidate once
  /// and then applies it without going back to the network. Null and empty
  /// fields are omitted so the cache file stays small and readable.
  /// `firstAirDate` and `endDate` are calendar days, not instants — they are
  /// written as-is and read back without a UTC conversion, matching
  /// `_parseCalendarDate` in the anime model.
  Map<String, dynamic> toJson() => {
    'source': source,
    if (sourceUrl != null) 'sourceUrl': sourceUrl,
    if (title != null) 'title': title,
    if (titleJa != null) 'titleJa': titleJa,
    if (titleRomaji != null) 'titleRomaji': titleRomaji,
    if (titleEn != null) 'titleEn': titleEn,
    if (synonyms.isNotEmpty) 'synonyms': synonyms,
    if (episodes != null) 'episodes': episodes,
    if (firstAirDate != null) 'firstAirDate': firstAirDate!.toIso8601String(),
    if (airDayOfWeek != null) 'airDayOfWeek': airDayOfWeek,
    if (airTime != null) 'airTime': airTime,
    if (endDate != null) 'endDate': endDate!.toIso8601String(),
    if (format != null) 'format': format,
    if (status != null) 'status': status,
    if (durationMinutes != null) 'durationMinutes': durationMinutes,
    if (genres.isNotEmpty) 'genres': genres,
    if (studios.isNotEmpty) 'studios': studios,
    if (score != null) 'score': score,
    'scoreMax': scoreMax,
    if (scoreVotes != null) 'scoreVotes': scoreVotes,
    if (scoreRank != null) 'scoreRank': scoreRank,
    if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
    if (summary != null) 'summary': summary,
    if (relations.isNotEmpty)
      'relations': [for (final r in relations) r.toJson()],
  };

  /// Purpose: Rebuild a cached result from its JSON form.
  /// Inputs: `json`.
  /// Returns: A new `AnimeSearchResult`.
  /// Side effects: None.
  /// Notes: Every field is defensive — a cache written by a newer build, or
  /// hand-edited, yields nulls rather than throwing. `source` falls back to an
  /// empty string so a malformed entry is still readable and can be discarded
  /// by the caller.
  factory AnimeSearchResult.fromJson(Map<String, dynamic> json) {
    List<String> stringList(Object? value) =>
        value is List ? value.whereType<String>().toList() : const <String>[];
    DateTime? date(Object? value) =>
        value is String ? DateTime.tryParse(value) : null;
    double? number(Object? value) => value is num ? value.toDouble() : null;

    return AnimeSearchResult(
      source: json['source'] is String ? json['source'] as String : '',
      sourceUrl: json['sourceUrl'] as String?,
      title: json['title'] as String?,
      titleJa: json['titleJa'] as String?,
      titleRomaji: json['titleRomaji'] as String?,
      titleEn: json['titleEn'] as String?,
      synonyms: stringList(json['synonyms']),
      episodes: json['episodes'] is int ? json['episodes'] as int : null,
      firstAirDate: date(json['firstAirDate']),
      airDayOfWeek: json['airDayOfWeek'] is int
          ? json['airDayOfWeek'] as int
          : null,
      airTime: json['airTime'] as String?,
      endDate: date(json['endDate']),
      format: json['format'] as String?,
      status: json['status'] as String?,
      durationMinutes: json['durationMinutes'] is int
          ? json['durationMinutes'] as int
          : null,
      genres: stringList(json['genres']),
      studios: stringList(json['studios']),
      score: number(json['score']),
      scoreMax: number(json['scoreMax']) ?? 10,
      scoreVotes: json['scoreVotes'] is int ? json['scoreVotes'] as int : null,
      scoreRank: json['scoreRank'] is int ? json['scoreRank'] as int : null,
      coverImageUrl: json['coverImageUrl'] as String?,
      summary: json['summary'] as String?,
      relations: [
        if (json['relations'] is List)
          for (final r in json['relations'] as List)
            if (r is Map)
              AnimeExternalRelation.fromJson(Map<String, dynamic>.from(r)),
      ],
    );
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

/// Live progress of one round of [AnimeSearchService.searchAll].
///
/// A search is slow for a reason worth showing: each source has its own 10–15
/// second timeout, and sources that come back empty are queried a second time
/// with titles harvested from the first round. Without this a user watches a
/// bare spinner for up to half a minute with no way to tell work from a hang.
///
/// Each round reports **its own denominator** — the second round only re-queries
/// the sources that found nothing — so the bar fills twice rather than jumping
/// backwards when the total grows mid-search.
class AnimeSearchProgress {
  /// 1 for the first pass, 2 for the cross-language backfill pass.
  final int round;

  /// The sources this round actually queries, in display order.
  final List<String> sources;

  /// Result count per source, for the sources that have answered.
  final Map<String, int> counts;

  /// Sources whose request threw or timed out.
  final Set<String> failed;

  /// Purpose: Create an immutable search progress snapshot.
  /// Inputs: `round`, `sources`, `counts`, `failed`.
  /// Returns: A new `AnimeSearchProgress` instance.
  /// Side effects: None.
  /// Notes: None.
  const AnimeSearchProgress({
    required this.round,
    required this.sources,
    this.counts = const {},
    this.failed = const {},
  });

  /// Purpose: Count the sources that have answered.
  /// Inputs: None.
  /// Returns: `int`.
  /// Side effects: None.
  /// Notes: A failed source counts as answered — it is no longer being waited on.
  int get done => counts.length;

  /// Purpose: Count the sources this round is waiting on in total.
  /// Inputs: None.
  /// Returns: `int`.
  /// Side effects: None.
  /// Notes: None.
  int get total => sources.length;

  /// Purpose: Return the completed fraction of this round.
  /// Inputs: None.
  /// Returns: `double?` in 0..1, or `null` when no source is being queried.
  /// Side effects: None.
  /// Notes: Bind this to a `LinearProgressIndicator.value` directly.
  double? get fraction =>
      total > 0 ? (done / total).clamp(0.0, 1.0).toDouble() : null;

  /// Purpose: Report whether one source is still being waited on.
  /// Inputs: `source`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool isPending(String source) => !counts.containsKey(source);
}

class AnimeSearchService {
  static const userAgent = 'MyAnime/1.6.2 (anime tracker)';

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
  /// `ja`); results carrying a title in that language win a near-tie;
  /// `onProgress` — optional, receives an [AnimeSearchProgress] when each round
  /// starts and again as each source answers.
  /// Returns: `Future<List<AnimeSearchResult>>`.
  /// Side effects: Issues HTTP requests to five external services concurrently,
  /// and to a subset of them a second time when cross-language backfill runs.
  /// Notes: Runs two rounds. Round one sends every source the query variant it
  /// indexes best (Simplified for bangumi.tv, Traditional for acgsecrets.hk,
  /// the Japanese-preferred variant for filmarks.com). Round two re-queries
  /// only the sources that came back empty, using titles harvested from round
  /// one, so a Chinese query can still reach a Japanese-only source. Results
  /// are deduplicated by `sourceUrl` and sorted by descending relevance.
  ///
  /// `onResults`, when given, receives the combined, sorted list so far each
  /// time a source answers with results, so a caller can show them without
  /// waiting for the slowest source. The returned list equals the last list
  /// passed to `onResults` (or is empty when nothing was found).
  static Future<List<AnimeSearchResult>> searchAll(
    String query, {
    String? preferredLanguage,
    void Function(AnimeSearchProgress)? onProgress,
    void Function(List<AnimeSearchResult> soFar)? onResults,
  }) async {
    final variants = queryVariants(query);
    final combined = <String, List<AnimeSearchResult>>{};

    void sourceDone(String source, List<AnimeSearchResult> results) {
      if (results.isEmpty) return;
      combined[source] = [...?combined[source], ...results];
      onResults?.call(_combine(combined, variants, preferredLanguage));
    }

    final firstRound = await _runRound(
      bangumiQuery: ChineseConvert.toSimplified(query),
      acgsecretsQuery: ChineseConvert.toTraditional(query),
      filmarksQuery: query,
      globalQuery: query,
      onProgress: onProgress,
      onSourceDone: sourceDone,
    );

    final emptySources = AnimeSearchSource.all
        .where((s) => (firstRound[s] ?? const []).isEmpty)
        .toSet();
    if (emptySources.isNotEmpty) {
      final backfill = _harvestBackfillTitles(firstRound, variants);
      if (backfill.hasAny) {
        await _runRound(
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
          round: 2,
          onProgress: onProgress,
          onSourceDone: sourceDone,
        );
      }
    }

    return _combine(combined, variants, preferredLanguage);
  }

  /// Purpose: Merge per-source results into one deduplicated, ranked list.
  /// Inputs: `bySource` — results keyed by source name; `variants` — from
  /// [queryVariants]; `preferredLanguage`.
  /// Returns: `List<AnimeSearchResult>` — deduplicated by `sourceUrl` (falling
  /// back to a title), sorted by descending [relevance], ties by source name.
  /// Side effects: None.
  /// Notes: Called after every source answers, so the order depends only on
  /// the results, never on which source happened to answer first.
  static List<AnimeSearchResult> _combine(
    Map<String, List<AnimeSearchResult>> bySource,
    List<String> variants,
    String? preferredLanguage,
  ) {
    // Deduplicate by sourceUrl, preserving source order.
    final seen = <String>{};
    final deduped = <AnimeSearchResult>[];
    for (final source in AnimeSearchSource.all) {
      for (final r in bySource[source] ?? const <AnimeSearchResult>[]) {
        final key = r.sourceUrl ?? r.title ?? r.titleJa ?? '';
        if (seen.add(key)) deduped.add(r);
      }
    }

    deduped.sort((a, b) {
      final cmp = relevance(
        b,
        variants,
        preferredLanguage: preferredLanguage,
      ).compareTo(relevance(a, variants, preferredLanguage: preferredLanguage));
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
      final s = bestSimilarity(title, queries);
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
      relations: result.relations,
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
  static Future<List<AnimeSearchResult>> refreshAll(
    Iterable<String> urls,
  ) async {
    final distinct = urls.where((u) => u.trim().isNotEmpty).toSet().toList();
    if (distinct.isEmpty) return [];
    final fetched = await Future.wait(
      distinct.map((u) => fetchByUrl(u).catchError((_) => null)),
    );
    return fetched.whereType<AnimeSearchResult>().toList();
  }

  /// Purpose: Fetch alternate titles for a query from bangumi.tv.
  /// Inputs: `query` — any language; sent in Simplified form.
  /// Returns: `Future<List<String>>` — Chinese and Latin-script titles of the
  /// confident hits, deduplicated; empty when nothing matched.
  /// Side effects: One HTTP POST to `api.bgm.tv`.
  /// Notes: Exists for the anime1.me lookup: a mainland title and a Taiwanese
  /// one can share no characters at all (间谍过家家 / 間諜家家酒), and
  /// bangumi.tv's 别名 field usually lists both. Only hits scoring at least
  /// `_backfillMinRelevance` contribute, so a stray result cannot inject
  /// unrelated aliases.
  static Future<List<String>> harvestAliases(String query) async {
    final hits = await _searchBangumi(ChineseConvert.toSimplified(query));
    return aliasCandidatesFrom(hits, queryVariants(query));
  }

  /// Purpose: Pick alias strings out of search hits that match the query well.
  /// Inputs: `hits`, `variants` — from [queryVariants].
  /// Returns: `List<String>`, at most six, in hit order.
  /// Side effects: None.
  /// Notes: Keeps Chinese (Han, no kana) and Latin-script titles only — a
  /// Japanese title cannot match anime1's Chinese index and a romaji one can,
  /// because the site keeps Latin franchise names (`SPY×FAMILY`, `GRAND BLUE`).
  @visibleForTesting
  static List<String> aliasCandidatesFrom(
    List<AnimeSearchResult> hits,
    List<String> variants,
  ) {
    const maxAliases = 6;
    final out = <String>[];
    final seen = <String>{};
    for (final hit in hits) {
      if (relevance(hit, variants) < _backfillMinRelevance) continue;
      for (final t in hit.allTitles) {
        if (!_isLikelyChinese(t) && !_isLatinScript(t)) continue;
        if (seen.add(t)) out.add(t);
        if (out.length >= maxAliases) return out;
      }
    }
    return out;
  }

  // ──── Round orchestration ────

  /// Test-only replacements for the per-source fetchers, keyed by source name.
  /// Lets the round logic be exercised without the network; always null in
  /// the app.
  @visibleForTesting
  static Map<String, Future<List<AnimeSearchResult>> Function(String query)>?
  debugSourceOverrides;

  /// Purpose: Query the requested sources once, in parallel, tolerating failures.
  /// Inputs: `bangumiQuery`, `acgsecretsQuery`, `filmarksQuery`, `globalQuery`,
  /// `malQuery`, `anilistQuery`; `round` labels the emitted progress and
  /// `onProgress` receives one snapshot when the round starts and one more as
  /// each source answers; `onSourceDone` receives each source's results as
  /// soon as that source answers successfully.
  /// Returns: `Future<Map<String, List<AnimeSearchResult>>>` keyed by source name.
  /// Side effects: One HTTP request per non-null, non-blank query, unless
  /// [debugSourceOverrides] replaces the fetcher.
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
    int round = 1,
    void Function(AnimeSearchProgress)? onProgress,
    void Function(String source, List<AnimeSearchResult> results)? onSourceDone,
  }) async {
    final active = <String>[];
    final counts = <String, int>{};
    final failed = <String>{};

    void emit() {
      onProgress?.call(
        AnimeSearchProgress(
          round: round,
          sources: List.unmodifiable(active),
          counts: Map.unmodifiable(counts),
          failed: Set.unmodifiable(failed),
        ),
      );
    }

    Future<List<AnimeSearchResult>> run(
      String source,
      String? query,
      Future<List<AnimeSearchResult>> Function(String) fetch,
    ) {
      if (query == null || query.trim().isEmpty) {
        return Future.value(const <AnimeSearchResult>[]);
      }
      active.add(source);
      final fetcher = debugSourceOverrides?[source] ?? fetch;
      return fetcher(query.trim())
          .then((results) {
            counts[source] = results.length;
            // Results first, then progress: a listener reacting to the
            // progress snapshot already sees this source's results.
            onSourceDone?.call(source, results);
            emit();
            return results;
          })
          .catchError((Object _) {
            // A source that threw and a source that found nothing are very
            // different things to a user staring at a slow dialog, so the
            // failure is recorded rather than flattened into "0 results".
            counts[source] = 0;
            failed.add(source);
            emit();
            return <AnimeSearchResult>[];
          });
    }

    final futures = <String, Future<List<AnimeSearchResult>>>{
      AnimeSearchSource.bangumi: run(
        AnimeSearchSource.bangumi,
        bangumiQuery,
        _searchBangumi,
      ),
      AnimeSearchSource.mal: run(
        AnimeSearchSource.mal,
        malQuery ?? globalQuery,
        _searchMAL,
      ),
      AnimeSearchSource.anilist: run(
        AnimeSearchSource.anilist,
        anilistQuery ?? globalQuery,
        _searchAniList,
      ),
      AnimeSearchSource.acgsecrets: run(
        AnimeSearchSource.acgsecrets,
        acgsecretsQuery,
        _searchAcgsecrets,
      ),
      AnimeSearchSource.filmarks: run(
        AnimeSearchSource.filmarks,
        filmarksQuery,
        _searchFilmarks,
      ),
    };

    // `active` is complete only once every `run` call above has returned, so
    // the "everything pending" snapshot is published here rather than inside
    // `run`. The fetch callbacks cannot have fired yet — they are async.
    emit();

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
            'User-Agent': userAgent,
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

    final json =
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
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
  /// Side effects: Two HTTP GETs (10s timeout each) to `api.bgm.tv`: the
  /// subject, then its related subjects.
  /// Notes: Internal helper used within this file only. The v0 subject endpoint
  /// is `/v0/subjects/{id}` — **plural**; the singular path 404s. It returns the
  /// same object shape as v0 search, so one mapper serves both. Since 1.6.0 the
  /// related subjects are fetched too; if that second request fails, the
  /// subject is returned without relations.
  static Future<AnimeSearchResult?> _fetchBangumiById(int id) async {
    final url = Uri.parse('https://api.bgm.tv/v0/subjects/$id');
    final resp = await http
        .get(
          url,
          headers: {'User-Agent': userAgent, 'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return null;
    final json =
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    if (json['id'] == null) return null;
    final subject = mapBangumiSubject(json);
    final relations = await _fetchBangumiRelations(id);
    return relations.isEmpty ? subject : subject.withRelations(relations);
  }

  /// Purpose: Fetch the works bangumi.tv lists as related to a subject.
  /// Inputs: `id`.
  /// Returns: `Future<List<AnimeExternalRelation>>` — empty on any failure.
  /// Side effects: One HTTP GET (10s timeout) to `api.bgm.tv`.
  /// Notes: Internal helper used within this file only. Never throws: the
  /// relations are an extra, and a subject without them still refreshes.
  static Future<List<AnimeExternalRelation>> _fetchBangumiRelations(
    int id,
  ) async {
    try {
      final resp = await http
          .get(
            Uri.parse('https://api.bgm.tv/v0/subjects/$id/subjects'),
            headers: {'User-Agent': userAgent, 'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return const [];
      final json = jsonDecode(utf8.decode(resp.bodyBytes));
      return json is List ? mapBangumiRelations(json) : const [];
    } catch (_) {
      return const [];
    }
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
        if (tag is Map && tag['name'] is String) {
          genres.add(tag['name'] as String);
        }
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
      airDayOfWeek: parseBangumiWeekday(_bangumiInfoboxText(infobox, '放送星期')),
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
    final m = RegExp(
      r'(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日',
    ).firstMatch(value);
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
          headers: {'User-Agent': userAgent, 'Accept': 'application/json'},
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
  /// returns the same object shape as search, plus the relations that
  /// [mapJikanRelations] reads (since 1.6.0).
  static Future<AnimeSearchResult?> _fetchMalById(int id) async {
    final url = Uri.parse('https://api.jikan.moe/v4/anime/$id/full');
    final resp = await http
        .get(
          url,
          headers: {'User-Agent': userAgent, 'Accept': 'application/json'},
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
      relations: mapJikanRelations(m),
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

  /// How long a downloaded acgsecrets.hk season page is reused. The pages are
  /// large (about 2.6 MB) and slow to generate (6–9 s), and change rarely.
  static const _acgsecretsPageTtl = Duration(minutes: 30);

  /// Per-request timeout for one acgsecrets.hk season page.
  static const _acgsecretsTimeout = Duration(seconds: 15);

  /// Parsed season pages kept in memory for [_acgsecretsPageTtl], keyed by
  /// season code. Holds the in-flight future too, so two searches started
  /// together share one download.
  static final _acgsecretsPages =
      <String, ({DateTime at, Future<List<AnimeSearchResult>?> items})>{};

  static final _acgsecretsLdPattern = RegExp(
    r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>',
    dotAll: true,
  );

  /// Purpose: acgsecrets.hk — fuzzy-match the query against recent season pages.
  /// Inputs: `query`.
  /// Returns: `Future<List<AnimeSearchResult>>` sorted by descending match
  /// score, then by season (current season first); at most `_maxPerSource`.
  /// Side effects: Up to four HTTP GETs to `acgsecrets.hk`, in parallel, 15 s
  /// timeout each; pages are cached in memory for 30 minutes.
  /// Notes: Internal helper used within this file only. The site has no search
  /// endpoint, so whole season pages ([acgsecretsSeasons]) are downloaded and
  /// matched locally. One page failing or timing out only loses that season;
  /// the source counts as failed only when every page failed.
  static Future<List<AnimeSearchResult>> _searchAcgsecrets(String query) async {
    final seasons = acgsecretsSeasons(DateTime.now());
    final pages = await Future.wait(seasons.map(_acgsecretsSeason));
    if (pages.every((p) => p == null)) {
      throw Exception('acgsecrets.hk: no season page could be loaded');
    }

    final queries = {
      query,
      ChineseConvert.toTraditional(query),
      ChineseConvert.toSimplified(query),
    };
    final scored = <(AnimeSearchResult, double, int)>[];
    final seenUrls = <String>{};
    for (var i = 0; i < pages.length; i++) {
      for (final r in pages[i] ?? const <AnimeSearchResult>[]) {
        final names = [?r.title, ?r.titleJa, ...r.synonyms];
        var best = 0.0;
        for (final n in names) {
          for (final q in queries) {
            final s = _similarity(n, q);
            if (s > best) best = s;
          }
        }
        if (best < 0.3) continue;
        if (r.sourceUrl != null && !seenUrls.add(r.sourceUrl!)) continue;
        scored.add((r, best, i));
      }
    }
    scored.sort((a, b) {
      final cmp = b.$2.compareTo(a.$2);
      return cmp != 0 ? cmp : a.$3.compareTo(b.$3);
    });
    return scored.take(_maxPerSource).map((e) => e.$1).toList();
  }

  /// Purpose: Get one season page's entries, from the cache or the network.
  /// Inputs: `season` — `YYYYMM`.
  /// Returns: `Future<List<AnimeSearchResult>?>` — null when the page could
  /// not be loaded.
  /// Side effects: May issue one HTTP GET; updates [_acgsecretsPages].
  /// Notes: Internal helper used within this file only. A failed load is
  /// dropped from the cache so the next search tries again.
  static Future<List<AnimeSearchResult>?> _acgsecretsSeason(String season) {
    final now = DateTime.now();
    final hit = _acgsecretsPages[season];
    if (hit != null && now.difference(hit.at) < _acgsecretsPageTtl) {
      return hit.items;
    }
    final items = _fetchAcgsecretsSeason(season);
    final entry = (at: now, items: items);
    _acgsecretsPages[season] = entry;
    items.then((list) {
      if (list == null && identical(_acgsecretsPages[season], entry)) {
        _acgsecretsPages.remove(season);
      }
    });
    return items;
  }

  /// Purpose: Download and parse one acgsecrets.hk season page.
  /// Inputs: `season` — `YYYYMM`.
  /// Returns: `Future<List<AnimeSearchResult>?>` — every entry on the page;
  /// null on a non-200 answer, a timeout or a network error.
  /// Side effects: One HTTP GET with a 15 s timeout.
  /// Notes: Internal helper used within this file only. Never throws.
  static Future<List<AnimeSearchResult>?> _fetchAcgsecretsSeason(
    String season,
  ) async {
    try {
      final resp = await http
          .get(
            Uri.parse('https://acgsecrets.hk/bangumi/$season/'),
            headers: {'User-Agent': userAgent},
          )
          .timeout(_acgsecretsTimeout);
      if (resp.statusCode != 200) return null;
      return parseAcgsecretsPage(utf8.decode(resp.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  /// Purpose: Read every entry from an acgsecrets.hk season page's JSON-LD.
  /// Inputs: `html` — the page.
  /// Returns: `List<AnimeSearchResult>` — one per `itemListElement` entry that
  /// has a name, in page order.
  /// Side effects: None.
  /// Notes: Each entry is read on its own, so one malformed entry never drops
  /// the rest of the page. Before 1.6.1 a single entry whose
  /// `numberOfEpisodes` was the string `"19"` silently discarded every entry
  /// after it.
  @visibleForTesting
  static List<AnimeSearchResult> parseAcgsecretsPage(String html) {
    final out = <AnimeSearchResult>[];
    for (final m in _acgsecretsLdPattern.allMatches(html)) {
      Object? data;
      try {
        data = jsonDecode(m.group(1)!);
      } catch (_) {
        continue;
      }
      if (data is! Map) continue;
      final items = data['itemListElement'];
      if (items is! List) continue;
      for (final item in items) {
        if (item is! Map) continue;
        try {
          if (_acgsecretsItem(item) case final r?) out.add(r);
        } catch (_) {
          // Skip just this entry.
        }
      }
    }
    return out;
  }

  /// Purpose: Map one JSON-LD entry to a search result.
  /// Inputs: `item` — one `itemListElement` entry.
  /// Returns: `AnimeSearchResult?` — null when the entry has no name.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Accepts
  /// `alternateName` as a string or a list, and `numberOfEpisodes` as a
  /// number or a numeric string; the Japanese title is the first alternate
  /// name containing kana.
  static AnimeSearchResult? _acgsecretsItem(Map item) {
    final rawName = item['name'];
    final name = rawName is String ? rawName.trim() : '';
    final rawAlt = item['alternateName'];
    final altNames = [
      if (rawAlt is String) rawAlt,
      if (rawAlt is List) ...rawAlt.whereType<String>(),
    ].where((n) => n.trim().isNotEmpty).toList();
    if (name.isEmpty && altNames.isEmpty) return null;
    final titleJa = altNames.where(_containsJapanese).firstOrNull;
    final startDate = item['startDate'];
    final image = item['image'];
    final url = item['url'];
    return AnimeSearchResult(
      source: AnimeSearchSource.acgsecrets,
      sourceUrl: url is String ? url : null,
      title: name.isNotEmpty ? name : null,
      titleJa: titleJa,
      synonyms: altNames.where((n) => n != titleJa).toList(),
      episodes: _looseInt(item['numberOfEpisodes']),
      coverImageUrl: image is String ? image : null,
      firstAirDate: startDate is String ? DateTime.tryParse(startDate) : null,
    );
  }

  /// Purpose: Read an integer that may arrive as a number or a numeric string.
  /// Inputs: `value`.
  /// Returns: `int?` — null for anything else.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static int? _looseInt(Object? value) => switch (value) {
    final int n => n,
    final num n => n.toInt(),
    final String s => int.tryParse(s.trim()),
    _ => null,
  };

  /// Purpose: List the acgsecrets.hk season pages worth searching.
  /// Inputs: `now` — the local date.
  /// Returns: `List<String>` — `YYYYMM` codes (month 01/04/07/10): the current
  /// season, the next one, then the two before the current one.
  /// Side effects: None.
  /// Notes: The next season covers shows added before they air; the two
  /// earlier seasons cover a show the user catches up on late. The order is
  /// also the tie-break order for equally good matches.
  @visibleForTesting
  static List<String> acgsecretsSeasons(DateTime now) {
    final start = DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1);
    String code(int offsetQuarters) {
      final d = DateTime(start.year, start.month + offsetQuarters * 3);
      return '${d.year}${d.month.toString().padLeft(2, '0')}';
    }

    return [code(0), code(1), code(-1), code(-2)];
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
        .get(url, headers: {'User-Agent': userAgent, 'Accept-Language': 'ja'})
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
          titleJa: decodeHtmlEntities(title),
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
            titleJa: decodeHtmlEntities(title),
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

  /// Relation edges, asked for only by the by-id refresh: search results
  /// never need them, and they would multiply the search payload.
  static const _aniListRelationFields = r'''
      relations { edges { relationType(version: 2) node { id type format siteUrl title { romaji english native } } } }
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
$_aniListMediaFields$_aniListRelationFields  }
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
            'User-Agent': userAgent,
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
      synonyms:
          (m['synonyms'] as List?)?.whereType<String>().toList() ?? const [],
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
      relations: mapAniListRelations(m),
    );
  }

  // ──── Relations ────

  /// AniList `relationType(version: 2)` values, normalised.
  static const _aniListRelationTypes = {
    'PREQUEL': AnimeRelationType.prequel,
    'SEQUEL': AnimeRelationType.sequel,
    'PARENT': AnimeRelationType.parent,
    'SIDE_STORY': AnimeRelationType.sideStory,
    'SUMMARY': AnimeRelationType.summary,
    'COMPILATION': AnimeRelationType.summary,
    'SPIN_OFF': AnimeRelationType.spinOff,
    'ALTERNATIVE': AnimeRelationType.alternative,
  };

  /// Jikan (MyAnimeList) relation names, normalised.
  static const _jikanRelationTypes = {
    'Prequel': AnimeRelationType.prequel,
    'Sequel': AnimeRelationType.sequel,
    'Parent Story': AnimeRelationType.parent,
    'Full Story': AnimeRelationType.parent,
    'Side Story': AnimeRelationType.sideStory,
    'Summary': AnimeRelationType.summary,
    'Spin-Off': AnimeRelationType.spinOff,
    'Alternative Setting': AnimeRelationType.alternative,
    'Alternative Version': AnimeRelationType.alternative,
  };

  /// bangumi.tv relation names, normalised. Checked against the live
  /// `/v0/subjects/{id}/subjects` endpoint on 2026-09-24.
  static const _bangumiRelationTypes = {
    '前传': AnimeRelationType.prequel,
    '续集': AnimeRelationType.sequel,
    '主线故事': AnimeRelationType.parent,
    '番外篇': AnimeRelationType.sideStory,
    '总集篇': AnimeRelationType.summary,
    '衍生': AnimeRelationType.spinOff,
    '不同演绎': AnimeRelationType.alternative,
    '不同世界观': AnimeRelationType.alternative,
  };

  /// Purpose: Build one relation from a source's raw relation name.
  /// Inputs: `source`, `raw` — the source's own name; `table`; `targetUrl`,
  /// `title`, `format`.
  /// Returns: `AnimeExternalRelation`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. A name the table does
  /// not know becomes `other`, with the raw name kept as `rawType`.
  static AnimeExternalRelation _relation(
    String source,
    String raw,
    Map<String, AnimeRelationType> table, {
    String? targetUrl,
    String? title,
    String? format,
  }) {
    final type = table[raw];
    return AnimeExternalRelation(
      source: source,
      type: type ?? AnimeRelationType.other,
      targetUrl: targetUrl,
      title: title,
      format: format,
      extraJson: type == null ? {'rawType': raw} : const {},
    );
  }

  /// Purpose: Map AniList relation edges onto relations.
  /// Inputs: `m` — a media object from the by-id query.
  /// Returns: `List<AnimeExternalRelation>` — anime targets only; empty when
  /// the object carries no `relations` (search results).
  /// Side effects: None.
  /// Notes: The title is the native one where known, else romaji, else English.
  @visibleForTesting
  static List<AnimeExternalRelation> mapAniListRelations(
    Map<String, dynamic> m,
  ) {
    final edges = (m['relations'] as Map?)?['edges'];
    if (edges is! List) return const [];
    final out = <AnimeExternalRelation>[];
    for (final edge in edges) {
      if (edge is! Map) continue;
      final node = edge['node'];
      final raw = edge['relationType'];
      if (node is! Map || raw is! String || node['type'] != 'ANIME') continue;
      final titles = node['title'] is Map ? node['title'] as Map : const {};
      final id = node['id'];
      out.add(
        _relation(
          AnimeSearchSource.anilist,
          raw,
          _aniListRelationTypes,
          targetUrl:
              node['siteUrl'] as String? ??
              (id is int ? 'https://anilist.co/anime/$id' : null),
          title:
              titles['native'] as String? ??
              titles['romaji'] as String? ??
              titles['english'] as String?,
          format: node['format'] as String?,
        ),
      );
    }
    return out;
  }

  /// Purpose: Map Jikan's `/full` relations onto relations.
  /// Inputs: `m` — an anime object from `/anime/{id}/full`.
  /// Returns: `List<AnimeExternalRelation>` — entries whose `type` is `anime`.
  /// Side effects: None.
  /// Notes: Search results carry no `relations`, so they map to an empty list.
  @visibleForTesting
  static List<AnimeExternalRelation> mapJikanRelations(Map<String, dynamic> m) {
    final groups = m['relations'];
    if (groups is! List) return const [];
    final out = <AnimeExternalRelation>[];
    for (final group in groups) {
      if (group is! Map || group['relation'] is! String) continue;
      final entries = group['entry'];
      if (entries is! List) continue;
      for (final e in entries) {
        if (e is! Map || e['type'] != 'anime') continue;
        final id = e['mal_id'];
        out.add(
          _relation(
            AnimeSearchSource.mal,
            group['relation'] as String,
            _jikanRelationTypes,
            targetUrl: id is int ? 'https://myanimelist.net/anime/$id' : null,
            title: e['name'] as String?,
          ),
        );
      }
    }
    return out;
  }

  /// Purpose: Map bangumi.tv's related-subjects list onto relations.
  /// Inputs: `list` — the body of `GET /v0/subjects/{id}/subjects`.
  /// Returns: `List<AnimeExternalRelation>` — anime targets (`type == 2`) only.
  /// Side effects: None.
  /// Notes: The title is `name_cn` when present, else `name`.
  @visibleForTesting
  static List<AnimeExternalRelation> mapBangumiRelations(List<dynamic> list) {
    final out = <AnimeExternalRelation>[];
    for (final s in list) {
      if (s is! Map || s['type'] != 2 || s['relation'] is! String) continue;
      final id = s['id'];
      final cn = s['name_cn'];
      out.add(
        _relation(
          AnimeSearchSource.bangumi,
          s['relation'] as String,
          _bangumiRelationTypes,
          targetUrl: id is int ? 'https://bgm.tv/subject/$id' : null,
          title: cn is String && cn.isNotEmpty ? cn : s['name'] as String?,
        ),
      );
    }
    return out;
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
      final previous = weekday == DateTime.monday
          ? DateTime.sunday
          : weekday - 1;
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

  /// Purpose: Compute the best similarity score of [title] against any of [queries].
  /// Inputs: `title`, `queries`.
  /// Returns: `double` in `0.0..1.0`.
  /// Side effects: None.
  /// Notes: Shared with `Anime1Service`, which ranks scraped search hits with
  /// it; the index path scores pre-folded strings through [similarityRaw].
  static double bestSimilarity(String title, List<String> queries) {
    double best = 0;
    for (final q in queries) {
      final s = _similarity(title, q);
      if (s > best) best = s;
    }
    return best;
  }

  /// Purpose: Fuzzy similarity of two titles, script- and punctuation-insensitive.
  /// Inputs: `a`, `b`.
  /// Returns: `double` in `0.0..1.0`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Takes the better of
  /// [similarityRaw] on the strings as given and on their [foldTitle] forms,
  /// so a Simplified query scores fully against a Traditional title and
  /// `【推しの子】` against `我推的孩子`-style punctuation variants. Through
  /// 1.5.6 the second pass normalized to Traditional, which is one-to-many
  /// (干 → 幹 or 乾) and therefore missed exactly the pairs it was meant to
  /// catch; Simplified is the many-to-one direction.
  static double _similarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    var best = similarityRaw(a, b);
    final fa = foldTitle(a);
    final fb = foldTitle(b);
    if (fa.isNotEmpty && fb.isNotEmpty) {
      final s = similarityRaw(fa, fb);
      if (s > best) best = s;
    }
    return best;
  }

  /// Purpose: The three-measure similarity core on strings exactly as given.
  /// Inputs: `a`, `b`.
  /// Returns: `double` in `0.0..1.0` — the best of LCS-Dice, character-set
  /// Dice, and containment (`0.7 + 0.3 · shorter/longer`).
  /// Side effects: None.
  /// Notes: Public so `Anime1Service` can score pre-folded strings without
  /// folding again per pair; every other caller wants [_similarity].
  static double similarityRaw(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    double best = 0;
    // LCS-based Dice coefficient.
    final lcs = 2.0 * _lcsLength(a, b) / (a.length + b.length);
    if (lcs > best) best = lcs;
    // Character-set Dice coefficient (order-independent).
    final set1 = a.runes.toSet();
    final set2 = b.runes.toSet();
    final shared = set1.intersection(set2).length;
    final dice = 2.0 * shared / (set1.length + set2.length);
    if (dice > best) best = dice;
    // Containment: if one contains the other, high score.
    if (a.contains(b) || b.contains(a)) {
      final shorter = a.length < b.length ? a.length : b.length;
      final longer = a.length > b.length ? a.length : b.length;
      final cont = shorter / longer;
      // Guarantee at least 0.7 for containment.
      final score = 0.7 + 0.3 * cont;
      if (score > best) best = score;
    }
    return best;
  }

  /// Purpose: Order-aware similarity only — LCS-Dice or containment.
  /// Inputs: `a`, `b`.
  /// Returns: `double` in `0.0..1.0`.
  /// Side effects: None.
  /// Notes: The character-set Dice term in [similarityRaw] is blind to
  /// order, which on short Latin strings lets `bocchitherock` and `tomjerry`
  /// share half their letters. `Anime1Service` requires this order-aware
  /// score to clear a floor as well, so such pairs are never offered.
  static double orderedSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    var best = 2.0 * _lcsLength(a, b) / (a.length + b.length);
    if (a.contains(b) || b.contains(a)) {
      final shorter = a.length < b.length ? a.length : b.length;
      final longer = a.length > b.length ? a.length : b.length;
      final score = 0.7 + 0.3 * shorter / longer;
      if (score > best) best = score;
    }
    return best;
  }

  static final _foldStrip = RegExp(r'[\s\p{P}\p{S}]+', unicode: true);

  /// Purpose: Normalize a title for matching — never for display.
  /// Inputs: `s`.
  /// Returns: `String` — fullwidth ASCII made halfwidth, lowercased,
  /// whitespace and Unicode punctuation/symbols removed, then converted to
  /// Simplified Chinese.
  /// Side effects: None.
  /// Notes: Simplified is the canonical side because Traditional→Simplified
  /// is many-to-one (乾/幹 → 干, 髮/發 → 发). The conversion also folds
  /// Japanese kanji (滅 → 灭), so `鬼滅の刃` reaches `鬼滅之刃`. Symbols such
  /// as `×` in `SPY×FAMILY` are stripped on both sides, so they never decide
  /// a match.
  static String foldTitle(String s) {
    if (s.isEmpty) return s;
    final buf = StringBuffer();
    for (final c in s.runes) {
      if (c >= 0xFF01 && c <= 0xFF5E) {
        buf.writeCharCode(c - 0xFEE0);
      } else if (c == 0x3000) {
        buf.write(' ');
      } else {
        buf.writeCharCode(c);
      }
    }
    final stripped = buf.toString().toLowerCase().replaceAll(_foldStrip, '');
    return ChineseConvert.toSimplified(stripped);
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

  /// Purpose: Provide the internal decode html entities helper for this file.
  /// Inputs: `text`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static String decodeHtmlEntities(String text) {
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
