import 'dart:async';
import 'dart:io';
import 'dart:ffi' show Abi;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'anime_native_player.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../app/flavor.dart';
import '../../../l10n/app_localizations.dart';
import '../models/anime_episode.dart';
import '../services/anime_media_service.dart';

class AnimePlayerPage extends StatefulWidget {
  final AnimeEpisodePage page;
  final List<AnimeEpisodePage> playlist;
  final Future<AnimeMediaSource?> Function(String)? resolveMedia;
  final AnimeNativePlayer Function()? playerFactory;
  final Future<bool> Function()? websiteAvailable;

  /// Purpose: Open one episode with native-first playback and website fallback.
  /// Inputs: Initial page and manually selectable episodes.
  /// Returns: Playback route.
  /// Side effects: None until mounted.
  /// Notes: Does not own or modify watching status.
  const AnimePlayerPage({
    super.key,
    required this.page,
    this.playlist = const [],
    this.resolveMedia,
    this.playerFactory,
    this.websiteAvailable,
  });

  /// Purpose: Create playback lifecycle state.
  /// Inputs: None.
  /// Returns: State.
  /// Side effects: None.
  /// Notes: None.
  @override
  State<AnimePlayerPage> createState() => _AnimePlayerPageState();
}

class _AnimePlayerPageState extends State<AnimePlayerPage> {
  late AnimeEpisodePage _page;
  AnimeNativePlayer? _player;

  StreamSubscription<String>? _errors;
  StreamSubscription<Duration>? _position;
  Timer? _startup;
  int _generation = 0;
  bool _web = false;
  bool _webReady = false;
  bool _failed = false;

  /// Purpose: Begin the explicitly requested episode.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Starts media resolution.
  /// Notes: Full-build gate is also enforced here for direct route callers.
  @override
  void initState() {
    super.initState();
    _page = widget.page;
    if (AppFlavor.isFull) {
      _start();
    } else {
      _failed = true;
    }
  }

  /// Purpose: Release the native player before replacing it.
  /// Inputs: None.
  /// Returns: Completion.
  /// Side effects: Cancels timers/listeners and stops audio/video.
  /// Notes: Clears references before awaiting disposal; cleanup errors must not block fallback.
  Future<void> _release() async {
    _startup?.cancel();
    _startup = null;
    final errors = _errors;
    final position = _position;
    _errors = null;
    _position = null;
    final player = _player;
    _player = null;

    // Stop the decoder immediately; listener cancellation must not delay audio shutdown.
    try {
      await Future.wait<void>([
        if (errors != null) errors.cancel(),
        if (position != null) position.cancel(),
        if (player != null) player.dispose(),
      ]);
    } catch (_) {
      // Cleanup has already been requested for every owned resource.
    }
  }

  /// Purpose: Try bounded native playback for the current episode.
  /// Inputs: None.
  /// Returns: Completion.
  /// Side effects: Network, decoder initialization and playback.
  /// Notes: Generation guards discard work belonging to a departed or switched episode.
  Future<void> _start() async {
    final generation = ++_generation;
    await _release();
    if (!mounted || generation != _generation) return;
    setState(() {
      _web = false;
      _webReady = false;
      _failed = false;
    });
    try {
      if (widget.playerFactory == null &&
          Platform.isWindows &&
          Abi.current() == Abi.windowsArm64) {
        await _fallback();
        return;
      }
      final source = await (widget.resolveMedia ?? AnimeMediaService.resolve)(
        _page.url,
      ).timeout(const Duration(seconds: 20));
      if (!mounted || generation != _generation) return;
      if (source == null) {
        await _fallback();
        return;
      }
      final player = (widget.playerFactory ?? MediaKitAnimePlayer.new)();
      _player = player;
      _errors = player.errors.listen((_) {
        if (mounted && generation == _generation) _fallback();
      });
      _position = player.positions.listen((position) {
        if (position > Duration.zero) _startup?.cancel();
      });
      _startup = Timer(const Duration(seconds: 20), () {
        if (mounted && generation == _generation) _fallback();
      });
      setState(() {});
      await player.open(source);
    } catch (_) {
      if (mounted && generation == _generation) await _fallback();
    }
  }

