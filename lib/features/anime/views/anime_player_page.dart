import 'dart:async';
import 'dart:io';
import 'dart:ffi' show Abi;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'anime_native_player.dart';
import 'anime_player_controls.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../app/flavor.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/playback_time.dart';
import '../models/anime_episode.dart';
import '../models/playback_progress.dart';
import '../services/anime_media_service.dart';
import '../services/playback_progress_service.dart';

/// One selectable episode in the player's playlist (1.6.5).
class AnimePlaylistEntry {
  /// The episode page.
  final AnimeEpisodePage page;

  /// Local episode number; null for extras.
  final int? episode;

  /// Purpose: Pair a page with its local episode number.
  /// Inputs: `page`, optional `episode`.
  /// Returns: A new entry.
  /// Side effects: None.
  /// Notes: The number is what playback progress and the watched mark key on.
  const AnimePlaylistEntry(this.page, {this.episode});
}

class AnimePlayerPage extends StatefulWidget {
  final AnimeEpisodePage page;
  final List<AnimePlaylistEntry> playlist;
  final String? animeId;
  final int? episode;
  final Future<AnimeMediaSource?> Function(String)? resolveMedia;
  final AnimeNativePlayer Function()? playerFactory;
  final Future<bool> Function()? websiteAvailable;

  /// Purpose: Open one episode with native-first playback and website fallback.
  /// Inputs: Initial page and its local episode number, the record id,
  /// and manually selectable episodes.
  /// Returns: Playback route.
  /// Side effects: None until mounted.
  /// Notes: Since 1.6.5 native playback records a synced resume point and
  /// marks a numbered episode watched past 95%; without `animeId` nothing is
  /// recorded. The website player records nothing.
  const AnimePlayerPage({
    super.key,
    required this.page,
    this.playlist = const [],
    this.animeId,
    this.episode,
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
  int? _episode;
  AnimeNativePlayer? _player;

  StreamSubscription<String>? _errors;
  StreamSubscription<Duration>? _position;
  StreamSubscription<Duration>? _duration;
  StreamSubscription<bool>? _playing;
  Timer? _startup;
  int _generation = 0;
  bool _web = false;
  bool _webReady = false;
  bool _failed = false;

  // Speed chosen from the menu; carried to the next episode of this session.
  double _preferredRate = 1.0;

  // Progress tracking for the episode the current decoder is playing.
  AnimeEpisodePage? _trackPage;
  int? _trackEpisode;
  Duration _lastPosition = Duration.zero;
  Duration _lastDuration = Duration.zero;
  Duration? _lastSavedPosition;
  String? _completedKey;
  PlaybackProgressEntry? _resume;

  /// Purpose: Begin the explicitly requested episode.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Starts media resolution.
  /// Notes: Full-build gate is also enforced here for direct route callers.
  @override
  void initState() {
    super.initState();
    _page = widget.page;
    _episode = widget.episode;
    if (AppFlavor.isFull) {
      _start();
    } else {
      _failed = true;
    }
  }

  /// Purpose: Return the progress key of the tracked episode.
  /// Inputs: None.
  /// Returns: `String?` — null when nothing is tracked.
  /// Side effects: None.
  /// Notes: Internal helper.
  String? get _trackKey {
    final id = widget.animeId;
    final page = _trackPage;
    if (id == null || page == null) return null;
    return PlaybackProgressService.keyFor(id, _trackEpisode, page.url);
  }

  /// Purpose: Record the tracked episode's last known position.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May write `playback_progress.json` and, past 95%,
  /// `anime_data.json`.
  /// Notes: Uses cached values only, so it is safe while the decoder is
  /// being released. A finished episode is completed once per session.
  void _flush() {
    final id = widget.animeId;
    final page = _trackPage;
    final key = _trackKey;
    if (id == null || page == null || key == null || key == _completedKey) {
      return;
    }
    final position = _lastPosition;
    final duration = _lastDuration;
    final rule = classifyPlayback(position, duration);
    if (rule == PlaybackProgressRule.ignore) return;
    if (rule == PlaybackProgressRule.complete) _completedKey = key;
    _lastSavedPosition = position;
    unawaited(
      PlaybackProgressService.report(
        animeId: id,
        episode: _trackEpisode,
        pageUrl: page.url,
        position: position,
        duration: duration,
      ).catchError((Object _) => rule),
    );
  }

  /// Purpose: Save progress, then release the native player before replacing it.
  /// Inputs: None.
  /// Returns: Completion.
  /// Side effects: Cancels timers/listeners and stops audio/video.
  /// Notes: Clears references before awaiting disposal; cleanup errors must not block fallback.
  Future<void> _release() async {
    _flush();
    _trackPage = null;
    _startup?.cancel();
    _startup = null;
    final subscriptions = <StreamSubscription<Object?>?>[
      _errors,
      _position,
      _duration,
      _playing,
    ];
    _errors = null;
    _position = null;
    _duration = null;
    _playing = null;
    final player = _player;
    _player = null;

    // Stop the decoder immediately; listener cancellation must not delay audio shutdown.
    try {
      await Future.wait<void>([
        for (final s in subscriptions)
          if (s != null) s.cancel(),
        if (player != null) player.dispose(),
      ]);
    } catch (_) {
      // Cleanup has already been requested for every owned resource.
    }
  }

  /// Purpose: Try bounded native playback for the current episode.
  /// Inputs: None.
  /// Returns: Completion.
  /// Side effects: Network, decoder initialization, playback and progress reads.
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
      final id = widget.animeId;
      _resume = id == null
          ? null
          : await PlaybackProgressService.resumePoint(
              PlaybackProgressService.keyFor(id, _episode, _page.url),
            ).catchError((Object _) => null);
      if (!mounted || generation != _generation) return;
      final player = (widget.playerFactory ?? MediaKitAnimePlayer.new)();
      _player = player;
      _trackPage = _page;
      _trackEpisode = _episode;
      _lastPosition = Duration.zero;
      _lastDuration = Duration.zero;
      _lastSavedPosition = null;
      _errors = player.errors.listen((_) {
        if (mounted && generation == _generation) _fallback();
      });
      _position = player.positions.listen((position) {
        if (position > Duration.zero) _startup?.cancel();
        _lastPosition = position;
        final saved = _lastSavedPosition;
        if (saved == null ||
            (position - saved).abs() >= const Duration(seconds: 5)) {
          _flush();
        }
      });
      _duration = player.durations.listen((duration) {
        _lastDuration = duration;
        if (duration > Duration.zero) _applyResume(player, duration);
      });
      _playing = player.playing.listen((playing) {
        if (!playing) _flush();
      });
      _startup = Timer(const Duration(seconds: 20), () {
        if (mounted && generation == _generation) _fallback();
      });
      setState(() {});
      await player.open(source);
      if (_preferredRate != 1.0 && generation == _generation) {
        await player.setRate(_preferredRate);
      }
    } catch (_) {
      if (mounted && generation == _generation) await _fallback();
    }
  }

