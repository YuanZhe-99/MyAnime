# lib/features/profile/services/avatar_image.dart

P3: shared declarations described below live in `myapps_profile`; this app
file is a re-export or adapter preserving its public import and constructor shape.
See [../../../../shared-ui.md](../../../../shared-ui.md).

The pure image operations behind the avatar editor (1.7.2). Every function is synchronous and
allocation-only, so callers run them in another isolate to keep the UI responsive: the two
`...InBackground` wrappers do that with `Isolate.run`. `squareAvatarJpeg` moved here from
`profile_store.dart`, where it lived in 1.7.0 and 1.7.1. See
[`../views/avatar_editor.md`](../views/avatar_editor.md), [`profile_store.md`](profile_store.md) and
[`../../../../features/profile.md`](../../../../features/profile.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `AvatarSource` | class | B | An upright, size-limited PNG copy of a picked image, with its `bytes`, `width` and `height`. |
| `AvatarSource.new` | constructor (`AvatarSource`) | B | Create an avatar source. |
| `_decode` | top-level function | B | Decode any image without letting a decoder exception escape. |
| [`prepareAvatarSource`](#prepareavatarsource) | top-level function | A | Normalise a picked image for the editor: upright, limited to 2048 px, PNG. |
| [`cropAvatarJpeg`](#cropavatarjpeg) | top-level function | A | Cut the square the user framed and encode it as the avatar JPEG. |
| [`squareAvatarJpeg`](#squareavatarjpeg) | top-level function | A | Turn any decodable image into a centred square JPEG (moved from `profile_store.dart`). |
| [`prepareAvatarSourceInBackground`](#prepareavatarsourceinbackground) | top-level function | A | Run `prepareAvatarSource` in another isolate. |
| [`cropAvatarJpegInBackground`](#cropavatarjpegbackground) | top-level function | A | Run `cropAvatarJpeg` in another isolate. |

`avatarSourceMaxEdge` (`2048`, the longest edge the editor works with) is a plain constant without a
`/// Purpose:` comment.

## _decode

- **Notes:** Truncated or foreign data can make a format probe throw (for example a `RangeError`)
  instead of returning null; both that and a null result become `FormatException('Not a supported image')`.

## prepareAvatarSource

- **Inputs:** `bytes` — the picked file; `quarterTurns` — extra clockwise 90° turns (the editor's rotate
  button), taken modulo 4.
- **Returns:** `AvatarSource` — upright (EXIF applied), longest edge at most `avatarSourceMaxEdge`, encoded as PNG.
- **Algorithm:** `_decode`, `bakeOrientation`, `copyRotate(angle: 90 * turns)` when the turns are not 0, then
  `copyResize` to 2048 on the longer side when the image is larger, then `encodePng`.
- **Notes:** Baking the orientation here means the pixels the editor shows and the pixels `cropAvatarJpeg` cuts
  are the same, whatever the platform's own EXIF handling. Throws `FormatException` for non-images. A 512-pixel
  avatar never needs more than 2048 pixels of source, which also keeps memory and isolate transfer small.

## cropAvatarJpeg

- **Inputs:** `source` — the PNG bytes from `prepareAvatarSource` (a `Uint8List`, not the `AvatarSource`);
  `x`, `y`, `side` — the square in source pixels; `size` — the output edge in pixels.
- **Returns:** `Uint8List` — JPEG bytes, `size` × `size`.
- **Algorithm:** `_decode`; clamp `side` into 1..shorter edge, then `x` and `y` so the square stays inside the
  image; `copyCrop`; `copyResize(size, size, interpolation: average)`; `encodeJpg(quality: 88)`.
- **Notes:** The clamp means rounding at the image edges never fails. Throws `FormatException` for non-images.
  The editor passes `ProfileStore.avatarSize` (512).

## squareAvatarJpeg

- **Inputs:** `bytes` — the source image; `size` — output edge in pixels.
- **Returns:** `Uint8List` — JPEG bytes.
- **Algorithm:** `_decode`, `bakeOrientation`, `copyResizeCropSquare(size: size, interpolation: average)`, then
  `encodeJpg(quality: 88)`.
- **Notes:** The non-interactive path (no editor): applies the EXIF orientation and takes the centred square.
  Pure and safe to run in another isolate. Throws `FormatException` for non-images.

## prepareAvatarSourceInBackground

- **Inputs:** `bytes`, `quarterTurns` (default 0).
- **Returns:** `Future<AvatarSource>`.
- **Side effects:** Spawns a short-lived isolate (`Isolate.run`).
- **Notes:** **Top-level on purpose.** A closure created inside a widget's `State` method also captures that
  `State` (and its controllers), which cannot be sent to another isolate; this was a real bug found in GUI
  testing. Here the closure captures only the arguments. Throws `FormatException` for non-images.

## cropAvatarJpegInBackground

- **Inputs:** as `cropAvatarJpeg`.
- **Returns:** `Future<Uint8List>` — the avatar JPEG.
- **Side effects:** Spawns a short-lived isolate (`Isolate.run`).
- **Notes:** Top-level for the same reason as `prepareAvatarSourceInBackground`.
