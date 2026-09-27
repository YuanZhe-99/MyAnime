import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:media_kit_video/media_kit_video_controls/media_kit_video_controls.dart'
    as mkc;

import '../services/anime_media_service.dart';

/// Fullscreen switch for the video the controls sit on (1.6.5).
///
/// Kept separate from media_kit so the controls overlay can be driven in
/// widget tests without a decoder.
abstract interface class AnimeFullscreenHost {
  /// Purpose: Report whether the video currently fills the screen.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get isFullscreen;

  /// Purpose: Enter or leave fullscreen.
  /// Inputs: None.
  /// Returns: Completion.
  /// Side effects: Pushes or pops the fullscreen route; on phones also hides
  /// the system bars and locks landscape.
  /// Notes: None.
  Future<void> toggle();

  /// Purpose: Leave fullscreen when in it.
  /// Inputs: None.
  /// Returns: Completion.
  /// Side effects: Pops the fullscreen route.
  /// Notes: No-op when not fullscreen.
  Future<void> exit();
}

/// Builds the controls drawn over the video; `host` is null where no
/// fullscreen switch exists.
typedef AnimePlayerControlsBuilder = Widget Function(AnimeFullscreenHost? host);

/// Small platform boundary that also allows deterministic playback lifecycle tests.
abstract interface class AnimeNativePlayer {
  /// Purpose: Expose decoder failures without logging sensitive media addresses.
  /// Inputs: None.
  /// Returns: Error event stream.
  /// Side effects: None.
  /// Notes: Consumers use only the occurrence, never display the raw error.
  Stream<String> get errors;

  /// Purpose: Expose playback progress.
  /// Inputs: None.
  /// Returns: Position event stream.
  /// Side effects: None.
  /// Notes: Drives the startup timeout, the controls and, since 1.6.5, the
  /// synced resume point.
  Stream<Duration> get positions;

  /// Purpose: Expose the media duration once known.
  /// Inputs: None.
  /// Returns: Duration event stream.
  /// Side effects: None.
  /// Notes: Zero until the decoder has read the media header.
  Stream<Duration> get durations;

  /// Purpose: Expose play/pause state changes.
  /// Inputs: None.
  /// Returns: `Stream<bool>` — true while playing.
  /// Side effects: None.
  /// Notes: None.
  Stream<bool> get playing;

  /// Purpose: Expose playback-rate changes.
  /// Inputs: None.
  /// Returns: `Stream<double>`.
  /// Side effects: None.
  /// Notes: None.
  Stream<double> get rates;

  /// Purpose: Return the current position.
  /// Inputs: None.
  /// Returns: `Duration`.
  /// Side effects: None.
  /// Notes: None.
  Duration get position;

  /// Purpose: Return the current duration.
  /// Inputs: None.
  /// Returns: `Duration` — zero while unknown.
  /// Side effects: None.
  /// Notes: None.
  Duration get duration;

  /// Purpose: Return whether playback is running.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get isPlaying;

  /// Purpose: Return the current playback rate.
  /// Inputs: None.
  /// Returns: `double` — 1.0 is normal speed.
  /// Side effects: None.
  /// Notes: None.
  double get rate;

  /// Purpose: Jump to a position.
  /// Inputs: `position` — callers clamp it to the duration.
  /// Returns: Completion.
  /// Side effects: Seeks the decoder.
  /// Notes: None.
  Future<void> seek(Duration position);

  /// Purpose: Start or resume playback.
  /// Inputs: None.
  /// Returns: Completion.
  /// Side effects: Playback.
  /// Notes: None.
  Future<void> play();

  /// Purpose: Pause playback.
  /// Inputs: None.
  /// Returns: Completion.
  /// Side effects: Playback.
  /// Notes: None.
  Future<void> pause();

  /// Purpose: Toggle between playing and paused.
  /// Inputs: None.
  /// Returns: Completion.
  /// Side effects: Playback.
  /// Notes: None.
  Future<void> playOrPause();

  /// Purpose: Change the playback speed.
  /// Inputs: `rate` — 1.0 is normal speed.
  /// Returns: Completion.
  /// Side effects: Playback.
  /// Notes: The app offers 0.25 to 3.0.
  Future<void> setRate(double rate);

  /// Purpose: Render the video with the app's own controls on top.
  /// Inputs: `controls` — builds the overlay for a fullscreen host.
  /// Returns: Video widget.
  /// Side effects: None.
  /// Notes: The same builder is used again inside the fullscreen route.
  Widget buildVideo(AnimePlayerControlsBuilder controls);

  /// Purpose: Begin one temporary media source.
  /// Inputs: Source and headers.
  /// Returns: Completion of opening.
  /// Side effects: Network and playback.
  /// Notes: No playlist auto-advance.
  Future<void> open(AnimeMediaSource source);

  /// Purpose: Stop playback and release decoder resources.
  /// Inputs: None.
  /// Returns: Disposal completion.
  /// Side effects: Releases native resources.
  /// Notes: Called once by the owning route.
  Future<void> dispose();
}

/// Fullscreen host backed by media_kit's context-based fullscreen helpers.
class _ContextFullscreenHost implements AnimeFullscreenHost {
  final BuildContext _context;

  /// Purpose: Wrap the build context the controls are drawn in.
  /// Inputs: `context` — below media_kit's video state.
  /// Returns: A new host.
  /// Side effects: None.
  /// Notes: The context differs inside the fullscreen route, which is how
  /// media_kit tells the two apart.
  _ContextFullscreenHost(this._context);

