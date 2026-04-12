import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../../features/anime/models/anime.dart';
import '../../features/anime/services/anime_search_service.dart';
import '../../features/anime/services/anime_storage.dart';

class LocalApiServer {
  static HttpServer? _server;
  static int _port = 7788;
  static String _listenAddress = 'localhost';
  static bool _enabled = false;
  static String? _username;
  static String? _password;

  static int get port => _port;
  static String get listenAddress => _listenAddress;
  static bool get enabled => _enabled;
  static bool get isRunning => _server != null;

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
    if (!_enabled) return;

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
      final bindAddress = _listenAddress == '0.0.0.0'
          ? InternetAddress.anyIPv4
          : InternetAddress(_listenAddress, type: InternetAddressType.any);
      _server = await shelf_io.serve(
        handler,
        bindAddress,
        _port,
      );
      // ignore: avoid_print
      print('[LocalApiServer] listening on port $_port');
    } catch (e) {
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
    return _json(data.animes.map(_animeToJson).toList());
  }

  static Future<Response> _handleUnwatched(Request request) async {
    final data = await AnimeStorage.load();
    final unwatched = data.animes
        .where((a) => !a.isCompleted && a.nextUnwatchedEpisode != null)
        .map((a) => _animeToJson(a))
        .toList();
    return _json(unwatched);
  }

  static Future<Response> _handleHistory(Request request) async {
    final data = await AnimeStorage.load();
    final list = data.animes.map((a) {
      final json = _animeToJson(a);
      json['watchedEpisodes'] = a.episodeStatuses.values
          .where((s) => s == EpisodeStatus.watched)
          .length;
      return json;
    }).toList();
    return _json(list);
  }

  // ── Helpers ──

  static Map<String, dynamic> _animeToJson(Anime a) => {
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
        'nextUnwatchedEpisode': a.nextUnwatchedEpisode,
        'type': a.effectiveType.name,
        'createdAt': a.createdAt.toIso8601String(),
      };

  static Response _json(Object data) => Response.ok(
        jsonEncode(data),
        headers: {'Content-Type': 'application/json'},
      );

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
