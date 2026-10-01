/// Pure image operations behind the avatar editor (1.7.2). Every function is
/// synchronous and allocation-only, so callers run them in another isolate
/// (`Isolate.run`) to keep the UI responsive.
library;

import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// An upright, size-limited copy of a picked image, ready for the editor.
class AvatarSource {
  /// Encoded image bytes (PNG), already rotated upright.
  final Uint8List bytes;

  /// Width of [bytes] in pixels.
  final int width;

  /// Height of [bytes] in pixels.
  final int height;

  /// Purpose: Create an avatar source.
  /// Inputs: `bytes`, `width`, `height`.
  /// Returns: A new `AvatarSource`.
  /// Side effects: None.
  /// Notes: None.
  const AvatarSource(this.bytes, this.width, this.height);
}

/// Longest edge, in pixels, the editor works with. Larger photos are scaled
/// down first; a 512-pixel avatar never needs more.
const avatarSourceMaxEdge = 2048;

/// Purpose: Decode any image without letting a decoder exception escape.
/// Inputs: `bytes`.
/// Returns: `img.Image`.
/// Side effects: None.
/// Notes: Internal helper used within this file only. Truncated or foreign
/// data can make a format probe throw (for example a RangeError) instead of
/// returning null; both become a [FormatException].
img.Image _decode(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    decoded = null;
  }
  if (decoded == null) {
    throw const FormatException('Not a supported image');
  }
  return decoded;
}

/// Purpose: Normalise a picked image for the editor.
/// Inputs: `bytes` — the picked file; `quarterTurns` — extra clockwise
/// 90° turns to apply (the editor's rotate button).
/// Returns: `AvatarSource` — upright (EXIF applied), longest edge at most
/// [avatarSourceMaxEdge], encoded as PNG.
/// Side effects: None.
/// Notes: Baking the orientation here means the pixels the editor shows and
/// the pixels [cropAvatarJpeg] cuts are the same, whatever the platform's
/// own EXIF handling. Throws [FormatException] for non-images.
AvatarSource prepareAvatarSource(Uint8List bytes, {int quarterTurns = 0}) {
  var image = img.bakeOrientation(_decode(bytes));
  final turns = quarterTurns % 4;
  if (turns != 0) {
    image = img.copyRotate(image, angle: 90 * turns);
  }
  final longest = image.width > image.height ? image.width : image.height;
  if (longest > avatarSourceMaxEdge) {
    image = image.width >= image.height
        ? img.copyResize(image, width: avatarSourceMaxEdge)
        : img.copyResize(image, height: avatarSourceMaxEdge);
  }
  return AvatarSource(
    Uint8List.fromList(img.encodePng(image)),
    image.width,
    image.height,
  );
}

/// Purpose: Cut the square the user framed and encode it as the avatar.
/// Inputs: `source` — bytes from [prepareAvatarSource]; `x`, `y`, `side` —
/// the square in source pixels; `size` — output edge in pixels.
/// Returns: `Uint8List` — JPEG bytes, `size` × `size`.
/// Side effects: None.
/// Notes: The square is clamped into the image, so rounding at the edges
/// never fails. Throws [FormatException] for non-images.
Uint8List cropAvatarJpeg(
  Uint8List source, {
  required int x,
  required int y,
  required int side,
  required int size,
}) {
  final image = _decode(source);
  final maxSide = image.width < image.height ? image.width : image.height;
  final s = side.clamp(1, maxSide);
  final cx = x.clamp(0, image.width - s);
  final cy = y.clamp(0, image.height - s);
  final cropped = img.copyCrop(image, x: cx, y: cy, width: s, height: s);
  final resized = img.copyResize(
    cropped,
    width: size,
    height: size,
    interpolation: img.Interpolation.average,
  );
  return Uint8List.fromList(img.encodeJpg(resized, quality: 88));
}

/// Purpose: Turn any decodable image into a centred square JPEG.
/// Inputs: `bytes` — the source image; `size` — output edge in pixels.
/// Returns: `Uint8List` — JPEG bytes.
/// Side effects: None; safe to run in another isolate.
/// Notes: The non-interactive path (no editor): applies EXIF orientation
/// and takes the centred square. Throws [FormatException] for non-images.
Uint8List squareAvatarJpeg(Uint8List bytes, int size) {
  final upright = img.bakeOrientation(_decode(bytes));
  final square = img.copyResizeCropSquare(
    upright,
    size: size,
    interpolation: img.Interpolation.average,
  );
  return Uint8List.fromList(img.encodeJpg(square, quality: 88));
}

/// Purpose: Run [prepareAvatarSource] in another isolate.
/// Inputs: `bytes`, `quarterTurns`.
/// Returns: `Future<AvatarSource>`.
/// Side effects: Spawns a short-lived isolate.
/// Notes: A top-level function on purpose: a closure created inside a
/// widget's State method also captures that State (and its controllers),
/// which cannot be sent to another isolate. Here the closure captures only
/// the arguments. Throws [FormatException] for non-images.
Future<AvatarSource> prepareAvatarSourceInBackground(
  Uint8List bytes, {
  int quarterTurns = 0,
}) => Isolate.run(() => prepareAvatarSource(bytes, quarterTurns: quarterTurns));

/// Purpose: Run [cropAvatarJpeg] in another isolate.
/// Inputs: as [cropAvatarJpeg].
/// Returns: `Future<Uint8List>` — the avatar JPEG.
/// Side effects: Spawns a short-lived isolate.
/// Notes: Top-level for the same reason as
/// [prepareAvatarSourceInBackground].
Future<Uint8List> cropAvatarJpegInBackground(
  Uint8List source, {
  required int x,
  required int y,
  required int side,
  required int size,
}) => Isolate.run(
  () => cropAvatarJpeg(source, x: x, y: y, side: side, size: size),
);