  /// Purpose: Report fullscreen state.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  @override
  bool get isFullscreen => mkc.isFullscreen(_context);

  /// Purpose: Toggle fullscreen.
  /// Inputs: None.
  /// Returns: Completion.
  /// Side effects: See [AnimeFullscreenHost.toggle].
  /// Notes: None.
  @override
  Future<void> toggle() => mkc.toggleFullscreen(_context);

  /// Purpose: Leave fullscreen.
  /// Inputs: None.
  /// Returns: Completion.
  /// Side effects: See [AnimeFullscreenHost.exit].
  /// Notes: None.
  @override
  Future<void> exit() => mkc.exitFullscreen(_context);
}

class MediaKitAnimePlayer implements AnimeNativePlayer {
  late final Player _player;
  late final VideoController _controller;

  /// Purpose: Initialize the supported native player on demand.
  /// Inputs: None.
  /// Returns: Platform adapter.
  /// Side effects: Loads native libraries and creates a decoder.
  /// Notes: Initialization errors release the decoder and propagate to the website fallback.
  MediaKitAnimePlayer() {
    MediaKit.ensureInitialized();
    _player = Player(
      configuration: const PlayerConfiguration(logLevel: MPVLogLevel.error),
    );
    try {
      _controller = VideoController(_player);
    } catch (_) {
      unawaited(_player.dispose().catchError((Object _) {}));
      rethrow;
    }
  }

  /// Purpose: Forward decoder error events.
  /// Inputs: None.
  /// Returns: Stream.
  /// Side effects: None.
  /// Notes: Do not log event contents.
  @override
  Stream<String> get errors => _player.stream.error;

  /// Purpose: Forward playback progress.
  /// Inputs: None.
  /// Returns: Stream.
  /// Side effects: None.
  /// Notes: None.
  @override
  Stream<Duration> get positions => _player.stream.position;

  /// Purpose: Forward duration changes.
  /// Inputs: None.
  /// Returns: Stream.
  /// Side effects: None.
  /// Notes: None.
  @override
  Stream<Duration> get durations => _player.stream.duration;

  /// Purpose: Forward play/pause changes.
  /// Inputs: None.
  /// Returns: Stream.
  /// Side effects: None.
  /// Notes: None.
  @override
  Stream<bool> get playing => _player.stream.playing;

  /// Purpose: Forward rate changes.
  /// Inputs: None.
  /// Returns: Stream.
  /// Side effects: None.
  /// Notes: None.
  @override
  Stream<double> get rates => _player.stream.rate;

  /// Purpose: Read the current position.
  /// Inputs: None.
  /// Returns: `Duration`.
  /// Side effects: None.
  /// Notes: None.
  @override
  Duration get position => _player.state.position;

  /// Purpose: Read the current duration.
  /// Inputs: None.
  /// Returns: `Duration`.
  /// Side effects: None.
  /// Notes: None.
  @override
  Duration get duration => _player.state.duration;

  /// Purpose: Read whether playback runs.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  @override
  bool get isPlaying => _player.state.playing;

  /// Purpose: Read the current rate.
  /// Inputs: None.
  /// Returns: `double`.
  /// Side effects: None.
  /// Notes: None.
  @override
  double get rate => _player.state.rate;

  /// Purpose: Seek the decoder.
  /// Inputs: `position`.
  /// Returns: Completion.
  /// Side effects: Seeks.
  /// Notes: None.
  @override
  Future<void> seek(Duration position) => _player.seek(position);

  /// Purpose: Start playback.
  /// Inputs: None.
  /// Returns: Completion.
  /// Side effects: Playback.
  /// Notes: None.
  @override
  Future<void> play() => _player.play();

  /// Purpose: Pause playback.
  /// Inputs: None.
  /// Returns: Completion.
  /// Side effects: Playback.
  /// Notes: None.
  @override
  Future<void> pause() => _player.pause();

  /// Purpose: Toggle playback.
  /// Inputs: None.
  /// Returns: Completion.
  /// Side effects: Playback.
  /// Notes: None.
  @override
  Future<void> playOrPause() => _player.playOrPause();

  /// Purpose: Change speed.
  /// Inputs: `rate`.
  /// Returns: Completion.
  /// Side effects: Playback.
  /// Notes: None.
  @override
  Future<void> setRate(double rate) => _player.setRate(rate);

  /// Purpose: Render the video with the app's controls.
  /// Inputs: `controls`.
  /// Returns: Native video widget.
  /// Side effects: None.
  /// Notes: media_kit's own controls are replaced; its wakelock and
  /// pause-in-background defaults are kept. A `Builder` supplies the context
  /// media_kit reads fullscreen state from, including inside its fullscreen
  /// route.
  @override
  Widget buildVideo(AnimePlayerControlsBuilder controls) => Video(
    controller: _controller,
    controls: (_) => Builder(
      builder: (context) => controls(_ContextFullscreenHost(context)),
    ),
  );

  /// Purpose: Open a session-only source with its request headers.
  /// Inputs: Media source.
  /// Returns: Completion.
  /// Side effects: Begins playback.
  /// Notes: None.
  @override
  Future<void> open(AnimeMediaSource source) =>
      _player.open(Media(source.url, httpHeaders: source.headers));

  /// Purpose: Stop and free the player.
  /// Inputs: None.
  /// Returns: Completion.
  /// Side effects: Stops audio and video.
  /// Notes: None.
  @override
  Future<void> dispose() => _player.dispose();
}
