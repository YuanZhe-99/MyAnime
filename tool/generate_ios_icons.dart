import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Purpose: Store the inclusive visible-pixel rectangle for an image.
/// Inputs: `minX`, `minY`, `maxX`, `maxY`.
/// Returns: A bounds value object.
/// Side effects: None.
/// Notes: Coordinates are inclusive because they come from pixel positions.
class Bounds {
  /// Purpose: Create an immutable image bounds value.
  /// Inputs: `minX`, `minY`, `maxX`, `maxY`.
  /// Returns: A `Bounds` instance.
  /// Side effects: None.
  /// Notes: None.
  const Bounds(this.minX, this.minY, this.maxX, this.maxY);

  final int minX;
  final int minY;
  final int maxX;
  final int maxY;

  /// Purpose: Calculate the inclusive bounds width.
  /// Inputs: None.
  /// Returns: Width in pixels.
  /// Side effects: None.
  /// Notes: None.
  int get width => maxX - minX + 1;

  /// Purpose: Calculate the inclusive bounds height.
  /// Inputs: None.
  /// Returns: Height in pixels.
  /// Side effects: None.
  /// Notes: None.
  int get height => maxY - minY + 1;
}

/// Purpose: Find the rectangle containing visible alpha pixels.
/// Inputs: `image`, optional alpha `threshold`.
/// Returns: Inclusive visible-pixel bounds.
/// Side effects: Throws if no visible pixels are found.
/// Notes: Used to center artwork by actual content instead of canvas size.
Bounds alphaBounds(img.Image image, {int threshold = 8}) {
  var minX = image.width;
  var minY = image.height;
  var maxX = -1;
  var maxY = -1;
  for (final pixel in image) {
    if (pixel.a > threshold) {
      minX = math.min(minX, pixel.x);
      minY = math.min(minY, pixel.y);
      maxX = math.max(maxX, pixel.x);
      maxY = math.max(maxY, pixel.y);
    }
  }
  if (maxX < minX || maxY < minY) {
    throw StateError('No visible pixels found.');
  }
  return Bounds(minX, minY, maxX, maxY);
}

/// Purpose: Find non-background content bounds for an opaque image.
/// Inputs: `image`, optional color-delta `threshold`.
/// Returns: Inclusive content bounds.
/// Side effects: Throws if no content pixels are found.
/// Notes: The top-left pixel is treated as the background reference color.
Bounds contentBoundsAgainstCorner(img.Image image, {int threshold = 12}) {
  final bg = image.getPixel(0, 0);
  var minX = image.width;
  var minY = image.height;
  var maxX = -1;
  var maxY = -1;
  for (final pixel in image) {
    final delta =
        (pixel.r - bg.r).abs() +
        (pixel.g - bg.g).abs() +
        (pixel.b - bg.b).abs() +
        (pixel.a - bg.a).abs();
    if (delta > threshold) {
      minX = math.min(minX, pixel.x);
      minY = math.min(minY, pixel.y);
      maxX = math.max(maxX, pixel.x);
      maxY = math.max(maxY, pixel.y);
    }
  }
  if (maxX < minX || maxY < minY) {
    throw StateError('No content pixels found.');
  }
  return Bounds(minX, minY, maxX, maxY);
}

/// Purpose: Resize source artwork into the iOS icon safe area.
/// Inputs: `source`, output `size`, max visible `targetBounds`.
/// Returns: A transparent square image with centered artwork.
/// Side effects: None.
/// Notes: Keeps the visible artwork at roughly 72% of the square icon size.
img.Image scaleIntoSafeArea(
  img.Image source, {
  int size = 2560,
  int targetBounds = 1850,
}) {
  final bounds = alphaBounds(source);
  final scale = targetBounds / math.max(bounds.width, bounds.height);
  final resized = img.copyResize(
    source,
    width: (source.width * scale).round(),
    height: (source.height * scale).round(),
    interpolation: img.Interpolation.average,
  );
  final resizedBounds = alphaBounds(resized);
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));
  final dstX = ((size - resizedBounds.width) / 2).round() - resizedBounds.minX;
  final dstY = ((size - resizedBounds.height) / 2).round() - resizedBounds.minY;
  img.compositeImage(canvas, resized, dstX: dstX, dstY: dstY);
  return canvas;
}

