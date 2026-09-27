import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/playback_time.dart';
import 'anime_native_player.dart';

/// Speeds offered by the speed menu (1.6.5).
const animePlaybackRates = <double>[0.25, 0.5, 1.0, 1.5, 2.0, 3.0];

/// Highest speed a long press may reach.
const animeMaxPlaybackRate = 3.0;

/// Distance one seek button or arrow key jumps.
const animeSeekStep = Duration(seconds: 5);

/// Media time one full-width horizontal swipe covers, at most.
const animeDragSeekSpan = Duration(seconds: 90);

/// How long the controls stay visible without interaction while playing.
const animeControlsHideDelay = Duration(seconds: 3);

/// Purpose: Return the speed used while a long press is held.
/// Inputs: `rate` — the speed before the press.
/// Returns: `double` — one step faster, capped at [animeMaxPlaybackRate].
/// Side effects: None.
/// Notes: 1.0 becomes 2.0, 1.5 becomes 2.5, 2.0 and 3.0 both become 3.0.
double boostedPlaybackRate(double rate) =>
    math.min(animeMaxPlaybackRate, rate + 1.0);

/// Purpose: Map a horizontal swipe to a target position.
/// Inputs: `start` — position when the swipe began; `dx` — horizontal
/// distance so far, positive to the right; `width` — the video's width;
/// `duration` — media length.
/// Returns: `Duration` clamped to `[0, duration]`.
/// Side effects: None.
/// Notes: A full-width swipe covers the shorter of the media length and
/// [animeDragSeekSpan], so a phone swipe stays fine-grained on a long
/// episode. Unknown duration or zero width returns `start`.
Duration dragSeekTarget({
  required Duration start,
  required double dx,
  required double width,
  required Duration duration,
}) {
  if (duration <= Duration.zero || width <= 0) return start;
  final span = duration < animeDragSeekSpan ? duration : animeDragSeekSpan;
  final ms = start.inMilliseconds + span.inMilliseconds * dx / width;
  return Duration(
    milliseconds: ms.round().clamp(0, duration.inMilliseconds).toInt(),
  );
}

/// Purpose: Format a speed for display.
/// Inputs: `rate`.
/// Returns: `String` such as `1.0x` or `0.25x`.
/// Side effects: None.
/// Notes: Numeric only, so it needs no localization.
String formatPlaybackRate(double rate) => '${rate}x';

/// The app's own playback controls, drawn over the native video (1.6.5).
class AnimePlayerControls extends StatefulWidget {
  /// The player the controls drive.
  final AnimeNativePlayer player;

  /// Fullscreen switch; null hides the fullscreen button.
  final AnimeFullscreenHost? fullscreen;

  /// Episode title, shown in fullscreen where the app bar is hidden.
  final String title;

  /// Called when the user picks a speed from the menu.
  final ValueChanged<double>? onRateSelected;

  /// Purpose: Create the overlay.
  /// Inputs: `player`, `fullscreen`, `title`, optional `onRateSelected`.
  /// Returns: Widget.
  /// Side effects: None until mounted.
  /// Notes: Does not import media_kit, so tests drive it with a fake player.
  const AnimePlayerControls({
    super.key,
    required this.player,
    required this.fullscreen,
    required this.title,
    this.onRateSelected,
  });

  /// Purpose: Create overlay state.
  /// Inputs: None.
  /// Returns: State.
  /// Side effects: None.
  /// Notes: None.
  @override
  State<AnimePlayerControls> createState() => _AnimePlayerControlsState();
}

class _AnimePlayerControlsState extends State<AnimePlayerControls> {
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _focus = FocusNode(debugLabel: 'animePlayerControls');
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  double _rate = 1.0;
  bool _visible = true;
  Timer? _hideTimer;
  Duration? _dragStart;
  Duration? _dragTarget;
  double _dragDx = 0;
  double? _sliderMs;
  double? _rateBeforeBoost;

  /// Purpose: Read the player's current state and follow its streams.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Subscribes to player streams; starts the hide timer.
  /// Notes: None.
  @override
  void initState() {
    super.initState();
    final p = widget.player;
    _position = p.position;
    _duration = p.duration;
    _playing = p.isPlaying;
    _rate = p.rate;
    _subscriptions
      ..add(p.positions.listen((v) => _update(() => _position = v)))
      ..add(p.durations.listen((v) => _update(() => _duration = v)))
      ..add(p.rates.listen((v) => _update(() => _rate = v)))
      ..add(
        p.playing.listen((v) {
          _update(() => _playing = v);
          if (v) {
            _restartHideTimer();
          } else {
            _show(autoHide: false);
          }
        }),
      );
    _restartHideTimer();
  }

