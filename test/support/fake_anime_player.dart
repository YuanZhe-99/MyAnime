import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:my_anime/features/anime/services/anime_media_service.dart';
import 'package:my_anime/features/anime/views/anime_native_player.dart';

/// Deterministic stand-in for the media_kit player in widget tests.
///
/// Streams are driven by the test; every control call is recorded. Seeking,
/// rate and play/pause update the readable state and echo on the streams,
/// the way the real decoder does.
class FakeAnimePlayer implements AnimeNativePlayer {
  final failures = StreamController<String>.broadcast();
  final progress = StreamController<Duration>.broadcast();
  final lengths = StreamController<Duration>.broadcast();
  final playingEvents = StreamController<bool>.broadcast();
  final rateEvents = StreamController<double>.broadcast();

  int disposed = 0;
  int opened = 0;
  int toggles = 0;
  bool failOpen = false;
  bool failDispose = false;
  final seeks = <Duration>[];
  final rateCalls = <double>[];

  Duration currentPosition = Duration.zero;
  Duration currentDuration = Duration.zero;
  bool currentlyPlaying = false;
  double currentRate = 1.0;

  /// Purpose: Emit a position as the decoder would.
  /// Inputs: `value`.
  /// Returns: None.
  /// Side effects: Updates state and the stream.
  /// Notes: Test helper.
  void emitPosition(Duration value) {
    currentPosition = value;
    progress.add(value);
  }

  /// Purpose: Emit a duration as the decoder would.
  /// Inputs: `value`.
  /// Returns: None.
  /// Side effects: Updates state and the stream.
  /// Notes: Test helper.
  void emitDuration(Duration value) {
    currentDuration = value;
    lengths.add(value);
  }

  /// Purpose: Emit a play/pause change.
  /// Inputs: `value`.
  /// Returns: None.
  /// Side effects: Updates state and the stream.
  /// Notes: Test helper.
  void emitPlaying(bool value) {
    currentlyPlaying = value;
    playingEvents.add(value);
  }

  @override
  Stream<String> get errors => failures.stream;
  @override
  Stream<Duration> get positions => progress.stream;
  @override
  Stream<Duration> get durations => lengths.stream;
  @override
  Stream<bool> get playing => playingEvents.stream;
  @override
  Stream<double> get rates => rateEvents.stream;
  @override
  Duration get position => currentPosition;
  @override
  Duration get duration => currentDuration;
  @override
  bool get isPlaying => currentlyPlaying;
  @override
  double get rate => currentRate;

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    emitPosition(position);
  }

  @override
  Future<void> play() async => emitPlaying(true);
  @override
  Future<void> pause() async => emitPlaying(false);
  @override
  Future<void> playOrPause() async {
    toggles++;
    emitPlaying(!currentlyPlaying);
  }

  @override
  Future<void> setRate(double rate) async {
    rateCalls.add(rate);
    currentRate = rate;
    rateEvents.add(rate);
  }

  @override
  Widget buildVideo(AnimePlayerControlsBuilder controls) => Stack(
    fit: StackFit.expand,
    children: [const Text('native video'), controls(null)],
  );

  @override
  Future<void> open(AnimeMediaSource source) async {
    opened++;
    if (failOpen) throw StateError('decoder failure');
  }

  @override
  Future<void> dispose() async {
    disposed++;
    await failures.close();
    await progress.close();
    await lengths.close();
    await playingEvents.close();
    await rateEvents.close();
    if (failDispose) throw StateError('cleanup failed');
  }
}
