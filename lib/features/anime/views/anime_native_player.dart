import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../services/anime_media_service.dart';

/// Small platform boundary that also allows deterministic playback lifecycle tests.
abstract interface class AnimeNativePlayer {
  /// Purpose: Expose decoder failures without logging sensitive media addresses.
  /// Inputs: None.
  /// Returns: Error event stream.
  /// Side effects: None.
  /// Notes: Consumers use only the occurrence, never display the raw error.
  Stream<String> get errors;

  /// Purpose: Expose playback progress for startup timeout cancellation.
  /// Inputs: None.
  /// Returns: Position event stream.
  /// Side effects: None.
  /// Notes: Does not write watch history.
  Stream<Duration> get positions;

  /// Purpose: Render the platform player's controls and video.
  /// Inputs: None.
  /// Returns: Video widget.
  /// Side effects: None.
  /// Notes: None.
  Widget buildVideo();

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

  /// Purpose: Render adaptive video controls.
  /// Inputs: None.
  /// Returns: Native video widget.
  /// Side effects: None.
  /// Notes: Controls include seeking, volume, rate and fullscreen.
  @override
  Widget buildVideo() => Video(controller: _controller);

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
