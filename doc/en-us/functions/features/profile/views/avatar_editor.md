# lib/features/profile/views/avatar_editor.dart

P3: shared declarations described below live in `myapps_profile`; this app
file is a re-export or adapter preserving its public import and constructor shape.
See [../../../../shared-ui.md](../../../../shared-ui.md).

The full-screen avatar editor (1.7.2): the user frames an image inside a circle, rotates it in quarter turns,
and saves. `showAvatarEditor` opens it and returns the framed square JPEG, which the profile dialog stores
through `ProfileNotifier.setAvatarJpeg`. The framed square is exactly what is stored, so the avatar always
matches what was shown. See [`../services/avatar_image.md`](../services/avatar_image.md),
[`profile_header.md`](profile_header.md) and [`../../../../features/profile.md`](../../../../features/profile.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`showAvatarEditor`](#showavatareditor) | top-level function | A | Let the user frame an avatar and return the result. |
| `AvatarEditorPage` | constructor (`AvatarEditorPage`) | B | Create the avatar editor for a source image. |
| `AvatarEditorPage.createState` | method (widget lifecycle) | B | Create the editor state. |
| `_AvatarEditorPageState.initState` | method (widget lifecycle) | B | Start preparing the image. |
| `_AvatarEditorPageState.dispose` | method (widget lifecycle) | B | Release the transformation controller. |
| [`_AvatarEditorPageState._prepare`](#_prepare) | method (`_AvatarEditorPageState`) | A | Decode, orient and size the source for the current rotation. |
| [`_AvatarEditorPageState._rotate`](#_rotate) | method (`_AvatarEditorPageState`) | A | Rotate a quarter turn clockwise. |
| [`_AvatarEditorPageState._reset`](#_reset) | method (`_AvatarEditorPageState`) | A | Return to the initial framing. |
| [`_AvatarEditorPageState._save`](#_save) | method (`_AvatarEditorPageState`) | A | Crop what the circle shows and return it. |
| [`_AvatarEditorPageState.build`](#_build) | method (widget build) | A | Build the editor: app bar, framed viewport, hint. |
| `_CircleMaskPainter` | constructor (`_CircleMaskPainter`) | B | Create the mask painter. |
| `_CircleMaskPainter.paint` | method (`CustomPainter`) | B | Paint the scrim with a circular hole and the outline. |
| `_CircleMaskPainter.shouldRepaint` | method (`CustomPainter`) | B | Repaint only when the colours change. |

## showAvatarEditor

- **Inputs:** `context`; `source` — the picked image, or the current avatar's bytes.
- **Returns:** `Future<Uint8List?>` — a `ProfileStore.avatarSize`-pixel square JPEG, or null when the user backed out.
- **Side effects:** Pushes a full-screen `MaterialPageRoute` (`fullscreenDialog: true`) with an `AvatarEditorPage`.
- **Notes:** Throws nothing for bad input: an undecodable image shows an error state in the editor instead.

## _prepare

- **Side effects:** Sets `_busy`, runs `prepareAvatarSourceInBackground(source, quarterTurns: _turns)` in
  another isolate, then stores the `AvatarSource`, clears the busy and failure flags and sets `_viewport = 0` so
  the next build re-centres the image; on failure sets `_failed`.
- **Notes:** Called from `initState` and after every rotation. Ignores the result when the page is no longer mounted.

## _rotate

- **Side effects:** Increments `_turns` (modulo 4) and calls `_prepare`, which re-prepares the image and resets the framing.
- **Notes:** The rotation is baked into the prepared PNG rather than applied as a display transform, so the
  pixels shown and the pixels cropped stay identical.

## _reset

- **Side effects:** Sets the transformation to `Matrix4.translationValues(-(base.width - viewport) / 2,
  -(base.height - viewport) / 2, 0)`: centred at zoom 1, the image filling the circle.
- **Notes:** Also called from a post-frame callback whenever the viewport size or image size changed.
  Transform resets happen after the frame, never during build, because the controller notifies its listeners.

## _save

- **Side effects:** Sets `_busy`, maps the viewport back through the transformation matrix to image pixels
  (`scale = getMaxScaleOnAxis()`; `x = -tx / scale * toPixels`; `y = -ty / scale * toPixels`;
  `side = viewport / scale * toPixels`, with `toPixels = image.width / base.width`), runs
  `cropAvatarJpegInBackground` with `size: ProfileStore.avatarSize`, and pops the route with the JPEG. On failure
  sets `_failed` and clears `_busy`.
- **Notes:** Does nothing while the image is not ready or the viewport has not been measured.

## _build

- **Algorithm:** A `Scaffold` whose `AppBar` (title `profileAdjustAvatar`) has three actions: **Rotate**
  (`rotate_90_degrees_cw_outlined`, tooltip `profileAvatarRotate`), **Reset** (`restart_alt`, tooltip
  `profileAvatarReset`) and a **Save** `FilledButton`; all are disabled while busy, before the image is
  ready and (Save) after a failure. The body is a `SafeArea`: the `profileAvatarError` text when `_failed`, a
  `CircularProgressIndicator` until the image is ready, otherwise a `Column` holding a square viewport and the
  hint text (`profileAvatarEditorHint`). The viewport side is `min(width, height - 96) - 32` clamped to
  160..480; the image is laid out to **cover** it (`cover = side / min(image.width, image.height)`) inside a
  `ClipRect` → `InteractiveViewer` (`constrained: false`, `minScale: 1`, `maxScale: 8`, `boundaryMargin:
  EdgeInsets.zero`) → `Image.memory`. Over it, an `IgnorePointer` `CustomPaint` draws `_CircleMaskPainter`:
  a `scrim` colour (55% alpha) everywhere outside the inscribed circle, plus a 2 px `primary` ring; a busy
  indicator overlays the viewport while `_busy`.
- **Notes:** Drag moves, pinch or scroll zooms (1x to 8x). `minScale: 1` and the zero boundary margin keep the
  image covering the circle however the user drags or zooms. `build` records the viewport side and the base image
  size for `_save`.