  /// Purpose: Seek once to the stored resume point when the duration is known.
  /// Inputs: `player`, `duration`.
  /// Returns: None.
  /// Side effects: Seeks; shows a snackbar offering to start over, which
  /// clears itself after five seconds.
  /// Notes: A resume point that the current media would already count as
  /// finished, or that is past its end, is not applied.
  void _applyResume(AnimeNativePlayer player, Duration duration) {
    final resume = _resume;
    if (resume == null || !mounted || player != _player) return;
    _resume = null;
    if (classifyPlayback(resume.position, duration) !=
        PlaybackProgressRule.save) {
      return;
    }
    unawaited(player.seek(resume.position));
    _lastPosition = resume.position;
    _lastSavedPosition = resume.position;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          // A snackbar with an action persists by default; this one must
          // clear itself so it does not cover the seek bar.
          persist: false,
          duration: const Duration(seconds: 5),
          content: Text(
            l10n.episodeResumedFrom(formatPlaybackClock(resume.position)),
          ),
          action: SnackBarAction(
            label: l10n.episodeStartOver,
            onPressed: () {
              if (_player == player) unawaited(player.seek(Duration.zero));
            },
          ),
        ),
      );
  }

  /// Purpose: Move once from native playback to the same episode's website.
  /// Inputs: None.
  /// Returns: Completion.
  /// Side effects: Saves progress, disposes native playback and checks the
  /// Windows WebView runtime.
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
  /// Side effects: Saves progress, invalidates pending requests and disposes
  /// native resources.
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
  /// Notes: Switching episodes saves the outgoing one's position first.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final generation = _generation;
    final player = _player;
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
                for (final e in widget.playlist)
                  PopupMenuItem(value: e.page.url, child: Text(e.page.title)),
              ],
              onSelected: (url) {
                final entry = widget.playlist.firstWhere(
                  (e) => e.page.url == url,
                );
                setState(() {
                  _page = entry.page;
                  _episode = entry.episode;
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
                : player != null && !_web
                ? ColoredBox(
                    color: Colors.black,
                    child: player.buildVideo(
                      (host) => AnimePlayerControls(
                        player: player,
                        fullscreen: host,
                        title: _page.title,
                        onRateSelected: (rate) => _preferredRate = rate,
                      ),
                    ),
                  )
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
