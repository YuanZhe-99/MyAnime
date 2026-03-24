import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

void main() async {
  final srcBytes = await File('assets/icon/app_icon.png').readAsBytes();
  final srcImage = img.decodePng(srcBytes)!;
  print('Source: ${srcImage.width}x${srcImage.height}');

  const sizes = [16, 32, 48, 256];

  // Encode each size as PNG
  final pngDataList = <Uint8List>[];
  for (final size in sizes) {
    final resized = img.copyResize(srcImage,
        width: size, height: size, interpolation: img.Interpolation.average);
    final pngData = Uint8List.fromList(img.encodePng(resized));
    pngDataList.add(pngData);
    print('  ${size}x$size -> ${pngData.length} bytes');
  }

  final ico = BytesBuilder();

  // ICONDIR header (6 bytes)
  ico.add([0, 0]); // reserved
  ico.add([1, 0]); // type: icon
  _addUint16(ico, sizes.length); // image count

  // Calculate data offset: header(6) + entries(16 * count)
  var dataOffset = 6 + 16 * sizes.length;

  // ICONDIRENTRY for each size (16 bytes each)
  for (var i = 0; i < sizes.length; i++) {
    final s = sizes[i];
    ico.addByte(s < 256 ? s : 0); // width (0 = 256)
    ico.addByte(s < 256 ? s : 0); // height (0 = 256)
    ico.addByte(0); // color palette
    ico.addByte(0); // reserved
    _addUint16(ico, 1); // color planes
    _addUint16(ico, 32); // bits per pixel
    _addUint32(ico, pngDataList[i].length); // image data size
    _addUint32(ico, dataOffset); // offset to image data
    dataOffset += pngDataList[i].length;
  }

  // PNG data for each size
  for (final pngData in pngDataList) {
    ico.add(pngData);
  }

  final result = ico.toBytes();
  await File('windows/runner/resources/app_icon.ico').writeAsBytes(result);
  print('Generated ICO: ${result.length} bytes (${sizes.length} sizes: ${sizes.join(", ")})');
}

void _addUint16(BytesBuilder b, int value) {
  b.add([value & 0xFF, (value >> 8) & 0xFF]);
}

void _addUint32(BytesBuilder b, int value) {
  b.add([
    value & 0xFF,
    (value >> 8) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 24) & 0xFF,
  ]);
}
