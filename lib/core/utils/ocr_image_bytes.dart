import 'dart:typed_data';
import 'dart:ui' as ui;

/// Downscale camera photos before OCR so Render finishes before gateway timeout.
Future<Uint8List> downscaleForOcr(
  Uint8List bytes, {
  int maxWidth = 1600,
}) async {
  if (bytes.isEmpty) return bytes;
  try {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: maxWidth,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null || byteData.lengthInBytes < 32) return bytes;
    return byteData.buffer.asUint8List();
  } catch (_) {
    return bytes;
  }
}