  /// Purpose: Move once from native playback to the same episode's website.
  /// Inputs: None.
  /// Returns: Completion.
  /// Side effects: Disposes native playback and checks the Windows WebView runtime.
  /// Notes: A failed website never triggers another native attempt automatically.
  Future<void> _fallback() async {
    if (_web || !mounted || !AppFlavor.isFull) return;
    final generation = ++_generation;
    setState(() {
      _web = true;
      _failed = false;
    });
    await _release();
    try {
      if (widget.websiteAvailable != null &&
          !await widget.websiteAvailable!()) {
        throw StateError('WebView unavailable');
      }
      if (Platform.isWindows &&
          await WebViewEnvironment.getAvailableVersion() == null) {
        throw StateError('WebView unavailable');
      }
      if (!mounted || generation != _generation) return;
      setState(() => _webReady = true);
      _startup = Timer(const Duration(seconds: 25), () {
        if (mounted && generation == _generation) {
          setState(() => _failed = true);
        }
      });
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    }
  }

  /// Purpose: Stop playback when the route leaves the widget tree.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Invalidates pending requests and disposes native resources.
  /// Notes: Embedded WebView is disposed by its widget lifecycle.
  @override
  void dispose() {
    _generation++;
    unawaited(_release());
    super.dispose();
  }

  /// Purpose: Render native controls or the website plus explicit escape actions.
  /// Inputs: Build context.
  /// Returns: Player screen.
  /// Side effects: User actions switch episodes or open a browser.
  /// Notes: Selecting another episode does not mark the previous one watched.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final generation = _generation;
    return Scaffold(
      appBar: AppBar(
        title: Text(_page.title),
        actions: [
          if (AppFlavor.isFull && !_web)
            IconButton(
              onPressed: _fallback,
              tooltip: l10n.episodeWebPlayer,
              icon: const Icon(Icons.web),
            ),
          IconButton(
            onPressed: () => launchUrl(
              Uri.parse(_page.url),
              mode: LaunchMode.externalApplication,
            ),
            tooltip: l10n.episodeBrowser,
            icon: const Icon(Icons.open_in_browser),
          ),
          if (AppFlavor.isFull && widget.playlist.length > 1)
            PopupMenuButton<String>(
              icon: const Icon(Icons.playlist_play),
              tooltip: l10n.episodeChoose,
              itemBuilder: (_) => [
                for (final p in widget.playlist)
                  PopupMenuItem(value: p.url, child: Text(p.title)),
              ],
              onSelected: (url) {
                setState(() {
                  _page = widget.playlist.firstWhere((p) => p.url == url);
                  _webReady = false;
                });
                _start();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (_web)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(l10n.episodeWebPlayer),
            ),
          if (_failed)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.episodePlaybackFailed),
            ),
          Expanded(
            child: !AppFlavor.isFull
                ? const SizedBox.shrink()
                : _web && _webReady
                ? InAppWebView(
                    key: ValueKey(_page.url),
                    initialUrlRequest: URLRequest(url: WebUri(_page.url)),
                    initialSettings: InAppWebViewSettings(
                      allowsInlineMediaPlayback: true,
                      mediaPlaybackRequiresUserGesture: true,
                      useShouldOverrideUrlLoading: true,
                      supportMultipleWindows: false,
                    ),
                    shouldOverrideUrlLoading: (_, action) async {
                      final uri = action.request.url;
                      return uri != null &&
                              ['https', 'http'].contains(uri.scheme)
                          ? NavigationActionPolicy.ALLOW
                          : NavigationActionPolicy.CANCEL;
                    },
                    onLoadStop: (_, _) {
                      if (!mounted || generation != _generation) return;
                      _startup?.cancel();
                    },
                    onReceivedError: (_, request, _) {
                      if (request.isForMainFrame == true &&
                          mounted &&
                          generation == _generation) {
                        setState(() => _failed = true);
                      }
                    },
                    onReceivedHttpError: (_, request, response) {
                      if (request.isForMainFrame == true &&
                          mounted &&
                          generation == _generation &&
                          (response.statusCode ?? 0) >= 400) {
                        setState(() => _failed = true);
                      }
                    },
                  )
                : _player != null && !_web
                ? _player!.buildVideo()
                : Center(
                    child: _failed
                        ? const Icon(Icons.error_outline)
                        : const CircularProgressIndicator(),
                  ),
          ),
        ],
      ),
    );
  }
}
