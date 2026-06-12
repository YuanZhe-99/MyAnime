import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../../features/anime/models/anime.dart';
import '../../features/anime/services/anime_search_service.dart';
import '../../features/anime/services/anime_storage.dart';
import '../utils/jst_time.dart';

enum _ApiRankingTime { all, quarter, year, range }

class _RankingQuery {
  final _ApiRankingTime time;
  final int? year;
  final int? quarter;
  final int? startYear;
  final int? startQuarter;
  final int? endYear;
  final int? endQuarter;
  final AnimeType? type;
  final AnimeRatingField field;
  final bool descending;
  final int limit;

  /// Purpose: Create parsed API ranking query options.
  /// Inputs: `time`, `year`, `quarter`, `startYear`, `startQuarter`, `endYear`, `endQuarter`, `type`, `field`, `descending`, `limit`.
  /// Returns: A new `_RankingQuery` instance.
  /// Side effects: None.
  /// Notes: Internal value object used by `/anime/ranking`.
  const _RankingQuery({
    required this.time,
    this.year,
    this.quarter,
    this.startYear,
    this.startQuarter,
    this.endYear,
    this.endQuarter,
    this.type,
    required this.field,
    required this.descending,
    required this.limit,
  });
}

class LocalApiServer {
  static HttpServer? _server;
  static int _port = 7788;
  static String _listenAddress = 'localhost';
  static bool _enabled = false;
  static String? _username;
  static String? _password;
  static String? _lastError;

  /// Purpose: Return the configured API server port.
  /// Inputs: None.
  /// Returns: `int`.
  /// Side effects: None.
  /// Notes: None.
  static int get port => _port;

  /// Purpose: Return the configured API server listen address.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: None.
  static String get listenAddress => _listenAddress;

  /// Purpose: Return whether the API server is enabled in saved settings.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  static bool get enabled => _enabled;

  /// Purpose: Return whether running is true.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  static bool get isRunning => _server != null;

  /// Purpose: Return the last startup or runtime error code for the API server.
  /// Inputs: None.
  /// Returns: `String?`.
  /// Side effects: None.
  /// Notes: None.
  static String? get lastError => _lastError;

