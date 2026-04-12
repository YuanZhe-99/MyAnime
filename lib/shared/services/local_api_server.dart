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

class LocalApiServer {
  static HttpServer? _server;
  static int _port = 7788;
  static String _listenAddress = 'localhost';
  static bool _enabled = false;
  static String? _username;
  static String? _password;
  static String? _lastError;

  static int get port => _port;
  static String get listenAddress => _listenAddress;
  static bool get enabled => _enabled;
  static bool get isRunning => _server != null;
  static String? get lastError => _lastError;

  static Future<void> loadConfig() async {
    final config = await AnimeStorage.readConfig();
    _port = config['apiPort'] as int? ?? 7788;
    _listenAddress = config['apiListenAddress'] as String? ?? 'localhost';
    _enabled = config['apiEnabled'] as bool? ?? false;
    _username = config['apiUsername'] as String?;
    _password = config['apiPassword'] as String?;
  }

  static Future<void> start() async {
    await loadConfig();
    await stop();
    _lastError = null;
    if (!_enabled) return;

    // Warn about missing credentials on non-loopback
    final isNonLoopback = _listenAddress == '0.0.0.0' ||
        (_listenAddress != 'localhost' && _listenAddress != '127.0.0.1');
    final hasCredentials = _username != null &&
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

    final handler = const Pipeline()
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_authMiddleware())
        .addMiddleware(_errorMiddleware())
        .addHandler(router.call);

    try {
      final InternetAddress bindAddress;
      if (_listenAddress == '0.0.0.0') {
        bindAddress = InternetAddress.anyIPv4;
      } else if (_listenAddress == 'localhost' || _listenAddress == '127.0.0.1') {
        bindAddress = InternetAddress.loopbackIPv4;
      } else {
        bindAddress = InternetAddress(_listenAddress, type: InternetAddressType.any);
      }
      _server = await shelf_io.serve(
        handler,
        bindAddress,
        _port,
      );
      // ignore: avoid_print
      print('[LocalApiServer] listening on port $_port');
    } catch (e) {
      _lastError = e.toString();
      // ignore: avoid_print
      print('[LocalApiServer] failed to start: $e');
    }
  }

  static Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  static Future<void> restart() async {
    await loadConfig();
    await start();
  }

  // ── Route handlers ──

  static Future<Response> _handlePing(Request request) async {
    return _json({'status': 'ok'});
  }

  static Future<Response> _handleSearch(Request request) async {
    final body = await _parseBody(request);
    if (body == null) return _error(400, 'invalid JSON body');
    final query = body['query'] as String?;
    if (query == null || query.trim().isEmpty) {
      return _error(400, 'query is required');
    }
    final results = await AnimeSearchService.searchAll(query.trim());
    final list = results.take(5).map((r) => {
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
    }).toList();
    return _json(list);
  }

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

  static Future<Response> _handleUnwatched(Request request) async {
    final data = await AnimeStorage.load();
    final now = JstTime.now();
    final results = <Map<String, dynamic>>[];
    for (final anime in data.animes) {
      final lastEp = anime.endEpisode ?? anime.startEpisode;
      for (var ep = anime.startEpisode; ep <= lastEp; ep++) {
        final status =
            anime.episodeStatuses[ep] ?? EpisodeStatus.unwatched;
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

  static Future<Response> _handleHistory(Request request) async {
    final data = await AnimeStorage.load();
    final allFiltered = _filterBySeason(data.animes, request, sample: false);
    final sampled = _filterBySeason(data.animes, request);
    final list = sampled.map((a) {
      final json = _animeToJson(a);
      json['watchedEpisodes'] = a.episodeStatuses.values
          .where((s) => s == EpisodeStatus.watched)
          .length;
      return json;
    }).toList();
    return _json({
      'total': allFiltered.length,
      'counts': _computeCounts(allFiltered),
      'data': list,
    });
  }

  // ── Helpers ──

  /// Parse `?season=` query param and filter anime list.
  ///
  /// Values:
  /// - absent or `current` → current JST quarter
  /// - `YYYYQn` (e.g. `2026Q2`) → specific quarter
  /// - `unassigned` → anime without firstAirDate
  /// - `all` → all anime (random 40)
  static List<Anime> _filterBySeason(List<Anime> animes, Request request,
      {bool sample = true}) {
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
      'isCompleted': a.isCompleted,
      'nextUnwatchedEpisode': nxt,
      'nextEpisodeAirDate': nxt != null
          ? _jstToUtcString(a.getEpisodeAirDate(nxt))
          : null,
      'type': a.effectiveType.name,
      'createdAt': a.createdAt.toIso8601String(),
    };
  }

  static Map<String, int> _computeCounts(List<Anime> animes) {
    int completed = 0, inProgress = 0, abandoned = 0, notStarted = 0;
    for (final a in animes) {
      if (a.isCompleted) {
        completed++;
      } else if (a.nextUnwatchedEpisode == null) {
        abandoned++;
      } else {
        final watched = a.episodeStatuses.values
            .where((s) => s == EpisodeStatus.watched)
            .length;
        if (watched > 0) {
          inProgress++;
        } else {
          notStarted++;
        }
      }
    }
    return {
      'completed': completed,
      'inProgress': inProgress,
      'abandoned': abandoned,
      'notStarted': notStarted,
    };
  }

  static Response _json(Object data) => Response.ok(
        jsonEncode(data),
        headers: {'Content-Type': 'application/json'},
      );

  /// Convert a naive JST DateTime to a UTC ISO-8601 string.
  static String? _jstToUtcString(DateTime? jst) {
    if (jst == null) return null;
    final utc = jst.subtract(const Duration(hours: 9));
    return DateTime.utc(utc.year, utc.month, utc.day, utc.hour, utc.minute,
            utc.second)
        .toIso8601String();
  }

  static Response _error(int status, String message) => Response(
        status,
        body: jsonEncode({'error': message}),
        headers: {'Content-Type': 'application/json'},
      );

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

  static Middleware _authMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        // Skip auth for loopback addresses
        final remoteAddr =
            (request.context['shelf.io.connection_info'] as HttpConnectionInfo?)
                ?.remoteAddress;
        final isLoopback = remoteAddr == null || remoteAddr.isLoopback;

        // Auth required if credentials are configured and request is not from loopback
        final hasCredentials =
            _username != null && _username!.isNotEmpty &&
            _password != null && _password!.isNotEmpty;
        if (!isLoopback && !hasCredentials) {
          return _error(403, 'authentication required for non-localhost access');
        }
        if (hasCredentials && !isLoopback) {
          final authHeader = request.headers['authorization'];
          if (authHeader == null || !_validateBasicAuth(authHeader)) {
            return Response(401,
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
