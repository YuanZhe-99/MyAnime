import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../../anime/models/anime.dart';
import '../../anime/services/anime_search_service.dart';
import '../models/recommendation_data.dart';
import 'recommendation_store.dart';

/// Fetches a short synopsis and a small cover thumbnail for a missing-sequel
/// card (1.6.3), and stores them in the synced `recommendations.json` under
/// the card's dedupe key.
///
/// This is a network feature: every caller must gate on `AppFlavor.isFull`,
/// like every other caller of [AnimeSearchService]. Store builds still show
/// what a full build fetched, because the result syncs.
class SequelInfoService {
  /// Purpose: Prevent direct instantiation and expose only static members.
  /// Inputs: None.
  /// Returns: A new `SequelInfoService._` instance.
  /// Side effects: None.
  /// Notes: None.
  const SequelInfoService._();

  /// Thumbnail width in pixels: twice the 56 dp card cover, so it stays sharp
  /// on a 2× screen.
  static const thumbWidth = 112;

  /// JPEG quality of the thumbnail.
  static const thumbQuality = 70;

  /// Largest thumbnail kept, in encoded bytes; anything bigger is dropped so
  /// one odd image cannot bloat the synced file.
  static const thumbMaxBytes = 24 * 1024;

  /// Longest synopsis kept, in characters.
  static const synopsisMaxLength = 600;

  /// Fetches the database page for a URL. Replaceable in tests.
  @visibleForTesting
  static Future<({String? summary, String? coverUrl})?> Function(String url)
  fetchPage = _fetchPage;

  /// Downloads an image. Replaceable in tests.
  @visibleForTesting
  static Future<Uint8List?> Function(String url) download = _download;

  static final _inFlight = <String, Future<SequelInfo?>>{};
  static final _attempted = <String>{};

  /// Purpose: Forget which keys were tried this session.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Clears the in-memory attempt set.
  /// Notes: For tests.
  @visibleForTesting
  static void resetSession() {
    _inFlight.clear();
    _attempted.clear();
  }

  /// Purpose: Fetch and store info for one missing sequel, once.
  /// Inputs: `key` — the dedupe key (`sequelTrashKey`); `sequel`;
  /// `existing` — what the store already holds.
  /// Returns: `Future<SequelInfo?>` — the stored info, or null when nothing
  /// was fetched.
  /// Side effects: At most one page request and one image request; one write
  /// of `recommendations.json`.
  /// Notes: Does nothing when info is already stored, when the sequel has no
  /// URL, or when this key already failed in this session (a failing source
  /// is not hit on every rebuild). Concurrent calls for one key share
  /// the request. A result with nothing in it is still stored, so it is not
  /// fetched again on the next launch either.
  static Future<SequelInfo?> ensure(
    String key,
    AnimeExternalRelation sequel, {
    SequelInfo? existing,
  }) {
    if (existing != null) return Future.value(existing);
    final url = sequel.targetUrl;
    if (url == null || url.isEmpty || key.isEmpty) return Future.value();
    final running = _inFlight[key];
    if (running != null) return running;
    if (!_attempted.add(key)) return Future.value();
    final future = _run(key, url);
    _inFlight[key] = future;
    return future.whenComplete(() => _inFlight.remove(key));
  }

  /// Purpose: Fetch, build the thumbnail, and store.
  /// Inputs: `key`, `url`.
  /// Returns: `Future<SequelInfo?>`.
  /// Side effects: Network; writes the store.
  /// Notes: Internal helper used within this file only. Any failure reads as
  /// null and stores nothing, so a network error is retried next session. A
  /// stored result clears the key's "tried" mark.
  static Future<SequelInfo?> _run(String key, String url) async {
    try {
      final page = await fetchPage(url);
      if (page == null) return null;
      String? thumb;
      final coverUrl = page.coverUrl;
      if (coverUrl != null && coverUrl.isNotEmpty) {
        final bytes = await download(coverUrl);
        if (bytes != null) thumb = await makeThumbnail(bytes);
      }
      final info = SequelInfo(
        synopsis: normalizeSynopsis(page.summary),
        coverUrl: coverUrl,
        coverThumb: thumb,
        fetchedAt: DateTime.now().toUtc(),
      );
      final data = await RecommendationStore.putSequelInfo(key, info);
      final stored = data.sequelInfo[key];
      // Stored: later calls pass it as `existing`. Forgetting the attempt
      // lets a card whose info the trash deleted (then Undo restored) fetch
      // again in this session.
      if (stored != null) _attempted.remove(key);
      return stored;
    } catch (_) {
      return null;
    }
  }

  /// Purpose: Read the synopsis and cover URL from a database page.
  /// Inputs: `url`.
  /// Returns: The two fields, or null when the host has no by-id endpoint or
  /// the fetch failed.
  /// Side effects: One request through `AnimeSearchService.fetchByUrl`.
  /// Notes: Internal helper used within this file only.
  static Future<({String? summary, String? coverUrl})?> _fetchPage(
    String url,
  ) async {
    final r = await AnimeSearchService.fetchByUrl(url);
    if (r == null) return null;
    return (summary: r.summary, coverUrl: r.coverImageUrl);
  }

  /// Purpose: Download an image.
  /// Inputs: `url`.
  /// Returns: `Future<Uint8List?>` — null on any failure.
  /// Side effects: One HTTP GET.
  /// Notes: Internal helper used within this file only. Sends the app's
  /// user agent, as the search requests do.
  static Future<Uint8List?> _download(String url) async {
    try {
      final resp = await http
          .get(
            Uri.parse(url),
            headers: {'User-Agent': AnimeSearchService.userAgent},
          )
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return null;
      return resp.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  /// Purpose: Shrink a cover into a small base64 JPEG.
  /// Inputs: `bytes` — the downloaded image, any format `package:image`
  /// decodes.
  /// Returns: `Future<String?>` — base64 text, or null when the image cannot
  /// be decoded or the result is larger than [thumbMaxBytes].
  /// Side effects: Runs the work on a background isolate.
  /// Notes: The aspect ratio is kept; images narrower than [thumbWidth] are
  /// not enlarged.
  static Future<String?> makeThumbnail(Uint8List bytes) =>
      compute(_thumbnail, bytes);

  /// Purpose: The isolate body of [makeThumbnail].
  /// Inputs: `bytes`.
  /// Returns: `String?`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static String? _thumbnail(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      final small = decoded.width > thumbWidth
          ? img.copyResize(
              decoded,
              width: thumbWidth,
              interpolation: img.Interpolation.average,
            )
          : decoded;
      final jpg = img.encodeJpg(small, quality: thumbQuality);
      if (jpg.length > thumbMaxBytes) return null;
      return base64Encode(jpg);
    } catch (_) {
      return null;
    }
  }

  /// Purpose: Clean a database synopsis for display and storage.
  /// Inputs: `raw`.
  /// Returns: `String?` — trimmed, whitespace collapsed, MyAnimeList's
  /// "[Written by MAL Rewrite]" and "(Source: …)" credits removed, capped at
  /// [synopsisMaxLength] with an ellipsis; null when empty.
  /// Side effects: None.
  /// Notes: Paragraph breaks become single spaces: the card shows three
  /// lines at most.
  static String? normalizeSynopsis(String? raw) {
    if (raw == null) return null;
    var s = raw
        .replaceAll(RegExp(r'\[Written by [^\]]*\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(Source:[^)]*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (s.isEmpty) return null;
    if (s.length > synopsisMaxLength) {
      s = '${s.substring(0, synopsisMaxLength).trimRight()}…';
    }
    return s;
  }
}