  /// Purpose: Cancel timers and stream subscriptions.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Releases listeners and the focus node.
  /// Notes: Does not touch the player, which the page owns.
  @override
  void dispose() {
    _hideTimer?.cancel();
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    _focus.dispose();
    super.dispose();
  }

  /// Purpose: Apply a state change while mounted.
  /// Inputs: `change`.
  /// Returns: None.
  /// Side effects: Rebuilds.
  /// Notes: Internal helper.
  void _update(VoidCallback change) {
    if (mounted) setState(change);
  }

  /// Purpose: Show the controls.
  /// Inputs: `autoHide` — whether to schedule hiding.
  /// Returns: None.
  /// Side effects: Rebuilds; may start the hide timer.
  /// Notes: Internal helper.
  void _show({bool autoHide = true}) {
    if (!_visible) _update(() => _visible = true);
    if (autoHide) {
      _restartHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  /// Purpose: Schedule hiding the controls.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Replaces the hide timer.
  /// Notes: Controls stay while paused, dragging or scrubbing.
  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(animeControlsHideDelay, () {
      if (!_playing || _dragTarget != null || _sliderMs != null) return;
      _update(() => _visible = false);
    });
  }

  /// Purpose: Seek to a clamped position.
  /// Inputs: `target`.
  /// Returns: None.
  /// Side effects: Seeks the player; updates the shown position.
  /// Notes: Ignored while the duration is unknown.
  void _seekTo(Duration target) {
    if (_duration <= Duration.zero) return;
    final ms = target.inMilliseconds.clamp(0, _duration.inMilliseconds);
    final clamped = Duration(milliseconds: ms);
    _update(() => _position = clamped);
    unawaited(widget.player.seek(clamped));
  }

  /// Purpose: Jump forward or back from the current position.
  /// Inputs: `delta`.
  /// Returns: None.
  /// Side effects: Seeks; shows the controls.
  /// Notes: None.
  void _seekBy(Duration delta) {
    _seekTo(_position + delta);
    _show();
  }

  /// Purpose: Toggle play/pause.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Playback; shows the controls.
  /// Notes: None.
  void _togglePlay() {
    unawaited(widget.player.playOrPause());
    _show();
  }

  /// Purpose: Pick a speed from the menu.
  /// Inputs: `rate`.
  /// Returns: None.
  /// Side effects: Changes speed; reports it to the page.
  /// Notes: A long press in progress now returns to this speed.
  void _selectRate(double rate) {
    if (_rateBeforeBoost != null) _rateBeforeBoost = rate;
    unawaited(widget.player.setRate(rate));
    widget.onRateSelected?.call(rate);
    _show();
  }

  /// Purpose: Start the temporary long-press speed-up.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Changes speed.
  /// Notes: Remembers the speed to restore.
  void _startBoost() {
    final base = _rate;
    _update(() => _rateBeforeBoost = base);
    unawaited(widget.player.setRate(boostedPlaybackRate(base)));
  }

  /// Purpose: End the long-press speed-up.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Restores the previous speed.
  /// Notes: None.
  void _endBoost() {
    final base = _rateBeforeBoost;
    if (base == null) return;
    _update(() => _rateBeforeBoost = null);
    unawaited(widget.player.setRate(base));
  }

  /// Purpose: Handle desktop keyboard shortcuts.
  /// Inputs: `node`, `event`.
  /// Returns: Whether the key was used.
  /// Side effects: Playback, seeking or fullscreen.
  /// Notes: Space, arrow keys, F and Escape.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space && event is KeyDownEvent) {
      _togglePlay();
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _seekBy(-animeSeekStep);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _seekBy(animeSeekStep);
    } else if (key == LogicalKeyboardKey.keyF && event is KeyDownEvent) {
      final host = widget.fullscreen;
      if (host == null) return KeyEventResult.ignored;
      unawaited(host.toggle());
    } else if (key == LogicalKeyboardKey.escape && event is KeyDownEvent) {
      final host = widget.fullscreen;
      if (host == null || !host.isFullscreen) return KeyEventResult.ignored;
      unawaited(host.exit());
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// Purpose: Draw the gesture layer, the controls and the transient labels.
  /// Inputs: Build context.
  /// Returns: Overlay widget.
  /// Side effects: User actions drive the player.
  /// Notes: The gesture layer sits beneath the buttons and the seek bar, so
  /// the slider's drag never competes with the swipe-to-seek gesture.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fullscreen = widget.fullscreen;
    final isFullscreen = fullscreen?.isFullscreen ?? false;
    final known = _duration > Duration.zero;
    final shownRate = _rateBeforeBoost ?? _rate;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: MouseRegion(
        onHover: (_) => _show(),
        child: IconTheme(
          data: const IconThemeData(color: Colors.white),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.white),
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                fit: StackFit.expand,
                children: [
                  _buildGestureLayer(constraints.maxWidth),
                  IgnorePointer(
                    ignoring: !_visible,
                    child: AnimatedOpacity(
                      opacity: _visible ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Column(
                        children: [
                          if (isFullscreen)
                            _buildTopBar(l10n, fullscreen!)
                          else
                            const SizedBox.shrink(),
                          Expanded(child: Center(child: _buildCenterRow(l10n))),
                          _buildBottomBar(l10n, known, shownRate, fullscreen),
                        ],
                      ),
                    ),
                  ),
                  // Above the centre buttons, so the preview never covers
                  // the play button.
                  if (_dragTarget != null)
                    Align(
                      alignment: const Alignment(0, -0.45),
                      child: _buildDragLabel(),
                    ),
                  if (_rateBeforeBoost != null)
                    Align(
                      alignment: const Alignment(0, -0.8),
                      child: _Badge(
                        key: const ValueKey('animePlayerBoost'),
                        text: formatPlaybackRate(_rate),
                        icon: Icons.fast_forward,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Purpose: Build the full-size layer that receives taps and swipes.
  /// Inputs: `width` — the video's width, used to scale swipes.
  /// Returns: Widget.
  /// Side effects: None.
  /// Notes: Single tap toggles visibility, double tap plays or pauses, a
  /// long press speeds up while held, a horizontal swipe seeks on release.
  Widget _buildGestureLayer(double width) => GestureDetector(
    key: const ValueKey('animePlayerGestures'),
    behavior: HitTestBehavior.opaque,
    onTap: () {
      if (_visible) {
        _hideTimer?.cancel();
        _update(() => _visible = false);
      } else {
        _show();
      }
    },
    onDoubleTap: _togglePlay,
    onLongPressStart: (_) => _startBoost(),
    onLongPressEnd: (_) => _endBoost(),
    onLongPressCancel: _endBoost,
    onHorizontalDragStart: (_) {
      if (_duration <= Duration.zero) return;
      _hideTimer?.cancel();
      _update(() {
        _dragStart = _position;
        _dragDx = 0;
        _dragTarget = _position;
        _visible = true;
      });
    },
    onHorizontalDragUpdate: (d) {
      final start = _dragStart;
      if (start == null) return;
      _dragDx += d.delta.dx;
      _update(
        () => _dragTarget = dragSeekTarget(
          start: start,
          dx: _dragDx,
          width: width,
          duration: _duration,
        ),
      );
    },
    onHorizontalDragEnd: (_) {
      final target = _dragTarget;
      _update(() {
        _dragStart = null;
        _dragTarget = null;
      });
      if (target != null) _seekTo(target);
      _restartHideTimer();
    },
    onHorizontalDragCancel: () {
      _update(() {
        _dragStart = null;
        _dragTarget = null;
      });
    },
  );

  /// Purpose: Build the fullscreen-only title row.
  /// Inputs: `l10n`, `host`.
  /// Returns: Widget.
  /// Side effects: None.
  /// Notes: Replaces the app bar, which the fullscreen route does not show.
  Widget _buildTopBar(AppLocalizations l10n, AnimeFullscreenHost host) =>
      DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black54, Colors.transparent],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              IconButton(
                onPressed: () => unawaited(host.exit()),
                tooltip: l10n.episodeExitFullscreen,
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );

  /// Purpose: Build the back-5, play/pause and forward-5 buttons.
  /// Inputs: `l10n`.
  /// Returns: Widget.
  /// Side effects: None.
  /// Notes: `mainAxisSize.min`, so taps beside the buttons reach the gesture
  /// layer.
  Widget _buildCenterRow(AppLocalizations l10n) {
    final known = _duration > Duration.zero;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: known ? () => _seekBy(-animeSeekStep) : null,
          tooltip: l10n.episodeSeekBack,
          iconSize: 36,
          icon: const Icon(Icons.replay_5),
        ),
        const SizedBox(width: 24),
        IconButton(
          onPressed: _togglePlay,
          tooltip: _playing ? l10n.episodePause : l10n.episodePlay,
          iconSize: 56,
          icon: Icon(_playing ? Icons.pause_circle : Icons.play_circle),
        ),
        const SizedBox(width: 24),
        IconButton(
          onPressed: known ? () => _seekBy(animeSeekStep) : null,
          tooltip: l10n.episodeSeekForward,
          iconSize: 36,
          icon: const Icon(Icons.forward_5),
        ),
      ],
    );
  }

  /// Purpose: Build the seek bar, times, speed menu and fullscreen button.
  /// Inputs: `l10n`; `known` — whether the duration is known; `shownRate` —
  /// the menu speed (the pre-boost one during a long press); `host`.
  /// Returns: Widget.
  /// Side effects: None.
  /// Notes: The seek bar is disabled while the duration is unknown.
  Widget _buildBottomBar(
    AppLocalizations l10n,
    bool known,
    double shownRate,
    AnimeFullscreenHost? host,
  ) {
    final max = known ? _duration.inMilliseconds.toDouble() : 1.0;
    final value = (_sliderMs ?? _position.inMilliseconds.toDouble()).clamp(
      0.0,
      max,
    );
    final isFullscreen = host?.isFullscreen ?? false;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black54, Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Text(
                formatPlaybackClock(
                  _sliderMs == null
                      ? _position
                      : Duration(milliseconds: _sliderMs!.round()),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  // White on the dark gradient, whatever the app theme, so
                  // the bar stays legible over any video.
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white38,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white24,
                  ),
                  child: Slider(
                    key: const ValueKey('animePlayerSeekBar'),
                    value: value,
                    max: max,
                    onChanged: known
                        ? (v) {
                            _hideTimer?.cancel();
                            _update(() => _sliderMs = v);
                          }
                        : null,
                    onChangeEnd: known
                        ? (v) {
                            _update(() => _sliderMs = null);
                            _seekTo(Duration(milliseconds: v.round()));
                            _restartHideTimer();
                          }
                        : null,
                  ),
                ),
              ),
              Text(known ? formatPlaybackClock(_duration) : '--:--'),
              PopupMenuButton<double>(
                key: const ValueKey('animePlayerSpeed'),
                tooltip: l10n.episodeSpeed,
                initialValue: shownRate,
                onSelected: _selectRate,
                onOpened: () => _hideTimer?.cancel(),
                onCanceled: _restartHideTimer,
                itemBuilder: (_) => [
                  for (final r in animePlaybackRates)
                    CheckedPopupMenuItem<double>(
                      value: r,
                      checked: r == shownRate,
                      child: Text(formatPlaybackRate(r)),
                    ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  child: Text(formatPlaybackRate(shownRate)),
                ),
              ),
              if (host != null)
                IconButton(
                  onPressed: () => unawaited(host.toggle()),
                  tooltip: isFullscreen
                      ? l10n.episodeExitFullscreen
                      : l10n.episodeFullscreen,
                  icon: Icon(
                    isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Purpose: Build the swipe preview label.
  /// Inputs: None.
  /// Returns: Widget.
  /// Side effects: None.
  /// Notes: Shows the target and the signed offset, e.g. `12:34 / 23:40
  /// (+15s)`.
  Widget _buildDragLabel() {
    final target = _dragTarget!;
    final offset = (target - (_dragStart ?? target)).inSeconds;
    final sign = offset >= 0 ? '+' : '-';
    return _Badge(
      key: const ValueKey('animePlayerDragLabel'),
      text:
          '${formatPlaybackClock(target)} / ${formatPlaybackClock(_duration)}'
          '  ($sign${offset.abs()}s)',
    );
  }
}

/// Rounded dark label used for the swipe preview and the speed-up badge.
class _Badge extends StatelessWidget {
  final String text;
  final IconData? icon;

  /// Purpose: Create a label.
  /// Inputs: `text`, optional `icon`.
  /// Returns: Widget.
  /// Side effects: None.
  /// Notes: None.
  const _Badge({super.key, required this.text, this.icon});

  /// Purpose: Draw the label.
  /// Inputs: Build context.
  /// Returns: Widget.
  /// Side effects: None.
  /// Notes: None.
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(text, style: const TextStyle(color: Colors.white)),
        ],
      ),
    ),
  );
}