/// Purpose: Compose the opaque default iOS icon source.
/// Inputs: Transparent padded artwork.
/// Returns: RGB icon image on a white background.
/// Side effects: None.
/// Notes: App Store marketing icons must not contain alpha.
img.Image buildDefaultIcon(img.Image padded) {
  final canvas = img.Image(
    width: padded.width,
    height: padded.height,
    numChannels: 4,
  );
  img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));
  img.compositeImage(canvas, padded, dstX: 0, dstY: 0);
  return canvas.convert(numChannels: 3);
}

/// Purpose: Compose the transparent dark-mode iOS icon source.
/// Inputs: Transparent padded artwork.
/// Returns: Slightly brightened transparent icon image.
/// Side effects: None.
/// Notes: The transparent background lets iOS draw the dark icon surface.
img.Image buildDarkIcon(img.Image padded) {
  final icon = img.Image.from(padded);
  for (final pixel in icon) {
    if (pixel.a == 0) {
      continue;
    }
    pixel
      ..r = math.min(255, (pixel.r * 1.05 + 6).round())
      ..g = math.min(255, (pixel.g * 1.05 + 6).round())
      ..b = math.min(255, (pixel.b * 1.05 + 6).round());
  }
  return icon;
}

/// Purpose: Compose the transparent grayscale tinted-mode iOS icon source.
/// Inputs: Transparent padded artwork.
/// Returns: Grayscale transparent icon image.
/// Side effects: None.
/// Notes: iOS applies the user's selected tint color to this source.
img.Image buildTintedIcon(img.Image padded) {
  final icon = img.Image.from(padded);
  for (final pixel in icon) {
    if (pixel.a == 0) {
      continue;
    }
    final luminance = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b)
        .round();
    final boosted = math.max(
      0,
      math.min(255, ((luminance - 18) * 1.12 + 24).round()),
    );
    pixel
      ..r = boosted
      ..g = boosted
      ..b = boosted;
  }
  return icon;
}

/// Purpose: Downscale an icon source to the iOS marketing preview size.
/// Inputs: `image`.
/// Returns: A 1024x1024 image.
/// Side effects: None.
/// Notes: Uses average interpolation to match launcher icon generation.
img.Image resize1024(img.Image image) {
  return img.copyResize(
    image,
    width: 1024,
    height: 1024,
    interpolation: img.Interpolation.average,
  );
}

/// Purpose: Simulate iOS rounded-rectangle clipping for previews.
/// Inputs: `square`, optional preview background color and corner ratio.
/// Returns: A rounded preview on the requested background.
/// Side effects: None.
/// Notes: This is only a static preview, not an asset shipped to iOS.
img.Image maskRoundedPreview(
  img.Image square, {
  int backgroundR = 238,
  int backgroundG = 241,
  int backgroundB = 243,
  double radiusRatio = 0.2237,
}) {
  final src = square.convert(numChannels: 4);
  final radius = (src.width * radiusRatio).round();
  final out = img.Image(width: src.width, height: src.height, numChannels: 4);
  img.fill(
    out,
    color: img.ColorRgba8(backgroundR, backgroundG, backgroundB, 255),
  );
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      final dx = x < radius
          ? radius - x
          : x >= src.width - radius
          ? x - (src.width - radius - 1)
          : 0;
      final dy = y < radius
          ? radius - y
          : y >= src.height - radius
          ? y - (src.height - radius - 1)
          : 0;
      if (dx == 0 || dy == 0 || dx * dx + dy * dy <= radius * radius) {
        out.setPixel(x, y, src.getPixel(x, y));
      }
    }
  }
  return out;
}

