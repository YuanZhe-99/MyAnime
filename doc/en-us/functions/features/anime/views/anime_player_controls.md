# lib/features/anime/views/anime_player_controls.dart

The app's own playback controls (1.6.5), drawn over the native video in place of media_kit's stock
controls on every platform. The widget does not import media_kit: it drives an
`AnimeNativePlayer` and an optional `AnimeFullscreenHost`, so tests run it against a fake. See
[`../../../../features/watch-url-lookup.md`](../../../../features/watch-url-lookup.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `boostedPlaybackRate` | function | B | Speed while a long press is held: one step faster, at most 3.0. |
| [`dragSeekTarget`](#dragseektarget) | function | A | Map a horizontal swipe to a target position. |
| `formatPlaybackRate` | function | B | Format a speed such as `1.0x`. |
| `AnimePlayerControls` | constructor | B | Create the overlay. |
| `createState` | method | B | Create overlay state. |
| `initState` | method | B | Read the player's state and follow its streams. |
| `dispose` | method | B | Cancel timers and subscriptions; never touches the player. |
| `_update` | method | B | Apply a state change while mounted. |
| `_show` | method | B | Show the controls, optionally scheduling hiding. |
| `_restartHideTimer` | method | B | Hide after 3 s while playing, unless dragging or scrubbing. |
| `_seekTo` | method | B | Seek to a position clamped to the duration. |
| `_seekBy` | method | B | Jump from the current position. |
| `_togglePlay` | method | B | Toggle play/pause. |
| `_selectRate` | method | B | Pick a speed from the menu and report it to the page. |
| `_startBoost` | method | B | Start the long-press speed-up. |
| `_endBoost` | method | B | Restore the speed from before the long press. |
| `_onKey` | method | B | Desktop keys: Space, ← / →, F, Esc. |
| [`build`](#build) | method | A | Draw the gesture layer, controls and transient labels. |
| `_buildGestureLayer` | method | B | Full-size layer for tap, double tap, long press and swipe. |
| `_buildTopBar` | method | B | Fullscreen-only title row with an exit button. |
| `_buildCenterRow` | method | B | Back 5 s, play/pause, forward 5 s. |
| `_buildBottomBar` | method | B | Times, seek bar, speed menu and fullscreen button. |
| `_buildDragLabel` | method | B | Swipe preview, e.g. `12:34 / 23:40 (+15s)`. |
| `_Badge` | constructor | B | Create a dark rounded label. |
| `_Badge.build` | method | B | Draw the label. |

`animePlaybackRates` (0.25, 0.5, 1.0, 1.5, 2.0, 3.0), `animeMaxPlaybackRate` (3.0),
`animeSeekStep` (5 s), `animeDragSeekSpan` (90 s) and `animeControlsHideDelay` (3 s) carry no
`/// Purpose:` comment.

## dragSeekTarget

- **Algorithm:** a full-width swipe covers the shorter of the media length and 90 s, so a phone
  swipe stays fine-grained on a 24-minute episode; the result is clamped to `[0, duration]`.
  Unknown duration or zero width returns the start position.

## build

- **Notes:** the gesture layer is the bottom child of a `Stack`, beneath the buttons and the seek
  bar, so the slider's own drag never competes with swipe-to-seek. The centre row is
  `MainAxisSize.min`, so taps beside it reach the gesture layer. Tap toggles visibility (delayed by
  the double-tap window), double tap plays or pauses, a long press sets `boostedPlaybackRate` until
  release and shows a badge, a horizontal swipe previews the target and seeks once on release. The
  seek bar and the ±5 s buttons are disabled while the duration is unknown. A mouse hover shows the
  controls on desktop.