  /// Purpose: Load config into the current workflow or state.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<void> loadConfig() async {
    final config = await AnimeStorage.readConfig();
    _port = config['apiPort'] as int? ?? 7788;
    _listenAddress = config['apiListenAddress'] as String? ?? 'localhost';
    _enabled = config['apiEnabled'] as bool? ?? false;
    _username = config['apiUsername'] as String?;
    _password = config['apiPassword'] as String?;
  }

  /// Purpose: Implement the start behavior for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<void> start() async {
    await loadConfig();
    await stop();
    _lastError = null;
    if (!_enabled) return;

    // Warn about missing credentials on non-loopback
    final isNonLoopback =
        _listenAddress == '0.0.0.0' ||
        (_listenAddress != 'localhost' && _listenAddress != '127.0.0.1');
    final hasCredentials =
        _username != null &&
        _username!.isNotEmpty &&
        _password != null &&
        _password!.isNotEmpty;
    if (isNonLoopback && !hasCredentials) {
      _lastError = 'credentials_required';
      return;
    }

    final router = Router();
    router.get('/ping', _handlePing);
    router.post('/anime/search', _handleSearch);
    router.post('/anime/add', _handleAdd);
    router.get('/anime/list', _handleList);
    router.get('/anime/unwatched', _handleUnwatched);
    router.get('/anime/history', _handleHistory);
    router.get('/anime/ranking', _handleRanking);

    final handler = const Pipeline()
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_authMiddleware())
        .addMiddleware(_errorMiddleware())
        .addHandler(router.call);

    try {
      final InternetAddress bindAddress;
      if (_listenAddress == '0.0.0.0') {
        bindAddress = InternetAddress.anyIPv4;
      } else if (_listenAddress == 'localhost' ||
          _listenAddress == '127.0.0.1') {
        bindAddress = InternetAddress.loopbackIPv4;
      } else {
        bindAddress = InternetAddress(
          _listenAddress,
          type: InternetAddressType.any,
        );
      }
      _server = await shelf_io.serve(handler, bindAddress, _port);
      // ignore: avoid_print
      print('[LocalApiServer] listening on port $_port');
    } catch (e) {
      _lastError = e.toString();
      // ignore: avoid_print
      print('[LocalApiServer] failed to start: $e');
    }
  }

  /// Purpose: Implement the stop behavior for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  /// Purpose: Implement the restart behavior for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<void> restart() async {
    await loadConfig();
    await start();
  }

  // ── Route handlers ──

  /// Purpose: Provide the internal handle ping helper for this file.
  /// Inputs: `request`.
  /// Returns: `Future<Response>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static Future<Response> _handlePing(Request request) async {
    return _json({'status': 'ok'});
  }

  /// Purpose: Provide the internal handle search helper for this file.
  /// Inputs: `request`.
  /// Returns: `Future<Response>`.
  /// Side effects: May perform network or file-system operations.
  /// Notes: Internal helper used within this file only.
  static Future<Response> _handleSearch(Request request) async {
    final body = await _parseBody(request);
    if (body == null) return _error(400, 'invalid JSON body');
    final query = body['query'] as String?;
    if (query == null || query.trim().isEmpty) {
      return _error(400, 'query is required');
    }
    final results = await AnimeSearchService.searchAll(query.trim());
    final list = results
        .take(5)
        .map(
          (r) => {
            'source': r.source,
            'sourceUrl': r.sourceUrl,
            'title': r.title,
            'titleJa': r.titleJa,
            'episodes': r.episodes,
            'firstAirDate': r.firstAirDate?.toIso8601String(),
            'airDayOfWeek': r.airDayOfWeek,
            'airTime': r.airTime,
            'coverImageUrl': r.coverImageUrl,
            'summary': r.summary,
          },
        )
        .toList();
    return _json(list);
  }

  /// Purpose: Provide the internal handle add helper for this file.
  /// Inputs: `request`.
  /// Returns: `Future<Response>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static Future<Response> _handleAdd(Request request) async {
    final body = await _parseBody(request);
    if (body == null) return _error(400, 'invalid JSON body');
    final title = body['title'] as String?;
    final titleJa = body['titleJa'] as String?;
    if ((title == null || title.isEmpty) &&
        (titleJa == null || titleJa.isEmpty)) {
      return _error(400, 'title or titleJa is required');
    }
    DateTime? firstAirDate;
    final dateStr = body['firstAirDate'] as String?;
    if (dateStr != null && dateStr.isNotEmpty) {
      firstAirDate = DateTime.tryParse(dateStr);
    }
    final anime = Anime.create(
      title: title,
      titleJa: titleJa,
      endEpisode: body['episodes'] as int?,
      firstAirDate: firstAirDate,
      airDayOfWeek: body['airDayOfWeek'] as int?,
      airTime: body['airTime'] as String?,
      infoUrl: body['sourceUrl'] as String?,
    );
    await AnimeStorage.addOrUpdate(anime);
    return _json({
      'success': true,
      'id': anime.id,
      'title': anime.displayTitle,
    });
  }

  /// Purpose: Provide the internal handle list helper for this file.
  /// Inputs: `request`.
  /// Returns: `Future<Response>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static Future<Response> _handleList(Request request) async {
    final data = await AnimeStorage.load();
    final allFiltered = _filterBySeason(data.animes, request, sample: false);
    final sampled = _filterBySeason(data.animes, request);
    return _json({
      'total': allFiltered.length,
      'counts': _computeCounts(allFiltered),
      'data': sampled.map(_animeToJson).toList(),
    });
  }

  /// Purpose: Provide the internal handle unwatched helper for this file.
  /// Inputs: `request`.
  /// Returns: `Future<Response>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static Future<Response> _handleUnwatched(Request request) async {
    final data = await AnimeStorage.load();
    final now = JstTime.now();
    final results = <Map<String, dynamic>>[];
    for (final anime in data.animes) {
      final lastEp = _episodeScanEnd(anime);
      for (var ep = anime.startEpisode; ep <= lastEp; ep++) {
        final status = anime.episodeStatuses[ep] ?? EpisodeStatus.unwatched;
        if (status == EpisodeStatus.unwatched) {
          final airDate = anime.getEpisodeAirDate(ep);
          if (airDate != null && !airDate.isAfter(now)) {
            final json = _animeToJson(anime);
            json['nextUnwatchedEpisode'] = ep;
            json['episodeAirDate'] = _jstToUtcString(airDate);
            results.add(json);
          }
          break; // only the earliest unwatched episode per anime
        }
      }
    }
    results.sort((a, b) {
      final aDate = a['episodeAirDate'] as String?;
      final bDate = b['episodeAirDate'] as String?;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });
    return _json(results);
  }

  /// Purpose: Provide the internal handle history helper for this file.
  /// Inputs: `request`.
  /// Returns: `Future<Response>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static Future<Response> _handleHistory(Request request) async {
    final data = await AnimeStorage.load();
    final allFiltered = _filterBySeason(data.animes, request, sample: false);
    final sampled = _filterBySeason(data.animes, request);
    return _json({
      'total': allFiltered.length,
      'counts': _computeCounts(allFiltered),
      'data': sampled.map(_animeToJson).toList(),
    });
  }

  /// Purpose: Return ranked anime with personal scores.
  /// Inputs: `request`.
  /// Returns: `Future<Response>`.
  /// Side effects: Reads anime storage.
  /// Notes: Supports time, type, score field, order, and limit query parameters.
  static Future<Response> _handleRanking(Request request) async {
    final data = await AnimeStorage.load();
    final result = buildRankingSnapshotForQuery(
      data.animes,
      request.url.queryParameters,
    );
    final error = result.error;
    if (error != null) return _error(400, error);
    return _json(result.data!);
  }

  // ── Helpers ──

  /// Purpose: Build the `/anime/ranking` response from anime data and query parameters.
  /// Inputs: `animes`, `queryParameters`.
  /// Returns: A record containing response data or an error message.
  /// Side effects: None.
  /// Notes: Shared by the route handler and tests so ranking semantics stay verifiable.
  static ({Map<String, dynamic>? data, String? error})
  buildRankingSnapshotForQuery(
    List<Anime> animes,
    Map<String, String> queryParameters,
  ) {
    final parsed = _parseRankingQuery(queryParameters);
    final error = parsed.error;
    if (error != null) return (data: null, error: error);

    final query = parsed.query!;
    final ranked = animes.where((anime) {
      if (!_matchesRankingQuery(anime, query)) return false;
      return anime.rating?.scoreFor(query.field) != null;
    }).toList();

    ranked.sort((a, b) {
      final aScore = a.rating!.scoreFor(query.field)!;
      final bScore = b.rating!.scoreFor(query.field)!;
      final scoreCompare = query.descending
          ? bScore.compareTo(aScore)
          : aScore.compareTo(bScore);
      if (scoreCompare != 0) return scoreCompare;
      return a.displayTitle.compareTo(b.displayTitle);
    });

    final limited = ranked.take(query.limit).toList();
    final rows = List<Map<String, dynamic>>.generate(limited.length, (index) {
      final anime = limited[index];
      return {
        'rank': index + 1,
        'score': anime.rating!.scoreFor(query.field),
        ..._animeToJson(anime),
      };
    });

    return (
      data: {
        'total': ranked.length,
        'filters': _rankingFiltersToJson(query),
        'sort': {
          'field': query.field.name,
          'order': query.descending ? 'desc' : 'asc',
        },
        'limit': query.limit,
        'data': rows,
      },
      error: null,
    );
  }

  /// Purpose: Parse `?season=` query param and filter anime list.
  /// Inputs: `animes`, `request`, `sample`.
  /// Returns: `List<Anime>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Parse `?season=` query param and filter anime list. Values: - absent or `current` → current JST quarter - `YYYYQn` (e.g. `2026Q2`) → specific quarter - `unassigned` → anime without firstAirDate - `all` → all anime (random 40)
  static List<Anime> _filterBySeason(
    List<Anime> animes,
    Request request, {
    bool sample = true,
  }) {
    final season = request.url.queryParameters['season']?.trim() ?? 'current';

    if (season == 'all') {
      if (!sample || animes.length <= 40) return animes;
      final shuffled = List<Anime>.from(animes)..shuffle(Random());
      return shuffled.take(40).toList();
    }

    if (season == 'unassigned') {
      return animes.where((a) => a.firstAirDate == null).toList();
    }

    int year;
    int quarter;
    if (season == 'current') {
      final now = JstTime.now();
      year = now.year;
      quarter = (now.month - 1) ~/ 3 + 1;
    } else {
      // Expect format YYYYQn, e.g. 2026Q2
      final match = RegExp(r'^(\d{4})Q([1-4])$').firstMatch(season);
      if (match == null) {
        return animes; // invalid format, return all
      }
      year = int.parse(match.group(1)!);
      quarter = int.parse(match.group(2)!);
    }
    return animes.where((a) => a.airsInQuarter(year, quarter)).toList();
  }

  /// Purpose: Parse `/anime/ranking` query parameters into typed options.
  /// Inputs: `queryParameters`.
  /// Returns: A record containing parsed query options or an error message.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static ({_RankingQuery? query, String? error}) _parseRankingQuery(
    Map<String, String> queryParameters,
  ) {
    final timeValue = (queryParameters['time'] ?? 'all').trim();
    final time = switch (timeValue) {
      '' || 'all' => _ApiRankingTime.all,
      'quarter' => _ApiRankingTime.quarter,
      'year' => _ApiRankingTime.year,
      'range' => _ApiRankingTime.range,
      _ => null,
    };
    if (time == null) {
      return (query: null, error: 'invalid time filter');
    }

    int? year;
    int? quarter;
    int? startYear;
    int? startQuarter;
    int? endYear;
    int? endQuarter;
    switch (time) {
      case _ApiRankingTime.all:
        break;
      case _ApiRankingTime.quarter:
        final parsed = _parseQuarterId(
          queryParameters['season']?.trim() ?? 'current',
          allowCurrent: true,
        );
        if (parsed == null) {
          return (query: null, error: 'invalid season');
        }
        year = parsed.$1;
        quarter = parsed.$2;
      case _ApiRankingTime.year:
        final yearText = queryParameters['year']?.trim();
        year = yearText == null || yearText.isEmpty
            ? JstTime.now().year
            : int.tryParse(yearText);
        if (year == null || year < 1) {
          return (query: null, error: 'invalid year');
        }
      case _ApiRankingTime.range:
        final start = _parseQuarterId(queryParameters['start']?.trim());
        final end = _parseQuarterId(queryParameters['end']?.trim());
        if (start == null || end == null) {
          return (query: null, error: 'invalid range');
        }
        startYear = start.$1;
        startQuarter = start.$2;
        endYear = end.$1;
        endQuarter = end.$2;
    }

    final type = _parseAnimeTypeParam(queryParameters['type']);
    if (type.error != null) return (query: null, error: type.error);

    final field = _parseRatingFieldParam(queryParameters['field']);
    if (field.error != null) return (query: null, error: field.error);

    final orderValue = (queryParameters['order'] ?? 'desc').trim();
    final descending = switch (orderValue) {
      '' || 'desc' => true,
      'asc' => false,
      _ => null,
    };
    if (descending == null) {
      return (query: null, error: 'invalid order');
    }

    final limitText = queryParameters['limit']?.trim();
    final limit = limitText == null || limitText.isEmpty
        ? 20
        : int.tryParse(limitText);
    if (limit == null || limit < 1 || limit > 100) {
      return (query: null, error: 'invalid limit');
    }

    return (
      query: _RankingQuery(
        time: time,
        year: year,
        quarter: quarter,
        startYear: startYear,
        startQuarter: startQuarter,
        endYear: endYear,
        endQuarter: endQuarter,
        type: type.value,
        field: field.value!,
        descending: descending,
        limit: limit,
      ),
      error: null,
    );
  }

  /// Purpose: Parse a `YYYYQn` quarter identifier.
  /// Inputs: `value`, `allowCurrent`.
  /// Returns: A `(year, quarter)` record or null.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static (int, int)? _parseQuarterId(
    String? value, {
    bool allowCurrent = false,
  }) {
    if (allowCurrent &&
        (value == null || value.isEmpty || value == 'current')) {
      final now = JstTime.now();
      return (now.year, (now.month - 1) ~/ 3 + 1);
    }
    if (value == null) return null;
    final match = RegExp(r'^(\d{4})Q([1-4])$').firstMatch(value);
    if (match == null) return null;
    return (int.parse(match.group(1)!), int.parse(match.group(2)!));
  }

  /// Purpose: Parse an optional anime type query parameter.
  /// Inputs: `value`.
  /// Returns: A record containing the type filter or an error message.
  /// Side effects: None.
  /// Notes: `all` and empty values mean no type filter.
  static ({AnimeType? value, String? error}) _parseAnimeTypeParam(
    String? value,
  ) {
    final trimmed = value?.trim() ?? 'all';
    if (trimmed.isEmpty || trimmed == 'all') {
      return (value: null, error: null);
    }
    for (final type in AnimeType.values) {
      if (type.name == trimmed) return (value: type, error: null);
    }
    return (value: null, error: 'invalid type');
  }

  /// Purpose: Parse a rating field query parameter.
  /// Inputs: `value`.
  /// Returns: A record containing the rating field or an error message.
  /// Side effects: None.
  /// Notes: Empty values default to overall.
  static ({AnimeRatingField? value, String? error}) _parseRatingFieldParam(
    String? value,
  ) {
    final trimmed = value?.trim() ?? 'overall';
    final normalized = trimmed.isEmpty ? 'overall' : trimmed;
    for (final field in AnimeRatingField.values) {
      if (field.name == normalized) return (value: field, error: null);
    }
    return (value: null, error: 'invalid field');
  }

  /// Purpose: Return whether an anime matches parsed ranking filters.
  /// Inputs: `anime`, `query`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static bool _matchesRankingQuery(Anime anime, _RankingQuery query) {
    if (query.type != null && anime.effectiveType != query.type) return false;

    switch (query.time) {
      case _ApiRankingTime.all:
        return true;
      case _ApiRankingTime.quarter:
        return anime.airsInQuarter(query.year!, query.quarter!);
      case _ApiRankingTime.year:
        for (var quarter = 1; quarter <= 4; quarter++) {
          if (anime.airsInQuarter(query.year!, quarter)) return true;
        }
        return false;
      case _ApiRankingTime.range:
        var startIndex = _quarterIndex(query.startYear!, query.startQuarter!);
        var endIndex = _quarterIndex(query.endYear!, query.endQuarter!);
        if (endIndex < startIndex) {
          final temp = startIndex;
          startIndex = endIndex;
          endIndex = temp;
        }
        for (var index = startIndex; index <= endIndex; index++) {
          final (year, quarter) = _quarterFromIndex(index);
          if (anime.airsInQuarter(year, quarter)) return true;
        }
        return false;
    }
  }

  /// Purpose: Convert parsed ranking filters into response JSON.
  /// Inputs: `query`.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static Map<String, dynamic> _rankingFiltersToJson(_RankingQuery query) {
    return {
      'time': query.time.name,
      if (query.year != null && query.quarter != null)
        'season': _quarterId(query.year!, query.quarter!),
      if (query.time == _ApiRankingTime.year) 'year': query.year,
      if (query.startYear != null && query.startQuarter != null)
        'start': _quarterId(query.startYear!, query.startQuarter!),
      if (query.endYear != null && query.endQuarter != null)
        'end': _quarterId(query.endYear!, query.endQuarter!),
      'type': query.type?.name ?? 'all',
    };
  }

  /// Purpose: Convert a year and quarter into a sortable index.
  /// Inputs: `year`, `quarter`.
  /// Returns: `int`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static int _quarterIndex(int year, int quarter) => year * 4 + quarter;

  /// Purpose: Convert a sortable quarter index back into year and quarter.
  /// Inputs: `index`.
  /// Returns: `(int, int)`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static (int, int) _quarterFromIndex(int index) {
    final year = (index - 1) ~/ 4;
    final quarter = ((index - 1) % 4) + 1;
    return (year, quarter);
  }

  /// Purpose: Format a year and quarter as an API quarter identifier.
  /// Inputs: `year`, `quarter`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static String _quarterId(int year, int quarter) => '${year}Q$quarter';

  /// Purpose: Serialize an anime for local API responses.
  /// Inputs: `a`.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Existing keys are preserved and newer keys are additive.
  static Map<String, dynamic> _animeToJson(Anime a) {
    final nxt = a.nextUnwatchedEpisode;
    return {
      'id': a.id,
      'title': a.displayTitle,
      'titleJa': a.titleJa,
      'season': a.season,
      'startEpisode': a.startEpisode,
      'endEpisode': a.endEpisode,
      'totalEpisodes': a.totalEpisodes,
      'firstAirDate': a.firstAirDate?.toIso8601String(),
      'airDayOfWeek': a.airDayOfWeek,
      'airTime': a.airTime,
      'infoUrl': a.infoUrl,
      'watchUrl': a.watchUrl,
      'coverImage': a.coverImage,
      'notes': a.notes,
      'isCompleted': a.isCompleted,
      'status': a.viewingStatus.name,
      'nextUnwatchedEpisode': nxt,
      'nextEpisodeAirDate': nxt != null
          ? _jstToUtcString(a.getEpisodeAirDate(nxt))
          : null,
      'type': a.effectiveType.name,
      'manualType': a.manualType?.name,
      'watchedEpisodes': _episodeStatusCount(a, EpisodeStatus.watched),
      'skippedEpisodes': _episodeStatusCount(a, EpisodeStatus.skippedThisWeek),
      'airedEpisodes': _airedEpisodeCount(a),
      'airedUnwatchedEpisodes': _airedUnwatchedEpisodeCount(a),
      'rating': _ratingToJson(a.rating),
      'createdAt': a.createdAt.toIso8601String(),
      'modifiedAt': a.modifiedAt.toIso8601String(),
    };
  }

  /// Purpose: Count episodes with a specific status.
  /// Inputs: `anime`, `status`.
  /// Returns: `int`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static int _episodeStatusCount(Anime anime, EpisodeStatus status) {
    return anime.episodeStatuses.values
        .where((value) => value == status)
        .length;
  }

  /// Purpose: Return the last episode number worth scanning for progress data.
  /// Inputs: `anime`.
  /// Returns: `int`.
  /// Side effects: None.
  /// Notes: Unknown-end anime scan through known statuses and the next unwatched episode only.
  static int _episodeScanEnd(Anime anime) {
    if (anime.endEpisode != null) return anime.endEpisode!;
    var last = anime.startEpisode;
    for (final episode in anime.episodeStatuses.keys) {
      if (episode > last) last = episode;
    }
    final next = anime.nextUnwatchedEpisode;
    if (next != null && next > last) last = next;
    return max(last, anime.startEpisode);
  }

  /// Purpose: Count aired episodes for API progress summaries.
  /// Inputs: `anime`.
  /// Returns: `int?`.
  /// Side effects: None.
  /// Notes: Returns null when schedule data is incomplete.
  static int? _airedEpisodeCount(Anime anime) {
    final now = JstTime.now();
    var count = 0;
    final end = _episodeScanEnd(anime);
    for (var episode = anime.startEpisode; episode <= end; episode++) {
      final airDate = anime.getEpisodeAirDate(episode);
      if (airDate == null) return null;
      if (airDate.isAfter(now)) break;
      count++;
    }
    return count;
  }

  /// Purpose: Count aired episodes that are still unwatched.
  /// Inputs: `anime`.
  /// Returns: `int?`.
  /// Side effects: None.
  /// Notes: Returns null when schedule data is incomplete.
  static int? _airedUnwatchedEpisodeCount(Anime anime) {
    final now = JstTime.now();
    var count = 0;
    final end = _episodeScanEnd(anime);
    for (var episode = anime.startEpisode; episode <= end; episode++) {
      final airDate = anime.getEpisodeAirDate(episode);
      if (airDate == null) return null;
      if (airDate.isAfter(now)) break;
      final status = anime.episodeStatuses[episode] ?? EpisodeStatus.unwatched;
      if (status == EpisodeStatus.unwatched) count++;
    }
    return count;
  }

  /// Purpose: Serialize a rating for local API responses.
  /// Inputs: `rating`.
  /// Returns: `Map<String, dynamic>?`.
  /// Side effects: None.
  /// Notes: Unknown future rating fields are intentionally not exposed through the API.
  static Map<String, dynamic>? _ratingToJson(AnimeRating? rating) {
    if (rating == null || !rating.hasAnyScore) return null;
    return {
      'overall': rating.overall,
      'effectiveOverall': rating.effectiveOverall,
      'hasManualOverall': rating.hasManualOverall,
      'visual': rating.visual,
      'story': rating.story,
      'character': rating.character,
      'music': rating.music,
      'enjoyment': rating.enjoyment,
    };
  }

  /// Purpose: Compute anime counts by derived viewing status.
  /// Inputs: `animes`.
  /// Returns: `Map<String, int>`.
  /// Side effects: None.
  /// Notes: Keeps legacy `inProgress` and `abandoned` aliases for existing API consumers.
  static Map<String, int> _computeCounts(List<Anime> animes) {
    var completed = 0;
    var watching = 0;
    var dropped = 0;
    var notStarted = 0;
    for (final a in animes) {
      switch (a.viewingStatus) {
        case AnimeViewingStatus.completed:
          completed++;
        case AnimeViewingStatus.watching:
          watching++;
        case AnimeViewingStatus.dropped:
          dropped++;
        case AnimeViewingStatus.notStarted:
          notStarted++;
      }
    }
    return {
      'completed': completed,
      'watching': watching,
      'inProgress': watching,
      'dropped': dropped,
      'abandoned': dropped,
      'notStarted': notStarted,
    };
  }

  /// Purpose: Provide the internal json helper for this file.
  /// Inputs: `data`.
  /// Returns: `Response`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static Response _json(Object data) => Response.ok(
    jsonEncode(data),
    headers: {'Content-Type': 'application/json'},
  );

  /// Purpose: Convert a JST-naive `DateTime` into the UTC string format used by the API.
  /// Inputs: `jst`.
  /// Returns: `String?`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static String? _jstToUtcString(DateTime? jst) {
    if (jst == null) return null;
    final utc = jst.subtract(const Duration(hours: 9));
    return DateTime.utc(
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute,
      utc.second,
    ).toIso8601String();
  }

  /// Purpose: Provide the internal error helper for this file.
  /// Inputs: `status`, `message`.
  /// Returns: `Response`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static Response _error(int status, String message) => Response(
    status,
    body: jsonEncode({'error': message}),
    headers: {'Content-Type': 'application/json'},
  );

  /// Purpose: Provide the internal parse body helper for this file.
  /// Inputs: `request`.
  /// Returns: `Future<Map<String, dynamic>?>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static Future<Map<String, dynamic>?> _parseBody(Request request) async {
    try {
      final raw = await request.readAsString();
      if (raw.trim().isEmpty) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── Middleware ──

  /// Purpose: Provide the internal cors middleware helper for this file.
  /// Inputs: None.
  /// Returns: `Middleware`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static Middleware _corsMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }
        final response = await innerHandler(request);
        return response.change(headers: _corsHeaders);
      };
    };
  }

  static const _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };

  /// Purpose: Provide the internal auth middleware helper for this file.
  /// Inputs: None.
  /// Returns: `Middleware`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. When credentials are
  /// configured, Basic Auth is required for every request including loopback,
  /// because permissive CORS would otherwise let any local web page read the
  /// API. Without credentials only loopback requests are allowed.
  static Middleware _authMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        final remoteAddr =
            (request.context['shelf.io.connection_info'] as HttpConnectionInfo?)
                ?.remoteAddress;
        final isLoopback = remoteAddr == null || remoteAddr.isLoopback;

        final hasCredentials =
            _username != null &&
            _username!.isNotEmpty &&
            _password != null &&
            _password!.isNotEmpty;
        if (!isLoopback && !hasCredentials) {
          return _error(
            403,
            'authentication required for non-localhost access',
          );
        }
        if (hasCredentials) {
          final authHeader = request.headers['authorization'];
          if (authHeader == null || !_validateBasicAuth(authHeader)) {
            return Response(
              401,
              body: jsonEncode({'error': 'unauthorized'}),
              headers: {
                'Content-Type': 'application/json',
                'WWW-Authenticate': 'Basic realm="MyAnime API"',
              },
            );
          }
        }
        return innerHandler(request);
      };
    };
  }

  /// Purpose: Provide the internal validate basic auth helper for this file.
  /// Inputs: `header`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static bool _validateBasicAuth(String header) {
    if (!header.startsWith('Basic ')) return false;
    try {
      final decoded = utf8.decode(base64Decode(header.substring(6)));
      final parts = decoded.split(':');
      if (parts.length < 2) return false;
      return parts[0] == _username && parts.sublist(1).join(':') == _password;
    } catch (_) {
      return false;
    }
  }

  /// Purpose: Provide the internal error middleware helper for this file.
  /// Inputs: None.
  /// Returns: `Middleware`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static Middleware _errorMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        try {
          return await innerHandler(request);
        } catch (e) {
          return _error(500, 'internal error: $e');
        }
      };
    };
  }
}