/// Purpose: Build a sample colored-tint preview from the grayscale source.
/// Inputs: `grayscale`, `tint`, and preview background `bg`.
/// Returns: A simulated tinted icon preview.
/// Side effects: None.
/// Notes: Approximation for review only; iOS applies the real tint effect.
img.Image tintPreview(
  img.Image grayscale,
  img.ColorRgba8 tint,
  img.ColorRgba8 bg,
) {
  final src = grayscale.convert(numChannels: 4);
  final out = img.Image(width: src.width, height: src.height, numChannels: 4);
  img.fill(out, color: bg);
  for (final pixel in src) {
    if (pixel.a == 0) {
      continue;
    }
    final strength = pixel.r / 255.0;
    final r = (34 + (tint.r - 34) * strength).round();
    final g = (38 + (tint.g - 38) * strength).round();
    final b = (46 + (tint.b - 46) * strength).round();
    out.setPixel(pixel.x, pixel.y, img.ColorRgba8(r, g, b, pixel.a.toInt()));
  }
  return out;
}

/// Purpose: Write a PNG image and create parent folders when needed.
/// Inputs: Output `path` and `image`.
/// Returns: None.
/// Side effects: Writes a PNG file to disk.
/// Notes: Used for both tracked icon assets and temporary preview files.
void writePng(String path, img.Image image) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(image));
}

/// Purpose: Generate iOS default, dark, tinted, and preview icons.
/// Inputs: None.
/// Returns: None.
/// Side effects: Writes `assets/icon/app_icon_ios*.png` and `/tmp` previews.
/// Notes: Run from the repository root with Dart package resolution enabled.
void main() {
  final source = img.decodePng(
    File('assets/icon/app_icon.png').readAsBytesSync(),
  );
  if (source == null) {
    throw StateError('Could not decode source icon.');
  }

  final padded = scaleIntoSafeArea(source);
  final defaultIcon = buildDefaultIcon(padded);
  final darkIcon = buildDarkIcon(padded);
  final tintedIcon = buildTintedIcon(padded);

  writePng('assets/icon/app_icon_ios.png', defaultIcon);
  writePng('assets/icon/app_icon_ios_dark.png', darkIcon);
  writePng('assets/icon/app_icon_ios_tinted.png', tintedIcon);

  final default1024 = resize1024(defaultIcon);
  final dark1024 = resize1024(darkIcon);
  final tinted1024 = resize1024(tintedIcon);

  writePng(
    '/tmp/myanime_icon_ios_default_rounded_preview.png',
    maskRoundedPreview(default1024),
  );
  writePng(
    '/tmp/myanime_icon_ios_dark_preview.png',
    maskRoundedPreview(
      dark1024,
      backgroundR: 20,
      backgroundG: 24,
      backgroundB: 32,
    ),
  );
  writePng(
    '/tmp/myanime_icon_ios_tinted_grayscale_preview.png',
    maskRoundedPreview(
      tinted1024,
      backgroundR: 32,
      backgroundG: 34,
      backgroundB: 38,
    ),
  );
  writePng(
    '/tmp/myanime_icon_ios_tinted_blue_preview.png',
    maskRoundedPreview(
      tintPreview(
        tinted1024,
        img.ColorRgba8(96, 188, 232, 255),
        img.ColorRgba8(24, 28, 36, 255),
      ),
      backgroundR: 24,
      backgroundG: 28,
      backgroundB: 36,
    ),
  );

  final defaultBounds = contentBoundsAgainstCorner(default1024);
  final darkBounds = alphaBounds(dark1024);
  final tintedBounds = alphaBounds(tinted1024);
  stdout.writeln('source=${source.width}x${source.height}');
  stdout.writeln(
    'default_1024_content=${defaultBounds.width}x${defaultBounds.height}',
  );
  stdout.writeln('dark_1024_alpha=${darkBounds.width}x${darkBounds.height}');
  stdout.writeln(
    'tinted_1024_alpha=${tintedBounds.width}x${tintedBounds.height}',
  );
}
